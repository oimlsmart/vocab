#!/usr/bin/env ruby
# Regenerate ALL 276 viml-1968 concept files from OCR body text.
# Uses the authoritative INDEX (from compare_viml_1968_index.rb) for
# concept numbering and term names, and OCR body text for definitions/notes/examples.
require "yaml"
require "securerandom"

INDEX = YAML.load_file("/tmp/viml1968_index.yaml")

OUTDIR = "datasets/viml-1968/concepts"

# OCR ID remap (where OCR body numbering differs from index)
OCR_ID_MAP = {
  "7.4.4.2.5" => "7.4.5.2",
}

# Section mapping: chapter => section_id
SECTION_MAP = Hash.new { |h, k| h[k] = "section-#{k}" }

def parse_ocr(md)
  concepts = {}
  lines = md.split("\n")
  i = 0
  while i < lines.length
    line = lines[i]
    if (m = line.match(/^##\s+(\d[\d.,]*\d(?:\.\d+)*)\.?\s+(.+)$/i))
      raw_id = m[1].gsub(",", ".")
      term_text = m[2].strip
      next if term_text =~ /^(Remarques?|Examples?|Exemples?|Préambule|CHAPITRE|LISTE|APPEL)/i
      raw_id = OCR_ID_MAP.fetch(raw_id, raw_id)
      content_lines = []
      i += 1
      while i < lines.length
        break if lines[i] =~ /^##\s+\d[\d.,]*\d/
        break if lines[i] =~ /^#\s+(CHAPITRE|ORGANISMES|INSTRUMENTS|CONDITIONS)/
        break if lines[i] =~ /^<div\s/
        content_lines << lines[i] unless lines[i] =~ /^!\[/
        i += 1
      end
      content = content_lines.join("\n").strip
      concepts[raw_id] = { ocr_term: term_text, content: content }
    else
      i += 1
    end
  end
  concepts
end

def parse_content(content)
  return { definition: "", notes: [], examples: [] } if content.nil? || content.strip.empty?
  lines = content.split("\n")
  definition_parts = []
  notes = []
  examples = []
  current = :definition
  lines.each do |line|
    s = line.strip
    if s =~ /^##\s*(Remarques?|Remarque\s*:)/i
      current = :notes
      next
    elsif s =~ /^##\s*(Examples?|Exemples?|Exemple\s*:)/i
      current = :examples
      next
    elsif s =~ /^Remarque\s*:/i
      notes << s.sub(/^Remarque\s*:\s*/i, "")
      current = :notes
      next
    elsif s.empty?
      next
    end
    case current
    when :definition then definition_parts << s
    when :notes then notes << s
    when :examples then examples << s
    end
  end
  { definition: definition_parts.join(" "), notes: notes, examples: examples }
end

def build_yaml(identifier, section_id, terms, definition, notes, examples)
  managed_id = SecureRandom.uuid
  localized_id = SecureRandom.uuid
  managed = {
    "data" => {
      "identifier" => identifier,
      "localized_concepts" => { "fra" => localized_id },
      "domains" => [{ "concept_id" => section_id, "source" => "urn:oiml:pub:v:1:1968", "ref_type" => "section" }]
    },
    "status" => "valid",
    "id" => managed_id,
    "schema_version" => "3"
  }
  terms_arr = terms.map.with_index { |t, i|
    { "type" => "expression", "normative_status" => i == 0 ? "preferred" : "admitted", "designation" => t }
  }
  def_arr = definition.nil? || definition.strip.empty? ? [] : [{ "content" => definition }]
  notes_arr = notes.map { |n| { "content" => n } }
  ex_arr = examples.map { |e| { "content" => e } }
  localized = {
    "data" => {
      "dates" => [{ "date" => "1968-01-01T00:00:00+00:00", "type" => "accepted" }],
      "definition" => def_arr,
      "examples" => ex_arr,
      "id" => "#{identifier}-fra",
      "notes" => notes_arr,
      "sources" => [],
      "terms" => terms_arr
    },
    "language_code" => "fra",
    "entry_status" => "valid",
    "date_accepted" => "1968-01-01T00:00:00+00:00",
    "id" => localized_id
  }
  YAML.dump(managed) + "---\n" + YAML.dump(localized).sub(/\A---\n/, "")
end

# Main
md = File.read("/tmp/viml1968_ocr.md")
ocr_concepts = parse_ocr(md)
puts "OCR body has #{ocr_concepts.size} concept headings"

# Build term-to-OCR-ID lookup for fuzzy matching
term_to_ocr = {}
ocr_concepts.each do |ocr_id, data|
  norm = data[:ocr_term].downcase.gsub(/['']/, "'").strip
  term_to_ocr[norm] = ocr_id
end

created = 0
not_found = []

INDEX.sort_by { |k, _| k.split(".").map(&:to_i) }.each do |index_id, terms|
  # Try exact ID match first
  parsed = parse_content(ocr_concepts[index_id]&.dig(:content))

  # If no content found by ID, try to match by term name
  if parsed[:definition].empty?
    found_id = nil
    terms.each do |term|
      norm_term = term.downcase.gsub(/['']/, "'").strip
      # Exact match
      if term_to_ocr.key?(norm_term)
        found_id = term_to_ocr[norm_term]
        break
      end
      # Prefix match (OCR may have truncated or different text)
      ocr_concepts.each do |ocr_id, data|
        ocr_norm = data[:ocr_term].downcase.gsub(/['']/, "'").strip
        if ocr_norm.include?(norm_term[0..20]) || norm_term.include?(ocr_norm[0..20])
          found_id = ocr_id
          break
        end
      end
      break if found_id
    end

    if found_id
      parsed = parse_content(ocr_concepts[found_id][:content])
    else
      not_found << index_id
    end
  end

  chapter = index_id.split(".").first
  section_id = SECTION_MAP[chapter]

  yaml = build_yaml(index_id, section_id, terms, parsed[:definition], parsed[:notes], parsed[:examples])
  File.write(File.join(OUTDIR, "#{index_id}.yaml"), yaml)
  created += 1
end

puts "Created #{created} files from INDEX"
if not_found.any?
  puts "\nNot found (#{not_found.size}):"
  not_found.each { |id| puts "  #{id}: #{INDEX[id].join('; ')}" }
end

# List any OCR concepts not covered by INDEX
index_ids = INDEX.keys.to_set
ocr_extra = ocr_concepts.keys.reject { |k| index_ids.include?(k) }
if ocr_extra.any?
  puts "\nOCR concepts not in INDEX (#{ocr_extra.size}):"
  ocr_extra.sort_by { |k| k.split(".").map(&:to_i) }.each do |id|
    puts "  #{id}: #{ocr_concepts[id][:ocr_term]}"
  end
end
