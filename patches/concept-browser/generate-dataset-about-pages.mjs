// Auto-generate dataset about pages from {localPath}/about.md
// Run after processPages, inserts into public/pages/
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { resolve, join } from 'path';
import yaml from 'js-yaml';

const ROOT = process.cwd();
const PUBLIC = join(ROOT, 'public');

// Minimal markdown-lite (matches concept-browser's rendering)
function stripFrontmatter(text) {
  const lines = text.split('\n');
  if (lines[0] !== '---') return text;
  let end = -1;
  for (let i = 1; i < lines.length; i++) { if (lines[i] === '---') { end = i; break; } }
  if (end < 0) return text;
  return lines.slice(end + 1).join('\n').trim();
}

function renderInline(text) {
  return text
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2">$1</a>');
}

function renderMd(text) {
  const lines = stripFrontmatter(text).split('\n');
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (/^#{1,4}\s/.test(line)) {
      const m = line.match(/^(#{1,4})\s+(.*)/);
      const level = m[1].length;
      blocks.push(`<h${level}>${renderInline(m[2])}</h${level}>`);
      i++; continue;
    }
    if (/^[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i])) { items.push(`<li>${renderInline(lines[i].replace(/^[-*]\s+/, ''))}</li>`); i++; }
      blocks.push(`<ul>${items.join('')}</ul>`); continue;
    }
    if (/^\d+\.\s/.test(line)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s/.test(lines[i])) { items.push(`<li>${renderInline(lines[i].replace(/^\d+\.\s+/, ''))}</li>`); i++; }
      blocks.push(`<ol>${items.join('')}</ol>`); continue;
    }
    if (/^>\s?/.test(line)) {
      const qLines = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) { qLines.push(lines[i].replace(/^>\s?/, '')); i++; }
      blocks.push(`<blockquote><p>${renderInline(qLines.join(' '))}</p></blockquote>`); continue;
    }
    if (line.trim().startsWith('```')) { i++; const cl = []; while (i < lines.length && !lines[i].trim().startsWith('```')) { cl.push(lines[i]); i++; } i++; blocks.push(`<pre><code>${cl.join('\n')}</code></pre>`); continue; }
    if (/^\|===/.test(line.trim())) { i++; const rows = []; while (i < lines.length && !/^\|===/.test(lines[i].trim())) { if (lines[i].includes('|') && !/^\|[-|]/.test(lines[i].trim())) { rows.push(lines[i]); } i++; } i++; if (rows.length) { const hCells = rows[0].split('|').filter(c => c.trim()); const ths = hCells.map(c => `<th>${renderInline(c.trim())}</th>`).join(''); const trs = rows.slice(1).map(r => { const cells = r.split('|').filter(c => c.trim()); return `<tr>${cells.map(c => `<td>${renderInline(c.trim())}</td>`).join('')}</tr>`; }).join(''); blocks.push(`<table><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`); } continue; }
    if (!line.trim()) { i++; continue; }
    const pl = [];
    while (i < lines.length && lines[i].trim() && !/^#{1,4}\s/.test(lines[i]) && !/^[-*]\s+/.test(lines[i]) && !/^\d+\.\s/.test(lines[i]) && !/^>\s?/.test(lines[i]) && !lines[i].trimStart().startsWith('```')) { pl.push(lines[i]); i++; }
    if (pl.length) blocks.push(`<p>${renderInline(pl.join(' '))}</p>`);
  }
  return blocks.join('\n');
}

const configPath = resolve(ROOT, 'site-config.yml');
if (!existsSync(configPath)) { console.log('No site-config.yml, skipping dataset about pages'); process.exit(0); }

const config = yaml.load(readFileSync(configPath, 'utf8'));
const pagesDir = join(PUBLIC, 'pages');
mkdirSync(pagesDir, { recursive: true });

const uiLanguages = config.uiLanguages?.map(l => l.code) || [];

for (const ds of config.datasets || []) {
  if (!ds.localPath) continue;
  const aboutSrc = resolve(ROOT, ds.localPath, 'about.md');
  if (!existsSync(aboutSrc)) continue;

  const raw = readFileSync(aboutSrc, 'utf8');
  const html = renderMd(raw);
  const route = `${ds.id}-about`;
  const title = `About`;

  const outPath = join(pagesDir, `${route}.json`);
  const outData = { title, html };
  mkdirSync(pagesDir, { recursive: true });
  writeFileSync(outPath, JSON.stringify(outData, null, 2));
  console.log(`  Auto-generated dataset about page: ${route}`);

  // Check for translations: about-{lang}.md
  const langs = uiLanguages.filter(l => l !== 'eng');
  const dsTranslations = ds.translations || {};
  for (const lang of langs) {
    const suffix = `about-${lang}.md`;
    const trAboutSrc = resolve(ROOT, ds.localPath, suffix);
    if (!existsSync(trAboutSrc)) continue;
    const trRaw = readFileSync(trAboutSrc, 'utf8');
    const trHtml = renderMd(trRaw);
    const trTitle = dsTranslations[lang]?.title ? `About ${dsTranslations[lang].title}` : title;
    const trOutPath = join(pagesDir, `${route}.${lang}.json`);
    writeFileSync(trOutPath, JSON.stringify({ title: trTitle, html: trHtml }, null, 2));
    console.log(`  Auto-generated dataset about page: ${route}.${lang}`);
  }
}
