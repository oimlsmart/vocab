#!/usr/bin/env ruby
# frozen_string_literal: true

# Scrape the VIM (International Vocabulary of Metrology, JCGM 200:2012)
# from https://jcgm.bipm.org/vim and convert to a Glossarist v3 dataset.
#
# The VIM (also published as OIML V 2-200:2012) contains 144 bilingual
# concepts across 5 chapters. The online version at jcgm.bipm.org includes
# informative annotations by JCGM/WG 2 that supplement the normative text.
#
# Key structural differences from VIML:
#   - EXAMPLEs use p.NoteEx2 (separate from NOTEs in p.NoteEx)
#   - Annotations in div#annotations (informative commentary by JCGM/WG 2)
#   - Tables in notes (table.InnerTab) for concept hierarchies
#   - List items (p.NoteExList) for enumerated sub-points
#   - French admitted terms include grammatical gender (e.g. "nature, f")
#
# Usage:
#   ruby scripts/scrape_vim.rb [COMMAND]
#
# Commands:
#   fetch    — download all pages to .vim-cache/
#   build    — parse cached HTML, build Glossarist dataset
#   about    — extract about pages from cached info.html
#   all      — fetch + build + about (default if cache is empty)

require "nokogiri"
require "net/http"
require "uri"
require "fileutils"
require "yaml"
require "securerandom"

BASE_URL = "https://jcgm.bipm.org/vim"
CACHE_DIR = File.join(File.dirname(__FILE__), "..", ".vim-cache")
OUTPUT_DIR = File.join(File.dirname(__FILE__), "..", "vim-glossarist")

DATASET_SOURCE = "urn:jcgm:pub:200:2012"
SOURCE_REF = "JCGM 200:2012"

SECTION_NAMES = {
  "1" => "Quantities and units",
  "2" => "Measurement",
  "3" => "Devices for measurement",
  "4" => "Properties of measuring devices",
  "5" => "Measurement standards (Etalons)",
}.freeze

LANGUAGES = %w[en fr].freeze

TERM_IDS = [
  *(1..30).map { |n| "1.#{n}" },
  *(1..53).map { |n| "2.#{n}" },
  *(1..12).map { |n| "3.#{n}" },
  *(1..31).map { |n| "4.#{n}" },
  *(1..18).map { |n| "5.#{n}" },
].freeze

# ═══════════════════════════════════════════════════════════════
# Phase 1: Fetch all pages to disk
# ═══════════════════════════════════════════════════════════════

def cache_path(lang, page)
  File.join(CACHE_DIR, lang, "#{page}.html")
end

def cached?(lang, page)
  File.exist?(cache_path(lang, page))
end

def fetch_page(url)
  uri = URI.parse(url)
  resp = Net::HTTP.get_response(uri)
  raise "HTTP #{resp.code}" unless resp.is_a?(Net::HTTPSuccess)

  resp.body.force_encoding("UTF-8")
end

def fetch_all
  FileUtils.mkdir_p(File.join(CACHE_DIR, "en"))
  FileUtils.mkdir_p(File.join(CACHE_DIR, "fr"))

  pages = TERM_IDS.flat_map { |tid| LANGUAGES.map { |l| [l, tid] } }
  pages += LANGUAGES.map { |l| [l, "info"] }

  total = pages.size
  fetched = 0
  skipped = 0
  errors = []

  pages.each do |lang, page|
    dest = cache_path(lang, page)

    if File.exist?(dest) && File.size(dest) > 0
      skipped += 1
      next
    end

    fetched += 1
    printf("\r  [%d/%d] Fetching %-4s %-8s  ", fetched + skipped, total, lang, page)

    begin
      url = "#{BASE_URL}/#{lang}/#{page}.html"
      html = fetch_page(url)
      File.write(dest, html, encoding: "utf-8")
      sleep 0.5
    rescue => e
      errors << "#{url} => #{e.message}"
    end
  end

  puts
  puts "  Fetched: #{fetched}, Cached: #{skipped}, Errors: #{errors.size}"
  errors.each { |e| puts "    ERROR: #{e}" } if errors.any?
  errors.empty?
end

# ═══════════════════════════════════════════════════════════════
# Phase 2: Parse cached HTML → term data
# ═══════════════════════════════════════════════════════════════

TermData = Struct.new(
  :term_id, :term_name, :definition, :notes, :examples,
  :cross_refs, :language_code, :admitted_terms,
  keyword_init: true,
)

def load_cached(lang, page)
  path = cache_path(lang, page)
  return nil unless File.exist?(path)

  File.read(path, encoding: "utf-8")
end

