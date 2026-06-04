# TODO 1: Register and Section models in glossarist-js

## Summary
Create `Register` and `Section` model classes in glossarist-js. A Register represents a self-describing dataset. A Section represents an organizational group within a dataset.

## Files to create

### `src/models/register.js`
Register model: identity (id, ref, year, urn, status), provenance (owner, sourceRepo, tags), languages, relationships (supersedes), sections, ordering, per-dataset metadata (logo, description, about). No concept list — concepts are discovered from the directory.

### `src/models/section.js`
Section model: id, localized names, optional ordering override.

### `src/register-parser.js`
Parse `register.yaml` into a Register instance. Mirrors `ConceptParser` pattern.

### `src/models/index.js`
Export `Register`, `Section`.

## Verification
- Unit tests for Register/Section construction, serialization, deserialization
- Round-trip: `Register.fromJSON(data).toJSON()` matches input
