# TODO 07: Verify G18→VIM/VIML cross-reference edges

## Status: DONE

## Description
Verified that all cross-dataset edges are correctly generated and rendered in the
concept-browser build output. Two critical issues were found and fixed during verification.

## Issues found and fixed

### 1. VIML edition targeting (wrong concepts)
G18 definition-text VIML links targeted VIML 2013, but G18:2010 references VIML 2000
concept numbers. VIML 2013 renumbered many concepts, so 11 of 13 unique VIML refs pointed
to wrong concepts (e.g., VIML 2000 2.13 "verification" vs VIML 2013 2.13 "subsequent
verification"). Fixed via `scripts/fix_g18_viml_edition.rb`.

### 2. Related field placement (silent data loss)
G18 concept `related` was inside `data.related` but the v3 schema places it at the
top level. The concept-browser's `generate-data.mjs` only reads top-level `related`,
silently dropping all G18 cross-links. Fixed via `scripts/fix_g18_related_placement.rb`.

## Build verification results

### G18 cross-dataset edges (101 total)
| Target | Count | Source |
|--------|-------|--------|
| VIM 1993 | 62 | Definition-text references |
| VIML 2000 | 21 | Definition-text references |
| VIM 2007 | 9 | Definition-text references |
| VIML 2022 | 7 | Term-based designation matches |
| VIM 2012 | 2 | Term-based designation matches |

### Cross-edition supersedes edges
| Dataset | Cross-edges | Target |
|---------|------------|--------|
| VIML 2022 | 135 | VIML 2013 |
| VIML 2013 | 37 | VIML 2000 |
| VIML 2000 | 30 | VIML 1968 |
| VIM 2012 | 143 | VIM 2010 |
| VIM 2007 | 83 | VIM 1993 |

### VIML↔VIM cross-vocabulary
- 13 × `compare` edges (VIML 2022 Section 0 ↔ VIM 2012)
