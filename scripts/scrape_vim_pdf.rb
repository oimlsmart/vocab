#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape VIM 3rd edition (2007/2010) from pdftotext output.
#
# The OIML V 2-200 editions have interleaved bilingual layout:
# Chapter 1 EN (first concept), Chapitre 1 FR (first concept),
# then EN concepts 1.2, 1.3, ..., then FR concepts 1.2, 1.3, ...
#
# Language is detected per concept from the term name content.
#
# Usage:
#   ruby scripts/scrape_vim_pdf.rb EDITION
#
# EDITION: 2007 or 2010

require "yaml"
require "securerandom"
require "fileutils"

PROJECT_DIR = File.expand_path("..", File.dirname(__FILE__))
REFERENCE_DIR = File.join(PROJECT_DIR, "reference-docs")

EDITIONS = {
  "2007" => {
    source_file: "v002-200-e07.txt",
    urn_prefix: "urn:jcgm:pub:200:2007",
    ref: "JCGM 200:2007",
    ref_aliases: ["OIML V 2-200:2007"],
    dataset_path: "datasets/vim-2007",
    year: 2007,
  },
  "2010" => {
    source_file: "v002-200-e10.txt",
    urn_prefix: "urn:jcgm:pub:200:2010",
    ref: "JCGM 200:2010",
    ref_aliases: ["OIML V 2-200:2010"],
    dataset_path: "datasets/vim-2010",
    year: 2010,
  },
}.freeze

TERM_IDS = [
  *(1..30).map { |n| "1.#{n}" },
  *(1..53).map { |n| "2.#{n}" },
  *(1..12).map { |n| "3.#{n}" },
  *(1..31).map { |n| "4.#{n}" },
  *(1..18).map { |n| "5.#{n}" },
].freeze

# ═══════════════════════════════════════════════════════════════
# Phase 1: Parse pdftotext output
# ═══════════════════════════════════════════════════════════════

ConceptEntry = Struct.new(
  :term_id, :term_name, :definition, :notes, :examples,
  :language_code, :admitted_terms, :prev_ed_id,
  keyword_init: true,
)

# French text indicators (for language detection)
FRENCH_INDICATORS = /[éèêëàùûôîïç]|,\s*[fm]\s*$|,\s*mp\s*$|,\s*fp\s*$/

def looks_french?(text)
  return false unless text
  return true if text =~ FRENCH_INDICATORS
  false
end

def detect_language(term_name, definition)
  return "eng" unless term_name
  return "fra" if looks_french?(term_name)
  return "eng" unless term_name =~ /\A[.\s]+\z/  # dots-only term is ambiguous
  # Fall back to definition text for ambiguous terms
  return "fra" if definition && looks_french?(definition)
  "eng"
end

def find_content_boundaries(lines)
  # Find where actual chapter content starts (after TOC)
  content_start = nil
  content_end = nil

  lines.each_with_index do |line, i|
    stripped = line.strip
    next if i < 600 # Skip TOC

    if content_start.nil? && stripped =~ /\AChapter 1:/
      content_start = i
    end

    if content_start && stripped =~ /\ABibliography\b/ && i > 5000
      content_end = i
      break
    end
  end

  { start: content_start || 0, end: content_end || lines.size }
end

def find_concept_headers(lines, start_line, end_line)
  headers = []
  lines[start_line...end_line].each_with_index do |line, offset|
    i = start_line + offset
    stripped = line.strip
    # Match "N.N" or "N.N (O.N)" or "N.N (O.N, Note X)"
    if stripped =~ /\A([0-5]\.\d+)(?:\s*\(([^)]+)\))?\z/
      headers << { line: i, id: $1, prev_ed: $2 }
    end
  end
  headers
end

