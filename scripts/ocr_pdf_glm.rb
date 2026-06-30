#!/usr/bin/env ruby
# frozen_string_literal: true
# Run GLM-OCR on any source PDF in reference-docs/.
# Output goes to reference-docs/<slug>-ocr/glm-ocr.md.
#
# Usage:
#   ruby scripts/ocr_pdf_glm.rb <pdf_filename> [<slug>]
#
# Example:
#   ruby scripts/ocr_pdf_glm.rb v001-ef13.pdf viml-2013
#
# Page count is auto-detected via pdfinfo (with mdls fallback on macOS).

require "fileutils"
require "open3"
require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("..", __dir__))
GLM_LIB   = REPO_ROOT.parent + "resolutions-data/scripts/ocr/glm_ocr.rb"
REF_DIR   = REPO_ROOT + "reference-docs"
require_relative GLM_LIB.to_s

def page_count(pdf)
  out, _, st = Open3.capture3("pdfinfo", pdf.to_s)
  return $1.to_i if out =~ /^Pages:\s+(\d+)/
  out, = Open3.capture3("mdls", "-name", "kMDItemNumberOfPages", pdf.to_s)
  return $1.to_i if out =~ /=\s+(\d+)/
  raise "cannot determine page count for #{pdf}"
end

pdf_name = ARGV[0] || abort("usage: ocr_pdf_glm.rb <pdf_filename> [<slug>]")
pdf = REF_DIR + pdf_name
abort "PDF not found: #{pdf}" unless pdf.exist?

slug = ARGV[1] || pdf.basename(".pdf").to_s
out_dir = REF_DIR + "#{slug}-ocr"
out_file = out_dir + "glm-ocr.md"

FileUtils.mkdir_p(out_dir)
num_pages = page_count(pdf)
warn "OCR #{pdf_name} (#{num_pages} pages) → #{out_file}"

ocr = ResolutionsData::GlmOcr.new
md  = ocr.ocr_pdf(pdf.to_s, num_pages: num_pages)
File.write(out_file, md)
puts "Wrote #{out_file} (#{md.size} chars)"
