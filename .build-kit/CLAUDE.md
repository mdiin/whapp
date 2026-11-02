# Project Configuration

This is an event-sourced iOS app (iPhone and iPad, iOS 26): SwiftUI, and
[ledjer-swift](https://github.com/planmdk/ledjer-swift) for events, read models, persisted views and
automations, with the events in an on-device SQLite database (GRDB). Read `README.md` for how the app is
put together, and the events in `AppCore/Sources/AppCore/Events/` to understand the global structure.

## Names

| What | Rule | Example |
|---|---|---|
| `{context}` | the context name, kebab-cased | `understanding-eventsourcing` |
| `{Context}` | the context name, PascalCase | `UnderstandingEventsourcing` |
| `{slice}` | the slice title, kebab-cased | `add-item` |
| `{Slice}` | the slice title, PascalCase | `AddItem` |
| command / screen name | `{context}/{slice}` | `understanding-eventsourcing/add-item` |

Slices refer to each other's commands and screens only by these names, through the registries — never by
their Swift types — so slices can be built in any order.

## File Structure Constraints

- **Strict Path Limitation**: if not instructed otherwise, only check the slice's own directory,
  `AppCore/Sources/AppCore/Slices/{Context}/{Slice}/`, its tests
  `AppCore/Tests/AppCoreTests/Slices/{Context}/{Slice}/`, and the shared files the build skills say to edit:
  `Events/` (one file per event) and `Events/AllEvents.swift`, `Slices/Slices.swift`,
  `Slices/{Context}/{Context}.swift`, and for configuration keys `Config/Info.plist` and `Config/Base.xcconfig`
- **Slice Organization**: Each feature/domain is a separate slice
- `AppCore/Sources/AppCore/Common/` is project code: never change it while building a slice. If a slice
  needs something it doesn't offer, the slice is `Blocked` (`/request-feedback`).
- Never edit `App.xcodeproj`: the app target uses synchronized folders, and everything a slice adds is in the
  `AppCore` package.

## Code Standards

- **Language**: Swift 6 (strict concurrency), SwiftUI for screens
- **Tests**: Swift Testing (`import Testing`, `@Test`), and swift-snapshot-testing for screens

## Development Guidelines

1. Each slice is self-contained and focused on a specific domain
2. Maintain clear separation of concerns within each slice
3. Use ledjer-swift through the scaffold: `ReadModel` for read models, `PersistedStateView` with a
   `GRDBAccumulator` where the build skill calls for it, `automation` for automations, and `gwt`/`gt` for
   the specifications — see each build skill
4. **Events are never migrated.** Never change an existing event's fields incompatibly: a changed event is a
   new event type, and the code that used the old one handles both.

**Time**: the app uses the device's time zone. `Date` fields of the board are `CalendarDate` (a day),
`DateTime` fields are `Date` (a point in time). See "Field types" in the `build-state-change` skill.

Do not change test files unless explicitly instructed, or the change brings the test in line with slice.json (e.g. step 4's field/spec diff).

At the start of every session, read `.build-kit/AGENTS.md` if it exists to load accumulated project learnings.

When starting to work on a slice, invoke the `update-slice-status` skill with `InProgress` status before doing anything else.

## Building a Slice

**CRITICAL: You MUST always use the provided skills to build slices. NEVER implement a slice manually.**
**ALL fields, event names, command names, and business rules MUST come exclusively from slice.json. Do NOT invent, assume, or guess any field or logic not present in the slice definition.**

**Default: make a reasonable assumption and build the slice.** If a detail is unclear or missing (an example value, a field type, a status mapping, a referenced event that isn't modeled yet, ...), pick the most sensible interpretation from `slice.json`, its specifications and the surrounding model, build it, and record each assumption in one line in `progress.txt` and as a code comment. Ambiguity alone is never a reason to stop. **Only if the slice literally cannot be built** — nothing runnable can be produced even with sensible assumptions — invoke `/request-feedback` with the specific question; it posts the question as a comment on the slice and marks it `Blocked`. That must be the absolute exception; a `Blocked` slice should mean "impossible without a human", never "the agent preferred to ask".

When asked to build a slice, always follow this flow:

1. Read the slice definition from `.build-kit/.slices/<context>/<slicename>/slice.json`.
2. Determine the slice type from `sliceType` in slice.json:
   - **Automation** — `"AUTOMATION"` → invoke `/build-automation`
   - **Translation** — `"TRANSLATION"` → read `description` and `notes` from slice.json for hints; default to `/build-automation` if nothing else is specified
   - **State-view** — `"STATE_VIEW"` → invoke `/build-state-view`
   - **State-change** — `"STATE_CHANGE"` → invoke `/build-state-change`
   - **Missing or `"UNDEFINED"`** — fall back on the arrays, in this order:
     - `processors` non-empty → `/build-automation`
     - `readmodels` non-empty and `commands` empty → `/build-state-view`
     - `commands` non-empty → `/build-state-change`
     - anything else (e.g. only `events`, or nothing at all) is a modelling error: invoke `/request-feedback` explaining that the slice has no command, read model or processor to build. Do not write any code for it.
   - A slice with status `Informational` is never built: it only tells the story of the user flow.
3. Invoke the matching skill and follow its instructions completely. Do not deviate.
4. **Verify against slice.json**: After the skill completes, check that every command field, event field, and specification in slice.json appears in the implementation. No invented fields — if it is not in slice.json, it must not be in the code. This applies even when the slice was previously `Done` and reappears as `Planned` — never dismiss a mismatch as "already implemented" or harmless drift; diff slice.json against the code field by field and update the code to match every change.
5. Run the quality checks, in this order:
   1. **The slice's own tests** — `scripts/test.sh --only AppCoreTests/{Slice}Tests` (the `@Suite` type's
      name). They must pass, snapshot tests included, with their images recorded and looked at.
   2. **The app builds** — `scripts/test.sh --app`. This is the only check that covers the app target. It must
      succeed.
   3. **The full suite** — `scripts/test.sh`. It includes `SystemTests`, which load every slice's
      registration together: a name registered twice, or an event type declared twice, fails there. A failure
      is yours only if it is caused by what this slice changed (e.g. an event whose fields changed); fix the
      code, never another slice's test. Any other failure was there before: record it in `progress.txt` and
      leave it alone. Commands and screens used but not yet registered are only listed, not failures.
6. If checks 1 and 2 pass and the full suite has no failures caused by this slice, commit with
   `feat: [Slice Name]` and set slice status to `Done`.

All checks run on the iOS simulator `scripts/test.sh` names; never change it while building a slice
(snapshot images depend on it).

## Example Slice Structure

```
AppCore/Sources/AppCore/
├── Common/                                   ← project code, never changed by a slice: AppSystem, registries, LiveValue, ReadModel, ...
├── Events/
│   ├── AllEvents.swift                       ← every event type is listed here
│   └── {Context}/{EventName}.swift           ← one file per event, shared by all slices
├── Slices/
│   ├── Slices.swift                          ← one line per slice: `{Context}.{Slice}.register(in: &registry)`
│   └── {Context}/
│       ├── {Context}.swift                   ← `enum {Context} {}`
│       └── {Slice}/
│           ├── {Slice}.swift                 ← command and handler, read model, automation, `register(in:)`
│           └── {Slice}Screen.swift           ← the screen and its `#Preview`, for a state view with a screen

AppCore/Tests/AppCoreTests/
├── Common/                                   ← tests of the scaffold, and SystemTests over all slices
├── Support/Snapshots.swift                   ← `assertScreenSnapshots`
└── Slices/{Context}/{Slice}/
    ├── {Slice}Tests.swift
    └── __Snapshots__/                        ← recorded screen images, committed
```
