import type { MarkdownParseResult } from '@tiptap/core';
import { Blockquote } from '@tiptap/extension-blockquote';
import { epdocCalloutPayload } from '../markdown/epdoc-markdown-nodes';

const parseBaseBlockquoteMarkdown = Blockquote.config.parseMarkdown;

export const EpdocBlockquote = Blockquote.extend({
  priority: 120,

  parseMarkdown(token, helpers): MarkdownParseResult {
    if (epdocCalloutPayload(token) !== null) return [];
    return parseBaseBlockquoteMarkdown?.(token, helpers) ?? [];
  },
});
