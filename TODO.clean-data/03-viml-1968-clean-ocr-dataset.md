# TODO 3: Clean VIML 1968 OCR Dataset

## Problem Summary

The VIML 1968 dataset (`datasets/viml-1968/`) is the worst affected. It has **136 concept
files** when there should be approximately **30 real concepts**. The source
(`reference-docs/v001-f68-ocr.html`) is a heavily OCR-corrupted PDF→HTML with French-only
content. The scraper (`scripts/scrape_viml_1968.rb`) picked up page numbers, line numbers,
table of contents entries, and other noise as concept identifiers.

### Issue 3A: Massive number of spurious entries

The register lists 136 concepts. Most are OCR artifacts. Examples:
- `0.00`, `00.3`, `0.49` — noise (not real concept numbers)
- `0.6` — possibly real (0,6 in French notation = "MÉTROLOGIE LÉGALE")
- `1.11`, `1.13`, `1.15`, `1.19`, `1.23`, `1.25`, `1.31`, `1.37`, `1.51`, `1.61` — likely page/line numbers
- `2.0`, `2.16`, `2.17`, `2.19`, `2.29`, `2.53`, `2.79` — some real, some artifacts
- `3.0`, `03.1`, `3.5`, `3.10` — mixed
- `4.05` — duplicate format (should be 4.5?)
- `05.1` — misread number
- Entries in the 5+ range: `5.35`, `6.59`, `7.47`, `7.69`, `8.0`–`8.6`, `8.49`, `9.1`–`9.87`, `10.10`–`10.49`, `11.1`–`11.8`, etc.
- High-numbered entries: `13.1`, `15.1`, `15.2`, `15.4`, `16.4`, `17.1`, `17.47`, `19.2`, `19.8`, `20.00`, `23.1`, `25.2`, `25.4`, `26.4`, `26.59`, `27.1`, `30.20`, `31.1`, `32.79`, `35.2`, `37.69`, `41.19`, `47.4`, `49.87`, `51.1`, `59.41`, `69.2`, `79.2`, `87.1`, `87.4`

These high numbers (13–87) are clearly page numbers or line numbers from the OCR, not
concept identifiers.

### Issue 3B: OCR-corrupted content

Even for the real concepts, the content is heavily corrupted:
- `0.1`: term = `"MÉTROLOGIEDomaine"` (should be `"MÉTROLOGIE"` with definition starting `"Domaine..."`)
- `1.1`: term = `":l171.Tnrtructlon"` (gibberish OCR of likely "Instruction")
- `2.1`: term = `"1287.Vnleur"` (should be "Valeur nominale" with page number "1287" prefix)
- `3.1`: term = `"1:U.ll"` (gibberish)
- `4.1`: term = `"2160.Grandeur"` (should be "Grandeur" with page number "2160")
- `6.1`: term = `"7uArlicle271.Unlté"` (should be "Unité" with article number prefix)
- `7.1`: term = `"1Système"` (should be "Système" with digit prefix)

Common OCR corruption patterns:
- Page/line numbers prepended to terms (e.g., `"1287."`, `"2160."`, `"7uArlicle271."`)
- Characters misread as similar-looking characters (ll→ll, rn→m, etc.)
- Words split or merged incorrectly
- Special characters lost or garbled (é→e, è→e, etc.)

### Issue 3C: No English content (by design)

The 1968 edition was published in French only. This is correct — `editions.yml` specifies
`languages: [fra]`. No English content needed.

## Source Document Structure

The 1968 OCR source (`reference-docs/v001-f68-ocr.html`) is a French-only document with
this chapter structure (reconstructed from the OCR):

**Chapter 0: MÉTROLOGIE** (6 concepts)
- 0,1. MÉTROLOGIE — Domaine des connaissances relatives aux mesurages
- 0,2. (sub-entry or continuation, possibly MÉTROLOGIE GÉNÉRALE = 0,1.1)
- 0,3. MÉTROLOGIE APPLIQUÉE
- 0,4. MÉTROLOGIE THÉORIQUE
- 0,5. TECHNIQUE DES MESURAGES
- 0,6. MÉTROLOGIE LÉGALE

**Chapter 1: ORGANISMES ET SERVICES SE RAPPORTANT A LA MÉTROLOGIE LÉGALE**
- 1,1 through approximately 1,9 (9–10 concepts)

