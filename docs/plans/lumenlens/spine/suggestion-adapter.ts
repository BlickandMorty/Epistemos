/**
 * suggestion-adapter.ts
 * Epistemos — LUMENLENS spine (authored from Spine Fork A)
 *
 * The swappable seam for the first-party tracked-changes engine. VERDICT
 * (Fork A): build first-party on raw ProseMirror transactions +
 * `prosemirror-changeset` + provenance IDs; adopt the
 * @handlewithcare/prosemirror-suggest-changes MARK SCHEMA as the reference —
 * mark names `insertion` / `deletion` / `modification`, plus the block-mark
 * trick (doc node: `marks: "insertion modification deletion"`) so block-level
 * suggestions (new list items, new blocks) carry marks too.
 *
 * WHY first-party: neither library carries our provenance span —
 *   author / turn / ranges / before-after / rationale / source / accept-state
 * hwc = numeric auto-increment id only (inferred; OQ-5 verifies schema.ts);
 * davefowler = username + data blob, WIP banner. `prosemirror-changeset`
 * (v2.4.1) DOES carry arbitrary per-span metadata + Meyers diff + incremental
 * build-up — that's the substrate; this adapter is the swap seam. Swapping to
 * the hwc package (or post-license Tiptap AI Toolkit) touches ONLY this file,
 * never the ledger or the Swift store.
 *
 * Wire-up home: js-editor/src/ (extend the EXISTING bundle — index.ts
 * registers extensions; inbound.ts/outbound.ts stamp bridge messages).
 * Truth-at-rest lives in Swift (EditorProvenanceStore.swift); attrs here
 * mirror SuggestionSpanRecord 1:1.
 */

import type { EditorState, Transaction } from 'prosemirror-state';
import type { Decoration } from 'prosemirror-view';

/** Mirror of SuggestionSpanRecord (Swift) — keep field-for-field in sync. */
export interface SuggestionAttrs {
  id: string;                 // stable UUID minted natively (NOT lib numeric id)
  turnId: string;             // '' for user edits
  author: string;             // companion id | 'user'
  source: 'agent' | 'user';
  kind: 'insertion' | 'deletion' | 'modification';  // hwc reference names
  rationale?: string;
  createdAt: number;          // epoch ms
}

/** The engine seam. Default impl = first-party changeset engine. */
export interface SuggestionAdapter {
  /** Apply an agent/user edit AS A SUGGESTION (never mutates base content). */
  suggest(state: EditorState, tr: Transaction, attrs: SuggestionAttrs): Transaction;
  /** Accept: fold the span into base content; emits accept to the bridge. */
  applySuggestion(state: EditorState, id: string): Transaction;
  /** Reject: revert the span; emits reject to the bridge. */
  revertSuggestion(state: EditorState, id: string): Transaction;
  /** Revert every pending span for a turn — "revert-all-by-companion". */
  revertTurn(state: EditorState, turnId: string): Transaction;
  /** Inline decorations (underline/strike + hover affordances). */
  decorations(state: EditorState): Decoration[];
  /**
   * Remap live span positions after a user edit lands mid-stream
   * (changeset step-maps; bump mapVersion on the Swift record).
   */
  remap(state: EditorState, tr: Transaction): void;
}

/**
 * Streaming notes (Plan P4): agent tokens buffer until a PARSEABLE BLOCK
 * BOUNDARY before projecting a suggestion (malformed-partial guard); apply
 * chunked at block boundaries; cancellation reverts the in-flight turn's
 * pending spans via revertTurn(). Conflicting user edits during a stream go
 * through remap() — never drop either side.
 *
 * Bridge messages (outbound.ts): 'suggestionCreated' | 'suggestionDecided'
 * carrying SuggestionAttrs + positions + mapVersion → Swift persists via
 * EditorProvenanceStore. Native accept/reject UI calls inbound commands
 * 'applySuggestion' / 'revertSuggestion' / 'revertTurn'.
 */
