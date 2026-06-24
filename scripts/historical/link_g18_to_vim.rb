#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract VIM/VIML references from G18 concept definitions and add cross-dataset
# `related` entries pointing to the authoritative VIM/VIML definitions.
#
# Usage:
#   ruby scripts/link_g18_to_vim.rb [--dry-run] [--write]
#
# --dry-run  Show what would be changed without modifying files (default)
# --write    Actually modify the G18 concept YAML files

require "yaml"
require "fileutils"
require "optparse"

BASE = File.expand_path("..", __dir__)
G18_CONCEPTS = File.join(BASE, "datasets", "g18", "concepts")

# VIM/VIML edition year → dataset URN mapping
VIM_EDITIONS = {
  "1993" => "urn:oiml:pub:v:2:1993",
  "2007" => "urn:oiml:pub:v:2:2007",
  "2010" => "urn:oiml:pub:v:2:2010",
  "2012" => "urn:oiml:pub:v:2:2012",
}.freeze

VIML_EDITIONS = {
  "2000" => "urn:oiml:pub:v:1:2000",
  "2013" => "urn:oiml:pub:v:1:2013",
  "2022" => "urn:oiml:pub:v:1:2022",
}.freeze

# Regex patterns for VIM references in definition text
# Matches: (VIM:2007, 2.52), [VIM:1993, 5.24], [VIM, 5.21], (adapted from VIM:2007, 2.26)
VIM_PATTERN = /
  VIM:?(?<year>\d{4})?,?\s+
  (?<id>\d+\.\d+)
/x.freeze

# Matches: [VIML, 2.13], VIML under 2.21
VIML_PATTERN = /
  VIML,?\s+(?:under\s+)?
  (?<id>\d+\.\d+)
/x.freeze

# VIM edition dataset paths (for verification)
VIM_DATASETS = {
  "1993" => File.join(BASE, "datasets", "vim-1993", "concepts"),
  "2007" => File.join(BASE, "datasets", "vim-2007", "concepts"),
  "2010" => File.join(BASE, "datasets", "vim-2010", "concepts"),
  "2012" => File.join(BASE, "datasets", "vim-2012", "concepts"),
}.freeze

VIML_DATASETS = {
  "2000" => File.join(BASE, "datasets", "viml-2000", "concepts"),
  "2013" => File.join(BASE, "datasets", "viml-2013", "concepts"),
  "2022" => File.join(BASE, "datasets", "viml-2022", "concepts"),
}.freeze

def parse_arguments
  options = { dry_run: true }
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [--dry-run] [--write]"
    opts.on("--dry-run", "Show changes without modifying files (default)") { options[:dry_run] = true }
    opts.on("--write", "Actually modify G18 concept files") { options[:dry_run] = false }
  end.parse!
  options
end

def concept_exists?(dataset_path, id)
  File.exist?(File.join(dataset_path, "#{id}.yaml"))
end

def extract_vim_refs(definition_texts)
  refs = []

  Array(definition_texts).each do |text|
    next unless text

    # Extract VIM references
    text.scan(VIM_PATTERN) do |match|
      year = match[0]
      id = match[1]
      # Default to 1993 if no year specified (most common in G18)
      year ||= "1993"

      # Normalize ID (remove leading zeros from sub-parts: "4.05" → "4.5")
      normalized_id = id.gsub(/\.(\d+)/) { ".#{$1.to_i}" }

      urn = VIM_EDITIONS[year]
      unless urn
        warn "  Unknown VIM edition year: #{year} for ref #{id}"
        next
      end

      dataset_path = VIM_DATASETS[year]
      exists = concept_exists?(dataset_path, normalized_id)

      refs << { type: "see", urn: urn, id: normalized_id, source: "vim", year: year, exists: exists }
    end

    # Extract VIML references (no year in G18 references, default to 2000)
    # G18:2010 references VIML 2000 concept numbers. VIML 2013 renumbered
    # many concepts (e.g., VIML 2000 2.13 "verification" → VIML 2013 2.09,
    # while VIML 2013 2.13 became "subsequent verification"), so targeting
    # VIML 2013 by number would point to wrong concepts.
    text.scan(VIML_PATTERN) do |match|
      id = match[0]
      year = "2000" # G18:2010 references VIML 2000 concept numbering
      urn = VIML_EDITIONS[year]

      dataset_path = VIML_DATASETS[year]
      resolved_id = id
      exists = concept_exists?(dataset_path, id)

      # VIML uses zero-padded sub-IDs: "2.01" not "2.1". Try zero-padding if not found.
      unless exists
        zero_padded = id.gsub(/\.(\d+)$/) { ".#{$1.rjust(2, '0')}" }
        if zero_padded != id && concept_exists?(dataset_path, zero_padded)
          resolved_id = zero_padded
          exists = true
        end
      end

      refs << { type: "see", urn: urn, id: resolved_id, source: "viml", year: year, exists: exists }
    end
  end

  refs.uniq { |r| "#{r[:urn]}:#{r[:id]}" }