def parse_body(body_lines)
  definition_parts = []
  notes = []
  examples = []
  admitted_terms = []
  current_section = :definition
  current_text = nil

  body_lines.each do |line|
    if line =~ /\ANOTE\s+(\d+)\s+(.+)/i
      finalize_section(notes, examples, current_section, current_text)
      current_section = :note
      current_text = $2.strip
      next
    elsif line =~ /\ANOTE\s+(.+)/i
      finalize_section(notes, examples, current_section, current_text)
      current_section = :note
      current_text = $1.strip
      next
    elsif line =~ /\A(EXAMPLES?|EXEMPLES?)\s*(.*)/i
      finalize_section(notes, examples, current_section, current_text)
      current_section = :example
      current_text = $2.strip.empty? ? nil : $2.strip
      next
    elsif line =~ /\A(EXAMPLE|EXEMPLE)\s+(.+)/i
      finalize_section(notes, examples, current_section, current_text)
      current_section = :example
      current_text = $2.strip
      next
    end

    if current_section == :definition
      definition_parts << line
    elsif current_text
      current_text << " #{line}"
    else
      current_text = line
    end
  end

  finalize_section(notes, examples, current_section, current_text)

  # Separate admitted terms from definition
  definition, admitted = extract_admitted_terms(definition_parts)

  [definition, notes, examples, admitted]
end

def extract_admitted_terms(parts)
  return ["", []] if parts.empty?

  admitted = []
  defn_start = 0

  parts.each_with_index do |part, idx|
    if looks_like_definition?(part)
      defn_start = idx
      break
    end
    admitted << part
  end

  if admitted.size == parts.size
    return [parts.join(" ").strip, []]
  end

  definition = parts[defn_start..].join(" ").strip
  [definition, admitted]
end

def looks_like_definition?(text)
  return true if text.length > 25
  return true if text =~ /\b(is|are|was|were|has|have|can|may|where|which|that|qui|que)\b/i
  return true if text =~ /\A(the|a|an|le|la|les|un|une|des|ensemble)\s/i
  return true if text =~ /\b(defined|property of|set of|ratio of|realization of)\b/i
  false
end

def finalize_section(notes, examples, section, text)
  return unless text

  case section
  when :note then notes << text
  when :example then examples << text
  end
end

def parse_concept(lines, header_line, next_header_line, end_line)
  term_id = lines[header_line].strip[/(\A[0-5]\.\d+)/, 1]
  prev_ed_id = lines[header_line].strip[/\(([^)]+)\)/, 1]

  # Collect all lines until next concept header or end
  body_lines = []
  i = header_line + 1

  while i < end_line
    l = lines[i]&.strip

    # Stop at next concept header
    break if l =~ /\A([0-5]\.\d+)(?:\s*\([^)]+\))?\z/
    # Skip page numbers
    if l =~ /\A\d+\z/
      i += 1
      next
    end
    # Skip page separators and footers
    if l =~ /OIML V 2-200/ || l =~ /JCGM 200:/ || l =~ /ISO Guide 99/
      i += 1
      next
    end
    # Skip long underscore separator lines
    if l =~ /\A_{10,}\z/
      i += 1
      next
    end
    # Skip French chapter headers
    if l =~ /\AChapitre\s+\d/
      i += 1
      next
    end
    # Skip English chapter headers
    if l =~ /\AChapter\s+\d/
      i += 1
      next
    end
    # Skip empty lines
    if l.empty?
      i += 1
      next
    end

    body_lines << l
    i += 1
  end

  return nil if body_lines.empty?

  # First line is the preferred term
  term_name = body_lines[0]

  # The rest is definition, notes, examples
  definition, notes, examples, admitted = parse_body(body_lines[1..])

  lang = detect_language(term_name, definition)

  ConceptEntry.new(
    term_id: term_id,
    term_name: term_name,
    definition: definition,
    notes: notes,
    examples: examples,
    language_code: lang,
    admitted_terms: admitted,
    prev_ed_id: prev_ed_id,
  )
end

def parse_all(lines)
  boundaries = find_content_boundaries(lines)
  headers = find_concept_headers(lines, boundaries[:start], boundaries[:end])

  eng_concepts = {}
  fra_concepts = {}

  headers.each_with_index do |header, idx|
    next_header_line = headers[idx + 1]&.dig(:line) || boundaries[:end]

    concept = parse_concept(lines, header[:line], next_header_line, boundaries[:end])
    next unless concept

    if concept.language_code == "eng"
      eng_concepts[concept.term_id] = concept
    else
      fra_concepts[concept.term_id] = concept
    end
  end

  [eng_concepts, fra_concepts]
end

# ═══════════════════════════════════════════════════════════════
# Phase 2: Build Glossarist v3 YAML
# ═══════════════════════════════════════════════════════════════

def section_for(term_id)
  term_id[/\A(\d+)/, 1]
end

