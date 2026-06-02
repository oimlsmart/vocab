#!/usr/bin/env ruby
# frozen_string_literal: true

# Full audit: compare cached HTML against generated concept YAML files
# to ensure no key details are missing from the VIM dataset.

require "nokogiri"
require "yaml"

CACHE_DIR = File.join(File.dirname(__FILE__), "..", ".vim-cache")
OUTPUT_DIR = File.join(File.dirname(__FILE__), "..", "vim-glossarist")

TERM_IDS = [
  *(1..30).map { |n| "1.#{n}" },
  *(1..53).map { |n| "2.#{n}" },
  *(1..12).map { |n| "3.#{n}" },
  *(1..31).map { |n| "4.#{n}" },
  *(1..18).map { |n| "5.#{n}" },
].freeze

issues = []
stats = {
  concepts: 0, eng_terms: 0, fra_terms: 0,
  admitted: 0, concept_mentions: 0, sources: 0,
  notes: 0, examples: 0, annotations: 0,
  related_ok: 0, domains_ok: 0,
}

TERM_IDS.each do |tid|
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

  # ── 1. Term name ──
  h2_div = en_doc.at_css("h2.lemmatitle div")
  html_term = h2_div ? h2_div.text.strip.sub(/\A\[VIM3\]\s*#{Regexp.escape(tid)}\s*/, "") : nil
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

  # ── 3. Definition ──
  yaml_defn = (eng&.dig("data", "definition") || []).map { |d| d["content"] }.join
  html_defn = en_doc.at_css("p.Definition")&.text&.strip

  if html_defn && html_defn.length > 10 && yaml_defn.empty?
    issues << "#{tid}: definition missing in YAML"
  end

  yaml_mentions = yaml_defn.scan(/\{\{[^}]+\}\}/)
  stats[:concept_mentions] += 1 if yaml_mentions.any?

  # ── 4. Cross-references ──
  html_anchors = en_doc.css("span.AnchorInDef a, span.AnchorInNote a") || []
  html_xref_ids = html_anchors.map { |a| a["href"]&.sub(/\.html\z/, "") }.compact.uniq.sort

  yaml_xref_ids = []
  all_yaml_text = yaml_defn + "\n" +
    (eng&.dig("data", "notes") || []).map { |n| n["content"] }.join("\n") + "\n" +
    (eng&.dig("data", "examples") || []).map { |e| e["content"] }.join("\n")
  all_yaml_text.scan(/\{\{[^,]+,([^}]+)\}\}/) { yaml_xref_ids << $1 }
  yaml_xref_ids = yaml_xref_ids.uniq.sort

  missing_mentions = html_xref_ids - yaml_xref_ids
  if missing_mentions.any?
    issues << "#{tid}: missing concept mentions for: #{missing_mentions.join(", ")}"
  end

  # ── 5. Notes count ──
  # Count HTML notes (exclude annotations and examples)
  html_notes = en_doc.css("div#notes p.NoteEx").select { |p|
    p.text.strip =~ /\ANOTE\s/
  }.size
  yaml_notes = (eng&.dig("data", "notes") || []).count { |n|
    !n["content"].start_with?("[Annotation]")
  }

  if html_notes > yaml_notes
    issues << "#{tid}: notes mismatch: HTML has #{html_notes} notes, YAML has #{yaml_notes}"
  end
  stats[:notes] += 1 if yaml_notes > 0

  # ── 6. Examples count ──
  html_examples = en_doc.css("div#notes p.NoteEx, div#notes p.NoteEx2").select { |p|
    p.text.strip =~ /\AEXAMPLES?/
  }.size
  yaml_examples = (eng&.dig("data", "examples") || []).size

  # Examples embedded in notes also count
  embedded_examples = (eng&.dig("data", "notes") || []).sum { |n|
    n["content"].scan(/\n\nEXAMPLE/).size
  }
  total_yaml_examples = yaml_examples + embedded_examples

  if html_examples > total_yaml_examples
    issues << "#{tid}: examples mismatch: HTML has #{html_examples}, YAML has #{total_yaml_examples} (#{yaml_examples} standalone + #{embedded_examples} embedded)"
  end
  stats[:examples] += 1 if yaml_examples > 0

  # ── 7. Annotations ──
  html_annotations = en_doc.css("div#annotations p.Annotation").size
  yaml_annotations = (eng&.dig("data", "notes") || []).count { |n|
    n["content"].start_with?("[Annotation]")
  }

  if html_annotations != yaml_annotations
    issues << "#{tid}: annotations mismatch: HTML=#{html_annotations} YAML=#{yaml_annotations}"
  end
  stats[:annotations] += 1 if yaml_annotations > 0

  # ── 8. Domains ──
  domains = concept.dig("data", "domains") || []
  if domains.any?
    stats[:domains_ok] += 1
  else
    issues << "#{tid}: missing domain"
  end

  # ── 9. Sources ──
  eng_sources = eng&.dig("data", "sources") || []
  concept_sources = concept.dig("data", "sources") || []
  stats[:sources] += 1 if eng_sources.any? || concept_sources.any?

  # ── 10. French localization ──
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
puts "  Has examples:         #{stats[:examples]}"
puts "  Has annotations:      #{stats[:annotations]}"
puts "  Domains OK:           #{stats[:domains_ok]}"
puts "  Issues found:         #{issues.size}"
puts

if issues.any?
  issues.each { |i| puts "  #{i}" }
else
  puts "  ALL CHECKS PASSED!"
end
