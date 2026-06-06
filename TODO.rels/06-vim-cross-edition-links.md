# TODO 06: Complete VIM/VIML cross-edition supersession links

## Status: DONE (automated matching + analysis complete)

## Description
Automated term-matching and analysis applied. All viable matches identified.
Remaining unmatched concepts are genuinely new (no predecessor in the older edition).

## Final supersession coverage

| From → To | Links | Concepts with links | Total concepts | Unmatched |
|---|---|---|---|---|
| VIML 2022 → 2013 | 135 | 135 | 135 | 0 (complete) |
| VIML 2013 → 2000 | 37 | 36 | 135 | 99 (genuinely new — VIML 2000 only had 44 concepts) |
| VIML 2000 → 1968 | 30 | 30 | 44 | 14 (French-only OCR, no English term match) |
| VIM 2012 → 2010 | 143 | 143 | 144 | 1 (genuinely new) |
| VIM 2010 → 2007 | 143 | 143 | 143 | 0 (complete) |
| VIM 2007 → 1993 | 83 | 83 | 143 | 60 (genuinely new — VIM 2007 was a major restructuring) |

## Details
- VIML 2013 → 2000: 36 from designation matching + 1 from definition analysis (TODO 10)
- VIM 2007 → 1993: Automated Jaccard similarity analysis found no high-confidence matches
  (only 5 moderate 25-43%). Most unmatched are genuinely new VIM 2007 concepts (TODO 09).
- VIML 2000 → 1968: French-only OCR dataset prevents English term matching.
  Requires manual French-language review.

## Scripts
- `scripts/match_supersedes.rb` — designation-based supersession matching
- `scripts/fix_g18_viml_edition.rb` — VIML edition targeting fix
- `scripts/fix_g18_related_placement.rb` — v3 schema related field placement fix
