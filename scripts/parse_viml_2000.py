#!/usr/bin/env python3
"""
Parse VIML 2000 edition from v001-ef00.html into Glossarist v3 YAML files.

The PDF→HTML source has bilingual content interleaved by page pairs:
EN block of concepts, then FR block of the same concepts, repeating.
Concept IDs repeat: first occurrence = EN, second occurrence = FR.

Concept numbering: 1.1-1.3, 2.1-2.24, 3.1-3.10, 4.1-4.7 = 44 concepts.
"""

import re
import os
import uuid
import yaml

# ── Configuration ──

DATASET_DIR = "datasets/viml-2000"
CONCEPTS_DIR = f"{DATASET_DIR}/concepts"
SOURCE_FILE = "reference-docs/v001-ef00.html"
EDITION_ID = "viml-2000"
REF = "OIML V 1:2000"
URN_PREFIX = "urn:oiml:pub:v:1:2000"
YEAR = 2000


def extract_lines(html_path):
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
    return bool(re.match(r'^(\d{1,2}\.\d{1,2})$', line))


def find_content_range(lines):
    """Find the start (first EN concept) and end (LIST OF ENTRIES) of concept content."""
    start = 0
    end = len(lines)

    # Start: first concept ID in EN section (after "BASIC TERMS IN LEGAL METROLOGY")
    for i in range(len(lines)):
        if "BASIC TERMS IN LEGAL METROLOGY" in lines[i]:
            # Next concept ID after this is our start
            for j in range(i + 1, min(i + 20, len(lines))):
                if is_concept_id(lines[j]):
                    start = j
                    break
            break

    # End: "LIST OF ENTRIES" marker
    for i in range(start + 10, len(lines)):
        if "LIST OF ENTRIES" in lines[i]:
            end = i
            break

    return start, end


def collect_entries_by_language(lines, start, end):
    """
    Collect concept entries, separating EN and FR by first/second occurrence.

    The PDF→HTML has concept IDs that repeat: first time is EN, second time is FR.
    """
    en_entries = {}  # concept_id -> [text_lines]
    fr_entries = {}

    i = start
    while i < end:
        line = lines[i].strip()
        if is_concept_id(line):
            concept_id = line
            text_lines = []
            j = i + 1
            while j < end:
                if is_concept_id(lines[j].strip()):
                    break
                text_lines.append(lines[j])
                j += 1

            # First occurrence = EN, second occurrence = FR
            if concept_id not in en_entries:
                en_entries[concept_id] = text_lines
            elif concept_id not in fr_entries:
                fr_entries[concept_id] = text_lines
            else:
                # Third occurrence shouldn't happen — skip
                pass

            i = j
        else:
            i += 1

    return en_entries, fr_entries


def parse_entry(text_lines):
    """
    Parse text lines for a single concept entry.

    Structure:
    - Line 1: term name
    - Following lines: definition text (may contain [VIM X.X] source reference)
    - Optional NOTE/NOTES marker followed by note content
    """
    if not text_lines:
        return None

    term_name = ""
    definition_lines = []
    source_ref = None
    notes = []
    current_note_lines = []
    in_notes = False
    in_definition = False

    for i, line in enumerate(text_lines):
        # Check for NOTE/NOTES marker
        if re.match(r'^NOTES?\s*$', line):
            in_notes = True
            continue

        if in_notes:
            # Numbered note: "1 Some text"
            note_num_match = re.match(r'^(\d+)\s+(.+)$', line)
            if note_num_match:
                if current_note_lines:
                    notes.append(' '.join(current_note_lines).strip())
                current_note_lines = [note_num_match.group(2)]
            elif line.startswith('- '):
                current_note_lines.append(line[2:])
            else:
                current_note_lines.append(line)
            continue

        # Check for source reference at end of line: "...text [VIM X.X]"
        vim_match = re.search(r'\[VIM\s+(\d+\.\d+)\]\s*$', line)
        if vim_match:
            before = line[:vim_match.start()].strip()
            source_ref = {"ref": "VIM", "clause": vim_match.group(1)}
            if not in_definition:
                # [VIM X.X] on term line means definition is empty, term is before it
                term_name = before
                in_definition = True
            else:
                if before:
                    definition_lines.append(before)
            continue

        # Standalone [VIM X.X] line
        if re.match(r'^\[VIM\s+(\d+\.\d+)\]$', line):
            vim_standalone = re.match(r'^\[VIM\s+(\d+\.\d+)\]$', line)
            source_ref = {"ref": "VIM", "clause": vim_standalone.group(1)}
            continue

        # First non-special line is the term
        if not in_definition:
            term_name = line
            in_definition = True
            continue

        definition_lines.append(line)

    # Save last note
    if current_note_lines:
        notes.append(' '.join(current_note_lines).strip())

    definition = ' '.join(definition_lines).strip()
    definition = re.sub(r'\s+', ' ', definition).strip()
    term_name = re.sub(r'\s+', ' ', term_name).strip()

    # Handle admitted terms: "type (pattern) evaluation"
    admitted = []
    alt_match = re.match(r'^(.+?)\s+\(([^)]+)\)\s+(.+)$', term_name)
    if alt_match:
        before = alt_match.group(1).strip()
        paren = alt_match.group(2).strip()
        after = alt_match.group(3).strip()
        if paren.lower() in ('pattern', 'modèle'):
            admitted.append(f"{before} ({paren}) {after}")
            term_name = f"{before} {after}"

    return {
        "term_name": term_name,
        "definition": definition,
        "notes": notes,
        "examples": [],
        "source_ref": source_ref,
        "admitted": admitted,
    }


