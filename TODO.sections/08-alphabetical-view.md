# TODO 8: Alphabetical view toggle

## Status: DONE

## Summary
Added a view mode toggle (Systematic / Alphabetical) to the concept list. Systematic is the default (original ID-ordered view). Alphabetical groups concepts by first letter of preferred designation, derived at render time.

## Changes made
- Implemented as part of TODO 07 changes to `DatasetView.vue`
- `alphabetGroups` computed groups `filtered` concepts by first letter of `eng` designation
- Template renders alphabetical groups with letter headers and dividers
- View mode toggle only shown when sections exist (indicating structured dataset)

## Files modified
- `src/views/DatasetView.vue` (part of TODO 07)
