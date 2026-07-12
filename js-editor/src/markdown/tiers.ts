import type { JSONContent } from '@tiptap/core';

export enum SerializerTier {
  A = 'canonical-lossless',
  B = 'custom-extension',
  C = 'byte-preserving-opaque',
}

export type LensId = 'prose' | 'document' | 'preview' | 'source';

export enum LensFidelityState {
  Rendered = 'rendered',
  Degraded = 'degraded',
  Invisible = 'invisible',
}

export interface TierFeature {
  readonly type: string;
  readonly tier: SerializerTier;
  readonly count: number;
}

export interface LensFidelityDescriptor {
  readonly type: string;
  readonly label: string;
  readonly tier: SerializerTier;
  readonly lens: Record<LensId, LensFidelityState>;
  readonly exportKind: 'markdown' | 'raw' | 'image' | 'csv' | 'xlsx' | 'transcript';
}

export interface TierSerializer<NodeLike extends { type?: string } = JSONContent> {
  readonly tier: SerializerTier;
  canHandle(node: NodeLike): boolean;
  serialize(node: NodeLike): string;
  parse(markdown: string): NodeLike;
}

export interface MarkdownRoundTripAdapter<DocumentLike = unknown> {
  parse(markdown: string): DocumentLike;
  serialize(document: DocumentLike): string;
}

export interface RoundTripResult {
  tier: SerializerTier;
  ok: boolean;
  bytesEqual: boolean;
  frontmatterPreserved: boolean;
  normalized: string;
  features: TierFeature[];
  passes: number;
  detail?: string;
}

export const LENS_FIDELITY_REGISTRY: readonly LensFidelityDescriptor[] = [
  tierB('table', 'Table', 'csv', { prose: 'degraded', source: 'degraded' }),
  tierB('taskList', 'Task list', 'markdown', { prose: 'degraded', source: 'degraded' }),
  tierB('inlineMath', 'Inline math', 'markdown', { prose: 'degraded', source: 'degraded' }),
  tierB('blockMath', 'Block math', 'image', { prose: 'invisible', source: 'degraded' }),
  tierB('callout', 'Callout', 'markdown', { prose: 'degraded', source: 'degraded' }),
  tierB('wikilink', 'Wikilink', 'markdown', { prose: 'degraded', source: 'degraded' }),
  tierB('highlight', 'Highlight', 'markdown', { prose: 'degraded', source: 'degraded' }),
  tierB('epdocChart', 'Chart', 'image', { prose: 'invisible', source: 'degraded' }),
  tierB('mermaid', 'Legacy diagram', 'image', { prose: 'invisible', source: 'degraded' }),
  tierB('epdocImage', 'Package image', 'raw', { prose: 'degraded', source: 'degraded' }),
  tierB('datasetEmbed', 'Dataset embed', 'xlsx', { prose: 'invisible', source: 'degraded' }),
  tierB('notebookSheetTab', 'Sheet tab', 'xlsx', { prose: 'invisible', preview: 'degraded', source: 'degraded' }),
  tierB('notebookChatTab', 'Chat tab', 'transcript', { prose: 'invisible', preview: 'degraded', source: 'degraded' }),
  {
    type: 'notebookUnknownTab',
    label: 'Unknown notebook tab',
    tier: SerializerTier.C,
    exportKind: 'raw',
    lens: {
      prose: LensFidelityState.Invisible,
      document: LensFidelityState.Degraded,
      preview: LensFidelityState.Degraded,
      source: LensFidelityState.Degraded,
    },
  },
  {
    type: 'opaqueQuarantine',
    label: 'Quarantined block',
    tier: SerializerTier.C,
    exportKind: 'raw',
    lens: {
      prose: LensFidelityState.Invisible,
      document: LensFidelityState.Degraded,
      preview: LensFidelityState.Degraded,
      source: LensFidelityState.Degraded,
    },
  },
];

const TIER_A_NODE_TYPES = new Set([
  'doc',
  'text',
  'paragraph',
  'heading',
  'bulletList',
  'orderedList',
  'listItem',
  'codeBlock',
  'blockquote',
  'horizontalRule',
  'hardBreak',
  'image',
]);

const TIER_B_NODE_TYPES = new Set([
  'table',
  'tableRow',
  'tableCell',
  'tableHeader',
  'taskList',
  'taskItem',
  'inlineMath',
  'blockMath',
  'callout',
  'epdocChart',
  'mermaid',
  'epdocImage',
  'footnote',
  'footnoteReference',
  'datasetEmbed',
]);

