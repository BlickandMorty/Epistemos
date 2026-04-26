// W7.17 — WKScriptMessageHandler typings.
//
// WKWebView injects window.webkit.messageHandlers.<name>.postMessage(_)
// for every WKScriptMessageHandler the host registers. EpdocEditorBridge
// registers the "epdoc" handler (cross-ref Epistemos/Engine/EpdocEditorBridge.swift).
//
// Defining the namespace keeps the bridge code in src/bridge/outbound.ts
// fully typed without `any` casts.

interface WebKitMessageHandler {
  postMessage(message: unknown): void;
}

interface WebKitMessageHandlers {
  /**
   * The host-registered Swift handler that decodes
   * `EpdocBridgeMessage` payloads and routes them to the active
   * `EpdocDocument`. See `Epistemos/Engine/EpdocEditorBridge.swift`.
   */
  epdoc: WebKitMessageHandler;
}

interface WebKit {
  messageHandlers: WebKitMessageHandlers;
}

interface Window {
  webkit?: WebKit;
  /** Tiptap Editor instance — exposed for Swift command dispatch. */
  epdocEditor?: import('@tiptap/core').Editor;
  /** Namespaced inbound command surface — installed by bridge/inbound.ts. */
  epistemos?: {
    setContent(json: string): void;
    focusStart(): void;
    focusEnd(): void;
    dismissSlashMenu(): void;
    insertSlashChoice(blockType: string): void;
    dismissBubbleMenu(): void;
    runCommand(name: string, ...args: unknown[]): boolean;
  };
}
