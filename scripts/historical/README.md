# Historical generation scripts

**Do not run these against the committed datasets.** They are preserved here for
provenance — to document how each edition was originally seeded — not for reuse.

## Why this directory exists

This repo has transitioned from a **data-generation pipeline** to an
**authoritative data store**:

- Previously, `datasets/**/*.yaml` was the derived output of scrapers and
  parsers. Re-running a script was the normal way to refresh data.
- Now, `datasets/**/*.yaml` is canonical. Human editors curate entries one at
  a time, by hand. The committed YAML is the source of truth.

Any script here that bulk-writes to `datasets/` would silently overwrite
manual edits on the next run. That is unacceptable in the stewardship phase.
They have been moved out of the active `scripts/` directory to make the
boundary explicit.

## What lives here

| Script | Purpose | Status |
|---|---|---|
| `scrape_viml.rb` | VIML 2022 from viml.oiml.info | One-shot, run once to seed `datasets/viml-2022/` |
| `scrape_viml_2013.rb` | VIML 2013 from Word HTML | One-shot, run once to seed `datasets/viml-2013/` |
| `scrape_viml_2000.rb` | VIML 2000 from PDF HTML | One-shot, run once to seed `datasets/viml-2000/` |
| `scrape_viml_1968.rb` | VIML 1968 from OCR HTML | One-shot, run once to seed `datasets/viml-1968/` |
| `scrape_vim.rb` | VIM 2012 from jcgm.bipm.org/vim | One-shot, run once to seed `datasets/vim-2012/` |
| `scrape_vim_pdf.rb` | VIM 2007 / 2010 from pdftotext | One-shot, run once per edition |
| `scrape_vim_1993.rb` | VIM 1993 from OCR HTML | One-shot, run once to seed `datasets/vim-1993/` |
| `viml_edition_scraper.rb` | Shared framework (EditionConfig, ConceptBuilder, DatasetWriter) used by the VIML scrapers | One-shot, retires with the scrapers |
| `regenerate_all_viml_1968.rb` | Bulk regenerate all 276 viml-1968 concepts from OCR | One-shot, run once |
| `generate_missing_viml_1968.rb` | Generate 81 missing viml-1968 concepts from OCR | One-shot, run once |
| `fix_g18_related_placement.rb` | Move `related` to top-level per v3 schema across g18 | One-shot, run once |
| `fix_g18_viml_edition.rb` | g18 dataset edition fixes | One-shot, run once |
| `link_g18_to_vim.rb` | Cross-link g18 concepts to VIM | One-shot, run once |

## If you absolutely must re-run one

If a dataset is catastrophically corrupted and you need to regenerate from
source:

1. Back up the current `datasets/<edition>/` first.
2. Branch off `main`.
3. Run the script against a clean checkout, NOT against editor-curated files.
4. Diff carefully against the backup. Manual edits must be preserved or
   intentionally reconciled.
5. Document the recovery in the commit message and PR description.
6. Get explicit reviewer sign-off before merging.

Under normal operation, **never** run anything in this directory.

## The new model

The active `scripts/` directory contains only read-only tools:

- `validate_datasets.rb` — CI gate, invariant checking
- `audit_vim.rb`, `audit_viml.rb` — read-only audits
- `compare_viml_1968_index.rb` — read-only comparison
- `match_supersedes.rb` — default `--dry-run`; `--write` is opt-in

If you need to fix data, edit the YAML directly with surgical changes. Do not
write a script that loops over `datasets/` and rewrites files.
