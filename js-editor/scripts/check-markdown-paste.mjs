import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Script, createContext } from 'node:vm';
import ts from 'typescript';

const sourcePath = new URL('../src/markdown/markdown-paste.ts', import.meta.url);
const source = readFileSync(sourcePath, 'utf8');
const transpiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
    strict: true,
  },
  fileName: 'markdown-paste.ts',
}).outputText;

const moduleShim = { exports: {} };
const context = createContext({
  exports: moduleShim.exports,
  module: moduleShim,
});
new Script(transpiled, { filename: 'markdown-paste.js' }).runInContext(context);

const { parseMarkdownPaste } = context.module.exports;
assert.equal(typeof parseMarkdownPaste, 'function');

const parsed = parseMarkdownPaste(`# Research Spine

Normal paragraph with [source](https://example.com) and \`inline code\`.

## Method

\`\`\`swift
func verify() {
  print("structured paste")
}
\`\`\`

\`\`\`mermaid
flowchart TD
  A --> B
\`\`\`

| Claim | Evidence |
|---|---|
| Local-first | Package assets |

- [ ] Verify paste
- [x] Ship structure

> [!NOTE] Canon
> Use real blocks.

\`\`\`json
{
  "type": "scatter",
  "points": [{ "x": 0.8, "y": 0.9, "label": "Evidence" }]
}
\`\`\`
`);

assert.ok(Array.isArray(parsed));
assert.equal(parsed[0].type, 'heading');
assert.equal(parsed[0].attrs.level, 1);
assert.equal(parsed[1].type, 'paragraph');
assert.equal(parsed[1].content[1].marks[0].type, 'link');
assert.equal(parsed[1].content[1].marks[0].attrs.href, 'https://example.com');
assert.equal(parsed[1].content[3].marks[0].type, 'code');
assert.equal(parsed[2].type, 'heading');
assert.equal(parsed[3].type, 'codeBlock');
assert.equal(parsed[3].attrs.language, 'swift');
assert.match(parsed[3].content[0].text, /func verify/);
assert.equal(parsed[4].type, 'mermaid');
assert.match(parsed[4].content[0].text, /^flowchart TD/);
assert.equal(parsed[5].type, 'table');
assert.equal(parsed[5].content[0].content[0].type, 'tableHeader');
assert.equal(parsed[6].type, 'taskList');
assert.equal(parsed[6].content[0].attrs.checked, false);
assert.equal(parsed[6].content[1].attrs.checked, true);
assert.equal(parsed[7].type, 'callout');
assert.equal(parsed[7].attrs.kind, 'note');
assert.equal(parsed[8].type, 'epdocChart');
assert.equal(parsed.at(-1).type, 'paragraph');

const image = parseMarkdownPaste('![Evidence screenshot](https://example.com/evidence.png "Figure 1")');
assert.equal(image[0].type, 'epdocImage');
assert.equal(image[0].attrs.src, 'https://example.com/evidence.png');
assert.equal(image[0].attrs.alt, 'Evidence screenshot');
assert.equal(image[0].attrs.title, 'Figure 1');

const bareImage = parseMarkdownPaste('https://cdn.example.com/plots/confidence-scatter.webp?rev=2');
assert.equal(bareImage[0].type, 'epdocImage');
assert.equal(bareImage[0].attrs.alt, 'confidence-scatter.webp');

const rich = parseMarkdownPaste(`# Rich Inline

**bold** *italic* ~~strike~~ ==highlight== $x^2$ [[Claim Note|claim]]`);
const richJSON = JSON.stringify(rich);
assert.match(richJSON, /"type":"bold"/);
assert.match(richJSON, /"type":"italic"/);
assert.match(richJSON, /"type":"strike"/);
assert.match(richJSON, /"type":"highlight"/);
assert.match(richJSON, /"type":"inlineMath"/);
assert.match(richJSON, /epistemos-doc:wiki\/Claim%20Note/);

assert.equal(parseMarkdownPaste('plain prose only\nwith another prose line'), null);
assert.equal(parseMarkdownPaste(''), null);

console.log('markdown paste parser check passed');
