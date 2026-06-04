# TODO 7: Concept-browser — render hierarchical sections in sidebar

## Summary
The concept-browser sidebar currently shows sections as a flat list. Update to render hierarchical sections with expandable/collapsible children. When a section has `children`, show them indented under the parent.

## Current behavior
- `domain-nodes.json` contains a flat array of section nodes
- Sidebar renders all nodes at the same level
- No visual distinction between parent and child sections

## Target behavior
- `domain-nodes.json` already has hierarchical structure (from TODO 02: children array)
- Sidebar renders parent sections as expandable groups
- Child sections indented under their parent
- Clicking a parent shows all concepts in that subtree (parent + descendants)
- Clicking a leaf section shows only concepts in that section
- Concept count for parent = sum of all descendant concept counts

## Files to modify (concept-browser)
- `src/adapters/DatasetAdapter.ts` — `loadDomainNodes()`: parse hierarchical children from domain-nodes.json
- `src/composables/use-domain-nodes.ts` (or equivalent) — flatten tree for display, track expanded state
- Sidebar component — render tree with indentation, expand/collapse UI
- Type updates: `DomainNode` type needs `children?: DomainNode[]`

## Design
```
▼ 102: Mathematics - General concepts (42 concepts)
    102-01: Sets and operations (12)
    102-02: Numbers (8)
    102-03: Vectors and tensors (6)
    ...
▼ 103: Mathematics - Functions (35 concepts)
    103-01: General concepts (10)
    ...
```

For flat datasets (VIM, VIML, ISO 34000): no children, rendered as before.

## Verification
- IEV dataset (hierarchical) renders with expandable parents
- VIM/VIML/ISO 34000 (flat) render unchanged
- Section concept counts correct (parent = sum of children)
- Clicking a section filters concepts correctly
