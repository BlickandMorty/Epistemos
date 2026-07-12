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
// IronCalc-WASM is the SOLE CALC AUTHORITY. Settled against the pinned
// @ironcalc/wasm 0.7.0 package: Model(name, locale, timezone, language_id),
// setUserInput -> evaluate -> getFormattedCellValue / getCellContent. The wasm
// build exports no UserModel and no getCellValueByIndex. IronCalc is pre-1.0
// ("expect things to break until 1.0") — the durable contract is calc_facade.rs
// in agent_core, not this wrapper.
// XLSX DOES NOT EXIST IN THE WASM BUILD — never import xlsx paths here; that
// work belongs to agent_core/src/reckoner/csv_xlsx.rs.

import init, { Model } from "@ironcalc/wasm"; // pinned in package.json

let model: Model | null = null;

export async function initCalc(): Promise<void> {
  await init(); // WebAssembly.instantiateStreaming via custom scheme (OQ-5: MIME application/wasm)
  model = new Model("Epistemos", "en", "UTC", "en");
}

export interface CellAddr { sheet: number; row: number; col: number }
export interface CalcResult { dirty: CellAddr[]; formatted: Map<string, string> }

export function routeToCalc(edit: { sheet: number; row: number; col: number; input: string }): CalcResult {
  if (!model) throw new Error("calc not initialized");
  model.setUserInput(edit.sheet, edit.row, edit.col, edit.input);
  model.evaluate();
  // TODO: dirty-cell set — diff pre/post snapshot of the touched region plus
  // IronCalc-reported changes; NEVER trigger a full-sheet repaint per keystroke.
  // The wasm build has no UserModel. Model snapshot/diff helpers may be used
  // for local tab continuity, while tracked agent edits stay in RECKONER's
  // provenance/suggestion layer.
  return { dirty: [edit], formatted: new Map() };
}

export function readFormatted(addr: CellAddr): string {
  if (!model) throw new Error("calc not initialized");
  return model.getFormattedCellValue(addr.sheet, addr.row, addr.col);
}
