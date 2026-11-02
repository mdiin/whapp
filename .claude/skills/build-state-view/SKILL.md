---
name: build-state-view
authors:
  - Matthias Varberg Ingesman
description: >
  Use when implementing a new read slice / projection from a slice.json event model in this project:
  events → read model → (optionally) a SwiftUI screen. Two read model kinds: a `ReadModel` (a ledjer-swift
  `StateView`, the default) and a ledjer-swift `PersistedStateView` with a `GRDBAccumulator` (only for read
  models that process many events or need advanced querying). Always use one of these - do not offer
  other alternatives.
---

# Build State View Slice

> Before doing anything else, read the slice definition from `.slices/{Context}/{slicename}/slice.json`.
> This file is the **source of truth** for all fields, events, and metadata — never invent
> fields not defined there. Keep this line verbatim; it applies to every stack.

---

## What a State View Slice is

A state view slice is **events → read model → screen**. The screen is there only if the read model has an
OUTBOUND `SCREEN` dependency; it shows the read model, has the forms of the commands on its screens, and
moves on after a command as the board's timeline says.

A state view slice consists of:

- A read model per `readmodel` in the slice (step 3.1 or 3.1p)
- Only if a read model has an OUTBOUND `SCREEN` dependency: a SwiftUI screen with its forms and
  navigation (step 3.2), and a `#Preview`
- A `register(in:)` function: the screen's route, the commands and screens it uses, and for a persisted
  view its table and lifecycle (step 3.3)
- Tests of the read model, and snapshot tests of the screen (step 4)

### Names and files

Names follow the `build-state-change` skill ("Names and files"): `{context}`/`{Context}`, `{slice}`/`{Slice}`.
The **route name** of the screen is `{context}/{slice}` — the contract between slices: other slices link and
navigate to it by that name.

```
AppCore/Sources/AppCore/
├── Events/{Context}/{EventName}.swift              ← events (step 2), listed in Events/AllEvents.swift
├── Slices/{Context}/{Context}.swift                ← `enum {Context} {}`: create it if it doesn't exist
├── Slices/{Context}/{Slice}/{Slice}.swift          ← read model(s) and `register(in:)`
├── Slices/{Context}/{Slice}/{Slice}Screen.swift    ← the screen and its preview, if there is a screen
└── Slices/Slices.swift                             ← one line per slice: `{Context}.{Slice}.register(in: &registry)`
AppCore/Tests/AppCoreTests/Slices/{Context}/{Slice}/{Slice}Tests.swift
AppCore/Tests/AppCoreTests/Slices/{Context}/{Slice}/__Snapshots__/       ← recorded screen images
```

**Never refer to another slice's types.** Other slices' commands and screens are used by name, through the
registries, so they may be built later.

## Step 1 — Read the slice.json

From the slice definition, extract:
- **sliceName** — the slice title
- **context** — the bounded context
- **events[]** - the events defined in this slice
- **readmodels[]** — the read model(s) this slice serves
- **screens[]** — the screens, if any
- **specifications[]** — test scenarios (given/when/then)

> **Comments & description**: each element carries a `comments: string[]` array (board comments) and a `description` field — use them as implementation hints, and resolve consumed comments via `POST <BASE_URL>/api/org/<ORG_ID>/boards/<BOARD_ID>/nodes/<nodeId>/comments/<commentId>/resolve`.

---

## Step 2 — the events — only if they don't already exist

Add the events that don't exist yet, exactly as in step 2 of the `build-state-change` skill (including
`AllEvents.types` and "Field types"), taken from:

- all the read model's `INBOUND` dependencies
- all the slice's `events`

## Step 3.0 — which kind of read model

**Default to `ReadModel`** (step 3.1): it reduces the read model's events whenever it is read. Use a
**persisted view** (step 3.1p) only when at least one of these holds:

- the read model processes a lot of events, e.g. from many different entities, so reducing them on every
  read is too expensive
- it must support advanced querying, e.g. search, filtering, sorting, paging

If slice.json or its comments don't say so, use `ReadModel`. If you pick a persisted view, record why in
`progress.txt`.

## Step 3.1 — the read model (`ReadModel`)

