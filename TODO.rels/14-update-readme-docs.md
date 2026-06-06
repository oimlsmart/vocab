# TODO 14: Update concept-model README docs

**Status:** DONE

## What was done

1. Updated `README.adoc` "Relationship Types (32)" → "Relationship Types (52)"
2. Added ISO 19135 to standards list
3. Expanded relationship types table from 9 to 12 categories with all 52 types
4. Added "Cross-dataset navigation" section with URN-based ref.source/ref.id YAML example
5. Added "Supersession chains" section explaining forward-author/derive-inverse pattern

## Why

The README documented 32 types but the schema now defines 52. The cross-dataset navigation pattern (URN resolution) and supersession chain architecture were undocumented.

## Files changed

- `concept-model/README.adoc` — expanded relationship types, added cross-dataset sections
- `concept-model/ontologies/README.md` — "32 relationship types" → "52 relationship types"
