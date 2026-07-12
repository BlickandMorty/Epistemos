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
    performance,
    require: (specifier) => {
      if (specifier.startsWith('.')) {
        return loadTSModule(resolve(dirname(absolutePath), `${specifier}.ts`));
      }
      return require(specifier);
    },
  });
  new Script(transpiled, { filename: absolutePath }).runInContext(context);
  return moduleShim.exports;
}

const { Schema } = require('@tiptap/pm/model');
const { EditorState } = require('@tiptap/pm/state');
const {
  beginLoad,
  currentLoadEpoch,
  endLoad,
  EPOCH_META,
  HOST_LOAD_META,
  loadStateKey,
  loadStatePlugin,
  USER_INPUT_META,
} = loadTSModule(resolve(sourceRoot, 'bridge/document-load-state.ts'));

const schema = new Schema({
  nodes: {
    doc: { content: 'block+' },
    paragraph: {
      content: 'text*',
      group: 'block',
      parseDOM: [{ tag: 'p' }],
      toDOM: () => ['p', 0],
    },
    text: { group: 'inline' },
  },
});

function makeState(epoch = 2) {
  return EditorState.create({
    schema,
    doc: schema.node('doc', null, [schema.node('paragraph')]),
    plugins: [loadStatePlugin(epoch)],
  });
}

let state = makeState(2);
assert.equal(currentLoadEpoch(state), 2);

const stale = state.tr.insertText('x', 1).setMeta(EPOCH_META, 1);
const staleResult = state.applyTransaction(stale);
assert.equal(
  staleResult.transactions.length,
  0,
  'a stale epoch document transaction must be rejected by filterTransaction',
);

const fresh = state.tr.insertText('y', 1).setMeta(EPOCH_META, 2);
const freshResult = state.applyTransaction(fresh);
assert.equal(freshResult.transactions.length, 1);

state = makeState(2);
const view = {
  get state() {
    return state;
  },
  dispatch(tr) {
    state = state.apply(tr);
  },
};

const loadEpoch = beginLoad(view, 10_000, 3);
assert.equal(loadEpoch, 3);
assert.equal(loadStateKey.getState(state).loading, true);

const userDuringLoad = state.tr
  .insertText('u', 1)
  .setMeta(EPOCH_META, 3)
  .setMeta(USER_INPUT_META, true);
assert.equal(
  state.applyTransaction(userDuringLoad).transactions.length,
  0,
  'document edits must not land while a host load is active',
);

const hostLoadTxn = state.tr
  .insertText('h', 1)
  .setMeta(EPOCH_META, 3)
  .setMeta(HOST_LOAD_META, true);
const hostLoadResult = state.applyTransaction(hostLoadTxn);
assert.equal(hostLoadResult.transactions.length, 1);
state = hostLoadResult.state;

assert.equal(endLoad(view), 3);
assert.equal(loadStateKey.getState(state).loading, false);

const suppressedProgrammatic = state.tr.insertText('s', 1).setMeta(EPOCH_META, 3);
assert.equal(
  state.applyTransaction(suppressedProgrammatic).transactions.length,
  0,
  'programmatic document churn inside the suppression window must be rejected',
);

const userAfterLoad = state.tr
  .insertText('u', 1)
  .setMeta(EPOCH_META, 3)
  .setMeta(USER_INPUT_META, true);
assert.equal(state.applyTransaction(userAfterLoad).transactions.length, 1);

console.log('document load-state check passed');
