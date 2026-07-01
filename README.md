# VIML — International Vocabulary of Legal Metrology

[![Deploy](https://github.com/oimlsmart/vocab/actions/workflows/build_deploy.yml/badge.svg)](https://github.com/oimlsmart/vocab/actions/workflows/build_deploy.yml)

Online terminology browser for the **International Vocabulary of Legal Metrology** (OIML V 1:2022), deployed at [oimlsmart.github.io/vocab](https://oimlsmart.github.io/vocab/).

Built with the [Glossarist Concept Browser](https://github.com/glossarist/concept-browser) — a statically deployable SPA for browsing terminology datasets.

## Contents

- [Repository structure](#repository-structure)
- [Dataset](#dataset)
- [Building locally](#building-locally)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Updating the dataset](#updating-the-dataset)

## Repository structure

```
vocab/├── site-config.yml          Site configuration (branding, features, dataset, base path)
├── about.md                 About page (English)
├── about-fra.md             About page (French)
├── viml-glossarist/         Glossarist v3 dataset (source of truth)
│   ├── register.yaml        Dataset metadata and concept list
│   └── concepts/            135 concept YAML files
├── logos/                    OIML logo files (SVG, light/dark variants)
├── scripts/                  Ruby scraper scripts for generating the dataset
└── .github/workflows/
    └── build_deploy.yml     CI: build + deploy to GitHub Pages
```

Build artifacts (gitignored): `dist/`, `public/`, `.datasets/`, `node_modules/`.

## Dataset

The `viml-glossarist/` directory contains the Glossarist v3 dataset with **135 concepts** covering all sections of OIML V 1:2022:

| Section | Topics |
|---------|--------|
| 0 | General concepts |
| 1 | Measurement |
| 2 | Measurement results |
| 3 | Measuring instruments |
| 4 | Legal metrology — General terms |
| 5 | Legal metrology — Metrological control |
| 6 | Legal metrology — Bodies, marks, certificates |
| A | Conformity assessment |

Each concept is a YAML file with English and French designations, definitions, notes, examples, and source references.

## Building locally

Prerequisites: Node.js 20+

```sh
npm install --ignore-scripts @glossarist/concept-browser
npm install --prefix node_modules/@glossarist/concept-browser sharp 2>/dev/null || true
npx concept-browser build
```

The CLI reads `site-config.yml` from the current directory, fetches the dataset from `viml-glossarist/` (via `localPath`), generates static data, and builds the SPA into `dist/`.

To preview the build:

```sh
npx vite preview
```

## Configuration

All configuration is in `site-config.yml`. Key fields:

```yaml
basePath: /vocab/               # Subpath for GitHub Pages deployment

datasets:
  - id: viml
    localPath: viml-glossarist       # Dataset source directory
    ref: "OIML V 1:2022"            # Publication reference (shown in sidebar provenance)
    owner: OIML
    sourceRepo: https://github.com/oimlsmart/vocab

branding:
  primaryColor: "#004996"
  logo:
    localPath: logos/oiml-logo.svg
    localLight: logos/oiml-logo-icon-light.svg
    localDark: logos/oiml-logo-icon-dark.svg
```

- **`basePath`** — sets the URL subpath for GitHub Pages. No `BASE_PATH` env var needed.
- **`localPath`** — points to the local dataset directory. No `DATASET_SOURCE_*` env var needed.
- **`ref`** — publication reference shown in the sidebar provenance section.
- **Branding** — logo variants for light/dark mode, colors, Google Fonts.

The site supports English and French UI (`uiLanguages` in config). About pages are provided in both languages (`about.md`, `about-fra.md`).

## Deployment

Pushing to `main` triggers the GitHub Actions workflow (`.github/workflows/build_deploy.yml`):

1. Checks out the repo
2. Installs `@glossarist/concept-browser` from npm
3. Runs `npx concept-browser build`
4. Deploys `dist/` to GitHub Pages

All configuration comes from `site-config.yml` — the only env var is `GITHUB_TOKEN`.

## Updating the dataset

Datasets under `datasets/**/*.yaml` are authoritative — human editors curate them by hand, one entry at a time. To fix data, edit the YAML directly with surgical changes.

The active `scripts/` directory contains only read-only tools:
- `scripts/validate_datasets.rb` — CI gate, invariant checking
- `scripts/compare_viml_1968_index.rb` — read-only comparison
- `scripts/match_supersedes.rb` — find supersedes relationships (default `--dry-run`)
- `scripts/ocr_pdf_glm.rb` — GLM-OCR driver for any source PDF (auto-splits >100p)

The original one-shot scrapers that seeded each edition live in `scripts/historical/` for provenance only. **Do not re-run them** — they would overwrite editor-curated entries. See `scripts/historical/README.md`.

## License

Copyright OIML. All terminology content is sourced from OIML publications.
