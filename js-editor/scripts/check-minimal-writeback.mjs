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
        return loadTSModule(resolve(dirname(absolutePath), `${specifier}.ts`));
      }
      return require(specifier);
    },
    TextEncoder,
  });
  new Script(transpiled, { filename: absolutePath }).runInContext(context);
  return moduleShim.exports;
}

const { Schema } = require('prosemirror-model');
const { EditorState } = require('prosemirror-state');
const {
  indexMarkdownBlocks,
  minimalWriteback,
  seedChangeSet,
} = loadTSModule(resolve(sourceRoot, 'markdown/minimal-diff-writeback.ts'));
const {
  MarkdownWritebackTracker,
} = loadTSModule(resolve(sourceRoot, 'markdown/writeback-tracker.ts'));

const schema = new Schema({
  nodes: {
    doc: { content: 'block+' },
    paragraph: {
      content: 'text*',
      group: 'block',
      toDOM: () => ['p', 0],
      parseDOM: [{ tag: 'p' }],
    },
    heading: {
      attrs: { level: { default: 1 } },
      content: 'text*',
      group: 'block',
      defining: true,
      toDOM: node => [`h${node.attrs.level}`, 0],
      parseDOM: [{ tag: 'h1', attrs: { level: 1 } }],
    },
    text: { group: 'inline' },
  },
  marks: {},
});

assert.equal(
  JSON.stringify(indexMarkdownBlocks('---\ntitle: Keep\n---\n\n# A\n\nBravo\n\nCharlie\n').map(block => block.markdown)),
  JSON.stringify(['# A', 'Bravo', 'Charlie']),
);

const simple = runParagraphEdit({
  oldMarkdown: 'Alpha\n\nBravo\n\nCharlie\n',
  paragraphs: ['Alpha', 'Bravo', 'Charlie'],
  editIndex: 1,
  replacement: 'Bravo updated',
});
assert.equal(simple.nextMarkdown, 'Alpha\n\nBravo updated\n\nCharlie\n');
assert.equal(simple.region.blockIndexFrom, 1);
assert.equal(simple.region.blockIndexTo, 1);
assert.equal(simple.region.blockMarkdown, 'Bravo updated');
assert.equal(simple.region.from, Buffer.byteLength('Alpha\n\n'));
assert.equal(simple.region.to, Buffer.byteLength('Alpha\n\nBravo'));
assert.ok(simple.region.to - simple.region.from < Buffer.byteLength(simple.nextMarkdown) / 2);

const frontmatter = runParagraphEdit({
  oldMarkdown: '---\ntitle: "[[Do not rewrite]]"\ntags: [a_b]\n---\n\nAlpha\n\nBravo\n\nCharlie\n',
  paragraphs: ['Alpha', 'Bravo', 'Charlie'],
  editIndex: 1,
  replacement: 'Bravo updated',
});
assert.equal(
  frontmatter.nextMarkdown,
  '---\ntitle: "[[Do not rewrite]]"\ntags: [a_b]\n---\n\nAlpha\n\nBravo updated\n\nCharlie\n',
);
assert.equal(frontmatter.nextMarkdown.startsWith('---\ntitle: "[[Do not rewrite]]"\ntags: [a_b]\n---\n'), true);

const unicode = runParagraphEdit({
  oldMarkdown: 'Alpha\n\nBravé\n\nCharlie\n',
  paragraphs: ['Alpha', 'Bravé', 'Charlie'],
  editIndex: 1,
  replacement: 'Bravé updated',
});
assert.equal(unicode.nextMarkdown, 'Alpha\n\nBravé updated\n\nCharlie\n');
assert.equal(unicode.region.from, Buffer.byteLength('Alpha\n\n'));
assert.equal(unicode.region.to, Buffer.byteLength('Alpha\n\nBravé'));
assert.notEqual(unicode.region.byteTo, unicode.region.codeUnitTo);

const crlf = runParagraphEdit({
  oldMarkdown: 'Alpha\r\n\r\nBravo\r\n\r\nCharlie\r\n',
  paragraphs: ['Alpha', 'Bravo', 'Charlie'],
  editIndex: 1,
  replacement: 'Bravo\nwrapped',
});
assert.equal(crlf.nextMarkdown, 'Alpha\r\n\r\nBravo\r\nwrapped\r\n\r\nCharlie\r\n');

