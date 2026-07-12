import { Extension } from '@tiptap/core';
import type {
  JSONContent,
  MarkdownParseHelpers,
  MarkdownRendererHelpers,
  MarkdownToken,
} from '@tiptap/core';
import Link from '@tiptap/extension-link';
import { isSafeImageSrc } from './markdown-paste';

const WIKI_HREF_PREFIX = 'epistemos-doc:wiki/';
const CALLOUT_MARKER_RE = /^\[!(NOTE|TIP|WARNING|DANGER|INFO)\]\s*(.*)$/i;
const WIKILINK_RE = /^\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]/;

export const EpdocLink = Link.extend({
  renderMarkdown: (node, helpers) => {
    const href = stringAttr(node.attrs?.href);
    const title = stringAttr(node.attrs?.title);
    const text = helpers.renderChildren(node);
    const wikiTarget = wikiTargetFromHref(href);

    if (
      wikiTarget !== null
      && canRenderWikiPart(wikiTarget, false)
      && canRenderWikiPart(text, true)
    ) {
      return wikiTarget === text ? `[[${wikiTarget}]]` : `[[${wikiTarget}|${text}]]`;
    }

    const safeText = text.replace(/\n/g, ' ');
    return title
      ? `[${safeText}](${href} "${escapeQuotedTitle(title)}")`
      : `[${safeText}](${href})`;
  },
});

export const EpdocWikiLinkMarkdown = Extension.create({
  name: 'epdocWikiLinkMarkdown',
  priority: 110,
  markdownTokenName: 'wikilink',

  parseMarkdown: (token, helpers) => {
    const target = stringAttr(token.target).trim();
    if (!target) return [];

    const label = stringAttr(token.text).trim() || target;
    const tokens = token.tokens?.length
      ? token.tokens
      : helpers.tokenizeInline?.(label) ?? [{ type: 'text', text: label }];

    return helpers.applyMark('link', helpers.parseInline(tokens), {
      href: `${WIKI_HREF_PREFIX}${encodeURIComponent(target)}`,
      title: null,
    });
  },

  markdownTokenizer: {
    name: 'wikilink',
    level: 'inline',
    start: source => source.indexOf('[['),
    tokenize(source, _tokens, lexer) {
      const match = source.match(WIKILINK_RE);
      if (!match) return undefined;

      const target = match[1].trim();
      if (!target) return undefined;

      const label = (match[2]?.trim() || target);
      return {
        type: 'wikilink',
        raw: match[0],
        text: label,
        target,
        tokens: lexer.inlineTokens(label),
      };
    },
  },
});

export function parseEpdocChartMarkdown(
  token: MarkdownToken,
  helpers: MarkdownParseHelpers
): JSONContent | JSONContent[] {
  const language = stringAttr(token.lang).trim().toLowerCase();
  const source = stringAttr(token.text).trimEnd();
  if (language !== 'chart' && !(language === 'json' && isChartSpec(source))) {
    return [];
  }
  if (!isChartSpec(source)) return [];
  return helpers.createNode('epdocChart', undefined, textContent(source, helpers));
}

export function renderEpdocChartMarkdown(
  node: JSONContent,
  helpers: MarkdownRendererHelpers
): string {
  const source = renderNodeText(node, helpers).trimEnd();
  return ['```chart', source, '```'].join('\n');
}

export function parseLegacyDiagramMarkdown(
  token: MarkdownToken,
  helpers: MarkdownParseHelpers
): JSONContent | JSONContent[] {
  const language = stringAttr(token.lang).trim().toLowerCase();
  if (language !== 'mermaid') return [];

  const source = stringAttr(token.text).trimEnd();
  return helpers.createNode('mermaid', undefined, textContent(source, helpers));
}

export function renderLegacyDiagramMarkdown(
  node: JSONContent,
  helpers: MarkdownRendererHelpers
): string {
  const source = renderNodeText(node, helpers).trimEnd();
  return ['```mermaid', source, '```'].join('\n');
}

