// Extracts the design tokens of the Figma file as JSON. Read-only.
//
// This is NOT a Node script: it is the body of a Figma Plugin API call, with top-level `await` and `return`.
// Run it with the Figma MCP's `use_figma` tool (Claude Code does this for you, see scripts/README-tokens.md),
// then save the returned value as design/tokens.json. `scripts/generate-tokens.mjs` turns that file into Swift.
//
// Output is deterministic: sorted keys, 8-bit colours, numbers rounded to 2 decimals, no timestamps.

// Which variable collections are design tokens. The others in the file are documentation or prototype wiring.
const COLOR_COLLECTIONS = ['Colors']

const round = (n) => Math.round(n * 100) / 100
const byte = (n) => Math.round(n * 255)
const hex = (c) => {
  const h = (n) => byte(n).toString(16).padStart(2, '0').toUpperCase()
  const rgb = `#${h(c.r)}${h(c.g)}${h(c.b)}`
  return c.a === undefined || byte(c.a) === 255 ? rgb : rgb + h(c.a)
}
const sorted = (o) => Object.fromEntries(Object.entries(o).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))

const collections = await figma.variables.getLocalVariableCollectionsAsync()
const colors = {}
const modeNames = new Set()

for (const c of collections.filter((c) => COLOR_COLLECTIONS.includes(c.name))) {
  for (const id of c.variableIds) {
    const v = await figma.variables.getVariableByIdAsync(id)
    if (v.resolvedType !== 'COLOR') continue
    const values = {}
    for (const m of c.modes) {
      modeNames.add(m.name)
      const val = v.valuesByMode[m.modeId]
      if (val && val.type === 'VARIABLE_ALIAS') {
        const target = await figma.variables.getVariableByIdAsync(val.id)
        values[m.name] = { alias: target.name }
      } else {
        values[m.name] = hex(val)
      }
    }
    colors[v.name] = { values: sorted(values) }
  }
}

const typography = {}
for (const s of await figma.getLocalTextStylesAsync()) {
  const lh = s.lineHeight
  const ls = s.letterSpacing
  typography[s.name] = {
    family: s.fontName.family,
    style: s.fontName.style,
    weight: s.fontName.variationSettings ? s.fontName.variationSettings.wght : null,
    size: round(s.fontSize),
    // PIXELS only; a PERCENT or AUTO line height is kept as-is so the generator can decide.
    lineHeight: lh.unit === 'PIXELS' ? round(lh.value) : lh.unit === 'AUTO' ? 'auto' : { unit: lh.unit, value: round(lh.value) },
    letterSpacing: ls.unit === 'PIXELS' ? round(ls.value) : { unit: ls.unit, value: round(ls.value) },
  }
}

return {
  modes: [...modeNames].sort(),
  colors: sorted(colors),
  typography: sorted(typography),
}
