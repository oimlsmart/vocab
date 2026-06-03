#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape VIML 2000 edition (v001-ef00.html) into a Glossarist v3 dataset.
#
# Source: PDF->HTML, bilingual EN/FR with English section first, then French section.
# 44 concepts: 1.1-1.3, 2.1-2.24, 3.1-3.10, 4.1-4.7
# 4 sections (no section 0, 5, or 6).
#
# The HTML has inline CSS that pollutes Nokogiri .text output, so we strip
# <style> elements first. Concept numbers are embedded directly in running
# text (e.g., "1.1metrology") with no separator before the term name.
#
# Usage:
#   cd /path/to/glossarist/glossarist-ruby
#   bundle exec ruby /path/to/oiml-viml/scripts/scrape_viml_2000.rb

require "nokogiri"
require_relative "viml_edition_scraper"

module Viml2000Parser
  # French section markers — text before these is English, after is French.
  FRA_SECTION_MARKERS = [
    "TERMES DE BASE",
    "ACTIVITÉS DE MÉTROLOGIE",
    "ACTIVITES DE METROLOGIE",
    "DOCUMENTS ET MARQUES",
    "UNITÉS ET INSTRUMENTS",
    "UNITES ET INSTRUMENTS",
    "INDEX FRANÇAIS",
  ].freeze

  FRA_SECTION_RE = /(?:#{FRA_SECTION_MARKERS.map { |m| Regexp.escape(m) }.join('|')})/

  def self.parse(html)
    doc = Nokogiri::HTML(html, nil, "utf-8")
    text = clean_text(doc)

    positions = find_concept_positions(text)

    entries = []
    positions.each_with_index do |p, i|
      next_pos = positions[i + 1] ? positions[i + 1][:pos] : text.length
      entry_text = text[p[:pos]..next_pos - 1].strip
      entry_text = entry_text.sub(/\b\d{1,2}\.\d{1,2}\s*\z/, "").strip
      entries << { number: p[:number], text: entry_text, pos: p[:pos] }
    end

    fra_start = find_french_start(text)

    en_entries = []
    fr_entries = []
    entries.each do |entry|
      if entry[:pos] < fra_start
        en_entries << entry
      else
        fr_entries << entry
      end
    end

    concepts = {}
    en_entries.each do |e|
      concepts[e[:number]] ||= {}
      concepts[e[:number]][:eng] = e[:text]
    end
    fr_entries.each do |e|
      concepts[e[:number]] ||= {}
      concepts[e[:number]][:fra] = e[:text]
    end

    result = {}
    concepts.each do |term_id, lang_texts|
      localizations = {}
      if lang_texts[:eng]
        localizations["eng"] = parse_entry(lang_texts[:eng], "eng")
      end
      if lang_texts[:fra]
        localizations["fra"] = parse_entry(lang_texts[:fra], "fra")
      end

      xrefs = extract_xrefs(localizations)
      result[term_id] = { localizations: localizations, cross_refs: xrefs }
    end

    result
  end

  private

  def self.clean_text(doc)
    doc.css("style, script").each(&:remove)
    text = doc.text
    text = text.gsub(/&nbsp;/, " ").gsub(/\xc2\xa0/, " ").gsub(/\s+/, " ").strip
    text
  end

  def self.find_concept_positions(text)
    positions = []
    # Concept numbers in the 2000 HTML are like "1.1metrology" or "2.24sealing"
    # They appear after section headers like "METROLOGY1.1metrology"
    # Match X.X or X.XX preceded by space/start/uppercase and followed by space or letter
    text.scan(/(?:\A|\s)(\d{1,2})\.(\d{1,2})(?=\s|[a-zA-Z])/) do
      match = Regexp.last_match
      number = "#{match[1]}.#{match[2]}"
      pos = match.offset(1)[0]
      prev_char = pos > 0 ? text[pos - 1] : " "
      next if prev_char =~ /[a-z]/
      positions << { pos: pos, number: number }
    end

    positions.uniq { |p| p[:pos] }
  end

  def self.find_french_start(text)
    match = text.match(FRA_SECTION_RE)
    match ? match.offset(0)[0] : text.length
  end

  def self.parse_entry(text, lang)
    return nil unless text

    text = text.sub(/\A\d{1,2}\.\d{1,2}\s*/, "")

    source_ref = nil
    if text =~ /\[([A-Z][^\]]+?)(?:,\s*([^\]]+?))?\]\s*\z/
      source_ref = { ref: $1.strip, clause: $2&.strip }
      text = text.sub(/\[[A-Z][^\]]+?\]\s*\z/, "")
    end

    if !source_ref && text =~ /\[(VIM\s+\d+\.\d+)\]/
      source_ref = { ref: $1.strip, clause: nil }
    end

    term_name, rest = split_term_from_definition(text, lang)
    definition, notes = separate_notes(rest)

    definition = clean_whitespace(definition)
    notes = notes.map { |n| clean_whitespace(n) }

    VimlEditionScraper::ParsedConcept.new(
      term_id: nil,
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
    if text =~ /\A(.+?)\s+((?:[a-zàâéèêëîïôùûü]|de la |de l'|du |des |d'|en |le |la |les ).+)/m
      term = $1.strip
      defn = $2.strip
      if term.length < 100 && term =~ /[A-ZÀÂÉÈÊËÎÏÔÙÛÜ]/
        return [term, defn]
      end
    end

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

    if text =~ /\s+NOTES?\s+/i
      parts = text.split(/\s+NOTES?\s+/i)
      definition = parts.shift.to_s.strip
      note_text = parts.join(" ").strip

      note_parts = note_text.split(/\s+(\d+)\s+/)
      if note_parts[0] && !note_parts[0].empty?
        notes << note_parts.shift
      end
      note_parts.each_slice(2) do |_num, txt|
        notes << txt.strip if txt
      end
    elsif text =~ /\s+Note\s+(?:\d+\s+)?/i
      parts = text.split(/\s+Note\s+(?:\d+\s+)?/i)
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
          t.scan(/\b(\d{1,2})\.(\d{1,2})\b/).each { |m| xrefs << "#{m[0]}.#{m[1]}" }
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

# -- Main --

config = VimlEditionScraper::EditionConfig.new("viml-2000")
builder = VimlEditionScraper::ConceptBuilder.new(config)

puts "Loading #{config.source_file}..."
html = File.read(config.source_file, encoding: "utf-8")

puts "Parsing 2000 edition..."
raw_concepts = Viml2000Parser.parse(html)
puts "Found #{raw_concepts.size} concepts"

managed_concepts = []
errors = []

raw_concepts.each do |term_id, data|
  begin
    data[:localizations].each_value { |d| d.term_id = term_id }
    mc = builder.build_managed_concept(term_id, data[:localizations], data[:cross_refs])
    managed_concepts << mc
    puts "  #{term_id}: OK"
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
