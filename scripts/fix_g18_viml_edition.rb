#!/usr/bin/env ruby
require "yaml"
require "optparse"

BASE = File.expand_path("..", __dir__)
G18_CONCEPTS = File.join(BASE, "datasets", "g18", "concepts")

def parse_arguments
  options = { dry_run: true }
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [--dry-run] [--write]"
    opts.on("--dry-run", "Show changes without modifying files (default)") { options[:dry_run] = true }
    opts.on("--write", "Actually modify G18 concept files") { options[:dry_run] = false }
  end.parse!
  options
end

def strip_viml_padding(id)
  id.gsub(/\.(\d+)/) { ".#{$1.to_i}" }
end

def main
  options = parse_arguments
  puts options[:dry_run] ? "DRY RUN — no files will be modified" : "WRITE MODE — files will be modified"
  puts

  total_changed = 0

  Dir.glob(File.join(G18_CONCEPTS, "*.yaml")).sort.each do |path|
    content = File.read(path)
    next unless content.include?("urn:oiml:pub:v:1:2013")

    docs = content.split(/^---\s*$/).reject { |d| d.strip.empty? }
    concept = YAML.safe_load(docs[0], permitted_classes: [Date, Time])
    related = concept.dig("data", "related") || []

    changed = false
    new_related = related.map do |r|
      if r.dig("ref", "source") == "urn:oiml:pub:v:1:2013" && r["type"] == "see"
        old_id = r.dig("ref", "id")
        new_id = strip_viml_padding(old_id)
        changed = true
        basename = File.basename(path, ".yaml")
        puts "  #{basename}: VIML #{old_id} (2013) -> VIML #{new_id} (2000)"
        {
          "type" => r["type"],
          "ref" => {
            "source" => "urn:oiml:pub:v:1:2000",
            "id" => new_id
          }
        }
      else
        r
      end
    end

    next unless changed

    if options[:dry_run]
      total_changed += 1
      next
    end

    concept["data"]["related"] = new_related
    new_first = YAML.dump(concept).sub(/^---\n/, "")
    new_content = "---\n#{new_first}"
    docs[1..].each { |p| new_content << "---\n#{p.strip}\n" }

    File.write(path, new_content)
    total_changed += 1
  end

  puts
  puts "#{total_changed} files #{options[:dry_run] ? "would be" : ""} changed"
end

main
