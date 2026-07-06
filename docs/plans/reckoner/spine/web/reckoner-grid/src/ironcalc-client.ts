// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// EMPIRICALLY SETTLED vs the shipped @ironcalc/wasm 0.7.0 d.ts (tarball-verified):
//  • PIN = 0.7.0 — @ironcalc/wasm 0.7.1 DOES NOT EXIST (0.7.1 is @ironcalc/nodejs only). Fix the pin here + calc_facade.rs + PLAN.
//  • OQ-1 SETTLED: Model constructor is 4-arg (name, locale, timezone, language_id) — the 2-arg call at :18 is WRONG.
//  • OQ-2 SETTLED: the wasm build exports NO UserModel. Model itself carries applyExternalDiffs(Uint8Array),
//    undo(), redo(), toBytes(), static from_bytes(bytes, language_id). Delete the UserModel branch everywhere.
//  • getCellValueByIndex DOES NOT EXIST — real read surface: getCellContent / getCellStyle / getCellType / getFormattedCellValue.
//  • Core loop (init/setUserInput/evaluate/getFormattedCellValue) VERIFIED exact — keep.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// IronCalc-WASM is the SOLE CALC AUTHORITY. Confirmed core loop (README verbatim
// pattern): setUserInput → evaluate → getCellValueByIndex / getFormattedCellValue.
// VERSION-GATED (OQ-1): constructor arity drifted — archived README shows
// new Model('en','UTC') (2-arg); the 0.7.1 nodejs sibling shows 4-arg
// (name, locale, tz, lang). Pin =0.7.1, read the shipped ironcalc.d.ts, then fix
// the TODO below. IronCalc is pre-1.0 ("expect things to break until 1.0") —
// the durable contract is calc_facade.rs in agent_core, not this wrapper.
// XLSX DOES NOT EXIST IN THE WASM BUILD — never import xlsx paths here; that
// work belongs to agent_core/src/reckoner/csv_xlsx.rs.

import init, { Model } from "@ironcalc/wasm"; // pinned in package.json

let model: Model | null = null;

export async function initCalc(): Promise<void> {
  await init(); // WebAssembly.instantiateStreaming via custom scheme (OQ-5: MIME application/wasm)
  model = new Model("en", "UTC"); // TODO OQ-1: confirm arity from shipped .d.ts
}

export interface CellAddr { sheet: number; row: number; col: number }
export interface CalcResult { dirty: CellAddr[]; formatted: Map<string, string> }

export function routeToCalc(edit: { sheet: number; row: number; col: number; input: string }): CalcResult {
  if (!model) throw new Error("calc not initialized");
  model.setUserInput(edit.sheet, edit.row, edit.col, edit.input);
  model.evaluate();
  // TODO: dirty-cell set — diff pre/post snapshot of the touched region plus
  // IronCalc-reported changes; NEVER trigger a full-sheet repaint per keystroke.
  // TODO OQ-2: if the wasm build exports UserModel (diff history / undo /
  // to_bytes / apply_external_diffs), lean on it for streamed agent edits;
  // otherwise RECKONER owns that layer in agent_core.
  return { dirty: [edit], formatted: new Map() };
}

export function readFormatted(addr: CellAddr): string {
  if (!model) throw new Error("calc not initialized");
  return model.getFormattedCellValue(addr.sheet, addr.row, addr.col);
}
