# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a deployment repository for the **VIML** (International Vocabulary of Legal Metrology, OIML V 1) concept browser and the **VIM** (International Vocabulary of Metrology, OIML V 2-200) concept dataset. It uses the `@glossarist/concept-browser` npm package — a statically deployable Vue 3 SPA — to serve an interactive terminology browser on GitHub Pages.

This is NOT a software project. It is a deployment configuration: site config, datasets, content pages, and CI.

## Build commands

```sh
# Install concept-browser
npm install --ignore-scripts @glossarist/concept-browser
npm install --prefix node_modules/@glossarist/concept-browser sharp 2>/dev/null || true

# Build the static site
npx concept-browser build

# Preview locally
npx vite preview
```

Output goes to `dist/`. All configuration is read from `site-config.yml` — no environment variables needed.

## Key files

- `site-config.yml` — All site configuration (branding, features, dataset source, base path, languages). Hand-edited, committed to the repo.
- `datasets/viml-2022/` — Glossarist v3 dataset for VIML 2022 (135 concept YAML files + `register.yaml`)
- `datasets/viml-2013/` — Glossarist v3 dataset for VIML 2013 (135 concepts, includes section A)
- `datasets/viml-2000/` — Glossarist v3 dataset for VIML 2000 (44 concepts)
- `datasets/viml-1968/` — Glossarist v3 dataset for VIML 1968 (OCR, needs manual review)
- `datasets/vim-2012/` — Glossarist v3 dataset for VIM 2012 (144 concepts, current)
- `datasets/vim-2010/` — Glossarist v3 dataset for VIM 2010 (143 concepts)
- `datasets/vim-2007/` — Glossarist v3 dataset for VIM 2007 (143 concepts)
- `datasets/vim-1993/` — Glossarist v3 dataset for VIM 1993 (120 concepts, OCR)
- `about-eng.md` / `about-fra.md` — Site-level about page content (English and French, covers both VIML and VIM)
- `logos/` — OIML logo SVGs (main, light variant, dark variant)
- `scripts/validate_datasets.rb` — CI gate, dataset invariant validation (read-only)
- `scripts/audit_viml.rb` — Read-only VIML dataset audit
- `scripts/audit_vim.rb` — Read-only VIM dataset audit
- `scripts/compare_viml_1968_index.rb` — Read-only comparator (viml-1968 index vs concepts)
- `scripts/match_supersedes.rb` — Find supersedes relationships across editions (default `--dry-run`)
- `scripts/historical/` — One-shot generation scripts that seeded each edition. **Do not re-run** — datasets are authoritative. See `scripts/historical/README.md`.
- `scripts/ocr_vim_1993_zai.py` — Z.AI GLM-OCR API client (writes to `/tmp/`, not datasets)
- `reference-docs/vim-1993-ocr/` — Z.AI OCR output for VIM 1993 (layout_details, mapping)
- `reference-docs/viml-1968-ocr/` — Z.AI OCR output for VIML 1968

## Configuration conventions

- `basePath: /vocab/` — GitHub Pages subpath deployment. No `BASE_PATH` env var.
- `localPath: datasets/viml-2022` — Dataset source directory. No `DATASET_SOURCE_*` env var.
- `ref: "OIML V 1:2022"` — Publication reference shown in sidebar provenance.
- All config is in `site-config.yml`. The CI uses only `GITHUB_TOKEN`.

### i18n in site-config.yml

Localized text uses **language maps** — a `translations` field keyed by ISO 639-2 language codes. The top-level `title`, `subtitle`, and `description` fields hold the default-language value; `translations` holds the non-default languages:

```yaml
title: OIML Vocabularies
subtitle: International Vocabularies of Metrology
description: Terminology from the International Vocabularies of Metrology published by OIML
translations:
  fra:
    subtitle: Vocabulaires internationaux de métrologie
    description: Terminologie des Vocabulaires internationaux de métrologie publiés par l'OIML
```

Do NOT use language suffixes like `title_fra` or `description_fra`. Always use nested language maps. This pattern applies to all localized text: site-level translations, dataset translations, group translations, and page translations.

## CI

Push to `main` triggers `.github/workflows/build_deploy.yml`:
1. Install `@glossarist/concept-browser` from npm (always released version, never git)
2. Run `npx concept-browser build`
3. Deploy `dist/` to GitHub Pages

Note: Edition scrapers in `scripts/historical/` are one-shots that have already run. They are not part of routine workflow. See `scripts/historical/README.md`.

## Datasets

### VIML (multi-edition)

Four VIML editions are available as separate datasets:

| Edition | Path | Concepts | Notes |
|---------|------|----------|-------|
| 2022 (current) | `datasets/viml-2022/` | 135 | Bilingual EN/FR, scraped from viml.oiml.info |
| 2013 | `datasets/viml-2013/` | 135 | Bilingual EN/FR, scraped from Word HTML (includes section A) |
| 2000 | `datasets/viml-2000/` | 44 | Bilingual EN/FR, scraped from PDF HTML |
| 1968 | `datasets/viml-1968/` | 276 | French only, OCR-derived — 302 index entries map to 276 unique concepts |

Cross-edition `supersedes` relations are encoded declaratively in each concept's `related` array — only the newer concept declares what it supersedes. `superseded_by` is derived at render time by concept-browser from incoming `supersedes` graph edges.

### VIM (multi-edition)

Four VIM editions are available as separate datasets:

| Edition | Path | Concepts | Notes |
|---------|------|----------|-------|
| 2012 (current) | `datasets/vim-2012/` | 144 | Bilingual EN/FR, scraped from jcgm.bipm.org/vim |
| 2010 | `datasets/vim-2010/` | 143 | Bilingual EN/FR, scraped from pdftotext |
| 2007 | `datasets/vim-2007/` | 143 | Bilingual EN/FR, scraped from pdftotext |
| 1993 | `datasets/vim-1993/` | 120 | Bilingual EN/FR, OCR HTML (6 chapters, 5.29-5.33 do not exist) |

VIM 2007/2010 share the same concept numbering (5 chapters, 143 concepts). VIM 1993 has 6 chapters with 120 concepts (1.1-1.22, 2.1-2.9, 3.1-3.16, 4.1-4.31, 5.1-5.28, 6.1-6.14).

Datasets are authoritative — hand-curated by editors. To fix data, edit the YAML directly. Do not regenerate from source (the original scrapers are in `scripts/historical/` for provenance only).