const TIER_A_MARK_TYPES = new Set(['bold', 'italic', 'strike', 'code', 'link']);
const TIER_B_MARK_TYPES = new Set(['highlight', 'insertion', 'deletion', 'modification']);
const OPAQUE_BLOCK_RE = /<!--\s*epistemos-quarantine:start\b[\s\S]*?<!--\s*epistemos-quarantine:end\s*-->/i;
const NOTEBOOK_FENCE_RE = /(?:^|\n)(?:```|~~~)epistemos-notebook\b[\s\S]*?(?:\n```|\n~~~)/gi;
const NOTEBOOK_TAB_LINE_RE = /^\s*tab:\s+(.+)$/gim;
const EPISTEMOS_REF_LINE_RE = /^.*epistemos-ref.*$/gim;
const DATASET_INLINE_ROW_KEYS = new Set(['rows', 'rowdata', 'records', 'values', 'cells', 'csv', 'tsv']);

export function pickTier<NodeLike extends { type?: string }>(
  node: NodeLike,
  serializers: readonly TierSerializer<NodeLike>[],
): TierSerializer<NodeLike> {
  const owner = serializers.find(serializer => serializer.tier !== SerializerTier.C && serializer.canHandle(node));
  if (owner) return owner;
  const quarantine = serializers.find(serializer => serializer.tier === SerializerTier.C);
  if (!quarantine) throw new Error('no Tier C quarantine serializer registered');
  return quarantine;
}

export function roundTrip<DocumentLike>(
  markdown: string,
  adapter: MarkdownRoundTripAdapter<DocumentLike>,
): RoundTripResult {
  const datasetRowPayloads = datasetEmbedRowPayloadLines(markdown);
  if (datasetRowPayloads.length > 0) {
    return {
      tier: SerializerTier.C,
      ok: false,
      bytesEqual: true,
      frontmatterPreserved: true,
      normalized: markdown,
      features: mergeFeatures([
        ...classifyRawMarkdown(markdown),
        { type: 'datasetInlineRows', tier: SerializerTier.C, count: datasetRowPayloads.length },
      ]),
      passes: 0,
      detail: 'dataset embeds must reference dataset artifacts, not inline row data',
    };
  }

  if (OPAQUE_BLOCK_RE.test(markdown)) {
    return {
      tier: SerializerTier.C,
      ok: true,
      bytesEqual: true,
      frontmatterPreserved: true,
      normalized: markdown,
      features: [{ type: 'opaqueQuarantine', tier: SerializerTier.C, count: 1 }],
      passes: 0,
    };
  }

  const split = splitFrontmatter(markdown);
  const parsed = adapter.parse(split.body);
  const canonical = canonicalizeMarkdownBody(adapter.serialize(parsed), adapter);
  const normalized = `${split.frontmatter}${canonical.body}`;
  const features = mergeFeatures([...classifyDocument(parsed), ...classifyRawMarkdown(markdown)]);
  const tier = highestTier(features);
  const ok = canonical.stable && normalized.startsWith(split.frontmatter);
  return {
    tier,
    ok,
    bytesEqual: normalized === markdown,
    frontmatterPreserved: normalized.startsWith(split.frontmatter),
    normalized,
    features,
    passes: canonical.passes,
    ...(ok ? {} : { detail: 'markdown parse/serialize did not reach a fixed point within 4 passes' }),
  };
}

export function datasetEmbedsContainNoRowData(markdown: string): boolean {
  return datasetEmbedRowPayloadLines(markdown).length === 0;
}

function canonicalizeMarkdownBody<DocumentLike>(
  firstBody: string,
  adapter: MarkdownRoundTripAdapter<DocumentLike>,
): { body: string; stable: boolean; passes: number } {
  let previous = normalizeKnownRendererDrift(firstBody);
  for (let pass = 1; pass <= 4; pass += 1) {
    const next = normalizeKnownRendererDrift(adapter.serialize(adapter.parse(previous)));
    if (next === previous) {
      return { body: next, stable: true, passes: pass };
    }
    previous = next;
  }
  return { body: previous, stable: false, passes: 4 };
}

function normalizeKnownRendererDrift(markdown: string): string {
  // @tiptap/markdown + mathematics can otherwise add one space before inline
  // code containing "$$" on every parse/serialize pass.
  return markdown.replace(/ {2,}(`\$\$`)/g, ' $1');
}

