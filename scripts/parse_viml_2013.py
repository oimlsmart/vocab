#!/usr/bin/env python3
"""
Parse VIML 2013 edition from V001-ef13.html into Glossarist v3 YAML files.

The Word HTML has each text element on its own line. Structure per concept:
  Line 1: concept ID (e.g. "0.01")
  Line 2+: term name (may span multiple lines)
  Then: definition text (multiple lines)
  Then: source reference "[OIML V2-200:2012, X.X]]" or "[ISO/IEC 17000:2004, X.X]]"
  Then: optional "Note" or "Note N" lines
  Then: optional note text

EN and FR entries are interleaved (EN first, FR second).
Uses VIML 2022 dataset as reference for correct term names.
"""

import re
import os
import uuid
import yaml
from pathlib import Path

# ── Configuration ──

DATASET_DIR = "datasets/viml-2013"
CONCEPTS_DIR = f"{DATASET_DIR}/concepts"
SOURCE_FILE = "reference-docs/V001-ef13.html"
EDITION_ID = "viml-2013"
REF = "OIML V 1:2013"
URN_PREFIX = "urn:oiml:pub:v:1:2013"
YEAR = 2013

# ── Load VIML 2022 reference terms ──

def load_reference_terms():
    """Load term names from VIML 2022 for comparison."""
    terms = {}
    concepts_dir = "datasets/viml-2022/concepts"
    if not os.path.exists(concepts_dir):
        return terms
    for fname in os.listdir(concepts_dir):
        if not fname.endswith('.yaml'):
            continue
        with open(os.path.join(concepts_dir, fname), encoding='utf-8') as f:
            docs = list(yaml.safe_load_all(f))
        cid = None
        for d in docs:
            if not d or 'data' not in d:
                continue
            data = d['data']
            if 'identifier' in data:
                cid = data['identifier']
            if 'language_code' in data and cid:
                lang = data['language_code']
                for t in data.get('terms', []):
                    desig = t.get('designation', '')
                    if desig and t.get('normative_status') == 'preferred':
                        key = f"{cid}:{lang}"
                        terms[key] = desig
                        # Also store admitted terms
                    elif desig and t.get('normative_status') == 'admitted':
                        akey = f"{cid}:{lang}:admitted"
                        terms.setdefault(akey, []).append(desig)
    return terms


def extract_lines(html_path):
    """Extract text lines from HTML, stripping tags and CSS."""
    with open(html_path, encoding="utf-8") as f:
        html = f.read()
    html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL)
    html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', '\n', html)
    text = re.sub(r'&nbsp;', ' ', text)
    text = re.sub(r'&#\d+;', ' ', text)
    lines = [l.strip() for l in text.split('\n') if l.strip()]
    return lines


def is_concept_id(line):
    """Check if a line is a standalone concept ID."""
    return bool(re.match(r'^(\d{1,2}\.\d{2}|[Aa]\.\d{1,2})$', line))


def find_content_range(lines):
    """Find the start and end of concept content (excluding TOC and index)."""
    # Start: first "0.01" followed by "metrology" (actual content, not TOC)
    start = 0
    for i in range(len(lines) - 1):
        if lines[i] == "0.01" and "metrology" in lines[i+1].lower():
            start = i
            break

    # End: "Alphabetical index" after the Annex A content
    end = len(lines)
    for i in range(start + 100, len(lines)):
        if "Alphabetical index" in lines[i] or "Index alphab" in lines[i]:
            end = i
            break

    return start, end


def collect_entries(lines, start, end):
    """
    Collect all concept entries as (concept_id, [text_lines]) tuples.
    Each entry spans from one concept ID to the next.
    """
    entries = []
    i = start
    while i < end:
        line = lines[i].strip()
        if is_concept_id(line) and line != "16.00":
            concept_id = line
            # Collect all lines until the next concept ID
            text_lines = []
            j = i + 1
            while j < end:
                if is_concept_id(lines[j].strip()) and lines[j].strip() != "16.00":
                    break
                text_lines.append(lines[j])
                j += 1
            entries.append((concept_id, text_lines))
            i = j
        else:
            i += 1
    return entries