def parse_term(html, term_id, lang)
  return nil unless html

  doc = Nokogiri::HTML(html, nil, "utf-8")
  content = doc.at_css('div[data-role="content"]')
  return nil unless content

  # ── Preferred term name ──
  h2_div = doc.at_css("h2.lemmatitle div")
  term_name = h2_div&.text&.strip&.sub(/\A\[VIM3\]\s*#{Regexp.escape(term_id)}\s*/, "")

  # ── Admitted terms (from div.lemmasubtitle) ──
  admitted_terms = doc.css("div.lemmasubtitle").flat_map { |el|
    el.css("i, em").map { |i| i.text.strip }
  }.reject(&:empty?)

  # ── Definition ──
  defn_node = content.at_css("p.Definition")
  definition, defn_xrefs = extract_text_with_xrefs(defn_node)

  # ── Notes, Examples (from div#notes) ──
  # VIM interleaves NOTEs and EXAMPLEs as separate block elements.
  # Each EXAMPLE is extracted as a standalone entry in the examples array,
  # regardless of its position relative to NOTEs.
  notes = []
  examples = []
  all_xrefs = defn_xrefs.dup

  notes_div = content.at_css("div#notes")
  if notes_div
    current_type = nil
    current_text = nil

    notes_div.children.each do |child|
      next unless child.is_a?(Nokogiri::XML::Element)
      next if child.name == "h3"

      css_class = child["class"].to_s

      if css_class.include?("NoteEx")
        text, xrefs = extract_text_with_xrefs(child)
        all_xrefs.concat(xrefs)
        stripped = text.strip

        if stripped =~ /\ANOTE\s+(?:\d+\s+)?(.+)/
          finalize_current(notes, examples, current_type, current_text)
          current_type = :note
          current_text = $1.strip
        elsif stripped =~ /\AEXAMPLES?\s*(?:\d+\s+)?(.*)/
          example_content = $1.strip
          finalize_current(notes, examples, current_type, current_text)
          current_type = :example
          current_text = example_content.empty? ? stripped : example_content
        elsif !stripped.empty? && current_text
          current_text << "\n#{stripped}"
        elsif !stripped.empty?
          current_type = :note
          current_text = stripped
        end

      elsif css_class.include?("NoteExList")
        text, xrefs = extract_text_with_xrefs(child)
        all_xrefs.concat(xrefs)
        item_text = text.strip.sub(/\A[-–—•·]\s*/, "")
        if current_text
          current_text << "\n— #{item_text}"
        else
          current_type = :note
          current_text = "— #{item_text}"
        end

      elsif child.name == "table"
        table_text = serialize_table(child)
        current_text << "\n\n#{table_text}" if current_text

      end
    end

    finalize_current(notes, examples, current_type, current_text)
  end

  # ── Annotations (from div#annotations) ──
  # Annotations are informative commentary by JCGM/WG 2, not part of
  # the normative VIM3 text. Stored as notes with [Annotation] prefix
  # to preserve the distinction in the concept browser.
  annotations_div = content.at_css("div#annotations")
  if annotations_div
    annotations_div.css("p.Annotation").each do |p|
      text, xrefs = extract_text_with_xrefs(p)
      all_xrefs.concat(xrefs)
      stripped = text.strip
      stripped = stripped.sub(/\AANNOTATION\s+\(informative\)\s*\[[^\]]+\]\s*/, "")
      notes << "[Annotation] #{stripped}" unless stripped.empty?
    end
  end

  TermData.new(
    term_id: term_id,
    term_name: term_name,
    definition: definition,
    notes: notes,
    examples: examples,
    cross_refs: all_xrefs.uniq,
    language_code: lang == "en" ? "eng" : "fra",
    admitted_terms: admitted_terms,
  )
end

def finalize_current(notes, examples, type, text)
  return unless text

  case type
  when :note then notes << text
  when :example then examples << text
  end
end

def extract_text_with_xrefs(node)
  return ["", []] unless node

  xrefs = []
  text_parts = []

  node.children.each do |child|
    case child
    when Nokogiri::XML::Text
      text_parts << child.text
    when Nokogiri::XML::Element
      span_class = child["class"].to_s

      if span_class.include?("Anchor")
        a = child.at_css("a") || (child.name == "a" ? child : nil)
        if a
          href = a["href"]&.sub(/\.html\z/, "")
          xrefs << href if href
          term_text = a.text.strip
          text_parts << "{{#{term_text},#{href}}}" unless term_text.empty?
        end
      elsif child.name == "a" && child.parent["class"].to_s.include?("Anchor")
        href = child["href"]&.sub(/\.html\z/, "")
        xrefs << href if href
        term_text = child.text.strip
        text_parts << "{{#{term_text},#{href}}}"
      elsif child.name == "sup"
        text_parts << child.text
      elsif child.name == "sub"
        text_parts << child.text
      elsif child.name == "br"
        text_parts << "\n"
      elsif child.name == "table"
        text_parts << "\n#{serialize_table(child)}"
      else
        inner_text, inner_xrefs = extract_text_with_xrefs(child)
        text_parts << inner_text
        xrefs.concat(inner_xrefs)
      end
    end
  end

  [text_parts.join("").strip, xrefs]
