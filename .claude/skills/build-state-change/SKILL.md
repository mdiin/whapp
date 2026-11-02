---
name: build-state-change
authors:
  - Matthias Varberg Ingesman
description: >
  Implement DCB-style write slices with ledjer-swift in this project's one established pattern: a
  `Codable` command and an `async` handler of the command and the event store that either throws or
  appends events, registered in the command registry by name. Use when implementing a new write
  slice / command handler from a slice.json event model in this project. There is exactly one
  supported style - do not offer alternatives.
---

# Build State Change Slice

> Before doing anything else, read the slice definition from `.slices/{Context}/{slicename}/slice.json`.
> This file is the **source of truth** for all fields, events, and metadata — never invent
> fields not defined there. Keep this line verbatim; it applies to every stack.

---

## What a State Change Slice is

A state change slice is **command → events**. It has no UI: the form that sends the command is on the
screen of a state-view slice, which sends it through the command registry by name (see
`build-state-view`). One pattern only.

A state change slice consists of:

- The events it appends, if they don't exist yet (step 2)
- A `Command` struct of the command's fields (step 3.1)
- A handler: an `async` function of the command and the event store that decides, using a `ReadModel`
  of the existing events, and appends with an append condition — or throws (step 3.2)
- A `register(in:)` function that registers the command by name (step 3.3)
- Tests: one `gwt` per specification (step 4)

### Names and files

| What | Rule | Example |
|---|---|---|
| `{context}` | the context name, kebab-cased | `understanding-eventsourcing` |
| `{Context}` | the context name, PascalCase | `UnderstandingEventsourcing` |
| `{slice}` | the slice title, kebab-cased | `add-item` |
| `{Slice}` | the slice title, PascalCase | `AddItem` |
| command name | `{context}/{slice}` — the contract between slices | `understanding-eventsourcing/add-item` |

```
AppCore/Sources/AppCore/
├── Events/{Context}/{EventName}.swift            ← one file per event (step 2)
├── Events/AllEvents.swift                        ← every event type is listed here (step 2)
├── Slices/{Context}/{Context}.swift              ← `enum {Context} {}`: create it if it doesn't exist
├── Slices/{Context}/{Slice}/{Slice}.swift        ← the slice: everything in steps 3.1–3.3
└── Slices/Slices.swift                           ← one line per slice: `{Context}.{Slice}.register(in: &registry)`
AppCore/Tests/AppCoreTests/Slices/{Context}/{Slice}/{Slice}Tests.swift
```

All slices are in one module, so the slice's types are nested in `enum {Slice}` inside
`extension {Context}`, and never collide with another slice's. **Never refer to another slice's types**:
slices are decoupled, and another slice may not be built yet.

## Step 1 — Read the slice.json

From the slice definition, extract:
- **sliceName** — the slice title
- **context** — the bounded context
- **commands[]** — list of commands with their data fields
- **events[]** — list of events emitted by each command
- **specifications[]** — test scenarios (given/when/then)

> **Comments & description**: each element carries a `comments: string[]` array (board comments) and a `description` field — use them as implementation hints, and resolve consumed comments via `POST <BASE_URL>/api/org/<ORG_ID>/boards/<BOARD_ID>/nodes/<nodeId>/comments/<commentId>/resolve`.

---

## Step 2 — the events — only if they don't already exist

**Check `AppCore/Sources/AppCore/Events/` first** (search for `static let eventType: EventType = "{context}/{event}"`);
add an event only if it does not exist.

```swift
import Foundation
import Ledjer

struct CartCreated: Event {
    static let eventType: EventType = "understanding-eventsourcing/cart-created"
    static var tags: [EventTag<Self>] { [EventTag("cartId", \.cartId), EventTag("userId", \.userId)] }

    var cartId: UUID
    var userId: UUID
    var description: String
}
```

- **The type name** is the event title in PascalCase (`Cart Created` → `CartCreated`). If another context
  already has an event of that name, prefix the context (`ShopCartCreated`).
- **`eventType`** is `"{context}/{event title kebab-cased}"`. It is stored with every event: never change it.
- **Properties** are the event's fields, with their board names (camelCase) and the types in "Field types" below.
- **`tags`** are the fields with `idAttribute: true`: `EventTag("{field}", \.{field})`. Only `String`,
  `UUID`, `Int` and `Bool` properties can be tags (optional ones too); an id field of another type is
  left out, recorded as an assumption.
