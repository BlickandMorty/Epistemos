import { ChangeSet } from 'prosemirror-changeset';
import type { Node as PMNode } from '@tiptap/pm/model';
import { Fragment } from '@tiptap/pm/model';
import type { StepMap } from '@tiptap/pm/transform';
import { splitFrontmatter } from './tiers';

export interface MarkdownBlockSpan {
  readonly index: number;
  readonly codeUnitFrom: number;
  readonly codeUnitTo: number;
  readonly byteFrom: number;
  readonly byteTo: number;
  readonly markdown: string;
}

export interface WritebackRegion {
  /** UTF-8 byte range in the on-disk buffer to replace. */
  readonly from: number;
  readonly to: number;
  readonly byteFrom: number;
  readonly byteTo: number;
  /** JavaScript string range for applying the splice in memory. */
  readonly codeUnitFrom: number;
  readonly codeUnitTo: number;
  /** ProseMirror changedRange in new-document coordinates. */
  readonly changedFrom: number;
  readonly changedTo: number;
  /** Top-level block ordinals covered by this writeback. */
  readonly blockIndexFrom: number;
  readonly blockIndexTo: number;
  /** Reserialized Markdown for exactly the touched block range. */
  readonly blockMarkdown: string;
}

export interface MinimalWritebackResult {
  readonly region: WritebackRegion;
  readonly nextMarkdown: string;
}

export interface MinimalWritebackInput {
  readonly oldSet: ChangeSet;
  readonly newSet: ChangeSet;
  readonly maps: readonly StepMap[];
  readonly oldMarkdown: string;
  readonly newDoc: PMNode;
  readonly serializeDoc: (doc: PMNode) => string;
}

export function minimalWriteback(input: MinimalWritebackInput): MinimalWritebackResult | null {
  const changedRange = input.oldSet.changedRange(input.newSet, input.maps);
  if (!changedRange) return null;

  const blockRange = topLevelBlockRange(input.newDoc, changedRange.from, changedRange.to);
  if (!blockRange) return null;

  const spans = indexMarkdownBlocks(input.oldMarkdown);
  if (spans.length !== input.newDoc.childCount) return null;

  const firstSpan = spans[blockRange.fromIndex];
  const lastSpan = spans[blockRange.toIndex];
  if (!firstSpan || !lastSpan) return null;

  const blockDoc = docFromTopLevelRange(input.newDoc, blockRange.fromIndex, blockRange.toIndex);
  const blockMarkdown = normalizeReplacementLineEndings(
    input.serializeDoc(blockDoc).trimEnd(),
    input.oldMarkdown,
  );
  const region: WritebackRegion = {
    from: firstSpan.byteFrom,
    to: lastSpan.byteTo,
    byteFrom: firstSpan.byteFrom,
    byteTo: lastSpan.byteTo,
    codeUnitFrom: firstSpan.codeUnitFrom,
    codeUnitTo: lastSpan.codeUnitTo,
    changedFrom: changedRange.from,
    changedTo: changedRange.to,
    blockIndexFrom: blockRange.fromIndex,
    blockIndexTo: blockRange.toIndex,
    blockMarkdown,
  };

  return {
    region,
    nextMarkdown: applyWritebackRegion(input.oldMarkdown, region),
  };
}

export function applyWritebackRegion(markdown: string, region: WritebackRegion): string {
  return `${markdown.slice(0, region.codeUnitFrom)}${region.blockMarkdown}${markdown.slice(region.codeUnitTo)}`;
}

export function seedChangeSet(doc: PMNode): ChangeSet {
  return ChangeSet.create(doc);
}

export function indexMarkdownBlocks(markdown: string): MarkdownBlockSpan[] {
  const split = splitFrontmatter(markdown);
  const bodyOffset = split.frontmatter.length;
  const lines = lineSpans(markdown.slice(bodyOffset), bodyOffset);
  const blocks: MarkdownBlockSpan[] = [];
  let lineIndex = 0;

  while (lineIndex < lines.length) {
    while (lineIndex < lines.length && isBlank(lines[lineIndex].content)) {
      lineIndex += 1;
    }
    if (lineIndex >= lines.length) break;

    const start = lineIndex;
    const endExclusive = scanBlockEnd(lines, lineIndex);
    const first = lines[start];
    const last = lines[endExclusive - 1];
    blocks.push({
      index: blocks.length,
      codeUnitFrom: first.start,
      codeUnitTo: last.contentEnd,
      byteFrom: utf8ByteLength(markdown.slice(0, first.start)),
      byteTo: utf8ByteLength(markdown.slice(0, last.contentEnd)),
      markdown: markdown.slice(first.start, last.contentEnd),
    });
    lineIndex = endExclusive;
  }

  return blocks;
}