end

def serialize_table(table_node)
  rows = []
  table_node.css("tr").each do |tr|
    cells = tr.css("td, th").map do |cell|
      cell.css("p.TableText").map { |p| p.text.strip.gsub(/\s+/, " ") }.join(" ")
    end.reject(&:empty?)
    rows << cells unless cells.empty?
  end
  return "" if rows.empty?

  # Build an Asciidoc table with |=== delimiters
  max_cols = rows.map(&:size).max
  normalized = rows.map { |r| r + [""] * (max_cols - r.size) }

  lines = []
  lines << "|==="
  normalized.each { |r| lines << "| #{r.join(' | ')}" }
  lines << "|==="
  lines.join("\n")
end

# ═══════════════════════════════════════════════════════════════
# Phase 3: Build Glossarist v3 dataset (YAML generation)
# ═══════════════════════════════════════════════════════════════

def section_for(term_id)
  term_id[/\A(\d+)/, 1]
end

def build_localized_yaml(data)
  {
    "data" => {
      "dates" => [{ "date" => "2012-01-01T00:00:00+00:00", "type" => "accepted" }],
      "definition" => data.definition && !data.definition.empty? ?
        [{ "content" => data.definition }] : [],
      "examples" => data.examples.map { |e| { "content" => e } },
      "id" => "#{data.term_id}-#{data.language_code}",
      "language_code" => data.language_code,
      "notes" => data.notes.map { |n| { "content" => n } },
      "sources" => [{
        "origin" => {
          "ref" => { "source" => SOURCE_REF },
          "locality" => {
            "type" => "clause",
            "reference_from" => data.term_id,
          },
        },
        "type" => "authoritative",
      }],
      "terms" => build_terms_yaml(data),
    },
    "date_accepted" => "2012-01-01T00:00:00+00:00",
    "entry_status" => "valid",
  }
end

def build_terms_yaml(data)
  terms = []

  if data.term_name && !data.term_name.empty?
    terms << {
      "type" => "expression",
      "normative_status" => "preferred",
      "designation" => data.term_name,
    }
  end

  data.admitted_terms.each do |alt|
    terms << {
      "type" => "expression",
      "normative_status" => "admitted",
      "designation" => alt,
    }
  end

  terms
end

def build_concept_file(term_id, eng_data, fra_data)
  concept_uuid = SecureRandom.uuid
  eng_uuid = SecureRandom.uuid
  fra_uuid = SecureRandom.uuid

  localized = { "eng" => eng_uuid }
  localized["fra"] = fra_uuid if fra_data

  managed = {
    "data" => {
      "identifier" => term_id,
      "localized_concepts" => localized,
      "domains" => [{
        "concept_id" => "section-#{section_for(term_id)}",
        "source" => DATASET_SOURCE,
        "ref_type" => "domain",
      }],
      "sources" => [{
        "origin" => {
          "ref" => { "source" => SOURCE_REF },
          "locality" => {
            "type" => "clause",
            "reference_from" => term_id,
          },
        },
        "type" => "authoritative",
      }],
    },
    "status" => "valid",
    "id" => concept_uuid,
    "schema_version" => "3",
  }

  eng_yaml = build_localized_yaml(eng_data)
  eng_yaml["id"] = eng_uuid

  docs = [managed, eng_yaml]

  if fra_data
    fra_yaml = build_localized_yaml(fra_data)
    fra_yaml["id"] = fra_uuid
    docs << fra_yaml
  end

  docs.map { |d| YAML.dump(d) }.join
end

