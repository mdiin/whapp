---
name: build-automation
authors:
  - Matthias Varberg Ingesman
description: >
  Implement automation slices (to-do list → command) with ledjer-swift in this project's one established
  pattern: a private `ReadModel` to-do list, a handler that performs the side effect through a protocol
  defined in the slice and records the outcome as events, and a ledjer `automation` that runs the handler
  for every to-do item whenever a trigger fires, registered with the app's lifecycle. Use when implementing
  an automation / processor slice from a slice.json event model in this project. There is exactly one
  supported style - do not offer alternatives.
---

# Build Automation Slice

> Before doing anything else, read the slice definition from `.slices/{Context}/{slicename}/slice.json`.
> This file is the **source of truth** for all fields, events, and metadata — never invent
> fields not defined there. Keep this line verbatim; it applies to every stack.

---

## What an Automation Slice is

In the event model, an automation (the processor) reads a **to-do list** (its INBOUND read model) and
issues a **command** for every item on it. The command's OUTBOUND events record the outcome, and the
outcome events take the item off the to-do list again.

An automation slice consists of:

- A private to-do list `ReadModel` — this slice's own copy of the processor's INBOUND read model
- For each external service the command needs: a protocol and its live implementation, **in the slice**
- A handler of the command, the services and the event store that performs the side effect (if any) and
  appends the outcome events
- A `start` function returning a ledjer `Automation` that runs the handler for every to-do item
- A `register(in:)` function that registers the automation with the app's lifecycle
- Tests

Names and files follow the `build-state-change` skill ("Names and files"). Everything goes into
`Slices/{Context}/{Slice}/{Slice}.swift`; there is no screen.

## How the automation runs

Read this before writing any code — the rules in the later steps follow from it:

- `automation(on:triggers:onError:body:)` subscribes to the triggers and runs `body` every time one fires.
  It returns an `Automation`; `stop()` stops it.
- **`body` is not given the triggering event.** It finds its work by reading the to-do `ReadModel`. That is
  why every automation has a to-do list.
- Triggers: `.event(SomeEvent.self)`, `.periodic(every:)`, and `Trigger.onStart` (`Common/ReadModel.swift`),
  which fires once when the automation starts.
- **The app starts automations when it becomes active and stops them when it goes to the background**
  (`Lifecycle`). Event triggers fire only for *new* events, so `.onStart` is always a trigger: it processes
  what is still on the to-do list from before.
- A body that throws is reported to `onError` and the automation keeps running. Still, catch failures **per
  item**, so one failing item doesn't stop the others; and the handler turns expected failures into events.
- `stop()` cancels a body in flight. Bodies should honour cancellation (`URLSession` does) and be
  idempotent: an item may be processed again after the app comes back.

## Step 1 — Read the slice.json

From the slice definition, extract:
- **sliceName** — the slice title
- **context** — the bounded context
- **processors[]** — the processor; its INBOUND `READMODEL` dependency is the to-do list, its OUTBOUND `COMMAND` dependency is the command
- **commands[]** — the command with its data fields; its OUTBOUND `EVENT` dependencies are the possible outcomes
- **events[]** — events defined in this slice
- **specifications[]** — test scenarios (given/when/then)

> **Comments & description**: each element carries a `comments: string[]` array (board comments) and a `description` field — use them as implementation hints, and resolve consumed comments via `POST <BASE_URL>/api/org/<ORG_ID>/boards/<BOARD_ID>/nodes/<nodeId>/comments/<commentId>/resolve`.

**The to-do read model is defined in another slice.** The processor only references it by `id` and
`title`. Find its definition by searching `.build-kit/.slices/{context}/*/slice.json` for a `readmodels[]`
entry with the same `id`. If it isn't there, run `/load-slice` for the slice that owns it. The read model's
`fields` and INBOUND `EVENT` dependencies are what step 4.1 builds the private copy from.

**Example slice.json processor and command (abbreviated)** — slice "Publish Cart":

