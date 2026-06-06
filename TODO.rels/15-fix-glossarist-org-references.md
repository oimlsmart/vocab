# TODO 15: Fix glossarist.org stale references

**Status:** DONE

## What was done

1. Updated `06-related-relationships.yaml` header from "All 32" to "All 52" with expanded standards listing
2. Added 20 missing ISO 19135 relationship type examples to the YAML body (deprecated_by, replaces, replaced_by, invalidates, invalidated_by, retires, retired_by, has_part, is_part_of, instance_of, has_instance, has_concept, is_concept_of, has_definition, definition_of, inherits, inherited_by, has_version, version_of, current_version, current_version_of, references, abbreviated_form_for, short_form_for)
3. Normalized all 52 IRIs in `glossarist.org/public/data/taxonomies.json` to canonical form `https://www.glossarist.org/ontologies/rel/{id}` (previously mixed `gloss:rel/...`, `https://glossarist.org/ontologies/relationship-type#...`, and `https://www.glossarist.org/ontologies/rel/...`)
4. Updated `glossarist.org/CLAUDE.md` to list RelationshipTypes.vue component and ontology data infrastructure
5. Updated `glossarist.org/docs/model/schemas/index.md` "All 32" → "All 52"
6. Updated examples `README.md`: "All 32" → "All 52", expanded category table, updated coverage table to all 52 types

## Why

Glossarist.org had stale "32 relationship types" references after the expansion to 52. The taxonomies.json had three different IRI formats that needed normalization.

## Files changed

- `concept-model/schemas/v3/examples/06-related-relationships.yaml` — header + 20 new examples
- `concept-model/schemas/v3/examples/README.md` — updated to 52 throughout
- `glossarist.org/public/data/taxonomies.json` — all 52 IRIs normalized
- `glossarist.org/.vitepress/theme/components/RelationshipTypes.vue` — already had all 52 (no change needed)
- `glossarist.org/CLAUDE.md` — added RelationshipTypes.vue, useOntologyData.ts
- `glossarist.org/docs/model/schemas/index.md` — "32" → "52"
