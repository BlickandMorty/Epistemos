// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DEP REALITY: prosemirror-changeset 2.4.1 IS already installed (js-editor/package.json:65).
// @handlewithcare/prosemirror-suggest-changes is NOT installed — L1 either `npm add`s it as the
// reference adapter or implements the marks first-party per the locked verdict. All @tiptap/* are
// 3.24.0; PM access goes through @tiptap/pm. The serializer to extend is @tiptap/markdown +
// js-editor/src/markdown/epdoc-markdown-nodes.ts (renderMarkdown hooks; wikilinks already
// round-trip [[target]] via EpdocLink) — check:markdown-roundtrip script exists in package.json.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// SuggestionAdapter.ts — EPI-RP-02-LUMENLENS · Fork A (BINDING).
// A first-party suggestion engine on raw ProseMirror transactions + prosemirror-changeset,
// behind a swappable adapter seam. Default impl references the hwc package's
// withSuggestChanges dispatch decorator. Swapping adapters (e.g. to davefowler's
// suggestion-mode, or post-license to Tiptap) touches ONLY this file, never the ledger.
//
// NEVER a shadow editor. NEVER blind setContent on the live doc. Cursor/selection/
// unsaved work are preserved because everything flows through the transaction pipeline.

import type { EditorState, Transaction } from "prosemirror-state";
import type { SuggestionPayload } from "../bridge/inbound";

export interface SuggestionAdapter {
  /** Wrap dispatch so ordinary edits are rewritten into suggestion marks. */
  decorateDispatch(base: (tr: Transaction) => void): (tr: Transaction) => void;

  /** Accept a suggestion: content stays, marks are removed. */
  applySuggestion(state: EditorState, id: string, dispatch: (tr: Transaction) => void): void;

  /** Reject a suggestion: inserted content removed, deletions restored. */
  revertSuggestion(state: EditorState, id: string, dispatch: (tr: Transaction) => void): void;

  /** Turn a (possibly streamed) agent edit payload into a suggestion-marked transaction. */
  ingestAgentEdit(state: EditorState, payload: SuggestionPayload): Transaction;

  /** Human-readable name for logging / adapter identification. */
  readonly name: string;
}

/** Default adapter backed by @handlewithcare/prosemirror-suggest-changes. */
export class HwcSuggestionAdapter implements SuggestionAdapter {
  readonly name = "hwc";

  decorateDispatch(base: (tr: Transaction) => void): (tr: Transaction) => void {
    // TODO: return withSuggestChanges(base) from the hwc package. Signature:
    //   withSuggestChanges(dispatch?, generateId?): EditorView["dispatch"]
    return base;
  }

  applySuggestion(_state: EditorState, _id: string, _dispatch: (tr: Transaction) => void): void {
    // TODO: applySuggestion(Number(id)) command -> dispatch.
  }

  revertSuggestion(_state: EditorState, _id: string, _dispatch: (tr: Transaction) => void): void {
    // TODO: revertSuggestion(Number(id)) command -> dispatch.
  }

  ingestAgentEdit(state: EditorState, payload: SuggestionPayload): Transaction {
    // TODO: build a tr that replaces [from,to] with `after`, wrapped by decorateDispatch
    //       so it lands as insertion/deletion marks tagged with payload.author/turnId.
    const tr = state.tr;
    void payload;
    return tr;
  }
}

/** A no-op adapter that must still compile — proves the seam is genuinely swappable. */
export class NoopSuggestionAdapter implements SuggestionAdapter {
  readonly name = "noop";
  decorateDispatch(base: (tr: Transaction) => void) { return base; }
  applySuggestion() { /* no-op */ }
  revertSuggestion() { /* no-op */ }
  ingestAgentEdit(state: EditorState) { return state.tr; }
}
