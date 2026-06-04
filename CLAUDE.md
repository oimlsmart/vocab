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

- `site-config.yml` — All site configuration (branding, features, dataset source, base path, languages). Auto-generated from `editions.yml` by `scripts/build_site_config.rb`.
- `editions.yml` — Single source of truth for all editions (4 VIML + 4 VIM)
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
- `scripts/scrape_viml.rb` — Scraper for VIML 2022 dataset (from viml.oiml.info)
- `scripts/scrape_viml_2013.rb` — Scraper for VIML 2013 (Word HTML)
- `scripts/scrape_viml_2000.rb` — Scraper for VIML 2000 (PDF HTML)
- `scripts/scrape_viml_1968.rb` — Scraper for VIML 1968 (OCR HTML, French only)
- `scripts/viml_edition_scraper.rb` — Shared scraper framework (EditionConfig, ConceptBuilder, DatasetWriter)
- `scripts/build_site_config.rb` — Generates site-config.yml datasets from editions.yml
- `scripts/scrape_vim.rb` — Scraper for VIM 2012 dataset (from jcgm.bipm.org/vim)
- `scripts/scrape_vim_pdf.rb` — Scraper for VIM 2007/2010 (from pdftotext output)
- `scripts/scrape_vim_1993.rb` — Scraper for VIM 1993 (from OCR HTML)
- `scripts/audit_viml.rb` — VIML dataset validation script
- `scripts/audit_vim.rb` — VIM dataset validation script
- `scripts/ocr_vim_1993_zai.py` — Re-OCR VIM 1993 / VIML 1968 PDFs via Z.AI GLM-OCR API
- `reference-docs/vim-1993-ocr/` — Z.AI OCR output for VIM 1993 (layout_details, mapping)
- `reference-docs/viml-1968-ocr/` — Z.AI OCR output for VIML 1968

## Configuration conventions

- `basePath: /oiml-vocab/` — GitHub Pages subpath deployment. No `BASE_PATH` env var.
- `localPath: datasets/viml-2022` — Dataset source directory. No `DATASET_SOURCE_*` env var.
- `ref: "OIML V 1:2022"` — Publication reference shown in sidebar provenance.
- All config is in `site-config.yml`. The CI uses only `GITHUB_TOKEN`.

### i18n in editions.yml

Localized text uses **language maps** — a `translations` field keyed by ISO 639-2 language codes. The `deploy.title` and `deploy.description` fields in `editions.yml` are language maps:

```yaml
deploy:
  title:
    eng: "VIML — International Vocabulary of Legal Metrology"
    fra: "VIML — Vocabulaire international de métrologie légale"
  description:
    eng: "Current edition with 135 terms..."
    fra: "Édition actuelle comprenant 135 termes..."
```

Do NOT use language suffixes like `title_fra` or `description_fra`. Always use nested language maps. This pattern applies to all localized text: site-level translations, dataset translations, group translations, and page translations.

`build_site_config.rb` extracts the default-language value and non-default translations using `localized()` and `localized_translations()` helpers.

## CI

Push to `main` triggers `.github/workflows/build_deploy.yml`:
1. Generate `site-config.yml` from `editions.yml` (Ruby)
2. Install `@glossarist/concept-browser` from npm (always released version, never git)
3. Run `npx concept-browser build`
4. Deploy `dist/` to GitHub Pages

Note: Edition scrapers run locally, not in CI. Datasets are committed to the repo.

## Datasets

### VIML (multi-edition)

Four VIML editions are available as separate datasets:

| Edition | Path | Concepts | Notes |
|---------|------|----------|-------|
| 2022 (current) | `datasets/viml-2022/` | 135 | Bilingual EN/FR, scraped from viml.oiml.info |
| 2013 | `datasets/viml-2013/` | 135 | Bilingual EN/FR, scraped from Word HTML (includes section A) |
| 2000 | `datasets/viml-2000/` | 44 | Bilingual EN/FR, scraped from PDF HTML |
| 1968 | `datasets/viml-1968/` | ~30 (OCR artifacts) | French only, OCR quality poor — needs manual review |

Cross-edition `supersedes` relations are encoded declaratively in each concept's `related` array — only the newer concept declares what it supersedes. `superseded_by` is derived at render time by concept-browser from incoming `supersedes` graph edges.

All edition metadata is in `editions.yml` — the single source of truth. Site config is generated by `scripts/build_site_config.rb`.

Scrapers are run locally from the glossarist-ruby repo context:
```sh
cd /path/to/glossarist-ruby
bundle exec ruby /path/to/oiml-vocab/scripts/scrape_viml_2013.rb
```

### VIM (multi-edition)

Four VIM editions are available as separate datasets:

| Edition | Path | Concepts | Notes |
|---------|------|----------|-------|
| 2012 (current) | `datasets/vim-2012/` | 144 | Bilingual EN/FR, scraped from jcgm.bipm.org/vim |
| 2010 | `datasets/vim-2010/` | 143 | Bilingual EN/FR, scraped from pdftotext |
| 2007 | `datasets/vim-2007/` | 143 | Bilingual EN/FR, scraped from pdftotext |
| 1993 | `datasets/vim-1993/` | 120 | Bilingual EN/FR, OCR HTML (6 chapters, 5.29-5.33 do not exist) |

VIM 2007/2010 share the same concept numbering (5 chapters, 143 concepts). VIM 1993 has 6 chapters with 120 concepts (1.1-1.22, 2.1-2.9, 3.1-3.16, 4.1-4.31, 5.1-5.28, 6.1-6.14).

To update 2012: `ruby scripts/scrape_vim.rb` (fetch/build/about phases)
To update 2007/2010: `ruby scripts/scrape_vim_pdf.rb EDITION` (2007 or 2010)
To update 1993: `ruby scripts/scrape_vim_1993.rb`