```json
"processors": [{
  "title": "automation",
  "type": "AUTOMATION",
  "dependencies": [
    { "id": "1ecaf8a8-...", "type": "OUTBOUND", "title": "Publish Cart", "elementType": "COMMAND" },
    { "id": "e3dc2c7e-...", "type": "INBOUND", "title": "Submitted Cart Data", "elementType": "READMODEL" }
  ]
}],
"commands": [{
  "title": "Publish Cart",
  "fields": [
    { "name": "aggregateId", "type": "UUID", "cardinality": "Single", "idAttribute": false },
    { "name": "orderedProducts", "type": "Custom", "cardinality": "List", "idAttribute": false,
      "subfields": [ { "name": "productId", "type": "UUID" }, { "name": "price", "type": "Decimal" } ] },
    { "name": "totalPrice", "type": "Decimal", "cardinality": "Single", "idAttribute": false }
  ],
  "dependencies": [
    { "type": "OUTBOUND", "title": "Cart Publication Failed", "elementType": "EVENT" },
    { "type": "OUTBOUND", "title": "Cart Published", "elementType": "EVENT" },
    { "type": "OUTBOUND", "title": "External Cart Published", "elementType": "EVENT" },
    { "type": "INBOUND", "title": "automation", "elementType": "AUTOMATION" }
  ]
}]
```

and the read model `e3dc2c7e-...` is found in `.build-kit/.slices/understanding-eventsourcing/submittedcartdata/slice.json`,
with the fields `aggregateId`, `orderedProducts`, `totalPrice` and the INBOUND event `Cart Submitted`.

## Step 2 — the events — only if they don't already exist

Add the events that don't exist yet, exactly as in step 2 of the `build-state-change` skill (including
`AllEvents.types` and "Field types"), taken from:

- all the to-do read model's `INBOUND` events
- all the command's `OUTBOUND` events
- all the slice's `events`

## Step 3 — the external services

Decide what the command needs from outside the event store to carry out its side effect (calling an HTTP
API, scheduling a notification, ...). Use the command's `description`, its comments, and the names of its
OUTBOUND events (e.g. "External Cart Published", "Welcome Email Sent") as evidence. A command with no side
effect has no services.

Each service is a **protocol in the slice**, with only the operations this command needs, and a **live
implementation** next to it:

```swift
protocol CartPublisher: Sendable {
    func publish(_ command: Command) async throws
}

struct LiveCartPublisher: CartPublisher {
    let baseURL: URL
    var session: URLSession = .shared

    func publish(_ command: Command) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("carts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(command)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
```

- **Never share a protocol with another slice**, even if two slices call the same API: each slice defines
  its own.
- HTTP uses `URLSession` with `async`/`await` and `Codable`. On-device frameworks (notifications, …) are
  wrapped the same way.
- **Configuration** (base URLs, API keys) is declared in `register(in:)` with
  `registry.requireConfig("{KEY}", testValue: "...")` and read with `system.config.url("{KEY}")` /
  `.string("{KEY}")`. Keys are SCREAMING_SNAKE_CASE. Add the key to `Config/Info.plist`'s `AppConfig`
  dictionary as `$({KEY})`, and to `Config/Base.xcconfig` with an empty value. If the value isn't known
  from slice.json or the project's `CLAUDE.md`, leave it empty: the app then refuses to start, naming the
  key, until someone sets it. Record that in `progress.txt`.
- If the service can't be built at all from what is known (no API description, no idea what it does),
  invoke `/request-feedback` naming the service and what the command needs it for. Never stub a live
  implementation.

## Step 4 — the automation slice

```swift
import Foundation
import Ledjer

extension UnderstandingEventsourcing {
    enum PublishCart {
        static let name = "understanding-eventsourcing/publish-cart"

        // To-do list (step 4.1)
        // Command, services and handler (steps 3 and 4.2)
        // Automation (step 4.3)
        // Registration (step 4.4)
    }
}
```

## Step 4.1 — the to-do list

A `ReadModel` built from the to-do read model's definition (step 1), as in step 3.1 of the
`build-state-view` skill, with two additions:

- **The state is the collection of items to do**: a dictionary keyed by the item's id (`[:]`), or an array
  when an item has no id. Each item holds exactly the read model's fields.
