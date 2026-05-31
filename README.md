# VIML Glossary

Terminology from the **International Vocabulary of Legal Metrology** (OIML V 1:2022).

## Repository structure

- `viml-glossarist/` — Glossarist v3 dataset (135 concepts, bilingual English/French)
- `site-config.yml` — Site configuration for the Glossarist Concept Browser
- `about.md` — About page content
- `logos/oiml-logo.svg` — OIML logo
- `.github/workflows/build_deploy.yml` — CI/CD pipeline

## Building locally

```sh
npm install
npx concept-browser build
```

The built site is output to `dist/`.

## Deployment

Pushing to `main` triggers the GitHub Actions workflow which builds and deploys to GitHub Pages.
