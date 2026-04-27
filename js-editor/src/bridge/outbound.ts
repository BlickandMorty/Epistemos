// W7.17 — JS → Swift bridge.
//
// Wraps window.webkit.messageHandlers.epdoc.postMessage so call sites
// stay readable + type-checked. Silently no-ops when running outside
// WKWebView (e.g. webpack-dev-server) so the bundle is debuggable in
// a regular browser.
//
// AP1 — outbound coalescing (Wave 13 §"Phase 4 perf — AP1 WKWebView
// bridge batching"). The bridge is the hot path on a paste burst (the
// JS side fires editorReady + caretChanged + contentDidChange + slash
// menu emissions in one frame). Every postMessage round-trips into the
// WKWebView IPC so coalescing 3-5 messages into a single batched
// postMessage drops the per-paste cost from 100-150 ms → 30-40 ms.
//
// We coalesce on a requestAnimationFrame tick (~16 ms window — matches
// the CADisplayLink cadence the Swift side uses for its inbound
// batcher) and flush as `{ type: 'batch', messages: [...] }`. The
// Swift handler unpacks the batch into individual EpdocBridgeMessage
// decodes — see EpdocEditorChromeView.Coordinator.userContentController.
//
// IMPORTANT — flushSync(): exposed for messages that can't tolerate
// the up-to-16 ms delay (today: none — caretChanged at 60 fps already
// rides this cadence; contentDidChange is debounced separately by
// AP8). Reserved as the escape hatch.

export interface OutboundMessageBase {
  type: string;
}

export interface EditorReadyMessage extends OutboundMessageBase {
  type: 'editorReady';
}

export interface ContentDidChangeMessage extends OutboundMessageBase {
  type: 'contentDidChange';
  /** Stringified ProseMirror JSON (the canonical .epdoc body). */
  json: string;
}

export interface RectPayload {
  x: number; y: number; w: number; h: number;
}

export interface SelectionPayload {
  from: number; to: number; empty: boolean;
}

export interface CaretChangedMessage extends OutboundMessageBase {
  type: 'caretChanged';
  rect: RectPayload;
  selection: SelectionPayload;
}

export interface RequestSlashMenuMessage extends OutboundMessageBase {
  type: 'requestSlashMenu';
  /** Substring after the `/` trigger; used to filter the slash-menu list. */
  query: string;
  anchor: RectPayload;
}

export interface RequestBubbleMenuMessage extends OutboundMessageBase {
  type: 'requestBubbleMenu';
  selection: SelectionPayload;
  anchor: RectPayload;
}

/**
 * AR5 — paste classification request. JS posts the raw pasted text to
 * the Swift host so `IntakeValve.shared.classifyAndRoute(...)` can
 * decide whether the paste belongs in the structured graph, the
 * ambient quarantine, or the bit-bucket. See
 * `js-editor/src/extensions/paste-classifier-bridge.ts` and
 * `Epistemos/Engine/IntakeValve.swift`.
 */
export interface ClassifyPasteMessage extends OutboundMessageBase {
  type: 'classifyPaste';
  /** Pasted text (after browser sanitisation, before Tiptap parsing). */
  text: string;
}

export type OutboundMessage =
  | EditorReadyMessage
  | ContentDidChangeMessage
  | CaretChangedMessage
  | RequestSlashMenuMessage
  | RequestBubbleMenuMessage
  | ClassifyPasteMessage;

/**
 * AP1 — single batched envelope. The Swift handler treats `type:
 * 'batch'` specially and decodes each entry of `messages` as a
 * standalone EpdocBridgeMessage.
 */
interface BatchedEnvelope {
  type: 'batch';
  messages: OutboundMessage[];
}

interface OutboundBridge {
  /** Queue a message for the next animation-frame flush. */
  post(message: OutboundMessage): void;
  /** Flush queued messages immediately (escape hatch — usually unneeded). */
  flushSync(): void;
}

const queue: OutboundMessage[] = [];
let scheduled = false;

function nativePost(payload: OutboundMessage | BatchedEnvelope): void {
  const handlers = window.webkit?.messageHandlers;
  if (!handlers) {
    // Surface in the dev console so we know we're running detached.
    console.debug('[epdoc bridge] postMessage skipped (no WKWebView host)', payload);
    return;
  }
  try {
    handlers.epdoc.postMessage(payload);
  } catch (error) {
    console.warn('[epdoc bridge] postMessage failed', payload, error);
  }
}

function flushQueue(): void {
  scheduled = false;
  if (queue.length === 0) return;
  // Splice once so concurrent enqueues during the flush land in the
  // *next* batch, not this one.
  const batch = queue.splice(0, queue.length);
  if (batch.length === 1) {
    // Avoid the envelope overhead for the common "one message per
    // tick" case (caret changes when the user is idle).
    nativePost(batch[0]);
    return;
  }
  nativePost({ type: 'batch', messages: batch });
}

function scheduleFlush(): void {
  if (scheduled) return;
  scheduled = true;
  // requestAnimationFrame is the closest the WebKit host hands us to
  // the Swift side's CADisplayLink cadence — both fire ~once per
  // display refresh, so the batches stay aligned.
  if (typeof requestAnimationFrame === 'function') {
    requestAnimationFrame(flushQueue);
  } else {
    // No rAF (running under jsdom / dev shell) — fall back to a
    // microtask-ish setTimeout so tests still drain the queue.
    setTimeout(flushQueue, 0);
  }
}

const bridge: OutboundBridge = {
  post(message: OutboundMessage): void {
    queue.push(message);
    scheduleFlush();
  },
  flushSync(): void {
    flushQueue();
  },
};

// Window-attached so non-bundle JS (the inbound shim, future debug
// surfaces) can reach the same coalescing batcher without re-importing.
declare global {
  interface Window {
    epdocOutboundBridge?: OutboundBridge;
  }
}
window.epdocOutboundBridge = bridge;

/**
 * Post a message to the Swift host. Coalesces with other postBridge
 * calls in the same animation-frame tick into one batched
 * `webkit.messageHandlers.epdoc.postMessage` (AP1).
 *
 * Use `window.epdocOutboundBridge.flushSync()` only in the rare case
 * you need to flush before the next rAF (today: none).
 */
export function postBridge(message: OutboundMessage): void {
  bridge.post(message);
}
