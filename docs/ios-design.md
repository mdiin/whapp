# iOS build kit — design decisions

This kit is being rewritten from Clojure (Pedestal, donut.system, ledjer) to Swift (SwiftUI,
ledjer-swift with its GRDB event store). This document records the decisions made before the rewrite.
It is the reference for the scaffold, the skills and the prompt.

The kit is *authored* on Linux (only the UI-free Swift code can be verified there, in a `swift`
container) and *run* on macOS with Xcode and the iOS simulator available.

## Scope

| Topic | Decision |
|---|---|
| Rewritten | The scaffold, the skills (`build-state-change`, `build-state-view`, `build-automation`, and `load-slice` for the navigation data within the slice's timeline), and the prompt. The Node `.build-kit` runtime stays as it is. |
| Devices | iPhone and iPad, iOS 26 minimum |
| Data | Offline-first: the events are on the device (ledjer-swift + GRDB). Sync with a server is project-specific, not part of the kit. |
| Users, authentication, authorization | Project-specific, not part of the kit |
| App groups (widgets, extensions) | Project-specific, not part of the kit |
| Styling | Project-specific: the project's `CLAUDE.md` describes the design system. For Figma projects, a separate step outside the kit extracts components and design tokens into SwiftUI. |

## Project layout

- An Xcode app target using **synchronized folders** (Xcode 16 `PBXFileSystemSynchronizedRootGroup`), so
  new files never require editing `.pbxproj`. The app target is a thin shell: `@main App`, `Info.plist`,
  `.xcconfig` files, and assets.
- A **local SwiftPM package `AppCore`** with a **single module**, which holds everything else. It doesn't
  isolate slices from each other, but `Package.swift` never changes per slice.

```
AppCore/Sources/AppCore/
  Common/                         AppSystem, lifecycle, registries, state-view helper, AppConfig
  Events/                         one file per event + AllEvents (like events.clj)
  Slices/{Context}/{Slice}/       everything of one slice
AppCore/Tests/AppCoreTests/
  Common/                         registry uniqueness, AllEvents uniqueness, link resolution
  Slices/{Context}/{Slice}/       gwt/gt tests, snapshot tests, __Snapshots__/
```

SwiftPM requires tests in their own target, so a slice spans the two `Slices/{Context}/{Slice}/`
directories.

## Dependency injection and lifecycle

- **A hand-written composition root**, `AppSystem`. It builds the `DatabasePool`, the event store,
  `AppConfig`, the live service implementations, persisted views and automations, and passes them on
  through initialisers. Tests and previews build an `AppSystem` on an in-memory store; that replaces
  the `:test` profile.
- **SwiftUI `@Environment`** is used only at the UI edge, to hand the system's pieces to screens.
- **Lifecycle** takes over the start/stop role of donut: a `@MainActor` coordinator in `Common/`,
  driven by `scenePhase`, following the start/stop ordering in ledjer-swift's README (start waits for
  the previous stop to finish). It stops automations, persisted views *and* screen subscriptions in
  the background, and starts them again when the app becomes active. Slices register with it and never
  write lifecycle code themselves.
- Swift has no load-time side effects, so "registered in the slice's file" means the slice declares a
  `register(in:)` function in its own file, and `AppSystem` calls it. That one line in a shared file
  is the counterpart of adding to `system.clj` today.

## Slices

### State change: command → events

- The slice's file holds the command (a `Codable` struct of the board's fields), its handler (an `async`
  function of the event store and the command that sources events, decides, and appends with an
  `AppendCondition`), and its registration in the **command registry**.
- It has no UI. It is tested with `gwt(given:when:then:)`, one test per board specification.

### State view: events → read model → screen

- The slice's file holds the read model (`StateView`, or `PersistedStateView` with a `GRDBAccumulator`),
  the SwiftUI screen, its registration in the **route registry**, and a `#Preview` on an in-memory store.
- The screen subscribes to the events of its read model's query through a shared helper in `Common/`
  and runs the view again when they change. The helper pauses in the background and catches up on
  resume.
- Forms on the screen send commands **through the command registry by name**, never by calling another
  slice directly.

### Automation

- Same pattern as today, on ledjer-swift's `automation(on:triggers:onError:body:)`, registered with the
  lifecycle coordinator.
- External services (HTTP, or on-device frameworks such as notifications) are behind **protocols
  defined inside the slice directory**, with the live implementation next to them. Two slices calling
  the same API each define their own protocol. HTTP uses `URLSession` with `async`/`await` and `Codable`.
  Tests pass fakes.

### Decoupling: registries instead of direct references

Slices are built in any order, so they never refer to each other's code. This mirrors `url-for-safe`.

