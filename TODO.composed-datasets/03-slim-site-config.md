# TODO 3: Slim site-config.yml, delete editions.yml and build_site_config.rb

## Summary
Remove `editions.yml` and `scripts/build_site_config.rb`. Slim `site-config.yml` to deployment/presentation config only. Dataset entries become `localPath` references.

## Files to delete
- `editions.yml`
- `scripts/build_site_config.rb`

## site-config.yml datasets section becomes:
```yaml
datasets:
  - localPath: datasets/viml-2022
  - localPath: datasets/viml-2013
  - localPath: datasets/viml-2000
  - localPath: datasets/viml-1968
  - localPath: datasets/vim-2012
  - localPath: datasets/vim-2010
  - localPath: datasets/vim-2007
  - localPath: datasets/vim-1993
```

Deployment-only fields that stay: id, domain, uriBase, basePath, title, subtitle, description, translations, uiLanguages, branding, features, pages, datasetGroups, defaults, copyright, routing.

## Verification
- `npx concept-browser build` succeeds
- All 8 datasets discovered and built correctly from register.yaml
