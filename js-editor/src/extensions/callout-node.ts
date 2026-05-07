import { Node, mergeAttributes } from '@tiptap/core';

export const CalloutNode = Node.create({
  name: 'callout',
  group: 'block',
  content: 'block+',
  defining: true,

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
