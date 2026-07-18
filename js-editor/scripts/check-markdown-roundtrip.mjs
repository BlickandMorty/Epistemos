import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, normalize, resolve } from 'node:path';
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
const { EpdocBlockquote } = loadTSModule(resolve(sourceRoot, 'extensions/blockquote-node.ts'));
const { EpdocListItem } = loadTSModule(resolve(sourceRoot, 'extensions/list-item-node.ts'));
const { EpdocChartNode } = loadTSModule(resolve(sourceRoot, 'extensions/chart-node.ts'));
const { EpdocImageNode } = loadTSModule(resolve(sourceRoot, 'extensions/image-node.ts'));
const { LegacyDiagramNode } = loadTSModule(resolve(sourceRoot, 'extensions/legacy-diagram-node.ts'));
const { CalloutNode } = loadTSModule(resolve(sourceRoot, 'extensions/callout-node.ts'));
const { EpdocLink, EpdocWikiLinkMarkdown } = loadTSModule(
  resolve(sourceRoot, 'markdown/epdoc-markdown-nodes.ts'),
);
const {
  LensFidelityState,
  SerializerTier,
  datasetEmbedsContainNoRowData,
  disclosureItemsForLens,
  pickTier,
  roundTrip,
  splitFrontmatter,
} = loadTSModule(resolve(sourceRoot, 'markdown/tiers.ts'));

