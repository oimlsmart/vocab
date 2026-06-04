# TODO 7: Concept-browser hierarchical section sidebar

## Status: DONE

## Summary
Added hierarchical section rendering in the sidebar with expandable/collapsible children. When a dataset has sections defined in its register.yaml, they appear as a "Sections" tree in the sidebar when the dataset is expanded. Clicking a section filters the concept list to show only concepts in that section.

## Changes made

### concept-browser
- `src/adapters/types.ts` — Added `SectionNode` interface with `id`, `names`, `conceptCount`, `children`. Added `children` and `conceptCount` to `GraphNode`.
- `src/adapters/DatasetAdapter.ts` — Added `mapDomainNode`, `mapSectionNode`, `getSectionTree`, `mapManifestSection` methods for hierarchical section support. `loadDomainNodes` now preserves children.
- `src/components/AppSidebar.vue` — Added sections tree between sub-pages and provenance in both grouped and flat dataset views. Expand/collapse for section parents with children. Section filter via query param `?section=section-X`.
- `src/views/DatasetView.vue` — Added section filter via `route.query.section`. Added `conceptMatchesSection()` for prefix-based matching. Added view mode toggle (Systematic / Alphabetical). Alphabetical view groups concepts by first letter of preferred designation.
- `src/i18n/locales/eng.yml` — Added `nav.sections`, `dataset.systematic`, `dataset.alphabetical`, `dataset.sectionFilter`, `dataset.clearSection`, `dataset.conceptsInSection`.
- `src/i18n/locales/fra.yml` — Added French translations for the same keys.

## How it works
1. `manifest.sections` carries the hierarchical section tree from register.yaml
2. Sidebar renders sections as expandable tree with "All" option to clear filter
3. Clicking a section navigates to `?section=section-X` which filters the concept list
4. `conceptMatchesSection()` uses prefix matching: section-1 → concepts 1.1, 1.2, etc.
5. Alphabetical view groups by first letter of preferred designation

## Files modified
- `src/adapters/types.ts`
- `src/adapters/DatasetAdapter.ts`
- `src/components/AppSidebar.vue`
- `src/views/DatasetView.vue`
- `src/i18n/locales/eng.yml`
- `src/i18n/locales/fra.yml`
