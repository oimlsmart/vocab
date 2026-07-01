#!/usr/bin/env ruby
# frozen_string_literal: true
# Run GLM-OCR on any source PDF in reference-docs/.
# Output goes to reference-docs/<slug>-ocr/glm-ocr.md.
#
# Usage:
#   ruby scripts/ocr_pdf_glm.rb <pdf_filename> [<slug>]
#
# Auto-splits PDFs exceeding the GLM API's 100-page limit using pdftk,
# OCRs each chunk, and concatenates the markdown output.
#
# Example:
#   ruby scripts/ocr_pdf_glm.rb v001-ef13.pdf viml-2013
#   ruby scripts/ocr_pdf_glm.rb v002-200-e07.pdf vim-2007   # 150 pages → 3 chunks of 50

require "fileutils"
require "open3"
require "pathname"
require "tempfile"

REPO_ROOT = Pathname.new(File.expand_path("..", __dir__))
GLM_LIB   = REPO_ROOT.parent + "resolutions-data/scripts/ocr/glm_ocr.rb"
REF_DIR   = REPO_ROOT + "reference-docs"
require_relative GLM_LIB.to_s

GLM_PAGE_LIMIT = 100
CHUNK_SIZE = 50 # smaller than the limit to reduce false-positive content-filter hits

def page_count(pdf)
  out, _, = Open3.capture3("pdfinfo", pdf.to_s)
  return $1.to_i if out =~ /^Pages:\s+(\d+)/
  out, = Open3.capture3("mdls", "-name", "kMDItemNumberOfPages", pdf.to_s)
  return $1.to_i if out =~ /=\s+(\d+)/
  raise "cannot determine page count for #{pdf}"
end

def split_pdf(pdf, chunks_outdir)
  total = page_count(pdf)
  paths = []
  (1..total).each_slice(CHUNK_SIZE).with_index do |window, idx|
    start_p = window.first
    end_p   = [window.last, total].min
    out = File.join(chunks_outdir, "chunk-#{idx}-p#{start_p}-#{end_p}.pdf")
    unless system("pdftk", pdf.to_s, "cat", "#{start_p}-#{end_p}", "output", out, out: "/dev/null", err: "/dev/null")
      raise "pdftk failed to split #{pdf} pages #{start_p}-#{end_p}"
    end
    paths << [out, start_p, end_p]
  end
  paths
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

if num_pages <= GLM_PAGE_LIMIT
  md = ocr.ocr_pdf(pdf.to_s, num_pages: num_pages)
else
  warn "  PDF exceeds GLM #{GLM_PAGE_LIMIT}-page limit; splitting via pdftk (chunk size: #{CHUNK_SIZE} pages)"
  Dir.mktmpdir("#{slug}-chunks-") do |tmp|
    chunks = split_pdf(pdf, tmp)
    warn "  split into #{chunks.size} chunks: " +
         chunks.map { |_, s, e| "p#{s}-#{e}" }.join(", ")
    parts = chunks.map do |chunk_path, start_p, end_p|
      chunk_pages = page_count(Pathname.new(chunk_path))
      warn "  OCR chunk #{File.basename(chunk_path)} (pages #{start_p}-#{end_p}, #{chunk_pages} pages)"
      begin
        ocr.ocr_pdf(chunk_path, num_pages: chunk_pages)
      rescue RuntimeError => e
        if e.message =~ /1301|content/i
          warn "  CONTENT FILTER on pages #{start_p}-#{end_p}; skipping chunk"
          "<!-- CONTENT FILTER SKIP: pages #{start_p}-#{end_p} of #{pdf_name} -->\n\n"
        else
          raise
        end
      end
    end
    md = parts.join("\n\n<!-- page-break (chunk boundary) -->\n\n")
  end
end

File.write(out_file, md)
puts "Wrote #{out_file} (#{md.size} chars)"
