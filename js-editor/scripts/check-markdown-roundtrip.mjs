import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Script, createContext } from 'node:vm';
import ts from 'typescript';

const require = createRequire(import.meta.url);
const scriptDir = dirname(fileURLToPath(import.meta.url));
const sourceRoot = resolve(scriptDir, '../src');
const moduleCache = new Map();

function loadTSModule(path) {
  const absolutePath = normalize(path);
  if (moduleCache.has(absolutePath)) return moduleCache.get(absolutePath).exports;

  const source = readFileSync(absolutePath, 'utf8');
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      strict: true,
      esModuleInterop: true,
    },
    fileName: absolutePath,
  }).outputText;

  const moduleShim = { exports: {} };
  moduleCache.set(absolutePath, moduleShim);
  const context = createContext({
    console,
    exports: moduleShim.exports,
    module: moduleShim,
    require: (specifier) => {
      if (specifier.startsWith('.')) {
        const resolvedPath = resolve(dirname(absolutePath), `${specifier}.ts`);
        return loadTSModule(resolvedPath);
      }
      return require(specifier);
    },
  });
  new Script(transpiled, { filename: absolutePath }).runInContext(context);
  return moduleShim.exports;
}

function tiptapModule(specifier, namedExport) {
  const module = require(specifier);
  return namedExport ? module[namedExport] : module.default ?? module;
}

const StarterKit = tiptapModule('@tiptap/starter-kit');
const Highlight = tiptapModule('@tiptap/extension-highlight');
const { Table } = require('@tiptap/extension-table');
const TableRow = tiptapModule('@tiptap/extension-table-row');
const TableCell = tiptapModule('@tiptap/extension-table-cell');
const TableHeader = tiptapModule('@tiptap/extension-table-header');
const TaskList = tiptapModule('@tiptap/extension-task-list');
const TaskItem = tiptapModule('@tiptap/extension-task-item');
const Mathematics = tiptapModule('@tiptap/extension-mathematics');
const { Footnotes, FootnoteReference, Footnote } = require('tiptap-footnotes');
const { MarkdownManager } = require('@tiptap/markdown');

const { EpdocCodeBlock } = loadTSModule(resolve(sourceRoot, 'extensions/code-block-node.ts'));
const { EpdocChartNode } = loadTSModule(resolve(sourceRoot, 'extensions/chart-node.ts'));
const { EpdocImageNode } = loadTSModule(resolve(sourceRoot, 'extensions/image-node.ts'));
const { LegacyDiagramNode } = loadTSModule(resolve(sourceRoot, 'extensions/legacy-diagram-node.ts'));
const { CalloutNode } = loadTSModule(resolve(sourceRoot, 'extensions/callout-node.ts'));
const { EpdocLink, EpdocWikiLinkMarkdown } = loadTSModule(
  resolve(sourceRoot, 'markdown/epdoc-markdown-nodes.ts'),
);

const manager = new MarkdownManager({
  indentation: { style: 'space', size: 2 },
  markedOptions: { breaks: false, gfm: true },
  extensions: [
    StarterKit.configure({ codeBlock: false, link: false }),
    EpdocLink.configure({ openOnClick: false, protocols: ['epistemos-doc'] }),
    Highlight,
    EpdocCodeBlock,
    Table.configure({ resizable: true }),
    TableRow,
    TableCell,
    TableHeader,
    TaskList,
    TaskItem.configure({ nested: true }),
    Mathematics,
    Footnotes,
    FootnoteReference,
    Footnote,
    EpdocChartNode,
    LegacyDiagramNode,
    EpdocImageNode,
    CalloutNode,
    EpdocWikiLinkMarkdown,
  ],
});

const markdown = `# Research Spine

Normal paragraph with [[Capability Sandwich|claim]] and [source](https://example.com).

\`\`\`swift
func verify() {
  print("structured markdown")
}
\`\`\`

\`\`\`mermaid
flowchart TD
  A --> B
\`\`\`

| Claim | Evidence |
|---|---|
| Local-first | Package assets |

- [ ] Verify parser
- [x] Keep schema stable

> [!NOTE] Canon
> Use real blocks.

\`\`\`chart
{
  "type": "scatter",
  "points": [{ "x": 0.8, "y": 0.9, "label": "Evidence" }]
}
\`\`\`

![Evidence screenshot](https://example.com/evidence.png "Figure 1")
`;

const parsed = manager.parse(markdown);
const parsedJSON = JSON.stringify(parsed);

assert.match(parsedJSON, /"type":"heading"/);
assert.match(parsedJSON, /"type":"mermaid"/);
assert.match(parsedJSON, /"type":"epdocChart"/);
assert.match(parsedJSON, /"type":"epdocImage"/);
assert.match(parsedJSON, /"type":"callout"/);
assert.match(parsedJSON, /epistemos-doc:wiki\/Capability%20Sandwich/);

const firstMarkdown = manager.serialize(parsed);
const secondMarkdown = manager.serialize(manager.parse(firstMarkdown));
assert.equal(secondMarkdown, firstMarkdown, 'Markdown parse/serialize must be a fixed point');
assert.match(firstMarkdown, /\[\[Capability Sandwich\|claim\]\]/);
assert.match(firstMarkdown, /```mermaid\nflowchart TD/);
assert.match(firstMarkdown, /```chart\n\{/);
assert.match(firstMarkdown, /> \[!NOTE\]/);
assert.match(firstMarkdown, /!\[Evidence screenshot\]\(https:\/\/example\.com\/evidence\.png "Figure 1"\)/);

const doc = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
      content: [
        {
          type: 'text',
          text: 'claim',
          marks: [{ type: 'link', attrs: { href: 'epistemos-doc:wiki/Capability%20Sandwich' } }],
        },
      ],
    },
    { type: 'callout', attrs: { kind: 'warning' }, content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Check source' }] }] },
    { type: 'mermaid', content: [{ type: 'text', text: 'flowchart LR\nA-->B' }] },
    { type: 'epdocChart', content: [{ type: 'text', text: '{"type":"bar","bars":[{"label":"A","value":1}]}' }] },
    { type: 'epdocImage', attrs: { src: 'epistemos-doc:///assets/figure.webp', alt: 'Figure', title: '' } },
  ],
};

const serializedDoc = manager.serialize(doc);
assert.match(serializedDoc, /\[\[Capability Sandwich\|claim\]\]/);
assert.match(serializedDoc, /> \[!WARNING\]/);
assert.match(serializedDoc, /```mermaid\nflowchart LR/);
assert.match(serializedDoc, /```chart\n\{"type":"bar"/);
assert.match(serializedDoc, /!\[Figure\]\(epistemos-doc:\/\/\/assets\/figure\.webp\)/);

const reparsedDoc = JSON.stringify(manager.parse(serializedDoc));
assert.match(reparsedDoc, /"type":"callout"/);
assert.match(reparsedDoc, /"type":"mermaid"/);
assert.match(reparsedDoc, /"type":"epdocChart"/);
assert.match(reparsedDoc, /"type":"epdocImage"/);

console.log('markdown roundtrip check passed');
