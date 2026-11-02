# Design tokens

```
Figma file ──(1) extract──▶ design/tokens.json ──(2) generate──▶ AppCore/.../Common/UI/DesignTokens.generated.swift
```

Both outputs are committed. Never edit them by hand.

## 1. Extract (needs Figma, run when the design changes)

`scripts/figma/extract-tokens.js` is a Figma Plugin API snippet, not a Node script. Ask Claude Code to run it
with the Figma MCP's `use_figma` tool on the TSS Warehouse App file (key `GIB7NCSxaFs5r587ZMeExM`), and to save
the returned JSON, pretty-printed (2 spaces, trailing newline), as `design/tokens.json`.

Which variable collections count as tokens is the `COLOR_COLLECTIONS` list at the top of the snippet. Text
styles are all taken. The output is sorted and has no timestamps, so an unchanged design gives an unchanged
file, and a `git diff` of `design/tokens.json` is the review of a design change.

## 2. Generate (offline, deterministic)

```
node scripts/generate-tokens.mjs           # write the Swift file
node scripts/generate-tokens.mjs --check   # exit 1 if it is stale (use in CI)
```

- Colours become `AppColor.<name>`. With a `Dark` mode in the tokens they become light/dark adaptive.
- Text styles become `AppFont.<name>`, mapped to the system text styles (Dynamic Type). The generator fails
  if Figma's size differs from iOS's for that style, so deviations are a conscious decision.
- Names that collide after conversion to Swift identifiers fail the run.

Not covered yet: spacing and corner radius (no token collections for them in the file), effects (none defined).
