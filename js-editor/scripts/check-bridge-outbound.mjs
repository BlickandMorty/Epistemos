import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const sourceRoot = resolve(scriptDir, '../src');
const tempDir = mkdtempSync(resolve(scriptDir, '../.tmp-bridge-outbound-'));

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

const postedPayloads = [];
const requestedFrames = [];

globalThis.requestAnimationFrame = (callback) => {
  requestedFrames.push(callback);
  return requestedFrames.length;
};

globalThis.window = {
  webkit: {
    messageHandlers: {
      epdoc: {
        postMessage(payload) {
          postedPayloads.push(payload);
        },
      },
    },
  },
};

try {
  const { postBridge } = await transpileTSModule('bridge/outbound.ts');

  postBridge({
    type: 'documentStatsChanged',
    epoch: 4,
    wordCount: 2,
    characterCount: 11,
  });
  window.epdocOutboundBridge.flushSync();
  assert.equal(postedPayloads.length, 1);
  assert.equal(postedPayloads[0].type, 'documentStatsChanged');
  assert.equal(postedPayloads[0].epoch, 4);

  postedPayloads.length = 0;
  postBridge({
    type: 'contentDidChange',
    epoch: 9,
    json: '{"type":"doc","content":[]}',
  });
  postBridge({
    type: 'markdownDidChange',
    epoch: 9,
    markdown: 'Alpha\n\nBravo updated\n',
    writeback: {
      from: 7,
      to: 12,
      byteFrom: 7,
      byteTo: 12,
      codeUnitFrom: 7,
      codeUnitTo: 12,
      changedFrom: 2,
      changedTo: 3,
      blockIndexFrom: 1,
      blockIndexTo: 1,
      blockMarkdown: 'Bravo updated',
    },
  });
  postBridge({
    type: 'suggestionResolved',
    epoch: 9,
    suggestionId: 'span-batch',
    state: 'accepted',
  });
  window.epdocOutboundBridge.flushSync();

  assert.equal(postedPayloads.length, 1);
  assert.equal(postedPayloads[0].type, 'batch');
  assert.deepEqual(
    postedPayloads[0].messages.map((message) => message.type),
    ['contentDidChange', 'markdownDidChange', 'suggestionResolved'],
  );
  assert.deepEqual(postedPayloads[0].messages.map((message) => message.epoch), [9, 9, 9]);
  assert.equal(postedPayloads[0].messages[1].writeback.blockMarkdown, 'Bravo updated');
  assert.equal(postedPayloads[0].messages[2].suggestionId, 'span-batch');
  assert.equal(postedPayloads[0].messages[2].state, 'accepted');
  assert.ok(requestedFrames.length >= 2, 'postBridge should schedule display-frame flushes');
} finally {
  rmSync(tempDir, { recursive: true, force: true });
  delete globalThis.window;
  delete globalThis.requestAnimationFrame;
}
