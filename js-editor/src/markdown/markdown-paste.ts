export interface EpdocJSONContent {
  type: string;
  attrs?: Record<string, unknown>;
  content?: EpdocJSONContent[];
  text?: string;
  marks?: Array<{ type: string; attrs?: Record<string, unknown> }>;
}

const FENCE_RE = /^\s*```([A-Za-z0-9_-]+)?\s*$/;
const HEADING_RE = /^(#{1,6})\s+(.+)$/;
const TASK_RE = /^\s*[-*]\s+\[([ xX])\]\s+(.+)$/;
const BULLET_RE = /^\s*[-*+]\s+(.+)$/;
const ORDERED_RE = /^\s*\d+[.)]\s+(.+)$/;
const QUOTE_RE = /^\s*>\s?(.*)$/;
const HORIZONTAL_RE = /^\s*(?:---|\*\*\*|___)\s*$/;
const MARKDOWN_IMAGE_RE = /^!\[([^\]\n]*)\]\((\S+?)(?:\s+"([^"\n]+)")?\)$/;
const BARE_IMAGE_URL_RE = /^(https?:\/\/[^\s<>()]+\.(?:png|jpe?g|gif|webp|avif|svg)(?:[?#][^\s<>()]*)?)$/i;
const INLINE_TOKEN_RE = /(`[^`\n]+`|\[\[[^\]\n]+\]\]|\[[^\]\n]+\]\([^)]+\)|\*\*\*[^*\n]+?\*\*\*|___[^_\n]+?___|\*\*[^*\n]+?\*\*|__[^_\n]+?__|~~[^~\n]+?~~|==[^=\n]+?==|\*[^*\n]+?\*|_[^_\n]+?_|\$[^\d$\n][^$\n]*\$)/g;

