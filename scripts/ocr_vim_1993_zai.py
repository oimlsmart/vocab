#!/usr/bin/env python3
"""
Re-OCR the VIM 1993 PDF using Z.AI GLM-OCR API.

Outputs markdown text for each page range, saved to reference-docs/vim-1993-ocr/.
Usage:
    python3 scripts/ocr_vim_1993_zai.py [--pages START END] [--all]
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

API_URL = "https://api.z.ai/api/paas/v4/layout_parsing"
MODEL = "glm-ocr"
MAX_PAGES_PER_REQUEST = 20

REPO_ROOT = Path(__file__).resolve().parent.parent
PDF_PATH = REPO_ROOT / "reference-docs" / "v002-ef93.pdf"
OUTPUT_DIR = REPO_ROOT / "reference-docs" / "vim-1993-ocr"


def load_api_key():
    key_file = Path.home() / ".zai-api-key"
    if not key_file.exists():
        print(f"Error: API key file not found at {key_file}", file=sys.stderr)
        sys.exit(1)
    content = key_file.read_text().strip()
    # Handle "export Z_AI_API_KEY=..." format
    if "=" in content:
        return content.split("=", 1)[1].strip()
    return content


def pdf_to_base64(path):
    return base64.b64encode(path.read_bytes()).decode("utf-8")


def call_ocr(api_key, pdf_b64, start_page=None, end_page=None):
    import urllib.request
    import urllib.error

    body = {
        "model": MODEL,
        "file": f"data:application/pdf;base64,{pdf_b64}",
    }
    if start_page is not None:
        body["start_page_id"] = start_page
    if end_page is not None:
        body["end_page_id"] = end_page

    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    print(f"  Requesting pages {start_page or 0}–{end_page or 'end'}...", end=" ", flush=True)
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            result = json.loads(resp.read().decode("utf-8"))
        print("done.")
        return result
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {error_body[:500]}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return None


def extract_markdown(result):
    """Extract combined markdown from Z.AI response."""
    if not result:
        return None

    # Response structure: { "data": { "md_results": [...], ... } }
    # Each md_result has "md" field with markdown text
    data = result.get("data", result)
    md_results = data.get("md_results", [])

    if not md_results:
        # Try top-level
        md_results = result.get("md_results", [])

    parts = []
    for i, md_item in enumerate(md_results):
        if isinstance(md_item, dict):
            md_text = md_item.get("md", md_item.get("text", ""))
            page_num = md_item.get("page_id", i)
            parts.append(f"<!-- Page {page_num} -->\n{md_text}")
        elif isinstance(md_item, str):
            parts.append(md_item)

    return "\n\n".join(parts) if parts else None


def get_page_count(result):
    """Get page count from response."""
    data = result.get("data", result)
    data_info = data.get("data_info", {})
    if data_info:
        return data_info.get("page_count", 0)
    return 0


def ocr_all_pages(api_key, pdf_b64, total_pages):
    """OCR the entire PDF in batches."""
    all_results = []

    for start in range(0, total_pages, MAX_PAGES_PER_REQUEST):
        end = min(start + MAX_PAGES_PER_REQUEST - 1, total_pages - 1)
        result = call_ocr(api_key, pdf_b64, start_page=start, end_page=end)

        if result:
            md_text = extract_markdown(result)
            if md_text:
                all_results.append(md_text)
                out_file = OUTPUT_DIR / f"pages-{start:03d}-{end:03d}.md"
                out_file.write_text(md_text, encoding="utf-8")
                print(f"  Saved: {out_file}")
            else:
                print(f"  Warning: No markdown in response for pages {start}–{end}")
                # Save raw response for debugging
                raw_file = OUTPUT_DIR / f"pages-{start:03d}-{end:03d}-raw.json"
                raw_file.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        else:
            print(f"  Failed for pages {start}–{end}")

        if start + MAX_PAGES_PER_REQUEST < total_pages:
            print("  Waiting 5s before next batch...")
            time.sleep(5)

    return all_results


def ocr_page_range(api_key, pdf_b64, start, end):
    """OCR a specific page range."""
    result = call_ocr(api_key, pdf_b64, start_page=start, end_page=end)

    if result:
        md_text = extract_markdown(result)
        if md_text:
            out_file = OUTPUT_DIR / f"pages-{start:03d}-{end:03d}.md"
            out_file.write_text(md_text, encoding="utf-8")
            print(f"Saved: {out_file}")

        raw_file = OUTPUT_DIR / f"pages-{start:03d}-{end:03d}-raw.json"
        raw_file.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Raw response: {raw_file}")
        return md_text
    else:
        print("Failed.")
        return None


def main():
    parser = argparse.ArgumentParser(description="Re-OCR VIM 1993 PDF via Z.AI GLM-OCR")
    parser.add_argument("--pages", nargs=2, type=int, metavar=("START", "END"),
                        help="OCR specific page range (0-indexed)")
    parser.add_argument("--all", action="store_true", help="OCR all pages in batches")
    parser.add_argument("--total-pages", type=int, default=59,
                        help="Total pages in PDF (default: 59)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    api_key = load_api_key()
    print(f"PDF: {PDF_PATH} ({PDF_PATH.stat().st_size / 1024 / 1024:.1f} MB)")
    print(f"Output: {OUTPUT_DIR}")

    pdf_b64 = pdf_to_base64(PDF_PATH)
    print(f"Base64 encoded: {len(pdf_b64)} chars")

    if args.pages:
        ocr_page_range(api_key, pdf_b64, args.pages[0], args.pages[1])
    elif args.all:
        results = ocr_all_pages(api_key, pdf_b64, args.total_pages)
        if results:
            combined = "\n\n---\n\n".join(results)
            combined_file = OUTPUT_DIR / "vim-1993-full.md"
            combined_file.write_text(combined, encoding="utf-8")
            print(f"\nCombined output: {combined_file}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
