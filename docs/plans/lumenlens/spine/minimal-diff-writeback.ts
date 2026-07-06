// minimal-diff-writeback.ts — EPI-RP-02-LUMENLENS · Fork B (BINDING).
// NEVER reserialize the whole doc on save. Use prosemirror-changeset.changedRange to find
// the touched range (in NEW-doc coordinates), expand to enclosing block boundaries,
// reserialize ONLY those blocks, and splice into the on-disk buffer. A one-paragraph edit
// must produce a one-paragraph git diff — everything else keeps its original bytes,
// line endings, indent style, and list markers.

import { ChangeSet } from "prosemirror-changeset";
import type { Node as PMNode } from "prosemirror-model";
import type { StepMap } from "prosemirror-transform";

export interface WritebackRegion {
  /** Byte range in the on-disk buffer to replace. */
  from: number;
  to: number;
  /** Reserialized markdown for exactly the touched block(s). */
  blockMarkdown: string;
}

/**
 * Compute the minimal writeback region for a batch of steps.
 * @param oldSet  changeset before this batch
 * @param newSet  changeset after applying the batch's maps
 * @param maps    the StepMaps produced by the batch
 * @param doc     the new document
 */
export function minimalWriteback(
  oldSet: ChangeSet,
  newSet: ChangeSet,
  maps: readonly StepMap[],
  doc: PMNode
): WritebackRegion | null {
  const range = oldSet.changedRange(newSet, maps); // {from,to} in new-doc coords, or null
  if (!range) return null;

  // TODO: expand [range.from, range.to] outward to the nearest block boundaries so we
  //       reserialize whole blocks (partial-block markdown is not writable).
  const blockFrom = range.from; // TODO widen to block start
  const blockTo = range.to;     // TODO widen to block end

  // TODO: serialize doc.slice(blockFrom, blockTo) via the tiered serializer.
  void doc;
  return { from: blockFrom, to: blockTo, blockMarkdown: "/* TODO block md */" };
}

/** Seed an empty changeset for a freshly loaded document. */
export function seedChangeSet(doc: PMNode): ChangeSet {
  return ChangeSet.create(doc);
}
