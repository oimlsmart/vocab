# TODO 10: Commit and release across all repos

## Status: DONE

## Summary
All changes committed and pushed across 4 repositories.

## Commits

### glossarist-js (v0.3.1)
- `ee71233` feat: Register and Section models with hierarchical section support
- Pushed to main

### concept-browser (v0.7.17+)
- `3ba8e40` feat: hierarchical sections sidebar, section filtering, alphabetical view
- Pushed to main
- Release via GHA tag workflow (not manual npm publish)

### iev gem
- `d393b8c` feat: generate register.yaml with hierarchical sections
- Pushed to main

### oiml-vocab
- `4f28c02` feat: self-describing datasets with hierarchical sections
- 1114 files changed: register.yaml files, concept ref_type changes, site-config slimming
- Pushed to main

## Release notes
- concept-browser needs a new version tag for release (e.g. v0.7.18)
- glossarist-js needs a new version tag for release (e.g. v0.3.2 or keep 0.3.1)