export function splitFrontmatter(source: string): { frontmatter: string; body: string } {
  const open = source.match(/^---[ \t]*(\r?\n)/);
  if (!open) return { frontmatter: '', body: source };
  const newline = open[1];
  const rest = source.slice(open[0].length);
  const close = new RegExp(`(?:^|${escapeRegExp(newline)})---[ \\t]*(?:${escapeRegExp(newline)}|$)`);
  const match = close.exec(rest);
  if (!match) return { frontmatter: '', body: source };
  const closeEnd = open[0].length + match.index + match[0].length;
  return {
    frontmatter: source.slice(0, closeEnd),
    body: source.slice(closeEnd),
  };
}

export function classifyDocument(document: unknown): TierFeature[] {
  const counts = new Map<string, { tier: SerializerTier; count: number }>();
  visitJSON(document, counts);
  return sortedFeatures(counts);
}

function classifyRawMarkdown(markdown: string): TierFeature[] {
  const counts = new Map<string, { tier: SerializerTier; count: number }>();
  for (const match of markdown.matchAll(NOTEBOOK_FENCE_RE)) {
    const block = match[0];
    for (const line of block.matchAll(NOTEBOOK_TAB_LINE_RE)) {
      const attrs = parseKeyValueAttributes(line[1] ?? '');
      const type = notebookFeatureType(attrs.type);
      recordFeature(counts, type, type === 'notebookUnknownTab' ? SerializerTier.C : SerializerTier.B);
    }
  }

  for (const line of markdown.matchAll(EPISTEMOS_REF_LINE_RE)) {
    const attrs = parseKeyValueAttributes(line[0] ?? '');
    const type = notebookFeatureType(attrs.type);
    recordFeature(
      counts,
      type === 'notebookSheetTab' ? 'datasetEmbed' : type,
      type === 'notebookUnknownTab' ? SerializerTier.C : SerializerTier.B,
    );
  }

  return sortedFeatures(counts);
}

function datasetEmbedRowPayloadLines(markdown: string): string[] {
  const lines: string[] = [];
  for (const match of markdown.matchAll(NOTEBOOK_FENCE_RE)) {
    const block = match[0];
    for (const line of block.matchAll(NOTEBOOK_TAB_LINE_RE)) {
      const attrs = parseKeyValueAttributes(line[1] ?? '');
      if (isDatasetReference(attrs) && hasInlineDatasetRows(attrs)) {
        lines.push(line[0] ?? '');
      }
    }
  }

  for (const line of markdown.matchAll(EPISTEMOS_REF_LINE_RE)) {
    const rawLine = line[0] ?? '';
    const attrs = parseKeyValueAttributes(rawLine);
    if (isDatasetReference(attrs) && hasInlineDatasetRows(attrs)) {
      lines.push(rawLine);
    }
  }

  return lines;
}

function isDatasetReference(attrs: Record<string, string>): boolean {
  const type = attrs.type?.trim().toLowerCase();
  if (type === 'sheet' || type === 'dataset') return true;
  const reference = attrs.ref ?? attrs.reference ?? attrs.datasetid ?? '';
  return reference.trim().toLowerCase().startsWith('dataset:')
    || reference.trim().toLowerCase().endsWith('.dataset.md');
}

function hasInlineDatasetRows(attrs: Record<string, string>): boolean {
  return Object.keys(attrs).some((key) => {
    const normalized = key.replace(/[-_]/g, '').toLowerCase();
    return DATASET_INLINE_ROW_KEYS.has(normalized);
  });
}

function sortedFeatures(counts: Map<string, { tier: SerializerTier; count: number }>): TierFeature[] {
  return [...counts.entries()]
    .map(([type, value]) => ({ type, tier: value.tier, count: value.count }))
    .sort((a, b) => a.type.localeCompare(b.type));
}

function mergeFeatures(features: readonly TierFeature[]): TierFeature[] {
  const counts = new Map<string, { tier: SerializerTier; count: number }>();
  for (const feature of features) {
    const previous = counts.get(feature.type);
    counts.set(feature.type, {
      tier: previous ? maxTier(previous.tier, feature.tier) : feature.tier,
      count: (previous?.count ?? 0) + feature.count,
    });
  }
  return sortedFeatures(counts);
}

export function disclosureItemsForLens(
  document: unknown,
  lens: LensId,
): Array<TierFeature & { fidelity: LensFidelityState; label: string; exportKind: LensFidelityDescriptor['exportKind'] }> {
  const features = classifyDocument(document);
  return features.flatMap((feature) => {
    const descriptor = LENS_FIDELITY_REGISTRY.find(candidate => candidate.type === feature.type);
    if (!descriptor) return [];
    const fidelity = descriptor.lens[lens];
    if (fidelity === LensFidelityState.Rendered) return [];
    return [{
      ...feature,
      fidelity,
      label: descriptor.label,
      exportKind: descriptor.exportKind,
    }];
  });
}

