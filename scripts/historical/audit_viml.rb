#!/usr/bin/env ruby
# frozen_string_literal: true

# Full audit: compare cached HTML against generated concept YAML files
# to ensure no key details are missing.

require "nokogiri"
require "yaml"

CACHE_DIR = File.join(File.dirname(__FILE__), "..", ".viml-cache")
OUTPUT_DIR = File.join(File.dirname(__FILE__), "..", "datasets/viml-2022")

TERM_IDS = [
  *("0.01".."0.15").to_a,
  *("1.01".."1.06").to_a,
  *("2.01".."2.24").to_a,
  *("3.01".."3.07").to_a,
  *("4.01".."4.16").to_a,
  *("5.01".."5.22").to_a,
  *("6.01".."6.08").to_a,
  *("A.1".."A.37").to_a,
].freeze

issues = []
stats = {
  concepts: 0, eng_terms: 0, fra_terms: 0,
  admitted: 0, concept_mentions: 0, sources: 0, notes: 0,
  related_ok: 0, domains_ok: 0,
}

TERM_IDS.each do |tid|
  # ── Load YAML concept file ──
  yaml_path = File.join(OUTPUT_DIR, "concepts", "#{tid}.yaml")
  unless File.exist?(yaml_path)
    issues << "#{tid}: YAML file missing"
    next
  end

  docs = YAML.load_stream(File.read(yaml_path, encoding: "utf-8"))
  concept = nil
  localizations = {}

  docs.each do |doc|
    next unless doc.is_a?(Hash)
    if doc["data"] && doc["data"]["localized_concepts"]
      concept = doc
    elsif doc["data"] && doc["data"]["language_code"]
      localizations[doc["data"]["language_code"]] = doc
    end
  end

  unless concept
    issues << "#{tid}: no ManagedConcept in YAML"
    next
  end
  stats[:concepts] += 1

  eng = localizations["eng"]
  fra = localizations["fra"]

  # ── Parse cached HTML ──
  en_html_path = File.join(CACHE_DIR, "en", "#{tid}.html")
  unless File.exist?(en_html_path)
    issues << "#{tid}: no cached English HTML"
    next
  end

  en_doc = Nokogiri::HTML(File.read(en_html_path, encoding: "utf-8"), nil, "utf-8")
  en_content = en_doc.at_css('div[data-role="content"]')

  # ── 1. Term name ──
  h2 = en_doc.at_css("h2.lemmatitle")
  html_term = h2 ? h2.text.strip.sub(/\A#{Regexp.escape(tid)}\s*/, "") : nil
  yaml_term = (eng&.dig("data", "terms") || [])
    .find { |t| t["normative_status"] == "preferred" }&.dig("designation")

  if html_term != yaml_term
    issues << "#{tid}: term name mismatch: HTML=#{html_term.inspect} YAML=#{yaml_term.inspect}"
  else
    stats[:eng_terms] += 1
  end

  # ── 2. Admitted terms ──
  html_admitted = en_doc.css("div.lemmasubtitle").flat_map { |el|
    el.css("i, em").map(&:text).map(&:strip)
  }.reject(&:empty?).sort

  yaml_admitted = (eng&.dig("data", "terms") || [])
    .select { |t| t["normative_status"] == "admitted" }
    .map { |t| t["designation"] }.sort

  if html_admitted != yaml_admitted
    issues << "#{tid}: admitted mismatch: HTML=#{html_admitted.inspect} YAML=#{yaml_admitted.inspect}"
  end
  stats[:admitted] += 1 if yaml_admitted.any?

  # ── 3. Definition + concept mentions ──
  yaml_defn = (eng&.dig("data", "definition") || []).map { |d| d["content"] }.join
  html_defn = en_content&.at_css("p.Definition")&.text&.strip

  if html_defn && html_defn.length > 10 && yaml_defn.empty?
    issues << "#{tid}: definition missing in YAML"
  end

  yaml_mentions = yaml_defn.scan(/\{\{[^}]+\}\}/)
  stats[:concept_mentions] += 1 if yaml_mentions.any?

  # ── 4. Cross-references from HTML anchors vs YAML ──
  html_anchors = en_content&.css("span.AnchorInDef a, span.AnchorInNote a") || []
  html_xref_ids = html_anchors.map { |a| a["href"]&.sub(/\.html\z/, "") }.compact.uniq.sort

  yaml_xref_ids = []
  all_yaml_text = yaml_defn + "\n" +
    (eng&.dig("data", "notes") || []).map { |n| n["content"] }.join("\n")
  all_yaml_text.scan(/\{\{[^,]+,([^}]+)\}\}/) { yaml_xref_ids << $1 }
  yaml_xref_ids = yaml_xref_ids.uniq.sort

  missing_mentions = html_xref_ids - yaml_xref_ids
  if missing_mentions.any?
    issues << "#{tid}: missing concept mentions for: #{missing_mentions.join(", ")}"
  end

  # ── 5. Related concepts ──
  yaml_related = (concept["related"] || [])
  yaml_related_ids = yaml_related.map { |r| r.dig("ref", "id") }.compact.sort
  expected_related = html_xref_ids.reject { |id| id == tid }

  missing_related = expected_related - yaml_related_ids
  if missing_related.any?
    issues << "#{tid}: missing related: #{missing_related.join(", ")}"
  end
  stats[:related_ok] += 1 if missing_related.empty? && expected_related.any?

  # ── 6. Domains ──
  domains = concept.dig("data", "domains") || []
  if domains.any?
    stats[:domains_ok] += 1
  else
    issues << "#{tid}: missing domain"
  end

  # ── 7. Notes ──
  yaml_notes = (eng&.dig("data", "notes") || []).size
  stats[:notes] += 1 if yaml_notes > 0

  # ── 8. Sources ──
  eng_sources = eng&.dig("data", "sources") || []
  concept_sources = concept.dig("data", "sources") || []
  stats[:sources] += 1 if eng_sources.any? || concept_sources.any?

  # ── 9. French localization ──
  if fra
    stats[:fra_terms] += 1
    fra_yaml_term = (fra["data"]["terms"] || [])
      .find { |t| t["normative_status"] == "preferred" }&.dig("designation")
    if fra_yaml_term.to_s.strip.empty?
      issues << "#{tid}: French preferred term is empty"
    end
  else
    issues << "#{tid}: missing French localization"
  end
end

puts "=" * 60
puts "AUDIT RESULTS"
puts "  Total terms:          #{TERM_IDS.size}"
puts "  Concepts in YAML:     #{stats[:concepts]}"
puts "  EN preferred terms:   #{stats[:eng_terms]}"
puts "  FR localizations:     #{stats[:fra_terms]}"
puts "  Has admitted terms:   #{stats[:admitted]}"
puts "  Has concept mentions: #{stats[:concept_mentions]}"
puts "  Has sources:          #{stats[:sources]}"
puts "  Has notes:            #{stats[:notes]}"
puts "  Related refs OK:      #{stats[:related_ok]}"
puts "  Domains OK:           #{stats[:domains_ok]}"
puts "  Issues found:         #{issues.size}"
puts

if issues.any?
  issues.each { |i| puts "  #{i}" }
else
  puts "  ALL CHECKS PASSED!"
end
