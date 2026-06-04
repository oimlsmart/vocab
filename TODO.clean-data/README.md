# VIML Multi-Edition Data Cleanup Plan

## Status

- [ ] **TODO 1**: Fix VIML 2013 scraper and re-scrape — `01-viml-2013-fix-scraper-and-rescrape.md`
- [ ] **TODO 2**: Fix VIML 2000 scraper and re-scrape — `02-viml-2000-fix-scraper-and-rescrape.md`
- [ ] **TODO 3**: Clean VIML 1968 OCR dataset — `03-viml-1968-clean-ocr-dataset.md`
- [ ] **TODO 4**: Complete cross-edition supersession mappings — `04-complete-supersession-mappings.md`
- [ ] **TODO 5**: Fix VIML 2013 French definitions — `05-viml-2013-fix-french-definitions.md`
- [ ] **TODO 6**: Update editions.yml and validate — `06-update-config-and-validate.md`

## Dependency Order

```
TODO 1 (2013 scraper fix) ──→ TODO 5 (2013 French fix)
TODO 2 (2000 scraper fix) ──┐
TODO 3 (1968 clean) ────────┤
TODO 5 (2013 French) ───────┤
                             └──→ TODO 4 (supersession mappings) ──→ TODO 6 (config + validate)
```

- TODOs 1, 2, 3 can be done in parallel (different datasets)
- TODO 5 depends on TODO 1 (must have re-scraped data first)
- TODO 4 depends on TODOs 1, 2, 3 (needs clean data in all three editions)
- TODO 6 depends on TODOs 4 and 5 (needs everything finalized)

## Problem Overview

The VIML (International Vocabulary of Legal Metrology) has 4 editions in this repository:

| Edition | Concepts | Languages | Source | Quality |
|---------|----------|-----------|--------|---------|
| **2022** (current) | 135 | EN/FR | Website scrape | Clean |
| **2013** | 109 (should be 135) | EN/FR (FR broken) | Word HTML | **Broken**: spurious concepts, missing Annex A, French definitions truncated |
| **2000** | 44 | FR only (should be EN/FR) | PDF HTML | **Broken**: no English, French definitions truncated, OCR artifacts |
| **1968** | 136 (should be ~30) | FR | OCR HTML | **Broken**: 80%+ spurious entries, OCR-corrupted content, wrong numbering |

### Root Causes

1. **VIML 2013**: The scraper regex (`\d{1,2}\.\d{2}`) matches false positives (page numbers,
   cross-references, note numbers) and completely misses Annex A (`A.XX` format).

2. **VIML 2000**: The scraper's language boundary detection failed, extracting only French.
   The PDF→HTML source has CSS pollution and no separators between concept numbers and terms.

3. **VIML 1968**: The OCR quality is too poor for automated parsing. The scraper picks up
   page numbers, line numbers, and noise as concept identifiers.

4. **Supersession mappings**: The map only covers 2022→2013→2000 (partial). The 1968→2000
   chain is completely absent. Annex A mappings are missing.
