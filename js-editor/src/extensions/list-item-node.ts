import type { JSONContent, MarkdownParseResult } from '@tiptap/core';
import { ListItem } from '@tiptap/extension-list';

const parseBaseListItemMarkdown = ListItem.config.parseMarkdown;

function startsWithParagraph(node: JSONContent): boolean {
  return node.content?.[0]?.type === 'paragraph';
}

function repairListItem(node: JSONContent): JSONContent {
  if (node.type !== 'listItem' || startsWithParagraph(node)) return node;
  return {
    ...node,
    content: [{ type: 'paragraph' }, ...(node.content ?? [])],
  };
}

export function repairListItemMarkdownParseResult(
  result: MarkdownParseResult,
): MarkdownParseResult {
  if (Array.isArray(result)) return result.map(repairListItem);
  if ('type' in result) return repairListItem(result);
  return result;
}

export const EpdocListItem = ListItem.extend({
  parseMarkdown(token, helpers) {
    const parsed = parseBaseListItemMarkdown?.(token, helpers) ?? [];
    return repairListItemMarkdownParseResult(parsed);
  },
});
