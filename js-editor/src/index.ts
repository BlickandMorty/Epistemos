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
//   3. block               — CodeBlockLowlight, Table, TaskList, TaskItem
//   4. W7.7 markdown plugins — Mathematics (KaTeX), Footnotes
//   5. W7.9 custom         — EpdocChartNode, legacy inert diagrams
//   6. W7.17.b chrome     — BubbleMenu, FloatingMenu, DragHandle
//   7. W7.17.a bridge     — slash menu, caret-rect emitter
//   8. CharacterCount     — drives the W7.17 stats badge
//
// Bridge contract documented in README.md + src/bridge/{outbound,inbound}.ts.

import { Editor } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Highlight from '@tiptap/extension-highlight';
import { Table } from '@tiptap/extension-table';
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
import { Placeholder } from '@tiptap/extensions/placeholder';
import { Markdown } from '@tiptap/markdown';
import { Footnotes, FootnoteReference, Footnote } from 'tiptap-footnotes';

import { EpdocCodeBlock } from './extensions/code-block-node';
import { EpdocBlockquote } from './extensions/blockquote-node';
import { EpdocListItem } from './extensions/list-item-node';
import { EpdocChartNode } from './extensions/chart-node';
import { EpdocImageNode } from './extensions/image-node';
import { LegacyDiagramNode } from './extensions/legacy-diagram-node';
import { imageAssetBridge } from './extensions/image-asset-bridge';
import { CalloutNode } from './extensions/callout-node';
import { epdocMarkdownInputRules } from './extensions/markdown-input-rules';
import { EpdocFindReplace } from './extensions/find-replace';
import { CaretRectEmitter } from './extensions/caret-rect-emitter';
import { buildSlashMenu } from './extensions/slash-menu';
import { pasteHandlingBridge } from './extensions/paste-classifier-bridge';
import { EpdocLink, EpdocWikiLinkMarkdown } from './markdown/epdoc-markdown-nodes';
import { MarkdownWritebackTracker } from './markdown/writeback-tracker';
import { postBridge } from './bridge/outbound';
import { installInboundCommands } from './bridge/inbound';
import {
  currentLoadEpoch,
  hasHostDocumentLoaded,
  HOST_LOAD_META,
  isDocumentLoadSettling,
  LoadStateExtension,
} from './bridge/document-load-state';

import 'katex/dist/katex.min.css';
import './editor.css';

const mountNode = document.getElementById('editor');
if (!mountNode) {
  throw new Error('Epdoc editor: #editor mount point missing from editor.html');
}
const editorRoot = mountNode;

// AP8 — JS-side debounce on the update stream. Tiptap can fire
// `onTransaction` on every keystroke; the host only needs coalesced change
// notices and small Markdown writeback regions during ordinary typing.
//
// 200 ms is the JS-side window — short enough that the user-visible
// "saved" badge still feels live, long enough to coalesce the typical
// burst-typing cadence. The Swift side still runs its own 300 ms save
// debounce (see `EpdocEditorSavePipeline`); the two layers stack so
// the canonical-save invariant is preserved.
const CONTENT_DID_CHANGE_DEBOUNCE_MS = 200;
const DOCUMENT_STATS_DEBOUNCE_MS = 250;
const ADAPTIVE_HEADING_SYNC_DEBOUNCE_MS = 750;
const LARGE_DOCUMENT_NODE_SIZE = 200_000;
const MARKDOWN_FULL_SNAPSHOT_IDLE_MS = 1_500;
let contentDidChangeTimer: ReturnType<typeof setTimeout> | null = null;
let documentStatsTimer: ReturnType<typeof setTimeout> | null = null;
let adaptiveHeadingSizeTimer: ReturnType<typeof setTimeout> | null = null;
let deferredMarkdownSnapshotTimer: ReturnType<typeof setTimeout> | null = null;
let pendingContentEditor: Editor | null = null;
let pendingStatsEditor: Editor | null = null;
let pendingDeferredMarkdownEditor: Editor | null = null;
let adaptiveHeadingSizeFrame: number | null = null;
let markdownProjectionMode = false;
const markdownWritebackTracker = new MarkdownWritebackTracker();

function editorIsLive(ed: Editor | null): ed is Editor {
  return ed !== null && (ed as { isDestroyed?: boolean }).isDestroyed !== true;
}

