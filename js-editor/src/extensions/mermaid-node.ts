// W7.9 — Mermaid Tiptap Node.
//
// Renders Mermaid blocks as live research diagrams. The renderer stays on
// the canonical Tiptap/WKWebView substrate, but borrows the right class of
// editor behavior from modern markdown editors: cached SVG rendering,
// strict-mode Mermaid config, sanitized SVG output, theme-aware palettes,
// and a diagram-first presentation with source available on demand.

import { Node, mergeAttributes } from '@tiptap/core';

declare global {
  interface Window {
    mermaid?: {
      render(id: string, diagram: string): Promise<{ svg: string }>;
      initialize(opts: {
        startOnLoad?: boolean;
        securityLevel?: string;
        theme?: string;
        themeVariables?: Record<string, string>;
        fontFamily?: string;
      }): void;
    };
  }
}

type MermaidTheme = 'light' | 'dark';

let mermaidPromise: Promise<typeof window.mermaid> | null = null;
const svgCache = new Map<string, string>();

const researchThemeVariables: Record<MermaidTheme, Record<string, string>> = {
  light: {
    background: 'transparent',
    mainBkg: '#f8fafc',
    secondBkg: '#eef6ff',
    tertiaryColor: '#fff7ed',
    primaryColor: '#f8fafc',
    primaryBorderColor: '#44617f',
    primaryTextColor: '#172033',
    secondaryColor: '#eef6ff',
    secondaryBorderColor: '#5277a0',
    secondaryTextColor: '#172033',
    tertiaryBorderColor: '#b7791f',
    tertiaryTextColor: '#172033',
    lineColor: '#5277a0',
    textColor: '#172033',
    edgeLabelBackground: '#ffffff',
    clusterBkg: '#f7fbff',
    clusterBorder: '#adc6e6',
    noteBkgColor: '#fff7ed',
    noteBorderColor: '#d69e2e',
    noteTextColor: '#172033',
    titleColor: '#172033',
  },
  dark: {
    background: 'transparent',
    mainBkg: '#121826',
    secondBkg: '#132235',
    tertiaryColor: '#2a1f16',
    primaryColor: '#121826',
    primaryBorderColor: '#8bb9e8',
    primaryTextColor: '#f3f7ff',
    secondaryColor: '#132235',
    secondaryBorderColor: '#9ec8f5',
    secondaryTextColor: '#f3f7ff',
    tertiaryBorderColor: '#e7b15c',
    tertiaryTextColor: '#fff4df',
    lineColor: '#9ec8f5',
    textColor: '#f3f7ff',
    edgeLabelBackground: '#101624',
    clusterBkg: '#101624',
    clusterBorder: '#385c83',
    noteBkgColor: '#241d13',
    noteBorderColor: '#e7b15c',
    noteTextColor: '#fff4df',
    titleColor: '#f3f7ff',
  },
};

function loadMermaid(): Promise<typeof window.mermaid> {
  if (window.mermaid) return Promise.resolve(window.mermaid);
  if (!mermaidPromise) {
    mermaidPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/vendor/mermaid/mermaid.min.js';
      script.async = true;
      script.onload = () => resolve(window.mermaid);
      script.onerror = () => reject(new Error('mermaid bundle failed to load'));
      document.head.appendChild(script);
    });
  }
  return mermaidPromise;
}

function currentMermaidTheme(): MermaidTheme {
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function cacheKey(source: string, theme: MermaidTheme): string {
  let hash = 0;
  const input = `${theme}|${source}`;
  for (let index = 0; index < input.length; index += 1) {
    hash = ((hash << 5) - hash + input.charCodeAt(index)) | 0;
  }
  return hash.toString(36);
}

function sanitizeMermaidSvg(svg: string): string {
  return svg
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/\son\w+\s*=\s*"[^"]*"/gi, '')
    .replace(/\son\w+\s*=\s*'[^']*'/gi, '');
}

async function renderMermaidSvg(diagram: string, id: string, theme: MermaidTheme): Promise<string> {
  const key = cacheKey(diagram, theme);
  const cached = svgCache.get(key);
  if (cached) return cached;

  const mermaid = await loadMermaid();
  if (!mermaid) throw new Error('mermaid bundle did not initialize');
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'strict',
    theme: 'base',
    themeVariables: researchThemeVariables[theme],
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", ui-sans-serif, sans-serif',
  });
  const result = await mermaid.render(id, diagram.trim());
  const sanitized = sanitizeMermaidSvg(result.svg);
  svgCache.set(key, sanitized);
  return sanitized;
}

export const MermaidNode = Node.create({
  name: 'mermaid',
  group: 'block',
  content: 'text*',
  marks: '',
  defining: true,
  isolating: true,
  selectable: true,
  draggable: true,
  code: true,

  addAttributes() {
    return {
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
      dom.contentEditable = 'false';
      Object.entries(HTMLAttributes).forEach(([key, value]) => {
        if (typeof value === 'string') dom.setAttribute(key, value);
      });

      const header = document.createElement('div');
      header.classList.add('epdoc-mermaid-header');
      const title = document.createElement('span');
      title.classList.add('epdoc-mermaid-title');
      title.textContent = 'Research diagram';
      const syntax = document.createElement('span');
      syntax.classList.add('epdoc-mermaid-syntax');
      syntax.textContent = firstLineLabel(node.textContent);
      header.append(title, syntax);
      dom.appendChild(header);

      const preview = document.createElement('div');
      preview.classList.add('epdoc-mermaid-preview');
      preview.innerHTML = '<div class="epdoc-mermaid-loading">Rendering diagram...</div>';
      dom.appendChild(preview);

      const sourceDisclosure = document.createElement('details');
      sourceDisclosure.classList.add('epdoc-mermaid-source-wrap');
      const summary = document.createElement('summary');
      summary.textContent = 'Mermaid source';
      const source = document.createElement('pre');
      source.contentEditable = 'false';
      source.classList.add('epdoc-mermaid-source');
      source.textContent = node.textContent;
      sourceDisclosure.append(summary, source);
      dom.appendChild(sourceDisclosure);

      let renderToken = 0;
      const render = (diagram: string) => {
        const myToken = ++renderToken;
        const theme = currentMermaidTheme();
        preview.innerHTML = '<div class="epdoc-mermaid-loading">Rendering diagram...</div>';
        renderMermaidSvg(diagram, `epdoc-mermaid-${myToken}`, theme)
          .then((svg) => {
            if (myToken !== renderToken) return;
            preview.innerHTML = svg;
            const renderedSvg = preview.querySelector('svg');
            if (renderedSvg) {
              renderedSvg.setAttribute('role', 'img');
              renderedSvg.setAttribute('aria-label', `Mermaid research diagram: ${firstLineLabel(diagram)}`);
            }
          })
          .catch((error) => {
            if (myToken !== renderToken) return;
            preview.innerHTML = `<div class="epdoc-mermaid-error">${escapeHtml(String(error))}</div>`;
          });
      };

      render(node.textContent);

      return {
        dom,
        update(updatedNode) {
          if (updatedNode.type !== node.type) return false;
          source.textContent = updatedNode.textContent;
          syntax.textContent = firstLineLabel(updatedNode.textContent);
          render(updatedNode.textContent);
          return true;
        },
        destroy() {
          renderToken += 1;
        },
      };
    };
  },
});

function firstLineLabel(source: string): string {
  const first = source.trim().split(/\r?\n/, 1)[0]?.trim();
  return first && first.length <= 44 ? first : 'mermaid';
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
