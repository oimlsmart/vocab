# TODO 6: IEV gem — generate register.yaml with hierarchical sections

## Status: DONE

## Summary
The IEV gem (`/Users/mulgogi/src/glossarist/iev`) generates a `register.yaml` file with hierarchical sections from `subject_areas.yaml`. The hierarchy is: area (part) > section. 99 areas, 752 sections.

## Changes made
- `lib/iev/exporter.rb` — added `save_register` method to `export` pipeline, generates register.yaml with hierarchical sections from `SubjectAreas.all`
- `domain_references_for()` — changed from `ref_type: "domain"` to `ref_type: "section"`, concepts reference their leaf section only (not both area and section)
- Updated test expectations across 4 spec files for new ref_type and single-domain behavior
- Added test for register.yaml generation (hierarchical sections verified)
- All 266 tests pass

## Files modified
- `lib/iev/exporter.rb` — `save_register`, `domain_references_for` updated
- `spec/iev/exporter_spec.rb` — updated expectations, added register.yaml test
- `spec/acceptance/db2yaml_spec.rb` — updated domain expectations
- `spec/acceptance/export_spec.rb` — updated domain expectations
- `spec/acceptance/xlsx2yaml_spec.rb` — updated domain expectations
