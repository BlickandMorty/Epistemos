// AR5 — IntakeValve / Tiptap paste classifier bridge.
//
// Wave 13 §"Phase 14 / Phase 4 perf — AR5 IntakeValve in Tiptap paste
// handler" + master plan Phase 14 (IntakeValve). Every paste into the
// .epdoc editor is intercepted *before* Tiptap parses the clipboard
// payload and forwarded to the Swift host so
// `IntakeValve.shared.classifyAndRoute(...)` can decide whether the
// paste belongs in the structured graph, the ambient quarantine, or
// the bit-bucket.
//
// We do NOT swallow the paste — Tiptap still inserts the content
// inline (the user keeps editing as normal). The classifier runs in
// parallel on the Swift side; if it routes the paste to `.ambient`
// or `.noise`, the host UI surfaces the decision via the Wave 11.4
// "Why?" affordance. The user-visible editor state is never
// buffered (HARD RULE — see CLAUDE.md "STREAM EVERYTHING").
//
// Bridge contract (`bridge/outbound.ts` — ClassifyPasteMessage):
//   { type: 'classifyPaste', text: <pasted plain text> }
// Swift side: EpdocEditorChromeView.Coordinator.userContentController
// switches on the `classifyPaste` type before falling through to
// EpdocBridgeMessage.decode.

import { Extension } from '@tiptap/core';
import type { Editor } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import { postBridge } from '../bridge/outbound';
import { parseMarkdownPaste } from '../markdown/markdown-paste';

const PASTE_CLASSIFIER_KEY = new PluginKey('epdocPasteClassifier');

/**
 * Minimum length below which we don't bother bouncing the paste
 * through the bridge — IntakeValve.preFilter would short-circuit it
 * to `.noise` anyway (see
 * `Epistemos/Engine/IntakeValve.swift` — `minLengthForClassification`).
 * Mirrored here so we don't waste a WKWebView IPC on clipboard cruft.
 */
const MIN_CHARS_FOR_CLASSIFY = 12;

/**
 * Tiptap extension that hooks the ProseMirror `handlePaste` /
 * `handleDOMEvents.paste` slots and posts the pasted text to the
 * Swift IntakeValve. Returns `false` so Tiptap continues with its
 * native paste handling (the goal is classification, not interception).
 */
export function pasteClassifierBridge(): Extension {
  return Extension.create({
    name: 'epdocPasteClassifierBridge',
    addProseMirrorPlugins(): Plugin[] {
      const editor = this.editor;
      return [
        new Plugin({
          key: PASTE_CLASSIFIER_KEY,
          props: {
            handlePaste(_view: EditorView, event: ClipboardEvent): boolean {
              const text = extractPasteText(event);
              const trimmed = text?.trim() ?? '';
              if (trimmed.length >= MIN_CHARS_FOR_CLASSIFY) {
                postBridge({ type: 'classifyPaste', text: trimmed });
              }

              const plainText = extractPlainPasteText(event);
              const structuredContent = plainText ? parseMarkdownPaste(plainText) : null;
              if (!structuredContent) {
                // Returning false hands the paste back to Tiptap so the
                // user-visible editor state is updated synchronously —
                // IntakeValve runs out-of-band on the Swift side.
                return false;
              }

              const didRun = editor.chain().focus().insertContent(structuredContent).run();
              if (!didRun) return false;
              event.preventDefault();
              postDocumentStats(editor);
              postBridge({ type: 'contentDidChange', json: JSON.stringify(editor.getJSON()) });
              window.epdocOutboundBridge?.flushSync();
              return true;
            },
          },
        }),
      ];
    },
  });
}

function postDocumentStats(editor: Editor): void {
  const storage = editor.storage as unknown as Record<string, unknown>;
  const characterCount = storage.characterCount as
    | { words?: () => number; characters?: () => number }
    | undefined;
  postBridge({
    type: 'documentStatsChanged',
    wordCount: characterCount?.words?.() ?? 0,
    characterCount: characterCount?.characters?.() ?? 0,
  });
}

function extractPlainPasteText(event: ClipboardEvent): string | null {
  const plain = event.clipboardData?.getData('text/plain') ?? '';
  return plain.length > 0 ? plain : null;
}

/**
 * Pull the plain-text payload from a paste event. Falls back to
 * `text/html` (stripped) when no `text/plain` is present. Returns
 * `null` when the clipboard has neither — IntakeValve only operates
 * on textual content (image/file pastes are routed elsewhere).
 */
function extractPasteText(event: ClipboardEvent): string | null {
  const data = event.clipboardData;
  if (!data) return null;
  const plain = data.getData('text/plain');
  if (plain && plain.length > 0) return plain;
  const html = data.getData('text/html');
  if (html && html.length > 0) {
    // Cheap HTML-to-text — the IntakeValve classifier doesn't need
    // perfect fidelity, just enough to bucket the paste. We strip
    // tags here rather than build a DOM (DOMParser would be heavier
    // than the classification round-trip itself).
    return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }
  return null;
}
