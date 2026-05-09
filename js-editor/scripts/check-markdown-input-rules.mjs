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

const {
  markdownLinkInputFinder,
  tableMarkdownInputFinder,
  wikiLinkInputFinder,
  replaceInputWithInlineLink,
} = loadTSModule(resolve(sourceRoot, 'extensions/markdown-input-rules.ts'));

assert.equal(typeof markdownLinkInputFinder, 'function');
assert.equal(typeof tableMarkdownInputFinder, 'function');
assert.equal(typeof wikiLinkInputFinder, 'function');
assert.equal(typeof replaceInputWithInlineLink, 'function');

const markdown = markdownLinkInputFinder('Read [source](https://example.com/paper)');
assert.equal(markdown.text, '[source](https://example.com/paper)');
assert.equal(markdown.data.label, 'source');
assert.equal(markdown.data.href, 'https://example.com/paper');

assert.equal(
  markdownLinkInputFinder('![source](https://example.com/paper.png)'),
  null,
  'image markdown must remain owned by EpdocImageNode, not become a stray text link',
);
assert.equal(markdownLinkInputFinder('[bad](javascript:alert(1))'), null);

const typedTable = tableMarkdownInputFinder('| Surface | Status |\n|---|---|\n| Epdoc graph | fixed |\n');
assert.equal(typedTable.text, '| Surface | Status |\n|---|---|\n| Epdoc graph | fixed |\n');
assert.equal(typedTable.data.markdown, '| Surface | Status |\n|---|---|\n| Epdoc graph | fixed |');

const headerOnlyTable = tableMarkdownInputFinder('| Surface | Status |\n|---|---|\n');
assert.equal(headerOnlyTable.data.markdown, '| Surface | Status |\n|---|---|');
assert.equal(tableMarkdownInputFinder('| not | enough |'), null);

const wiki = wikiLinkInputFinder('Connect [[Capability Sandwich|claim]]');
assert.equal(wiki.text, '[[Capability Sandwich|claim]]');
assert.equal(wiki.data.label, 'claim');
assert.equal(wiki.data.href, 'epistemos-doc:wiki/Capability%20Sandwich');

const wikiNoAlias = wikiLinkInputFinder('Connect [[Epdoc Graph]]');
assert.equal(wikiNoAlias.data.label, 'Epdoc Graph');
assert.equal(wikiNoAlias.data.href, 'epistemos-doc:wiki/Epdoc%20Graph');

const { createChainableState } = require('@tiptap/core');
const { Schema } = require('@tiptap/pm/model');
const { EditorState } = require('@tiptap/pm/state');

const schema = new Schema({
  nodes: {
    doc: { content: 'block+' },
    paragraph: {
      content: 'text*',
      group: 'block',
      toDOM() { return ['p', 0]; },
    },
    text: { group: 'inline' },
  },
  marks: {
    link: {
      attrs: { href: {} },
      inclusive: false,
      toDOM(mark) { return ['a', { href: mark.attrs.href }, 0]; },
    },
  },
});

const token = '[[Capability Sandwich|claim]]';
const doc = schema.nodes.doc.create(null, [
  schema.nodes.paragraph.create(null, schema.text(token)),
]);
const baseState = EditorState.create({ schema, doc });
const tr = baseState.tr;
const chainableState = createChainableState({ state: baseState, transaction: tr });

replaceInputWithInlineLink(chainableState, { from: 1, to: 1 + token.length }, wiki.data);

const output = tr.doc.toJSON();
assert.equal(output.content[0].content[0].text, 'claim');
assert.equal(output.content[0].content[0].marks[0].type, 'link');
assert.equal(output.content[0].content[0].marks[0].attrs.href, 'epistemos-doc:wiki/Capability%20Sandwich');
assert.ok(tr.steps.length > 0, 'input-rule helper must mutate the active transaction');

console.log('markdown input rules check passed');
