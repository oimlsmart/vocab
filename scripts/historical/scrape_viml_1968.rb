#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape VIML 1968 edition (v001-f68-ocr.html) into a Glossarist v3 dataset.
#
# Source: OCR PDF→HTML, French only, heavy corruption.
# ~30 concepts with numbering 0.1–0.5, 1.x–6.x.
# French convention: comma separator in numbers (0,1 instead of 0.1).
# OCR errors are prevalent — this scraper applies corrections and flags
# entries needing manual review.
#
# Usage:
#   cd /path/to/glossarist/glossarist-ruby
#   bundle exec ruby /path/to/oiml-vocab/scripts/scrape_viml_1968.rb

require "nokogiri"
require "cgi"
require_relative "viml_edition_scraper"

module Viml1968Parser
  # Common OCR errors in this document and their corrections.
  OCR_CORRECTIONS = {
    "MtTROLOGIE" => "MÉTROLOGIE",
    "m6trologie" => "métrologie",
    "mesurnge" => "mesurage",
    "mesur.1go" => "mesurage",
    "mesuragll" => "mesurages",
    "mesuragll.!!" => "mesurages",
    "rnétrologie" => "métrologie",
    "rnét.J" => "mét",
    "MÉTROLOGIE GtN" => "MÉTROLOGIE GÉN",
    "APPLIQUt:E" => "APPLIQUÉE",
    "M�tROLOGIE" => "MÉTROLOGIE",
    "Mt:TROLOGIE" => "MÉTROLOGIE",
    "METROLOGIE" => "MÉTROLOGIE",
    "métrodologie" => "métrologie",
    "proprî.étds" => "propriétés",
    "proprdété1" => "propriétés",
    "domaln11&" => "domaines",
    "concorn<lnt" => "concernant",
    "llte.blissemeot" => "établissement",
    "co!llleIVation" => "conservation",
    "tranerolsslon" => "transmission",
    "lcuri;" => "leurs",
    "précislon" => "précision",
    "qunlltés" => "qualités",
    "npportant" => "rapportant",
    "lndJcatlons" => "indications",
    "lnstrument.s" => "instruments",
    "probltrnee" => "problèmes",
    "pratl.que.s" => "pratiques",
    "meE1ll'agea" => "mesurages",
    "dlviso" => "divise",
    "rnétrologle" => "métrologie",
    "tecnlque" => "technique",
    "médîcale" => "médicale",
    "compl'lscs" => "comprises",
    "subet.ances" => "substances",
    "la etruclUTe" => "la structure",
    "syrtème" => "système",
    "orrours" => "erreurs",
    "mesur.1go" => "mesurage",
    "remplac6" => "remplacé",
    "appllcation" => "application",
    "exlgmente" => "exigente",
    "r6glement" => "règlement",
    "mesurande" => "mesurande",
    "6talonnage" => "étalonnage",
    "6talon" => "étalon",
    "6talon" => "étalon",
  }.freeze

  # Regex patterns for concept numbers in French convention
  # 0,1. or 0.1. format
  CONCEPT_NUMBER_RE = /(\d{1,2})[,.](\d{1,2})\./

  def self.parse(html)
    text = clean_text(html)
    text = apply_ocr_corrections(text)

    entries = extract_concept_entries(text)

    concepts = {}
    entries.each do |entry|
      term_id = entry[:number]
      parsed = parse_entry(entry[:text], entry[:needs_review])
      next unless parsed

      localizations = { "fra" => parsed }
      xrefs = extract_xrefs(localizations)
      concepts[term_id] = {
        localizations: localizations,
        cross_refs: xrefs,
        needs_review: entry[:needs_review],
      }
    end

    concepts
  end

  private

  def self.clean_text(html)
    doc = Nokogiri::HTML(html, nil, "utf-8")
    text = doc.text
    text = CGI.unescapeHTML(text)
    text.gsub(/&nbsp;/, " ").gsub(/ /, " ").gsub(/\s+/, " ").strip
  end

  def self.apply_ocr_corrections(text)
    OCR_CORRECTIONS.each do |wrong, right|
      text = text.gsub(wrong, right)
    end
    text
  end

  def self.extract_concept_entries(text)
    positions = []
    text.scan(/(?=(\d{1,2})[,.](\d{1,2})\.\s*)/) do
      match = Regexp.last_match
      section = match[1]
      num = match[2]
      pos = match.offset(0)[0]
      term_id = "#{section}.#{num}"
      positions << { pos: pos, number: term_id, raw: match[0] }
    end

    entries = []
    positions.each_with_index do |p, i|
      next_pos = positions[i + 1] ? positions[i + 1][:pos] : text.length
      entry_text = text[p[:pos]..next_pos - 1].strip
      # Remove trailing next concept number
      entry_text = entry_text.sub(/\d{1,2}[,.]\d{1,2}\.\s*\z/, "").strip

      # Detect if entry likely needs review (many non-ASCII anomalies)
      needs_review = entry_text.scan(/[^\x00-\x7F]/).size > entry_text.size * 0.3

      entries << { number: p[:number], text: entry_text, needs_review: needs_review }
    end

    entries
  end

  def self.parse_entry(text, needs_review)
    return nil unless text

    # Remove the leading concept number
    text = text.sub(/\A\d{1,2}[,.]\d{1,2}\.\s*/, "")

    # Term name is typically in ALL CAPS for 1968 edition
    term_name = ""
    if text =~ /\A([A-ZÀÂÉÈÊËÎÏÔÙÛÜÇŒÆ\s]{2,}?)\s+([a-zàâéèêëîïôùûü])/
      term_name = $1.strip
      rest = text[term_name.length..].strip
    else
      # Fallback: first word is term
      if text =~ /\A(\S+)\s+(.+)/
        term_name = $1
        rest = $2
      else
        term_name = text
        rest = ""
      end
    end

    # Split definition and notes (Remarques)
    definition, notes = separate_remarques(rest)

    definition = clean_whitespace(definition)
    notes = notes.map { |n| clean_whitespace(n) }

    # Skip entries with very corrupted text
    if definition.length < 5
      needs_review = true
    end

    VimlEditionScraper::ParsedConcept.new(
      term_id: nil,
      term_name: term_name,
      definition: definition,
      notes: notes,
      examples: [],
      source_ref: nil, # 1968 edition has no structured source refs
      cross_refs: [],
      language_code: "fra",
      admitted_terms: [],
    )
  end

  def self.separate_remarques(text)
    return [text, []] unless text

    if text =~ /\s+Remarques?\s*:/i
      parts = text.split(/\s+Remarques?\s*:/i, 2)
      definition = parts[0].strip
      note_text = parts[1].to_s.strip

      # Split numbered remarks
      note_parts = note_text.split(/\s+(\d+)\s+/)
      notes = []
      if note_parts[0] && !note_parts[0].empty?
        notes << note_parts.shift
      end
      note_parts.each_slice(2) do |_num, txt|
        notes << txt.strip if txt
      end

      [definition, notes]
    else
      [text, []]
    end
  end

  def self.extract_xrefs(localizations)
    xrefs = []
    localizations.each_value do |data|
      next unless data
      [:definition, :notes].each do |field|
        texts = field == :notes ? data.notes : [data.definition]
        Array(texts).each do |t|
          t.scan(/\b(\d{1,2})[,.](\d{1,2})\b/).each { |m| xrefs << "#{m[0]}.#{m[1]}" }
        end
      end
    end
    xrefs.uniq
  end

  def self.clean_whitespace(text)
    return "" unless text
    text.gsub(/\s+/, " ").strip
  end
