// Deterministic Tiptap paste handling for .epdoc documents.
//
// Structured Markdown is inserted immediately. Ordinary content returns
// `false` so Tiptap performs its native paste path without delay or a host
// side channel.

import { Extension } from '@tiptap/core';
import type { Editor } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import { currentLoadEpoch } from '../bridge/document-load-state';
import { postBridge } from '../bridge/outbound';
import { parseMarkdownPaste } from '../markdown/markdown-paste';

const PASTE_HANDLING_KEY = new PluginKey('epdocPasteHandling');

/**
 * Tiptap extension that preserves Markdown paste enrichment while leaving
 * ordinary paste handling to Tiptap.
 */
export function pasteHandlingBridge(): Extension {
  return Extension.create({
    name: 'epdocPasteHandlingBridge',
    addProseMirrorPlugins(): Plugin[] {
      const editor = this.editor;
      return [
        new Plugin({
          key: PASTE_HANDLING_KEY,
          props: {
            handlePaste(_view: EditorView, event: ClipboardEvent): boolean {
              const plainText = extractPlainPasteText(event);
              const structuredContent = plainText ? parseMarkdownPaste(plainText) : null;
              if (!structuredContent) {
                // Native handling keeps ordinary paste synchronous.
                return false;
              }

              const didRun = editor.chain().focus().insertContent(structuredContent).run();
              if (!didRun) return false;
              event.preventDefault();
              postDocumentStats(editor);
              postBridge({
                type: 'contentDidChange',
                epoch: currentLoadEpoch(editor.state),
                json: JSON.stringify(editor.getJSON()),
              });
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
    epoch: currentLoadEpoch(editor.state),
    wordCount: characterCount?.words?.() ?? 0,
    characterCount: characterCount?.characters?.() ?? 0,
  });
}

function extractPlainPasteText(event: ClipboardEvent): string | null {
  const plain = event.clipboardData?.getData('text/plain') ?? '';
  return plain.length > 0 ? plain : null;
}
