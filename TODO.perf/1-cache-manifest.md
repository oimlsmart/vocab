# TODO.perf/1: Cache guard on loadManifest()

**Status:** DONE

## Problem

`DatasetAdapter.loadManifest()` re-fetches `register.yaml` every time `loadDataset()` is called, even when the manifest is already in memory. In `AdapterFactory.discoverDatasets()`, all manifests are loaded. Then when a user navigates to a dataset, `loadDataset()` calls `loadManifest()` again — a redundant network round-trip.

## Fix

Add an early return in `DatasetAdapter.loadManifest()` when `this.manifest` is already set.

## Files

- `concept-browser/src/adapters/DatasetAdapter.ts` — cache guard in `loadManifest()`
- `concept-browser/src/__tests__/dataset-adapter.test.ts` — test for cache guard

## Verification

- Unit test: calling `loadManifest()` twice only fetches once
- Existing tests still pass
