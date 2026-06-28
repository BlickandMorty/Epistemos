import { Node, mergeAttributes } from '@tiptap/core';
import {
  parseCalloutMarkdown,
  renderCalloutMarkdown,
} from '../markdown/epdoc-markdown-nodes';

export const CalloutNode = Node.create({
  name: 'callout',
  priority: 110,
  group: 'block',
  content: 'block+',
  defining: true,
  markdownTokenName: 'blockquote',
  parseMarkdown: parseCalloutMarkdown,
  renderMarkdown: renderCalloutMarkdown,

  addAttributes() {
    return {
      kind: {
        default: 'info',
        parseHTML: element => element.getAttribute('data-callout') ?? 'info',
        renderHTML: attributes => ({ 'data-callout': attributes.kind ?? 'info' }),
      },
    };
  },

  parseHTML() {
    return [{ tag: '[data-callout]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', mergeAttributes(HTMLAttributes), 0];
  },
});
