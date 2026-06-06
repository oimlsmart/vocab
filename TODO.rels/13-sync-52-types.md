# TODO 13: Sync concept-model schemas to 52 types

**Status:** DONE

## What was done

1. Expanded `related_concept_type` enum in `schemas/v3/concept.yaml` from 32 to 52 values
   - Added 20 ISO 19135 types: deprecated_by, replaces, replaced_by, invalidates, invalidated_by, retires, retired_by, has_part, is_part_of, instance_of, has_instance, has_concept, is_concept_of, has_definition, definition_of, inherits, inherited_by, has_version, version_of, current_version, current_version_of, references
2. Updated `RelatedConceptType.lutaml` model from 32 to 52 members
3. Fixed TTL taxonomy header comment from "51" to "52"

## Why

The concept-model only had 32 relationship types but the ontology and glossarist-ruby config defined 52. The schema, LutaML model, and TTL taxonomy needed to agree.

## Files changed

- `concept-model/schemas/v3/concept.yaml` — enum expanded
- `concept-model/models/concepts/RelatedConceptType.lutaml` — enum expanded
- `concept-model/ontologies/taxonomies/relationship-type.ttl` — header comment fixed
