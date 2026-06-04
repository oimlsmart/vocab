# TODO 9: Semantic concept ordering per ISO 10241-1

## Summary
Add `ordering` field to Register and Section models. Three methods: systematic (tree hierarchy), mixed (pedagogical sequence), alphabetical (by designation). Canonical sequence = natural sort of concept filenames.

## ISO 10241-1 ordering methods

### Systematic
- Tree-based: broader before narrower, top-down left-to-right
- Hierarchy via dot-separated IDs AND explicit `broader`/`narrower` relationships
- Used by VIM, VIML, ISO 34000

### Mixed
- Pedagogical sequence, fundamental → specific
- No strict tree
- Common in legal/regulatory vocabularies

### Alphabetical
- Sorted by preferred designation
- Derived at render time, no storage

## Model
```yaml
# register.yaml
ordering: systematic    # default for entire dataset
sections:
  - id: "3"
    names: { eng: "General" }
    ordering: systematic    # per-section override
```

**Canonical sequence = natural sort of filenames.** For `ordering: systematic`, concept files are already named 1.1, 1.2, 2.1, etc. — natural sort produces the correct systematic order.

For `ordering: mixed`, the filenames still define the intended sequence (3.1, 3.2, 3.2.1, 3.3, ...).

Alphabetical view: derived at render time by sorting index entries by preferred designation.

## Hierarchy (systematic order)
Two representations:
1. **Implicit**: dot-separated IDs (3.6 → 3.6.1, 3.6.2)
2. **Explicit**: `broader`/`narrower` relationships in concept YAML

ISO 34000 already uses both. The explicit form is authoritative.

## Files to modify
- `glossarist-js/src/models/register.js` — add `ordering` field
- `glossarist-js/src/models/section.js` — add `ordering` field
- `concept-browser/scripts/generate-data.mjs` — include ordering in manifest.json
- `concept-browser/src/adapters/types.ts` — add `ordering` to Manifest type
- Concept list view — respect declared ordering
- Add alphabetical view toggle (sort by designation at render time)
- All 8 OIML register.yaml: add `ordering: systematic`
- ISO 34000 register.yaml: add `ordering: systematic`

## Verification
- manifest.json includes `ordering` field
- Concept list follows natural-sort order by default
- Alphabetical toggle sorts by preferred designation
- `broader`/`narrower` edges show in graph view
