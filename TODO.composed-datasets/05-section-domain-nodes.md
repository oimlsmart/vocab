# TODO 5: Generate section/domain nodes from register sections

## Summary
Use section definitions in `register.yaml` to generate `domain-nodes.json` with localized section names, stable IDs, and correct ordering.

## Current behavior (replace)
`build-edges.js` extracts domain labels from concept data, slugifies them, loses i18n names and ordering.

## New behavior
1. Read sections from register.yaml
2. Each section: id, localized names, optional ordering
3. Generate domain nodes from sections
4. Concepts reference sections via `domains[].concept_id = "section-5"`
5. Domain URI: `{uriBase}/{registerId}/domain/section-{id}` (stable)

### domain-nodes.json format
```json
{
  "registerId": "vim-2007",
  "domainNodes": [
    {
      "uri": "https://metanorma.github.io/oiml-vocab/vim-2007/domain/section-1",
      "id": "section-1",
      "names": { "eng": "Quantities and units", "fra": "Grandeurs et unités" },
      "conceptCount": 22,
      "order": 1
    }
  ]
}
```

## Concept-browser changes
- `DatasetAdapter.loadDomainNodes()`: use localized names from domain-nodes.json
- Section/domain display uses localized section names based on UI language

## Verification
- domain-nodes.json has correct localized section names
- Concept detail shows correct section name in user's language