- **Command registry**: commands are looked up by name (`{context}/{slicename}`), and the screen builds
  the payload from the board's field names. The command slice decodes the payload into its typed
  command (`Codable`); a payload that doesn't decode becomes a field error, the way malli coercion
  errors do today. A command that isn't registered shows its form disabled.
- **Route registry**: screens are looked up by name with their parameters. A link or navigation target
  that isn't registered shows disabled.
- Neither is checked by the compiler. To make up for it, building the `AppSystem` fails on a name
  registered twice (so `SystemTests` does), and slices declare the names they use
  (`registry.uses(command:from:)`, `uses(route:from:)`). `SystemTests` lists the used names no slice
  registers; that only fails with `APP_STRICT_REFERENCES=1`, since mid-build it is expected.

## Navigation

Navigation comes **entirely from the board's timeline**. There are no screen-to-screen connections, and
no navigation comments.

- A non-informational state-view slice is one screen and one route. Slices with status `Informational`
  are never built; they only tell the story.
- **After a command succeeds**, the destination is chosen from the state-view slices to the right of the
  command's state-change slice, up to the next state change, skipping any automations in between. The
  destination doesn't depend on which events the command appended.
  - **One view** → it is the destination.
  - **Several views** → they are *alternatives*. Each gets a condition on read-model state, which the
    agent works out from the board (screen content, specifications, descriptions). After the command,
    the app goes to the first alternative whose condition holds. If no condition can be worked out, the
    agent asks for feedback (`request-feedback`).
  - **An informational view** stands for its original. The original is found by the read model's title,
    then its fields, and it must be the triggering screen or one earlier on the timeline. If no original
    is found, the agent asks for feedback. If the original is the current screen, the app stays and the
    subscription refreshes the screen.
- **Moving to the destination**: if it is already earlier in the navigation stack, go back to it;
  otherwise push it. A command sent from a sheet closes the sheet first. A command that throws keeps
  the screen where it is and shows the error.
- **Screen parameters** (ids) come from the command's or event's fields of the same name. A parameter
  that can't be resolved is reported as an error, never guessed.
- **`load-slice`** works out the navigation from the slice's own timeline (statuses, informational
  originals, alternatives and their conditions) and writes it next to `slice.json`, so the build skills
  still only read local files.
- **The kit only navigates within one timeline.** Everything that crosses timelines, and the app's
  top-level structure, is project-specific (see "Navigation beyond one timeline" under "Notes for the
  generated README"). The scaffold's `RootView` shows a "Screens" catalog of every registered route, so
  every screen can be reached until the project defines its own structure.

Example (Case A: a checklist with a submit button):

1. State view, 2 items (screen *Checklist*)
2. State change, `ItemChecked`
3. State view, informational, 1 item → *Checklist*
4. State view, 0 items with a submit button (screen *Ready to submit*)
5. State change, `ItemsSubmitted`
6. State view (screen *Submitted*)

After step 2 there are two alternatives: 3 (→ stay on *Checklist*, when items remain) and 4 (→ *Ready to
submit*, when none remain). After step 5 the app goes to *Submitted*.

## Events

- One `struct: Event` per board event, in `Events/`, with tags from the fields where `idAttribute` is true.
- **`AllEvents`** lists every event type, and a test checks that the event types are unique. ledjer-swift
  has no registry, and otherwise only catches duplicates that occur in the same query, view or
  automation.
- **Events are never migrated.** Any incompatible change, and in practice most changes, is a new event
  type. Read models and handlers then deal with both the old and the new type.

### Field types

| slice.json | Swift |
|---|---|
| `String` | `String` |
| `UUID` | `UUID` |
| `Boolean` | `Bool` |
| `Int`, `Integer`, `Long` | `Int` |
| `Double` | `Double` |
| `Decimal` | `Decimal` (exact, for money) |
| `Date` | a calendar date: `"yyyy-MM-dd"` or year/month/day, never a `Date` |
| `DateTime` | `Date`, shown in the **device's time zone** |
| `Custom` | a nested `Codable` struct |
| `cardinality: List` | `[T]`: an array, never a `Set` (`gwt` compares events as JSON) |

## Verification per slice (on macOS)

- `swift test` for `AppCore`'s logic and `xcodebuild test` on a fixed simulator destination (one
  iPhone, one iPad).
- **Swift Testing** for `AppCore`. XCTest only where Swift Testing can't do the job (UI tests, if ever).
- **Screenshots with swift-snapshot-testing**, rendered through `UIHostingController`. For each state
  of a screen on the timeline, the given events are the ones the timeline has produced up to that
  state. Workflow:
  1. record the image;
  2. the agent looks at it and compares it with the Figma frame or the board's screen;
  3. it fixes the screen and records again;
  4. it commits the image.

  "Close enough" is the agent's judgement, not a pixel threshold.
