# TODO 7: Concepts reference sections via domains — tags removed

## Summary
All concepts reference their section via `domains` field using section IDs from `register.yaml`. The `tags` field is removed from concept files.

## OIML Vocab (viml-*, vim-*)
Already uses `domains`. No changes to concept files.

## ISO 34000
Replace `tags` with `domains`:

```yaml
# Before:
tags:
  - general

# After:
domains:
  - concept_id: section-3
    source: urn:iso:std:iso:34000:2026
    ref_type: domain
```

## ISO 34000 section → tag mapping

| Section | ID |
|---------|-----|
| 3 | section-3 |
| 4 | section-4 |
| 5 | section-5 |
| 6 | section-6 |
| 7 | section-7 |
| 8 | section-8 |

## Concept ID tracing
Section IDs enable tracing across editions:
- VIM 1993 concept 6.8: `domains: [{concept_id: section-6}]` (6 chapters)
- VIM 2007 concept 5.8: `domains: [{concept_id: section-5}]` (5 chapters)
- Section change (6→5) explains ID reorganization
- `supersedes` relationship connects 5.8 → 6.8 across the structural change

## Verification
- All concepts have `domains` referencing valid section IDs
- No concept files use `tags` for section membership
- domain-nodes.json shows correct concept counts per section
