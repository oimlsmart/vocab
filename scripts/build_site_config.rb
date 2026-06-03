#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates the dataset section of site-config.yml from editions.yml.
#
# This maintains a single source of truth: editions.yml defines all edition
# metadata, and this script derives the site-config dataset entries from it.
# Non-edition config (branding, features, pages, etc.) is preserved as-is.
#
# Usage:
#   ruby scripts/build_site_config.rb [--write]
#
# Without --write, prints the generated datasets to stdout.
# With --write, updates site-config.yml in place.

require "yaml"

SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
PROJECT_DIR = File.expand_path("..", SCRIPT_DIR)
EDITIONS_PATH = File.join(PROJECT_DIR, "editions.yml")
SITE_CONFIG_PATH = File.join(PROJECT_DIR, "site-config.yml")

VIML_DATASET_IDS = begin
  editions = YAML.load_file(EDITIONS_PATH, permitted_classes: [Date], aliases: true)["editions"]
  editions.map { |e| e["id"] }
end

# Non-edition datasets that exist in site-config.yml (e.g., VIM).
# These are preserved as-is when regenerating.
FIXED_DATASETS = ["vim"].freeze

def build_edition_dataset(edition)
  id = edition["id"]
  year = edition["year"]
  ref = edition["ref"]
  deploy = edition["deploy"] || {}
  color = deploy["color"] || "#6B7280"
  title = deploy["title"] || "VIML (#{year})"
  title_fra = deploy["title_fra"] || title
  languages = edition["languages"] || ["eng", "fra"]

  dataset = {
    "id" => id,
    "uri" => edition["urn_prefix"],
    "uriAliases" => ["#{edition['urn_prefix']}*"],
    "sourceRepo" => "https://github.com/metanorma/oiml-viml",
    "localPath" => edition["dataset_path"],
    "ref" => ref,
    "title" => title,
    "description" => "Terminology definitions from the International Vocabulary of Legal Metrology (#{ref})",
    "translations" => {
      "fra" => {
        "title" => title_fra,
        "description" => "Définitions de terminologie du Vocabulaire international de métrologie légale (#{ref})",
      },
    },
    "owner" => "OIML",
    "color" => color,
    "tags" => ["metrology", "legal", "oiml", "vocabulary"],
    "languages" => languages.dup,
    "languageOrder" => languages.dup,
  }

  # For older editions, add edition status info
  status = edition["status"]
  if status && status != "current"
    dataset["editionStatus"] = status
  end

  dataset
end

def generate_datasets
  editions = YAML.load_file(EDITIONS_PATH, permitted_classes: [Date], aliases: true)["editions"]

  # Build edition datasets from editions.yml
  edition_datasets = editions.map { |e| build_edition_dataset(e) }

  # Load existing site-config to preserve non-edition datasets
  existing_config = YAML.load_file(SITE_CONFIG_PATH, aliases: true)
  existing_datasets = existing_config["datasets"] || []

  # Preserve non-VIML datasets (like VIM)
  preserved = existing_datasets.select { |d| FIXED_DATASETS.include?(d["id"]) }

  # Final order: current edition first, then older editions, then non-edition datasets
  edition_datasets + preserved
end

# ── Main ──

datasets = generate_datasets

if ARGV.include?("--write")
  config = YAML.load_file(SITE_CONFIG_PATH, aliases: true)
  config["datasets"] = datasets
  File.write(SITE_CONFIG_PATH, YAML.dump(config), encoding: "utf-8")
  puts "Updated #{SITE_CONFIG_PATH} with #{datasets.size} datasets"
else
  puts "# Generated dataset entries from editions.yml"
  puts "# Run with --write to update site-config.yml"
  puts
  puts YAML.dump(datasets)
end
