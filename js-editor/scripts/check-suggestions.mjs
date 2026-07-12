import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';
import { addSuggestionMarks, suggestChanges, suggestChangesKey } from '@handlewithcare/prosemirror-suggest-changes';
import { Schema } from 'prosemirror-model';
import { EditorState } from 'prosemirror-state';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const sourceRoot = resolve(scriptDir, '../src');
const tempDir = mkdtempSync(resolve(scriptDir, '../.tmp-suggestions-'));

function transpileTSModule(relativePath) {
  const sourcePath = resolve(sourceRoot, relativePath);
  const source = readFileSync(sourcePath, 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.ES2022,
      target: ts.ScriptTarget.ES2022,
      strict: true,
      esModuleInterop: true,
      isolatedModules: true,
    },
    fileName: sourcePath,
  }).outputText;
  const outputPath = resolve(tempDir, `${relativePath.replaceAll('/', '-')}.mjs`);
  writeFileSync(outputPath, output);
  return import(pathToFileURL(outputPath));
}

const { HwcSuggestionAdapter, NoopSuggestionAdapter } = await transpileTSModule(
  'suggestions/SuggestionAdapter.ts',
);
const { suggestionPayloadFromArgs } = await transpileTSModule(
  'bridge/suggestion-payload.ts',
);

const schema = new Schema({
  nodes: {
    doc: { content: 'block+', marks: 'insertion modification deletion' },
    paragraph: {
      content: 'text*',
      group: 'block',
      parseDOM: [{ tag: 'p' }],
      toDOM: () => ['p', 0],
    },
    text: { group: 'inline' },
  },
  marks: addSuggestionMarks({}),
});

function makeState(text = 'Alpha beta') {
  let state = EditorState.create({
    schema,
    doc: schema.node('doc', null, [
      schema.node('paragraph', null, text.length > 0 ? schema.text(text) : undefined),
    ]),
    plugins: [suggestChanges()],
  });
  state = state.apply(state.tr.setMeta(suggestChangesKey, { enabled: true }));
  return state;
}

function suggestionTexts(state, markName) {
  const values = [];
  state.doc.descendants((node) => {
    if (!node.isText) return true;
    const mark = node.marks.find(candidate => candidate.type.name === markName);
    if (mark) values.push({ text: node.text ?? '', id: mark.attrs.id });
    return true;
  });
  return values;
}

function suggestionMarkCount(state) {
  let count = 0;
  state.doc.descendants((node) => {
    count += node.marks.filter(mark => (
      mark.type.name === 'insertion'
      || mark.type.name === 'deletion'
      || mark.type.name === 'modification'
    )).length;
  });
  return count;
}

const payload = {
  id: 'agent-1',
  author: 'lumen',
  turnId: 'turn-1',
  kind: 'replacement',
  from: 7,
  to: 11,
  mapVersion: 2,
  before: 'beta',
  after: 'delta',
  claimId: 'claim:agent-1',
};

assert.deepEqual(suggestionPayloadFromArgs([payload]), payload);
assert.equal(suggestionPayloadFromArgs([{ ...payload, from: 7.25 }]), null);
assert.equal(suggestionPayloadFromArgs([{ ...payload, from: -1 }]), null);
assert.equal(suggestionPayloadFromArgs([{ ...payload, to: 6 }]), null);
assert.equal(suggestionPayloadFromArgs([{ ...payload, mapVersion: 2.5 }]), null);
assert.equal(suggestionPayloadFromArgs([{ ...payload, mapVersion: -1 }]), null);
assert.equal(suggestionPayloadFromArgs([{ ...payload, id: '   ' }]), null);

let state = makeState();
const adapter = new HwcSuggestionAdapter();
state = state.apply(adapter.ingestAgentEdit(state, payload));

assert.equal(state.doc.textContent, 'Alpha betadelta');
assert.deepEqual(suggestionTexts(state, 'deletion'), [{ text: 'beta', id: 'agent-1' }]);
assert.deepEqual(suggestionTexts(state, 'insertion'), [{ text: 'delta', id: 'agent-1' }]);

let accepted = state;
assert.equal(adapter.applySuggestion(accepted, 'agent-1', (tr) => {
  accepted = accepted.apply(tr);
}), true);
assert.equal(accepted.doc.textContent, 'Alpha delta');
assert.equal(suggestionMarkCount(accepted), 0);

let rejected = makeState();
rejected = rejected.apply(adapter.ingestAgentEdit(rejected, payload));
assert.equal(adapter.revertSuggestion(rejected, 'agent-1', (tr) => {
  rejected = rejected.apply(tr);
}), true);
assert.equal(rejected.doc.textContent, 'Alpha beta');
assert.equal(suggestionMarkCount(rejected), 0);

let missingAcceptDispatchRan = false;
assert.equal(adapter.applySuggestion(makeState(), 'missing-agent', () => {
  missingAcceptDispatchRan = true;
}), false);
assert.equal(missingAcceptDispatchRan, false);

let missingRejectDispatchRan = false;
assert.equal(adapter.revertSuggestion(makeState(), 'missing-agent', () => {
  missingRejectDispatchRan = true;
}), false);
assert.equal(missingRejectDispatchRan, false);

let decoratedState = makeState('');
const view = {
  get state() {
    return decoratedState;
  },
  dispatch(tr) {
    decoratedState = decoratedState.apply(tr);
  },
  updateState(next) {
    decoratedState = next;
  },
};
const decorated = new HwcSuggestionAdapter({ view: () => view }).decorateDispatch((tr) => {
  decoratedState = decoratedState.apply(tr);
});
decorated(decoratedState.tr.insertText('x', 1));
assert.equal(decoratedState.doc.textContent, 'x');
assert.deepEqual(suggestionTexts(decoratedState, 'insertion'), [{ text: 'x', id: 'agent-1' }]);

decoratedState = makeState();
decorated(adapter.ingestAgentEdit(decoratedState, payload));
assert.equal(decoratedState.doc.textContent, 'Alpha betadelta');
assert.deepEqual(suggestionTexts(decoratedState, 'deletion'), [{ text: 'beta', id: 'agent-1' }]);
assert.deepEqual(suggestionTexts(decoratedState, 'insertion'), [{ text: 'delta', id: 'agent-1' }]);
assert.equal(adapter.applySuggestion(decoratedState, 'agent-1', (tr) => {
  decoratedState = decoratedState.apply(tr);
}), true);
assert.equal(decoratedState.doc.textContent, 'Alpha delta');
assert.equal(suggestionMarkCount(decoratedState), 0);

const noop = new NoopSuggestionAdapter();
let noopDispatchRan = false;
noop.decorateDispatch(() => {
  noopDispatchRan = true;
})(makeState().tr);
assert.equal(noopDispatchRan, true);
assert.equal(noop.ingestAgentEdit(makeState(), payload).docChanged, false);
assert.equal(noop.applySuggestion(makeState(), 'agent-1', () => {}), false);
assert.equal(noop.revertSuggestion(makeState(), 'agent-1', () => {}), false);

rmSync(tempDir, { recursive: true, force: true });

console.log('suggestion adapter check passed');
