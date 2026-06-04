# TODO 5: Fix VIML 2013 French Definitions (Manual Review)

## Problem Summary

Even after the scraper is fixed (TODO 1), many VIML 2013 French definitions will still be
wrong because the scraper's term/definition splitting logic doesn't handle French well.
This task covers the manual review and correction of French content.

## Scope

All 135 VIML 2013 concepts need French definition review. The English definitions are
expected to be mostly correct after the scraper fix, but French needs human verification.

## Known French Issues

### Pattern 1: Term swallowed into definition

Many French entries have the actual French term split incorrectly:

| Concept | Current FR term | Current FR definition | Correct FR term | Correct FR definition |
|---------|----------------|----------------------|-----------------|----------------------|
| 1.01 | "mise" | "sur le marché" | "mise sur le marché" | "..." (full definition) |
| 1.02 | "M" | "marquage" | (need to check source) | "..." |
| 1.03 | "remise" | "en conformité..." | (need to check source) | "..." |
| 2.01 | "contrôle" | "légal des instruments de mesure" | "contrôle métrologique légal" | "ensemble des activités..." |
| 3.01 | "certificat" | "de vérification" | "certificat de vérification" | "..." |
| 4.01 | "certificat" | "d'approbation de type" | "certificat d'approbation de type" | "..." |
| 5.01 | "échelon" | "de vérification" | "échelon de vérification" | "..." |
| 6.01 | "indication" | (empty) | (need to check source) | "..." |

### Pattern 2: Definitions are fragments

Some French definitions are truncated — just the last few words of the actual definition.

### Pattern 3: Notes missing or wrong

French notes may be missing or incorrectly parsed (merged into definition text).

## Implementation Steps

### Step 1: Extract all French terms and definitions

Generate a comparison table from the source document:

```sh
# For each concept, show the raw source text (EN and FR) alongside the parsed result
ruby scripts/audit_viml.rb --edition viml-2013 --compare-source
```

### Step 2: Create a correction spreadsheet

For each of the 135 concepts:
1. Show the EN term and definition (from the 2022 edition, which is correct)
2. Show the current FR term and definition (from the 2013 dataset)
3. Show the expected FR term and definition (from the source document)
4. Mark whether correction is needed

### Step 3: Apply corrections

Two approaches:
- **Manual YAML editing**: Directly edit each concept file for correctness
- **Scraper improvement**: Fix the scraper's French parsing and re-scrape

Recommendation: Fix the scraper first (TODO 1 Step 3), then manually correct any
remaining issues.

### Step 4: Spot-check key concepts

Verify these specific concepts after correction:
- [ ] 0.01 FR: term = "métrologie", definition = "science des mesurages et ses applications"
- [ ] 1.01 FR: term = "mise sur le marché", full definition present
- [ ] 2.01 FR: term = "contrôle métrologique légal", definition includes "ensemble des activités"
- [ ] 3.01 FR: term = "certificat de vérification", full definition present
- [ ] 4.01 FR: term = "catégorie d'instruments", full definition present
- [ ] 5.01 FR: term = "échelon (d'un instrument de mesure)", full definition present
- [ ] 6.01 FR: term = "identification du logiciel", full definition present
- [ ] A.1 FR: term = "évaluation de la conformité", full definition present
