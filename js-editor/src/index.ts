// W7.17 — Tiptap WKWebView mount point.
//
// Built by webpack.config.js into dist/editor.js + dist/editor.css.
// build-tiptap-bundle.sh stages dist/ → Epistemos/Resources/Editor/.
// EpdocEditorURLSchemeHandler serves the result via
// epistemos-doc:///editor.html.
//
// Editor extension stack ordered by layer:
//   1. core               — StarterKit + UniqueId
//   2. inline             — Link, Highlight
//   3. block               — Table, TaskList, TaskItem
//   4. W7.7 markdown plugins — Mathematics (KaTeX), Footnotes
//   5. W7.9 custom         — MermaidNode
//   6. W7.17.b chrome     — BubbleMenu, FloatingMenu, DragHandle
//   7. W7.17.a bridge     — slash menu, caret-rect emitter
//   8. CharacterCount     — drives the W7.17 stats badge
//
// Bridge contract documented in README.md + src/bridge/{outbound,inbound}.ts.

import { Editor } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Highlight from '@tiptap/extension-highlight';
import Table from '@tiptap/extension-table';
import TableRow from '@tiptap/extension-table-row';
import TableCell from '@tiptap/extension-table-cell';
import TableHeader from '@tiptap/extension-table-header';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import CharacterCount from '@tiptap/extension-character-count';
import Mathematics from '@tiptap/extension-mathematics';
import BubbleMenu from '@tiptap/extension-bubble-menu';
import FloatingMenu from '@tiptap/extension-floating-menu';
import DragHandle from '@tiptap/extension-drag-handle';
import UniqueId from '@tiptap/extension-unique-id';
import { Footnotes, FootnoteReference, Footnote } from 'tiptap-footnotes';

import { MermaidNode } from './extensions/mermaid-node';
import { CaretRectEmitter } from './extensions/caret-rect-emitter';
import { buildSlashMenu } from './extensions/slash-menu';
import { pasteClassifierBridge } from './extensions/paste-classifier-bridge';
import { postBridge } from './bridge/outbound';
import { installInboundCommands } from './bridge/inbound';

import 'katex/dist/katex.min.css';
import './editor.css';

const mountNode = document.getElementById('editor');
if (!mountNode) {
  throw new Error('Epdoc editor: #editor mount point missing from editor.html');
}

// AP8 — JS-side debounce on the update stream (Wave 13 §"Phase 4 perf —
// AP8 Tiptap update debounce"). Tiptap fires `onTransaction` on every
// keystroke (~50/s during typing); the SwiftUI complexity meter +
// canonical-save pipeline only need ~5/s. Debouncing here drops the
// per-keystroke contentDidChange cost from 50 Hz → ~5 Hz, which the
// Wave 13 perf compass measures as -80% complexity-meter CPU.
//
// 200 ms is the JS-side window — short enough that the user-visible
// "saved" badge still feels live, long enough to coalesce the typical
// burst-typing cadence. The Swift side still runs its own 300 ms save
// debounce (see `EpdocEditorSavePipeline`); the two layers stack so
// the canonical-save invariant is preserved.
const CONTENT_DID_CHANGE_DEBOUNCE_MS = 200;
let contentDidChangeTimer: ReturnType<typeof setTimeout> | null = null;
let pendingDocJSON: string | null = null;

function scheduleContentDidChange(json: string): void {
  pendingDocJSON = json;
  if (contentDidChangeTimer !== null) return;
  contentDidChangeTimer = setTimeout(() => {
    contentDidChangeTimer = null;
    const json = pendingDocJSON;
    pendingDocJSON = null;
    if (json === null) return;
    postBridge({ type: 'contentDidChange', json });
  }, CONTENT_DID_CHANGE_DEBOUNCE_MS);
}

const editor = new Editor({
  element: mountNode,
  extensions: [
    StarterKit.configure({ history: true }),
    UniqueId.configure({
      types: ['heading', 'paragraph', 'codeBlock', 'blockquote'],
    }),
    Link.configure({ openOnClick: false }),
    Highlight,
    Table.configure({ resizable: true }),
    TableRow,
    TableCell,
    TableHeader,
    TaskList,
    TaskItem.configure({ nested: true }),
    CharacterCount,
    Mathematics,
    Footnotes,
    FootnoteReference,
    Footnote,
    MermaidNode,
    BubbleMenu.configure({ pluginKey: 'epdocBubble' }),
    FloatingMenu.configure({ pluginKey: 'epdocFloating' }),
    DragHandle,
    CaretRectEmitter.configure({
      onChange: (rect, selection) => {
        postBridge({
          type: 'caretChanged',
          rect: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
          selection,
        });
      },
    }),
    buildSlashMenu({
      onActivate: () => {
        // The Suggestion plugin already posts requestSlashMenu; this
        // hook is reserved for future inline analytics.
      },
    }),
    pasteClassifierBridge(),
  ],
  content: { type: 'doc', content: [{ type: 'paragraph' }] },
  onUpdate: ({ editor: ed }) => {
    // AP8 — debounce content-change emissions. We use `onUpdate`
    // rather than `onTransaction` so selection-only transactions
    // (caret moves, focus changes) don't burn the timer; those are
    // already covered by CaretRectEmitter.
    scheduleContentDidChange(JSON.stringify(ed.getJSON()));
  },
  onCreate: () => {
    postBridge({ type: 'editorReady' });
  },
});

// Expose for the Swift inbound bridge + dev console.
window.epdocEditor = editor;
installInboundCommands(editor);