def parse_entry_lines(text_lines, ref_term=None):
    """
    Parse a list of text lines into structured concept data.

    Line-by-line structure:
    - Term name lines (one or more lines at the start)
    - Definition lines
    - Source reference line: "[OIML V2-200:2012, 2.2]]" (may span multiple lines)
    - "Note" or "Note N" line
    - Note text lines
    """
    if not text_lines:
        return None

    # Phase 1: Identify structural boundaries line by line
    # Look for: "Note", "Note N", source refs starting with "[", bullet points "•"

    source_lines = []
    notes = []  # list of (note_num_or_None, [text_lines])
    definition_lines = []
    term_lines = []

    phase = "term"  # term -> definition -> source -> notes
    current_note_num = None
    current_note_lines = []

    i = 0
    while i < len(text_lines):
        line = text_lines[i]

        # Check for source reference: lines starting with "[" or continuing a "[..." pattern
        if phase in ("definition", "term") and line.startswith('['):
            # Could be a source reference
            # Accumulate source lines until we see "]]" or a Note
            source_lines.append(line)
            phase = "source"
            i += 1
            continue

        if phase == "source":
            source_lines.append(line)
            i += 1
            continue

        # Check for "Note" or "Note N"
        if re.match(r'^Note\s*(\d*)\s*$', line):
            # Save previous note if any
            if current_note_lines:
                notes.append((current_note_num, current_note_lines))
                current_note_lines = []
            note_num_match = re.match(r'^Note\s*(\d*)\s*$', line)
            current_note_num = note_num_match.group(1) if note_num_match.group(1) else None
            phase = "notes"
            i += 1
            continue

        # In notes phase, lines are note content
        if phase == "notes":
            current_note_lines.append(line)
            i += 1
            continue

        # In definition phase
        if phase == "term":
            # First line(s) could be term or definition start
            # Use reference term if available to determine boundary
            term_lines.append(line)
            phase = "definition"
            i += 1
            continue

        # definition phase
        definition_lines.append(line)
        i += 1

    # Save last note
    if current_note_lines:
        notes.append((current_note_num, current_note_lines))

    # Phase 2: Parse source reference
    source_ref = None
    if source_lines:
        source_text = ' '.join(source_lines)
        # Pattern: [OIML V2-200:2012, 2.2] or [ISO/IEC 17000:2004, 2.1]
        # May have extra ] from HTML encoding
        source_text = source_text.replace(']]', ']')
        m = re.match(r'\[([^\],]+?)(?:,\s*([^\]]+?))?\]', source_text)
        if m:
            source_ref = {"ref": m.group(1).strip()}
            if m.group(2):
                source_ref["clause"] = m.group(2).strip()

    # Phase 3: Determine term vs definition using reference term
    all_text = ' '.join(term_lines + definition_lines)

    term_name = ""
    definition = ""

    if ref_term and ref_term in all_text:
        # Use the reference term to split
        idx = all_text.index(ref_term)
        before = all_text[:idx].strip()
        after_term = all_text[idx + len(ref_term):].strip()

        if before:
            # Term has text before the ref_term — prepend
            term_name = all_text[:idx + len(ref_term)].strip()
            definition = after_term
        else:
            term_name = ref_term
            definition = after_term
    else:
        # No reference term — split using heuristics
        term_name, definition = heuristic_split(all_text)

    # Phase 4: Parse notes
    parsed_notes = []
    for note_num, note_lines in notes:
        note_text = ' '.join(note_lines).strip()
        # Clean up bullet points
        note_text = re.sub(r'\s*•\s*', ' ', note_text)
        note_text = re.sub(r'\s+', ' ', note_text).strip()
        if note_text:
            parsed_notes.append(note_text)

    # Clean up definition
    definition = re.sub(r'\s*•\s*', ' ', definition)
    definition = re.sub(r'\s+', ' ', definition).strip()

    # Handle admitted terms in parentheses: "term (alt1, alt2)"
    admitted = []
    admitted_match = re.match(r'^(.+?)\s+\(([^)]+)\)\s*$', term_name)
    if admitted_match:
        term_name = admitted_match.group(1).strip()
        admitted_str = admitted_match.group(2).strip()
        admitted = [a.strip() for a in admitted_str.split(',') if a.strip()]

    return {
        "term_name": term_name.strip(),
        "definition": definition.strip(),
        "notes": parsed_notes,
        "examples": [],
        "source_ref": source_ref,
        "admitted": admitted,
    }


def heuristic_split(text):
    """
    Split text into term name and definition using heuristics.
    Term is the initial capitalized words; definition starts at first lowercase.
    """
    if not text:
        return ("", "")

    words = text.split()
    if not words:
        return ("", "")

    # Special connector words that are part of terms
    connectors = {'of', 'a', 'in', 'for', 'to', 'the', 'and', 'or', 'with', 'by',
                  'from', 'on', 'at', 'an', 'into', 'through', 'per',
                  'de', 'du', 'des', 'la', 'le', 'les', "d'", "l'", 'à', 'au', 'aux',
                  'en', 'et', 'ou', 'pour', 'dans', 'sur', 'par', 'un', 'une',
                  'ou', 'ni', 'chez', 'sous', 'avec', 'sans', 'vers'}

    # Track: initially all words are "term candidates"
    # Find the split point: first word that starts lowercase AND is not a connector
    # AND is preceded by a non-connector word

    term_end = 0
    for i in range(len(words)):
        word = words[i]
        # Term continues if: starts with uppercase, is a connector, or is first word
        if i == 0:
            term_end = i + 1
        elif word[0].isupper() or word in connectors or word.startswith('('):
            term_end = i + 1
        elif re.match(r'^[-/]', word):
            # hyphenated or slashed compound
            term_end = i + 1
        else:
            # First non-connector lowercase word = definition start
            break

    if term_end == 0:
        term_end = 1

    term = ' '.join(words[:term_end])
    defn = ' '.join(words[term_end:])
    return (term, defn)


