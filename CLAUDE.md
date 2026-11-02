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
- Buttons use the shared components in the same folder (Figma "Button" page), not a bare `Button` with
  hand-made styling:
  - `AppButton(title, systemImage:, kind:, fillsWidth:)`: capsule button. `kind` is `.primary` (dark),
    `.accent` (dark, accent label) or `.glass` (light, translucent, e.g. Login). `fillsWidth: true` is the
    full-width "Enter" button. Disabled is `.disabled(...)`; the grey look is automatic.
  - `AppIconButton(systemImage:, label:)`: round icon-only button (`label` is the accessibility label).
  - `AppButtonStyle` is the style behind them, for a `Button` that needs custom content.
- Progress uses `AppProgressBar` (Figma "Progressbar" page): `AppProgressBar(completed:of:label:)`, e.g.
  `AppProgressBar(completed: 2, of: 3, label: "materials received")`, or `AppProgressBar(value:label:)`.
  Rules: determinate and linear only; the count is in the label and the percentage at the right end;
  place it below the list title and above the list it summarises; keep it visible while the list is
  processed (it is the user's checklist, not a loading state); update it per receipt; fill the container.
- Receiving a material uses `ReceiveMaterialForm` (Figma "Receive Material"): tracking tag, material and
  expected quantity, received-quantity and batch/serial fields with a scan button (shelf-life materials
  also an expiry date), and a Receive button that is enabled when every field the `MaterialTracking`
  (`.batched`, `.serialized`, `.shelfLife`) asks for is filled. It stacks on a narrow screen.
- Notifications use `AppNotification` / `.appNotification($content)` (Figma "Notification"): brief,
  non-blocking feedback only ("All materials received"), never for a decision or anything destructive
  (use an alert). Set `AppNotificationContent(title:message:systemImage:)` on a binding and the modifier
  shows it centred at the top, 8 pt below the status bar and above everything, then dismisses it. Titles
  under about four words, one-sentence messages. `stackedBehind:` only illustrates a notification history.
- Screen headings, navigation, scan and search use `AppToolbar` (Figma "Toolbar"): pick the preset by
  screen type — `.overview` / `.overviewInline` (heading and search), `.detailSearch` (back, header and
  subheader, scanner, search) or `.detail` (back and header/subheader, no scanner or search). Pass
  `tabs: AppToolbarTabs(...)` when the sidebar is collapsed (Tabs=On) and nothing when it is expanded
  (Tabs=Off). Give it a clear title/subtitle, relevant actions only, and the full container width.
- Navigation between the app's main areas uses `AppSidebar` (Figma "Sidebar"): `AppSidebarSection` /
  `AppSidebarItem` with a `selection` binding. It is the navigation column, not full-screen content: give it
  its column width (e.g. in a `NavigationSplitView`) and let the content fill the rest. Use the approved
  destinations (Goods Receipt, Put Away, Stock Overview, Goods Movement, Pick & Pack) in that order, mark
  the current destination as selected, keep it consistent with the toolbar tabs (expanded sidebar =
  `Tabs=Off`, collapsed = `Tabs=On`), and remove placeholder labels. Titled sections are expandable.
- Settings- and form-like tables use `AppGroupedTable` with `AppTableRow` (title, optional subtitle and
  leading image, trailing control such as `AppTableDetail`, `Toggle`, `Stepper`, `DatePicker` or a `Menu`),
  `AppTableActionRow` ("Row - Button"), `AppSectionTitle` and `AppSegmentedControl` (Figma "Table" page).
  Use native controls for the trailing part. For columns of records use `ListTable`, not these.
- `design/tokens.json` and `DesignTokens.generated.swift` are generated from Figma. Never edit them by
  hand. If a token is missing, add it in Figma and re-run the pipeline in `scripts/README-tokens.md`,
  instead of adding a local constant.
- Not covered by tokens yet: spacing, corner radius, effects, dark mode. Until they exist, use system
  defaults rather than inventing values.