```swift
import Foundation
import Ledjer

extension UnderstandingEventsourcing {
    enum CartItems {
        static let name = "understanding-eventsourcing/cart-items"

        struct Item: Codable, Sendable, Equatable {
            var cartId: UUID
            var itemId: UUID
            var productId: UUID
            var description: String
            var image: String
            var price: Decimal
            var totalPrice: Decimal
        }

        static let model = ReadModel(initial: [UUID: Item](), bindings: [
            .on(ItemAdded.self) { items, event in
                items[event.itemId] = Item(
                    cartId: event.cartId, itemId: event.itemId, productId: event.productId,
                    description: event.description, image: event.image, price: event.price,
                    totalPrice: event.price)
            },
            .on(ItemRemoved.self) { items, event in items[event.itemId] = nil },
            .on(CartCleared.self) { items, _ in items = [:] },
            // ... one binding per INBOUND event
        ])

        // register(in:) — step 3.3
    }
}
```

- **One binding per INBOUND event** of the read model: ledjer throws if an event it reads has none (or two).
- **The state's shape** follows from how the read model is read:
  - **One entry** — every id attribute of the read model is known when it is read (from the screen's
    route): the state is one struct of the read model's fields, optional or with defaults until the first
    event (`initial: Cart?.none`).
  - **Many entries** — some id attribute is *not* known when it is read (`cartId` is in the route but
    `itemId` isn't), or the screen shows a list: a dictionary from that id to a struct of the read model's
    fields, starting as `[:]`. An array only when entries have no id attribute at all.
- **Fields** are the read model's fields, with "Field types" from `build-state-change`. A field with a
  non-empty `mapping` takes its value from the event field named by `mapping` (`totalPrice` with
  `"mapping": "price"` is set from the event's `price`).
- The specifications define any special requirements on how the bindings update the state.
- The state, and everything in it, is `Sendable` and `Equatable` (tests compare it).

## Step 3.1p — a persisted view

A persisted view keeps tables of the app's SQLite database up to date from a subscription, and the screen
reads the tables. Its reducers are pure: they return `GRDBOperation`s, which ledjer commits in batches,
together with the view's checkpoint.

```swift
import Foundation
import GRDB
import Ledjer
import LedjerGRDB

extension Catalog {
    enum ProductSearch {
        static let name = "catalog/product-search"
        static let table = "catalog_product_search"

        static let view = PersistedStateView<GRDBOperation>(bindings: [
            .on(ProductAdded.self) { event in
                [GRDBOperation { db in
                    try db.execute(
                        sql: "INSERT INTO \(table) (productId, name, price) VALUES (?, ?, ?)",
                        arguments: [event.productId.uuidString, event.name, "\(event.price)"])
                }]
            },
            .on(ProductRemoved.self) { event in
                [GRDBOperation { db in
                    try db.execute(sql: "DELETE FROM \(table) WHERE productId = ?", arguments: [event.productId.uuidString])
                }]
            },
        ])

        struct Product: Codable, Sendable, Equatable, FetchableRecord { var productId: String; var name: String; var price: String }

        /// The queries the screen needs.
        static func search(_ db: Database, text: String) throws -> [Product] {
            try Product.fetchAll(db, sql: "SELECT * FROM \(table) WHERE name LIKE ? ORDER BY name", arguments: ["%\(text)%"])
        }

        static func register(in registry: inout Registry) {
            registry.migration("\(name)/v1") { db in
                try db.create(table: table) { t in
                    t.primaryKey("productId", .text)
                    t.column("name", .text).notNull()
                    t.column("price", .text).notNull()
                }
            }
            registry.persistedView(name) { system in
                let accumulator = try await GRDBAccumulator.open(name: name, writer: system.database)
                var options = PersistedViewOptions()
                options.onError = system.reportError
                return try await view.start(on: system.store, accumulator: accumulator, options: options)
            }
            // registry.route(...) if there is a screen — step 3.3
        }
    }
}
```

- **One binding per INBOUND event**, as for `ReadModel`. A reducer never does IO: it only returns
  operations. No runtime tag bindings: the view reduces every event of its types, so filter by user, id
  etc. in the queries.
- **The table** is created by a migration registered as `"{context}/{slice}/v1"`. Migrations are never
  changed once shipped: a changed table is a new migration (`/v2`). To rebuild a read model after its
  reducers change, a new migration empties the table and calls
  `GRDBAccumulator.clearCheckpoint(named: name, in: db)`; the view then replays every event.
- Store `Decimal` as text (`"\(price)"`), `UUID` as `uuidString`, `CalendarDate` as its `description`,
  and `Date` as `timeIntervalSince1970`, so values round-trip exactly.
- `registry.persistedView` gives the view the app's lifecycle: it runs while the app is active, and
  resumes after its checkpoint when the app becomes active again.
- The read model may lag a little behind the latest events: a screen observing its tables updates when
  the view commits.

## Step 3.2 — the screen — only if a read model has an OUTBOUND `SCREEN` dependency

**Find the screen's commands first.** The read model's OUTBOUND SCREEN dependencies point at screens, most
of which live in *other* slices. Look each one up by `id` in `.build-kit/.slices/{context}/*/slice.json`
(`screens[]`). Every OUTBOUND `COMMAND` dependency on those screens is a form or button on this screen,
sending that command to the state-change slice that owns it.

Example: the `cart items` read model has three OUTBOUND SCREEN dependencies. One is the screen in this slice;
the others are in `removeitem` and `clearcart`, with OUTBOUND commands `Remove Item` and `Clear Cart`. The
cart items screen therefore has a remove button per item, and a clear button.

**Then find where each command leads.** `load-slice` writes `navigation.json` into the folder of every
state-change slice (`.build-kit/.slices/{context}/{commandslice}/navigation.json`): the state-view slices
that follow the command on its timeline, resolved to the screens they show. See "Navigation" below.

### The screen

```swift
import Foundation
import Ledjer
import SwiftUI

extension UnderstandingEventsourcing.CartItems {
    struct Parameters: Codable, Sendable { var cartId: UUID }

    struct Screen: View {
        let system: AppSystem
        let cartId: UUID
        @State private var live: LiveValue<[UUID: Item]>
        @State private var errors: [String: CommandErrors] = [:]
        @Environment(Navigator.self) private var navigator

        init(system: AppSystem, cartId: UUID) {
            self.init(system: system, cartId: cartId,
                      live: LiveValue(system, model, where: [.payload("cartId"): .bound(cartId)]))
        }

        /// Also for snapshot tests, with a value loaded beforehand.
        init(system: AppSystem, cartId: UUID, live: LiveValue<[UUID: Item]>) {
            self.system = system
            self.cartId = cartId
            _live = State(initialValue: live)
        }

        var body: some View {
            content
                .navigationTitle("Cart")
                .task { await live.run() }
        }

        @ViewBuilder private var content: some View {
            if let items = live.value {
                List {
                    ForEach(items.values.sorted { $0.description < $1.description }, id: \.itemId) { item in
                        HStack {
                            Text(item.description)
                            Spacer()
                            Text(item.price, format: .number)
                        }
                        .swipeActions {
                            Button("Remove", role: .destructive) { Task { await removeItem(item.itemId) } }
                                .disabled(!system.commands.isRegistered("understanding-eventsourcing/remove-item"))
                        }
                    }
                    ErrorMessages(errors["understanding-eventsourcing/remove-item"]?.general ?? [])
                }
            } else if let failure = live.failure {
                ContentUnavailableView("Could not load", systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: failure)))
            } else {
                ProgressView()
            }
        }

        private func removeItem(_ itemId: UUID) async {
            let command = "understanding-eventsourcing/remove-item"
            do {
                try await system.send(command, ["cartId": .uuid(cartId), "itemId": .uuid(itemId)])
                errors[command] = nil
                // Navigation: navigation.json says the next view is this screen again: stay.
            } catch {
                errors[command] = CommandErrors(error)
            }
        }
    }
}

#Preview {
    let cartId = UUID()
    PreviewHost(given: [
        ItemAdded(cartId: cartId, description: "Shoes", image: "", price: Decimal(string: "59.95")!,
                  itemId: UUID(), productId: UUID()),
    ]) { system in
        UnderstandingEventsourcing.CartItems.Screen(system: system, cartId: cartId)
    }
}
```

- **Route parameters** are the read model's id attributes known when the screen opens — the ones it is
  read by (`cartId`, not the list's `itemId`). They are decoded from the route into `Parameters` (step 3.3).
  Ids of the signed-in user (e.g. `userId`) come from wherever the project's `CLAUDE.md` says; if it says
  nothing and the read model needs one, invoke `/request-feedback`.
- **The read model**: `LiveValue(system, model, where: [...])`, with the route parameters as tag bindings
  (only tags the read model's events have), or for a persisted view
  `LiveValue(system, observing: { db in try search(db, text: ...) })`. `.task { await live.run() }` follows it
  while the screen is shown and the app is active; nothing else is needed to refresh after a command.
- **Show the screen's `fields`** — they are what the screen displays, taken from the read model. Show `Date`
  values with `.formatted(...)` (device time zone), `CalendarDate` with its own formatting, `Decimal` with
  `.number` or `.currency(code:)`.
- **Loading and failure**: `live.value == nil` while loading; `live.failure` if loading failed.

### Forms — one per command found above

```swift
@State private var description = ""
@State private var price: Decimal = 0

Section("Add item") {
    TextField("Description", text: $description)
    ErrorMessages(errors[command]?["description"] ?? [])
    TextField("Price", value: $price, format: .number)
    ErrorMessages(errors[command]?["price"] ?? [])
    ErrorMessages(errors[command]?.general ?? [])
    Button("Add") { Task { await addItem() } }
        .disabled(!system.commands.isRegistered(command))
}
```

- **Send by name**: `try await system.send("{context}/{commandslice}", payload)`. The payload's keys are the
  command's field names on the board, exactly; values are `FieldValue`s (`.uuid`, `.string`, `.int`,
  `.decimal`, `.bool`, `.date`, `.dateTime`, `.list`, `.object`, `.null` for an empty optional field).
- **Ids** come from the route, the read model or, for a new entity, `UUID()` created by the screen. Never
  let the user type an id.
- **Controls per field type**: `String` → `TextField`; `Int`, `Double`, `Decimal` → `TextField(value:format: .number)`;
  `Boolean` → `Toggle`; `Date` → `DatePicker(displayedComponents: .date)`, sent as `.date(CalendarDate(date))`;
  `DateTime` → `DatePicker` with `[.date, .hourAndMinute]`, sent as `.dateTime(date)`; `List` → one control per
  item, or a multiple selection from the read model. `Custom` fields with `subfields` and lists of them have
  no obvious form shape; if a screen needs one, invoke `/request-feedback` instead of inventing one.
- **Errors**: `CommandErrors(error)` gives field errors (`errors[command]?["{field}"]`) and general ones
  (`.general`). Show field errors next to their control and general ones with the button.
- **Disable** the form while the command isn't registered: its slice may not be built yet.
- A form with fields the user fills in is typically a sheet or a section, as the board's screen shows it.
- **Styling and layout follow the project's own `CLAUDE.md`** (design system, components, tokens).
  Without one, use plain system controls. Never write raw design values the project's rules forbid.

### Navigation

What happens after a command succeeds comes from the command's `navigation.json`, **never** from which
events it appended:

```json
{
  "command": "Remove Item",
  "destinations": [
    { "slice": "Cart Items", "informational": true, "screen": "understanding-eventsourcing/cart-items",
      "readmodel": "cart items" }
  ],
  "unresolved": []
}
```

- **No destination** → stay. The screen refreshes by itself.
- **One destination** that is this screen (`screen` is this slice's route name) → stay.
- **One destination** that is another screen → `navigator.navigate(to: Route("{screen}", parameters))`. It
  goes back to that screen if it is already on the stack, and pushes it otherwise; it closes a sheet first.
- **Several destinations** → they are alternatives: the app goes to the first one whose condition holds.
  Work out each condition from the board — what the destination screens show (e.g. "1 item" vs "0 items and
  a submit button"), the read models' specifications, descriptions and comments — and evaluate it on this
  screen's read model after the command: `await live.refresh()`, then test `live.value`. If a condition
  needs data this read model doesn't have, define a private `ReadModel` for it in this slice. If a
  condition can't be worked out, invoke `/request-feedback` naming the alternatives.
- **`unresolved` is not empty** (an informational slice whose original screen wasn't found) → invoke
  `/request-feedback`.
- **Parameters** of the destination: its read model's id attributes, taken from this screen's route, the
  command's payload or the read model, by field name. One that can't be resolved is an error to report
  (`/request-feedback`), never a guess. Extra parameters are ignored by the destination.
- A command that throws keeps the screen where it is, showing the errors.

```swift
try await system.send(command, payload)
errors[command] = nil
await live.refresh()
if live.value?.isEmpty == true {  // condition for "Ready to submit", from its screen showing 0 items
    navigator.navigate(to: Route("checklist/ready-to-submit", ["listId": .uuid(listId)]))
}  // otherwise the next view is this screen again: stay
```

Links to other screens that aren't the result of a command are `RouteLink(Route(...), system: system) { ... }`,
disabled while that screen isn't registered.

## Step 3.3 — registration

```swift
static func register(in registry: inout Registry) {
    registry.route(name, title: "Cart Items", parameters: ["cartId"]) { route, system in
        let parameters = try route.decode(Parameters.self)
        return Screen(system: system, cartId: parameters.cartId)
    }
    registry.uses(command: "understanding-eventsourcing/remove-item", from: name)
    registry.uses(command: "understanding-eventsourcing/clear-cart", from: name)
    // registry.uses(route: "...", from: name) for every screen it navigates or links to
}
```

- `title` is the screen's title on the board (or the slice title).
- `uses` declares every command the screen sends and every screen it navigates or links to; the full
  suite reports names that end up registered by no slice.
- Without a screen, `register(in:)` registers nothing for a `ReadModel` — omit it then, and the line in
  `Slices.swift` — or only the persisted view's migration and lifecycle (step 3.1p).

Then add `{Context}.{Slice}.register(in: &registry)` to `Slices.register(in:)` in `Slices/Slices.swift`.

## Step 4 — tests

One `@Test` per specification, with Swift Testing and ledjer-swift's scenarios on a fresh in-memory store:

```swift
import Foundation
import Ledjer
import Testing

@testable import AppCore

@Suite struct CartItemsTests {
    typealias Slice = UnderstandingEventsourcing.CartItems
    let cartId = UUID(uuidString: "6B4D7F0E-2F0A-4C55-9C8E-1F6A2B3C4D5E")!
    let itemId = UUID(uuidString: "0D1E2F30-4152-6374-8596-A7B8C9DAEBFC")!

    @Test func listsAddedItems() async throws {
        try await gwt(
            given: [ItemAdded(cartId: cartId, description: "Shoes", image: "", price: Decimal(string: "59.95")!,
                              itemId: itemId, productId: itemId)],
            view: { try await Slice.model.run(on: $0, where: [.payload("cartId"): .bound(cartId)]) },
            then: [itemId: Slice.Item(cartId: cartId, itemId: itemId, productId: itemId, description: "Shoes",
                                      image: "", price: Decimal(string: "59.95")!, totalPrice: Decimal(string: "59.95")!)])
    }
}
```

**A persisted view** is tested with `gt`, which starts the view on a fresh store, appends `given`, waits
until the view has committed it, and then checks `then`. The accumulator is fresh per test, on the database
of a fresh in-memory system (which has the slice's tables):

```swift
@Test func findsProductsByName() async throws {
    let system = try await AppSystem.inMemory()
    try await gt(
        view: Slice.view,
        accumulator: try GRDBAccumulator(name: Slice.name, writer: system.database),
        given: [ProductAdded(productId: id, name: "Shoes", price: Decimal(string: "59.95")!)],
        then: { _ in try await system.database.read { try Slice.search($0, text: "sho") }.map(\.name) == ["Shoes"] })
}
```

### Snapshot tests of the screen

Every screen gets snapshot tests, on an iPhone and an iPad (`Tests/AppCoreTests/Support/Snapshots.swift`):
one for an empty read model and one per specification of the read model, given its events.

```swift
#if canImport(UIKit)
extension CartItemsTests {
    @Test @MainActor func screenWithAnItem() async throws {
        let system = try await AppSystem.inMemory(given: [/* the specification's given events */])
        let live = LiveValue(system, Slice.model, where: [.payload("cartId"): .bound(cartId)])
        await live.refresh()
        assertScreenSnapshots(of: Slice.Screen(system: system, cartId: cartId, live: live), system: system,
                              named: "one-item")
    }
}
#endif
```

1. The first run records the images under `__Snapshots__/` and fails. **Look at every recorded image**
   (iPhone and iPad).
2. Compare it with the board's screen (its fields, its `html`/sketch content) and, if the project provides
   them (see the README), the Figma frame of the screen. Judge whether it is close enough by eye: same
   content, same structure, styling as the project's `CLAUDE.md` says.
3. Fix the screen, delete the image, and run again to record it anew. Repeat until it is right.
4. Commit the images with the slice.

Use fixed ids, values and dates in snapshot tests, so the images don't change between runs.

## Quality gate

Before marking this slice as `Done`, verify the implementation against slice.json:

- [ ] Every field of the read model in slice.json is in its state (or what the persisted view's queries return) — no invented fields
- [ ] Every INBOUND event of the read model has exactly one binding — no events missed or assumed
- [ ] A persisted view is used only when step 3.0 calls for it; its reducers only return operations; its table is a registered migration
- [ ] Every GWT scenario in `specifications[]` has a corresponding `@Test`
- [ ] No extra filters or query logic beyond what slice.json defines
- [ ] If there is a screen: it shows the screen's fields, has a form for every command on the read model's screens, sends them by name, and shows their errors
- [ ] If there is a screen: navigation after each command follows its `navigation.json`, and every alternative's condition is traceable to the board
- [ ] If there is a screen: it is registered as `{context}/{slice}` with its parameters, `uses` lists every command and screen it refers to, and it has a `#Preview`
- [ ] If there is a screen: its snapshot images were recorded, looked at, and compared with the board's screen
- [ ] The slice doesn't refer to any other slice's types, and `Slices.swift` calls its `register(in:)` (if it has one)
- [ ] The slice's own tests pass: `scripts/test.sh --only AppCoreTests/{Slice}Tests`
