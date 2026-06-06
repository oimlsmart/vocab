# TODO 16: Add register.yaml example to concept-model

**Status:** DONE

## What was done

1. Created `schemas/v3/examples/17-register-dataset.yaml` — dataset-level register.yaml example showing:
   - URN-based dataset identification (`urn: "urn:example:vocab:2024"`)
   - Cross-edition supersession (`supersedes: vocab-2018`, `superseded_by: vocab-2024`)
   - `urnAliases` for glob-style URN matching
   - Multi-language descriptions and sections
   - Inline comments demonstrating how concept-level `related` entries use URN `ref.source` to cross-link between datasets
2. Updated `schemas/v3/examples/README.md` to include example 17 in feature coverage table and section listing

## Why

Cross-dataset URN resolution was undocumented in the concept-model examples. The OIML vocab project uses this pattern extensively (VIML 2022 supersedes VIML 2013, G18 cross-links to VIM/VIML), but there was no canonical example showing how `register.yaml` URNs map to concept-level `ref.source` values.

## Files changed

- `concept-model/schemas/v3/examples/17-register-dataset.yaml` — created
- `concept-model/schemas/v3/examples/README.md` — added example 17 entry
