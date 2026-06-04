# TODO 8: Per-dataset metadata — logo, description, provenance, about pages

## Summary
Each dataset carries its own metadata in `register.yaml`: logo, localized description, provenance/contribution info, and about page paths.

## register.yaml fields
```yaml
logo:
  path: logos/viml-2022.svg
  alt: "OIML V 1:2022"
description:
  eng: "Current edition with 135 terms..."
  fra: "Édition actuelle..."
about:
  eng: about-eng.md
  fra: about-fra.md
provenance:
  - role: publisher
    organization: OIML
    url: https://www.oiml.org
contributors:
  - name: "OIML TC 3/SC 1"
    role: editorial committee
```

## Concept-browser changes
- manifest.json includes per-dataset logo, description, provenance
- Dataset sidebar shows per-dataset logo and owner
- About page paths read from register.yaml
- Logo copied to `public/logos/{dsId}-logo.svg` at build time

## Verification
- Each dataset's manifest includes logo, description, provenance
- Dataset about pages render correctly
- Dataset sidebar shows per-dataset branding