export function parseMarkdownPaste(source: string): EpdocJSONContent[] | null {
  const normalized = source
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\u200B|\uFEFF/g, '')
    .trim();
  if (!normalized) return null;

  const lines = normalized.split('\n');
  const nodes: EpdocJSONContent[] = [];
  let sawMarkdownStructure = false;
  let index = 0;

  while (index < lines.length) {
    const line = lines[index] ?? '';
    if (line.trim().length === 0) {
      index += 1;
      continue;
    }

    const fence = line.match(FENCE_RE);
    if (fence) {
      const parsed = parseFence(lines, index, fence[1] ?? '');
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    const heading = line.match(HEADING_RE);
    if (heading) {
      nodes.push({
        type: 'heading',
        attrs: { level: heading[1].length },
        content: inlineContent(heading[2].trim()),
      });
      sawMarkdownStructure = true;
      index += 1;
      continue;
    }

    if (HORIZONTAL_RE.test(line)) {
      nodes.push({ type: 'horizontalRule' });
      sawMarkdownStructure = true;
      index += 1;
      continue;
    }

    const image = parseMarkdownImageLine(line);
    if (image) {
      nodes.push(image);
      sawMarkdownStructure = true;
      index += 1;
      continue;
    }

    if (isTableStart(lines, index)) {
      const parsed = parseTable(lines, index);
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    if (TASK_RE.test(line)) {
      const parsed = parseTaskList(lines, index);
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    if (BULLET_RE.test(line)) {
      const parsed = parseBulletList(lines, index);
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    if (ORDERED_RE.test(line)) {
      const parsed = parseOrderedList(lines, index);
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    if (QUOTE_RE.test(line)) {
      const parsed = parseQuoteOrCallout(lines, index);
      nodes.push(parsed.node);
      sawMarkdownStructure = true;
      index = parsed.nextIndex;
      continue;
    }

    const parsed = parseParagraph(lines, index);
    nodes.push(parsed.node);
    index = parsed.nextIndex;
  }

  if (!sawMarkdownStructure) return null;
  return ensureTrailingParagraph(nodes);
}

export function parseMarkdownImageLine(line: string): EpdocJSONContent | null {
  const trimmed = line.trim();
  const markdown = trimmed.match(MARKDOWN_IMAGE_RE);
  if (markdown) {
    const src = markdown[2].trim();
    if (!isSafeImageSrc(src)) return null;
    return {
      type: 'epdocImage',
      attrs: {
        src,
        alt: markdown[1]?.trim() ?? '',
        title: markdown[3]?.trim() ?? '',
      },
    };
  }

  const bare = trimmed.match(BARE_IMAGE_URL_RE);
  if (!bare) return null;
  const src = bare[1].trim();
  if (!isSafeImageSrc(src)) return null;
  return {
    type: 'epdocImage',
    attrs: {
      src,
      alt: imageAltFromSrc(src),
      title: '',
    },
  };
}

function parseFence(
  lines: string[],
  startIndex: number,
  language: string
): { node: EpdocJSONContent; nextIndex: number } {
  const body: string[] = [];
  let index = startIndex + 1;
  while (index < lines.length && !FENCE_RE.test(lines[index] ?? '')) {
    body.push(lines[index] ?? '');
    index += 1;
  }
  const closed = index < lines.length;
  const nextIndex = closed ? index + 1 : index;
  const text = body.join('\n').trimEnd();
  const normalizedLanguage = language.trim().toLowerCase();

  if (normalizedLanguage === 'mermaid') {
    return {
      node: { type: 'mermaid', content: textNodeContent(text) },
      nextIndex,
    };
  }

  if ((normalizedLanguage === 'json' || normalizedLanguage === 'chart') && isChartSpec(text)) {
    return {
      node: { type: 'epdocChart', content: textNodeContent(text) },
      nextIndex,
    };
  }

  return {
    node: {
      type: 'codeBlock',
      attrs: language ? { language } : {},
      content: textNodeContent(text),
    },
    nextIndex,
  };
}

function parseParagraph(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const paragraphLines: string[] = [];
  let index = startIndex;
  while (index < lines.length) {
    const line = lines[index] ?? '';
    if (line.trim().length === 0) break;
    if (index !== startIndex && startsMarkdownBlock(lines, index)) break;
    paragraphLines.push(line);
    index += 1;
  }
  return {
    node: paragraph(paragraphLines.join('\n').trim()),
    nextIndex: index,
  };
}

function parseTaskList(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const items: EpdocJSONContent[] = [];
  let index = startIndex;
  while (index < lines.length) {
    const match = (lines[index] ?? '').match(TASK_RE);
    if (!match) break;
    items.push({
      type: 'taskItem',
      attrs: { checked: match[1].toLowerCase() === 'x' },
      content: [paragraph(match[2].trim())],
    });
    index += 1;
  }
  return { node: { type: 'taskList', content: items }, nextIndex: index };
}

function parseBulletList(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const items: EpdocJSONContent[] = [];
  let index = startIndex;
  while (index < lines.length) {
    const match = (lines[index] ?? '').match(BULLET_RE);
    if (!match || TASK_RE.test(lines[index] ?? '')) break;
    items.push({ type: 'listItem', content: [paragraph(match[1].trim())] });
    index += 1;
  }
  return { node: { type: 'bulletList', content: items }, nextIndex: index };
}

function parseOrderedList(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const items: EpdocJSONContent[] = [];
  let index = startIndex;
  while (index < lines.length) {
    const match = (lines[index] ?? '').match(ORDERED_RE);
    if (!match) break;
    items.push({ type: 'listItem', content: [paragraph(match[1].trim())] });
    index += 1;
  }
  return { node: { type: 'orderedList', content: items }, nextIndex: index };
}

function parseQuoteOrCallout(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const quoteLines: string[] = [];
  let index = startIndex;
  while (index < lines.length) {
    const match = (lines[index] ?? '').match(QUOTE_RE);
    if (!match) break;
    quoteLines.push(match[1]);
    index += 1;
  }

  const first = quoteLines[0]?.trim() ?? '';
  const callout = first.match(/^\[!(NOTE|TIP|WARNING|DANGER|INFO)\]\s*(.*)$/i);
  if (callout) {
    const title = callout[2]?.trim();
    const body = [title, ...quoteLines.slice(1)].filter((line) => line && line.trim()).join('\n');
    return {
      node: {
        type: 'callout',
        attrs: { kind: callout[1].toLowerCase() },
        content: [paragraph(body || callout[1].toLowerCase())],
      },
      nextIndex: index,
    };
  }

  return {
    node: { type: 'blockquote', content: [paragraph(quoteLines.join('\n').trim())] },
    nextIndex: index,
  };
}

function parseTable(
  lines: string[],
  startIndex: number
): { node: EpdocJSONContent; nextIndex: number } {
  const rows: string[][] = [];
  let index = startIndex;
  rows.push(splitTableRow(lines[index] ?? ''));
  index += 2;
  while (index < lines.length && isPipeRow(lines[index] ?? '')) {
    rows.push(splitTableRow(lines[index] ?? ''));
    index += 1;
  }

  const content = rows.map((cells, rowIndex) => ({
    type: 'tableRow',
    content: cells.map((cell) => ({
      type: rowIndex === 0 ? 'tableHeader' : 'tableCell',
      content: [paragraph(cell.trim())],
    })),
  }));
  return { node: { type: 'table', content }, nextIndex: index };
}

function startsMarkdownBlock(lines: string[], index: number): boolean {
  const line = lines[index] ?? '';
  return FENCE_RE.test(line)
    || HEADING_RE.test(line)
    || HORIZONTAL_RE.test(line)
    || parseMarkdownImageLine(line) !== null
    || TASK_RE.test(line)
    || BULLET_RE.test(line)
    || ORDERED_RE.test(line)
    || QUOTE_RE.test(line)
    || isTableStart(lines, index);
}

function isTableStart(lines: string[], index: number): boolean {
  return isPipeRow(lines[index] ?? '') && isTableDivider(lines[index + 1] ?? '');
}

function isPipeRow(line: string): boolean {
  const trimmed = line.trim();
  return trimmed.includes('|') && splitTableRow(trimmed).length >= 2;
}

function isTableDivider(line: string): boolean {
  const cells = splitTableRow(line);
  return cells.length >= 2 && cells.every((cell) => /^:?-{3,}:?$/.test(cell.trim()));
}

function splitTableRow(line: string): string[] {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map((cell) => cell.trim());
}

function paragraph(text: string): EpdocJSONContent {
  const content = inlineContent(text);
  return content.length > 0 ? { type: 'paragraph', content } : { type: 'paragraph' };
}

function inlineContent(text: string): EpdocJSONContent[] {
  const nodes: EpdocJSONContent[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  INLINE_TOKEN_RE.lastIndex = 0;
  while ((match = INLINE_TOKEN_RE.exec(text)) !== null) {
    appendText(nodes, text.slice(lastIndex, match.index));
    const token = match[0];
    if (token.startsWith('`')) {
      appendText(nodes, token.slice(1, -1), [{ type: 'code' }]);
    } else if (token.startsWith('***') && token.endsWith('***')) {
      appendText(nodes, token.slice(3, -3), [{ type: 'bold' }, { type: 'italic' }]);
    } else if (token.startsWith('___') && token.endsWith('___')) {
      appendText(nodes, token.slice(3, -3), [{ type: 'bold' }, { type: 'italic' }]);
    } else if (token.startsWith('**') && token.endsWith('**')) {
      appendText(nodes, token.slice(2, -2), [{ type: 'bold' }]);
    } else if (token.startsWith('__') && token.endsWith('__')) {
      appendText(nodes, token.slice(2, -2), [{ type: 'bold' }]);
    } else if (token.startsWith('~~') && token.endsWith('~~')) {
      appendText(nodes, token.slice(2, -2), [{ type: 'strike' }]);
    } else if (token.startsWith('==') && token.endsWith('==')) {
      appendText(nodes, token.slice(2, -2), [{ type: 'highlight' }]);
    } else if (token.startsWith('*') && token.endsWith('*')) {
      appendText(nodes, token.slice(1, -1), [{ type: 'italic' }]);
    } else if (token.startsWith('_') && token.endsWith('_')) {
      appendText(nodes, token.slice(1, -1), [{ type: 'italic' }]);
    } else if (token.startsWith('$') && token.endsWith('$')) {
      nodes.push({ type: 'inlineMath', attrs: { latex: token.slice(1, -1) } });
    } else if (token.startsWith('[[')) {
      const wiki = token.match(/^\[\[([^\]|]+)(?:\|([^\]]+))?\]\]$/);
      const target = wiki?.[1]?.trim() ?? '';
      const label = wiki?.[2]?.trim() || target;
      if (target) {
        appendText(nodes, label, [{ type: 'link', attrs: { href: `epistemos-doc:wiki/${encodeURIComponent(target)}` } }]);
      } else {
        appendText(nodes, token);
      }
    } else {
      const link = token.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
      const href = link?.[2]?.trim() ?? '';
      if (link && isSafeHref(href)) {
        appendText(nodes, link[1], [{ type: 'link', attrs: { href } }]);
      } else {
        appendText(nodes, token);
      }
    }
    lastIndex = match.index + token.length;
  }
  appendText(nodes, text.slice(lastIndex));
  return nodes;
}

function appendText(
  nodes: EpdocJSONContent[],
  text: string,
  marks?: Array<{ type: string; attrs?: Record<string, unknown> }>
): void {
  if (!text) return;
  nodes.push(marks ? { type: 'text', text, marks } : { type: 'text', text });
}

function textNodeContent(text: string): EpdocJSONContent[] {
  return text ? [{ type: 'text', text }] : [];
}

function ensureTrailingParagraph(nodes: EpdocJSONContent[]): EpdocJSONContent[] {
  const last = nodes[nodes.length - 1];
  if (!last || last.type === 'paragraph') return nodes;
  return [...nodes, { type: 'paragraph' }];
}

function isChartSpec(text: string): boolean {
  try {
    const parsed = JSON.parse(text) as { type?: unknown };
    return parsed.type === 'scatter' || parsed.type === 'bar' || parsed.type === 'line';
  } catch {
    return false;
  }
}

function isSafeHref(href: string): boolean {
  return /^(https?:|epistemos-doc:|mailto:)/i.test(href);
}

export function isSafeImageSrc(src: string): boolean {
  return /^(https?:|epistemos-doc:|data:image\/)/i.test(src)
    && !/[\u0000-\u001F<>"']/.test(src);
}

function imageAltFromSrc(src: string): string {
  const withoutQuery = src.split(/[?#]/, 1)[0] ?? src;
  const lastPathSegment = withoutQuery.split('/').filter(Boolean).pop();
  if (!lastPathSegment) return 'Pasted image';
  try {
    return decodeURIComponent(lastPathSegment);
  } catch {
    return lastPathSegment;
  }
}
