// inbound.ts — host (Swift) -> webview messages. EPI-RP-02-LUMENLENS.
// Every message carries the LoadEpoch it targets so a stale reply can be dropped.

import type { LoadEpoch } from "./document-load-state";

export interface SuggestionPayload {
  id: string;
  author: string;        // companion-id, "june", or "user"
  turnId: string;
  from: number;          // ProseMirror doc position (pre-edit)
  to: number;
  before: string;
  after: string;
  rationale?: string;
  sourceCitation?: string;
}

export type InboundMessage =
  | { kind: "loadDocument"; epoch: LoadEpoch; markdown: string; frontmatter: string }
  | { kind: "applySuggestion"; epoch: LoadEpoch; suggestion: SuggestionPayload }
  | { kind: "streamSuggestionDelta"; epoch: LoadEpoch; suggestionId: string; partialMarkdown: string; done: boolean }
  | { kind: "cancelSuggestion"; epoch: LoadEpoch; suggestionId: string }
  | { kind: "acceptSuggestion"; epoch: LoadEpoch; suggestionId: string }
  | { kind: "rejectSuggestion"; epoch: LoadEpoch; suggestionId: string }
  | { kind: "setSuppression"; epoch: LoadEpoch; ms: number }
  | { kind: "switchLens"; epoch: LoadEpoch; lens: "prose" | "epdoc" | "preview" | "source" };

/** Parse + validate an inbound message. TODO: replace hand-check with a zod schema. */
export function parseInbound(raw: string): InboundMessage {
  const msg = JSON.parse(raw) as InboundMessage;
  if (typeof (msg as { epoch?: unknown }).epoch !== "number") {
    throw new Error("inbound message missing epoch");
  }
  return msg;
}

/** Wire this to window.addEventListener or a WKScriptMessageHandler bridge entrypoint. */
export type InboundHandler = (msg: InboundMessage) => void;
export function installInbound(handler: InboundHandler): void {
  // TODO: subscribe to the actual host->webview channel used by EpdocEditorBridge.
  (window as unknown as { __epdocInbound?: (raw: string) => void }).__epdocInbound =
    (raw: string) => handler(parseInbound(raw));
}
