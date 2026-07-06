// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// BUNDLE SEAM (unaddressed): dataset-embed.ts mounting this drags Univer+IronCalc-WASM into the
// SHARED js-editor webpack bundle that BOTH builds stage (build-tiptap-bundle.sh runs in the MAS
// preBuild chain too). WASM in WKWebView is MAS-legal, but this is bundle-bloat vs the perf
// doctrine + the unresolved wasm-MIME OQ-5. REQUIRED: lazy dynamic-import chunk (or separate entry)
// so the grid engine loads only when a dataset embed/tab actually mounts. Also: web/reckoner-grid
// is a NEW top-level dir — the repo has no web/ today; it needs package.json + webpack config +
// build-reckoner-grid.sh + project.yml preBuild entries + resource staging (Epistemos/Resources/
// ReckonerGrid/), following build-tiptap-bundle.sh's hash-gate/rsync/CI=1 pattern. Entirely missing
// from the wave — budget it in R0/R2.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// The lightweight grid region the datasetEmbed note block hosts. ONE CALC
// AUTHORITY: this region and the full Data tab share the same IronCalc model +
// GRDB dataset — an edit here is instantly consistent in the tab, by construction.
// Inline edits allowed: single-cell values, sort/filter view. Structural ops
// (add/delete column, range formulas, charts) surface "Open in Data tab".

export interface EmbedViewSpec {
  datasetId: string;
  range?: string;        // A1 window; default = whole sheet, virtualized
  readOnly?: boolean;
  maxRowsVisible?: number;
}

export function mountEmbedGrid(_host: HTMLElement, spec: EmbedViewSpec): () => void {
  // TODO: read-optimized render (second small Univer instance OR canvas view —
  // decide in Phase 3 against memory numbers); edits route through the SAME
  // routeToCalc path; subscribe to datasetChanged for live consistency.
  void spec;
  return () => { /* unmount */ };
}
