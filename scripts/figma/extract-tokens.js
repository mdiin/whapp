// Extracts the design tokens of the Figma file as JSON. Read-only.
//
// This is NOT a Node script: it is the body of a Figma Plugin API call, with top-level `await` and `return`.
// Run it with the Figma MCP's `use_figma` tool (Claude Code does this for you, see scripts/README-tokens.md),
// then save the returned value as design/tokens.json. `scripts/generate-tokens.mjs` turns that file into Swift.
//
// Output is deterministic: sorted keys, 8-bit colours, numbers rounded to 2 decimals, no timestamps.
// Designers own the tokens. Whatever is inconsistent in Figma is reported under `issues`, never fixed here.

// Where the tokens live in the Figma file.
const COLORS_PAGE = '10001:193' // page "Colors"
const COLORS_SECTION = '4853:17840' // its swatch section: every variable bound there is a colour token
const TYPOGRAPHY_PAGE = '10114:81519' // page "Typografi": its text nodes use the text styles
const COLOR_COLLECTIONS = ['Colors'] // local collections taken in full, on top of the swatches' variables

const round = (n) => Math.round(n * 100) / 100
const byte = (n) => Math.round(n * 255)
const hex = (c, a) => {
  const h = (n) => byte(n).toString(16).padStart(2, '0').toUpperCase()
  const rgb = `#${h(c.r)}${h(c.g)}${h(c.b)}`
  return a === undefined || byte(a) === 255 ? rgb : rgb + h(a)
}
const sorted = (o) => Object.fromEntries(Object.entries(o).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
const issues = []

// ---- Colours ----------------------------------------------------------------------------------------------

const variableIds = new Set()
for (const c of await figma.variables.getLocalVariableCollectionsAsync()) {
  if (COLOR_COLLECTIONS.includes(c.name)) c.variableIds.forEach((id) => variableIds.add(id))
}

const colorsPage = await figma.getNodeByIdAsync(COLORS_PAGE)
await colorsPage.loadAsync()
const section = await figma.getNodeByIdAsync(COLORS_SECTION)
for (const r of section.findAllWithCriteria({ types: ['RECTANGLE'] })) {
  const fill = Array.isArray(r.fills) ? r.fills.find((f) => f.visible !== false && f.type === 'SOLID') : null
  if (!fill) continue
  const bound = r.boundVariables && r.boundVariables.fills && r.boundVariables.fills[0]
  if (bound) {
    variableIds.add(bound.id)
  } else {
    // The label is the first text in the swatch's frame.
    let p = r.parent, label = null
    while (p && p.id !== section.id && !label) {
      label = p.findAllWithCriteria({ types: ['TEXT'] })[0] || null
      p = p.parent
    }
    const name = label ? label.characters.replace(/\s*\n\s*/g, ' ').trim() : r.id
    issues.push(`Colors: swatch "${name}" (${r.id}) is ${hex(fill.color, fill.opacity)} but not bound to a variable, so it is not a token.`)
  }
}

const colors = {}
const modeNames = new Set()
for (const id of variableIds) {
  const v = await figma.variables.getVariableByIdAsync(id)
  if (!v || v.resolvedType !== 'COLOR') continue
  const collection = await figma.variables.getVariableCollectionByIdAsync(v.variableCollectionId)
  const values = {}
  for (const m of collection.modes) {
    modeNames.add(m.name)
    const val = v.valuesByMode[m.modeId]
    if (val && val.type === 'VARIABLE_ALIAS') {
      const target = await figma.variables.getVariableByIdAsync(val.id)
      values[m.name] = { alias: target.name }
    } else {
      values[m.name] = hex(val, val.a)
    }
  }
  if (colors[v.name]) {
    issues.push(`Colors: more than one variable is named "${v.name}" (collections "${colors[v.name].collection}" and "${collection.name}"); only the first is kept.`)
    continue
  }
  colors[v.name] = { collection: collection.name, values: sorted(values) }
}

// ---- Typography -------------------------------------------------------------------------------------------

const typographyPage = await figma.getNodeByIdAsync(TYPOGRAPHY_PAGE)
await typographyPage.loadAsync()
const typography = {}
for (const t of typographyPage.findAllWithCriteria({ types: ['TEXT'] })) {
  if (typeof t.textStyleId !== 'string' || !t.textStyleId || typeof t.fontName === 'symbol') continue
  const s = await figma.getStyleByIdAsync(t.textStyleId)
  if (!s || typography[s.name]) continue
  const lh = t.lineHeight
  const ls = t.letterSpacing
  const italic = /italic/i.test(t.fontName.style)
  if (italic !== /italic/i.test(s.name)) {
    issues.push(`Typography: "${s.name}" uses the font style "${t.fontName.style}", which does not match its name.`)
  }
  typography[s.name] = {
    family: t.fontName.family,
    style: t.fontName.style,
    weight: t.fontName.variationSettings ? Math.round(t.fontName.variationSettings.wght) : null,
    italic,
    size: round(t.fontSize),
    // PIXELS only; a PERCENT or AUTO line height is kept as-is so the generator can decide.
    lineHeight: lh.unit === 'PIXELS' ? round(lh.value) : lh.unit === 'AUTO' ? 'auto' : { unit: lh.unit, value: round(lh.value) },
    letterSpacing: ls.unit === 'PIXELS' ? round(ls.value) : { unit: ls.unit, value: round(ls.value) },
  }
}

return {
  modes: [...modeNames].sort(),
  colors: sorted(colors),
  typography: sorted(typography),
  issues: issues.sort(),
}
