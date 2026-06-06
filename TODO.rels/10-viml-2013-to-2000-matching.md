# TODO 10: Improve VIML 2013→2000 supersession matching

## Status: DONE

## Description
8 VIML 2000 concepts were not superseded by any VIML 2013 concept (44 total VIML 2000
concepts, 36 already had supersedes links). Analysis of the remaining 8 showed most are
genuinely dropped concepts.

## Analysis results
Only 1 clear additional match found:
- **VIML 2013 2.09 "verification of a measuring instrument"** → also supersedes
  **VIML 2000 2.11 "conformity assessment of a measuring instrument"**. The VIML 2013
  2.09 definition explicitly says "conformity assessment procedure (other than type
  evaluation)", confirming it absorbed the VIML 2000 conformity assessment concept.

### 7 genuinely dropped VIML 2000 concepts (no VIML 2013 successor)
| VIML 2000 | Term | Reason |
|-----------|------|--------|
| 1.3 | metrological assurance | No equivalent in VIML 2013 |
| 2.18 | voluntary verification | Merged into broader verification subtypes |
| 2.21 | inspection of a measuring instrument | Closest is A.11 "inspection" (different scope) |
| 2.4 | metrological expertise | No equivalent in VIML 2013 |
| 2.8 | examination for conformity with approved type | Subsumed into type approval process |
| 3.4 | metrological expertise certificate | Related to 2.4, both dropped |
| 3.6 | documentation of a measurement standard | No equivalent in VIML 2013 |

## Files modified
- `datasets/viml-2013/concepts/2.09.yaml` — added second supersedes link to VIML 2000 2.11

## Total VIML 2013→2000 supersedes coverage
- 36 from designation matching (TODO 06)
- 1 from definition analysis (this TODO)
- 7 genuinely dropped concepts
- **44 VIML 2000 concepts fully accounted for**
