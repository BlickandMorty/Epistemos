// W7.9 — Mermaid Tiptap Node.
//
// Renders ```mermaid fenced blocks as live diagrams. Mermaid is loaded
// from the vendored `vendor/mermaid/mermaid.min.js` bundle (the
// CopyPlugin in webpack.config.js stages it from node_modules at build
// time) so we don't trigger dynamic import chunks (WKWebView's CSP
// refuses by default).
//
// Storage: a single text-content node holding the diagram source. The
// ProseMirrorMarkdownProjector (Swift side, W7.7) emits the canonical
// ```mermaid fence so projections/shadow.md round-trips through any
// markdown reader.

import { Node, mergeAttributes } from '@tiptap/core';

declare global {
  interface Window {
    mermaid?: {
      render(id: string, diagram: string): Promise<{ svg: string }>;
      initialize(opts: { startOnLoad?: boolean; theme?: string }): void;
    };
  }
}

let mermaidPromise: Promise<typeof window.mermaid> | null = null;

function loadMermaid(): Promise<typeof window.mermaid> {
  if (window.mermaid) return Promise.resolve(window.mermaid);
  if (!mermaidPromise) {
    mermaidPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/vendor/mermaid/mermaid.min.js';
      script.async = true;
      script.onload = () => {
        window.mermaid?.initialize({ startOnLoad: false, theme: 'default' });
        resolve(window.mermaid);
      };
      script.onerror = () => reject(new Error('mermaid bundle failed to load'));
      document.head.appendChild(script);
    });
  }
  return mermaidPromise;
}

export const MermaidNode = Node.create({
  name: 'mermaid',
  group: 'block',
  content: 'text*',
  marks: '',
  defining: true,
  isolating: true,
  code: true,                 // treat content as raw text (no marks parsed)

  addAttributes() {
    return {
      // Optional render-pass cache key; updated when the diagram source
      // changes so the SVG re-renders.
      cacheKey: { default: '' },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-mermaid]', preserveWhitespace: 'full' }];
  },

  renderHTML({ HTMLAttributes, node }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, { 'data-mermaid': '' }),
      node.textContent,
    ];
  },

  addNodeView() {
    return ({ node, HTMLAttributes }) => {
      const dom = document.createElement('div');
      dom.dataset.mermaid = '';
      dom.classList.add('epdoc-mermaid');
      Object.entries(HTMLAttributes).forEach(([k, v]) => {
        if (typeof v === 'string') dom.setAttribute(k, v);
      });

      const source = document.createElement('pre');
      source.contentEditable = 'true';
      source.classList.add('epdoc-mermaid-source');
      source.textContent = node.textContent;
      dom.appendChild(source);

      const preview = document.createElement('div');
      preview.classList.add('epdoc-mermaid-preview');
      dom.appendChild(preview);

      let renderToken = 0;
      const render = (diagram: string) => {
        const myToken = ++renderToken;
        loadMermaid().then((mermaid) => {
          if (!mermaid || myToken !== renderToken) return;
          const id = `epdoc-mermaid-${myToken}`;
          mermaid.render(id, diagram).then(({ svg }) => {
            if (myToken !== renderToken) return;
            preview.innerHTML = svg;
          }).catch((error) => {
            if (myToken !== renderToken) return;
            preview.innerHTML = `<div class="epdoc-mermaid-error">${escapeHtml(String(error))}</div>`;
          });
        }).catch((error) => {
          preview.innerHTML = `<div class="epdoc-mermaid-error">${escapeHtml(String(error))}</div>`;
        });
      };

      render(node.textContent);

      return {
        dom,
        contentDOM: source,
        update(updatedNode) {
          if (updatedNode.type !== node.type) return false;
          render(updatedNode.textContent);
          return true;
        },
        destroy() {
          renderToken++;          // invalidate any in-flight render
        },
      };
    };
  },
});

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