function topLevelBlockRange(
  doc: PMNode,
  changedFrom: number,
  changedTo: number,
): { fromIndex: number; toIndex: number } | null {
  let position = 0;
  let fromIndex: number | null = null;
  let toIndex: number | null = null;

  for (let index = 0; index < doc.childCount; index += 1) {
    const child = doc.child(index);
    const childFrom = position;
    const childTo = position + child.nodeSize;
    const overlaps = changedFrom < childTo && changedTo > childFrom;
    const emptyInside = changedFrom === changedTo && changedFrom >= childFrom && changedFrom <= childTo;
    if (overlaps || emptyInside) {
      fromIndex ??= index;
      toIndex = index;
    }
    position = childTo;
  }

  if (fromIndex === null || toIndex === null) return null;
  return { fromIndex, toIndex };
}

function docFromTopLevelRange(doc: PMNode, fromIndex: number, toIndex: number): PMNode {
  const nodes: PMNode[] = [];
  for (let index = fromIndex; index <= toIndex; index += 1) {
    nodes.push(doc.child(index));
  }
  return doc.type.create(doc.attrs, Fragment.fromArray(nodes));
}

interface LineSpan {
  readonly start: number;
  readonly end: number;
  readonly contentEnd: number;
  readonly content: string;
}

function lineSpans(source: string, offset: number): LineSpan[] {
  const spans: LineSpan[] = [];
  let start = 0;
  while (start < source.length) {
    let end = start;
    while (end < source.length && source[end] !== '\n' && source[end] !== '\r') {
      end += 1;
    }
    let lineEnd = end;
    if (end < source.length) {
      if (source[end] === '\r' && source[end + 1] === '\n') {
        lineEnd = end + 2;
      } else {
        lineEnd = end + 1;
      }
    }
    spans.push({
      start: offset + start,
      end: offset + lineEnd,
      contentEnd: offset + end,
      content: source.slice(start, end),
    });
    start = lineEnd;
  }
  return spans;
}

function scanBlockEnd(lines: readonly LineSpan[], start: number): number {
  const line = lines[start].content;
  const trimmed = line.trim();
  const fence = fenceMarker(trimmed);
  if (fence) return scanFencedBlockEnd(lines, start, fence);
  if (isATXHeading(trimmed) || isHorizontalRule(trimmed)) return start + 1;
  if (looksLikeTableHeader(lines, start)) return scanContiguous(lines, start, line => line.includes('|'));
  if (isListLine(line)) return scanContiguous(lines, start, line => isListLine(line) || isIndentedContinuation(line));
  if (trimmed.startsWith('>')) return scanContiguous(lines, start, line => line.trim().startsWith('>'));
  return scanContiguous(lines, start, line => !isBlank(line));
}

function scanFencedBlockEnd(lines: readonly LineSpan[], start: number, fence: string): number {
  for (let index = start + 1; index < lines.length; index += 1) {
    if (lines[index].content.trim().startsWith(fence)) {
      return index + 1;
    }
  }
  return lines.length;
}

function scanContiguous(
  lines: readonly LineSpan[],
  start: number,
  accept: (line: string) => boolean,
): number {
  let index = start;
  while (index < lines.length && !isBlank(lines[index].content) && accept(lines[index].content)) {
    index += 1;
  }
  return Math.max(start + 1, index);
}

function fenceMarker(trimmed: string): string | null {
  if (trimmed.startsWith('```')) return '```';
  if (trimmed.startsWith('~~~')) return '~~~';
  return null;
}

function isATXHeading(trimmed: string): boolean {
  return /^#{1,6}(?:\s|$)/.test(trimmed);
}

function isHorizontalRule(trimmed: string): boolean {
  return /^(?:-{3,}|\*{3,}|_{3,})$/.test(trimmed.replace(/\s+/g, ''));
}

function looksLikeTableHeader(lines: readonly LineSpan[], start: number): boolean {
  return lines[start].content.includes('|')
    && start + 1 < lines.length
    && /^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(lines[start + 1].content.trim());
}

function isListLine(line: string): boolean {
  return /^\s*(?:[-*+]|\d+[.)])\s+/.test(line);
}

function isIndentedContinuation(line: string): boolean {
  return /^(?: {2,}|\t)\S/.test(line);
}

function isBlank(line: string): boolean {
  return line.trim().length === 0;
}

function normalizeReplacementLineEndings(replacement: string, originalBlock: string): string {
  if (originalBlock.includes('\r\n')) return replacement.replace(/\n/g, '\r\n');
  if (originalBlock.includes('\r')) return replacement.replace(/\n/g, '\r');
  return replacement;
}

function utf8ByteLength(value: string): number {
  return new TextEncoder().encode(value).byteLength;
}
