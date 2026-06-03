#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape VIM 2nd edition (1993) from OCR HTML.
#
# Source: reference-docs/v002-ef93-ocr.html
# OCR quality is poor — many typographical errors. Manual review recommended.
#
# HTML structure per concept:
#   p.s31 "1.1"              → concept number
#   p.s31 "(admitted) term"  → admitted term(s) in parens + term name
#   p "definition text"      → definition
#   p.s20 "NOTES"            → notes section header
#   p.s20 "note text"        → note content
#   p.s20 "EXAMPLES"         → examples section header
#   ol/li                     → example items
#
# EN and FR concepts are interleaved.
#
# Usage:
#   ruby scripts/scrape_vim_1993.rb

require "nokogiri"
require "yaml"
require "securerandom"
require "fileutils"

PROJECT_DIR = File.expand_path("..", File.dirname(__FILE__))
SOURCE_FILE = File.join(PROJECT_DIR, "reference-docs", "v002-ef93-ocr.html")
OUTPUT_DIR = File.join(PROJECT_DIR, "datasets/vim-1993")

URN_PREFIX = "urn:jcgm:pub:200:1993"

ConceptEntry = Struct.new(
  :term_id, :term_name, :definition, :notes, :examples,
  :language_code, :admitted_terms,
  keyword_init: true,
)

FRENCH_INDICATORS = /[éèêëàùûôîïç]|,\s*[fm]\s*$|,\s*mp\s*$|,\s*fp\s*$/

def looks_french?(text)
  text =~ FRENCH_INDICATORS ? true : false
end

def concept_number?(text)
  cleaned = text.gsub(/[​‌‍﻿]/, "")
  cleaned =~ /\A\d+\.\d+\z/
end

def parse_all_elements(doc)
  all_els = doc.css("p, ol").select { |el| !el.text.strip.empty? }

  concepts = []
  current = nil

  all_els.each do |el|
    text = el.text.strip

    if concept_number?(text)
      # Normalize: strip invisible chars from concept ID
      id = text.gsub(/[​‌‍﻿]/, "")
      concepts << current if current
      current = { id: id, elements: [] }
      next
    end

    if current
      if el.name == "ol"
        el.css("li").each do |li|
          li_text = li.text.strip
          current[:elements] << li_text unless li_text.empty?
        end
      else
        current[:elements] << text
      end
    end
  end
  concepts << current if current

  concepts
end

def parse_concept(raw)
  elements = raw[:elements]
  return nil if elements.empty?

  # Skip leading cross-reference: "(2.07)", "( 1.03)", "(-)", "(- & 4.21)", "{1.13)"
  first = elements[0]
  if first =~ /\A[({]\s*[^)}]*[)}]\s*\z/ && first !~ /[[:alpha:]]{3,}/
    elements = elements[1..]
    return nil if elements.empty?
    first = elements[0]
  end

  # First element is the term header (admitted terms + term name)
  admitted, term_name = parse_term_header(first)
  return nil if term_name.nil? || term_name.empty?

  # If the next element is a standalone gender marker ("m", "f", "mp", "fp"),
  # append it to the term name and skip it from the body.
  remaining = elements[1..]
  if remaining && !remaining.empty? && remaining[0] =~ /\A[fm]p?\z/
    term_name = "#{term_name}, #{remaining[0]}"
    remaining = remaining[1..]
  end

  lang = looks_french?(term_name) ? "fra" : "eng"

  # Remaining elements are definition, notes, examples
  definition, notes, examples = parse_body(remaining)

  ConceptEntry.new(
    term_id: raw[:id],
    term_name: term_name,
    definition: definition,
    notes: notes,
    examples: examples,
    language_code: lang,
    admitted_terms: admitted,
  )
end

