import { escapeHtml, escapeAttr } from './escape';

export type XrefResolver = (uri: string, term: string) => string;
export type BibResolver = (refId: string, title: string) => string;
export type FigResolver = (figId: string) => string;
export type ConceptRefResolver = (conceptId: string, term: string) => string;

export interface RenderOptions {
  xrefResolver?: XrefResolver;
  bibResolver?: BibResolver;
  figResolver?: FigResolver;
  conceptRefResolver?: ConceptRefResolver;
}

function replaceBracketed(text: string, prefix: string, handler: (content: string, bold: boolean) => string): string {
  let result = '';
  let i = 0;
  const boldPrefix = '*' + prefix;
  while (i < text.length) {
    if (text.startsWith(boldPrefix + '[', i)) {
      i += boldPrefix.length + 1;
      let j = i;
      let d = 1;
      while (j < text.length && d > 0) {
        if (text[j] === '[') d++;
        else if (text[j] === ']') d--;
        j++;
      }
      const content = text.slice(i, j - 1);
      let end = j;
      if (end < text.length && text[end] === '*') end++;
      result += handler(content, true);
      i = end;
    } else if (text.startsWith(prefix + '[', i)) {
      i += prefix.length + 1;
      let j = i;
      let d = 1;
      while (j < text.length && d > 0) {
        if (text[j] === '[') d++;
        else if (text[j] === ']') d--;
        j++;
      }
      const content = text.slice(i, j - 1);
      result += handler(content, false);
      i = j;
    } else {
      result += text[i];
      i++;
    }
  }
  return result;
}

function mathPlaceholder(expr: string, format: string, bold: boolean): string {
  return `<span class="math-pending${bold ? ' math-bold' : ''}" data-expr="${escapeAttr(expr)}" data-format="${format}">${escapeAttr(expr)}</span>`;
}

function convertLists(text: string): string {
  let result = text.replace(/(?:^|\n)((?:[ \t]*\* [^\n]+)(?:\n[ \t]*\* [^\n]+)*)/g, (_, block) => {
    if (/^\*stem:\[/.test(block.trimStart())) return _;
    const items: string[] = [];
    const re = /[ \t]*\* ([^\n]+)/g;
    let m;
    while ((m = re.exec(block)) !== null) {
      items.push(m[1].trim());
    }
    if (!items.length) return _;
    const lis = items.map(item => `<li>${item}</li>`).join('');
    return `\n<ul class="concept-list">${lis}</ul>`;
  });

  result = result.replace(/(?:^|\n)((?:[ \t]*\d+[).][ \t]+[^\n]+)(?:\n[ \t]*\d+[).][ \t]+[^\n]+)*)/g, (_, block) => {
    const items: string[] = [];
    const re = /[ \t]*\d+[).][ \t]+([^\n]+)/g;
    let m;
    while ((m = re.exec(block)) !== null) {
      items.push(m[1].trim());
    }
    if (!items.length) return _;
    const lis = items.map(item => `<li>${item}</li>`).join('');
    return `\n<ol class="concept-list concept-list-ordered">${lis}</ol>`;
  });

  return result;
}

export function renderMath(text: string, xrefResolverOrOpts?: XrefResolver | RenderOptions): string {
  if (!text) return '';
  let result = text;

  const opts: RenderOptions = typeof xrefResolverOrOpts === 'function'
    ? { xrefResolver: xrefResolverOrOpts }
    : (xrefResolverOrOpts ?? {});

  // Math expressions: output placeholders for v-math directive to upgrade
  result = replaceBracketed(result, 'stem:', (expr, bold) => mathPlaceholder(expr, 'asciimath', bold));
  result = replaceBracketed(result, 'latexmath:', (expr, bold) => mathPlaceholder(expr, 'latex', bold));

  result = convertLists(result);
  result = result.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  result = result.replace(/~([^~]+)~/g, '<sub>$1</sub>');

  result = result.replace(/<<([^,>]+),([^>]+)>>/g, (_, refId, title) => {
    if (opts.bibResolver) {
      return opts.bibResolver(refId.trim(), title.trim());
    }
    return `<span class="bib-ref">${escapeHtml(title.trim())}</span>`;
  });

  result = result.replace(/<<(fig_[^>]+)>>/g, (_, figId) => {
    if (opts.figResolver) {
      return opts.figResolver(figId.trim());
    }
    return `<span class="fig-ref">${escapeHtml(figId.trim())}</span>`;
  });

  result = result.replace(/\{\{(urn:[^,}]+),([^,}]+)(?:,([^}]+))?\}\}/g, (_, uri, term, display) => {
    const t = (display || term).trim();
    if (opts.xrefResolver) {
      return opts.xrefResolver(uri, t);
    }
    return t;
  });

  result = result.replace(/\{(urn:[^,}]+),([^,}]+)(?:,([^}]+))?\}/g, (_, uri, term, display) => {
    const t = (display || term).trim();
    if (opts.xrefResolver) {
      return opts.xrefResolver(uri, t);
    }
    return t;
  });

  result = result.replace(/\{\{([^,}]+),\s*([^}]+)\}\}/g, (_, term, id) => {
    if (opts.conceptRefResolver) {
      return opts.conceptRefResolver(id.trim(), term.trim());
    }
    return term.trim();
  });

  return result;
}

export function cleanContent(text: string): string {
  if (!text) return '';
  let result = text
    .replace(/<[^>]+>/g, '')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/~([^~]+)~/g, '_$1')
    .replace(/\n[ \t]*\* /g, '; ')
    .replace(/<<([^,>]+),([^>]+)>>/g, '$2')
    .replace(/<<(fig_[^>]+)>>/g, '$1')
    .replace(/\{\{urn:[^,}]+,([^,}]+)(?:,[^}]+)?\}\}/g, '$1')
    .replace(/\{urn:[^,}]+,([^,}]+)(?:,[^}]+)?\}/g, '$1')
    .replace(/\{\{([^,}]+)(?:,\s*[^}]+)?\}\}/g, '$1')
    .replace(/(?:\*?)stem:\[([^\]]*)\]/g, '$1')
    .replace(/(?:\*?)latexmath:\[([^\]]*)\]/g, '$1');
  return result;
}
