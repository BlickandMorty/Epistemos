/**
 * load-epoch.ts
 * Epistemos — LUMENLENS spine (authored from Spine Fork D + amendment L4)
 *
 * Load-vs-edit hardening: nonce/loadEpoch + suppression window +
 * filterTransaction guard. NEVER rely on `emitUpdate:false` —
 *   • Tiptap v3 flipped setContent's emitUpdate default false→true;
 *   • #1715: setContent emits update anyway when a node view is present;
 *   • #4828: setEditable can emit an empty-document update first (~20%).
 * Repo runs Tiptap 3.24.0 → all three apply.
 *
 * ⚠️ INTEGRATION (L4): this EXTENDS the existing
 * js-editor/src/bridge/document-load-state.ts (markHostDocumentLoaded /
 * hasHostDocumentLoaded) — it does not replace it. AND:
 * EpistemosTests/EpdocVisibilitySourceGuardTests.swift pins EXACT STRINGS
 * from the load path (e.g. `setContent(parsed, { emitUpdate: false })`,
 * `markHostDocumentLoaded()`); any refactor here updates those guard tests
 * DELIBERATELY IN THE SAME COMMIT. A green build with red source-guards is a
 * blocked phase.
 *
 * Protocol (idempotent; survives both bugs):
 *  1. Native mints a monotonic loadEpoch per programmatic load
 *     (LensSessionCoordinator.nextLoadEpoch()) and stamps the inbound
 *     bridge message.
 *  2. Before setContent: suppressUntilEpoch = loadEpoch (window opens).
 *  3. filterTransaction drops programmatic transactions with no user-input
 *     meta while the window is open.
 *  4. Every outbound 'update'/'contentDidChange' carries the current epoch;
 *     native ignores any outbound whose epoch ≠ latest requested.
 *  5. Window closes when the post-load stats tick confirms the load settled
 *     (reuse the existing markHostDocumentLoaded() call site).
 */

let currentEpoch = 0;          // last epoch requested by native
let suppressUntilEpoch = 0;    // transactions suppressed while <= this

/** Called from inbound.ts when native pushes content (stamped message). */
export function beginEpochLoad(epoch: number): void {
  currentEpoch = epoch;
  suppressUntilEpoch = epoch;
  // then: markHostDocumentLoaded() flow proceeds as today (document-load-state.ts)
}

/** Called after the load settles (same site that runs postDocumentStats). */
export function endEpochLoad(epoch: number): void {
  if (epoch === suppressUntilEpoch) suppressUntilEpoch = 0;
}

export function activeEpoch(): number {
  return currentEpoch;
}

/** filterTransaction guard — register on the editor (index.ts). */
export function shouldSuppressTransaction(meta: {
  isUserInput: boolean;        // tr.getMeta('uiEvent') / input rules / paste
}): boolean {
  return suppressUntilEpoch !== 0 && !meta.isUserInput;
}

/**
 * Outbound stamping (outbound.ts): attach { epoch: activeEpoch() } to every
 * update-class message. Native side (EpdocEditorBridge/chrome coordinator)
 * drops messages whose epoch ≠ the session's latest requested epoch.
 */
