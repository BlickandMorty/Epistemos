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
import { postBridge } from './bridge/outbound';
import { installInboundCommands } from './bridge/inbound';

import 'katex/dist/katex.min.css';
import './editor.css';

const mountNode = document.getElementById('editor');
if (!mountNode) {
  throw new Error('Epdoc editor: #editor mount point missing from editor.html');
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
  ],
  content: { type: 'doc', content: [{ type: 'paragraph' }] },
  onTransaction: ({ editor: ed }) => {
    postBridge({
      type: 'contentDidChange',
      json: JSON.stringify(ed.getJSON()),
    });
  },
  onCreate: () => {
    postBridge({ type: 'editorReady' });
  },
});

// Expose for the Swift inbound bridge + dev console.
window.epdocEditor = editor;
installInboundCommands(editor);
