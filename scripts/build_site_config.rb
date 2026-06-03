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

def localized(deploy, field, default_lang = "eng")
  value = deploy[field]
  return value unless value.is_a?(Hash)
  value[default_lang] || value.values.first
end

def localized_translations(deploy, field, default_lang)
  value = deploy[field]
  return {} unless value.is_a?(Hash)
  value.each_with_object({}) do |(lang, text), map|
    next if lang == default_lang
    map[lang] = text
  end
end

def build_edition_dataset(edition)
  id = edition["id"]
  ref = edition["ref"]
  deploy = edition["deploy"] || {}
  color = deploy["color"] || "#6B7280"
  languages = edition["languages"] || ["eng", "fra"]
  default_lang = languages.first
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

  main_description = localized(deploy, "description", default_lang) ||
    "Terminology definitions from the #{full_name} (#{ref})"

  desc_translations = localized_translations(deploy, "description", default_lang)

  translations = {}
  desc_translations.each do |lang, desc|
    translations[lang] = {
      "title" => ref,
      "description" => desc,
    }
  end

  dataset = {
    "id" => id,
    "uri" => edition["urn_prefix"],
    "uriAliases" => ["#{edition['urn_prefix']}*"],
    "sourceRepo" => "https://github.com/metanorma/oiml-viml",
    "localPath" => edition["dataset_path"],
    "ref" => ref,
    "title" => ref,
    "description" => main_description,
    "translations" => translations.empty? ? nil : translations,
    "owner" => owner,
    "color" => color,
    "tags" => tags,
    "languages" => languages.dup,
    "languageOrder" => languages.dup,
  }

  dataset.delete("translations") if translations.empty?

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

  families = editions.group_by { |e| edition_type(e) }

  families.map do |type, family_editions|
    ids = family_editions.map { |e| e["id"] }
    current = family_editions.find { |e| e["status"] == "current" } || family_editions.first
    deploy = current["deploy"] || {}
    default_lang = current["languages"]&.first || "eng"

    group_label = localized(deploy, "title", default_lang) || current["id"]

    group = {
      "id" => type.to_s,
      "label" => group_label,
      "datasets" => ids,
    }

    if deploy["color"]
      group["color"] = deploy["color"]
    end

    title_translations = localized_translations(deploy, "title", default_lang)
    unless title_translations.empty?
      group["translations"] = title_translations.each_with_object({}) do |(lang, label), map|
        map[lang] = { "label" => label }
      end
    end

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
