# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a deployment repository for the **VIML** (International Vocabulary of Legal Metrology, OIML V 1:2022) concept browser and the **VIM** (International Vocabulary of Metrology, JCGM 200:2012 / OIML V 2-200:2012) concept dataset. It uses the `@glossarist/concept-browser` npm package — a statically deployable Vue 3 SPA — to serve an interactive terminology browser on GitHub Pages.

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

- `site-config.yml` — All site configuration (branding, features, dataset source, base path, languages)
- `viml-glossarist/` — Glossarist v3 dataset for VIML (135 concept YAML files + `register.yaml`)
- `vim-glossarist/` — Glossarist v3 dataset for VIM (144 concept YAML files + `register.yaml`)
- `about.md` / `about-fra.md` — About page content for VIML (English and French)
- `about-vim.md` / `about-vim-fra.md` — About page content for VIM (English and French)
- `logos/` — OIML logo SVGs (main, light variant, dark variant)
- `scripts/scrape_viml.rb` — Scraper for VIML dataset (from viml.oiml.info)
- `scripts/scrape_vim.rb` — Scraper for VIM dataset (from jcgm.bipm.org/vim)
- `scripts/audit_viml.rb` — VIML dataset validation script
- `scripts/audit_vim.rb` — VIM dataset validation script

## Configuration conventions

- `basePath: /oiml-viml/` — GitHub Pages subpath deployment. No `BASE_PATH` env var.
- `localPath: viml-glossarist` — Dataset source directory. No `DATASET_SOURCE_*` env var.
- `ref: "OIML V 1:2022"` — Publication reference shown in sidebar provenance.
- All config is in `site-config.yml`. The CI uses only `GITHUB_TOKEN`.

## CI

Push to `main` triggers `.github/workflows/build_deploy.yml`:
1. Install `@glossarist/concept-browser` from npm (always released version, never git)
2. Run `npx concept-browser build`
3. Deploy `dist/` to GitHub Pages

## Datasets

### VIML (OIML V 1:2022)

The `viml-glossarist/` directory contains 135 bilingual (English/French) concepts from OIML V 1:2022. Concepts are YAML files in Glossarist v3 format. To update: `ruby scripts/scrape_viml.rb`, commit changes to `viml-glossarist/`, push to `main`.

### VIM (JCGM 200:2012 / OIML V 2-200:2012)

The `vim-glossarist/` directory contains 144 bilingual (English/French) concepts from JCGM 200:2012 (3rd edition). The dataset includes:

- **5 sections**: Quantities and units (1.1–1.30), Measurement (2.1–2.53), Devices for measurement (3.1–3.12), Properties of measuring devices (4.1–4.31), Measurement standards (5.1–5.18)
- **65 annotations** — informative commentary by JCGM/WG 2, stored as notes with `[Annotation]` prefix
- **Examples** separated from notes; examples following a note are embedded in that note's text
- **Cross-references** as `{{term text,concept_id}}` patterns
- **Tables** serialized as pipe-delimited text within note content

To update: `ruby scripts/scrape_vim.rb`, commit changes to `vim-glossarist/`, push to `main`.

Scraper commands: `fetch` (download HTML), `build` (parse → YAML), `about` (generate about pages), or run without args for all phases.
