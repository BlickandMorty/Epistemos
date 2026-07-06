// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// Sound design (staged-until-accept, local until commit). Align its accept-state strings with the
// UNIFIED schema (see tabular_suggestion.rs header: locked LUMENLENS shape, 3 states + typed
// author) and with GridBridgeMessage's enums — M3/M4 cross-file drift is a build-blocker to fix.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Agent cell edits are NEVER blind writes. They stage as TabularSuggestions and
// render as before/after chips over the grid — the tabular analogue of tracked
// changes. Staged values do NOT enter the IronCalc model or GRDB until accepted;
// on accept they commit through the normal routeToCalc → persist path and the
// ledger records the acceptance.
// (Dependencies / hand-off seam: the suggestion schema — author/turn/ranges/
// before-after/rationale/source/accept-state — is owned by EPI-RP-02-LUMENLENS;
// this layer reuses it for cells, it does not fork it.)

import type { TabularSuggestionDTO } from "./grid-bridge";

const staged = new Map<string, TabularSuggestionDTO>();

export function stage(s: TabularSuggestionDTO): void {
  staged.set(s.id, s);
  render();
}

export function resolve(id: string, state: "accepted" | "rejected"): TabularSuggestionDTO | undefined {
  const s = staged.get(id);
  if (s) { s.acceptState = state; staged.delete(id); render(); }
  return s;
}

function render(): void {
  // TODO: Univer custom canvas rendering extension — tint proposed cells,
  // before→after chip on hover, accept/reject per cell / per range / per turn.
  // Values stay in THIS layer only until accepted.
}
