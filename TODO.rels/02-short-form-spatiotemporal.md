# TODO 02: Normalize spatiotemporal names to short form

## Status: DONE

## Description
Renamed `sequentially_related_concept`, `spatially_related_concept`, `temporally_related_concept`
to short form (`sequentially_related`, `spatially_related`, `temporally_related`)
consistently across all Glossarist repos.

## Files modified

### concept-model
- `ontologies/taxonomies/relationship-type.ttl` — renamed IRIs and prefLabels
- `models/concepts/RelatedConceptType.lutaml` — renamed enum values
- `schemas/v3/concept.yaml` — renamed in schema enum
- `schemas/v2/examples/06-related-relationships.yaml` — renamed in examples
- `schemas/v3/examples/06-related-relationships.yaml` — renamed in examples
- `README.adoc` — renamed in documentation

### concept-browser
- `src/utils/relationship-categories.ts` — renamed in types array
- `src/data/taxonomies.json` — renamed keys, ids, IRIs
- `src/__tests__/ontology-registry.test.ts` — renamed in assertions

### glossarist.org
- `.vitepress/theme/components/RelationshipTypes.vue` — renamed in categories
- `.vitepress/data/schemas-bundled.json` — renamed in bundled schema
- `public/data/taxonomies.json` — renamed keys, ids
- `public/data/schemas/v3/concept.yaml` — renamed in schema
- `public/data/schemas/v{2,3}/examples/06-related-relationships.yaml` — renamed

### glossarist-js
- `src/models/related-concept.js` — renamed in type constants
- `test/models/supporting.test.js` — renamed in assertions

### glossarist-ruby
- `lib/glossarist/rdf/relationship_predicates.rb` — renamed predicates
- `spec/unit/related_concept_spec.rb` — renamed in specs
- `spec/fixtures/concept-model-examples/v{2,3}/06-related-relationships.yaml` — renamed
- `CLAUDE.md` — renamed in docs
- `README.adoc` — renamed in docs

## Verification
```sh
grep -r "sequentially_related_concept" glossarist-js/ concept-browser/ glossarist-ruby/ concept-model/
# Returns no results (except TODO files)
```
