# TODO 9: Organized views — architectural design

## Summary
Document the organized views architecture: how `sections` in register.yaml serves as the systematic view, how alphabetical is derived, and how future views (thematic, pedagogical) would extend the model.

## The core principle
**Concepts exist independently of how they're organized.** A concept just IS — it has a definition, terms, and relationships. Organization is a view concern: different views arrange the same concepts differently for navigation.

## Two organizational dimensions

### 1. Structural (ref_type: section)
Where the concept appears in the document's own hierarchy. Encoded in register.yaml `sections` tree. Concepts reference their leaf group via `domains` with `ref_type: section`.

```yaml
# register.yaml
sections:
  - id: "102"
    names: { eng: "Mathematics" }
    children:
      - id: "102-01"
        names: { eng: "Sets and operations" }
```

### 2. Thematic (ref_type: domain)
What the concept is ABOUT — independent of where it appears structurally. A concept about "uncertainty" could be in section "Measurements" structurally but domain "statistics" thematically.

```yaml
# concept
domains:
  - concept_id: section-2       # structural: in chapter 2
    source: urn:oiml:pub:v:2:2012
    ref_type: section
  - concept_id: domain-statistics  # thematic: about statistics
    source: urn:oiml:pub:v:2:2012
    ref_type: domain
```

## Available views

| View | Source | Storage | Derivation |
|------|--------|---------|------------|
| Systematic | `sections` in register.yaml | Hierarchical tree | Direct from register |
| Alphabetical | Concept designations | None | Sort by preferred designation |
| Domain | `domains` with `ref_type: domain` | Optional group definitions | Cross-cutting, thematic |
| Pedagogical | Future: named view in register.yaml | Separate tree | Ordered by learning path |

## IEV example
IEV currently uses pseudo-concepts (SubjectAreaConcepts) for both structural and thematic purposes — area/section references are `ref_type: domain`. The migration path:
1. Register.yaml sections provide the structural hierarchy (part > section)
2. Concepts use `ref_type: section` for structural membership
3. Pseudo-concepts remain for graph edges (narrower/broader visualization)
4. Future: areas could also serve as thematic domains via `ref_type: domain`

## Future: multiple named views
If a dataset needs more than the default systematic + alphabetical views:
```yaml
# register.yaml (future extension)
views:
  - id: systematic
    name: { eng: "By topic" }
    ordering: systematic
    source: sections  # references the sections tree
  - id: pedagogical
    name: { eng: "Learning path" }
    ordering: mixed
    roots:
      - id: "fundamentals"
        names: { eng: "Fundamentals" }
      - id: "applications"
        names: { eng: "Applications" }
```

This is NOT implemented now — the model doesn't preclude it but doesn't require it either.

## What's implemented
- [x] Hierarchical sections (children in Section model)
- [x] Section edge type (ref_type: section vs domain)
- [x] Domain-nodes generation from register.yaml sections
- [x] Manifest includes hierarchical sections
- [ ] Concept-browser sidebar renders hierarchy (TODO 07)
- [ ] Alphabetical view toggle (TODO 08)
- [ ] IEV register.yaml generation (TODO 06)
