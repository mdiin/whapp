---
name: load-slice
description: Load all slices from the board via the slicedata API and persist them to the .build-kit/.slices/ directory hierarchy (index.json with full definitions, per-slice folders, and navigation.json for state-change slices from the timeline). Returns data for a specific slice by ID or title.
---

# Load Slice

> **Before doing anything else**, invoke the `connect` skill to resolve `TOKEN`, `BOARD_ID`, `ORG_ID`, and `BASE_URL`. Do not proceed until the connect skill has completed.

---

## Step 1 — Parse arguments

From `$ARGUMENTS`, extract:

| Field | How to find it | Default |
|-------|---------------|---------|
| `sliceId` | UUID of the slice (SLICE_BORDER node ID) | optional — prefer over title |
| `sliceTitle` | slice title (case-insensitive match) | optional — used if sliceId missing |

If neither is provided, load and persist all slices without filtering.

---

## Step 2 — Fetch all slices from the slicedata API

Prefer the MCP tool when `mcp__eventmodelers__*` tools are visible in this session:

```
mcp__eventmodelers__list_slices { "boardId": "<BOARD_ID>" }
```

This returns `{ "slices": [ { "id": "...", "title": "...", "status": "..." } ] }` — lighter than the full slicedata payload (no `contextName`/`contextId`/`comments`). If Step 3/4 below need those richer fields for a specific slice, follow up with:

```
mcp__eventmodelers__get_slice_data { "boardId": "<BOARD_ID>", "contextName": "<name>" }
```

This call stays full (no `projection`): Step 3 persists the complete slice object as `slice.json`, which the build skills read fields, specs and comments from. When only one slice is needed, pass `sliceId` as well.

(`get_slice_data` requires a `contextName` or `contextId`. If the context isn't already known, list the context names in one call — `mcp__eventmodelers__get_nodes { "boardId": "<BOARD_ID>", "type": "MODEL_CONTEXT", "projection": "line" }` (only titles needed; a timeline name works as `contextName` too, so fall back to `type: "CHAPTER"` with `projection: "line"` when there are no MODEL_CONTEXT nodes) — then map slices to contexts with `list_slices { "boardId": "<BOARD_ID>", "contextName": "<name>" }` per context. Don't `get_node` each `SLICE_BORDER`.)

**Fallback (no MCP):**

```bash
curl -s \
  -H "x-token: <TOKEN>" \
  -H "x-user-id: load-slice-skill" \
  "<BASE_URL>/api/org/<ORG_ID>/boards/<BOARD_ID>/slicedata/slices"
```

Response shape: `{ "slices": [ { "id": "...", "title": "...", "status": "...", "contextName": "...", "contextId": "...", "comments": ["..."], ... } ] }`

Save the full array as `ALL_SLICES`.

---

## Step 3 — Persist slices to .build-kit/.slices/ directory

Apply the following logic for every slice in `ALL_SLICES`.

### Derive paths

- `contextSlug` = slugify `slice.contextName` if present, otherwise `"default"` — lowercase, spaces to hyphens, non-alphanumeric removed (e.g. `"My Ctx"` → `"my-ctx"`)
- `sliceFolder` = `slice.title` lowercased, with all spaces removed and the prefix `"slice:"` stripped  
  e.g. `"Beta Enable User for Beta Test"` → `"betaenableuserforbetatest"`
- `baseFolder` = `.build-kit/.slices/<contextSlug>/`
- `sliceDir`   = `.build-kit/.slices/<contextSlug>/<sliceFolder>/`

### Write files

```bash
mkdir -p ".build-kit/.slices/<contextSlug>/<sliceFolder>"
```

**`.build-kit/.slices/current_context.json`** — always overwrite:

```json
{ "name": "Beta" }
```

**`.build-kit/.slices/<contextSlug>/context.json`** — write once per context:

```json
{ "name": "Beta" }
```

**`.build-kit/.slices/<contextSlug>/<sliceFolder>/slice.json`** — the full slice object with the `index` field removed.

### Maintain `.build-kit/.slices/<contextSlug>/index.json`

Read the file if it exists, otherwise start with `{ "slices": [] }`.

Each entry in `index.json` contains the index metadata **plus** the complete slice definition fetched from the API:

