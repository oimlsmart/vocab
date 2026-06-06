# TODO.perf/5: Background chunk preloading in DatasetView

**Status:** DONE

## Problem

After browsing a dataset (Tier 1 loaded), clicking a concept triggers a separate fetch for the concept JSON. For large datasets, concept JSON files are in chunks that aren't loaded until filtering or pagination reaches them.

## Fix

After the dataset index loads in `DatasetView.vue`, schedule background chunk preloading via `requestIdleCallback` with a 2-second timeout. This progressively loads all concept chunks during idle browser time, so concept views are instant.

This is progressive enhancement — the app works correctly without preloading; preloading just makes it faster.

## Files

- `concept-browser/src/views/DatasetView.vue` — add idle preloading after index loads

## Verification

- Browse a dataset, wait 3 seconds, click a concept: verify instant load
- Browse and immediately click a concept: still works (just slower)
