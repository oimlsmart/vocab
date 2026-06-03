#!/usr/bin/env ruby
# frozen_string_literal: true

# Build supersedes/superseded_by relations from supersession-map.yaml
# and inject them into each edition's concept YAML files.
#
# This is idempotent: re-running produces the same output.
# Existing supersedes/superseded_by relations are replaced;
# other relation types (see, compare, etc.) are preserved.
#
# Usage:
#   cd /path/to/glossarist/glossarist-ruby
#   bundle exec ruby /path/to/oiml-viml/scripts/build_supersessions.rb [--dry-run]

require "yaml"
require "fileutils"
require_relative "viml_edition_scraper"

SUPERSESSION_MAP_PATH = File.join(VimlEditionScraper::PROJECT_DIR, "supersession-map.yaml")

# Loads and queries the supersession map.
class SupersessionMap
  attr_reader :mappings, :editions_by_id

  def initialize
    data = YAML.load_file(SUPERSESSION_MAP_PATH)
    @mappings = data["mappings"] || []
    @edition_chain = data["edition_chain"] || []
    @editions_by_id = {}
    @edition_chain.each { |e| @editions_by_id[e["id"]] = e }
  end

  # Returns all mappings where a concept appears in the given edition.
  def for_edition(edition_id)
    @mappings.select { |m| m[edition_id] }
  end

  # Returns the edition that the given edition supersedes (previous in chain).
  def predecessor(edition_id)
    idx = @edition_chain.index { |e| e["id"] == edition_id }
    return nil unless idx && idx < @edition_chain.size - 1
    @edition_chain[idx + 1]["id"]
  end

  # Returns the edition that supersedes the given edition (next in chain).
  def successor(edition_id)
    idx = @edition_chain.index { |e| e["id"] == edition_id }
    return nil unless idx && idx > 0
    @edition_chain[idx - 1]["id"]
  end

  # For a concept in a given edition, returns the concept ID in the predecessor edition.
  def predecessor_concept(edition_id, concept_id)
    pred = predecessor(edition_id)
    return nil unless pred
    mapping = @mappings.find { |m| m[edition_id] == concept_id }
    mapping ? mapping[pred] : nil
  end

  # For a concept in a given edition, returns the concept ID in the successor edition.
  def successor_concept(edition_id, concept_id)
    succ = successor(edition_id)
    return nil unless succ
    mapping = @mappings.find { |m| m[edition_id] == concept_id }
    mapping ? mapping[succ] : nil
  end

  # All edition IDs in the chain.
  def edition_ids
    @edition_chain.map { |e| e["id"] }
  end
end

# Reads, modifies, and writes concept YAML files.
class ConceptYamlFile
  attr_reader :path

  def initialize(path)
    @path = path
    @documents = nil
  end

  def load
    @documents = YAML.load_stream(File.read(@path, encoding: "utf-8"))
    self
  end

  # The managed concept (first document).
  def managed_concept
    @documents&.first
  end

  def concept_id
    managed_concept&.dig("data", "identifier")
  end

  # Replace supersedes/superseded_by relations, preserve others.
  def set_supersession_relations(relations)
    return unless @documents && @documents.first

    existing = @documents.first["related"] || []
    preserved = existing.reject { |r| %w[supersedes superseded_by].include?(r["type"]) }
    @documents.first["related"] = preserved + relations
  end

  def to_yaml_stream
    @documents.map { |doc| YAML.dump(doc) }.join("---\n").gsub(/---\n---/, "---")
  end

  def save
    File.write(@path, to_yaml_stream, encoding: "utf-8")
  end
end

# Main builder: reads map, injects relations into all editions.
class SupersessionBuilder
  def initialize(dry_run: false)
    @dry_run = dry_run
    @map = SupersessionMap.new
    @configs = {}
  end

  def run
    @map.edition_ids.each do |edition_id|
      config = config_for(edition_id)
      next unless config && Dir.exist?(config.full_dataset_path)

      puts "\nProcessing #{edition_id}..."
      inject_relations_for(edition_id, config)
    end
  end

  private

  def config_for(edition_id)
    @configs[edition_id] ||= VimlEditionScraper::EditionConfig.new(edition_id)
  rescue ArgumentError
    nil
  end

  def inject_relations_for(edition_id, config)
    concepts_dir = File.join(config.full_dataset_path, "concepts")
    return unless Dir.exist?(concepts_dir)

    urn = config.urn_prefix
    pred_id = @map.predecessor(edition_id)
    succ_id = @map.successor(edition_id)

    pred_urn = pred_id ? config_for(pred_id)&.urn_prefix : nil
    succ_urn = succ_id ? config_for(succ_id)&.urn_prefix : nil

    updated = 0
    Dir.glob(File.join(concepts_dir, "*.yaml")).each do |filepath|
      file = ConceptYamlFile.new(filepath).load
      concept_id = file.concept_id
      next unless concept_id

      relations = []

      # supersedes: this concept supersedes the concept in the predecessor edition
      if pred_id && pred_urn
        pred_concept = @map.predecessor_concept(edition_id, concept_id)
        if pred_concept
          relations << {
            "type" => "supersedes",
            "ref" => { "source" => pred_urn, "id" => pred_concept },
          }
        end
      end

      # superseded_by: this concept is superseded by the concept in the successor edition
      if succ_id && succ_urn
        succ_concept = @map.successor_concept(edition_id, concept_id)
        if succ_concept
          relations << {
            "type" => "superseded_by",
            "ref" => { "source" => succ_urn, "id" => succ_concept },
          }
        end
      end

      if relations.any?
        file.set_supersession_relations(relations)
        if @dry_run
          puts "  #{concept_id}: would add #{relations.size} relations"
        else
          file.save
          puts "  #{concept_id}: added #{relations.size} relations"
        end
        updated += 1
      end
    end

    puts "  #{updated} concepts updated in #{edition_id}"
  end
end

# ── Main ──

dry_run = ARGV.include?("--dry-run")
puts "Building supersession relations#{' (dry run)' if dry_run}..."
puts "Map: #{SUPERSESSION_MAP_PATH}"

builder = SupersessionBuilder.new(dry_run: dry_run)
builder.run

puts "\nDone."
