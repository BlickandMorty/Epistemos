import { Node, mergeAttributes } from '@tiptap/core';

// Compatibility-only schema node for old Epdoc files that already contain
// diagram blocks. New visual work routes to the native HTML Workspace.
export const LegacyDiagramNode = Node.create({
  name: 'mermaid',
  group: 'block',
  content: 'text*',
  marks: '',
  defining: true,
  isolating: true,
  selectable: true,
  draggable: false,
  code: true,

  parseHTML() {
    return [
      { tag: 'pre[data-legacy-diagram]', preserveWhitespace: 'full' },
      { tag: 'div[data-mermaid]', preserveWhitespace: 'full' },
    ];
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'pre',
      mergeAttributes(HTMLAttributes, { 'data-legacy-diagram': '', class: 'epdoc-legacy-diagram' }),
      ['code', 0],
    ];
  },

  addNodeView() {
    return ({ node, HTMLAttributes }) => {
      const dom = document.createElement('pre');
      dom.dataset.legacyDiagram = '';
      dom.classList.add('epdoc-legacy-diagram');
      dom.contentEditable = 'false';
      Object.entries(HTMLAttributes).forEach(([key, value]) => {
        if (typeof value === 'string') dom.setAttribute(key, value);
      });

      const code = document.createElement('code');
      code.textContent = node.textContent;
      dom.appendChild(code);

      return {
        dom,
        update(updatedNode) {
          if (updatedNode.type !== node.type) return false;
          code.textContent = updatedNode.textContent;
          return true;
        },
      };
    };
  },
});
