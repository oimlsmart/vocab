# TODO 05: Document relationship system on glossarist.org

## Status: DONE

## Description
Updated `glossarist.org/docs/model/relationships.md` and supporting components to document
the full relationship system with cross-dataset navigation.

## Changes made

### docs/model/relationships.md
- Updated type count from 32 to 51
- Added "Inverse Derivation" section — explains how superseded_by etc. are derived from graph edges
- Added "Cross-Dataset Navigation" section — documents VIM multi-edition and G18→VIM use cases
- Added cross-dataset YAML authoring example with `ref.source` and `ref.id`
- Added ISO 19135 to design principles
- Updated SKOS alignment table

### .vitepress/theme/components/RelationshipTypes.vue
- Expanded from 8 categories to 12, matching concept-browser's full set:
  - Added Partitive (ISO 19135: has_part, is_part_of)
  - Added Instantial (ISO 19135: instance_of, has_instance)
  - Added Register Management (ISO 19135: has_concept, is_concept_of, inherits, inherited_by)
  - Added Versioning and Definitional (ISO 19135: has_definition, definition_of, has_version, version_of, current_version, current_version_of)
  - Split Comparative from Associative
  - Split Designation from Lexical
  - Added complete lifecycle: deprecated_by, replaces, replaced_by, invalidates, invalidated_by, retires, retired_by
- Expanded inverse mappings from 16 to 36 entries

### public/data/taxonomies.json
- Synced relationshipType section from concept-browser (30 → 52 types)
- Updated scheme definition to mention ISO 19135 categories
