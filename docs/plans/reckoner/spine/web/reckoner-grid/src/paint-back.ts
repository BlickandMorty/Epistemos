// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// P0 — SUPPRESSION TOO WEAK: a synchronous depth counter cannot cover Univer's async command-bus
// settle tail (the exact failure class the locked LUMENLENS pattern exists for — its time-window
// suppressUntil + loading flag + inbound epoch validation, document-load-state.ts). REQUIRED: a
// grid-load-state.ts porting ALL THREE semantics (loading flag blocks input; time-window covers the
// settle tail; inbound epoch validated JS-side). Keep the depth counter ONLY as the re-entry guard.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Evaluated results paint back into Univer via setValues INSIDE a suppression
// window — the grid analogue of the locked editor loadEpoch/filterTransaction
// pattern. Dataset loads also run inside this window: loading a dataset MUST
// emit zero change/autosave events (hard constraint #4).
// (Dependencies / hand-off seam: the epoch/suppression pattern is owned by
// EPI-RP-02-LUMENLENS; this file extends it to the grid, it does not redefine it.)

let suppressionDepth = 0;

export function isSuppressed(): boolean { return suppressionDepth > 0; }

export function withSuppression<T>(fn: () => T): T {
  suppressionDepth++;
  try { return fn(); } finally { suppressionDepth--; }
}

import type { CalcResult } from "./ironcalc-client";

export function paintBack(univerAPI: unknown, result: CalcResult): void {
  withSuppression(() => {
    // TODO: group dirty cells into contiguous ranges → range.setValues([...]);
    // repaint ONLY dirty cells (100k-row budget depends on this).
    void univerAPI; void result;
  });
}
