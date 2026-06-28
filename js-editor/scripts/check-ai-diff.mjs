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
  });
  new Script(transpiled, { filename: absolutePath }).runInContext(context);
  return moduleShim.exports;
}

const { Schema } = require('@tiptap/pm/model');
const {
  buildEpdocAIDiffPreview,
  epdocAIDiffIsPreviewCommand,
  normalizeEpdocAIDiffStageRequest,
} = loadTSModule(resolve(sourceRoot, 'extensions/ai-diff.ts'));

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

function doc(text) {
  return schema.node('doc', null, [
    schema.node('paragraph', null, text.length > 0 ? schema.text(text) : undefined),
  ]);
}

const request = normalizeEpdocAIDiffStageRequest({
  markdown: 'Alpha delta gamma',
  claimId: 'claim-123',
  batchId: 'batch-abc',
  settled: true,
});
assert.equal(request.markdown, 'Alpha delta gamma');
assert.equal(request.claimId, 'claim-123');
assert.equal(request.batchId, 'batch-abc');
assert.equal(request.settled, true);

assert.equal(normalizeEpdocAIDiffStageRequest({
  markdown: 'Alpha delta gamma',
  claimId: 'claim-123',
  batchId: 'batch-abc',
  settled: false,
}), null, 'AI diff must reject token-stream or unsettled batches');

assert.equal(normalizeEpdocAIDiffStageRequest({
  markdown: 'Alpha delta gamma',
  claimId: 'claim-123',
  settled: true,
}), null, 'AI diff must carry a batch id for review/provenance');

const preview = buildEpdocAIDiffPreview(
  doc('Alpha beta gamma'),
  doc('Alpha delta gamma'),
  { claimId: 'claim-123', batchId: 'batch-abc' },
);

assert.equal(preview.changes.length, 1);
assert.equal(preview.insertions.length, 1);
assert.equal(preview.deletions.length, 1);
assert.equal(preview.insertions[0].text, 'delta');
assert.equal(preview.deletions[0].text, 'beta');
assert.equal(preview.insertions[0].claimId, 'claim-123');
assert.equal(preview.deletions[0].batchId, 'batch-abc');

const insertionOnly = buildEpdocAIDiffPreview(
  doc('Alpha beta'),
  doc('Alpha beta gamma'),
  { claimId: 'claim-456', batchId: 'batch-def' },
);
assert.equal(insertionOnly.deletions.length, 0);
assert.equal(insertionOnly.insertions[0].text, 'gamma');

assert.equal(epdocAIDiffIsPreviewCommand('stageEpdocAIDiff'), true);
assert.equal(epdocAIDiffIsPreviewCommand('rejectEpdocAIDiff'), true);
assert.equal(epdocAIDiffIsPreviewCommand('clearEpdocAIDiff'), true);
assert.equal(epdocAIDiffIsPreviewCommand('acceptEpdocAIDiff'), false);

console.log('AI diff check passed');
