# Project Configuration

This project can have more than one eventmodelers agent kit installed at once — typically
one backend stack plus the modeling kit, working side by side on the same board. Each
installed kit ships its own CLAUDE.md with that kit's own responsibilities. Check which
of these exist in this project and read whichever are present, following all of them
together:

- `.build-kit/CLAUDE.md` — building this project's backend from board slices
- `.agent-modeling-kit/CLAUDE.md` — designing and updating the event model board itself

Neither is guaranteed to exist — this file is installed once, up front, before either kit
is known to be present.

`.agent-modeling-kit/CLAUDE-STANDALONE.md` is deliberately *not* in that list: it holds the
rules for the self-directed turns a `run --standalone` session gets, and the agent in such a
session reads it itself when the first one arrives. Leave it alone otherwise — it licenses
work nobody asked for, which is right for those turns and wrong everywhere else.

## Design system

- Screens use the design tokens: `AppColor.*` for colours and `AppFont.*` for text styles
  (`AppCore/Sources/AppCore/Common/UI/DesignTokens.generated.swift`). No literal colours (`Color(red:)`,
  hex values) and no fixed font sizes in slice code.
- Lists use the shared components in `AppCore/Sources/AppCore/Common/UI/Components/` (from the Figma
  "List" page). Use them instead of building a `List`/`ForEach` layout by hand, and never edit them
  while building a slice:
  - `ListTable` + `ListTableColumn`: multi-column table (text columns leading, number columns trailing).
  - `TaggedList` + `TaggedListItem` + `ListTag`: rows with image, title, subtitle, tag, detail, chevron.
    `ListRowButtonStyle` gives the neutral pressed highlight (never a persistent selection).
  - `ListHeader` (title, optional count badge, optional trailing segmented control) and
    `ListLargeTitleHeader` (large title, optional subtitle).
  - Rules: keep each process's lists separate; columns stay aligned; IDs and units are exact; lists fill
    their container; no clipped critical data.
- `design/tokens.json` and `DesignTokens.generated.swift` are generated from Figma. Never edit them by
  hand. If a token is missing, add it in Figma and re-run the pipeline in `scripts/README-tokens.md`,
  instead of adding a local constant.
- Not covered by tokens yet: spacing, corner radius, effects, dark mode. Until they exist, use system
  defaults rather than inventing values.
