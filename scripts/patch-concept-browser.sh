#!/bin/bash
# Patches concept-browser for:
#   - {{term,concept_id}} clickable links (math.ts, ConceptDetail.vue)
#   - Cross-dataset source citation links (CitationDisplay.vue)
#   - Keyboard shortcuts: J/K navigation, ? help modal (ConceptView.vue, DatasetView.vue)
# Run after npm install.
set -e
CB="node_modules/@glossarist/concept-browser"
PD="$(dirname "$0")/../patches/concept-browser"

if [ ! -d "$CB/src" ]; then
  echo "concept-browser not installed, skipping patches"
  exit 0
fi

for f in math.ts ConceptDetail.vue CitationDisplay.vue ConceptView.vue DatasetView.vue; do
  src="$PD/$f"
  case "$f" in
    math.ts) dest="$CB/src/utils/math.ts" ;;
    ConceptDetail.vue) dest="$CB/src/components/ConceptDetail.vue" ;;
    CitationDisplay.vue) dest="$CB/src/components/CitationDisplay.vue" ;;
    ConceptView.vue) dest="$CB/src/views/ConceptView.vue" ;;
    DatasetView.vue) dest="$CB/src/views/DatasetView.vue" ;;
  esac
  if [ -f "$src" ] && [ -f "$dest" ] && ! diff -q "$src" "$dest" > /dev/null 2>&1; then
    echo "Patching $f..."
    cp "$src" "$dest"
  fi
done

echo "Patches applied."
