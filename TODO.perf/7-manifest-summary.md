# TODO.perf/7: Manifest summary in datasets.json

**Status:** DONE

## Problem

Initial page load fetches `datasets.json` (1 request) then 9 manifest.json files in parallel (9 requests) before the home page can render. Total: 10 requests, ~29KB, before `appReady = true`.

## Fix

Embed manifest summaries in `datasets.json` at build time. The home page only needs `title`, `description`, `conceptCount`, `languages`, `owner`, `tags`, `color` — all available during data generation.

Runtime: `discoverDatasets()` populates adapters with summary manifests (no network fetch). Full manifests are loaded lazily in `loadDataset()` when the user navigates to a dataset.

### New `DatasetSummary` type
```typescript
export interface DatasetSummary {
  title: string;
  description: string;
  conceptCount: number;
  languages: string[];
  owner: string;
  tags: string[];
  color?: string;
}
```

### Adapter changes
- Added `manifestComplete` flag — distinguishes summary manifest from full manifest
- `setSummaryManifest(summary)` — creates partial Manifest from summary data
- `loadManifest()` only skips fetch when `manifestComplete === true`

### Factory changes
- `discoverDatasets()` checks `reg.summary` — if present, calls `adapter.setSummaryManifest()` instead of fetching
- Adapters without summaries fall back to manifest fetch (backwards compatible)
- Added `loadCrossRefIndex()` method — moved from vocabulary store for encapsulation

## Files

- `concept-browser/src/adapters/types.ts` — add `DatasetSummary`, extend `DatasetRegistry`
- `concept-browser/src/adapters/DatasetAdapter.ts` — `setSummaryManifest()`, `manifestComplete` flag
- `concept-browser/src/adapters/factory.ts` — lazy discovery with summaries, `loadCrossRefIndex()`
- `concept-browser/src/stores/vocabulary.ts` — use `factory.loadCrossRefIndex()`, extract `deduplicateSearchHits()`
- `concept-browser/scripts/generate-data.mjs` — embed summaries in datasets.json

## Verification

- Initial page load: only `datasets.json` + `site-config.json` = 2 requests (was 11)
- Home page renders correctly with summary data (title, concept count, languages, color)
- Dataset navigation loads full manifest lazily
- All 451 tests pass