function scheduleContentDidChange(ed: Editor): void {
  pendingContentEditor = ed;
  if (contentDidChangeTimer !== null) return;
  contentDidChangeTimer = setTimeout(() => {
    contentDidChangeTimer = null;
    const editor = pendingContentEditor;
    pendingContentEditor = null;
    if (!editorIsLive(editor)) return;
    if (markdownProjectionMode) {
      postMarkdownDidChange(editor, { preferWriteback: true });
      return;
    }
    postBridge({
      type: 'contentDidChange',
      epoch: currentLoadEpoch(editor.state),
      json: JSON.stringify(editor.getJSON()),
    });
    postMarkdownDidChange(editor, { preferWriteback: false });
  }, CONTENT_DID_CHANGE_DEBOUNCE_MS);
}

function postMarkdownDidChange(
  ed: Editor,
  options: { preferWriteback?: boolean } = {},
): void {
  if (typeof ed.getMarkdown !== 'function') return;
  if (options.preferWriteback) {
    const writeback = markdownWritebackTracker.consume(ed) ?? undefined;
    if (writeback) {
      postBridge({
        type: 'markdownDidChange',
        epoch: currentLoadEpoch(ed.state),
        markdown: '',
        writeback,
      });
      return;
    }
    if (documentIsLarge(ed)) {
      scheduleDeferredFullMarkdownSnapshot(ed);
      return;
    }
  }
  const markdown = markdownSnapshotWithVisibleTextFallback(ed);
  const writeback = markdownWritebackTracker.consume(ed, markdown) ?? undefined;
  postBridge({
    type: 'markdownDidChange',
    epoch: currentLoadEpoch(ed.state),
    markdown,
    ...(writeback ? { writeback } : {}),
  });
}

function postContentDidChangeSnapshot(ed: Editor): void {
  if (markdownProjectionMode) return;
  postBridge({
    type: 'contentDidChange',
    epoch: currentLoadEpoch(ed.state),
    json: JSON.stringify(ed.getJSON()),
  });
}

function documentIsLarge(ed: Editor): boolean {
  return ed.state.doc.content.size >= LARGE_DOCUMENT_NODE_SIZE;
}

function scheduleDeferredFullMarkdownSnapshot(ed: Editor): void {
  pendingDeferredMarkdownEditor = ed;
  if (deferredMarkdownSnapshotTimer !== null) return;
  deferredMarkdownSnapshotTimer = setTimeout(() => {
    deferredMarkdownSnapshotTimer = null;
    const editor = pendingDeferredMarkdownEditor;
    pendingDeferredMarkdownEditor = null;
    if (!editorIsLive(editor)) return;
    postMarkdownDidChange(editor, { preferWriteback: false });
  }, MARKDOWN_FULL_SNAPSHOT_IDLE_MS);
}

function markdownSnapshotWithVisibleTextFallback(ed: Editor): string {
  const markdown = ed.getMarkdown();
  if (markdownBodyText(markdown).trim().length > 0) return markdown;
  const visibleText = ed.state.doc.textBetween(0, ed.state.doc.content.size, '\n\n', '\n\n');
  if (visibleText.trim().length > 0) {
    return visibleText;
  }
  return markdown;
}

function markdownBodyText(markdown: string): string {
  if (!markdown.startsWith('---')) return markdown;
  const closingFence = markdown.indexOf('\n---', 3);
  if (closingFence === -1) return markdown;
  const bodyStart = markdown.indexOf('\n', closingFence + 4);
  if (bodyStart === -1) return '';
  return markdown.slice(bodyStart + 1);
}

function postDocumentStats(ed: Editor): void {
  postBridge({
    type: 'documentStatsChanged',
    epoch: currentLoadEpoch(ed.state),
    wordCount: ed.storage.characterCount.words(),
    characterCount: ed.storage.characterCount.characters(),
  });
}

function scheduleDocumentStats(ed: Editor): void {
  pendingStatsEditor = ed;
  if (documentStatsTimer !== null) return;
  documentStatsTimer = setTimeout(() => {
    documentStatsTimer = null;
    const editor = pendingStatsEditor;
    pendingStatsEditor = null;
    if (!editorIsLive(editor)) return;
    postDocumentStats(editor);
  }, DOCUMENT_STATS_DEBOUNCE_MS);
}

function scheduleAdaptiveHeadingSizeSync(): void {
  if (adaptiveHeadingSizeTimer !== null) return;
  adaptiveHeadingSizeTimer = setTimeout(() => {
    adaptiveHeadingSizeTimer = null;
    scheduleAdaptiveHeadingSizeSyncFrame();
  }, ADAPTIVE_HEADING_SYNC_DEBOUNCE_MS);
}

function scheduleAdaptiveHeadingSizeSyncFrame(): void {
  if (adaptiveHeadingSizeFrame !== null) return;
  adaptiveHeadingSizeFrame = window.requestAnimationFrame(() => {
    adaptiveHeadingSizeFrame = null;
    syncAdaptiveHeadingSizes();
  });
}

