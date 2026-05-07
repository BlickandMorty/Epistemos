import { InputRule, Node, mergeAttributes } from '@tiptap/core';
import { replaceInputWithBlockAndTrailingParagraph } from './block-insert';
import { parseMarkdownImageLine } from '../markdown/markdown-paste';

const IMAGE_INPUT_RE = /(!\[[^\]\n]*\]\(\S+(?:\s+"[^"\n]+")?\)|https?:\/\/[^\s<>()]+\.(?:png|jpe?g|gif|webp|avif|svg)(?:[?#][^\s<>()]*)?)$/i;

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    epdocImage: {
      insertEpdocImage: (options: { src: string; alt?: string; title?: string }) => ReturnType;
    };
  }
}

export const EpdocImageNode = Node.create({
  name: 'epdocImage',
  group: 'block',
  atom: true,
  draggable: true,

  addAttributes() {
    return {
      src: { default: null },
      alt: { default: null },
      title: { default: null },
    };
  },

  parseHTML() {
    return [{ tag: 'img[src]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['img', mergeAttributes(HTMLAttributes, { 'data-epdoc-image': '' })];
  },

  addCommands() {
    return {
      insertEpdocImage:
        options =>
        ({ commands }) => {
          const src = options.src.trim();
          if (!src) return false;
          return commands.insertContent({
            type: this.name,
            attrs: {
              src,
              alt: options.alt ?? '',
              title: options.title ?? '',
            },
          });
        },
    };
  },

  addInputRules() {
    return [
      new InputRule({
        find: IMAGE_INPUT_RE,
        handler: ({ state, range, match }) => {
          const imageJSON = parseMarkdownImageLine(match[0]);
          if (!imageJSON) return null;
          const imageNode = state.schema.nodeFromJSON(imageJSON);
          return replaceInputWithBlockAndTrailingParagraph(state, range, imageNode);
        },
      }),
    ];
  },
});
