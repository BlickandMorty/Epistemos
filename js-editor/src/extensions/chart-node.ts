import { Node, mergeAttributes } from '@tiptap/core';
import type { Node as ProseMirrorNode } from '@tiptap/pm/model';

type ChartKind = 'scatter' | 'bar' | 'line';

interface ChartAxis {
  label?: string;
  min?: number;
  max?: number;
}

interface ChartPoint {
  x: number;
  y: number;
  label?: string;
  category?: string;
}

interface ChartBar {
  label: string;
  value: number;
}

interface EpdocChartSpec {
  type: ChartKind;
  title?: string;
  x?: ChartAxis;
  y?: ChartAxis;
  points?: ChartPoint[];
  bars?: ChartBar[];
}

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    epdocChart: {
      insertEpdocChart: (options: { source: string }) => ReturnType;
    };
  }
}

export const EpdocChartNode = Node.create({
  name: 'epdocChart',
  group: 'block',
  content: 'text*',
  marks: '',
  defining: true,
  isolating: true,
  selectable: true,
  draggable: true,
  code: true,

  parseHTML() {
    return [{ tag: 'div[data-epdoc-chart]', preserveWhitespace: 'full' }];
  },

  renderHTML({ HTMLAttributes, node }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, { 'data-epdoc-chart': '' }),
      node.textContent,
    ];
  },

  addCommands() {
    return {
      insertEpdocChart:
        options =>
        ({ commands }) => {
          const source = options.source.trim();
          if (!source) return false;
          return commands.insertContent([
            {
              type: this.name,
              content: [{ type: 'text', text: source }],
            },
            { type: 'paragraph' },
          ]);
        },
    };
  },

  addNodeView() {
    return ({ node, HTMLAttributes }) => {
      const dom = document.createElement('div');
      dom.dataset.epdocChart = '';
      dom.classList.add('epdoc-chart');
      dom.contentEditable = 'false';
      Object.entries(HTMLAttributes).forEach(([key, value]) => {
        if (typeof value === 'string') dom.setAttribute(key, value);
      });

      const header = document.createElement('div');
      header.classList.add('epdoc-chart-header');
      const title = document.createElement('span');
      title.classList.add('epdoc-chart-title');
      title.textContent = 'Research chart';
      const syntax = document.createElement('span');
      syntax.classList.add('epdoc-chart-syntax');
      syntax.textContent = chartKindLabel(node.textContent);
      header.append(title, syntax);
      dom.appendChild(header);

      const preview = document.createElement('div');
      preview.classList.add('epdoc-chart-preview');
      dom.appendChild(preview);

      const sourceDisclosure = document.createElement('details');
      sourceDisclosure.classList.add('epdoc-chart-source-wrap');
      const summary = document.createElement('summary');
      summary.textContent = 'Chart data';
      const source = document.createElement('pre');
      source.contentEditable = 'false';
      source.classList.add('epdoc-chart-source');
      source.textContent = node.textContent;
      sourceDisclosure.append(summary, source);
      dom.appendChild(sourceDisclosure);

      renderChartInto(preview, node.textContent);

      return {
        dom,
        update(updatedNode: ProseMirrorNode) {
          if (updatedNode.type !== node.type) return false;
          source.textContent = updatedNode.textContent;
          syntax.textContent = chartKindLabel(updatedNode.textContent);
          renderChartInto(preview, updatedNode.textContent);
          return true;
        },
      };
    };
  },
});

function chartKindLabel(source: string): string {
  const spec = parseChartSpec(source);
  return spec ? spec.type : 'chart';
}

function parseChartSpec(source: string): EpdocChartSpec | null {
  try {
    const value = JSON.parse(source) as Partial<EpdocChartSpec>;
    if (!isChartKind(value.type)) return null;
    return {
      type: value.type,
      title: typeof value.title === 'string' ? value.title : undefined,
      x: normalizeAxis(value.x),
      y: normalizeAxis(value.y),
      points: Array.isArray(value.points) ? value.points.map(normalizePoint).filter(isPoint) : undefined,
      bars: Array.isArray(value.bars) ? value.bars.map(normalizeBar).filter(isBar) : undefined,
    };
  } catch {
    return null;
  }
}

function isChartKind(value: unknown): value is ChartKind {
  return value === 'scatter' || value === 'bar' || value === 'line';
}

