# frozen_string_literal: true

# Shared infrastructure for VIML edition scrapers.
#
# Provides:
#   - EditionConfig: loads editions.yml, returns config for a given edition
#   - ConceptBuilder: builds Glossarist v3 objects from parsed concept data
#   - DatasetWriter: writes concept YAML files and register.yaml
#
# Usage:
#   require_relative "viml_edition_scraper"
#   config = VimlEditionScraper::EditionConfig.new("viml-2013")
#   concepts = MyParser.new(config).parse
#   VimlEditionScraper::DatasetWriter.new(config).write_all(concepts)

require "yaml"
require "fileutils"
require "glossarist"
require "glossarist/v3"

module VimlEditionScraper
  SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
  PROJECT_DIR = File.expand_path("..", SCRIPT_DIR)
  EDITIONS_PATH = File.join(PROJECT_DIR, "editions.yml")

  class EditionConfig
    attr_reader :id, :ref, :year, :urn_prefix, :dataset_path, :languages,
                :status, :supersedes, :sections, :sections_fra, :source,
                :deploy, :concept_count

    def initialize(edition_id)
      all = YAML.load_file(EDITIONS_PATH)
      edition = all["editions"].find { |e| e["id"] == edition_id }
      raise ArgumentError, "Unknown edition: #{edition_id}" unless edition

      @id = edition["id"]
      @ref = edition["ref"]
      @year = edition["year"]
      @urn_prefix = edition["urn_prefix"]
      @dataset_path = edition["dataset_path"]
      @languages = edition["languages"]
      @status = edition["status"]
      @supersedes = edition["supersedes"]
      @sections = edition["sections"] || {}
      @sections_fra = edition["sections_fra"] || {}
      @source = edition["source"] || {}
      @deploy = edition["deploy"] || {}
      @concept_count = edition["concept_count"]
    end

    def source_file
      File.join(PROJECT_DIR, @source["file"]) if @source["file"]
    end

    def full_dataset_path
      File.join(PROJECT_DIR, @dataset_path)
    end

    def section_for(term_id)
      term_id[/\A([0-9A-Za-z]+)/, 1]
    end
  end

  # Parsed concept data — the interface contract between parser and builder.
  ParsedConcept = Struct.new(
    :term_id, :term_name, :definition, :notes, :examples,
    :source_ref, :cross_refs, :language_code, :admitted_terms,
    keyword_init: true,
  )

  # Builds Glossarist v3 objects from ParsedConcept structs.
  class ConceptBuilder
    def initialize(config)
      @config = config
    end

    def build_source(source_ref)
      return nil unless source_ref

      origin = Glossarist::Citation.new(
        ref: Glossarist::Citation::Ref.new(source: source_ref[:ref]),
        locality: source_ref[:clause] ? Glossarist::Locality.new(
          type: "clause",
          reference_from: source_ref[:clause],
        ) : nil,
      )

      Glossarist::ConceptSource.new(type: "authoritative", origin: origin)
    end

    def build_localized_concept(data, date)
      cd = Glossarist::ConceptData.new
      cd.id = "#{data.term_id}-#{data.language_code}"
      cd.language_code = data.language_code
      cd.dates = [Glossarist::ConceptDate.new(type: "accepted", date: DateTime.parse(date))]

      if data.definition && !data.definition.empty?
        cd.definition = [Glossarist::DetailedDefinition.new(content: data.definition)]
      end

      cd.notes = (data.notes || []).map { |n| Glossarist::DetailedDefinition.new(content: n) }
      cd.examples = []

      if data.source_ref
        cd.sources = [build_source(data.source_ref)]
      end

      cd.terms = [
        Glossarist::Designation::Expression.new(
          designation: data.term_name,
          normative_status: "preferred",
        ),
      ]

      (data.admitted_terms || []).each do |alt|
        cd.terms << Glossarist::Designation::Expression.new(
          designation: alt,
          normative_status: "admitted",
        )
      end

      l10n = Glossarist::LocalizedConcept.new
      l10n.data = cd
      l10n.entry_status = "valid"
      l10n
    end

    def build_managed_concept(term_id, localizations, cross_refs)
      mc = Glossarist::ManagedConcept.new(data: { "id" => term_id })
      mc.schema_version = "3"

      mc.data.domains = [
        Glossarist::ConceptReference.new(
          source: @config.urn_prefix,
          concept_id: "section-#{@config.section_for(term_id)}",
          ref_type: "domain",
        ),
      ]

      first_data = localizations.values.first
      if first_data&.source_ref
        mc.data.sources = [build_source(first_data.source_ref)]
      end

      localizations.each do |_lang, data|
        mc.add_l10n(build_localized_concept(data, "#{@config.year}-01-01"))
      end

      mc.related = cross_refs.reject { |id| id == term_id }.map do |xref_id|
        Glossarist::RelatedConcept.new(
          type: "see",
          ref: Glossarist::ConceptRef.new(source: @config.urn_prefix, id: xref_id),
        )
      end

      mc.status = "valid"
      mc
    end
  end

  # Writes Glossarist v3 datasets to disk.
  class DatasetWriter
    def initialize(config)
      @config = config
    end

    def write_all(managed_concepts)
      concepts_dir = File.join(@config.full_dataset_path, "concepts")
      FileUtils.mkdir_p(concepts_dir)

      concept_ids = []
      managed_concepts.each do |mc|
        doc = Glossarist::V3::ConceptDocument.from_managed_concept(mc)
        filename = File.join(concepts_dir, "#{mc.data.id}.yaml")
        File.write(filename, doc.to_yamls, encoding: "utf-8")
        concept_ids << mc.data.id
      end

      register_data = {
        "schema_version" => "3",
        "edition" => {
          "id" => @config.id,
          "ref" => @config.ref,
          "year" => @config.year,
          "urn_prefix" => @config.urn_prefix,
          "status" => @config.status,
          "supersedes" => @config.supersedes,
        },
        "concepts" => sort_concept_ids(concept_ids),
      }
      File.write(
        File.join(@config.full_dataset_path, "register.yaml"),
        YAML.dump(register_data),
        encoding: "utf-8",
      )

      puts "Wrote #{managed_concepts.size} concepts to #{@config.dataset_path}/"
      managed_concepts.size
    end

    private

    def sort_concept_ids(ids)
      ids.sort_by do |id|
        section, num = id.split(".", 2)
        [section == "A" ? 99 : section.to_i, (num || "").to_i]
      end
    end
  end
end
