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

def edition_type(edition)
  edition["id"].start_with?("viml-") ? :viml : :vim
end

def build_edition_dataset(edition)
  id = edition["id"]
  year = edition["year"]
  ref = edition["ref"]
  deploy = edition["deploy"] || {}
  color = deploy["color"] || "#6B7280"
  title = ref
  title_fra = ref
  languages = edition["languages"] || ["eng", "fra"]
  type = edition_type(edition)

  if type == :vim
    full_name = "International Vocabulary of Metrology"
    full_name_fra = "Vocabulaire international de métrologie"
    owner = "JCGM"
    tags = ["metrology", "jcgm", "vocabulary"]
  else
    full_name = "International Vocabulary of Legal Metrology"
    full_name_fra = "Vocabulaire international de métrologie légale"
    owner = "OIML"
    tags = ["metrology", "legal", "oiml", "vocabulary"]
  end

  description = deploy["description"] || "Terminology definitions from the #{full_name} (#{ref})"
  description_fra = deploy["description_fra"] || "Définitions de terminologie du #{full_name_fra} (#{ref})"

  dataset = {
    "id" => id,
    "uri" => edition["urn_prefix"],
    "uriAliases" => ["#{edition['urn_prefix']}*"],
    "sourceRepo" => "https://github.com/metanorma/oiml-viml",
    "localPath" => edition["dataset_path"],
    "ref" => ref,
    "title" => title,
    "description" => description,
    "translations" => {
      "fra" => {
        "title" => title_fra,
        "description" => description_fra,
      },
    },
    "owner" => owner,
    "color" => color,
    "tags" => tags,
    "languages" => languages.dup,
    "languageOrder" => languages.dup,
  }

  if edition["ref_aliases"]
    dataset["refAliases"] = edition["ref_aliases"].dup
  end

  status = edition["status"]
  if status && status != "current"
    dataset["editionStatus"] = status
  end

  dataset
end

def generate_datasets
  editions = YAML.load_file(EDITIONS_PATH, permitted_classes: [Date], aliases: true)["editions"]
  editions.map { |e| build_edition_dataset(e) }
end

def generate_dataset_groups
  editions = YAML.load_file(EDITIONS_PATH, permitted_classes: [Date], aliases: true)["editions"]

  # Group editions by family prefix (viml-*, vim-* excluding viml-*)
  families = editions.group_by { |e| edition_type(e) }

  families.map do |type, family_editions|
    ids = family_editions.map { |e| e["id"] }
    current = family_editions.find { |e| e["status"] == "current" } || family_editions.first
    deploy = current["deploy"] || {}

    group = {
      "id" => type.to_s,
      "label" => deploy["title"] || current["id"],
      "datasets" => ids,
    }

    if deploy["color"]
      group["color"] = deploy["color"]
    end

    # Collect translations from the current edition's deploy section
    translations = {}
    deploy.each do |key, value|
      if key =~ /\Atitle_(\w{3})\z/
        lang = $1
        translations[lang] = { "label" => value }
      end
    end
    group["translations"] = translations unless translations.empty?

    group
  end
end

# ── Main ──

datasets = generate_datasets

if ARGV.include?("--write")
  config = YAML.load_file(SITE_CONFIG_PATH, aliases: true)
  config["datasets"] = datasets
  config["datasetGroups"] = generate_dataset_groups
  File.write(SITE_CONFIG_PATH, YAML.dump(config), encoding: "utf-8")
  puts "Updated #{SITE_CONFIG_PATH} with #{datasets.size} datasets and #{config['datasetGroups'].size} groups"
else
  puts "# Generated dataset entries from editions.yml"
  puts "# Run with --write to update site-config.yml"
  puts
  puts YAML.dump(datasets)
end