- The reference images depend on the simulator model and iOS version, so the kit fixes both.

## Configuration and storage

- **`AppConfig`**: a typed struct in `AppCore`. The app target builds it from `Info.plist`, which
  `Debug.xcconfig` and `Release.xcconfig` fill. Secrets go in a gitignored `Secrets.xcconfig`. A missing
  key stops the app at launch. Write `//` as `/$()/` in `.xcconfig` URLs. Anything in `Info.plist` ships
  inside the app bundle and can be read from it, so real secrets don't belong there.
- **Database**: a `DatabasePool` in Application Support. File protection defaults to
  `.completeUntilFirstUserAuthentication`, set in one place (it covers the `-wal`/`-shm` files too), and
  a project can change it.

## Notes for the generated README

- **Backup**: Application Support is included in iCloud and Finder backups. In an offline-first app the
  events are the only copy of the user's data, so don't exclude the database from backup.
- **Snapshot variants**: how to add dark mode, landscape or Dynamic Type sizes to the snapshot tests.
- **Figma**: how to provide the reference frames for screenshot comparison (exported files or a Figma MCP
  server).
- The `.xcconfig` `//` problem, and where secrets go.
- File protection, and how to change it.
- Background behaviour: automations, persisted views and subscriptions stop while the app is suspended.

### Navigation beyond one timeline

The kit doesn't build any of this. The README explains the board conventions and how a project can
build on them, in its own `CLAUDE.md` and its own code:

- **Links between timelines.** Timeline B *continues from* timeline A when B contains a linked copy
  (`meta.linkedTo`) of an event whose original is in A. Only event copies count. A timeline is the happy
  path; an exceptional event that needs its own user flow starts a new timeline linked this way.
- **Top-level candidates** are the timelines in a context that don't continue from another timeline in the
  same context. The project decides:
  - each timeline's entry screen;
  - grouping by context (for example iOS 18 `TabSection`s in a `.sidebarAdaptable` `TabView`);
  - the order and the start screen;
  - how links across contexts count.
- **Error paths.** Navigating into a continuation timeline after a command requires knowing which events
  the command appended. Kit commands don't report that, so a project that wants it extends its
  commands.
- **Copies that only feed data.** A linked event copy can also exist just to feed a read model, with no
  continuation meant. Telling the two apart is a project convention.
- **Exceptional events appended by automations.** The user may be on any screen. Whether to navigate, show
  an alert, badge or notification, or do nothing is up to the project.
- **Replacing the catalog.** The project replaces the "Screens" catalog in `RootView` with its own
  structure, using the route registry to reach screens by name.

## Settled during the rewrite

- **Payloads** are `[String: FieldValue]`, where `FieldValue` is a JSON-like enum of the board's field types.
  `PayloadDecoder` decodes a payload into the command's `Codable` struct; a `DecodingError` becomes a
  `CommandInputError` naming the field. `CommandErrors(error)` turns what `AppSystem.send` throws into
  field errors and general errors for the form: `CommandRejected` messages as they are, and a general
  message for anything else (which is reported). Route parameters use the same type and decoding.
- **`ReadModel`** wraps a ledjer `StateView` together with its event types, because `StateView` doesn't
  expose its query. One definition serves a command's consistency check (`decide`: the state, and an append
  condition taken *before* reading, so a concurrent append fails rather than slips by), a screen
  (`LiveValue`), and an automation's to-do list. If ledjer-swift ever makes a view's query public, this
  can shrink to a thin helper.
- **`Trigger.onStart`** fires once when an automation starts. Automations start whenever the app becomes
  active, and event triggers only fire for new events, so every automation has it, to process what is
  still on its to-do list.
- **Lifecycle**: `Lifecycle` starts the components and sets `AppSystem.activity`, which screens follow.
  A component that fails to start is reported, and is started again the next time the app becomes active.
- **`navigation.json`** lists, for a state-change slice, the state-view slices that follow it on the
  timeline (skipping automations), with informational ones resolved to the screen of their original, and
  `unresolved` for those without one. The format is in the `load-slice` skill.
- **Verification on Linux**: `scripts/swift-linux.sh test` builds and tests `AppCore` without its SwiftUI
  code (`#if canImport(SwiftUI)`), including the non-UI code from the skills' examples. The SwiftUI code,
  the snapshot support, the Xcode project and `scripts/test.sh` have not been compiled or run yet: the
  first run on a Mac has to fix whatever they got wrong.
