#!/usr/bin/env ruby
# frozen_string_literal: true
# Run GLM-OCR on the VIM 1993 PDF using the resolutions-data GlmOcr library.
# Writes markdown to reference-docs/vim-1993-ocr/glm-ocr.md.

require "fileutils"
require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("..", __dir__))
GLM_LIB   = REPO_ROOT.parent + "resolutions-data/scripts/ocr/glm_ocr.rb"
PDF       = REPO_ROOT + "reference-docs/v002-ef93.pdf"
OUT_DIR   = REPO_ROOT + "reference-docs/vim-1993-ocr"
OUT_FILE  = OUT_DIR + "glm-ocr.md"
NUM_PAGES = 59  # via `pdfinfo reference-docs/v002-ef93.pdf`

require_relative GLM_LIB.to_s

FileUtils.mkdir_p(OUT_DIR)
ocr = ResolutionsData::GlmOcr.new
md  = ocr.ocr_pdf(PDF.to_s, num_pages: NUM_PAGES)
File.write(OUT_FILE, md)
puts "Wrote #{OUT_FILE} (#{md.size} chars)"
