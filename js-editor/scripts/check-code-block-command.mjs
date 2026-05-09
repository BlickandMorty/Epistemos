import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Schema } from '@tiptap/pm/model';
import { EditorState, TextSelection } from '@tiptap/pm/state';

const codeBlockSource = readFileSync(new URL('../src/extensions/code-block-node.ts', import.meta.url), 'utf8');
assert.match(
  codeBlockSource,
  /export function closingFenceLineRange/,
  'Epdoc code blocks must keep a typed closing-fence detector',
);
assert.match(
  codeBlockSource,
  /this\.editor\.commands\.exitCode\(\)/,
  'Typed closing ``` inside an Epdoc code block must exit to a normal paragraph',
);
assert.doesNotMatch(
  codeBlockSource,
  /closingFenceLineRange[\s\S]*toggleCodeBlock/,
  'Closing fence handling should exit the current code block, not toggle a second block',
);

const schema = new Schema({
  nodes: {
    doc: { content: 'block+' },
    paragraph: {
      content: 'text*',
      group: 'block',
      toDOM() { return ['p', 0]; },
    },
    codeBlock: {
      content: 'text*',
      marks: '',
      group: 'block',
      code: true,
      defining: true,
      attrs: { language: { default: null } },
      toDOM() { return ['pre', ['code', 0]]; },
    },
    text: { group: 'inline' },
  },
  marks: {},
});

const lines = [
  'memory is structured',
  'claims are typed',
  'attention is scarce',
  'proof is attached',
  'state is witnessed',
];

const doc = schema.nodes.doc.create(
  null,
  lines.map(line => schema.nodes.paragraph.create(null, schema.text(line))),
);

let state = EditorState.create({ doc, schema });
state = state.apply(state.tr.setSelection(TextSelection.create(doc, 1, doc.content.size - 1)));

const { from, to, $from, $to } = state.selection;
const selectedText = state.doc.textBetween(from, to, '\n').trimEnd();
const codeBlockType = schema.nodes.codeBlock;
const paragraphType = schema.nodes.paragraph;
const codeBlock = codeBlockType.create({ language: 'swift' }, schema.text(selectedText));
const blockRange = $from.blockRange($to);
const replaceFrom = blockRange?.start ?? from;
const replaceTo = blockRange?.end ?? to;
let tr = state.tr.replaceWith(replaceFrom, replaceTo, codeBlock);
const paragraphPosition = tr.mapping.map(replaceFrom) + codeBlock.nodeSize;
tr = tr.insert(paragraphPosition, paragraphType.create());

const output = tr.doc.toJSON();
assert.equal(output.content?.length, 2);
assert.equal(output.content?.[0]?.type, 'codeBlock');
assert.equal(output.content?.[0]?.attrs?.language, 'swift');
assert.equal(output.content?.[0]?.content?.[0]?.text, lines.join('\n'));
assert.equal(output.content?.[1]?.type, 'paragraph');

let codeBlockCount = 0;
tr.doc.descendants(node => {
  if (node.type.name === 'codeBlock') codeBlockCount += 1;
});
assert.equal(codeBlockCount, 1, `expected one codeBlock, got ${codeBlockCount}`);

console.log('code block command range check passed');
