# TODO 03: Cross-link G18 terms to VIM/VIML definitions

## Status: DONE (script written and applied, edition targeting corrected)

## Description
G18 (OIML G 18:2010) is an alphabetical list of 2132 terms from various OIML publications.
161 concepts reference VIM or VIML in their definition text. This script extracts those
references and adds `see` cross-dataset relationships.

## Edition targeting
- **VIM references**: G18 cites specific VIM editions by year (1993, 2007). No ambiguity.
- **VIML references**: G18 cites VIML without year. Since G18:2010 predates VIML 2013/2022,
  these references use VIML **2000** concept numbering. VIML 2013 renumbered many concepts,
  so targeting VIML 2013 by number would point to wrong concepts (e.g., VIML 2000 2.13
  "verification" → VIML 2013 2.09, while VIML 2013 2.13 is "subsequent verification").

## Results
- 94 G18 concepts with extractable VIM/VIML references
- 92 cross-links successfully added (94 - 2 missing concepts)
  - 62 VIM:1993 references (VIM 1993 concepts)
  - 9 VIM:2007 references (VIM 2007 concepts)
  - 21 VIML:2000 references (VIML 2000 concepts, via `fix_g18_viml_edition.rb`)
- 2 unmatched: VIM:1993 2.10 (doesn't exist), VIM:2007 2.53 (doesn't exist)

## Scripts
- `scripts/link_g18_to_vim.rb` — extracts VIM/VIML references from definition text
- `scripts/fix_g18_viml_edition.rb` — retargets VIML links from 2013 to 2000 (edition fix)

```sh
ruby scripts/link_g18_to_vim.rb --dry-run   # preview changes
ruby scripts/link_g18_to_vim.rb --write     # apply changes
ruby scripts/fix_g18_viml_edition.rb --dry-run  # preview edition fix
ruby scripts/fix_g18_viml_edition.rb --write    # apply edition fix
```

## Example output
G18 concept "measuring instrument" (00079) sourced from OIML B003 now links to VIM:1993 4.1:
```yaml
related:
  - type: see
    ref:
      source: urn:oiml:pub:v:2:1993
      id: '4.1'
```

## Remaining work
- Manual review of the 2 unmatched references
- Consider linking G18 concepts that cite VIM sources but without explicit concept IDs
- Build verification (TODO 11)