- **It also has a binding for every outcome event that ends the processing of an item**, which removes the
  item. Without it the automation runs the command for the same item on every trigger, forever. An outcome
  that should be retried (e.g. "... Failed" when the slice describes retries) gets no such binding.

The read model is private to this slice: define it here even if the owning state-view slice has one too.

```swift
struct Item: Codable, Sendable, Equatable {
    var aggregateId: UUID
    var orderedProducts: [CartSubmitted.OrderedProduct]  // the event's own type for its Custom field
    var totalPrice: Decimal
}

static let todo = ReadModel(initial: [UUID: Item](), bindings: [
    .on(CartSubmitted.self) { items, event in
        items[event.aggregateId] = Item(aggregateId: event.aggregateId, orderedProducts: event.orderedProducts,
                                        totalPrice: event.totalPrice)
    },
    .on(CartPublished.self) { items, event in items[event.aggregateId] = nil },
    .on(CartPublicationFailed.self) { items, event in items[event.aggregateId] = nil },
])
```

## Step 4.2 — the command and its handler

The `Command` struct is the command's fields, as in step 3.1 of `build-state-change`. Services come
before the store, so tests can pass fakes:

```swift
struct Command: Codable, Sendable, Equatable {
    var aggregateId: UUID
    var orderedProducts: [CartSubmitted.OrderedProduct]
    var totalPrice: Decimal
}

static func handle(_ command: Command, publisher: any CartPublisher, store: any EventStore) async throws {
    do {
        try await publisher.publish(command)
    } catch is CancellationError {
        throw CancellationError()  // stopped: not a failure, try again next time
    } catch {
        try await store.append([CartPublicationFailed(aggregateId: command.aggregateId)])
        return
    }
    try await store.append([
        ExternalCartPublished(aggregateId: command.aggregateId),
        CartPublished(aggregateId: command.aggregateId),
    ])
}
```

- When the command has **one** OUTBOUND event, append it after the side effect and let failures throw:
  the item stays on the to-do list and is retried at the next trigger.
- When the command has a **success and a failure** event, catch the side effect's error and append the
  failure event, as above. Cancellation is never a failure.
- Only add retry limits, abort events, or other logic when slice.json describes them. Then source the
  earlier attempts, e.g. "abort after 5 failed attempts":

```swift
let failures = try await store.source(
    try EventQuery.of(CartPublicationFailed.self, where: [.payload("aggregateId"): .bound(command.aggregateId)]))
if failures.count >= 4 { /* append the abort event */ } else { /* append the failure event */ }
```

- Anything non-deterministic the handler needs (the current time, random ids) is a parameter with a
  default, so tests can fix it.

## Step 4.3 — the automation

```swift
static func start(
    on store: any EventStore,
    publisher: any CartPublisher,
    onError: @escaping @Sendable (any Error) -> Void
) async throws -> Automation {
    try await automation(
        on: store,
        triggers: [.onStart, .event(CartSubmitted.self)],
        onError: onError
    ) { store in
        for item in try await todo.run(on: store).values {
            try Task.checkCancellation()
            do {
                try await handle(Command(aggregateId: item.aggregateId, orderedProducts: item.orderedProducts,
                                         totalPrice: item.totalPrice),
                                 publisher: publisher, store: store)
            } catch is CancellationError {
                return
            } catch {
                onError(error)  // reported; the item is retried at the next trigger
            }
        }
    }
}
```

- **Triggers** are `.onStart` and the to-do read model's INBOUND event types — the events that put items on
  the list.
- **Periodic trigger** (`.periodic(every: .seconds(...))`): only when slice.json describes retries,
  scheduling, or a time-based rule; take the interval from the description or comments, or use 5 minutes
  and record the assumption. It only runs while the app is active.
- Use `.values` for a dictionary-shaped to-do list, the array itself otherwise.

## Step 4.4 — registration

```swift
static func register(in registry: inout Registry) {
    registry.requireConfig("CART_PUBLISHER_URL", testValue: "https://cart-publisher.example.test")
    registry.automation(name) { system in
        try await start(on: system.store,
                        publisher: LiveCartPublisher(baseURL: try system.config.url("CART_PUBLISHER_URL")),
                        onError: system.reportError)
    }
}
```

