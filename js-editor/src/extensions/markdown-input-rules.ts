import { Extension, InputRule } from '@tiptap/core';
import { replaceInputWithBlockAndTrailingParagraph } from './block-insert';
import { parseMarkdownPaste } from '../markdown/markdown-paste';

const TABLE_INPUT_RE = /(\|[^\n]+\|\n\|(?:\s*:?-{3,}:?\s*\|)+)\n$/;

export function epdocMarkdownInputRules(): Extension {
  return Extension.create({
    name: 'epdocMarkdownInputRules',
    addInputRules() {
      return [
        new InputRule({
          find: TABLE_INPUT_RE,
          handler: ({ state, range, match }) => {
            const tableJSON = parseMarkdownPaste(match[1])?.find((node) => node.type === 'table');
            if (!tableJSON) return null;
            const tableNode = state.schema.nodeFromJSON(tableJSON);
            return replaceInputWithBlockAndTrailingParagraph(state, range, tableNode);
          },
        }),
      ];
    },
  });
}
