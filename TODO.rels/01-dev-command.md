# TODO 01: Add `dev` command to concept-browser CLI

## Status: Pending

## Description
Add a `dev` command that runs `generate + edges` then spawns `vite dev` with HMR,
instead of the full `build` pipeline. This enables `npm run dev` in deployment repos
like oiml-vocab for live development.

## Files to modify

### concept-browser/cli/index.mjs
- Add `dev` case alongside `build` in the command handler
- Run fetch + generate + edges (shared with build)
- Instead of favicon generation + vite build, run `vite dev` directly
- Update help text to list `dev` command

### oiml-vocab/package.json
- Add `"dev": "npx concept-browser dev"` script

## How to verify
```sh
cd /Users/mulgogi/src/mn/oiml-vocab
npm run dev
# Should open browser with HMR at localhost:5173
```
