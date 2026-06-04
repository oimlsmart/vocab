# TODO 4: Complete Cross-Edition Supersession Mappings

## Problem Summary

The `supersession-map.yaml` maps concepts across VIML editions (2022→2013→2000) but has
significant gaps:

1. **No 1968 mappings at all** — the 1968→2000 chain is missing
2. **2000 edition has 3 removed concepts** (3.8, 3.9, 3.10) not mapped to anything
3. **No Annex A mappings for 2013** — since the 2013 annex data is missing/broken
4. **Some 2000 concepts may be misidentified** — because the 2000 data itself is wrong
5. **The VIM editions also need validation** (though they may be cleaner)

## Current Mapping Coverage

### VIML 2022 → 2013 → 2000

The existing mappings in `supersession-map.yaml` cover:

| Edition | Concepts | Mapped to next | Coverage |
|---------|----------|----------------|----------|
| 2022 | 135 | → 2013 | 98 mapped (main only, no Annex A) |
| 2013 | 109* | → 2000 | ~40 mapped |
| 2000 | 44 | → 1968 | **0 mapped** |
| 1968 | ~30 | — | — |

*2013 has 109 entries but should have 135 (see TODO 1)

### What's missing

1. **2022 Annex A → 2013 Annex A**: Concepts A.1–A.37 in 2022 should map to their 2013
   counterparts (same A.XX numbering). Currently not in the map at all.

2. **2013 → 2000 mappings for all concepts**: The current map has partial coverage.
   Many section 2 and section 3 concepts in 2013 (2.01–2.24, 3.01–3.07) map to 2000
   concepts with the same numbering (2.1–2.24, 3.1–3.7). But this needs verification
   against the actual source documents.

3. **2000 → 1968 mappings**: Completely absent. Every 2000 concept that derives from a
   1968 concept needs to be mapped.

4. **2000 removed concepts**: Concepts 3.8, 3.9, 3.10 in the 2000 edition are annotated
   "Removed after 2000 edition" — they have no 2013 equivalent. These are correctly
   flagged but need to be verified against the source.

5. **2000 concept "metrological assurance" (1.3)**: Annotated "No direct equivalent in
   2013/2022 editions". Needs verification.

## Concept Correspondence Table

Based on source analysis, here is the expected correspondence:

### Section 0/1 (Basic terms)

| Entity | 2022 | 2013 | 2000 | 1968 |
|--------|------|------|------|------|
| metrology | 0.01 | 0.01 | 1.1 | 0.1 |
| international_system_of_units | 0.02 | 0.02 | 4.2 | ~7.1 |
| indication | 0.03 | 0.03 | — | — |
| error_of_indication | 0.04 | 0.04 | — | — |
| maximum_permissible_error | 0.05 | 0.05 | — | — |
| intrinsic_error | 0.06 | 0.06 | — | — |
| influence_quantity | 0.07 | 0.07 | — | — |
| rated_operating_condition | 0.08 | 0.08 | — | — |
| reference_operating_condition | 0.09 | 0.09 | — | — |
| measuring_instrument | 0.10 | 0.10 | — | — |
| measuring_transducer | 0.11 | 0.11 | — | — |
| measuring_system | 0.12 | 0.12 | — | — |
| scale_of_a_displaying_measuring_instrument | 0.13 | 0.13 | — | — |
| calibration | 0.14 | 0.14 | — | — |
| adjustment_of_a_measuring_system | 0.15 | 0.15 | — | — |
| legal_metrology | 1.01 | 1.01 | 1.2 | 0.6 |
| law_on_metrology | 1.02 | 1.02 | — | — |
| legal_metrology_regulation | 1.03 | 1.03 | — | — |
| metrological_assurance | — | — | 1.3 | — |
| national_responsible_body | 1.04 | 1.04 | — | — |
| metrological_authority | 1.05 | 1.05 | — | — |
| legal_units_of_measurement | 1.06 | 1.06 | 4.1 | ~7.1 |

### Sections 2–6

Sections 2 through 6 have largely the same numbering across 2022 and 2013 (2.01–2.24,
3.01–3.07, 4.01–4.16, 5.01–5.22, 6.01–6.08). The 2000 edition uses X.Y format for the
same concepts (2.1–2.24, 3.1–3.7, 4.1–4.7) with fewer concepts in sections 3 and 4.

### Annex A (2022 and 2013 only)

Both editions have A.1–A.37. The 2000 edition does NOT have an Annex A section.
The 1968 edition does NOT have an Annex A section.

### 1968 mapping challenges

The 1968 edition has a very different structure:
- Chapter 0 (Métrologie) → partially maps to 2000 section 1
- Chapter 1 (Organismes) → no direct 2000 equivalent (2000 has no chapter 1 equivalent)
- Chapter 2 (Activités) → maps to 2000 section 2
- Chapter 3 (Documents et marques) → maps to 2000 section 3
- Chapter 4 (Unités et instruments) → maps to 2000 section 4
- Chapter 5 (Caractéristiques métrologiques) → no direct 2000 equivalent
- Chapter 6 (Étalons) → no direct 2000 equivalent

Many 1968 concepts were restructured, merged, or dropped in the 2000 edition.

## Implementation Steps

### Step 1: Complete the VIML supersession map

After TODOs 1–3 are done (all three editions have clean data), update `supersession-map.yaml`:

1. **Add 2022 Annex A → 2013 Annex A mappings**: A.1→A.1, A.2→A.2, ..., A.37→A.37
2. **Verify 2013 → 2000 main section mappings**: Compare term names between editions
3. **Add 2000 → 1968 mappings**: Requires manual review of both datasets
4. **Document unmapped concepts**: Add annotations for concepts that don't carry forward

### Step 2: Run build_supersessions.rb

After the map is complete:
```sh
cd /path/to/glossarist-ruby
bundle exec ruby /path/to/oiml-viml/scripts/build_supersessions.rb
```

This injects `supersedes` and `superseded_by` relations into the concept YAML files.

### Step 3: Validate cross-edition links

For each concept in each edition, verify:
- [ ] Every concept in 2022 that has a `supersedes` link points to a valid 2013 concept
- [ ] Every concept in 2013 has both `supersedes` (→2000) and `superseded_by` (→2022) where applicable
- [ ] Every concept in 2000 has both `supersedes` (→1968) and `superseded_by` (→2013) where applicable
- [ ] Every concept in 1968 that survives to 2000 has `superseded_by` (→2000)
- [ ] No circular references
- [ ] No broken URN references

### Step 4: Build and test the site

```sh
ruby scripts/build_site_config.rb
npx concept-browser build
npx vite preview
```

Verify that:
- [ ] Cross-edition navigation works (clicking "superseded by" / "supersedes" links)
- [ ] All editions display the correct concept count
- [ ] No 404s on cross-edition links

### Step 5: VIM edition validation (optional)

The VIM editions (2012, 2010, 2007, 1993) may also have supersession issues.
Check that:
- [ ] VIM 2012 → 2010 mappings exist and are correct
- [ ] VIM 2010 → 2007 mappings exist and are correct
- [ ] VIM 2007 → 1993 mappings exist and are correct
- [ ] All 144 concepts in 2012/2010/2007 map correctly (same numbering)
