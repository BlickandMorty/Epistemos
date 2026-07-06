/**
 * minimal-diff-writeback.ts
 * Epistemos — LUMENLENS spine (authored from Spine Fork B + amendment L7)
 *
 * The anti-#440 core: NEVER reserialize the whole document on save. The
 * DesktopCommanderMCP #440 bug class (Tiptap round-trip silently corrupting
 * frontmatter, collapsing GFM tables, rewriting [[wikilinks]], adding
 * spurious escapes) is what this module exists to make impossible.
 *
 * Mechanism:
 *  1. `prosemirror-changeset` (v2.4.1, Meyers diff, incremental) accumulates
 *     the session's changes; `changedRange` yields the touched block range.
 *  2. Reserialize ONLY the touched top-level blocks via the existing
 *     serializer (js-editor/src/markdown/epdoc-markdown-nodes.ts — extend it;
 *     don't add a second serializer).
 *  3. Splice the reserialized block text into the ON-DISK buffer, preserving
 *     line endings, indent style, and list markers everywhere else.
 *  4. ⚠️ L7: the splice is IN MEMORY. The disk write is the WHOLE buffer,
 *     atomically, through KEELSTONE's AtomicVaultWriter (coordinate → temp →
 *     replace). Minimal-diff = which BYTES change (git-diff minimality),
 *     never partial file IO / seek-and-patch.
 *
 * Tier map (Fork B — drives both serialization and the test harness):
 *  Tier A canonical-lossless: headings, paragraphs, bold/italic, inline code,
 *    bullet/ordered/task lists, fenced code (lowlight), blockquotes, HR,
 *    images, links. Bar: canonically idempotent after first normalization.
 *  Tier B custom serializers + tests: tables, inline/block math, callouts,
 *    wikilinks, highlights, charts, YAML frontmatter. Frontmatter is parsed
 *    and passed through VERBATIM — never reserialized.
 *  Tier C opaque quarantine: unknown nodes stored as byte-spans, written
 *    back unchanged.
 *
 * prosemirror-markdown serializer options set DELIBERATELY (not defaults):
 *   tightLists, escapeExtraCharacters, strict — chosen per-corpus in Phase 1.
 */

export type Tier = 'A' | 'B' | 'C';

export interface TouchedBlock {
  /** Index range of top-level blocks touched this save (from changedRange). */
  fromBlock: number;
  toBlock: number;
}

export interface SpliceResult {
  /** Full new file content — hand to AtomicVaultWriter (whole-buffer, atomic). */
  newContent: string;
  /** For the done-bar: the byte range that actually changed (git-diff check). */
  changedByteRange: { start: number; end: number };
}

/** Classify a node type into its round-trip tier (drives harness + writeback). */
export function tierOf(nodeTypeName: string): Tier {
  const tierA = new Set([
    'heading', 'paragraph', 'bulletList', 'orderedList', 'taskList',
    'codeBlock', 'blockquote', 'horizontalRule', 'image', 'text',
  ]);
  const tierB = new Set([
    'table', 'inlineMath', 'blockMath', 'callout', 'wikilink',
    'highlight', 'epdocChart', 'epdocImage', 'frontmatter',
  ]);
  if (tierA.has(nodeTypeName)) return 'A';
  if (tierB.has(nodeTypeName)) return 'B';
  return 'C';
}

/**
 * Splice reserialized blocks into the on-disk buffer.
 * Preserves: original EOL style (detect CRLF/LF once), indentation of
 * untouched lines, list-marker style outside the touched range, and the
 * byte-verbatim frontmatter block.
 *
 * DONE-BAR (Phase 1): a one-paragraph edit on a multi-MB doc yields a
 * one-region git diff; the four #440 corruption cases do not reproduce.
 */
export function spliceTouchedBlocks(
  diskBuffer: string,
  touched: TouchedBlock,
  reserializedBlocks: string,
): SpliceResult {
  // Skeleton: block-boundary mapping (disk line offsets per top-level block)
  // + splice + EOL preservation land in Phase 1. The signature is the seam.
  throw new Error('LUMENLENS Phase 1: implement block splice');
}