def build_all
  puts "Parsing cached HTML files..."

  concepts_dir = File.join(OUTPUT_DIR, "concepts")
  FileUtils.mkdir_p(concepts_dir)

  concept_ids = []
  errors = []
  stats = { concepts: 0, eng: 0, fra: 0, notes: 0, examples: 0, annotations: 0 }

  TERM_IDS.each_with_index do |term_id, idx|
    printf("[%3d/%d] %s ", idx + 1, TERM_IDS.size, term_id)

    begin
      en_html = load_cached("en", term_id)
      unless en_html
        puts "SKIP (no English HTML cached)"
        errors << "#{term_id}: no cached English page"
        next
      end

      en_data = parse_term(en_html, term_id, "en")
      unless en_data
        puts "SKIP (parse failed)"
        errors << "#{term_id}: English parse failed"
        next
      end

      fr_html = load_cached("fr", term_id)
      fr_data = fr_html ? parse_term(fr_html, term_id, "fr") : nil

      yaml = build_concept_file(term_id, en_data, fr_data)
      File.write(File.join(concepts_dir, "#{term_id}.yaml"), yaml, encoding: "utf-8")
      concept_ids << term_id
      stats[:concepts] += 1
      stats[:eng] += 1
      stats[:fra] += 1 if fr_data
      stats[:notes] += en_data.notes.size
      stats[:examples] += en_data.examples.size
      stats[:annotations] += en_data.notes.count { |n| n.start_with?("[Annotation]") }

      lang = fr_data ? "EN+FR" : "EN"
      n = en_data.notes.size
      e = en_data.examples.size
      a = en_data.notes.count { |n| n.start_with?("[Annotation]") }
      x = (en_data.cross_refs + (fr_data&.cross_refs || [])).uniq.size
      puts "OK #{lang} (#{n}n, #{e}e, #{a}a, #{x}x)"
    rescue => e
      puts "ERROR: #{e.message}"
      errors << "#{term_id}: #{e.message}"
    end
  end

  # Register
  register = {
    "schema_version" => "3",
    "concepts" => concept_ids.sort_by { |id|
      section, num = id.split(".", 2)
      [section.to_i, num.to_i]
    },
  }
  File.write(File.join(OUTPUT_DIR, "register.yaml"), YAML.dump(register), encoding: "utf-8")

  puts
  puts "Stats: #{stats[:concepts]} concepts, #{stats[:notes]} notes, " \
       "#{stats[:examples]} examples, #{stats[:annotations]} annotations"
  puts "Done! #{concept_ids.size} concepts saved to #{OUTPUT_DIR}/."

  if errors.any?
    puts "Errors (#{errors.size}):"
    errors.each { |e| puts "  #{e}" }
  end
end

# ═══════════════════════════════════════════════════════════════
# Phase 4: About pages from info.html
# ═══════════════════════════════════════════════════════════════

def build_about
  LANGUAGES.each do |lang|
    html = load_cached(lang, "info")
    unless html
      puts "  No cached info page for #{lang}"
      next
    end

    doc = Nokogiri::HTML(html, nil, "utf-8")
    content = doc.at_css('div[data-role="content"]')
    next unless content

    lines = []
    lines << (lang == "en" ? "# About this VIM Concept Browser" : "# À propos du navigateur de concepts VIM")
    lines << ""

    content.css("p.info").each do |p|
      text = html_to_markdown(p.inner_html)
      lines << text unless text.empty?
      lines << ""
    end

    content.css("ul.info li").each do |li|
      text = html_to_markdown(li.inner_html)
      lines << "- #{text}"
    end
    lines << ""

    suffix = lang == "en" ? "" : "-fra"
    filename = File.join(File.dirname(__FILE__), "..", "about-vim#{suffix}.md")
    File.write(filename, lines.join("\n"), encoding: "utf-8")
    puts "  Wrote #{filename}"
  end
end

def html_to_markdown(html)
  html
    .gsub(/<i>(.*?)<\/i>/, '_\1_')
    .gsub(/<em>(.*?)<\/em>/, '_\1_')
    .gsub(%r{<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>}, '[\2](\1)')
    .gsub("&mdash;", "—")
    .gsub("&ndash;", "–")
    .gsub("&laquo;", "«")
    .gsub("&raquo;", "»")
    .gsub("&eacute;", "é")
    .gsub("&egrave;", "è")
    .gsub("&ecirc;", "ê")
    .gsub("&agrave;", "à")
    .gsub("&nbsp;", " ")
    .strip
end

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

command = ARGV[0]

case command
when "fetch"
  puts "Phase 1: Fetching all VIM pages..."
  fetch_all
when "build"
  puts "Phase 2: Building Glossarist dataset from cache..."
  build_all
when "about"
  puts "Phase 4: Extracting about pages..."
  build_about
else
  cached_count = LANGUAGES.sum { |l| TERM_IDS.count { |t| cached?(l, t) } }
  if cached_count < TERM_IDS.size * LANGUAGES.size
    puts "Phase 1: Fetching all VIM pages (#{cached_count}/#{TERM_IDS.size * LANGUAGES.size} cached)..."
    fetch_all
    puts
  else
    puts "All #{cached_count} concept pages already cached."
  end
  puts "Phase 2: Building Glossarist dataset..."
  build_all
  puts
  puts "Phase 4: Extracting about pages..."
  build_about
end