export function parseEpdocImageMarkdown(
  token: MarkdownToken,
  helpers: MarkdownParseHelpers
): JSONContent | JSONContent[] {
  const src = stringAttr(token.href).trim();
  if (!src || !isSafeImageSrc(src)) return [];
  return helpers.createNode('epdocImage', {
    src,
    alt: stringAttr(token.text).trim(),
    title: stringAttr(token.title).trim(),
  });
}

export function renderEpdocImageMarkdown(node: JSONContent): string {
  const attrs = node.attrs ?? {};
  const src = stringAttr(attrs.src).trim();
  if (!src || !isSafeImageSrc(src)) return '';

  const alt = sanitizeImageLabel(stringAttr(attrs.alt));
  const title = sanitizeImageTitle(stringAttr(attrs.title));
  return title ? `![${alt}](${src} "${title}")` : `![${alt}](${src})`;
}

export function parseCalloutMarkdown(
  token: MarkdownToken,
  helpers: MarkdownParseHelpers
): JSONContent | JSONContent[] {
  const payload = epdocCalloutPayload(token);
  if (!payload) return [];

  const content = payload.body
    ? [
        helpers.createNode(
          'paragraph',
          undefined,
          helpers.parseInline(
            helpers.tokenizeInline?.(payload.body) ?? [{ type: 'text', text: payload.body }]
          ),
        ),
      ]
    : [helpers.createNode('paragraph')];

  return helpers.createNode('callout', { kind: payload.kind }, content);
}

export function epdocCalloutPayload(
  token: MarkdownToken,
): { kind: string; body: string } | null {
  const text = stringAttr(token.text).replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
  const lineBreak = text.indexOf('\n');
  const firstLine = lineBreak >= 0 ? text.slice(0, lineBreak) : text;
  const marker = firstLine.trim().match(CALLOUT_MARKER_RE);
  if (!marker) return null;

  const kind = marker[1].toLowerCase();
  const title = marker[2]?.trim() ?? '';
  const rest = lineBreak >= 0 ? text.slice(lineBreak + 1).trim() : '';
  const body = [title, rest].filter(Boolean).join('\n').trim();
  return { kind, body };
}

export function renderCalloutMarkdown(
  node: JSONContent,
  helpers: MarkdownRendererHelpers
): string {
  const kind = (stringAttr(node.attrs?.kind).trim() || 'info').toUpperCase();
  const body = Array.isArray(node.content) ? helpers.renderChildren(node.content).trimEnd() : '';
  const lines = [`> [!${kind}]`];
  if (!body) return lines.join('\n');

  for (const line of body.split('\n')) {
    lines.push(line.trim().length > 0 ? `> ${line}` : '>');
  }
  return lines.join('\n');
}

function textContent(source: string, helpers: MarkdownParseHelpers): JSONContent[] {
  return source ? [helpers.createTextNode(source)] : [];
}

function renderNodeText(node: JSONContent, helpers: MarkdownRendererHelpers): string {
  return Array.isArray(node.content) ? helpers.renderChildren(node.content) : '';
}

function isChartSpec(source: string): boolean {
  try {
    const parsed = JSON.parse(source) as { type?: unknown };
    return parsed.type === 'scatter' || parsed.type === 'bar' || parsed.type === 'line';
  } catch {
    return false;
  }
}

function wikiTargetFromHref(href: string): string | null {
  if (!href.startsWith(WIKI_HREF_PREFIX)) return null;
  const encoded = href.slice(WIKI_HREF_PREFIX.length);
  if (!encoded) return null;
  try {
    return decodeURIComponent(encoded);
  } catch {
    return encoded;
  }
}

function canRenderWikiPart(value: string, allowPipe: boolean): boolean {
  if (!value.trim()) return false;
  if (/[\]\n\r]/.test(value)) return false;
  return allowPipe || !value.includes('|');
}

function sanitizeImageLabel(value: string): string {
  return value.replace(/[\]\n\r]/g, ' ').trim();
}

function sanitizeImageTitle(value: string): string {
  return value.replace(/["\n\r]/g, ' ').trim();
}

function escapeQuotedTitle(value: string): string {
  return value.replace(/"/g, '\\"').replace(/\n/g, ' ');
}

function stringAttr(value: unknown): string {
  return typeof value === 'string' ? value : '';
}