**Chapter 2: ACTIVITÉS DE MÉTROLOGIE LÉGALE**
- 2,1 through approximately 2,8

**Chapter 3: DOCUMENTS ET MARQUES**
- 3,1 through approximately 3,5

**Chapter 4: UNITÉS ET INSTRUMENTS DE MESURE**
- 4,1 through approximately 4,11

**Chapter 5: CARACTÉRISTIQUES MÉTROLOGIQUES**
- 5,1 through approximately 5,5

**Chapter 6: ÉTALONS**
- 6,1 through approximately 6,4

**Estimated total: ~30–40 concepts** across 7 chapters.

Note: The 1968 edition uses French decimal notation (comma: 0,1 instead of 0.1) and
some entries have sub-entries (like 0,1.1 for MÉTROLOGIE GÉNÉRALE). The scraper converts
commas to dots but doesn't handle sub-entries correctly.

## Implementation Steps

### Step 1: Manual review of source PDF

Open `reference-docs/v001-f68-ocr.pdf` and create a definitive list of all concepts:
1. Go through each chapter and list every concept number and term
2. Note which entries have sub-entries (like 0,1.1)
3. Record the correct French term and definition for each
4. Flag entries where OCR corruption makes the text unreadable

This step cannot be automated — the OCR quality is too poor for reliable parsing.

### Step 2: Determine the authoritative concept list

Based on the manual review, create a mapping:
```yaml
# Expected concepts in VIML 1968
concepts:
  - id: "0.1"
    term: "MÉTROLOGIE"
    section: "0"
  - id: "0.2"
    term: "MÉTROLOGIE GÉNÉRALE"
    section: "0"
  # ... etc.
```

### Step 3: Rebuild the dataset manually or semi-automatically

Given the OCR quality, there are two approaches:

**Option A: Manual entry** — Create each concept YAML file by hand from the PDF review.
Best data quality but time-consuming.

**Option B: Assisted scraping** — Rewrite the scraper with:
1. A hardcoded list of expected concept numbers
2. Text extraction only for those specific positions
3. Post-processing with known OCR corrections
4. Flag all entries for manual review

Recommendation: **Option B** with thorough manual review. The scraper can extract
approximately-correct text, and then a human reviews and corrects each entry.

### Step 4: OCR correction dictionary

Expand the existing `OCR_CORRECTIONS` hash in the scraper with all known errors. Common
patterns found in the data:
- Page/line numbers prefixed: `\d{1,4}\.` before term names — strip these
- Character substitutions: `ll→ll`, `rn→m`, `6→é`, `1→l`, `0→o`
- Broken accented characters: `MtTROLOGIE→MÉTROLOGIE`, `APPLIQUt:E→APPLIQUÉE`
- HTML entity leftovers: `&amp;`, `&#39;`, etc.

### Step 5: Fix concept numbering

The 1968 edition uses French notation (0,1 → 0.1). The scraper should:
1. Convert commas to dots in concept numbers
2. Handle sub-entries like 0,1.1 as `0.1.1` or merge into parent
3. Normalize section numbers: Chapter 0 → section-0, etc.

### Step 6: Clean up spurious entries

Delete all 136 current concept files and rebuild with only the ~30 real concepts.

### Step 7: Validate against supersession map

Cross-check the 1968 concepts against the VIML 2000 concepts using `supersession-map.yaml`.
The 2000 edition superseded the 1968 edition, so each 1968 concept should map to either:
- A 2000 concept (if it was carried forward)
- Nothing (if the concept was dropped in 2000)

### Step 8: Re-run and validate

```sh
cd /path/to/glossarist-ruby
bundle exec ruby /path/to/oiml-viml/scripts/scrape_viml_1968.rb
```

Validation:
- [ ] ~30 concept files (exact count from manual review)
- [ ] All concepts are French only (`language_code: fra`)
- [ ] No entries with identifiers > X.Y format (no 3+ digit section numbers)
- [ ] No entries with terms that are purely numeric or single characters
- [ ] Concept `0.1` has term "MÉTROLOGIE" (not "MÉTROLOGIEDomaine")
- [ ] No entries with page numbers embedded in terms
- [ ] Update `register.yaml` with correct concept list
- [ ] Update `editions.yml` concept_count to match actual count