const manager = new MarkdownManager({
  indentation: { style: 'space', size: 2 },
  markedOptions: { breaks: false, gfm: true },
  extensions: [
    StarterKit.configure({
      blockquote: false,
      codeBlock: false,
      link: false,
      listItem: false,
    }),
    EpdocBlockquote,
    EpdocListItem,
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

const roundTripAdapter = {
  parse: source => manager.parse(source),
  serialize: document => manager.serialize(document),
};

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
  "provenance": { "kind": "dataset", "datasetId": "dataset:evidence.dataset.md", "range": "A1:B2", "ledgerPointer": "claim:chart-roundtrip" },
  "points": [{ "x": 0.8, "y": 0.9, "label": "Evidence" }]
}
\`\`\`

![Evidence screenshot](https://example.com/evidence.png "Figure 1")
`;

const roundTripResult = roundTrip(markdown, roundTripAdapter);
assert.equal(roundTripResult.ok, true, roundTripResult.detail);
assert.equal(roundTripResult.tier, SerializerTier.B);
assert.equal(roundTripResult.frontmatterPreserved, true);
assert.ok(roundTripResult.features.some(feature => feature.type === 'epdocChart'));
assert.ok(roundTripResult.features.some(feature => feature.type === 'wikilink'));

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
    { type: 'epdocChart', content: [{ type: 'text', text: '{"type":"bar","provenance":{"kind":"manual","source":"check-markdown-roundtrip"},"bars":[{"label":"A","value":1}]}' }] },
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

const tierA = {
  tier: SerializerTier.A,
  canHandle: node => node.type === 'paragraph',
  parse: source => ({ type: source }),
  serialize: node => node.type ?? '',
};
const tierC = {
  tier: SerializerTier.C,
  canHandle: () => true,
  parse: source => ({ type: source }),
  serialize: node => node.type ?? '',
};
assert.equal(pickTier({ type: 'paragraph' }, [tierA, tierC]).tier, SerializerTier.A);
assert.equal(pickTier({ type: 'unknownBlock' }, [tierA, tierC]).tier, SerializerTier.C);

const frontmatterDoc = `---
title: "[[Do not rewrite]]"
tags: [a_b, spaced value]
aliases:
  - Research~Draft
---

# Body

[[Target|Label]]
`;
const split = splitFrontmatter(frontmatterDoc);
assert.equal(split.frontmatter, `---
title: "[[Do not rewrite]]"
tags: [a_b, spaced value]
aliases:
  - Research~Draft
---
`);
assert.match(split.body, /^\n# Body/);

const frontmatterResult = roundTrip(frontmatterDoc, roundTripAdapter);
assert.equal(frontmatterResult.ok, true, frontmatterResult.detail);
assert.equal(frontmatterResult.frontmatterPreserved, true);
assert.equal(frontmatterResult.normalized.slice(0, split.frontmatter.length), split.frontmatter);
assert.match(frontmatterResult.normalized, /\[\[Target\|Label\]\]/);
assert.doesNotMatch(frontmatterResult.normalized, /\\\[|\\\]|\\_|\\~/);

const desktopCommander440 = `---
title: "A [[B]]"
tags: [raw_tag, keep~tilde]
---

| Claim | Evidence |
|---|---|
| One_Two | keep_this_token |

[[One_Two|One Two]]
`;
const desktopResult = roundTrip(desktopCommander440, roundTripAdapter);
assert.equal(desktopResult.ok, true, desktopResult.detail);
assert.equal(desktopResult.normalized.startsWith(desktopCommander440.split('\n\n')[0]), true);
assert.match(desktopResult.normalized, /\| Claim\s+\| Evidence\s+\|/);
assert.match(desktopResult.normalized, /\[\[One_Two\|One Two\]\]/);
assert.doesNotMatch(desktopResult.normalized, /\\\[|\\\]|\\_|\\~/);

const exactArchiveNestedQuote = `---
id: 3DA442EE-ECAA-4A5F-976C-552EFF240137
title: Codex Prompt 2 Stable Identity Archive Pass 2026-07-10
---

# Codex Prompt 2 Stable Identity Archive Pass 2026-07-10

**Rich fidelity marker:** c4c365bc-a716-48d9-bf0a-b10a761137e9

| Column A | Column B |
| --- | --- |
| **Bold cell** | _Italic cell_ |
| Alpha | Beta |

- First item
- - Second item
- > Archive fidelity quote
  >`;

function collectNodesByType(node, type, matches = []) {
  if (node?.type === type) matches.push(node);
  for (const child of node?.content ?? []) collectNodesByType(child, type, matches);
  return matches;
}

const exactArchiveParsed = manager.parse(exactArchiveNestedQuote);
const exactArchiveListItems = collectNodesByType(exactArchiveParsed, 'listItem');
assert.ok(exactArchiveListItems.length >= 3, 'exact archive fixture should retain all list items');
assert.equal(
  collectNodesByType(exactArchiveParsed, 'callout').length,
  0,
  'an ordinary blockquote must not parse as an Epistemos callout',
);
for (const item of exactArchiveListItems) {
  assert.equal(
    item.content?.[0]?.type,
    'paragraph',
    'Markdown list items must begin with a paragraph accepted by the editor schema',
  );
}
const exactArchiveSerialized = manager.serialize(exactArchiveParsed);
assert.notEqual(
  exactArchiveSerialized.trim(),
  '',
  'schema-repaired nested list items must not collapse the whole Markdown snapshot to empty',
);
assert.match(exactArchiveSerialized, /Archive fidelity quote/);
assert.match(exactArchiveSerialized, /\*\*Rich fidelity marker:\*\*/);
assert.doesNotMatch(
  exactArchiveSerialized,
  /> \[!INFO\]/,
  'an ordinary blockquote must not serialize as an Epistemos callout',
);
const exactArchiveReparsed = manager.parse(exactArchiveSerialized);
for (const item of collectNodesByType(exactArchiveReparsed, 'listItem')) {
  assert.equal(item.content?.[0]?.type, 'paragraph');
}
assert.match(JSON.stringify(exactArchiveReparsed), /Archive fidelity quote/);
assert.equal(
  collectNodesByType(exactArchiveReparsed, 'callout').length,
  0,
  'an ordinary blockquote must remain an ordinary blockquote after reparse',
);

const notebookManifest440 = `---
title: "Notebook [[Do not rewrite]]"
tags: [raw_tag, keep~tilde]
---

# Notebook

\`\`\`epistemos-notebook
version: 1
tab: id=11111111-1111-4111-8111-111111111111 type=sheet version=1 title="Metrics" ref="dataset:metrics.dataset.md"
tab: id=33333333-3333-4333-8333-333333333333 type=chat version=1 title="Analysis chat" ref="session:analysis-thread"
tab: id=44444444-4444-4444-8444-444444444444 type=future version=9 title="Future tab" ref="future:opaque"
\`\`\`

{{epistemos-ref id=55555555-5555-4555-8555-555555555555 type=sheet version=1 title="Inline Dataset" ref="dataset:inline.dataset.md"}}
`;
const notebookResult = roundTrip(notebookManifest440, roundTripAdapter);
assert.equal(notebookResult.ok, true, notebookResult.detail);
assert.equal(notebookResult.frontmatterPreserved, true);
assert.ok(notebookResult.features.some(feature => feature.type === 'notebookSheetTab'));
assert.ok(notebookResult.features.some(feature => feature.type === 'notebookChatTab'));
assert.ok(notebookResult.features.some(feature => feature.type === 'notebookUnknownTab' && feature.tier === SerializerTier.C));
assert.ok(notebookResult.features.some(feature => feature.type === 'datasetEmbed'));
assert.match(notebookResult.normalized, /```epistemos-notebook\nversion: 1/);
assert.match(notebookResult.normalized, /tab: id=11111111-1111-4111-8111-111111111111 type=sheet version=1/);
assert.match(notebookResult.normalized, /epistemos-ref id=55555555-5555-4555-8555-555555555555 type=sheet version=1/);
assert.doesNotMatch(notebookResult.normalized, /\\\[|\\\]|\\_|\\~/);

const rowPayloadNotebook = `# Notebook

\`\`\`epistemos-notebook
version: 1
tab: id=77777777-7777-4777-8777-777777777777 type=sheet version=1 title="Leaky" ref="dataset:leaky.dataset.md" rows="Alpha,2"
\`\`\`

{{epistemos-ref id=88888888-8888-4888-8888-888888888888 type=sheet version=1 title="Inline Dataset" ref="dataset:inline.dataset.md" values="Alpha,2"}}
`;
const rowPayloadResult = roundTrip(rowPayloadNotebook, roundTripAdapter);
assert.equal(datasetEmbedsContainNoRowData(rowPayloadNotebook), false);
assert.equal(rowPayloadResult.ok, false);
assert.equal(rowPayloadResult.detail, 'dataset embeds must reference dataset artifacts, not inline row data');
assert.ok(rowPayloadResult.features.some(feature => feature.type === 'datasetInlineRows' && feature.tier === SerializerTier.C));

const inlineMathCodeDrift = 'Inline code containing display math markers should skip  `$$` regions.\\n';
const inlineMathCodeResult = roundTrip(inlineMathCodeDrift, roundTripAdapter);
assert.equal(inlineMathCodeResult.ok, true, inlineMathCodeResult.detail);
assert.doesNotMatch(inlineMathCodeResult.normalized, / {2,}`\$\$`/);

const quarantine = `Before

<!-- epistemos-quarantine:start type="unknown" -->
<custom-block data-preserve="bytes">[[literal]]</custom-block>
<!-- epistemos-quarantine:end -->
`;
const quarantineResult = roundTrip(quarantine, roundTripAdapter);
assert.equal(quarantineResult.tier, SerializerTier.C);
assert.equal(quarantineResult.ok, true);
assert.equal(quarantineResult.bytesEqual, true);
assert.equal(quarantineResult.normalized, quarantine);

const disclosure = disclosureItemsForLens(parsed, 'prose');
assert.ok(disclosure.some(item => item.type === 'epdocChart' && item.fidelity === LensFidelityState.Invisible));
assert.ok(disclosure.some(item => item.type === 'callout' && item.fidelity === LensFidelityState.Degraded));
assert.equal(disclosureItemsForLens(parsed, 'document').length, 0);

const corpusFiles = markdownCorpus(resolve(scriptDir, '../../docs')).slice(0, 120);
assert.ok(corpusFiles.length >= 100, `expected at least 100 markdown corpus files, found ${corpusFiles.length}`);
const corpusFailures = [];
for (const file of corpusFiles) {
  const result = roundTrip(readFileSync(file, 'utf8'), roundTripAdapter);
  if (!result.ok) {
    corpusFailures.push(`${file}: ${result.detail ?? 'roundtrip failed'}`);
  }
}
assert.deepEqual(corpusFailures, [], `markdown corpus roundtrip failures:\n${corpusFailures.join('\n')}`);

console.log('markdown roundtrip check passed');

function markdownCorpus(root) {
  const files = [];
  walk(root, files);
  return files.sort((lhs, rhs) => lhs.localeCompare(rhs));
}

function walk(directory, files) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    if (entry.name === 'node_modules' || entry.name === 'build' || entry.name === 'DerivedData') continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      walk(path, files);
      continue;
    }
    if (!entry.isFile() || !entry.name.endsWith('.md')) continue;
    const stats = statSync(path);
    if (stats.size === 0 || stats.size > 200_000) continue;
    files.push(path);
  }
}
