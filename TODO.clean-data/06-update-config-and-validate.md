# TODO 6: Update editions.yml and Register Files

## Problem Summary

After all datasets are cleaned, several configuration files need updating to reflect
the correct concept counts, section definitions, and metadata.

## Current vs. Expected Values

### editions.yml

| Field | Current | Expected (after cleanup) | Notes |
|-------|---------|-------------------------|-------|
| viml-2013 concept_count | 109 | 135 | After adding Annex A, removing spurious |
| viml-2000 concept_count | 45 | 44 | Register says 44, editions.yml says 45 |
| viml-1968 concept_count | 30 | TBD (from manual review) | Could be 30–40 |

### Register files

Each `datasets/viml-*/register.yaml` must be regenerated after re-scraping. The concept
lists must match the actual concept files in `concepts/` directories.

## Implementation Steps

### Step 1: After TODO 1 (VIML 2013) is complete

1. Verify `datasets/viml-2013/register.yaml` lists exactly 135 concepts
2. Verify concepts are numbered: 0.01–0.15, 1.01–1.06, 2.01–2.24, 3.01–3.07, 4.01–4.16, 5.01–5.22, 6.01–6.08, A.1–A.37
3. Update `editions.yml` viml-2013:
   - `concept_count: 135`
   - Add Annex A section to `sections` and `sections_fra` (if missing)

### Step 2: After TODO 2 (VIML 2000) is complete

1. Verify `datasets/viml-2000/register.yaml` lists exactly 44 concepts
2. Verify all concepts have both `eng` and `fra` localizations
3. Update `editions.yml` viml-2000:
   - `concept_count: 44`

### Step 3: After TODO 3 (VIML 1968) is complete

1. Verify `datasets/viml-1968/register.yaml` lists the correct number of concepts
2. Update `editions.yml` viml-1968:
   - `concept_count: <actual count from manual review>`
   - Verify `sections` mapping is correct for the 1968 chapter structure

### Step 4: After TODO 4 (supersession mappings) is complete

1. Run `ruby scripts/build_site_config.rb` to regenerate `site-config.yml`
2. Verify all datasets are listed with correct paths and concept counts

### Step 5: Build and smoke-test

```sh
npx concept-browser build
npx vite preview
```

Verify:
- [ ] All 8 editions load correctly (4 VIML + 4 VIM)
- [ ] Each edition shows the correct concept count in the sidebar
- [ ] Cross-edition links work (supersedes / superseded_by)
- [ ] Switching languages (EN/FR) works for all bilingual editions
- [ ] The 1968 edition shows French only (no broken EN tab)
- [ ] No console errors
