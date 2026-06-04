# TODO 2: Hierarchical section model in glossarist-js

## Summary
Section model supports `children` array for hierarchical nesting (e.g., IEV part > section). Register.sectionById searches recursively through children.

## Status: DONE

## Changes made
- `glossarist-js/src/models/section.js` — added `children`, `descendantById()`
- `glossarist-js/src/models/register.js` — `sectionById()` recursive search
- `glossarist-js/src/models/index.d.ts` — TypeScript declarations for children
- `glossarist-js/test/models/register.test.js` — 4 new tests for hierarchical sections
- All 381 tests pass

## Model
```yaml
sections:
  - id: "102"
    names: { eng: "Mathematics" }
    children:
      - id: "102-01"
        names: { eng: "Sets and operations" }
      - id: "102-02"
        names: { eng: "Numbers" }
```

Concepts reference leaf groups only:
```yaml
domains:
  - concept_id: section-102-01
    source: urn:iec:std:iec:60050
    ref_type: section
```

Parent membership derived from tree structure, not duplicated in concept.