- **Add the type to `AllEvents.types`** in `Events/AllEvents.swift`. `SystemTests` checks that event types
  are unique; ledjer-swift itself only notices a duplicate where both types meet.

**Events are never migrated.** Once an event type exists, never change its fields incompatibly: a
changed event is a new event type (e.g. `CartCreatedV2` with `eventType` `".../cart-created-v2"`), and the
read models and handlers that use the old one handle both. Adding an *optional* field is the one
compatible change.

### Field types

The same rules apply to every struct built from slice.json fields — events, commands, read models, route
parameters:

| slice.json `type` (case-insensitive) | Swift |
|---|---|
| `String` | `String` |
| `UUID` | `UUID` |
| `Boolean` | `Bool` |
| `Int`, `Integer`, `Long` | `Int` |
| `Double` | `Double` |
| `Decimal` | `Decimal` — exact, for money. Never `Double` |
| `Date` | `CalendarDate` — a day without time or zone (`Common/CalendarDate.swift`). Never `Foundation.Date` |
| `DateTime` | `Date` — a point in time, shown in the **device's** time zone |
| `Custom` | a nested `struct {FieldName}: Codable, Sendable, Equatable` built from `subfields` with these same rules (singular for a list: `orderedProducts` → `OrderedProduct`) |

- **`cardinality: "List"`** is an array: `[UUID]`. Never a `Set`, and no dictionaries with non-`String`
  keys in events: `gwt` compares events as JSON, and those encode in no fixed order.
- **`optional: true`** is an optional: `var image: String?`.
- A type not in the table gets the closest match, recorded as an assumption.
- Every struct conforms to `Codable, Sendable, Equatable`.
- A `Custom` struct is nested in the **event** that has the field. A command, read model or item that
  carries the same data uses the event's type (`[CartSubmitted.OrderedProduct]`): events are shared by all
  slices, unlike slice types. A command's `Custom` field that no event has gets its own nested struct.

**Example slice.json event (abbreviated):**

```json
{
  "title": "Cart Created",
  "fields": [
    { "name": "cartId", "type": "UUID", "optional": false, "cardinality": "Single", "idAttribute": true },
    { "name": "userId", "type": "UUID", "optional": false, "cardinality": "Single", "idAttribute": true },
    { "name": "description", "type": "string", "optional": false, "cardinality": "Single", "idAttribute": false }
  ]
}
```

becomes the `CartCreated` above, in `Events/UnderstandingEventsourcing/CartCreated.swift`.

## Step 3 — the slice

```swift
import Foundation
import Ledjer

extension UnderstandingEventsourcing {
    enum AddItem {
        static let name = "understanding-eventsourcing/add-item"

        // The command (step 3.1)

        // The read model of the consistency check and the handler (step 3.2)

        // Registration (step 3.3)
    }
}
```

If `Slices/{Context}/{Context}.swift` doesn't exist, create it with `enum {Context} {}`.

## Step 3.1 — the command

```swift
struct Command: Codable, Sendable, Equatable {
    var cartId: UUID
    var description: String
    var image: String
    var price: Decimal
    var itemId: UUID
    var productId: UUID
}
```

Exactly the command's fields from slice.json, with "Field types" above. The screen sends a payload keyed by
these field names, and the registry decodes it into `Command`: a missing field or a value of the wrong
type comes back to the form as a field error (`CommandInputError`) without any code here. Never parse
or convert values in the handler.

## Step 3.2 — the handler

```swift
/// What the decision depends on: the read model of the events the rules need.
static let cart = ReadModel(initial: Cart(), bindings: [
    .on(CartCreated.self) { cart, _ in cart.exists = true },
    .on(ItemAdded.self) { cart, _ in cart.itemCount += 1 },
    .on(ItemRemoved.self) { cart, _ in cart.itemCount -= 1 },
])

struct Cart: Sendable {
    var exists = false
    var itemCount = 0
}

static func handle(_ command: Command, store: any EventStore) async throws {
    let decision = try await cart.decide(on: store, where: [.payload("cartId"): .bound(command.cartId)])
    guard decision.state.exists else { throw CommandRejected("This cart doesn't exist") }
    guard decision.state.itemCount < 3 else { throw CommandRejected("A cart holds at most 3 items") }
    try await store.append(
        [ItemAdded(cartId: command.cartId, description: command.description, image: command.image,
                   price: command.price, itemId: command.itemId, productId: command.productId)],
        condition: decision.condition)
}
```

