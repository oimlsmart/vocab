#!/bin/bash
# Patches concept-browser for:
#   - {{term,concept_id}} clickable links (math.ts, ConceptDetail.vue)
#   - Cross-dataset source citation links (CitationDisplay.vue)
#   - Keyboard shortcuts: J/K navigation, ? help modal (ConceptView.vue, DatasetView.vue)
#   - Restructured sidebar navigation (AppSidebar.vue)
#   - Search results isolated rendering (SearchBar.vue, SearchResults.vue)
#   - Auto-generates dataset about pages from {localPath}/about.md
# Run after npm install.
set -e
CB="node_modules/@glossarist/concept-browser"
PD="$(dirname "$0")/../patches/concept-browser"

if [ ! -d "$CB/src" ]; then
  echo "concept-browser not installed, skipping patches"
  exit 0
fi

for f in math.ts ConceptDetail.vue CitationDisplay.vue ConceptView.vue DatasetView.vue AppSidebar.vue SearchBar.vue SearchResults.vue; do
  src="$PD/$f"
  case "$f" in
    math.ts) dest="$CB/src/utils/math.ts" ;;
    ConceptDetail.vue) dest="$CB/src/components/ConceptDetail.vue" ;;
    CitationDisplay.vue) dest="$CB/src/components/CitationDisplay.vue" ;;
    ConceptView.vue) dest="$CB/src/views/ConceptView.vue" ;;
    DatasetView.vue) dest="$CB/src/views/DatasetView.vue" ;;
    AppSidebar.vue) dest="$CB/src/components/AppSidebar.vue" ;;
    SearchBar.vue) dest="$CB/src/components/SearchBar.vue" ;;
    SearchResults.vue) dest="$CB/src/components/SearchResults.vue" ;;
  esac
  if [ -f "$src" ] && [ -f "$dest" ] && ! diff -q "$src" "$dest" > /dev/null 2>&1; then
    echo "Patching $f..."
    cp "$src" "$dest"
  elif [ -f "$src" ] && [ ! -f "$dest" ]; then
    echo "Adding $f..."
    cp "$src" "$dest"
  fi
done

# Auto-generate dataset about pages from {localPath}/about.md
if [ -f "$PD/generate-dataset-about-pages.mjs" ]; then
  echo "Generating dataset about pages..."
  node "$PD/generate-dataset-about-pages.mjs"
fi

echo "Patches applied."
