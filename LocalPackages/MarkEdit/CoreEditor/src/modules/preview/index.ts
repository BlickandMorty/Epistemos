import { getClientRect } from '../../common/utils';
import { globalState } from '../../common/store';

export enum PreviewType {
  mermaid = 'mermaid',
  katex = 'katex',
  table = 'table',
}

const embeddedPreviewClassName = 'cm-md-embeddedPreview';

/**
 * Invokes native methods to show code preview.
 */
export function showPreview(event: MouseEvent) {
  const target = event.target as HTMLSpanElement;
  if (!(target instanceof HTMLSpanElement)) {
    return;
  }

  const code = target.dataset.code;
  if (code === undefined) {
    return;
  }

  const pos = target.dataset.pos;
  if (pos === undefined) {
    return;
  }

  const type = target.dataset.type as PreviewType;
  if (window.config.epistemosMode === 'markdown') {
    showEmbeddedPreview(target, code, type);
    cancelDefaultEvent(event);
    return;
  }

  const rect = window.editor.coordsAtPos(parseInt(pos));
  if (rect === null) {
    return;
  }

  window.nativeModules.preview.show({ code, type, rect: getClientRect(rect) });

  cancelDefaultEvent(event);
}

function showEmbeddedPreview(anchor: HTMLElement, code: string, type: PreviewType) {
  document.querySelector(`.${embeddedPreviewClassName}`)?.remove();

  const preview = document.createElement('aside');
  preview.className = 'cm-md-embeddedPreview';
  preview.setAttribute('role', 'dialog');
  preview.setAttribute('aria-label', `${previewTitle(type)} preview`);
  applyEmbeddedPreviewTheme(preview);

  const header = document.createElement('header');
  header.className = 'cm-md-embeddedPreviewHeader';

  const title = document.createElement('span');
  title.textContent = previewTitle(type);
  header.appendChild(title);

  const closeButton = document.createElement('button');
  closeButton.type = 'button';
  closeButton.className = 'cm-md-embeddedPreviewClose';
  closeButton.setAttribute('aria-label', 'Close preview');
  closeButton.textContent = '×';
  header.appendChild(closeButton);
  preview.appendChild(header);

  const body = document.createElement('div');
  body.className = 'cm-md-embeddedPreviewBody';
  body.appendChild(type === PreviewType.table ? renderTablePreview(code) : renderFallbackPreview(code, type));
  preview.appendChild(body);

  document.body.appendChild(preview);
  placeEmbeddedPreview(preview, anchor);

  const close = () => {
    preview.remove();
    document.removeEventListener('keydown', closeOnEscape);
    document.removeEventListener('mousedown', closeOnOutsideClick, true);
  };
  const closeOnEscape = (keyboardEvent: KeyboardEvent) => {
    if (keyboardEvent.key === 'Escape') {
      close();
    }
  };
  const closeOnOutsideClick = (mouseEvent: MouseEvent) => {
    const nextTarget = mouseEvent.target;
    if (nextTarget instanceof Node && !preview.contains(nextTarget) && nextTarget !== anchor) {
      close();
    }
  };

  closeButton.addEventListener('click', close);
  document.addEventListener('keydown', closeOnEscape);
  setTimeout(() => document.addEventListener('mousedown', closeOnOutsideClick, true), 0);
}

function placeEmbeddedPreview(preview: HTMLElement, anchor: HTMLElement) {
  const anchorRect = anchor.getBoundingClientRect();
  const width = Math.min(520, Math.max(280, window.innerWidth - 32));
  preview.style.width = `${width}px`;

  const previewRect = preview.getBoundingClientRect();
  const left = clamp(anchorRect.left, 16, window.innerWidth - previewRect.width - 16);
  const belowTop = anchorRect.bottom + 10;
  const top = belowTop + previewRect.height <= window.innerHeight - 16
    ? belowTop
    : clamp(anchorRect.top - previewRect.height - 10, 16, window.innerHeight - previewRect.height - 16);

  preview.style.left = `${left}px`;
  preview.style.top = `${top}px`;
}

function renderTablePreview(code: string): HTMLElement {
  const rows = code
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.includes('|'));
  const parsedRows = rows
    .map(parseTableRow)
    .filter((row): row is string[] => row.length > 0);
  const bodyRows = parsedRows.filter(row => !isTableSeparatorRow(row));

  if (bodyRows.length === 0) {
    return renderFallbackPreview(code, PreviewType.table);
  }

  const table = document.createElement('table');
  const headerRow = bodyRows[0];
  const dataRows = bodyRows.slice(1);
  const thead = document.createElement('thead');
  thead.appendChild(renderTableDomRow(headerRow, 'th'));
  table.appendChild(thead);

  if (dataRows.length > 0) {
    const tbody = document.createElement('tbody');
    dataRows.forEach(row => tbody.appendChild(renderTableDomRow(row, 'td')));
    table.appendChild(tbody);
  }

  return table;
}

function renderFallbackPreview(code: string, type: PreviewType): HTMLElement {
  const fallback = document.createElement('pre');
  fallback.className = 'cm-md-embeddedPreviewFallback';
  fallback.textContent = code.trim() || `${previewTitle(type)} preview is empty.`;
  return fallback;
}

function applyEmbeddedPreviewTheme(preview: HTMLElement) {
  const colors = globalState.colors;
  if (colors === undefined) {
    return;
  }

  preview.style.background = colors.background;
  preview.style.color = colors.text;
  preview.style.borderColor = colorWithAlpha(colors.text, '2e');
}

function colorWithAlpha(color: string, alpha: string): string {
  return /^#[0-9a-f]{6}$/i.test(color) ? `${color}${alpha}` : color;
}

function renderTableDomRow(cells: string[], cellTagName: 'th' | 'td'): HTMLTableRowElement {
  const rowElement = document.createElement('tr');
  cells.forEach(cell => {
    const cellElement = document.createElement(cellTagName);
    cellElement.textContent = cell;
    rowElement.appendChild(cellElement);
  });
  return rowElement;
}

function parseTableRow(row: string): string[] {
  return row
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map(cell => cell.trim());
}

function isTableSeparatorRow(row: string[]): boolean {
  return row.every(cell => /^:?-{3,}:?$/.test(cell));
}

function previewTitle(type: PreviewType): string {
  switch (type) {
    case PreviewType.table:
      return 'Table';
    case PreviewType.katex:
      return 'Math';
    case PreviewType.mermaid:
      return 'Diagram';
    default:
      return 'Preview';
  }
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(Math.max(value, minimum), maximum);
}

export function cancelDefaultEvent(event: MouseEvent) {
  const target = event.target as HTMLElement;
  if (target.className.includes('cm-md-previewButton')) {
    event.preventDefault();
    event.stopPropagation();
  }
}