function normalizeAxis(axis: unknown): ChartAxis | undefined {
  if (typeof axis !== 'object' || axis === null) return undefined;
  const candidate = axis as Record<string, unknown>;
  return {
    label: typeof candidate.label === 'string' ? candidate.label : undefined,
    min: typeof candidate.min === 'number' && Number.isFinite(candidate.min) ? candidate.min : undefined,
    max: typeof candidate.max === 'number' && Number.isFinite(candidate.max) ? candidate.max : undefined,
  };
}

function normalizePoint(value: unknown): ChartPoint | null {
  if (typeof value !== 'object' || value === null) return null;
  const candidate = value as Record<string, unknown>;
  if (typeof candidate.x !== 'number' || typeof candidate.y !== 'number') return null;
  if (!Number.isFinite(candidate.x) || !Number.isFinite(candidate.y)) return null;
  return {
    x: candidate.x,
    y: candidate.y,
    label: typeof candidate.label === 'string' ? candidate.label : undefined,
    category: typeof candidate.category === 'string' ? candidate.category : undefined,
  };
}

function normalizeBar(value: unknown): ChartBar | null {
  if (typeof value !== 'object' || value === null) return null;
  const candidate = value as Record<string, unknown>;
  if (typeof candidate.label !== 'string' || typeof candidate.value !== 'number') return null;
  if (!Number.isFinite(candidate.value)) return null;
  return { label: candidate.label, value: candidate.value };
}

function isPoint(value: ChartPoint | null): value is ChartPoint {
  return value !== null;
}

function isBar(value: ChartBar | null): value is ChartBar {
  return value !== null;
}

function renderChartInto(container: HTMLElement, source: string): void {
  container.replaceChildren();
  const spec = parseChartSpec(source);
  if (!spec) {
    container.appendChild(errorBox('Invalid chart JSON'));
    return;
  }

  const svg = createSvg(720, 360);
  const title = spec.title ?? `${spec.type[0].toUpperCase()}${spec.type.slice(1)} chart`;
  appendText(svg, 32, 34, title, 'epdoc-chart-svg-title');

  if (spec.type === 'bar') {
    renderBarChart(svg, spec);
  } else {
    renderPointChart(svg, spec);
  }

  container.appendChild(svg);
}

