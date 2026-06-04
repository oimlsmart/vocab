# TODO 4: Update concept-browser build to read from register.yaml

## Summary
Update `generate-data.mjs` to read dataset metadata from `register.yaml` instead of `site-config.yml`'s datasets entries. Discover concepts by scanning the `concepts/` directory instead of reading a concept list.

## Key changes in `generate-data.mjs`

### Dataset discovery
For each `config.datasets[i].localPath`:
1. Read `{localPath}/register.yaml`
2. Extract identity, sections, relationships, languages, ordering, metadata
3. Scan `{localPath}/concepts/*.yaml` for concept files (natural sort)
4. Build manifest.json from register data

### processDataset()
- Accept register data instead of config-derived metadata
- Discover concepts from directory listing: `fs.readdirSync(conceptsDir).filter(f => f.endsWith('.yaml'))`
- Natural sort for correct systematic ordering
- Use register's sections for domain-node generation
- Use register's languages/languageOrder for language stats

### buildRefMaps()
- Build URN map from all register.yaml files
- Each register's `urn` and `urnAliases` populate the map

### buildDatasetGroups()
- Read group definitions from site-config.yml (deployment concern)
- Dataset metadata (title, description, color) from register.yaml

## Key changes in `build-edges.js`
- Build URN map from register.yaml directly
- No dependency on manifest.json for URN resolution

## Key changes in `load-site-config.mjs`
- For each dataset with only `localPath`, read register.yaml for metadata
- Merge register metadata into the dataset config for backwards pipeline compat during build

## Verification
- Build succeeds with register.yaml-based metadata
- manifest.json matches expected output
- Concepts discovered from directory, ordered by natural sort
