# TODO.perf/6: GraphView cleanup

**Status:** DONE

## Problem

After Phases 2–3, `loadAllGraphData()` and `ensureAllEdgesLoaded()` should only be called from GraphView. Need to verify no Tier 3 calls leak into Tier 1/2 code paths.

## Fix

Audit all call sites:
- `loadAllGraphData()` — only called from `GraphView.vue:onMounted` ✓
- `ensureAllEdgesLoaded()` — was called from `viewConcept()`, now replaced by `ensureEdgesForDataset()`. Keep the method for GraphView use but ensure it's not called elsewhere.

## Files

- `concept-browser/src/stores/vocabulary.ts` — verify `ensureAllEdgesLoaded()` only called from graph-related code paths

## Verification

- Grep for all usages of `ensureAllEdgesLoaded` and `loadAllGraphData`
- Confirm both only appear in graph-related contexts