def parse_term_header(text)
  # OCR may swap parentheses for curly braces: "{derived)" instead of "(derived)"
  if text =~ /\A[({]([^)}]*)[)}]\s*(.+)/
    admitted_str = $1
    term_name = $2.strip
    if admitted_str == "-" || admitted_str.empty?
      admitted = []
    else
      admitted = admitted_str.split(/,\s*/).map(&:strip).reject(&:empty?)
    end
    [admitted, term_name]
  else
    [[], text.strip]
  end
end

def parse_body(elements)
  return ["", [], []] unless elements

  definition_parts = []
  notes = []
  examples = []
  current_section = :definition
  current_text = nil

  elements.each do |text|
    # Match section headers, tolerating OCR errors in first 1-3 chars ("î✓OTE" → NOTE)
    stripped = text.strip
    is_notes = stripped =~ /NOTES?\z/i && stripped.length <= 8
    is_examples = stripped =~ /(?:EXAMPLES?|EXEMPLES?)\z/i && stripped.length <= 10

    if is_notes
      finalize_section(notes, examples, current_section, current_text)
      current_section = :notes_header
      current_text = nil
      next
    elsif is_examples
      finalize_section(notes, examples, current_section, current_text)
      current_section = :examples_header
      current_text = nil
      next
    elsif stripped =~ /(?:NOTE|EXEMPLE|EXAMPLE)\s+(.+)/i && stripped.length <= 80
      finalize_section(notes, examples, current_section, current_text)
      current_section = :note
      current_text = $1.strip
      next
    end

    case current_section
    when :definition
      definition_parts << text
    when :notes_header
      current_section = :note
      current_text = text
    when :note
      current_text << " #{text}"
    when :examples_header
      current_section = :example
      current_text = text
    when :example
      current_text << " #{text}"
    end
  end

  finalize_section(notes, examples, current_section, current_text)

  [definition_parts.join(" ").strip, notes, examples]
end

def finalize_section(notes, examples, section, text)
  return unless text
  case section
  when :note then notes << text
  when :example then examples << text
  end
end

# ═══════════════════════════════════════════════════════════════
# Phase 2: Build Glossarist v3 YAML
# ═══════════════════════════════════════════════════════════════

def section_for(term_id)
  term_id[/\A(\d+)/, 1]
end

def build_localized_yaml(data)
  {
    "data" => {
      "dates" => [{ "date" => "1993-01-01T00:00:00+00:00", "type" => "accepted" }],
      "definition" => data.definition && !data.definition.empty? ?
        [{ "content" => data.definition }] : [],
      "examples" => data.examples.map { |e| { "content" => e } },
      "id" => "#{data.term_id}-#{data.language_code}",
      "language_code" => data.language_code,
      "notes" => data.notes.map { |n| { "content" => n } },
      "terms" => build_terms_yaml(data),
    },
    "date_accepted" => "1993-01-01T00:00:00+00:00",
    "entry_status" => "valid",
  }
end

def build_terms_yaml(data)
  terms = []
  if data.term_name && !data.term_name.empty?
    terms << { "type" => "expression", "normative_status" => "preferred", "designation" => data.term_name }
  end
  data.admitted_terms.each do |alt|
    terms << { "type" => "expression", "normative_status" => "admitted", "designation" => alt }
  end
  terms
end

def build_concept_file(term_id, eng_data, fra_data)
  concept_uuid = SecureRandom.uuid
  eng_uuid = SecureRandom.uuid
  fra_uuid = SecureRandom.uuid

  localized = {}
  localized["eng"] = eng_uuid if eng_data
  localized["fra"] = fra_uuid if fra_data

  managed = {
    "data" => {
      "identifier" => term_id,
      "localized_concepts" => localized,
      "domains" => [{
        "concept_id" => "section-#{section_for(term_id)}",
        "source" => URN_PREFIX,
        "ref_type" => "domain",
      }],
    },
    "status" => "valid",
    "id" => concept_uuid,
    "schema_version" => "3",
  }

  docs = [managed]

  if eng_data
    eng_yaml = build_localized_yaml(eng_data)
    eng_yaml["id"] = eng_uuid
    docs << eng_yaml
  end

  if fra_data
    fra_yaml = build_localized_yaml(fra_data)
    fra_yaml["id"] = fra_uuid
    docs << fra_yaml
  end

  docs.map { |d| YAML.dump(d) }.join