def detect_language(text_lines):
    """Detect if a block of text lines is English or French."""
    text = ' '.join(text_lines).lower()
    fr_markers = ['des ', 'du ', 'de la ', "d'un", 'les ', 'dans ',
                  'métrologie', 'conformité', 'organisme', 'règlement',
                  'étalon', 'mesurage', 'mésurage']
    en_markers = ['measurement', 'metrology', 'conformity', 'body',
                  'regulation', 'standard', 'measuring', 'assessment']
    fr = sum(1 for m in fr_markers if m in text)
    en = sum(1 for m in en_markers if m in text)
    return 'fra' if fr > en else 'eng'


def get_section(concept_id):
    section = concept_id.split('.')[0]
    return section.upper() if section == 'a' else section


def build_concept_yaml(concept_id, eng_data, fra_data, superseded_by=None, supersedes=None):
    concept_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}"))
    eng_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:eng"))
    fra_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:fra"))
    section = get_section(concept_id)

    related = []
    if supersedes:
        related.append({"type": "supersedes", "ref": {"source": "urn:oiml:pub:v:1:2000", "id": supersedes}})
    if superseded_by:
        related.append({"type": "superseded_by", "ref": {"source": "urn:oiml:pub:v:1:2022", "id": superseded_by}})

    header = {
        "data": {
            "identifier": concept_id,
            "localized_concepts": {"eng": eng_uuid, "fra": fra_uuid},
            "domains": [{"concept_id": f"section-{section}", "source": URN_PREFIX, "ref_type": "domain"}],
        },
        "status": "valid",
        "id": concept_uuid,
        "schema_version": "3",
    }
    if related:
        header["related"] = related

    eng_loc = build_localization(concept_id, eng_data, "eng")
    fra_loc = build_localization(concept_id, fra_data, "fra")

    docs = [header, eng_loc, fra_loc]
    return "---\n" + "\n---\n".join(
        yaml.dump(d, allow_unicode=True, default_flow_style=False, sort_keys=False)
        for d in docs
    )


def build_localization(concept_id, data, lang):
    loc_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:{lang}"))
    loc = {
        "data": {
            "dates": [{"date": f"{YEAR}-01-01T00:00:00+00:00", "type": "accepted"}],
            "definition": [],
            "examples": [],
            "id": f"{concept_id}-{lang}",
            "notes": [],
            "sources": [],
            "terms": [],
        },
        "language_code": lang,
        "entry_status": "valid",
    }

    if data:
        if data.get("definition"):
            loc["data"]["definition"] = [{"content": data["definition"]}]
        if data.get("notes"):
            loc["data"]["notes"] = [{"content": n} for n in data["notes"]]
        if data.get("examples"):
            loc["data"]["examples"] = [{"content": e} for e in data["examples"]]
        if data.get("source_ref"):
            sr = data["source_ref"]
            src = {"origin": {"ref": {"source": sr["ref"]}}, "type": "authoritative"}
            if sr.get("clause"):
                src["origin"]["locality"] = {"type": "clause", "reference_from": sr["clause"]}
            loc["data"]["sources"] = [src]
        terms = [{"type": "expression", "normative_status": "preferred", "designation": data.get("term_name", "")}]
        for alt in data.get("admitted", []):
            terms.append({"type": "expression", "normative_status": "admitted", "designation": alt})
        loc["data"]["terms"] = terms

    loc["date_accepted"] = f"{YEAR}-01-01T00:00:00+00:00"
    loc["id"] = loc_uuid
    return loc


