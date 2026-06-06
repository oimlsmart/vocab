# TODO 08: G18 term-based cross-linking (designation matching)

## Status: DONE

## Description
Added 9 additional cross-links from G18 concepts to VIM/VIML by matching preferred
designations. These complement the 92 definition-text-based links from TODO 03.

## Edition targeting

### Definition-text links (TODO 03): G18 → VIML **2000**
G18:2010 references VIML 2000 concept numbers. VIML 2013 renumbered many concepts
(e.g., 2000 2.13 "verification" → 2013 2.09; 2013 2.13 became "subsequent verification").
Targeting VIML 2013 by number would point to wrong concepts. Fixed via
`scripts/fix_g18_viml_edition.rb`.

### Term-based links (this TODO): G18 → VIML **2022**
These are editorial navigation links matched by designation (not citations from G18 text).
"module", "audit", "inspection", "terminal" first appeared in VIML 2013 — they don't exist
in VIML 2000 at all. Targeting VIML 2022 (current) is appropriate since these are
navigational aids, not citation references. The concept-browser's supersedes chain
navigates VIML 2013 → 2022 automatically.

## Links added
- 4 × "module" (G18:00082, 00584, 00896, 01341) → VIML 2022 4.04
- 1 × "validation" (G18:00176) → VIM 2012 2.45
- 1 × "validation" (G18:02223) → VIM 2012 2.45
- 1 × "audit" (G18:00177) → VIML 2022 A.12
- 1 × "inspection" (G18:00190) → VIML 2022 A.11
- 1 × "terminal" (G18:00901) → VIML 2022 5.10

## Total G18 cross-links
- 92 from definition text parsing (TODO 03): 62 VIM 1993, 21 VIML 2000, 9 VIM 2007
- 9 from designation matching (TODO 08): 7 VIML 2022, 2 VIM 2012
- **101 total G18→VIM/VIML cross-links**
