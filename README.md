# SwiftUI + ledjer-swift starter

A minimal project for event-sourced iOS apps (iPhone and iPad, iOS 18): SwiftUI for screens, and
[ledjer-swift](https://github.com/planmdk/ledjer-swift) for events, read models, persisted views and
automations, with the events in an on-device SQLite database ([GRDB](https://github.com/groue/GRDB.swift)).
The app is offline-first: the events live on the device. It is ready for the `build-state-change`,
`build-state-view` and `build-automation` skills in `.claude/skills/` to generate slices into.

No slices are included: each one is generated from a board's `slice.json`.

## Before you start

1. **Name the app.** In `Config/Base.xcconfig`, set `PRODUCT_NAME` and `PRODUCT_BUNDLE_IDENTIFIER` (and
   `DEVELOPMENT_TEAM` to run on a device). The project file needs no renaming.
2. **Install the tools.** Xcode 16 or later with an iOS 18 simulator, and `mise install` for Node (the
   `.build-kit` runtime needs it).
3. **Pick the simulator.** `scripts/test.sh` runs everything on `iPhone 16`. If your Xcode doesn't have it,
   set `SIMULATOR` to one it has (`xcrun simctl list devices available`), and change the default in the
   script: screen snapshots are recorded on that simulator and only compare equal on it.
4. **Describe the design system** in the project's `CLAUDE.md` before building screens (see "Styling").

## Running and testing

Open `App.xcodeproj` in Xcode and run the `App` scheme. From the command line:

```bash
scripts/test.sh                              # AppCore's tests (incl. snapshots), then a build of the app
scripts/test.sh --only AppCoreTests/AddItemTests   # one test suite (a @Suite type's name)
scripts/test.sh --app                        # only build the app
```

Without slices, the app shows an empty "Screens" catalog. That is expected.

`scripts/swift-linux.sh test` runs `AppCore`'s tests in a Linux container (podman), for working on the
scaffold without a Mac. Only the UI-free code builds there; SwiftUI code is behind `#if canImport(SwiftUI)`.

## What's here

```
App.xcodeproj               the app target: synchronized folders, so new files never need project edits
App/                        the app target's sources: only MainApp.swift (and assets)
Config/                     Base/Debug/Release.xcconfig, Info.plist (the AppConfig dictionary)
AppCore/                    a local Swift package with everything else, in one module
├── Sources/AppCore/
│   ├── Common/             the scaffold: composition root, lifecycle, registries, read model helpers, UI shell
│   ├── Events/             one file per event, and AllEvents.swift listing them all
│   └── Slices/             one folder per slice; Slices.swift registers them all
└── Tests/AppCoreTests/
    ├── Common/             tests of the scaffold, and SystemTests over every slice
    ├── Support/            assertScreenSnapshots
    └── Slices/             one folder per slice: tests and recorded screen images
scripts/                    test.sh (macOS), swift-linux.sh (Linux)
```

### How it fits together

- **`AppSystem`** is the composition root: the event store, the database, `AppConfig`, and what the slices
  registered. It is built once at launch (`AppSystem.live`); tests and previews build one in memory
  (`AppSystem.inMemory(given:)`). There is no DI framework: dependencies are passed explicitly.
- **Slices register themselves** in `Slices/Slices.swift`, one line each, through their own `register(in:)`:
  commands, screens, automations, persisted views, migrations, configuration keys.
- **Slices never use each other's types.** Screens send commands by name (`system.send("{context}/{slice}", payload)`)
  and navigate to screens by name (`Route("{context}/{slice}", parameters)`). A command or screen whose slice
  isn't built yet shows disabled. The payload is keyed by the board's field names, and decoded into the
  command's own type; what doesn't fit comes back to the form as field errors.
- **`Lifecycle`** starts automations and persisted views when the app becomes active and stops them when it
  goes to the background (`AppRoot` follows the scene phase). Starting waits for the previous stop to finish.
- **Screens follow their read model** with `LiveValue`: a `ReadModel` (a ledjer `StateView`) is read again
  whenever one of its events arrives, a persisted view's tables whenever they change. They pause in the
  background and catch up when the app is active again.
- **`ReadModel`** is a `StateView` that knows its event types, so one definition serves a command's
  consistency check (`decide`: the state plus the append condition), a screen, and an automation's to-do list.

### Events are never migrated

The events on a device are its only data, and they stay there across app updates: every version of the app
must read every event any earlier version wrote. So an event's fields are never changed incompatibly. A
changed event is a new event type, and the read models and handlers handle both the old and the new one.
Adding an optional field is the one compatible change. `AllEvents.swift` lists every event type, and
`SystemTests` checks that no two declare the same `eventType`.

### Dates and time

The app uses the device's time zone. The board's `Date` is a `CalendarDate` (a day, stored as
`yyyy-MM-dd`), never a `Foundation.Date`, so it doesn't move to another day when the time zone changes.
`DateTime` is a `Date`.

## Navigation

The kit navigates **within a timeline**: after a command succeeds, the screen moves to the state view that
follows the command's slice on the board's timeline (`load-slice` writes this to each state-change slice's
`navigation.json`). Informational slices stand for the screen they copy; several views after one command
are alternatives, chosen by a condition the agent works out from the board.

**Everything beyond one timeline is the project's to decide**, in its own `CLAUDE.md` and code. Until then,
`RootView` shows a "Screens" catalog of every registered screen, so each one can be reached.

- **The app's structure.** Replace the catalog in `Common/UI/RootView.swift` with the app's own: a start
  screen, tabs or a sidebar (iOS 18's `TabView` with `.tabViewStyle(.sidebarAdaptable)` gives tabs on iPhone
  and a sidebar on iPad, and `TabSection`s can group them, e.g. per context). Keep the `routeDestinations`
  and the `sheet`: they are how every screen is shown. Reach screens with `system.screen(for: Route(...))`.
- **Links between timelines.** On the board, timeline B continues timeline A when B holds a linked copy
  (`meta.linkedTo`) of an event whose original is in A. Only event copies count. A timeline is the happy
  path; an exceptional event that needs its own user flow starts a new timeline linked that way.
- **Top-level candidates** are the timelines of a context that don't continue another timeline of the same
  context. Which screen each one starts with, how they are grouped and ordered, which is the start screen,
  and how links across contexts count, is the project's decision.
- **Error paths.** Navigating into a continuation timeline after a command needs to know which events the
  command appended. The kit's commands don't report that; a project that wants it extends its commands.
- **Copies that only feed data.** A linked event copy can also exist only to feed a read model, with no
  continuation meant. Telling the two apart is a project convention.
- **Exceptional events appended by automations.** The user may be on any screen when it happens. Whether to
  navigate, show an alert, a badge or a notification, or nothing, is up to the project.

## Configuration

`AppConfig` holds the app's configuration: base URLs, API keys, per build configuration.

1. A slice declares each key it needs: `registry.requireConfig("API_BASE_URL", testValue: "...")`. Tests and
   previews use the test value.
2. `Config/Info.plist` maps the key into the `AppConfig` dictionary: `<key>API_BASE_URL</key><string>$(API_BASE_URL)</string>`.
3. The value is set in `Config/Base.xcconfig`, or per configuration in `Debug.xcconfig`/`Release.xcconfig`.
   **`//` starts a comment in an `.xcconfig` file**: write URLs as `https:/$()/api.example.com`.
4. Secrets go in `Config/Secrets.xcconfig` (copy `Secrets.xcconfig.example`; it is gitignored), which
   Debug and Release include last.

A required key that is missing or empty stops the app at launch with a message naming it. Everything in
`Info.plist` ships inside the app and can be read by anyone who has it: `Secrets.xcconfig` keeps keys out of
the repository, not out of the app. Secrets that must stay secret belong on a server.

## Storage

- **The database** is `Application Support/Database/app.sqlite`: the events (`ledjer_*` tables) and the
  persisted views' read models, in a GRDB `DatabasePool`.
- **Backup.** Application Support is included in iCloud and Finder backups. In an offline-first app the
  events are the only copy of the user's data: keep the database in the backup.
- **File protection** decides when iOS keeps the database files encrypted. The kit uses
  `.completeUntilFirstUserAuthentication` (the iOS default: readable from the first unlock after the device
  starts). For more sensitive data, pass another `DatabaseFileProtection` to `AppSystem.live` in
  `Common/UI/AppRoot.swift`. With `.complete` the files are unreadable while the device is locked, so
  anything running then fails. It covers the `-wal` and `-shm` files too.
- **App groups** (to share data with a widget or an extension) are not set up. A database in a shared
  container has extra rules while the app is suspended: see "Backgrounding on iOS" in ledjer-swift's README.
- **Persisted views' tables** are created by migrations the slices register (`registry.migration`). A shipped
  migration is never changed; a change is a new migration.

## In the background

Automations, persisted views and screens stop while the app is in the background, and start again when it
is active: persisted views resume after their checkpoint, automations process what is still on their to-do
list (`Trigger.onStart`), screens load afresh. Nothing runs while the app is suspended. A project that needs
work done in the background (`BGTaskScheduler`, notifications) adds it itself.

## Screens and snapshots

Every screen has snapshot tests ([swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)),
on an iPhone and an iPad: the first run records the images next to the test, under `__Snapshots__/`, and the
agent looks at them and compares them with the board's screen before committing them.

- **More variants** (dark mode, landscape, larger Dynamic Type): add them in `assertScreenSnapshots`
  (`Tests/AppCoreTests/Support/Snapshots.swift`) — another device such as `.iPadPro11(.landscape)` in
  `snapshotDevices`, a second `.image(on: config, traits: UITraitCollection(userInterfaceStyle: .dark))`
  per device, or the screen wrapped in `.environment(\.dynamicTypeSize, .accessibility2)`. Each variant
  multiplies the images and the agent's time.
- **Figma.** For projects designed in Figma, the agent compares a screen with its Figma frame instead of the
  board's sketch. Make the frames available in one of two ways, and say which in the project's `CLAUDE.md`:
  export each frame as a PNG to `design/{context}/{slice}.png`, or register a Figma MCP server and name the
  file and the page the screens are on. Extracting components and design tokens from Figma into SwiftUI is
  a separate step, outside this kit.
- Snapshot images depend on the simulator and its iOS version: record and compare them on the one
  `scripts/test.sh` uses.

## Styling

There is no design system, on purpose. The build skills style screens as the project's own `CLAUDE.md`
says, so describe the design system there (components, colors, typography, spacing) before building
screens. Without one, screens use plain system controls.

## Users and authentication

Not part of the kit: model them on the board if the app has them. A read model that needs the signed-in
user's id takes it from wherever the project's `CLAUDE.md` says.

## Building slices

The agent runtime in `.build-kit/` reads slices from the board and builds them with the skills.
`.build-kit/CLAUDE.md` has the rules; in short, for each slice it:

- builds it in `AppCore/Sources/AppCore/Slices/{Context}/{Slice}/`, with its tests, and adds its events to
  `Events/` and `AllEvents.swift`;
- registers it in `Slices/Slices.swift`;
- runs the slice's tests (recording and checking screen snapshots), builds the app, and runs the full suite.

Everything the skills assume exists is in `Common/`. Slices do not change it.