def load_supersession_map():
    with open("supersession-map.yaml", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    entity_map = {}
    for mapping in data.get("mappings", []):
        entity = mapping["entity"]
        entity_map[entity] = {k: v for k, v in mapping.items() if k not in ("entity", "annotation")}
    return entity_map


def main():
    print(f"Loading reference terms from VIML 2022...")
    ref_terms = load_reference_terms()
    print(f"  Loaded {len(ref_terms)} reference term entries")

    print(f"Parsing {SOURCE_FILE}...")
    lines = extract_lines(SOURCE_FILE)
    print(f"  Extracted {len(lines)} text lines")

    start, end = find_content_range(lines)
    print(f"  Content range: lines {start}-{end}")

    raw_entries = collect_entries(lines, start, end)
    print(f"  Found {len(raw_entries)} raw entries")

    # Group by concept ID (EN then FR interleaved)
    grouped = {}
    for concept_id, text_lines in raw_entries:
        if concept_id not in grouped:
            grouped[concept_id] = []
        grouped[concept_id].append(text_lines)

    print(f"  Grouped into {len(grouped)} unique concept IDs")

    # Load supersession map
    entity_map = load_supersession_map()
    to_2000 = {}
    to_2022 = {}
    for entity, editions in entity_map.items():
        if "viml-2013" in editions and "viml-2000" in editions:
            to_2000[editions["viml-2013"]] = editions["viml-2000"]
        if "viml-2013" in editions and "viml-2022" in editions:
            to_2022[editions["viml-2013"]] = editions["viml-2022"]
        elif "viml-2013" in editions:
            to_2022[editions["viml-2013"]] = editions["viml-2013"]

    os.makedirs(CONCEPTS_DIR, exist_ok=True)
    concept_ids = []
    errors = []

    for concept_id in sorted(grouped.keys(), key=lambda x: (
        0 if x[0] in '0123456789' else 1,
        999 if x.split('.')[0] in ('A', 'a') else int(x.split('.')[0]) if x.split('.')[0].isdigit() else 99,
        int(x.split('.')[1]) if len(x.split('.')) > 1 else 0
    )):
        entry_list = grouped[concept_id]

        # Get reference terms for this concept
        ref_eng = ref_terms.get(f"{concept_id}:eng", "")
        ref_fra = ref_terms.get(f"{concept_id}:fra", "")

        # Determine EN/FR entries
        if len(entry_list) == 2:
            first_lang = detect_language(entry_list[0])
            second_lang = detect_language(entry_list[1])

            if first_lang == 'eng':
                eng_text, fra_text = entry_list[0], entry_list[1]
            elif first_lang == 'fra':
                eng_text, fra_text = entry_list[1], entry_list[0]
            else:
                # Default: first = EN, second = FR
                eng_text, fra_text = entry_list[0], entry_list[1]
        elif len(entry_list) > 2:
            # Multiple entries — pick the two longest (TOC entries are shorter)
            indexed = [(sum(len(l) for l in t), i, t) for i, t in enumerate(entry_list)]
            indexed.sort(key=lambda x: x[0], reverse=True)
            first, second = indexed[0][2], indexed[1][2]
            if detect_language(first) == 'eng':
                eng_text, fra_text = first, second
            else:
                eng_text, fra_text = second, first
        else:
            text = entry_list[0]
            lang = detect_language(text)
            if lang == 'eng':
                eng_text, fra_text = text, None
            else:
                eng_text, fra_text = None, text

        eng_data = parse_entry_lines(eng_text, ref_eng) if eng_text else None
        fra_data = parse_entry_lines(fra_text, ref_fra) if fra_text else None

        # Get supersession info
        supersedes_2000 = to_2000.get(concept_id)
        superseded_by_2022 = to_2022.get(concept_id)

        try:
            yaml_text = build_concept_yaml(
                concept_id, eng_data, fra_data,
                superseded_by=superseded_by_2022,
                supersedes=supersedes_2000,
            )
        except Exception as e:
            errors.append(f"{concept_id}: {e}")
            continue

        filepath = f"{CONCEPTS_DIR}/{concept_id}.yaml"
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(yaml_text)

        eng_term = eng_data.get("term_name", "?") if eng_data else "?"
        fra_term = fra_data.get("term_name", "?") if fra_data else "?"
        eng_def_len = len(eng_data.get("definition", "")) if eng_data else 0
        fra_def_len = len(fra_data.get("definition", "")) if fra_data else 0
        eng_notes = len(eng_data.get("notes", [])) if eng_data else 0
        fra_notes = len(fra_data.get("notes", [])) if fra_data else 0
        print(f"  {concept_id:8s}: EN={eng_term[:35]:35s} ({eng_def_len:3d}c,{eng_notes}n)  FR={fra_term[:35]:35s} ({fra_def_len:3d}c,{fra_notes}n)")

        concept_ids.append(concept_id)

    # Write register
    register = {
        "schema_version": "3",
        "edition": {"id": EDITION_ID, "ref": REF, "year": YEAR, "urn_prefix": URN_PREFIX, "status": "superseded", "supersedes": "viml-2000"},
        "concepts": concept_ids,
    }
    with open(f"{DATASET_DIR}/register.yaml", 'w', encoding='utf-8') as f:
        yaml.dump(register, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

    print(f"\nDone: {len(concept_ids)} concepts written to {DATASET_DIR}/")
    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  {e}")


if __name__ == "__main__":
    main()
