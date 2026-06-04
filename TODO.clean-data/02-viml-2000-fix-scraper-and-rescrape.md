# TODO 2: Fix VIML 2000 Scraper and Re-scrape Dataset

## Problem Summary

The VIML 2000 dataset (`datasets/viml-2000/`) has 44 concept files but is severely broken:

### Issue 2A: No English content — French only

All 44 concepts have **only French (`fra`) localizations**. The `localized_concepts` field
contains only a `fra` UUID, no `eng`. The source document (`reference-docs/v001-ef00.html`,
a PDF→HTML conversion) is bilingual: English section first, then French section. The
scraper's `find_french_start()` logic apparently failed, causing all concepts (including
those in the English section) to be treated as French.

**Evidence:** Running `grep -c "language_code: eng" datasets/viml-2000/concepts/*.yaml`
returns 0 for all 44 files.

### Issue 2B: French definitions are truncated fragments

Every French definition is a fragment — not the actual definition text. The terms are
truncated and the definitions are what follows the term in the source text, split
incorrectly.

**Evidence:**
- `1.1`: term = `"métrologie"`, definition = `"légale"` (should be "science de la mesure")
- `1.2`: term = `"Ooblitération"`, definition = `"d'une marque de vérification"` (should be about "legal metrology" with OCR artifact "Oo")
- `2.1`: term = `"contrôle"`, definition = `"légal des instruments de mesure"` (should be "contrôle métrologique légal")
- `3.1`: term = `"Mmarquage"`, definition = `[]` (should be "marquage" with "Mm" OCR artifact)
- `4.1`: term = `"Vvérification"`, definition = `"d'un instrument de mesure"` (should be about "unités de mesure légales" with "Vv" OCR artifact)

The scraper seems to be extracting from the French section only and splitting at the wrong
boundaries. The definition is always just the text fragment that follows the truncated term.

### Issue 2C: OCR artifacts in terms

Terms have doubled initial letters from OCR:
- `"Ooblitération"` → should be `"Oblitération"`
- `"Mmarquage"` → should be `"Marquage"`
- `"Vvérification"` → should be `"Vérification"`

This is a common OCR artifact where the initial letter is duplicated.

### Issue 2D: Wrong supersession mappings

Concept `4.1` is mapped to superseded_by `1.06` in the 2013 edition. But looking at the
supersession-map.yaml, entity `legal_units_of_measurement` maps to 2022:1.06, 2013:1.06,
2000:4.1. This means concept 4.1 in the 2000 edition is "legal units of measurement" —
but the dataset has term "Vvérification" (verification), not "legal units of measurement".

The concept content is wrong, not the mapping — but the mapping needs verification after
the data is fixed.

## Source Document Structure

The VIML 2000 PDF→HTML (`reference-docs/v001-ef00.html`) has this structure:

**English section** (comes first):
```
1 BASIC TERMS IN LEGAL METROLOGY
1.1 metrology science of measurement [VIM 2.2]
1.2 legal metrology part of metrology relating to activities which result from
statutory requirements and concern measurement, units of measurement, measuring
instruments and methods of measurement and which are performed by competent bodies
NOTES 1 The scope of legal metrology may be different from country to country.
2 The competent bodies responsible for legal metrology activities...
1.3 metrological assurance all the regulations, technical means and necessary
operations used to ensure the credibility of measurement results in legal metrology
```

**French section** (after "TERMES DE BASE DE MÉTROLOGIE LÉGALE"):
```
TERMES DE BASE DE MÉTROLOGIE LÉGALE
1.1 métrologie science de la mesure [VIM 2.2]
1.2 métrologie légale partie de la métrologie se rapportant aux activités qui
résultent d'exigences réglementaires...
NOTES 1 L'étendue de la métrologie légale peut différer d'un pays à l'autre.
2 Les organismes compétents...
1.3 assurance métrologique ensemble des règlements, moyens techniques et actions
nécessaires utilisés pour assurer la crédibilité des résultats de mesure...
```

The HTML has inline CSS that heavily pollutes `Nokogiri .text` output. The scraper strips
`<style>` elements, but the remaining text has concept numbers embedded in running text
with no separator before the term (e.g., "1.1metrology").

**Concept list:**
- Section 1 (Basic terms): 1.1–1.3 = 3 concepts
- Section 2 (Legal metrology activities): 2.1–2.24 = 24 concepts
- Section 3 (Documents and marks): 3.1–3.10 = 10 concepts
- Section 4 (Units and measuring instruments): 4.1–4.7 = 7 concepts
- **Total: 44 concepts** (bilingual EN/FR, no Annex A)

## Implementation Steps

### Step 1: Fix scraper's language detection

The `find_french_start()` method in `scripts/scrape_viml_2000.rb` uses section markers
like "TERMES DE BASE", "ACTIVITÉS DE MÉTROLOGIE", etc. to split EN/FR. The issue might be
that:
1. These markers aren't being found (encoding issues with accented characters)
2. Or the `find_concept_positions()` regex matches concept numbers in the CSS/style content
3. Or the French section markers match too early

Debug by:
1. Printing the `fra_start` position and confirming it's correct
2. Printing the first EN entry and first FR entry to verify correct splitting
3. Checking that concept numbers from CSS (like font sizes "1.1pt") aren't matched

### Step 2: Fix concept number regex

The current regex `/(?:\A|\s)(\d{1,2})\.(\d{1,2})(?=\s|[a-zA-Z])/` may match numbers
in CSS declarations. Since the HTML has `<style>` blocks stripped but inline CSS classes
like `.s1`, `.s2` etc., verify that no CSS artifacts remain in the text.

Also, the regex should NOT match inside square brackets (source references like `[VIM 2.2]`).

### Step 3: Fix French term extraction

For French entries, the term/definition split needs the same fix as the 2013 scraper.
French terms are typically single words or short phrases. The definition follows
immediately after. For this edition, the pattern is:
```
X.X [term] [definition] [NOTES N ...] [source reference]
```

### Step 4: Add OCR artifact cleanup

Strip doubled initial consonants in French terms. Common pattern: if term starts with
two identical uppercase/lowercase pairs like `Mm`, `Vv`, `Oo`, keep only one.

### Step 5: Re-run the scraper

```sh
cd /path/to/glossarist-ruby
bundle exec ruby /path/to/oiml-viml/scripts/scrape_viml_2000.rb
```

### Step 6: Validate the output

- [ ] 44 concept files exist
- [ ] All concepts have BOTH `eng` and `fra` localizations
- [ ] No French terms have doubled initial letters (Mm, Vv, Oo)
- [ ] Concept `1.1` EN: term = "metrology", definition = "science of measurement"
- [ ] Concept `1.1` FR: term = "métrologie", definition = "science de la mesure"
- [ ] Concept `1.2` EN: term = "legal metrology", definition starts with "part of metrology"
- [ ] Concept `2.1` EN: term = "legal metrological control", definition starts with "the whole of"
- [ ] Concept `4.1` is "legal units of measurement" (NOT "vérification")
- [ ] All NOTES are captured (2.1 has 1 note, 1.2 has 2 notes, etc.)
- [ ] Source references `[VIM X.X]` are captured where present

### Step 7: Update register.yaml

After validation, update `datasets/viml-2000/register.yaml` to include correct concept
list (same 44 concepts but confirm numbering).