function renderPointChart(svg: SVGSVGElement, spec: EpdocChartSpec): void {
  const points = (spec.points ?? []).slice(0, 48);
  if (points.length === 0) {
    appendEmptyState(svg, 'Add points to render this chart');
    return;
  }

  const frame = chartFrame();
  const domainX = domain(points.map(point => point.x), spec.x);
  const domainY = domain(points.map(point => point.y), spec.y);
  appendAxes(svg, frame, spec.x?.label ?? 'x', spec.y?.label ?? 'y');

  if (spec.type === 'line') {
    const path = document.createElementNS(svg.namespaceURI, 'path');
    const sorted = [...points].sort((a, b) => a.x - b.x);
    path.setAttribute('class', 'epdoc-chart-line');
    path.setAttribute('d', sorted.map((point, index) => {
      const x = scale(point.x, domainX, frame.x, frame.x + frame.width);
      const y = scale(point.y, domainY, frame.y + frame.height, frame.y);
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)}`;
    }).join(' '));
    svg.appendChild(path);
  }

  for (const point of points) {
    const x = scale(point.x, domainX, frame.x, frame.x + frame.width);
    const y = scale(point.y, domainY, frame.y + frame.height, frame.y);
    const dot = document.createElementNS(svg.namespaceURI, 'circle');
    dot.setAttribute('class', `epdoc-chart-point epdoc-chart-category-${categoryIndex(point.category)}`);
    dot.setAttribute('cx', x.toFixed(2));
    dot.setAttribute('cy', y.toFixed(2));
    dot.setAttribute('r', spec.type === 'line' ? '4.5' : '6');
    if (point.label) dot.appendChild(svgTitle(point.label));
    svg.appendChild(dot);
  }
}

function renderBarChart(svg: SVGSVGElement, spec: EpdocChartSpec): void {
  const bars = (spec.bars ?? []).slice(0, 12);
  if (bars.length === 0) {
    appendEmptyState(svg, 'Add bars to render this chart');
    return;
  }

  const frame = chartFrame();
  const yDomain = domain(bars.map(bar => bar.value), spec.y);
  appendAxes(svg, frame, spec.x?.label ?? 'category', spec.y?.label ?? 'value');

  const gap = 10;
  const width = Math.max(8, (frame.width - gap * (bars.length - 1)) / bars.length);
  bars.forEach((bar, index) => {
    const x = frame.x + index * (width + gap);
    const y = scale(bar.value, yDomain, frame.y + frame.height, frame.y);
    const height = frame.y + frame.height - y;
    const rect = document.createElementNS(svg.namespaceURI, 'rect');
    rect.setAttribute('class', `epdoc-chart-bar epdoc-chart-category-${index % 5}`);
    rect.setAttribute('x', x.toFixed(2));
    rect.setAttribute('y', y.toFixed(2));
    rect.setAttribute('width', width.toFixed(2));
    rect.setAttribute('height', Math.max(0, height).toFixed(2));
    rect.appendChild(svgTitle(`${bar.label}: ${bar.value}`));
    svg.appendChild(rect);

    appendText(svg, x + width / 2, frame.y + frame.height + 22, truncate(bar.label, 12), 'epdoc-chart-axis-label', 'middle');
  });
}

function createSvg(width: number, height: number): SVGSVGElement {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label', 'Epistemos research chart');
  return svg;
}

function chartFrame() {
  return { x: 70, y: 62, width: 604, height: 238 };
}

function appendAxes(svg: SVGSVGElement, frame: { x: number; y: number; width: number; height: number }, xLabel: string, yLabel: string): void {
  const axis = document.createElementNS(svg.namespaceURI, 'path');
  axis.setAttribute('class', 'epdoc-chart-axis');
  axis.setAttribute('d', `M ${frame.x} ${frame.y} V ${frame.y + frame.height} H ${frame.x + frame.width}`);
  svg.appendChild(axis);

  for (let index = 0; index <= 4; index += 1) {
    const y = frame.y + (frame.height / 4) * index;
    const line = document.createElementNS(svg.namespaceURI, 'line');
    line.setAttribute('class', 'epdoc-chart-grid');
    line.setAttribute('x1', String(frame.x));
    line.setAttribute('x2', String(frame.x + frame.width));
    line.setAttribute('y1', String(y));
    line.setAttribute('y2', String(y));
    svg.appendChild(line);
  }

  appendText(svg, frame.x + frame.width / 2, 344, xLabel, 'epdoc-chart-axis-label', 'middle');
  appendText(svg, 20, frame.y + frame.height / 2, yLabel, 'epdoc-chart-axis-label epdoc-chart-axis-label-y', 'middle');
}

function appendEmptyState(svg: SVGSVGElement, message: string): void {
  appendText(svg, 360, 190, message, 'epdoc-chart-empty', 'middle');
}

function appendText(svg: SVGSVGElement, x: number, y: number, value: string, className: string, anchor = 'start'): void {
  const text = document.createElementNS(svg.namespaceURI, 'text');
  text.setAttribute('x', String(x));
  text.setAttribute('y', String(y));
  text.setAttribute('class', className);
  text.setAttribute('text-anchor', anchor);
  text.textContent = value;
  svg.appendChild(text);
}

function svgTitle(value: string): SVGTitleElement {
  const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
  title.textContent = value;
  return title;
}

function errorBox(message: string): HTMLElement {
  const error = document.createElement('div');
  error.classList.add('epdoc-chart-error');
  error.textContent = message;
  return error;
}

function domain(values: number[], axis: ChartAxis | undefined): [number, number] {
  const fallback: [number, number] = [0, 1];
  if (values.length === 0) return fallback;
  let min = axis?.min ?? Math.min(...values);
  let max = axis?.max ?? Math.max(...values);
  if (!Number.isFinite(min) || !Number.isFinite(max)) return fallback;
  if (min === max) {
    min -= 1;
    max += 1;
  }
  return [min, max];
}

function scale(value: number, input: [number, number], outputMin: number, outputMax: number): number {
  const [inputMin, inputMax] = input;
  const ratio = (value - inputMin) / (inputMax - inputMin);
  return outputMin + ratio * (outputMax - outputMin);
}

function categoryIndex(category: string | undefined): number {
  if (!category) return 0;
  let hash = 0;
  for (let index = 0; index < category.length; index += 1) {
    hash = ((hash << 5) - hash + category.charCodeAt(index)) | 0;
  }
  return Math.abs(hash) % 5;
}

function truncate(value: string, max: number): string {
  return value.length <= max ? value : `${value.slice(0, max - 1)}…`;
}
