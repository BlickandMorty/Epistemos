// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// EXTENDS the LIVE 14-line module (js-editor/src/bridge/document-load-state.ts:
//   hostDocumentLoaded flag + markHostDocumentLoaded()/hasHostDocumentLoaded()) — do NOT delete it.
// The epoch plugin here LAYERS onto that gate. CRITICAL: EpdocVisibilitySourceGuardTests.swift:270
// pins the EXACT 4-line loader block INCLUDING `setContent(parsed, { emitUpdate: false })` as a
// multiline string literal. So: (a) keep emitUpdate:false at the load site (belt) — the epoch/
// filterTransaction guard is the CORRECTNESS layer (suspenders); the ban is on RELYING on the flag,
// not on passing it; (b) any reflow of that loader block updates the guard test IN THE SAME COMMIT.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// document-load-state.ts
// EPI-RP-02-LUMENLENS · Fork D (BINDING): loadEpoch nonce + suppression window +
// filterTransaction guard. We do NOT rely on setContent's emitUpdate:false, because
// it is documented-unreliable: Tiptap #1715 (emitUpdate:false still emits when a node
// view is present) and #4828 (setEditable emits an empty-doc update ~20% of the time).
// The guard lives in OUR transaction filter, not in Tiptap's flag. Loading != editing.

import { Plugin, PluginKey, type Transaction, type EditorState } from "prosemirror-state";

/** Branded nonce so a raw number can't be passed where an epoch is required. */
export type LoadEpoch = number & { readonly __brand: "LoadEpoch" };

export interface DocumentLoadState {
  /** Bumped by the host on every programmatic load. */
  epoch: LoadEpoch;
  /** performance.now() ms; transactions are dropped while now() < suppressUntil. */
  suppressUntil: number;
  /** True from the moment a load begins until content has settled. */
  loading: boolean;
}

export const loadStateKey = new PluginKey<DocumentLoadState>("epdoc-load-state");

export function nextEpoch(prev: LoadEpoch): LoadEpoch {
  return ((prev as number) + 1) as LoadEpoch;
}

/** Meta key user-input transactions must carry to bypass the epoch check. */
export const USER_INPUT_META = "epdoc:userInput";
/** Meta key host-originated load transactions carry so they are allowed through once. */
export const HOST_LOAD_META = "epdoc:hostLoad";

/**
 * The load-vs-edit guard. Rejects stale or suppressed transactions instead of
 * trusting emitUpdate. A host load opens a suppression window and stamps its own
 * transaction with HOST_LOAD_META so it is the only thing allowed to mutate during load.
 */
export function loadStatePlugin(initial: LoadEpoch): Plugin<DocumentLoadState> {
  return new Plugin<DocumentLoadState>({
    key: loadStateKey,
    state: {
      init: (): DocumentLoadState => ({ epoch: initial, suppressUntil: 0, loading: false }),
      apply(tr: Transaction, value: DocumentLoadState): DocumentLoadState {
        const meta = tr.getMeta(loadStateKey) as Partial<DocumentLoadState> | undefined;
        return meta ? { ...value, ...meta } : value;
      },
    },
    filterTransaction(tr: Transaction, state: EditorState): boolean {
      const s = loadStateKey.getState(state);
      if (!s) return true;

      // A host load transaction is always allowed (it IS the load).
      if (tr.getMeta(HOST_LOAD_META) === true) return true;

      // While loading, nothing user-originated may pass — loading != editing.
      if (s.loading) return false;

      // Suppression window (covers the microtask tail after setContent settles).
      if (performance.now() < s.suppressUntil) return false;

      // Stale-epoch guard: a transaction stamped with a superseded epoch is dropped.
      const stamp = tr.getMeta("epoch") as LoadEpoch | undefined;
      if (stamp !== undefined && stamp !== s.epoch) return false;

      return true;
    },
  });
}

/**
 * Begin a host-driven load. Bumps the epoch, opens a suppression window, marks loading.
 * The caller then dispatches the actual setContent transaction stamped HOST_LOAD_META,
 * and calls endLoad() on the next microtask.
 *
 * @param suppressMs how long to keep dropping non-host transactions after load (e.g. 32ms).
 */
export function beginLoad(view: { state: EditorState; dispatch: (tr: Transaction) => void },
                          suppressMs: number): LoadEpoch {
  const current = loadStateKey.getState(view.state)!;
  const epoch = nextEpoch(current.epoch);
  const tr = view.state.tr.setMeta(loadStateKey, {
    epoch,
    loading: true,
    suppressUntil: performance.now() + suppressMs,
  });
  tr.setMeta(HOST_LOAD_META, true);
  view.dispatch(tr);
  return epoch;
  // TODO: caller now dispatches setContent(md) stamped HOST_LOAD_META + this epoch.
}

/** Close the load: clear the loading flag. Suppression window may still be counting down. */
export function endLoad(view: { state: EditorState; dispatch: (tr: Transaction) => void }): void {
  const tr = view.state.tr.setMeta(loadStateKey, { loading: false });
  tr.setMeta(HOST_LOAD_META, true);
  view.dispatch(tr);
  // TODO: schedule via queueMicrotask so it runs after setContent's own async settle.
}