```json
{
  "slices": [
    {
      "id": "d0dbc70c-f244-4048-886b-1d11e461f466",
      "slice": "Beta Enable User for Beta Test",
      "index": 0,
      "contextName": "Beta",
      "contextSlug": "beta",
      "folder": "betaenableuserforbetatest",
      "status": "Created",
      "definition": {
        "id": "d0dbc70c-f244-4048-886b-1d11e461f466",
        "title": "Beta Enable User for Beta Test",
        "status": "Created",
        "contextName": "Beta",
        "contextId": "..."
      }
    }
  ]
}
```

The `definition` field holds the full object returned by the API for that slice (all fields as-is).

**Merge rules:**
- If an entry with the same `id` already exists: update all fields and refresh `definition`; preserve any existing `assigned` field.
- If not found: append the new entry.

Write the updated object back to `.build-kit/.slices/<contextSlug>/index.json`.

---

## Step 3b — Write `navigation.json` for every state-change slice

The app navigates after a command as the board's timeline says: to the state-view slice(s) to the right
of the command's state-change slice. The build skills only read local files, so work that out here, for
every slice with `sliceType` `"STATE_CHANGE"` in the contexts just persisted, and write it to
`.build-kit/.slices/<contextSlug>/<sliceFolder>/navigation.json`. Skip this step if the board isn't
reachable (no MCP and no credentials).

### Find each slice's timeline and its order

1. **The slices' elements**, once per context: `mcp__eventmodelers__get_slice_data { "boardId": "<BOARD_ID>",
   "contextName": "<name>", "projection": "outline" }` — every slice with its elements as `{id, title, type}`.
2. **The timeline of a slice**: its `SLICE_BORDER` node's `parentId` is its timeline (chapter):
   `mcp__eventmodelers__get_nodes { "boardId": "<BOARD_ID>", "nodeIds": ["<sliceId>", ...] }` (one call for
   all slices of the context).
3. **The order on a timeline**, once per timeline: `mcp__eventmodelers__get_board_outline { "boardId":
   "<BOARD_ID>", "chapterId": "<timelineId>" }` — its columns in order, with the nodes in each column and the
   column's `sliceStatus`. A slice is at the first column that holds one of its elements. That gives the
   timeline's slices in order, each with its `sliceType` and `status`.

### Work out the destinations of a state-change slice S

- Walk right from S on its timeline. **Skip automation and translation slices** (any number of them).
  Collect the **state-view slices** that follow, up to the next state-change slice or the end of the
  timeline. Those are the destinations; several are alternatives (the build skill works out which applies
  when).
- A destination with status **`Informational`** is a copy of an earlier screen that only tells the story.
  Find its **original**: a non-informational state-view slice to the left of it on the same timeline whose
  read model has the same title (case-insensitive); failing that, the same set of field names. If the copy
  carries `meta.linkedTo`, its original is that node's slice. If no original is found, add the destination
  to `unresolved` instead.
- **The screen** of a destination is the route name of the slice that builds it: `{context}/{slice}`, the
  context and slice title kebab-cased (for an informational one, its original's).

### Write the file

```json
{
  "command": "Remove Item",
  "slice": "Remove Item",
  "timeline": "Shopping",
  "destinations": [
    {
      "slice": "Cart Items",
      "status": "Informational",
      "informational": true,
      "originalSlice": "Cart Items",
      "readmodel": "cart items",
      "screen": "understanding-eventsourcing/cart-items"
    }
  ],
  "unresolved": []
}
```

- `destinations` keeps the timeline's order. Empty if nothing follows (the app then stays on the screen).
- `unresolved` lists informational destinations without an original: `{ "slice": "...", "reason": "..." }`.
- A slice that isn't on any timeline gets `{ "command": "...", "destinations": [], "unresolved": [],
  "timeline": null }`.

Always overwrite the file: the board is the source of truth.

---

## Step 4 — Return the requested slice

If `sliceId` was given: find the entry in `ALL_SLICES` where `id === sliceId`.  
If `sliceTitle` was given: find the entry where `title` matches case-insensitively.  
If neither: return all slices.

If a specific slice was requested but not found, stop and list the available titles.

---

## Step 5 — Output

```
Slices loaded: <count> total
Persisted to: .build-kit/.slices/<contextSlug>/

Requested slice:
  Title:  <title>
  ID:     <id>
  Status: <status>
  Folder: .build-kit/.slices/<contextSlug>/<sliceFolder>/slice.json
```

Or if no filter was given:

```
All slices (<count>) — context: <contextSlug>:
  - <title> [<status>] → .build-kit/.slices/<contextSlug>/<sliceFolder>/
  - ...
```

Make the matched slice's `id`, `title`, `status`, and local folder path available to subsequent steps in the same session.
