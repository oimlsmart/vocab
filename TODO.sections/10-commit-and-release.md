# TODO 10: Commit and release across all repos

## Summary
Commit changes across glossarist-js, concept-browser, oiml-vocab, and iev repos. Release updated packages.

## glossarist-js
- `src/models/section.js` — children, descendantById
- `src/models/register.js` — recursive sectionById
- `src/models/index.d.ts` — TypeScript declarations
- `test/models/register.test.js` — hierarchical section tests
- Bump version to 0.3.1

## concept-browser
- `scripts/build-edges.js` — hierarchical domain-nodes generation
- `scripts/generate-data.mjs` — manifest includes hierarchical sections
- `src/adapters/types.ts` — ManifestSection with children, section edge type
- `src/adapters/DatasetAdapter.ts` — localized domain node names
- Release new version (0.7.18?) via GHA tag workflow

## oiml-vocab
- All 8 register.yaml files — full metadata, sections
- All 1074 concept files — ref_type: section
- `site-config.yml` — slimmed to deployment-only
- `.github/workflows/build_deploy.yml` — removed Ruby generation step
- Delete `editions.yml` and `scripts/build_site_config.rb`
- `TODO.sections/` — task tracking

## IEV gem
- `lib/iev/exporter.rb` — register.yaml generation with hierarchical sections
- `domain_references_for()` — ref_type: section for structural references

## Verification
- `npm test` passes in glossarist-js (381 tests)
- `npx concept-browser build` succeeds in oiml-vocab
- Manifest files include correct section hierarchy
- Domain-nodes include children for hierarchical datasets
