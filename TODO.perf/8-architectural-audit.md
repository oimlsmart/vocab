# TODO.perf/8: Architectural audit findings

**Status:** DONE

## Findings and fixes applied

### 1. Cross-reference index encapsulation (FIXED)
`loadCrossRefIndex()` used raw `fetch()` in the store, breaking the adapter/factory encapsulation layer. Moved to `AdapterFactory.loadCrossRefIndex()`.

### 2. Deduplication utility extraction (FIXED)
`deduplicate()` was a closure inside `searchAcrossDatasets()`. Extracted as `deduplicateSearchHits()` in `utils/search.ts`.

### 3. Lazy manifest loading (FIXED)
Added `DatasetSummary` type, `setSummaryManifest()`, `manifestComplete` flag. Factory populates adapters with summary data from `datasets.json`, avoiding 9 HTTP requests on initial page load.

### 4. Dead code: `ensureAllEdgesLoaded()` (FIXED)
Defined in vocabulary.ts but not in the return statement — never callable. Removed entirely. `ensureEdgesForDataset()` and `loadAllGraphData()` cover all legitimate use cases.

### 5. Duplicate `loadAdjacent()` call in ConceptView.vue (FIXED)
Two watchers both triggered on conceptId change. Removed the redundant standalone watcher.

### 6. Double-fetch in HomeView.vue `exploreRandom()` (FIXED)
Called `store.viewConcept()` before navigation, then ConceptView's watcher called `viewConcept()` again. Removed the pre-navigation fetch.

### 7. GraphEngine missing `clear()` method (FIXED)
Added `clear()` method to reset all internal state (nodes, edges, adjacency, edgeKeys).

### 8. `deduplicateSearchHits` location (FIXED)
Moved from inline in vocabulary.ts to dedicated `utils/search.ts` module.

### 9. GraphEngine.getSubgraph BFS performance (FIXED)
Replaced `queue.shift()` (O(n) per dequeue) with index-based iteration.

### 10. DEFAULT_LANG duplication (FIXED)
Consolidated: `i18n/index.ts` now imports from `utils/lang.ts`.

### 11. OntologyRegistry class not exported (FIXED)
Exported the class (not just the singleton) for testability.

### 12. App.vue `document.querySelector` (FIXED)
Replaced `document.querySelector('main')` with Vue template ref `ref="mainRef"`.

### 13. DRY: Chunk loading watchers in DatasetView (FIXED)
Three identical watchers (filter, sectionQuery, selectedLang) consolidated into `ensureAllChunksForFilter()`.

### 14. DRY: Section enrichment in DatasetView (FIXED)
Removed duplicate `enrichSection()` — `getSections()` now delegates to `adapter.getSectionTree()`.

## Noted but not addressed (lower priority)

### 15. `viewConcept()` does too much (~50 lines of graph manipulation)
Could decompose into smaller methods. Low urgency since it's called from one place.

### 16. `edgeStatus` uses `Record<string, ...>` while other state uses `Map`
Inconsistent but not harmful.

### 17. `GraphEdge.type` is `string`
Not improvable without glossarist providing a string literal union.

### 18. `ConceptSummary.eng` hardcoded English field
Should be `primaryDesignation` computed from `designations` record. Model-level change requiring all consumers to update.

### 19. `DatasetAdapter` is 465+ lines
Does manifest loading, index loading, chunk loading, concept fetching, search, graph node extraction, edge extraction, domain extraction, position tracking. Could decompose but needs careful interface design.

### 20. `searchAcrossDatasets()` loads indexes for all adapters
First search triggers index loading for all datasets (~550KB). Could be optimized with manifest-level pre-filtering.

### 21. Build scripts use mixed module systems
`build-edges.js` uses CommonJS, `generate-data.mjs` uses ESM. Should standardize to ESM.

## Tests added

- `graph-engine-fixes.test.ts` — 6 tests for `clear()`, BFS behavior
- `search-utils.test.ts` — 6 tests for `deduplicateSearchHits`
- `utils-barrel.test.ts` — 2 tests for exports
