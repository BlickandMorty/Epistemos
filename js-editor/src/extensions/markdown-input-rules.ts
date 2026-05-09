import { Extension, InputRule } from '@tiptap/core';
import type { InputRuleMatch } from '@tiptap/core';
import type { EditorState } from '@tiptap/pm/state';
import { TextSelection } from '@tiptap/pm/state';
import { replaceInputWithBlockAndTrailingParagraph } from './block-insert';
import { parseMarkdownPaste } from '../markdown/markdown-paste';

const TABLE_INPUT_RE = /((?:\|[^\n]+\|\n)\|(?:\s*:?-{3,}:?\s*\|)+(?:\n\|[^\n]+\|)*)\n?$/;
const MARKDOWN_LINK_INPUT_RE = /\[([^\]\n]+)\]\((https?:\/\/[^\s<>()]+|mailto:[^\s<>()]+|epistemos-doc:[^\s<>()]+)\)$/i;
const WIKILINK_INPUT_RE = /\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]$/;

interface InlineLinkReplacement {
  label: string;
  href: string;
}

export function epdocMarkdownInputRules(): Extension {
  return Extension.create({
    name: 'epdocMarkdownInputRules',
    addInputRules() {
      return [
        new InputRule({
          find: markdownLinkInputFinder,
          handler: ({ state, range, match }) => {
            const replacement = inlineLinkReplacement(match.data);
            if (!replacement) return null;
            return replaceInputWithInlineLink(state, range, replacement);
          },
        }),
        new InputRule({
          find: wikiLinkInputFinder,
          handler: ({ state, range, match }) => {
            const replacement = inlineLinkReplacement(match.data);
            if (!replacement) return null;
            return replaceInputWithInlineLink(state, range, replacement);
          },
        }),
        new InputRule({
          find: tableMarkdownInputFinder,
          handler: ({ state, range, match }) => {
            const markdown = typeof match.data?.markdown === 'string' ? match.data.markdown : match[1];
            const tableJSON = parseMarkdownPaste(markdown)?.find((node) => node.type === 'table');
            if (!tableJSON) return null;
            const tableNode = state.schema.nodeFromJSON(tableJSON);
            return replaceInputWithBlockAndTrailingParagraph(state, range, tableNode);
          },
        }),
      ];
    },
  });
}

export function tableMarkdownInputFinder(text: string): InputRuleMatch | null {
  const match = TABLE_INPUT_RE.exec(text);
  if (!match) return null;
  const markdown = match[1]?.trimEnd() ?? '';
  if (!markdown || !/\n\|(?:\s*:?-{3,}:?\s*\|)+/.test(markdown)) return null;
  return {
    index: match.index,
    text: match[0],
    data: { markdown },
  };
}

export function markdownLinkInputFinder(text: string): InputRuleMatch | null {
  const match = MARKDOWN_LINK_INPUT_RE.exec(text);
  if (!match) return null;
  if (match.index > 0 && text[match.index - 1] === '!') return null;

  const label = match[1]?.trim() ?? '';
  const href = match[2]?.trim() ?? '';
  if (!label || !isSafeInlineHref(href)) return null;

  return {
    index: match.index,
    text: match[0],
    data: { label, href },
  };
}

export function wikiLinkInputFinder(text: string): InputRuleMatch | null {
  const match = WIKILINK_INPUT_RE.exec(text);
  if (!match) return null;

  const target = match[1]?.trim() ?? '';
  const alias = match[2]?.trim();
  if (!target) return null;

  return {
    index: match.index,
    text: match[0],
    data: {
      label: alias || target,
      href: `epistemos-doc:wiki/${encodeURIComponent(target)}`,
    },
  };
}

export function replaceInputWithInlineLink(
  state: EditorState,
  range: { from: number; to: number },
  replacement: InlineLinkReplacement
): void | null {
  const linkMark = state.schema.marks.link;
  const label = replacement.label.trim();
  const href = replacement.href.trim();
  if (!linkMark || !label || !isSafeInlineHref(href)) return null;

  const tr = state.tr.replaceWith(range.from, range.to, state.schema.text(label, [
    linkMark.create({ href }),
  ]));
  const cursorPosition = Math.min(range.from + label.length, tr.doc.content.size);
  tr.setSelection(TextSelection.near(tr.doc.resolve(cursorPosition)));
  tr.scrollIntoView();
}

function inlineLinkReplacement(data: Record<string, unknown> | undefined): InlineLinkReplacement | null {
  const label = typeof data?.label === 'string' ? data.label.trim() : '';
  const href = typeof data?.href === 'string' ? data.href.trim() : '';
  if (!label || !isSafeInlineHref(href)) return null;
  return { label, href };
}

function isSafeInlineHref(href: string): boolean {
  return /^(https?:|epistemos-doc:|mailto:)/i.test(href)
    && !/[\u0000-\u001F<>"']/.test(href);
}
