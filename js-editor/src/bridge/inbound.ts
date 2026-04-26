// W7.17 — Swift → JS bridge.
//
// Installs window.epistemos.* command surface that EpdocEditorCommand
// (Epistemos/Engine/EpdocEditorBridge.swift) calls via
// WKWebView.evaluateJavaScript. Each command dispatches into the live
// Tiptap editor; unknown commands return false (callers can fall back).

import type { Editor } from '@tiptap/core';
import type { RectPayload, SelectionPayload } from './outbound';

export interface InboundCallbacks {
  /** Re-emit a bubble-menu request after the host accepts a slash choice. */
  emitBubbleMenu?: (selection: SelectionPayload, anchor: RectPayload) => void;
}

export function installInboundCommands(editor: Editor, _callbacks: InboundCallbacks = {}): void {
  const epistemos: Window['epistemos'] = {
    setContent(json: string): void {
      try {
        const parsed = JSON.parse(json);
        editor.commands.setContent(parsed, { emitUpdate: false });
      } catch (e) {
        console.warn('[epdoc inbound] setContent: invalid JSON', e);
      }
    },

    focusStart(): void {
      editor.commands.focus('start');
    },

    focusEnd(): void {
      editor.commands.focus('end');
    },

    dismissSlashMenu(): void {
      // The slash-menu Suggestion plugin owns its own state — we
      // dismiss by simulating Esc, which the plugin's keymap handles.
      const view = editor.view;
      view.dispatch(view.state.tr.setMeta('slashMenuDismiss', true));
    },

    insertSlashChoice(blockType: string): void {
      // The slash menu's Suggestion command (registered in
      // extensions/slash-menu.ts) reads this dispatch and runs the
      // matching Tiptap command. Names mirror the SlashMenuItem
      // catalogue's `id` field.
      const view = editor.view;
      view.dispatch(view.state.tr.setMeta('slashMenuChoice', blockType));
    },

    dismissBubbleMenu(): void {
      // BubbleMenu is selection-driven; collapsing the selection hides
      // it without a dedicated dismiss command.
      const { from } = editor.state.selection;
      editor.commands.setTextSelection(from);
    },

    runCommand(name: string, ...args: unknown[]): boolean {
      const command = (editor.commands as Record<string, unknown>)[name];
      if (typeof command === 'function') {
        return Boolean((command as (...a: unknown[]) => boolean)(...args));
      }
      console.warn(`[epdoc inbound] runCommand: '${name}' is not a Tiptap command`);
      return false;
    },
  };
  window.epistemos = epistemos;
}
