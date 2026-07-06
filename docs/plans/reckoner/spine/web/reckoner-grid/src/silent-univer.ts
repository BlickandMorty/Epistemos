// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// VERIFIED (tarball): notExecuteFormula is REAL — @univerjs/sheets-formula 0.25.1 config.d.ts:38,
// consumed in the plugin. registerPlugin(UniverSheetsFormulaPlugin,{notExecuteFormula:true}) stands.
// The version-gate caveat + R0 smoke-test-as-arbiter stays exactly as written. No changes.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Locked engine canon: Univer OSS is the RENDERER ONLY. Its formula engine is
// silenced at registration — no calc result is ever trusted from Univer.
// Confirmed mechanism (Univer Web Worker docs): notExecuteFormula on the
// sheets-formula plugin. VERSION-GATED: the same field name also appears on
// @univerjs/engine-formula config in some versions — the Phase-0 smoke test is
// the arbiter, not this comment.

import { Univer } from "@univerjs/core";
import { UniverSheetsFormulaPlugin } from "@univerjs/sheets-formula";

export function registerSilentUniver(univer: Univer): void {
  univer.registerPlugin(UniverSheetsFormulaPlugin, {
    notExecuteFormula: true, // Univer parses + stores formula strings, computes NOTHING
  });
  // TODO: register render/UI plugins (sheets, sheets-ui, docs core deps) — pinned
  // versions only; vendor the bundle through the brotli custom-scheme pipeline.
}

/**
 * Phase-0 proven-done bar, encoded as a runnable assertion:
 *   1. enter "=1+1" into A1
 *   2. assert Univer's cell model holds the STRING, no computed value
 *   3. assert IronCalc returns 2 via evaluate() + getFormattedCellValue
 *   4. assert the painted-back "2" arrived through paint-back.ts, not Univer calc
 */
export async function silentUniverSmokeTest(): Promise<void> {
  throw new Error("TODO: Phase-0 spike — this test gates everything downstream");
}
