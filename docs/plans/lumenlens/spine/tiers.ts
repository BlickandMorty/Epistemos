// tiers.ts — EPI-RP-02-LUMENLENS · Fork B (BINDING).
// Canonical-normalized round-trip is the honest target for the full schema; byte-for-byte
// is achievable only for a restricted set. Three tiers, enforced by a test harness:
//   Tier A — canonical-lossless (headings, paragraphs, bold/italic, inline code,
//            bullet/ordered/task lists, fenced code w/ lowlight, blockquotes, HR, images, links)
//   Tier B — custom-extension serializers WITH round-trip tests (tables, inline+block math,
//            callouts, wikilinks, highlights, charts, YAML frontmatter=verbatim passthrough)
//   Tier C — byte-preserving opaque quarantine (anything the schema doesn't own)

import type { Node as PMNode } from "prosemirror-model";

export enum SerializerTier {
  A = "canonical-lossless",
  B = "custom-extension",
  C = "byte-preserving-opaque",
}

export interface TierSerializer {
  readonly tier: SerializerTier;
  canHandle(node: PMNode): boolean;
  serialize(node: PMNode): string;
  parse(markdown: string): PMNode;
}

export interface RoundTripResult {
  tier: SerializerTier;
  /** Tier A/B: structurally equal after canonicalization. Tier C: bytes equal. */
  ok: boolean;
  bytesEqual: boolean;
  detail?: string;
}

/** Pick the serializer that owns this node; Tier C is the last-resort catch-all. */
export function pickTier(node: PMNode, serializers: TierSerializer[]): TierSerializer {
  const owner = serializers.find((s) => s.tier !== SerializerTier.C && s.canHandle(node));
  if (owner) return owner;
  const quarantine = serializers.find((s) => s.tier === SerializerTier.C);
  if (!quarantine) throw new Error("no Tier C quarantine serializer registered");
  return quarantine;
}

/**
 * The proof obligation. For a corpus of real vault files:
 *   Tier A: canonicalize(md) === serialize(parse(md))   (idempotent after 1st normalize)
 *   Tier B: same, with the extension's parse/serialize registered
 *   Tier C: bytes returned verbatim
 * This runs in CI as the Phase L2 done-bar.
 */
export function roundTrip(md: string, serializers: TierSerializer[]): RoundTripResult {
  // TODO: parse -> pick tier -> serialize -> compare per tier rules.
  void serializers;
  return { tier: SerializerTier.A, ok: false, bytesEqual: false, detail: "TODO" + md.slice(0, 0) };
}

/**
 * YAML frontmatter is parsed off the top and passed through VERBATIM. It is never
 * handed to the markdown engine (the #440 corruption class: frontmatter was the #1 victim).
 */
export function splitFrontmatter(source: string): { frontmatter: string; body: string } {
  if (!source.startsWith("---\n")) return { frontmatter: "", body: source };
  const end = source.indexOf("\n---\n", 4);
  if (end === -1) return { frontmatter: "", body: source };
  return { frontmatter: source.slice(0, end + 5), body: source.slice(end + 5) };
}
