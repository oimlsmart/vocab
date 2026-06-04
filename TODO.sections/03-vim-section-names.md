# TODO 3: Verify VIM section names against source documents

## Summary
Verify all 4 VIM edition register.yaml section names match source documents (English and French). Fix any discrepancies.

## Status: DONE — verified correct

## Source verification

### VIM 2012 (OIML V 2-200:2012) — `reference-docs/v002-200-e12.txt`
All names match TOC entries and chapter headings:
| Ch | English (TOC) | French (TOC) | Status |
|----|---------------|--------------|--------|
| 1 | Quantities and units | Grandeurs et unités | ✓ |
| 2 | Measurements | Mesurages | ✓ |
| 3 | Devices for measurements | Dispositifs de mesure | ✓ |
| 4 | Properties of measuring devices | Propriétés des dispositifs de mesure | ✓ |
| 5 | Measurement standards (Etalons) | Étalons | ✓ |

Note: Chapter headings use singular ("Measurement", "Devices for measurement") while TOC uses plural. Register uses TOC form (commonly cited).

### VIM 2010 (OIML V 2-200:2010) — `reference-docs/v002-200-e10.txt`
Same 5 chapters as VIM 2012. Names verified ✓.

### VIM 2007 (JCGM 200:2008) — `reference-docs/v002-200-e07.txt`
Same 5 chapters. Names verified ✓.

### VIM 1993 (ISO Guide 99:1993) — `reference-docs/vim-1993-ocr/layout-text.md`
6 chapters (different structure from later editions):
| Ch | English | French | Status |
|----|---------|--------|--------|
| 1 | Quantities and units | Grandeurs et unités | ✓ |
| 2 | Measurements | Mesurages | ✓ |
| 3 | Measurement results | Résultats de mesure | ✓ |
| 4 | Measuring instruments | Instruments de mesure | ✓ |
| 5 | Characteristics of measuring instruments | Caractéristiques des instruments de mesure | ✓ |
| 6 | Measurement standards, etalons | Étalons | ✓ |

All concept files already have `ref_type: section` (120/120).
