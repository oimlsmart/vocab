# TODO 6: Cross-dataset URN resolution from register.yaml

## Summary
Build URN resolution map from all `register.yaml` files. Enables cross-dataset concept linking.

## How it works
1. Each register declares its URN: `urn: "urn:oiml:pub:v:1:2022"`
2. Build process discovers all registers, builds map: URN → dataset ID
3. Cross-dataset references resolve automatically
4. Adding a dataset = adding its directory → new URN entries → new links resolved

## Resolution chain
```
concept YAML: source: urn:oiml:pub:v:2:2010, id: "1.1"
  → URN map lookup: urn:oiml:pub:v:2:2010 → vim-2010
  → navigate to {uriBase}/vim-2010/concept/1.1
```

## Files to modify
- `scripts/build-edges.js` — read register.yaml for URN map
- `scripts/generate-data.mjs` — `buildRefMaps()` from register.yaml
- `src/adapters/UriRouter.ts` — runtime URN resolution uses embedded map

## Verification
- Cross-dataset supersedes links resolve in concept-browser
- URN map includes all aliases
- Adding a dataset directory extends resolution automatically