end

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

unless File.exist?(SOURCE_FILE)
  puts "ERROR: Source file not found: #{SOURCE_FILE}"
  exit 1
end

puts "Parsing #{SOURCE_FILE}..."
doc = Nokogiri::HTML(File.read(SOURCE_FILE, encoding: "utf-8"), nil, "utf-8")

raw_concepts = parse_all_elements(doc)
puts "Found #{raw_concepts.size} raw concept blocks"

# In the OCR HTML, concepts are interleaved: first occurrence is EN, second is FR.
# Track occurrence count per concept ID.
occurrence_count = Hash.new(0)

eng_concepts = {}
fra_concepts = {}

raw_concepts.each do |raw|
  concept = parse_concept(raw)
  next unless concept
  next unless concept.term_name && !concept.term_name.empty?
  next unless concept.term_name.match?(/[[:alpha:]]/)

  occurrence_count[concept.term_id] += 1
  n = occurrence_count[concept.term_id]

  if n == 2
    # Second occurrence is always FR
    concept.language_code = "fra"
    fra_concepts[concept.term_id] = concept
  else
    # First (or only) occurrence — use term name to detect language
    lang = looks_french?(concept.term_name) ? "fra" : "eng"
    concept.language_code = lang
    if lang == "eng"
      eng_concepts[concept.term_id] = concept
    else
      fra_concepts[concept.term_id] = concept
    end
  end
end

puts "Found #{eng_concepts.size} English, #{fra_concepts.size} French concepts"

concepts_dir = File.join(OUTPUT_DIR, "concepts")
FileUtils.rm_rf(concepts_dir)
FileUtils.mkdir_p(concepts_dir)

all_ids = (eng_concepts.keys + fra_concepts.keys).uniq.sort_by { |id|
  section, num = id.split(".", 2)
  [section.to_i, num.to_i]
}

concept_ids = []
stats = { concepts: 0, eng: 0, fra: 0, notes: 0, examples: 0 }

all_ids.each_with_index do |term_id, idx|
  printf("[%3d/%d] %s ", idx + 1, all_ids.size, term_id)

  eng_data = eng_concepts[term_id]
  fra_data = fra_concepts[term_id]

  unless eng_data || fra_data
    puts "SKIP"
    next
  end

  yaml = build_concept_file(term_id, eng_data, fra_data)
  File.write(File.join(concepts_dir, "#{term_id}.yaml"), yaml, encoding: "utf-8")
  concept_ids << term_id

  stats[:concepts] += 1
  stats[:eng] += 1 if eng_data
  stats[:fra] += 1 if fra_data
  stats[:notes] += eng_data&.notes&.size || 0
  stats[:examples] += eng_data&.examples&.size || 0

  lang = eng_data && fra_data ? "EN+FR" : (eng_data ? "EN" : "FR")
  n = eng_data&.notes&.size || 0
  e = eng_data&.examples&.size || 0
  puts "OK #{lang} (#{n}n, #{e}e)"
end

register = {
  "schema_version" => "3",
  "concepts" => concept_ids.sort_by { |id|
    section, num = id.split(".", 2)
    [section.to_i, num.to_i]
  },
}
File.write(File.join(OUTPUT_DIR, "register.yaml"), YAML.dump(register), encoding: "utf-8")

puts
puts "Stats: #{stats[:concepts]} concepts, #{stats[:eng]} EN, #{stats[:fra]} FR"
puts "Done! #{concept_ids.size} concepts saved to #{OUTPUT_DIR}/."
puts "NOTE: OCR-derived dataset — contains typographical errors. Manual review recommended."
