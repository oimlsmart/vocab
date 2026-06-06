# TODO.perf/3: cross-ref-index.json + targeted edge loading

**Status:** DONE

## Problem

`viewConcept()` calls `ensureAllEdgesLoaded()` which fetches edges.json from **all 9 datasets** (1.5MB total) on every concept view. Most of those edges are irrelevant to the concept being viewed.

## Fix

### Build time

Generate `cross-ref-index.json` — a tiny artifact (~200 bytes) mapping each dataset to the list of other datasets whose edges.json contains edges targeting it. Built in `scripts/build-edges.js` by scanning all edges' `register` fields.

Example: `{"viml-2022": ["viml-2013", "viml-2000"], "viml-2013": ["viml-2022"]}`

### Runtime

New method `ensureEdgesForDataset(registerId)` in vocabulary.ts:
1. Load `cross-ref-index.json` once (cached)
2. For the given dataset, load only the edges.json files listed in the cross-ref index
3. Skip datasets already loaded via `edgeStatus`

Replace `ensureAllEdgesLoaded()` call in `viewConcept()` with `ensureEdgesForDataset()`.

## Files

- `concept-browser/scripts/build-edges.js` — generate `cross-ref-index.json`
- `concept-browser/src/stores/vocabulary.ts` — add `ensureEdgesForDataset()`, replace `ensureAllEdgesLoaded()` in `viewConcept()`
- `concept-browser/src/__tests__/vocabulary-store.test.ts` — test targeted edge loading

## Verification

- View a VIML 2022 concept: verify only VIML 2022's edges.json + datasets referenced by VIML 2022 are fetched
- Cross-dataset supersession still works: VIML 2022 concepts show "superseded by" from older editions