def get_section(concept_id):
    return concept_id.split('.')[0]


def build_concept_yaml(concept_id, eng_data, fra_data, superseded_by=None, supersedes=None):
    concept_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}"))
    eng_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:eng"))
    fra_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:fra"))
    section = get_section(concept_id)

    related = []
    if supersedes:
        related.append({"type": "supersedes", "ref": {"source": "urn:oiml:pub:v:1:1968", "id": supersedes}})
    if superseded_by:
        related.append({"type": "superseded_by", "ref": {"source": "urn:oiml:pub:v:1:2013", "id": superseded_by}})

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
    print(f"Parsing {SOURCE_FILE}...")
    lines = extract_lines(SOURCE_FILE)
    print(f"  Extracted {len(lines)} text lines")

    start, end = find_content_range(lines)
    print(f"  Content range: lines {start}-{end}")

    en_entries, fr_entries = collect_entries_by_language(lines, start, end)
    print(f"  EN entries: {len(en_entries)}, FR entries: {len(fr_entries)}")

    # All unique concept IDs from EN (authoritative for numbering)
    all_ids = sorted(en_entries.keys(),
                     key=lambda x: (int(x.split('.')[0]), int(x.split('.')[1])))
    print(f"  Unique concept IDs: {len(all_ids)}")

    # Check for missing FR entries
    missing_fr = [cid for cid in all_ids if cid not in fr_entries]
    if missing_fr:
        print(f"  WARNING: Missing FR for: {missing_fr}")

    # Load supersession map
    entity_map = load_supersession_map()
    to_2013 = {}
    from_1968 = {}
    for entity, editions in entity_map.items():
        if "viml-2000" in editions and "viml-2013" in editions:
            to_2013[editions["viml-2000"]] = editions["viml-2013"]
        if "viml-2000" in editions and "viml-1968" in editions:
            from_1968[editions["viml-1968"]] = editions["viml-2000"]

    os.makedirs(CONCEPTS_DIR, exist_ok=True)
    concept_ids = []
    errors = []

    for concept_id in all_ids:
        eng_text = en_entries.get(concept_id)
        fra_text = fr_entries.get(concept_id)

        eng_data = parse_entry(eng_text) if eng_text else None
        fra_data = parse_entry(fra_text) if fra_text else None

        superseded_by = to_2013.get(concept_id)
        supersedes = from_1968.get(concept_id)

        try:
            yaml_text = build_concept_yaml(
                concept_id, eng_data, fra_data,
                superseded_by=superseded_by,
                supersedes=supersedes,
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
        print(f"  {concept_id:5s}: EN={eng_term[:35]:35s} ({eng_def_len:3d}c,{eng_notes}n)  FR={fra_term[:35]:35s} ({fra_def_len:3d}c,{fra_notes}n)")

        concept_ids.append(concept_id)

    # Write register
    register = {
        "schema_version": "3",
        "edition": {"id": EDITION_ID, "ref": REF, "year": YEAR, "urn_prefix": URN_PREFIX, "status": "superseded", "supersedes": "viml-1968"},
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
