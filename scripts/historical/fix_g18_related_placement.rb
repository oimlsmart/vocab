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

def main
  options = parse_arguments
  puts options[:dry_run] ? "DRY RUN — no files will be modified" : "WRITE MODE — files will be modified"
  puts

  total_moved = 0

  Dir.glob(File.join(G18_CONCEPTS, "*.yaml")).sort.each do |path|
    content = File.read(path)
    docs = content.split(/^---\s*$/).reject { |d| d.strip.empty? }
    next if docs.empty?

    concept = YAML.safe_load(docs[0], permitted_classes: [Date, Time])
    next unless concept

    data_related = concept.dig("data", "related")
    next unless data_related && data_related.is_a?(Array) && !data_related.empty?

    basename = File.basename(path, ".yaml")
    top_related = concept["related"] || []

    # Move related from data.related to top-level related
    all_related = top_related + data_related

    if options[:dry_run]
      puts "  #{basename}: move #{data_related.size} related entries from data→top level (total: #{all_related.size})"
    else
      concept["related"] = all_related
      concept["data"].delete("related")

      new_first = YAML.dump(concept).sub(/^---\n/, "")
      new_content = "---\n#{new_first}"
      docs[1..].each { |p| new_content << "---\n#{p.strip}\n" }

      File.write(path, new_content)
      puts "  #{basename}: moved #{data_related.size} related entries"
    end

    total_moved += 1
  end

  puts
  puts "#{total_moved} files #{options[:dry_run] ? "would be" : ""} updated"
end

main
