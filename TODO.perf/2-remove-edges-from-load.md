# TODO.perf/2: Remove edges from loadDataset()

**Status:** DONE

## Problem

`vocabulary.ts:loadDataset()` calls `await loadEdges(adapter)` and `seedGraphNodes(registerId, adapter)` eagerly. For dataset browsing (showing the sidebar concept list), only the index is needed. Edges and graph nodes are only needed when viewing a concept (Tier 2) or the graph view (Tier 3).

This causes 560KB–2.2MB of unnecessary edge data to be fetched every time a user clicks on a dataset.

## Fix

Remove `await loadEdges(adapter)` and `seedGraphNodes(registerId, adapter)` from `loadDataset()`. Keep `loadDataset()` as: load manifest → load index → done.

Edge loading moves to `viewConcept()` (via `ensureEdgesForDataset()`) and `loadAllGraphData()` (for GraphView).

## Files

- `concept-browser/src/stores/vocabulary.ts` — remove `loadEdges()` and `seedGraphNodes()` from `loadDataset()`

## Verification

- Browse a dataset: verify no `edges.json` or `domain-nodes.json` requests in Network tab
- View a concept: verify edges still load (via targeted loading from Phase 3)
- Graph view: verify all edges still load via `loadAllGraphData()`
