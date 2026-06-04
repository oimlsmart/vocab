# TODO 1: Fix VIML 2013 Scraper and Re-scrape Dataset

## Problem Summary

The VIML 2013 dataset (`datasets/viml-2013/`) has 109 entries in its register, but the
source document (`reference-docs/V001-ef13.html`, a Word HTML export) contains 135 concepts:
98 main (sections 0–6) + 37 Annex A concepts. The scraper (`scripts/scrape_viml_2013.rb`)
has three fundamental flaws:

### Issue 1A: False positive concept numbers

The scraper finds all `\d{1,2}\.\d{2}` patterns in the flattened text, which catches:
- Page numbers from the table of contents (e.g., "40" after "Annex A...")
- Cross-reference clause numbers in definitions/notes (e.g., "1.16" from "See: OIML V2-200:2012, 1.16")
- Word document version "16.00" (partially filtered)

This produces **7 spurious concepts**: `1.16`, `2.39`, `2.44`, `2.52`, `3.11`, `4.26`, and
partial entries that pollute real concepts.

**Evidence:**
- `1.16.yaml`: term = `"] Note 1 The SI"`, definition = `"is founded on the seven base quantities..."`
- `2.39.yaml`: term = `"]"`, definition = `[]` (empty)
- `2.44.yaml`: term = `"."`, definition = `[]` (empty)
- `3.11.yaml`: term = `"] 1. Metrology"`, definition = `"and its legal aspects..."`
- `4.26.yaml`: term = `"] Note 3 Usually"`, definition = `"the term 'maximum permissible error'..."`

These are fragments of notes and cross-references, not concepts.

### Issue 1B: Annex A concepts not parsed

The source document uses `A.XX` numbering for Annex A (A.1 through A.37), but the scraper
only matches `\d{1,2}\.\d{2}` — it never finds `A.1`, `A.2`, etc. The Annex A content
starts at offset ~85050 in the source text with clean entries like:

```
A.1 conformity assessment demonstration that specified requirements...
A.1 évaluation de la conformité démonstration que des exigences spécifiées...
A.2 conformity assessment body body that performs conformity assessment services...
```

Because the Annex A numbers aren't recognized, the scraper doesn't split them. Instead, the
entire Annex A text from ~A.24 onwards gets merged into existing section 2 or 3 entries,
creating the `7.10`–`7.14` entries which are actually fragments of A.24–A.37+ crammed
together with EN/FR text interleaved.

**Evidence:**
- `7.10.yaml`: contains text for A.24 ("agreement group") mixed with A.25 ("homologation")
- `7.14.yaml`: contains text for A.30 through A.37 PLUS the entire alphabetical index

The result: **all 37 Annex A concepts are missing** from the dataset (replaced by 5 mangled
entries), and concepts A.1–A.23 are completely absent.

### Issue 1C: French definitions are truncated/wrong