Then add `{Context}.{Slice}.register(in: &registry)` to `Slices.register(in:)` in `Slices/Slices.swift`.
The lifecycle starts the automation whenever the app becomes active and stops it in the background.

## Step 5 — the tests

```swift
import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct PublishCartTests {
    typealias Slice = UnderstandingEventsourcing.PublishCart
    let cartId = UUID(uuidString: "6B4D7F0E-2F0A-4C55-9C8E-1F6A2B3C4D5E")!

    struct Succeeding: Slice.CartPublisher { func publish(_ command: Slice.Command) async throws {} }
    struct Failing: Slice.CartPublisher {
        func publish(_ command: Slice.Command) async throws { throw URLError(.notConnectedToInternet) }
    }

    // 1. The to-do list: an item appears, and every outcome that ends processing removes it
    @Test func submittedCartIsToDo() async throws {
        try await gwt(
            given: [CartSubmitted(aggregateId: cartId, orderedProducts: [], totalPrice: 0)],
            view: { try await Slice.todo.run(on: $0) },
            then: [cartId: Slice.Item(aggregateId: cartId, orderedProducts: [], totalPrice: 0)])
    }

    @Test func publishedCartIsDone() async throws {
        try await gwt(
            given: [CartSubmitted(aggregateId: cartId, orderedProducts: [], totalPrice: 0),
                    CartPublished(aggregateId: cartId)],
            view: { try await Slice.todo.run(on: $0) },
            then: [:])
    }

    // 2. The handler: one scenario per outcome, with fake services
    @Test func publishesTheCart() async throws {
        try await gwt(
            when: { try await Slice.handle(Slice.Command(aggregateId: cartId, orderedProducts: [], totalPrice: 0),
                                           publisher: Succeeding(), store: $0) },
            then: [ExternalCartPublished(aggregateId: cartId), CartPublished(aggregateId: cartId)])
    }

    @Test func recordsAFailedPublication() async throws {
        try await gwt(
            when: { try await Slice.handle(Slice.Command(aggregateId: cartId, orderedProducts: [], totalPrice: 0),
                                           publisher: Failing(), store: $0) },
            then: [CartPublicationFailed(aggregateId: cartId)])
    }

    // 3. The automation end to end: given the to-do event, then the outcome events
    @Test func publishesSubmittedCarts() async throws {
        try await gt(
            automation: { try await Slice.start(on: $0, publisher: Succeeding(), onError: { _ in }) },
            given: [CartSubmitted(aggregateId: cartId, orderedProducts: [], totalPrice: 0)],
            then: [ExternalCartPublished(aggregateId: cartId), CartPublished(aggregateId: cartId)])
    }
}
```

Automation scenarios in `specifications[]` read "given events, then command (or nothing)". Test each one on
the handler (part 2), with `then:` being the events the command results in — or on the to-do list (part 1)
when the scenario is about whether an item is on it at all. Use fixed ids and values; build `given` from the
event structs, never from another slice's command.

## Quality gate

Before considering the slice done:

- [ ] The to-do list's items have exactly the read model's fields — no invented fields, none missing
- [ ] Every outcome event that ends processing removes the item from the to-do list
- [ ] Every field in slice.json's `commands[]` is in `Command` — no invented fields, none missing
- [ ] Every field in slice.json's `events[]` is in its event struct, and every event is in `AllEvents.types`
- [ ] Every external service is a protocol in this slice with a live implementation; its configuration keys are declared with `requireConfig` and listed in `Config/Info.plist` and `Config/Base.xcconfig`
- [ ] The triggers include `.onStart`; failures are caught per item and reported; cancellation is not a failure
- [ ] The automation is registered with `registry.automation`, and `Slices.swift` calls `register(in:)`
- [ ] Every `specifications[]` scenario has a corresponding `@Test`
- [ ] No business rule (retry limits, intervals, ...) exists that isn't traceable to slice.json's `description`/`comments`
- [ ] The slice's own tests pass: `scripts/test.sh --only AppCoreTests/{Slice}Tests`
- [ ] If checks pass, commit with `feat: {slicename}` and set slice status to `Done`
