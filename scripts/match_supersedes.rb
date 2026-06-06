#!/usr/bin/env ruby
# frozen_string_literal: true

# Match concepts across VIM/VIML editions by term designation to generate
# missing supersedes relationships.
#
# Usage:
#   ruby scripts/match_supersedes.rb [--dry-run] [--write] [--edition PAIR]
#
# --dry-run       Show what would be changed (default)
# --write         Actually modify concept YAML files
# --edition PAIR  Only process a specific pair (e.g., "viml-2013/viml-2000")
#
# Edition pairs processed (newer → older):
#   viml-2022/viml-2013   (135→135, VIML current → 2013)
#   viml-2013/viml-2000   (135→44, VIML 2013 → 2000)
#   viml-2000/viml-1968   (44→~30, VIML 2000 → 1968)
#   vim-2012/vim-2010     (144→143, VIM current → 2010)
#   vim-2010/vim-2007     (143→143, VIM 2010 → 2007)
#   vim-2007/vim-1993     (143→120, VIM 2007 → 1993)

require "yaml"
require "optparse"

BASE = File.expand_path("..", __dir__)

# Edition pair definitions: [newer_dataset, older_dataset, newer_urn, older_urn]
EDITION_PAIRS = [
  {
    newer: "viml-2022", older: "viml-2013",
    newer_urn: "urn:oiml:pub:v:1:2022", older_urn: "urn:oiml:pub:v:1:2013",
  },
  {
    newer: "viml-2013", older: "viml-2000",
    newer_urn: "urn:oiml:pub:v:1:2013", older_urn: "urn:oiml:pub:v:1:2000",
  },
  {
    newer: "viml-2000", older: "viml-1968",
    newer_urn: "urn:oiml:pub:v:1:2000", older_urn: "urn:oiml:pub:v:1:1968",
  },
  {
    newer: "vim-2012", older: "vim-2010",
    newer_urn: "urn:oiml:pub:v:2:2012", older_urn: "urn:oiml:pub:v:2:2010",
  },
  {
    newer: "vim-2010", older: "vim-2007",
    newer_urn: "urn:oiml:pub:v:2:2010", older_urn: "urn:oiml:pub:v:2:2007",
  },
  {
    newer: "vim-2007", older: "vim-1993",
    newer_urn: "urn:oiml:pub:v:2:2007", older_urn: "urn:oiml:pub:v:2:1993",
  },
].freeze

def parse_arguments
  options = { dry_run: true, edition: nil }
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [--dry-run] [--write] [--edition PAIR]"
    opts.on("--dry-run", "Show changes without modifying files") { options[:dry_run] = true }
    opts.on("--write", "Actually modify concept files") { options[:dry_run] = false }
    opts.on("--edition PAIR", "Only process a specific pair (e.g., vim-2007/vim-1993)") { |v| options[:edition] = v }
  end.parse!
  options
end

def load_concept(path)
  parts = File.read(path).split(/^---\s*$/).reject { |p| p.strip.empty? }
  return nil if parts.empty?

  concept_data = YAML.safe_load(parts[0], permitted_classes: [Date, Time])
  entry_data = parts.size > 1 ? YAML.safe_load(parts[1], permitted_classes: [Date, Time]) : {}
  entry_data ||= {}

  identifier = concept_data.dig("data", "identifier") || File.basename(path, ".yaml")

  # Extract English preferred designation
  terms = entry_data.dig("data", "terms") || []
  preferred_term = terms.find { |t| t["normative_status"] == "preferred" && t["type"] == "expression" }
  designation = preferred_term&.dig("designation")&.downcase&.strip

  # Extract existing supersedes refs (to skip already-linked concepts)
  related = concept_data.dig("data", "related") || []
  existing_supersedes = related
    .select { |r| r["type"] == "supersedes" }
    .map { |r| r.dig("ref", "id") }

  {
    identifier: identifier,
    designation: designation,
    existing_supersedes: existing_supersedes,
    path: path,
  }
end

def load_dataset_terms(dataset_name)
  concepts_dir = File.join(BASE, "datasets", dataset_name, "concepts")
  return {} unless Dir.exist?(concepts_dir)

  terms = {}
  Dir.glob(File.join(concepts_dir, "*.yaml")).sort.each do |path|
    concept = load_concept(path)
    next unless concept && concept[:designation]

    terms[concept[:designation]] = concept
  end
  terms
end

def add_supersedes(path, concept_data, older_id, older_urn, dry_run:)
  content = File.read(path)
  parts = content.split(/^---\s*$/).reject { |p| p.strip.empty? }
  return false if parts.empty?

  parsed = YAML.safe_load(parts[0], permitted_classes: [Date, Time])
  return false unless parsed

  parsed["data"] ||= {}
  parsed["data"]["related"] ||= []

  new_entry = { "type" => "supersedes", "ref" => { "source" => older_urn, "id" => older_id } }
  parsed["data"]["related"] << new_entry

  if dry_run
    puts "    + supersedes → #{older_urn}##{older_id}"
    return true
  end

  new_content = "---\n#{YAML.dump(parsed).sub(/^---\n/, "")}"
  parts[1..].each { |p| new_content << "---\n#{p.strip}\n" }

  File.write(path, new_content)
  true
end

def process_pair(pair, dry_run:)
  newer_name = pair[:newer]
  older_name = pair[:older]
  newer_urn = pair[:newer_urn]
  older_urn = pair[:older_urn]

  puts "\n=== #{newer_name} → #{older_name} ==="

  newer_terms = load_dataset_terms(newer_name)
  older_terms = load_dataset_terms(older_name)

  puts "  #{newer_name}: #{newer_terms.size} concepts with terms"
  puts "  #{older_name}: #{older_terms.size} concepts with terms"

  matched = 0
  already_linked = 0
  unmatched = 0

  newer_terms.each do |term, concept|
    older_concept = older_terms[term]
    unless older_concept
      unmatched += 1
      next
    end

    # Skip if already linked
    if concept[:existing_supersedes].include?(older_concept[:identifier])
      already_linked += 1
      next
    end

    # Skip if the same identifier (self-reference)
    if concept[:identifier] == older_concept[:identifier]
      next
    end

    puts "  #{concept[:identifier]} (#{term}) → #{older_concept[:identifier]}"
    add_supersedes(concept[:path], concept, older_concept[:identifier], older_urn, dry_run: dry_run)
    matched += 1
  end

  puts "  Result: #{matched} new, #{already_linked} already linked, #{unmatched} no term match"
  matched
end

def main
  options = parse_arguments

  pairs = EDITION_PAIRS
  if options[:edition]
    pairs = EDITION_PAIRS.select { |p| "#{p[:newer]}/#{p[:older]}" == options[:edition] }
    if pairs.empty?
      abort "Unknown edition pair: #{options[:edition]}. Available: #{EDITION_PAIRS.map { |p| "#{p[:newer]}/#{p[:older]}" }.join(', ')}"
    end
  end

  puts options[:dry_run] ? "DRY RUN — no files will be modified" : "WRITE MODE — files will be modified"

  total_matched = 0
  pairs.each do |pair|
    total_matched += process_pair(pair, dry_run: options[:dry_run])
  end

  puts "\nTotal: #{total_matched} new supersedes relationships #{options[:dry_run] ? "would be" : ""} added"
end

main
