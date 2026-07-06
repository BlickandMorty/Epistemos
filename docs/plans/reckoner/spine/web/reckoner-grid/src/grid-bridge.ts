// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// DEFECTS: (1) the loop is UNWIRED — nothing calls paintBack or postOutbound, there is no index.ts
// composition root and no inbound GridInbound dispatcher: R0 must wire intercept→calc→paint + the
// inbound handler FIRST. (2) Epoch width: TS number (2^53) vs Swift UInt64 — pick u32-safe epoch or
// document the cap. (3) bridgeError is defined but the optional-chained post silently drops when the
// handler is absent — surface it. Handler name "reckoner" matches the Swift side ✓.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// WKWebView bridge, epoch-stamped both directions; Swift drops stale epochs.
// Mirrors Epistemos/Reckoner/GridBridgeMessage.swift EXACTLY — drift between the
// two files is a build failure, not a style issue.

export type GridEpoch = number & { readonly __brand: "GridEpoch" };

export type GridInbound =
  | { kind: "loadDataset"; epoch: GridEpoch; datasetId: string; snapshotB64?: string }
  | { kind: "applyAcceptedSuggestion"; epoch: GridEpoch; suggestionId: string }
  | { kind: "stageSuggestion"; epoch: GridEpoch; suggestion: TabularSuggestionDTO }
  | { kind: "cancelSuggestion"; epoch: GridEpoch; suggestionId: string };

export type GridOutbound =
  | { kind: "loadApplied"; epoch: GridEpoch; rowCount: number; colCount: number }
  | { kind: "rawEdit"; epoch: GridEpoch; sheet: number; row: number; col: number; input: string }
  | { kind: "calcCompleted"; epoch: GridEpoch; dirtyCount: number }
  | { kind: "suggestionResolved"; epoch: GridEpoch; suggestionId: string; state: "accepted" | "rejected" }
  | { kind: "embedInvalidated"; epoch: GridEpoch; datasetId: string }
  | { kind: "bridgeError"; epoch: GridEpoch; code: string; message: string };

export interface TabularSuggestionDTO {
  id: string; author: string; turnId: string;
  ranges: string[];              // A1 ranges
  before: Record<string, string>; // addr → value
  after: Record<string, string>;
  rationale?: string;
  acceptState: "proposed" | "accepted" | "rejected" | "superseded";
}

let seq = 0;
export function postOutbound(msg: GridOutbound): void {
  // @ts-expect-error injected by WKWebView userContentController
  window.webkit?.messageHandlers?.reckoner?.postMessage(JSON.stringify({ seq: ++seq, ...msg }));
}
