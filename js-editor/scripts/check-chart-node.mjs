import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Script, createContext } from 'node:vm';
import ts from 'typescript';

const sourcePath = new URL('../src/extensions/chart-node.ts', import.meta.url);
const source = readFileSync(sourcePath, 'utf8');
const transpiled = ts.transpileModule(
  `${source}\nmodule.exports.__epdocChartTest = { parseChartSpec, renderChartInto };`,
  {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      strict: true,
    },
    fileName: 'chart-node.ts',
  },
).outputText;

class FakeClassList {
  constructor() {
    this.values = new Set();
  }

  add(...values) {
    values.forEach((value) => this.values.add(value));
  }

  contains(value) {
    return this.values.has(value);
  }
}

class FakeElement {
  constructor(tagName, namespaceURI = '') {
    this.tagName = tagName;
    this.namespaceURI = namespaceURI;
    this.attributes = new Map();
    this.children = [];
    this.classList = new FakeClassList();
    this.dataset = {};
    this.textContent = '';
    this.contentEditable = '';
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
    if (name === 'class') {
      this.classList.add(...String(value).split(/\s+/).filter(Boolean));
    }
  }

  append(...nodes) {
    nodes.forEach((node) => this.appendChild(node));
  }

  appendChild(node) {
    this.children.push(node);
    return node;
  }

  replaceChildren(...nodes) {
    this.children = [];
    this.append(...nodes);
  }
}

const fakeDocument = {
  createElement(tagName) {
    return new FakeElement(tagName);
  },
  createElementNS(namespaceURI, tagName) {
    return new FakeElement(tagName, namespaceURI);
  },
};

const moduleShim = { exports: {} };
const context = createContext({
  exports: moduleShim.exports,
  module: moduleShim,
  document: fakeDocument,
  require(name) {
    if (name === '@tiptap/core') {
      return {
        Node: { create: (definition) => definition },
        mergeAttributes: (...attributes) => Object.assign({}, ...attributes),
      };
    }
    throw new Error(`Unexpected import in chart-node check: ${name}`);
  },
});

new Script(transpiled, { filename: 'chart-node.js' }).runInContext(context);

const { parseChartSpec, renderChartInto } = context.module.exports.__epdocChartTest;
assert.equal(typeof parseChartSpec, 'function');
assert.equal(typeof renderChartInto, 'function');

const scatter = JSON.stringify({
  type: 'scatter',
  title: 'Confidence vs impact',
  x: { label: 'Confidence', min: 0, max: 1 },
  y: { label: 'Impact', min: 0, max: 1 },
  points: [
    { x: 0.82, y: 0.74, label: 'Primary source', category: 'source' },
    { x: 0.32, y: 0.42, label: 'Anecdote', category: 'weak' },
  ],
});

const line = JSON.stringify({
  type: 'line',
  points: [
    { x: 1, y: 0.42, label: 'Capture' },
    { x: 2, y: 0.58, label: 'Source pass' },
  ],
});

const bar = JSON.stringify({
  type: 'bar',
  bars: [
    { label: 'Primary', value: 8 },
    { label: 'Dataset', value: 5 },
  ],
});

assert.equal(parseChartSpec(scatter).type, 'scatter');
assert.equal(parseChartSpec(line).type, 'line');
assert.equal(parseChartSpec(bar).type, 'bar');
assert.equal(parseChartSpec('{"type":"pie"}'), null);
assert.equal(parseChartSpec('not json'), null);

const scatterContainer = render(scatter);
assert.equal(countByTag(scatterContainer, 'svg'), 1);
assert.equal(countByClass(scatterContainer, 'epdoc-chart-point'), 2);
assert.equal(countByClass(scatterContainer, 'epdoc-chart-bar'), 0);
assert.equal(countByClass(scatterContainer, 'epdoc-chart-line'), 0);

const lineContainer = render(line);
assert.equal(countByClass(lineContainer, 'epdoc-chart-line'), 1);
assert.equal(countByClass(lineContainer, 'epdoc-chart-point'), 2);

const barContainer = render(bar);
assert.equal(countByClass(barContainer, 'epdoc-chart-bar'), 2);
assert.equal(countByClass(barContainer, 'epdoc-chart-point'), 0);

const invalidContainer = render('not json');
assert.equal(countByClass(invalidContainer, 'epdoc-chart-error'), 1);
assert.ok(flatText(invalidContainer).includes('Invalid chart JSON'));

const emptyContainer = render('{"type":"scatter","points":[]}');
assert.ok(flatText(emptyContainer).includes('Add points to render this chart'));

console.log('chart node renderer check passed');

function render(sourceText) {
  const container = new FakeElement('div');
  renderChartInto(container, sourceText);
  return container;
}

function countByTag(node, tagName) {
  return walk(node).filter((candidate) => candidate.tagName === tagName).length;
}

function countByClass(node, className) {
  return walk(node).filter((candidate) => candidate.classList?.contains(className)).length;
}

function flatText(node) {
  return walk(node).map((candidate) => candidate.textContent ?? '').join(' ');
}

function walk(node) {
  const nodes = [node];
  for (const child of node.children ?? []) {
    nodes.push(...walk(child));
  }
  return nodes;
}
