# TODO 1: Delete obsolete editions.yml and build_site_config.rb

## Status: DONE

## Summary
`editions.yml` and `scripts/build_site_config.rb` are no longer needed. All metadata now lives in per-dataset `register.yaml` files. The CI workflow no longer runs the Ruby generation step.

## Files deleted
- `editions.yml`
- `scripts/build_site_config.rb`

## Verification
- CI workflow (`.github/workflows/build_deploy.yml`) does not reference either file
- `npx concept-browser build` succeeds without them
- All dataset metadata resolved from `register.yaml` files