end

def parse_concept_file(path)
  # Glossarist v3 YAML files use --- as document separator
  # First doc: concept-level data (identifier, localized_concepts, sources, domains)
  # Second doc: localized entry data (terms, definition, etc.)
  docs = File.read(path).split(/^---\s*$/).reject { |d| d.strip.empty? }.map { |d| YAML.safe_load(d, permitted_classes: [Date, Time]) }

  concept_data = docs[0] || {}
  entry_data = docs[1] || {}

  identifier = concept_data.dig("data", "identifier")
  definitions = entry_data.dig("data", "definition") || []

  { identifier: identifier, definitions: definitions, concept_data: concept_data }
end

def add_related_to_concept(path, refs, dry_run:)
  content = File.read(path)

  # Parse both YAML documents
  parts = content.split(/^---\s*$/).reject { |p| p.strip.empty? }
  return false if parts.empty?

  concept_yaml = YAML.safe_load(parts[0], permitted_classes: [Date, Time])
  return false unless concept_yaml

  # v3 schema: 'related' is a top-level property, not inside 'data'
  existing_related = concept_yaml["related"] || concept_yaml.dig("data", "related") || []

  # Build new related entries (only for refs that don't already exist)
  existing_keys = existing_related.map { |r| "#{r.dig("ref", "source")}:#{r.dig("ref", "id")}" }.to_set
  new_entries = refs
    .select { |r| r[:exists] }
    .reject { |r| existing_keys.include?("#{r[:urn]}:#{r[:id]}") }
    .map do |r|
      { "type" => r[:type], "ref" => { "source" => r[:urn], "id" => r[:id] } }
    end

  return false if new_entries.empty?

  if dry_run
    new_entries.each do |e|
      puts "  + #{e["type"]} → #{e.dig("ref", "source")}##{e.dig("ref", "id")}"
    end
    return true
  end

  # Add to concept data (top-level per v3 schema)
  concept_yaml["related"] = existing_related + new_entries
  # Clean up any stale data.related to avoid duplication
  concept_yaml["data"]&.delete("related")

  # Reconstruct the file
  new_content = "---\n#{YAML.dump(concept_yaml).sub(/^---\n/, "")}"
  parts[1..].each { |p| new_content << "---\n#{p.strip}\n" }

  File.write(path, new_content)
  true
end

def main
  options = parse_arguments

  puts options[:dry_run] ? "DRY RUN — no files will be modified" : "WRITE MODE — files will be modified"
  puts

  total_files = 0
  total_refs = 0
  missing_concepts = 0

  Dir.glob(File.join(G18_CONCEPTS, "*.yaml")).sort.each do |path|
    basename = File.basename(path, ".yaml")
    parsed = parse_concept_file(path)

    definition_texts = parsed[:definitions].map { |d| d["content"] }
    refs = extract_vim_refs(definition_texts)
    next if refs.empty?

    total_files += 1
    missing = refs.select { |r| !r[:exists] }
    unless missing.empty?
      missing_concepts += missing.size
      missing.each { |r| warn "  WARNING: #{basename} references #{r[:source].upcase}:#{r[:year]} #{r[:id]} but concept not found" }
    end

    changed = add_related_to_concept(path, refs, dry_run: options[:dry_run])
    total_refs += refs.count { |r| r[:exists] } if changed

    if changed || !refs.empty?
      puts "#{basename}: #{refs.size} refs found, #{refs.count { |r| r[:exists] }} valid"
    end
  end

  puts
  puts "Summary: #{total_files} files with VIM/VIML references, #{total_refs} cross-links #{options[:dry_run] ? "would be" : ""} added"
  puts "Missing concepts: #{missing_concepts}" if missing_concepts > 0
end

main
