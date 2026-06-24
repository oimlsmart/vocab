#!/usr/bin/env ruby
# Generate 81 missing YAML concept files for viml-1968 from OCR markdown.
#
# Usage: ruby scripts/generate_missing_viml_1968.rb

require "yaml"
require "securerandom"
require "set"

# Map concept identifier → term(s) from the alphabetical index
INDEX = {
  "2.5.1" => ["expertise métrologique"],
  "2.7.1" => ["oblitération de la marque de vérification"],
  "3.1" => ["loi relative à la métrologie légale"],
  "3.2" => ["marques d'un instrument de mesurage"],
  "3.3.1" => ["certificat de vérification"],
  "3.3.2" => ["certificat d'étalonnage", "certificat d'expertise"],
  "3.4" => ["inscriptions d'identification d'un instrument de mesurage"],
  "4.4.2" => ["équation entre unités de mesure"],
  "4.7" => ["système d'unités de mesure"],
  "5.2.5.1" => ["méthode de mesurage par comparaison directe"],
  "5.3" => ["indication d'un instrument de mesurage"],
  "5.5.1" => ["reproductibilité des mesurages"],
  "6.3.1" => ["équipement de mesurage"],
  "6.4.10" => ["étalon national"],
  "6.4.11" => ["prototype international", "prototype national"],
  "6.5" => ["schéma d'une hiérarchie des instruments de mesurage"],
  "7.1.2.1" => ["modèle d'un instrument de mesurage"],
  "7.2" => ["schéma de structure"],
  "7.3.1.1" => ["élément récepteur du capteur"],
  "7.3.3.2" => ["repère"],
  "7.4.2.1.1" => ["valeur minimale de l'échelle"],
  "7.4.2.1.2" => ["valeur maximale de l'échelle"],
  "7.4.4.1" => ["base d'une échelle à traits"],
  "7.4.4.2" => ["équation d'une échelle à traits"],
  "7.4.4.2.1" => ["échelle équidistante"],
  "7.4.4.2.2" => ["échelle à valeur d'échelon constante"],
  "7.4.4.2.3" => ["échelle linéaire"],
  "7.4.4.2.4" => ["échelle régulière"],
  "7.4.5.1" => ["échelle semi-numérique"],
  "7.4.5.2" => ["échelle non-linéaire"],
  "8.1.8" => ["incertitude de mesurage"],
  "8.2" => ["erreur instrumentale"],
  "8.2.6.1" => ["erreur complémentaire d'un instrument de mesurage"],
  "8.2.6.1.1" => ["variation d'indication d'un instrument de mesurage"],
  "8.2.6.2" => ["erreur due à la température"],
  "8.2.6.2.1" => ["coefficient de température d'un instrument de mesurage"],
  "8.2.6.3" => ["erreur due au frottement"],
  "8.2.6.4" => ["erreur due à l'inertie"],
  "8.3" => ["erreurs maximales tolérées lors de la vérification"],
  "9.1" => ["conditions usuelles d'emploi"],
  "9.1.1" => ["valeur de référence"],
  "9.1.2" => ["domaine de référence"],
  "9.1.3" => ["conditions de référence"],
  "9.1.4" => ["domaine nominal d'utilisation"],
  "9.2" => ["étendue de mesurage"],
  "9.2.1" => ["portée maximale"],
  "9.2.2" => ["portée minimale"],
  "9.2.3" => ["charge d'un compteur"],
  "9.2.4" => ["étendue de la charge d'un compteur"],
  "9.2.5" => ["charge maximale d'un compteur"],
  "9.2.6" => ["charge minimale d'un compteur"],
  "9.2.7" => ["surcharge d'un instrument de mesurage"],
  "9.2.8" => ["cadence de mesurage maximale", "cadence de mesurage minimale"],
  "9.3" => ["sûreté de lecture d'un instrument de mesurage"],
  "9.4" => ["sensibilité d'un instrument de mesurage"],
  "9.5" => ["justesse d'un instrument de mesurage"],
  "9.5.1" => ["erreur de justesse"],
  "9.5.2" => ["erreurs maximales tolérées de justesse"],
  "9.5.3" => ["correction de justesse"],
  "9.5.4" => ["facteur de correction de justesse"],
  "9.6" => ["fidélité d'un instrument de mesurage"],
  "9.6.1" => ["dispersion des indications"],
  "9.6.2" => ["étendue de dispersion des indications"],
  "9.6.3" => ["erreur de fidélité"],
  "9.6.4" => ["erreurs limites de fidélité"],
  "9.6.5" => ["erreurs maximales tolérées de fidélité"],
  "9.7" => ["réversibilité d'un instrument de mesurage"],
  "9.7.1" => ["erreur de réversibilité"],
  "9.7.2" => ["erreur limite de réversibilité"],
  "9.7.3" => ["erreur maximale tolérée de réversibilité"],
  "9.8" => ["mobilité d'un instrument de mesurage"],
  "9.8.1" => ["erreur de mobilité"],
  "9.8.2" => ["erreur limite de mobilité"],
  "9.8.3" => ["seuil de mobilité"],
  "9.8.4" => ["seuil de démarrage d'un compteur"],
  "9.9" => ["temps de réponse d'un instrument de mesurage"],
  "9.10" => ["précision d'un instrument de mesurage"],
  "9.10.1" => ["erreur de précision"],
  "9.10.2" => ["erreurs limites de précision"],
  "9.10.3" => ["erreurs maximales tolérées de précision"],
  "9.10.4" => ["classe de précision"],
}.freeze