const largeParagraphs = Array.from({ length: 1280 }, (_, index) => (
  `Paragraph ${index} ${'x'.repeat(4096)}`
));
const largeOldMarkdown = `${largeParagraphs.join('\n\n')}\n`;
assert.ok(Buffer.byteLength(largeOldMarkdown) > 5 * 1024 * 1024, 'large fixture must be multi-MB');
const large = runParagraphEdit({
  oldMarkdown: largeOldMarkdown,
  paragraphs: largeParagraphs,
  editIndex: 777,
  replacement: `Paragraph 777 ${'y'.repeat(4096)}`,
});
assert.equal(large.nextMarkdown.includes(`Paragraph 777 ${'y'.repeat(128)}`), true);
assert.equal(large.nextMarkdown.includes(`Paragraph 776 ${'x'.repeat(128)}`), true);
assert.equal(large.nextMarkdown.includes(`Paragraph 778 ${'x'.repeat(128)}`), true);
assert.ok(large.region.to - large.region.from < 5000, 'large-doc writeback range should cover only one block');
assert.ok(Buffer.byteLength(large.nextMarkdown) > 5 * 1024 * 1024);

const fallbackTrackerRegion = runTrackerFallbackReset();
assert.equal(fallbackTrackerRegion.blockMarkdown, 'Alpha updated');
assert.equal(fallbackTrackerRegion.byteFrom, 0);
assert.equal(fallbackTrackerRegion.byteTo, Buffer.byteLength('Alpha'));

console.log('minimal writeback check passed');

function runParagraphEdit({ oldMarkdown, paragraphs, editIndex, replacement }) {
  const originalDoc = docFromParagraphs(paragraphs);
  const state = EditorState.create({ schema, doc: originalDoc });
  const from = textStartForParagraph(originalDoc, editIndex);
  const to = from + paragraphs[editIndex].length;
  const tr = state.tr.insertText(replacement, from, to);
  const maps = tr.steps.map(step => step.getMap());
  const oldSet = seedChangeSet(originalDoc);
  const newSet = oldSet.addSteps(tr.doc, maps, { source: 'check-minimal-writeback' });
  const result = minimalWriteback({
    oldSet,
    newSet,
    maps,
    oldMarkdown,
    newDoc: tr.doc,
    serializeDoc,
  });
  assert.ok(result, 'minimalWriteback should return one changed block region');
  return result;
}

function docFromParagraphs(paragraphs) {
  return schema.node(
    'doc',
    null,
    paragraphs.map(text => schema.node('paragraph', null, text.length ? schema.text(text) : null)),
  );
}

function textStartForParagraph(doc, paragraphIndex) {
  let position = 0;
  for (let index = 0; index < paragraphIndex; index += 1) {
    position += doc.child(index).nodeSize;
  }
  return position + 1;
}

function serializeDoc(doc) {
  const blocks = [];
  doc.forEach((node) => {
    if (node.type.name === 'heading') {
      blocks.push(`${'#'.repeat(node.attrs.level)} ${node.textContent}`.trimEnd());
    } else {
      blocks.push(node.textContent);
    }
  });
  return blocks.join('\n\n');
}

function runTrackerFallbackReset() {
  const tracker = new MarkdownWritebackTracker();
  let state = EditorState.create({ schema, doc: docFromParagraphs(['Alpha', 'Bravo']) });
  let currentMarkdown = 'Alpha\n';
  const editor = {
    get state() {
      return state;
    },
    getMarkdown() {
      return currentMarkdown;
    },
    markdown: {
      serialize(json) {
        return serializeDoc(schema.nodeFromJSON(json));
      },
    },
  };

  tracker.reset(editor, currentMarkdown);
  const first = state.tr.insertText(
    'Bravo updated',
    textStartForParagraph(state.doc, 1),
    textStartForParagraph(state.doc, 1) + 'Bravo'.length,
  );
  tracker.recordTransaction(editor, first);
  state = state.apply(first);
  currentMarkdown = 'Alpha\n\nBravo updated\n';
  assert.equal(
    tracker.consume(editor, currentMarkdown),
    null,
    'mismatched markdown/doc block counts should fall back to the full snapshot',
  );

  const second = state.tr.insertText(
    'Alpha updated',
    textStartForParagraph(state.doc, 0),
    textStartForParagraph(state.doc, 0) + 'Alpha'.length,
  );
  tracker.recordTransaction(editor, second);
  state = state.apply(second);
  currentMarkdown = 'Alpha updated\n\nBravo updated\n';
  const result = tracker.consume(editor, currentMarkdown);
  assert.ok(result, 'fallback reset should allow the next edit to use a fresh baseline');
  return result;
}