- **`ReadModel`** (`Common/ReadModel.swift`) is a ledjer `StateView` that knows its event types. Its state
  holds only what the rules need. Every event type it reads gets exactly one binding.
- **`decide(on:where:)`** returns the state and the append condition. **Always append with
  `decision.condition`**: if an event the decision read was appended meanwhile, the append fails instead of
  breaking a rule. With no rules to check, append without a read model or a condition.
- **Tag bindings** are the command's id fields that the read model's events have as tags:
  `[.payload("{field}"): .bound(command.{field})]`. Bind only tags at least one of the read model's event
  types has (ledjer rejects others); an event type without the bound tag is read unfiltered.
- **Business-rule violations throw `CommandRejected("…")`.** The message is shown to the user as it is, so
  write it for them, in the UI's language. Any other error (a failed append condition, a bug) is reported
  and the user sees a general message — never throw `CommandRejected` for those.
- Rules come from slice.json's specifications, description and comments only. Ids of new entities are
  fields of the command (the screen creates them), not created here.
- Anything non-deterministic the handler needs (the current time, random values) is a parameter with a
  default, so tests can fix it: `static func handle(_ command: Command, store: any EventStore, now: Date = Date())`.

## Step 3.3 — registration

```swift
static func register(in registry: inout Registry) {
    registry.command(name, Command.self) { command, system in
        try await handle(command, store: system.store)
    }
}
```

Then add `{Context}.{Slice}.register(in: &registry)` to `Slices.register(in:)` in
`Slices/Slices.swift`. A name registered twice makes the app fail at launch, and `SystemTests` too.

## Step 4 — the tests

ledjer-swift's `gwt` runs each scenario on a fresh in-memory event store. One `@Test` per specification,
named after it, with Swift Testing:

```swift
import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct AddItemTests {
    typealias Slice = UnderstandingEventsourcing.AddItem
    let cartId = UUID(uuidString: "6B4D7F0E-2F0A-4C55-9C8E-1F6A2B3C4D5E")!
    let itemId = UUID(uuidString: "0D1E2F30-4152-6374-8596-A7B8C9DAEBFC")!
    let price = Decimal(string: "59.95")!  // not the literal 59.95, which goes through Double

    var command: Slice.Command {
        Slice.Command(cartId: cartId, description: "Shoes", image: "shoes.png", price: price,
                      itemId: itemId, productId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)
    }

    @Test func addsAnItemToAnExistingCart() async throws {
        try await gwt(
            given: [CartCreated(cartId: cartId, userId: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
                                description: "")],
            when: { try await Slice.handle(command, store: $0) },
            then: [ItemAdded(cartId: cartId, description: "Shoes", image: "shoes.png", price: price,
                             itemId: itemId, productId: command.productId)])
    }

    @Test func rejectsAFourthItem() async throws {
        try await gwt(
            given: [/* CartCreated and three ItemAdded */],
            when: { try await Slice.handle(command, store: $0) },
            thenThrows: { ($0 as? CommandRejected)?.message == "A cart holds at most 3 items" })
    }
}
```

- `then:` lists the expected events; an empty `then:` asserts that nothing was appended.
- `thenThrows:` **always** has a predicate naming the expected error: by default any error passes, so a
  bug would pass too.
- Use fixed ids and values (taken from the specification's examples where it has them), never `UUID()` in
  expected events.
- Build `given` from the event structs; never call another slice's command.

## Quality gate

Before considering the slice done:

- [ ] Every field in slice.json's `commands[]` is in `Command` — no invented fields, none missing
- [ ] Every field in slice.json's `events[]` is in its event struct — no invented fields, none missing — and every event is in `AllEvents.types`
- [ ] Field types follow "Field types": `Decimal` for money, `CalendarDate` for `Date`, arrays for lists
- [ ] Every `specifications[]` scenario has a corresponding `@Test`, and every `thenThrows:` has a specific predicate
- [ ] No business rule exists in the handler that isn't traceable to slice.json's `description`/`comments`/specifications
- [ ] Business-rule errors are `CommandRejected` with a message for the end user; the append uses `decision.condition`
- [ ] The slice doesn't refer to any other slice's types
- [ ] `register(in:)` registers the command as `{context}/{slice}`, and `Slices.swift` calls it
- [ ] The slice's own tests pass: `scripts/test.sh --only AppCoreTests/{Slice}Tests`
- [ ] If checks pass, commit with `feat: {slicename}` and set slice status to `Done`