# OCR heading ID → index ID (where they differ)
OCR_ID_MAP = {
  "7.4.4.2.5" => "7.4.5.2",  # échelle non-linéaire
}.freeze

# Section mapping: chapter → section-id
SECTION_MAP = {
  "0" => "section-0",
  "1" => "section-1",
  "2" => "section-2",
  "3" => "section-3",
  "4" => "section-4",
  "5" => "section-5",
  "6" => "section-6",
  "7" => "section-7",
  "8" => "section-8",
  "9" => "section-8",  # Chapter 9 maps to section 8 in YAML
}.freeze

OUTDIR = "datasets/viml-1968/concepts"

# Parse OCR markdown into concept blocks
def parse_ocr(md)
  concepts = {}
  lines = md.split("\n")
  i = 0

  while i < lines.length
    line = lines[i]

    # Match concept headings like "## 9.5.1. ERREUR DE JUSTESSE"
    # Also handle OCR variants: "## 2,4.6.", "## 8.26."
    if (m = line.match(/^##\s+(\d[\d.,]*\d(?:\.\d+)*)\.?\s+(.+)$/i))
      raw_id = m[1].gsub(",", ".")
      term_text = m[2].strip
      raw_id = OCR_ID_MAP.fetch(raw_id, raw_id)

      # Skip if this is a "Remarques" or "Examples" or "Exemples" heading
      if term_text =~ /^(Remarques?|Examples?|Exemples?|Remarque)/i
        i += 1
        next
      end

      # Collect content until next numbered concept heading
      content_lines = []
      i += 1
      while i < lines.length
        # Stop at numbered concept headings (e.g. "## 9.5.1.") or chapter headings
        break if lines[i] =~ /^##\s+\d[\d.,]*\d/
        # Stop at chapter dividers
        break if lines[i] =~ /^#\s+(CHAPITRE|ORGANISMES|INSTRUMENTS|CONDITIONS)/
        # Stop at div tags
        break if lines[i] =~ /^<div\s/
        content_lines << lines[i] unless lines[i] =~ /^!\[/
        i += 1
      end

      content = content_lines.join("\n").strip
      concepts[raw_id] = { term: term_text, content: content }
    else
      i += 1
    end
  end

  concepts
end

# Parse content block into definition, notes, examples
def parse_content(content)
  return { definition: "", notes: [], examples: [] } if content.nil? || content.strip.empty?

  lines = content.split("\n")
  definition_parts = []
  notes = []
  examples = []
  current_section = :definition

  lines.each do |line|
    stripped = line.strip

    if stripped =~ /^##\s*(Remarques?|Remarque\s*:)/i
      current_section = :notes
      next
    elsif stripped =~ /^##\s*(Examples?|Exemples?|Exemple\s*:)/i
      current_section = :examples
      next
    elsif stripped =~ /^Remarque\s*:/i
      # Inline remarque (not a heading)
      note_text = stripped.sub(/^Remarque\s*:\s*/i, "")
      notes << note_text unless note_text.empty?
      current_section = :notes
      next
    elsif stripped.empty?
      next
    end

    case current_section
    when :definition
      definition_parts << stripped
    when :notes
      notes << stripped
    when :examples
      examples << stripped
    end
  end

  {
    definition: definition_parts.join(" "),
    notes: notes,
    examples: examples
  }
end

def generate_uuid
  SecureRandom.uuid
end

def build_yaml(identifier, section_id, terms, definition, notes, examples)
  managed_id = generate_uuid
  localized_id = generate_uuid

  # Build managed concept
  managed = {
    "data" => {
      "identifier" => identifier,
      "localized_concepts" => { "fra" => localized_id },
      "domains" => [
        { "concept_id" => section_id, "source" => "urn:oiml:pub:v:1:1968", "ref_type" => "section" }
      ]
    },
    "status" => "valid",
    "id" => managed_id,
    "schema_version" => "3"
  }

  # Build terms array
  terms_arr = terms.map.with_index do |term, idx|
    { "type" => "expression", "normative_status" => idx == 0 ? "preferred" : "admitted", "designation" => term }
  end

  # Build localized concept
  definition_arr = definition.nil? || definition.strip.empty? ? [] : [{ "content" => definition }]
  notes_arr = notes.map { |n| { "content" => n } }
  examples_arr = examples.map { |e| { "content" => e } }

  localized = {
    "data" => {
      "dates" => [{ "date" => "1968-01-01T00:00:00+00:00", "type" => "accepted" }],
      "definition" => definition_arr,
      "examples" => examples_arr,
      "id" => "#{identifier}-fra",
      "notes" => notes_arr,
      "sources" => [],
      "terms" => terms_arr
    },
    "language_code" => "fra",
    "entry_status" => "valid",
    "date_accepted" => "1968-01-01T00:00:00+00:00",
    "id" => localized_id
  }

  # Render as YAML
  managed_yaml = YAML.dump(managed)
  localized_yaml = YAML.dump(localized).sub(/\A---\n/, "")

  "#{managed_yaml}\n---\n#{localized_yaml}"
end

# Main
md = File.read("/tmp/viml1968_ocr.md")
ocr_concepts = parse_ocr(md)

# Debug: show what we found
puts "Found #{ocr_concepts.size} concept headings in OCR"

# Check which missing IDs we can find
missing_ids = INDEX.keys.to_set
found = 0
not_found = []

missing_ids.sort_by { |k| k.split(".").map(&:to_i) }.each do |id|
  parsed = parse_content(ocr_concepts[id]&.dig(:content))

  if parsed[:definition].empty?
    # Try to find with OCR quirks
    # The OCR might have different numbering format
    alt_ids = []
    # Try with trailing dot variations
    alt_ids << id

    found_alt = nil
    alt_ids.each do |aid|
      if ocr_concepts[aid] && !parse_content(ocr_concepts[aid][:content])[:definition].empty?
        found_alt = aid
        break
      end
    end

    if found_alt
      parsed = parse_content(ocr_concepts[found_alt][:content])
    else
      not_found << id
      next
    end
  end

  found += 1
  chapter = id.split(".").first
  section_id = SECTION_MAP[chapter] || "section-#{chapter}"
  terms = INDEX[id]
  definition = parsed[:definition]
  notes = parsed[:notes]
  examples = parsed[:examples]

  yaml_content = build_yaml(id, section_id, terms, definition, notes, examples)
  filepath = File.join(OUTDIR, "#{id}.yaml")
  File.write(filepath, yaml_content)
  puts "  Created: #{id}.yaml (#{terms.first})"
end

puts ""
puts "Created: #{found} files"
puts "Not found in OCR: #{not_found.size}" unless not_found.empty?
not_found.each { |id| puts "  #{id}: #{INDEX[id].join('; ')}" }
