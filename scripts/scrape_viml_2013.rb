#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape VIML 2013 edition (V001-ef13.html) into a Glossarist v3 dataset.
#
# Source: Word HTML export, bilingual EN/FR interleaved.
# Structure: each concept appears twice — English then French — with the same number.
# Pattern per entry: [number] [term] [definition] Note [notes] [source]
#
# Usage:
#   cd /path/to/glossarist/glossarist-ruby
#   bundle exec ruby /path/to/oiml-viml/scripts/scrape_viml_2013.rb

require "nokogiri"
require_relative "viml_edition_scraper"

module Viml2013Parser
  CONCEPT_NUMBER_RE = /\b(\d{1,2}\.\d{2})\b/

  def self.parse(html)
    doc = Nokogiri::HTML(html, nil, "utf-8")
    text = clean_text(doc)

    entries = split_into_entries(text)
    grouped = group_by_concept(entries)

    concepts = {}
    grouped.each do |term_id, lang_entries|
      eng = lang_entries[:eng]
      fra = lang_entries[:fra]

      localizations = {}
      localizations["eng"] = parse_entry(eng, "eng") if eng
      localizations["fra"] = parse_entry(fra, "fra") if fra

      xrefs = extract_xrefs(localizations)
      concepts[term_id] = { localizations: localizations, cross_refs: xrefs }
    end

    concepts
  end

  private

  def self.clean_text(doc)
    text = doc.text
    text = text.gsub(/&nbsp;/, " ")
    text = text.gsub(/ /, " ")
    text = text.gsub(/\s+/, " ")
    text.strip
    text
  end

  def self.split_into_entries(text)
    positions = []
    text.scan(/(?=\b(\d{1,2}\.\d{2})\b)/) do |match|
      m = Regexp.last_match
      pos = m.offset(0)[0]
      number = match[0]
      # Skip the Word version number 16.00
      next if number == "16.00"
      positions << { pos: pos, number: number }
    end

    entries = []
    positions.each_with_index do |p, i|
      next_pos = positions[i + 1] ? positions[i + 1][:pos] : text.length
      entry_text = text[p[:pos]..next_pos - 1].strip
      # Remove the trailing number of the next entry
      entry_text = entry_text.sub(/\b\d{1,2}\.\d{2}\z/, "").strip
      entries << { number: p[:number], text: entry_text } unless entry_text.empty?
    end

    entries
  end

  def self.group_by_concept(entries)
    grouped = {}
    entries.each do |entry|
      num = entry[:number]
      grouped[num] ||= {}
      if grouped[num][:eng]
        grouped[num][:fra] = entry[:text]
      else
        grouped[num][:eng] = entry[:text]
      end
    end
    grouped
  end

  def self.parse_entry(text, lang)
    return nil unless text

    # Remove the leading concept number
    text = text.sub(/\A\d{1,2}\.\d{2}\s*/, "")

    # Extract source reference: [ref, clause] at end
    source_ref = nil
    if text =~ /\[(OIML[^,\]]+?)(?:,\s*([^\]]+?))?\]\s*\z/
      source_ref = { ref: $1.strip, clause: $2&.strip }
      text = text.sub(/\[(OIML[^,\]]+?)(?:,\s*([^\]]+?))?\]\s*\z/, "")
    elsif text =~ /\[(VIM\s*[^\]]+?)\]\s*\z/
      source_ref = { ref: $1.strip, clause: nil }
      text = text.sub(/\[(VIM\s*[^\]]+?)\]\s*\z/, "")
    end

    # Split into term + definition + notes
    # Term is the first "phrase" — ends at the first lowercase word or known pattern
    term_name, rest = split_term_from_definition(text, lang)

    # Extract notes
    definition, notes = separate_notes(rest)

    # Clean up
    definition = clean_whitespace(definition)
    notes = notes.map { |n| clean_whitespace(n) }

    VimlEditionScraper::ParsedConcept.new(
      term_id: nil, # set by caller
      term_name: term_name,
      definition: definition,
      notes: notes,
      examples: [],
      source_ref: source_ref,
      cross_refs: [],
      language_code: lang,
      admitted_terms: [],
    )
  end

  def self.split_term_from_definition(text, lang)
    # Term name is followed by the definition which starts with lowercase
    # For English: "metrology science of measurement..."
    # For French: "métrologie science des mesurages..."
    # The term ends and definition begins at the first lowercase word after initial capitalized words

    # Try splitting at first lowercase word boundary
    if text =~ /\A(.+?)\s+((?:[a-zàâéèêëîïôùûü]|de la |de l'|du |des |d'|en |le |la |les ).+)/m
      term = $1.strip
      defn = $2.strip
      # Verify term is reasonable (not too long, contains capitalized words)
      if term.length < 100 && term =~ /[A-ZÀÂÉÈÊËÎÏÔÙÛÜ]/
        return [term, defn]
      end
    end

    # Fallback: first word is term, rest is definition
    if text =~ /\A(\S+)\s+(.+)/
      [$1, $2]
    else
      [text, ""]
    end
  end

  def self.separate_notes(text)
    return [text, []] unless text

    notes = []
    definition = text

    # Extract numbered notes: "Note 1 ... Note 2 ..."
    # Also handle "Note ..." (unnumbered) and "Notes ..." (plural)
    note_pattern = /\s+Note\s+(?:\d+\s+)?/i
    if text =~ note_pattern
      parts = text.split(note_pattern)
      definition = parts.shift.to_s.strip
      notes = parts.map(&:strip).reject(&:empty?)
    end

    [definition, notes]
  end

  def self.extract_xrefs(localizations)
    xrefs = []
    localizations.each_value do |data|
      next unless data
      [:definition, :notes].each do |field|
        texts = field == :notes ? data.notes : [data.definition]
        Array(texts).each do |t|
          t.scan(/\b(\d{1,2}\.\d{2})\b/).each { |m| xrefs << m[0] }
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

config = VimlEditionScraper::EditionConfig.new("viml-2013")
builder = VimlEditionScraper::ConceptBuilder.new(config)

puts "Loading #{config.source_file}..."
html = File.read(config.source_file, encoding: "utf-8")

puts "Parsing 2013 edition..."
raw_concepts = Viml2013Parser.parse(html)
puts "Found #{raw_concepts.size} concepts"

managed_concepts = []
errors = []

raw_concepts.each do |term_id, data|
  begin
    data[:localizations].each_value { |d| d.term_id = term_id }
    mc = builder.build_managed_concept(term_id, data[:localizations], data[:cross_refs])
    managed_concepts << mc
    puts "  #{term_id}: #{managed_concepts.last.data.id} OK"
  rescue => e
    puts "  #{term_id}: ERROR: #{e.message}"
    errors << "#{term_id}: #{e.message}"
  end
end

writer = VimlEditionScraper::DatasetWriter.new(config)
writer.write_all(managed_concepts)

if errors.any?
  puts "\nErrors (#{errors.size}):"
  errors.each { |e| puts "  #{e}" }
end
