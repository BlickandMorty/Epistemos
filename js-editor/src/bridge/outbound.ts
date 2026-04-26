// W7.17 — JS → Swift bridge.
//
// Wraps window.webkit.messageHandlers.epdoc.postMessage so call sites
// stay readable + type-checked. Silently no-ops when running outside
// WKWebView (e.g. webpack-dev-server) so the bundle is debuggable in
// a regular browser.

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

export type OutboundMessage =
  | EditorReadyMessage
  | ContentDidChangeMessage
  | CaretChangedMessage
  | RequestSlashMenuMessage
  | RequestBubbleMenuMessage;

/**
 * Post a message to the Swift host. No-op when the WebKit bridge
 * isn't available (e.g. running the bundle in a browser for dev).
 */
export function postBridge(message: OutboundMessage): void {
  const handlers = window.webkit?.messageHandlers;
  if (!handlers) {
    // Surface in the dev console so we know we're running detached.
    console.debug('[epdoc bridge] postMessage skipped (no WKWebView host)', message);
    return;
  }
  try {
    handlers.epdoc.postMessage(message);
  } catch (error) {
    console.warn('[epdoc bridge] postMessage failed', message, error);
  }
}
