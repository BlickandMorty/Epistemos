import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Script, createContext } from 'node:vm';
import ts from 'typescript';

const sourcePath = new URL('../src/graph/document-graph.ts', import.meta.url);
const source = readFileSync(sourcePath, 'utf8');
const transpiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
    strict: true,
  },
  fileName: 'document-graph.ts',
}).outputText;

const moduleShim = { exports: {} };
const context = createContext({
  exports: moduleShim.exports,
  module: moduleShim,
});
new Script(transpiled, { filename: 'document-graph.js' }).runInContext(context);

const { buildMermaidGraphFromDocument } = context.module.exports;
assert.equal(typeof buildMermaidGraphFromDocument, 'function');

const richDocument = {
  type: 'doc',
  content: [
    {
      type: 'heading',
      attrs: { level: 1 },
      content: [{ type: 'text', text: 'Epdoc Research Spine' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'The central claim is that package-local assets make documents durable.' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'Evidence comes from saved images, source citations, and measured replay results.' }],
    },
    {
      type: 'blockquote',
      content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Why does the graph stay shallow?' }] }],
    },
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Method: compare toolbar, paste, and drop paths.' }] }],
        },
      ],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'Connect this to [[Halo Memory]] and [[DAG Replay]].' }],
    },
    {
      type: 'codeBlock',
      content: [{ type: 'text', text: 'func verify() { print("graph") }' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '```swift' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'let fencedCode = "must not break mermaid"' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '```' }],
    },
    { type: 'mermaid', content: [{ type: 'text', text: 'flowchart TD\nA-->B' }] },
    { type: 'epdocImage', attrs: { alt: 'Microscope evidence screenshot' } },
  ],
};

const diagram = buildMermaidGraphFromDocument(richDocument);
const nodeLines = diagram.split('\n').filter((line) => /^\s*N\d+/.test(line));

assert.match(diagram, /^flowchart TD/);
assert.match(diagram, /Research document/);
assert.match(diagram, /Epdoc Research Spine/);
assert.match(diagram, /Evidence: Evidence comes from saved images/);
assert.match(diagram, /Question: Why does the graph stay shallow/);
assert.match(diagram, /Method: Method: compare toolbar/);
assert.match(diagram, /\(\(Halo Memory\)\)/);
assert.match(diagram, /\(\(DAG Replay\)\)/);
assert.match(diagram, /Code: func verify/);
assert.match(diagram, /let fencedCode =/);
assert.doesNotMatch(diagram, /```/);
assert.match(diagram, /Diagram block/);
assert.match(diagram, /Microscope evidence screenshot/);
assert.ok(nodeLines.length >= 10, `expected a rich graph, got ${nodeLines.length} node lines:\n${diagram}`);
assert.doesNotMatch(diagram, /Idea/);
assert.doesNotMatch(diagram, /Evidence\]\s*-->/);

const rawMarkdownDocument = {
  type: 'doc',
  content: [
    {
      type: 'heading',
      attrs: { level: 1 },
      content: [{ type: 'text', text: 'Runtime Smoke' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '| Surface | Status |' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '|---|---|' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '| Epdoc graph | should not break Mermaid |' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '![Tiny image](https://example.com/image.png)' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '```swift' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'func verify() { print("ok") }' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '```' }],
    },
  ],
};

const rawDiagram = buildMermaidGraphFromDocument(rawMarkdownDocument);
assert.match(rawDiagram, /Surface \/ Status/);
assert.match(rawDiagram, /Epdoc graph \/ should not break Mermaid/);
assert.match(rawDiagram, /Image evidence: Tiny image|Tiny image/);
assert.doesNotMatch(rawDiagram, /\|---\|---\|/);
assert.doesNotMatch(rawDiagram, /!\[Tiny image\]/);
assert.doesNotMatch(rawDiagram, /```/);
assert.doesNotMatch(rawDiagram, /classDef .*;$/m);

const emptyDiagram = buildMermaidGraphFromDocument({ type: 'doc', content: [] });
assert.match(emptyDiagram, /Add headings, claims, evidence, or links/);

console.log('document graph builder check passed');
