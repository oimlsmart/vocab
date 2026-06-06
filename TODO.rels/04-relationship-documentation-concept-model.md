# TODO 04: Document relationship types in concept-model ontology

## Status: DONE

## Description
Updated `concept-model/ontologies/taxonomies/relationship-type.ttl` to include all 52
relationship types (was 30). Added 22 missing ISO 19135 types:

### Added types
- Lifecycle: `deprecated_by`, `replaces`, `replaced_by`, `invalidates`, `invalidated_by`, `retires`, `retired_by`
- Partitive: `has_part`, `is_part_of`
- Instantial: `instance_of`, `has_instance`
- Register: `has_concept`, `is_concept_of`, `has_definition`, `definition_of`, `inherits`, `inherited_by`
- Versioning: `has_version`, `version_of`, `current_version`, `current_version_of`
- Associative: `references`

Also renamed spatiotemporal types to short form (see TODO 02).

## Source of truth
- ISO 19135-2 Edition 2: `sections/data/08-data-relations-rc.yaml`
- ISO 19135-2 Edition 2: `sections/09-actions.adoc`
- ISO 19135-2 Edition 2: `sections/13-models.adoc`
- concept-browser: `src/data/taxonomies.json` and `src/utils/relationship-categories.ts`
