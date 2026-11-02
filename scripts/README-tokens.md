# Design tokens

```
Figma file ──(1) extract──▶ design/tokens.json ──(2) generate──▶ AppCore/.../Common/UI/DesignTokens.generated.swift
```

Both outputs are committed. Never edit them by hand. **Designers own the tokens in Figma**: there are no
hand-maintained values here, so there is one source of truth. If a token is missing or wrong, it is fixed in
Figma and the pipeline is run again.

## 1. Extract (needs Figma, run when the design changes)

`scripts/figma/extract-tokens.js` is a Figma Plugin API snippet, not a Node script. Ask Claude Code to run it
with the Figma MCP's `use_figma` tool on the TSS Warehouse App file (key `GIB7NCSxaFs5r587ZMeExM`), and to save
the returned JSON, pretty-printed (2 spaces, trailing newline), as `design/tokens.json`.

Where the tokens come from (node ids are constants at the top of the snippet):

- **Colours**: every variable in the local `Colors` collection, plus every variable bound to a swatch in the
  Colors page's "Colors" section. Some of those live in a library collection called "Variable collection";
  `tokens.json` records each token's collection and its own modes (`Light`, `Mode 1`, ...).
- **Typography**: the text styles used by the text nodes on the "Typografi" page.
- **Spacing, corner radius, effects**: not extracted. Figma has no tokens for them yet (the Spacing page is
  a screenshot of general guidance). When the designers add variables, extend the snippet.

The output is sorted and has no timestamps, so an unchanged design gives an unchanged file, and a `git diff`
of `design/tokens.json` is the review of a design change.

Inconsistencies in Figma are never fixed here. They are listed under `issues` in `tokens.json` (for example a
colour swatch that is not bound to a variable, or a text style whose font does not match its name), and the
generator prints them as warnings. Send them to the designers.

## 2. Generate (offline, deterministic)

```
node scripts/generate-tokens.mjs           # write the Swift file
node scripts/generate-tokens.mjs --check   # exit 1 if it is stale (use in CI)
```

- Colours become `AppColor.<name>`. A token with a `Dark` mode becomes light/dark adaptive; one with only
  one mode is used as the light value.
- Text styles become `AppFont.<name>` (`AppFont.bodyEmphasized`, `AppFont.largeTitleRegular`), mapped to the
  system text styles so they follow Dynamic Type, with `.italic()` where Figma's font is italic. The generator
  fails if Figma's size differs from iOS's for that style, so deviations are a conscious decision.
- Names that collide after conversion to Swift identifiers fail the run.
- Names are generated from Figma's as they are, typos included (`AppFont.subheadlineEmphaizedItalic`). Fix
  them in Figma, not here.
