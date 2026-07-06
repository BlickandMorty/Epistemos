// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// VERDICT INVERTED (canon + evidence): Swift Charts is PRIMARY (canon §0.9 + RESHAPE "Swift Charts
// stands"); this vchart overlay is the "later if needed" experimental lane. Tarball facts: the
// plugin exists (CREATE_VCHART_COMMAND_ID verified) BUT its npm manifest declares NO license (the
// "MIT VERIFIED" header claim is unconfirmed — check the repo LICENSE before ANY vendoring), it is
// peer-locked to @univerjs/core ^0.2.5 (+React 18) — ~23 minors behind the pinned Univer — and
// stale since 2024-11. Decide OQ-4 at R0, not R6; expect the native Swift-Charts block to be the
// real path. R6's provenance contract (ledger pointer before chart exists; staleness) is unchanged
// and applies to the native block.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// VERIFIED LICENSE BOUNDARY: Univer's first-party charts are Pro-gated
// (@univerjs-pro/*). RECKONER must not touch Pro code. OSS path: the MIT
// @visactor/univer-vchart-plugin (CREATE_VCHART_COMMAND_ID + a VChart spec).
// Maturity caveat (~8 stars): pin its version against the pinned Univer; if it
// lags, execute the documented fallback — a native chart block rendered from a
// dataset query via an OSS chart lib as its own Tiptap node.

export interface ChartProvenance {
  datasetId: string;
  sourceRange: string;   // A1 range the chart was generated from
  ledgerPointer: string; // F5 record id — every chart is auditable to its data
}

export function createChartOverlay(_spec: unknown, prov: ChartProvenance): void {
  // TODO: executeCommand(CREATE_VCHART_COMMAND_ID, { spec }) via the plugin;
  // append prov to the ledger BEFORE the overlay exists — no orphan charts.
  void prov;
}

export function onSourceChanged(_datasetId: string, _range: string): void {
  // TODO: mark dependent charts stale (embedInvalidated / datasetChanged events).
}