end

# ── Main ──

config = VimlEditionScraper::EditionConfig.new("viml-1968")
builder = VimlEditionScraper::ConceptBuilder.new(config)

puts "Loading #{config.source_file}..."
html = File.read(config.source_file, encoding: "utf-8")

puts "Parsing 1968 edition (OCR — expect errors, manual review needed)..."
raw_concepts = Viml1968Parser.parse(html)
puts "Found #{raw_concepts.size} concepts"

managed_concepts = []
errors = []
review_needed = []

raw_concepts.each do |term_id, data|
  begin
    data[:localizations].each_value { |d| d.term_id = term_id }
    mc = builder.build_managed_concept(term_id, data[:localizations], data[:cross_refs])
    managed_concepts << mc
    review_marker = data[:needs_review] ? " [REVIEW]" : ""
    puts "  #{term_id}: OK#{review_marker}"
    review_needed << term_id if data[:needs_review]
  rescue => e
    puts "  #{term_id}: ERROR: #{e.message}"
    errors << "#{term_id}: #{e.message}"
  end
end

writer = VimlEditionScraper::DatasetWriter.new(config)
writer.write_all(managed_concepts)

if review_needed.any?
  puts "\nConcepts needing manual review (#{review_needed.size}):"
  review_needed.each { |id| puts "  #{id}" }
end

if errors.any?
  puts "\nErrors (#{errors.size}):"
  errors.each { |e| puts "  #{e}" }
end
