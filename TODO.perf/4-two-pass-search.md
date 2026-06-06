# TODO.perf/4: Two-pass search

**Status:** DONE

## Problem

`searchAcrossDatasets()` calls `adapter.ensureAllChunksLoaded()` for every adapter — loading 66MB of concept data for a single search query. Most searches find results in already-loaded index data.

## Fix

Two-pass search strategy:

**Pass 1**: Search loaded data only (index entries in memory). If ≥20 results, return immediately — no additional loading.

**Pass 2**: If <20 results, load chunks lazily for datasets that haven't loaded yet, one dataset at a time, checking result count after each. Stop as soon as ≥20 results are found.

## Files

- `concept-browser/src/stores/vocabulary.ts` — rewrite `searchAcrossDatasets()` with two-pass strategy
- `concept-browser/src/__tests__/search-integration.test.ts` — test lazy search loading

## Verification

- Search for a common term: verify results return instantly from loaded data
- Search for a rare term: verify chunks load lazily, one dataset at a time
- No more 66MB bulk load on search
