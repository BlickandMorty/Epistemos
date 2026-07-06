// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// P0 — THE STUB FAILS OPEN: extractIntent() returns null and null → plain `return`, so every edit
// commits into Univer as authority — the exact hard-constraint breach this file warns about. A safe
// skeleton FAILS CLOSED: unknown/unparsed intents are CANCELLED (throw), never passed through.
// ALSO (tarball-verified @univerjs 0.25.1): onBeforeCommandExecute is DEPRECATED — the current path
// is univerAPI.addEvent(univerAPI.Event.BeforeCommandExecute, …); re-prove throw-to-cancel on the
// PINNED version at R0 (or use the addEvent cancel path). Command ids set-range-values VERIFIED real.
// OQ-3 (full value-mutating command enumeration) stands — reviewer assignment 1.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Every mutation that can change a cell value routes through IronCalc. Univer's
// command system is the interception boundary: onBeforeCommandExecute can cancel
// by throwing (Univer docs demonstrate read-only sheets this way).
// OPEN QUESTION OQ-3 (hard-constraint-2 risk): the command allowlist below must
// be EXHAUSTIVELY enumerated — paste, fill/autofill, cut, clear, structural
// row/col ops. A single missed command = a value trusted from Univer = breach.

import type { FUniver } from "@univerjs/core/facade";
import { routeToCalc } from "./ironcalc-client";
import { isSuppressed } from "./paint-back";

/** Commands known to mutate cell values. EXTEND via OQ-3 enumeration, never assume. */
export const VALUE_MUTATING_COMMANDS = new Set<string>([
  "sheet.command.set-range-values",
  "sheet.mutation.set-range-values",
  // TODO OQ-3: paste / fill / autofill / cut / clear-selection / insert-row /
  // remove-col / sort — enumerate against the pinned Univer version's command ids.
]);

export function installEditIntercept(univerAPI: FUniver): void {
  univerAPI.onBeforeCommandExecute((command) => {
    if (isSuppressed()) return;                          // paint-back re-entry guard
    if (!VALUE_MUTATING_COMMANDS.has(command.id)) return;
    const intent = extractIntent(command);               // raw value or "=formula"
    if (intent === null) return;
    // Cancel Univer's own commit for computed content; RECKONER owns the commit path.
    routeToCalc(intent);                                 // → IronCalc → GRDB → paint-back
    throw new CancelledByReckoner();                     // throwing cancels the command
  });
}

export class CancelledByReckoner extends Error {}

interface EditIntent { sheet: number; row: number; col: number; input: string }
function extractIntent(_command: { id: string; params?: unknown }): EditIntent | null {
  return null; // TODO: decode set-range-values params (single cell + range forms)
}
