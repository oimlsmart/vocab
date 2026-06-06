# TODO 09: Improve VIM 2007→1993 supersession matching

## Status: DONE (analysis complete — no auto-matching applied)

## Description
60 VIM 2007 concepts lacked supersedes links to VIM 1993. Analysis showed most are
genuinely new concepts with no VIM 1993 predecessor.

## Analysis results
- **Exact designation matches**: 0 (all terms were renamed or are genuinely new)
- **Partial designation matches**: 24 (mostly noise from common words)
- **Definition-similarity matches (Jaccard ≥25%)**: only 5 moderate, 0 strong (≥50%)

### Chapter distribution of unmatched VIM 2007 concepts
- Ch1 (Quantities): 10 unmatched
- Ch2 (Measurements): 32 unmatched (largest group — VIM 2007 greatly expanded this chapter)
- Ch3 (Devices): 1 unmatched
- Ch4 (Properties): 12 unmatched
- Ch5 (Reference): 5 unmatched

### Conclusion
~36 of 60 are genuinely new VIM 2007 concepts. The remaining ~24 could potentially
be matched by a domain expert, but automated matching produced no high-confidence results.
VIM 2007 was a major restructuring that introduced many new concepts and renamed others.

## Files to modify (manual review only)
- `datasets/vim-2007/concepts/*.yaml` — up to 24 concepts could receive supersedes entries
  if a domain expert identifies the correct VIM 1993 predecessors

## Not actionable by script
The definition-similarity matching found only 5 moderate matches (25-43% overlap),
insufficient confidence for automated linking. Manual domain-expert review needed.