def build_localized_yaml(data, year)
  {
    "data" => {
      "dates" => [{ "date" => "#{year}-01-01T00:00:00+00:00", "type" => "accepted" }],
      "definition" => data.definition && !data.definition.empty? ?
        [{ "content" => data.definition }] : [],
      "examples" => data.examples.map { |e| { "content" => e } },
      "id" => "#{data.term_id}-#{data.language_code}",
      "language_code" => data.language_code,
      "notes" => data.notes.map { |n| { "content" => n } },
      "terms" => build_terms_yaml(data),
    },
    "date_accepted" => "#{year}-01-01T00:00:00+00:00",
    "entry_status" => "valid",
  }
end

def build_terms_yaml(data)
  terms = []

  if data.term_name && !data.term_name.empty?
    terms << {
      "type" => "expression",
      "normative_status" => "preferred",
      "designation" => data.term_name,
    }
  end

  data.admitted_terms.each do |alt|
    terms << {
      "type" => "expression",
      "normative_status" => "admitted",
      "designation" => alt,
    }
  end

  terms
end

def build_concept_file(term_id, eng_data, fra_data, edition_config)
  concept_uuid = SecureRandom.uuid
  eng_uuid = SecureRandom.uuid
  fra_uuid = SecureRandom.uuid

  localized = { "eng" => eng_uuid }
  localized["fra"] = fra_uuid if fra_data

  managed = {
    "data" => {
      "identifier" => term_id,
      "localized_concepts" => localized,
      "domains" => [{
        "concept_id" => "section-#{section_for(term_id)}",
        "source" => edition_config[:urn_prefix],
        "ref_type" => "domain",
      }],
    },
    "status" => "valid",
    "id" => concept_uuid,
    "schema_version" => "3",
  }

  eng_yaml = build_localized_yaml(eng_data, edition_config[:year])
  eng_yaml["id"] = eng_uuid

  docs = [managed, eng_yaml]

  if fra_data
    fra_yaml = build_localized_yaml(fra_data, edition_config[:year])
    fra_yaml["id"] = fra_uuid
    docs << fra_yaml
  end

  docs.map { |d| YAML.dump(d) }.join
end

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

edition_key = ARGV[0]
unless edition_key && EDITIONS.key?(edition_key)
  puts "Usage: ruby scripts/scrape_vim_pdf.rb EDITION"
  puts "  EDITION: #{EDITIONS.keys.join(", ")}"
  exit 1
end

edition_config = EDITIONS[edition_key]
source_path = File.join(REFERENCE_DIR, edition_config[:source_file])
output_dir = File.join(PROJECT_DIR, edition_config[:dataset_path])

unless File.exist?(source_path)
  puts "ERROR: Source file not found: #{source_path}"
  exit 1
end

puts "Parsing #{source_path}..."
lines = File.read(source_path, encoding: "utf-8").split("\n")

eng_concepts, fra_concepts = parse_all(lines)
puts "Found #{eng_concepts.size} English concepts, #{fra_concepts.size} French concepts"

concepts_dir = File.join(output_dir, "concepts")
FileUtils.mkdir_p(concepts_dir)

concept_ids = []
stats = { concepts: 0, eng: 0, fra: 0, notes: 0, examples: 0 }

TERM_IDS.each_with_index do |term_id, idx|
  printf("[%3d/%d] %s ", idx + 1, TERM_IDS.size, term_id)

  eng_data = eng_concepts[term_id]
  fra_data = fra_concepts[term_id]

  unless eng_data || fra_data
    puts "SKIP (no data)"
    next
  end

  yaml = build_concept_file(term_id, eng_data, fra_data, edition_config)
  File.write(File.join(concepts_dir, "#{term_id}.yaml"), yaml, encoding: "utf-8")
  concept_ids << term_id

  stats[:concepts] += 1
  stats[:eng] += 1 if eng_data
  stats[:fra] += 1 if fra_data
  stats[:notes] += eng_data&.notes&.size || 0
  stats[:examples] += eng_data&.examples&.size || 0

  lang = fra_data ? "EN+FR" : (eng_data ? "EN" : "FR")
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
File.write(File.join(output_dir, "register.yaml"), YAML.dump(register), encoding: "utf-8")

puts
puts "Stats: #{stats[:concepts]} concepts, #{stats[:eng]} EN, #{stats[:fra]} FR"
puts "Done! #{concept_ids.size} concepts saved to #{output_dir}/."