Many French concepts have truncated or incorrect definitions. The scraper splits terms from
definitions by looking for the first lowercase word, but French term/definition boundaries
are ambiguous because:
- French terms often start with lowercase articles (de, du, des, d', le, la, les)
- The same heuristic that works for English ("Metrology science of measurement...") fails
  for French where the definition might start identically

**Evidence:**
- Concept `1.01`: French term = `"mise"`, definition = `"sur le marché"` (should be "mise sur le marché / placing on the market")
- Concept `1.02`: French term = `"M"`, definition = `"marquage"` (should be from "marquage" / "marking")
- Concept `1.03`: French term = `"remise"`, definition = `"en conformité..."` (fragment)
- Concept `2.01`: French term = `"contrôle"`, definition = `"légal des instruments..."` (should be "contrôle légal des instruments de mesure")
- Concept `3.01`: French term = `"certificat"`, definition = `"de vérification"` (should be "certificat de vérification")
- Concept `4.01`: French term = `"certificat"`, definition = `"d'approbation de type"` (should be "certificat d'approbation de type")

The scraper incorrectly splits the term from the definition for French entries.

## Source Document Structure

The VIML 2013 Word HTML (`reference-docs/V001-ef13.html`) has this structure:
1. Front matter (title page, foreword, introduction, scope, TOC) — pages 1–8
2. Section 0 (Basic terms): 0.01–0.15 — 15 concepts, EN then FR for each
3. Section 1 (Metrology and legal aspects): 1.01–1.06 — 6 concepts
4. Section 2 (Legal metrology activities): 2.01–2.24 — 24 concepts
5. Section 3 (Documents and marks): 3.01–3.07 — 7 concepts
6. Section 4 (Classification): 4.01–4.16 — 16 concepts
7. Section 5 (Construction and operation): 5.01–5.22 — 22 concepts
8. Section 6 (Software): 6.01–6.08 — 8 concepts
9. Annex A (Conformity assessment): A.1–A.37 — 37 concepts
10. Alphabetical index (page 50+)

Each concept entry follows this pattern (EN then FR interleaved):
```
X.XX [English term] [English definition] Note [notes] [source reference]
X.XX [French term] [French definition] Note [notes] [source reference]
```

The same number appears twice (once EN, once FR), and the scraper groups by number
(first occurrence = EN, second = FR). This grouping logic is correct but fails when
false positives create phantom entries that consume the FR slot.

## Expected Outcome

After fixing:
- **98 main concepts**: 0.01–0.15, 1.01–1.06, 2.01–2.24, 3.01–3.07, 4.01–4.16, 5.01–5.22, 6.01–6.08
- **37 Annex A concepts**: A.1–A.37 (with identifier `A.XX` and domain `section-A`)
- **Total: 135 concepts** (matching the 2022 edition count)
- All concepts have correct bilingual EN/FR content with proper terms, definitions, notes, and sources

## Implementation Steps

### Step 1: Fix the scraper regex to avoid false positives

In `scripts/scrape_viml_2013.rb`, the `split_into_entries` method needs to:
1. Skip the front matter entirely (everything before "0.01" — the first real concept)
2. Only match concept numbers that appear at the START of a line or after a `]` (source ref close)
   Pattern: `/(?:^|\])\s*(\d{1,2}\.\d{2})\s+(?=[A-Z])/` — concept number followed by
   a capital letter (term start), not a lowercase letter (mid-sentence reference)
3. Exclude the alphabetical index section (after "Alphabetical index")
4. Filter out entries where the "term" is just `]` or `.` or starts with `]`

### Step 2: Add Annex A parsing

Add a second pass for Annex A:
1. Find the Annex A start: `"Annex A (informative)"` or similar marker
2. Match `A.XX` patterns instead of `\d{1,2}\.\d{2}`
3. Use the same EN/FR grouping logic (first A.XX = EN, second A.XX = FR)
4. Set identifier to `A.XX` and domain to `section-A`

### Step 3: Fix French term/definition splitting

The `split_term_from_definition` method needs French-specific logic:
1. For French, the term is typically ALL CAPS or properly capitalized
2. French definitions start with lowercase but so do French prepositions in terms
3. Better approach: split at the boundary between the term (which ends with a period
   or capital letter) and the definition (which starts with a lowercase letter that
   is NOT a common French article/preposition)
4. Alternative: use the bilingual pairing — since EN and FR entries are adjacent and
   the EN term is known, use it to infer the FR term boundary

### Step 4: Re-run the scraper

```sh
cd /path/to/glossarist-ruby
bundle exec ruby /path/to/oiml-viml/scripts/scrape_viml_2013.rb
```

### Step 5: Validate the output

Run audit checks:
- [ ] 135 concept files exist (98 main + 37 annex)
- [ ] All concepts have both EN and FR localizations
- [ ] No concept has a term that is just `]`, `.`, or empty
- [ ] Annex A concepts use `A.XX` identifiers with `section-A` domain
- [ ] All source references (`[OIML V2-200:2012, X.X]`, `[ISO/IEC 17000:2004, X.X]`) are captured
- [ ] Concept `1.06` exists with correct term "placing on the market" / "mise sur le marché"
- [ ] No concepts with identifiers like `1.16`, `2.39`, `2.44`, `2.52`, `3.11`, `4.26`
- [ ] No concepts with identifiers like `7.10`–`7.14`
- [ ] French term for `0.01` is "métrologie" with full definition
- [ ] French term for `2.01` is "contrôle métrologique légal" with full definition

### Step 6: Update register.yaml and editions.yml

After validation:
- Update `datasets/viml-2013/register.yaml` with correct 135 concepts
- Update `editions.yml` concept_count from 109 to 135
- Add Annex A section info if not already present
