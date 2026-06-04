# TODO 2: Populate all 8 register.yaml files with full metadata

## Summary
Rewrite `register.yaml` in all 8 dataset directories to carry full identity, sections, relationships, and per-dataset metadata. Remove the `concepts` list — concepts are discovered from the `concepts/` directory.

## Source data
All information comes from `editions.yml` (sections, sections_fra, deploy metadata, URN config, supersedes chains). This is the one-time migration that makes editions.yml unnecessary.

## Files to rewrite

- `datasets/viml-2022/register.yaml` — status: current, supersedes: viml-2013, 8 sections (0-6 + A), bilingual
- `datasets/viml-2013/register.yaml` — status: superseded, supersedes: viml-2000, 8 sections
- `datasets/viml-2000/register.yaml` — status: superseded, supersedes: viml-1968, 4 sections
- `datasets/viml-1968/register.yaml` — status: superseded, French only, 9 sections (0-8), no supersedes
- `datasets/vim-2012/register.yaml` — status: current, supersedes: vim-2010, 5 sections
- `datasets/vim-2010/register.yaml` — status: superseded, supersedes: vim-2007, 5 sections
- `datasets/vim-2007/register.yaml` — status: superseded, supersedes: vim-1993, 5 sections
- `datasets/vim-1993/register.yaml` — status: superseded, 6 sections, no supersedes

## register.yaml template

```yaml
schema_type: glossarist
schema_version: '3'
id: viml-2022
ref: "OIML V 1:2022"
year: 2022
urn: "urn:oiml:pub:v:1:2022"
urnAliases: ["urn:oiml:pub:v:1:2022*"]
status: current
refAliases: ["OIML V 1:2022"]
owner: OIML
sourceRepo: https://github.com/metanorma/oiml-vocab
tags: [metrology, legal, oiml, vocabulary]
languages: [eng, fra]
languageOrder: [eng, fra]
ordering: systematic
supersedes: viml-2013
logo: null
description:
  eng: "Current edition with 135 terms across 8 sections..."
  fra: "Édition actuelle comprenant 135 termes..."
about:
  eng: about-eng.md
  fra: about-fra.md
sections:
  - id: "0"
    names:
      eng: "Basic terms"
      fra: "Termes fondamentaux"
  # ...
```

Note: NO `concepts:` list. Concepts are discovered from `concepts/*.yaml` files.

## Verification
- Each register.yaml parses correctly
- All section IDs match concept `domains[].concept_id` values
- URN prefixes match concept `related[].ref.source` values
