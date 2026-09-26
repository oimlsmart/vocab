#!/usr/bin/env node

/**
 * Post-build robots injection — vocab's own noindex mechanism.
 *
 * The standing owner directive (2026-09-26) is noindex on all family
 * sites. vocab is exempt from the site-shell conformance that carries
 * the directive elsewhere, so the directive lands here instead: a
 * post-build pass over dist/ that stamps
 * `<meta name="robots" content="noindex, nofollow">` into every HTML
 * page the build emitted (the Astro build produces per-route HTML, so
 * index.html alone is not enough) and installs the committed
 * robots.txt (open crawl, so the de-index can propagate).
 *
 * Idempotent: a page that already carries a robots meta is left
 * untouched, so the script is safe to run twice over the same dist/.
 *
 * Self-verifying: after the pass, every HTML file must carry the meta
 * exactly once and dist/robots.txt must exist; otherwise the script
 * exits non-zero and fails the build.
 */

import { readFileSync, writeFileSync, readdirSync, statSync, copyFileSync, existsSync } from 'fs';
import { resolve, join, dirname } from 'path';
import { fileURLToPath } from 'url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const distDir = resolve(repoRoot, 'dist');
const robotsSrc = resolve(repoRoot, 'robots.txt');
const robotsDest = resolve(distDir, 'robots.txt');

const META = '<meta name="robots" content="noindex, nofollow" />';
const META_PRESENT = /<meta\s+name="robots"/i;

function* walkHtml(dir) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) {
      yield* walkHtml(p);
    } else if (entry.endsWith('.html')) {
      yield p;
    }
  }
}

if (!existsSync(distDir)) {
  console.error(`inject-robots: dist/ not found — run the build first`);
  process.exit(1);
}

let stamped = 0;
let already = 0;
let fragments = 0;
const files = [...walkHtml(distDir)];
const pages = [];

for (const file of files) {
  const html = readFileSync(file, 'utf8');
  if (META_PRESENT.test(html)) {
    already++;
    pages.push(file);
    continue;
  }
  if (!/<\/head>/i.test(html)) {
    // Not a served page — a build fragment such as favicon-links.html.
    fragments++;
    continue;
  }
  writeFileSync(file, html.replace(/<\/head>/i, `    ${META}\n  </head>`));
  stamped++;
  pages.push(file);
}

copyFileSync(robotsSrc, robotsDest);

// Self-verification: exactly one robots meta per page, robots.txt installed.
let failures = 0;
for (const file of pages) {
  const count = (readFileSync(file, 'utf8').match(/<meta\s+name="robots"/gi) || []).length;
  if (count !== 1) {
    console.error(`inject-robots: ${file} carries ${count} robots meta tag(s), expected exactly 1`);
    failures++;
  }
}
if (!existsSync(robotsDest)) {
  console.error(`inject-robots: ${robotsDest} was not written`);
  failures++;
}
if (failures > 0) process.exit(1);

console.log(`inject-robots: ${files.length} HTML files — ${stamped} pages stamped, ${already} already carried the meta, ${fragments} fragment(s) skipped; robots.txt installed`);