function syncAdaptiveHeadingSizes(): void {
  editorRoot.querySelectorAll<HTMLElement>('h1, h2, h3').forEach((heading) => {
    const density = adaptiveHeadingSizeDensity(heading);
    if (density === null) {
      heading.removeAttribute('data-epdoc-heading-size');
    } else {
      heading.setAttribute('data-epdoc-heading-size', density);
    }
  });
}

function adaptiveHeadingSizeDensity(heading: HTMLElement): 'medium' | 'long' | 'xlong' | null {
  const level = Number(heading.tagName.slice(1));
  const textLength = (heading.textContent ?? '').trim().replace(/\s+/g, ' ').length;
  const limits = headingSizeLimits(level);
  if (textLength > limits.long) return 'xlong';
  if (textLength > limits.medium) return 'long';
  if (textLength > limits.full) return 'medium';
  return null;
}

function headingSizeLimits(level: number): { full: number; medium: number; long: number } {
  if (level === 2) return { full: 36, medium: 64, long: 96 };
  if (level === 3) return { full: 44, medium: 72, long: 110 };
  return { full: 24, medium: 44, long: 72 };
}

const editor = new Editor({
  element: mountNode,
  extensions: [
    StarterKit.configure({
      codeBlock: false,
      blockquote: false,
      link: false,
      listItem: false,
    }),
    EpdocBlockquote,
    EpdocListItem,
    UniqueId.configure({
      types: ['heading', 'paragraph', 'codeBlock', 'blockquote'],
    }),
    Placeholder.configure({
      placeholder: 'Start writing your Epistemos document...',
      showOnlyCurrent: false,
    }),
    EpdocLink.configure({
      openOnClick: false,
      protocols: ['epistemos-doc'],
    }),
    Highlight,
    EpdocCodeBlock,
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
    EpdocChartNode,
    LegacyDiagramNode,
    EpdocImageNode,
    CalloutNode,
    EpdocWikiLinkMarkdown,
    Markdown.configure({
      indentation: { style: 'space', size: 2 },
      markedOptions: { breaks: false, gfm: true },
    }),
    EpdocFindReplace,
    LoadStateExtension,
    BubbleMenu.configure({ pluginKey: 'epdocBubble' }),
    FloatingMenu.configure({ pluginKey: 'epdocFloating' }),
    DragHandle,
    CaretRectEmitter.configure({
      onChange: (rect, selection, marks) => {
        postBridge({
          type: 'caretChanged',
          rect: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
          selection,
          marks,
        });
      },
    }),
    buildSlashMenu({
      onActivate: () => {
        // The Suggestion plugin already posts requestSlashMenu; this
        // hook is reserved for future inline analytics.
      },
    }),
    imageAssetBridge(),
    epdocMarkdownInputRules(),
    pasteHandlingBridge(),
  ],
  content: { type: 'doc', content: [{ type: 'paragraph' }] },
  onUpdate: ({ editor: ed, transaction }) => {
    // AP8 — debounce content-change emissions. We use `onUpdate`
    // rather than `onTransaction` so selection-only transactions
    // (caret moves, focus changes) don't burn the timer; those are
    // already covered by CaretRectEmitter.
    if (
      transaction.getMeta(HOST_LOAD_META) !== true
      && hasHostDocumentLoaded()
      && !isDocumentLoadSettling(ed.state)
    ) {
      scheduleContentDidChange(ed);
    }
    scheduleDocumentStats(ed);
    if (ed.state.doc.content.size < LARGE_DOCUMENT_NODE_SIZE) {
      scheduleAdaptiveHeadingSizeSync();
    }
  },
  onTransaction: ({ editor: ed, transaction }) => {
    markdownWritebackTracker.recordTransaction(ed, transaction);
  },
  onCreate: ({ editor: ed }) => {
    postDocumentStats(ed);
    scheduleAdaptiveHeadingSizeSync();
    postBridge({ type: 'editorReady' });
  },
});

// Expose for the Swift inbound bridge + dev console.
window.epdocEditor = editor;
installInboundCommands(editor, {
  resetMarkdownWritebackBaseline: (ed, markdown) => {
    markdownWritebackTracker.reset(ed, markdown);
  },
  postContentSnapshot: postContentDidChangeSnapshot,
  postMarkdownSnapshot: (ed) => postMarkdownDidChange(ed, { preferWriteback: false }),
  setMarkdownProjectionMode: (enabled) => {
    markdownProjectionMode = enabled;
  },
});