function visitJSON(value: unknown, counts: Map<string, { tier: SerializerTier; count: number }>): void {
  if (typeof value !== 'object' || value === null) return;
  const node = value as JSONContent;
  if (typeof node.type === 'string') {
    recordFeature(counts, canonicalFeatureType(node), tierForNode(node));
  }
  if (Array.isArray(node.marks)) {
    for (const mark of node.marks) {
      if (typeof mark.type === 'string') {
        const type = mark.type === 'link' && isWikiHref(mark.attrs?.href) ? 'wikilink' : mark.type;
        recordFeature(counts, type, tierForMark(type));
      }
    }
  }
  if (Array.isArray(node.content)) {
    for (const child of node.content) visitJSON(child, counts);
  }
}

function recordFeature(
  counts: Map<string, { tier: SerializerTier; count: number }>,
  type: string,
  tier: SerializerTier,
): void {
  if (tier === SerializerTier.A) return;
  const previous = counts.get(type);
  counts.set(type, {
    tier: previous ? maxTier(previous.tier, tier) : tier,
    count: (previous?.count ?? 0) + 1,
  });
}

function canonicalFeatureType(node: JSONContent): string {
  if (node.type === 'epdocImage') return 'epdocImage';
  return node.type ?? 'unknown';
}

function tierForNode(node: JSONContent): SerializerTier {
  if (!node.type) return SerializerTier.C;
  if (TIER_B_NODE_TYPES.has(node.type)) return SerializerTier.B;
  if (TIER_A_NODE_TYPES.has(node.type)) return SerializerTier.A;
  return SerializerTier.C;
}

function tierForMark(type: string): SerializerTier {
  if (TIER_B_MARK_TYPES.has(type) || type === 'wikilink') return SerializerTier.B;
  if (TIER_A_MARK_TYPES.has(type)) return SerializerTier.A;
  return SerializerTier.C;
}

function highestTier(features: readonly TierFeature[]): SerializerTier {
  let tier = SerializerTier.A;
  for (const feature of features) {
    tier = maxTier(tier, feature.tier);
  }
  return tier;
}

function maxTier(lhs: SerializerTier, rhs: SerializerTier): SerializerTier {
  if (lhs === SerializerTier.C || rhs === SerializerTier.C) return SerializerTier.C;
  if (lhs === SerializerTier.B || rhs === SerializerTier.B) return SerializerTier.B;
  return SerializerTier.A;
}

function isWikiHref(value: unknown): boolean {
  return typeof value === 'string' && value.startsWith('epistemos-doc:wiki/');
}

function notebookFeatureType(rawType: unknown): string {
  if (typeof rawType !== 'string') return 'notebookUnknownTab';
  switch (rawType.trim().toLowerCase()) {
    case 'sheet':
    case 'dataset':
      return 'notebookSheetTab';
    case 'chat':
      return 'notebookChatTab';
    default:
      return 'notebookUnknownTab';
  }
}

function parseKeyValueAttributes(source: string): Record<string, string> {
  const values: Record<string, string> = {};
  const pattern = /([A-Za-z0-9_-]+)\s*[=:]\s*("(?:\\.|[^"\\])*"|[^\s,}]+)/g;
  for (const match of source.matchAll(pattern)) {
    const key = (match[1] ?? '').toLowerCase();
    const rawValue = match[2] ?? '';
    values[key] = unquoteAttribute(rawValue);
  }
  return values;
}

function unquoteAttribute(value: string): string {
  if (!value.startsWith('"') || !value.endsWith('"')) return value;
  return value
    .slice(1, -1)
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\');
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function tierB(
  type: string,
  label: string,
  exportKind: LensFidelityDescriptor['exportKind'],
  overrides: Partial<Record<LensId, `${LensFidelityState}`>>,
): LensFidelityDescriptor {
  return {
    type,
    label,
    tier: SerializerTier.B,
    exportKind,
    lens: {
      prose: LensFidelityState.Rendered,
      document: LensFidelityState.Rendered,
      preview: LensFidelityState.Rendered,
      source: LensFidelityState.Rendered,
      ...stateOverrides(overrides),
    },
  };
}

function stateOverrides(
  overrides: Partial<Record<LensId, `${LensFidelityState}`>>,
): Partial<Record<LensId, LensFidelityState>> {
  return Object.fromEntries(
    Object.entries(overrides).map(([key, value]) => [key, value as LensFidelityState]),
  ) as Partial<Record<LensId, LensFidelityState>>;
}
