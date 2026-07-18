// W7.17 — Swift → JS bridge.
//
// Installs window.epistemos.* command surface that EpdocEditorCommand
// (Epistemos/Engine/EpdocEditorBridge.swift) calls via
// WKWebView.evaluateJavaScript. Each command dispatches into the live
// Tiptap editor; unknown commands return false (callers can fall back).

import type { Editor } from '@tiptap/core';
import '@tiptap/markdown';
import { Fragment, type Node as ProseMirrorNode, type ResolvedPos } from '@tiptap/pm/model';
import { TextSelection } from '@tiptap/pm/state';
import type { RectPayload, SelectionPayload } from './outbound';
import { postBridge } from './outbound';
import { applySlashChoice } from '../extensions/slash-menu';
import {
  beginLoad,
  currentLoadEpoch,
  endLoad,
  EPOCH_META,
  HOST_LOAD_META,
  type LoadEpoch,
} from './document-load-state';
import { completeImageAssetRequest } from '../extensions/image-asset-bridge';
import {
  clearFindQuery,
  findNext,
  findPrevious,
  replaceAll,
  replaceCurrent,
  setFindQuery,
} from '../extensions/find-replace';

export interface InboundCallbacks {
  /** Re-emit a bubble-menu request after the host accepts a slash choice. */
  emitBubbleMenu?: (selection: SelectionPayload, anchor: RectPayload) => void;
  resetMarkdownWritebackBaseline?: (editor: Editor, markdown: string) => void;
  postContentSnapshot?: (editor: Editor) => void;
  postMarkdownSnapshot?: (editor: Editor) => void;
  setMarkdownProjectionMode?: (enabled: boolean) => void;
}

export function installInboundCommands(editor: Editor, callbacks: InboundCallbacks = {}): void {
  function settleHostLoad(): void {
    queueMicrotask(() => {
      const epoch = endLoad(editor.view);
      postBridge({ type: 'loadSettled', epoch });
      postDocumentStats(editor);
      requestAnimationFrame(() => postDocumentStats(editor));
    });
  }

  const epistemos: Window['epistemos'] = {
    setContent(json: string, epoch?: number): void {
      try {
        const parsed = JSON.parse(json);
        callbacks.setMarkdownProjectionMode?.(false);
        const loadEpoch = beginLoad(editor.view, undefined, normalizeLoadEpoch(epoch));
        editor
          .chain()
          .setMeta(HOST_LOAD_META, true)
          .setMeta(EPOCH_META, loadEpoch)
          .setContent(parsed, { emitUpdate: false })
          .run();
        callbacks.resetMarkdownWritebackBaseline?.(editor, editor.getMarkdown?.() ?? '');
        settleHostLoad();
      } catch (e) {
        console.warn('[epdoc inbound] setContent: invalid JSON', e);
      }
    },

    getMarkdown(): string {
      return typeof editor.getMarkdown === 'function' ? editor.getMarkdown() : '';
    },

    setMarkdown(markdown: string, epoch?: number): void {
      try {
        callbacks.setMarkdownProjectionMode?.(true);
        const loadEpoch = beginLoad(editor.view, undefined, normalizeLoadEpoch(epoch));
        editor
          .chain()
          .setMeta(HOST_LOAD_META, true)
          .setMeta(EPOCH_META, loadEpoch)
          .setContent(markdown, { emitUpdate: false, contentType: 'markdown' })
          .run();
        callbacks.resetMarkdownWritebackBaseline?.(editor, markdown);
        settleHostLoad();
      } catch (e) {
        console.warn('[epdoc inbound] setMarkdown: invalid Markdown', e);
      }
    },

    replaceDocumentTitle(title: string, epoch?: number): boolean {
      if (title.trim().length === 0) return false;
      const heading = firstTopLevelHeading(editor);
      if (!heading) return false;

      const scrollingElement = document.scrollingElement;
      const scrollLeft = scrollingElement?.scrollLeft ?? 0;
      const scrollTop = scrollingElement?.scrollTop ?? 0;
      const loadEpoch = beginLoad(editor.view, undefined, normalizeLoadEpoch(epoch));
      const from = heading.position + 1;
      const to = from + heading.node.content.size;
      const transaction = editor.state.tr
        .insertText(title, from, to)
        .setMeta(HOST_LOAD_META, true)
        .setMeta(EPOCH_META, loadEpoch)
        .setMeta('addToHistory', false);
      editor.view.dispatch(transaction);
      callbacks.resetMarkdownWritebackBaseline?.(editor, editor.getMarkdown?.() ?? '');
      settleHostLoad();
      requestAnimationFrame(() => {
        if (scrollingElement?.isConnected) {
          scrollingElement.scrollTo(scrollLeft, scrollTop);
        }
      });
      return true;
    },

    setContentWidth(value: string): void {
      document.documentElement.style.setProperty(
        '--epdoc-content-max-width',
        sanitizeContentWidth(value),
      );
    },

    flushDocumentSnapshot(): void {
      postDocumentStats(editor);
      postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
    },

    setFindQuery(query: string, caseSensitive = false): boolean {
      return setFindQuery(editor, query, caseSensitive === true);
    },

    findNext(query: string, caseSensitive = false): boolean {
      return findNext(editor, query, caseSensitive === true);
    },

    findPrevious(query: string, caseSensitive = false): boolean {
      return findPrevious(editor, query, caseSensitive === true);
    },

    replaceCurrent(query: string, replacement: string, caseSensitive = false): boolean {
      const didRun = replaceCurrent(editor, query, replacement, caseSensitive === true);
      if (didRun) {
        postDocumentStats(editor);
        postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
      }
      return didRun;
    },

    replaceAll(query: string, replacement: string, caseSensitive = false): boolean {
      const didRun = replaceAll(editor, query, replacement, caseSensitive === true);
      if (didRun) {
        postDocumentStats(editor);
        postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
      }
      return didRun;
    },

    clearFindHighlights(): void {
      clearFindQuery(editor);
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
      const didRun = applySlashChoice(editor, blockType);
      if (didRun) {
        postDocumentStats(editor);
        postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
      }
    },

    dismissBubbleMenu(): void {
      // BubbleMenu is selection-driven; collapsing the selection hides
      // it without a dedicated dismiss command.
      const { from } = editor.state.selection;
      editor.commands.setTextSelection(from);
    },

    runCommand(name: string, ...args: unknown[]): boolean {
      if (name === 'setLink') {
        const href = linkHrefFromArgs(args) ?? (args.length === 0 ? window.prompt('Link URL') : null);
        if (!href) return false;
        const didRun = editor.chain().focus().extendMarkRange('link').setLink({ href }).run();
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'insertEpdocImage') {
        const image = imageArgs(args);
        if (!image) return false;
        const didRun = editor.chain().focus().insertEpdocImage(image).run();
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'requestHTMLWorkspace') {
        editor.commands.focus();
        postBridge({
          type: 'requestHTMLWorkspace',
          source: 'dock',
        });
        return true;
      }
      if (name === 'insertEpdocFrontmatter') {
        const didRun = insertEpdocFrontmatter(editor);
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'toggleCodeBlock') {
        const didRun = toggleEpdocCodeBlock(editor);
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'setHeadingLevel') {
        const level = headingLevelFromArgs(args);
        if (level === null) return false;
        const didRun = setHeadingLevel(editor, level);
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'setParagraph') {
        const didRun = setParagraph(editor);
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      if (name === 'completeImageAssetRequest') {
        const response = imageAssetResponseArgs(args);
        if (!response) return false;
        const didRun = completeImageAssetRequest(editor, response.requestID, response.src);
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      const didRun = runEditorCommand(editor, name, args);
      if (didRun !== null) {
        if (didRun) {
          postDocumentStats(editor);
          postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot);
        }
        return didRun;
      }
      console.warn(`[epdoc inbound] runCommand: '${name}' is not a Tiptap command`);
      return false;
    },
  };
  window.epistemos = epistemos;
}

function firstTopLevelHeading(
  editor: Editor,
): { position: number; node: ProseMirrorNode } | null {
  let result: { position: number; node: ProseMirrorNode } | null = null;
  editor.state.doc.forEach((node, position) => {
    if (result || node.type.name !== 'heading' || node.attrs.level !== 1) return;
    result = { position, node };
  });
  return result;
}

function normalizeLoadEpoch(epoch: number | undefined): LoadEpoch | undefined {
  if (epoch === undefined || !Number.isFinite(epoch) || epoch < 0) return undefined;
  return Math.trunc(epoch) as LoadEpoch;
}

function sanitizeContentWidth(value: string): string {
  const trimmed = value.trim().toLowerCase();
  if (trimmed === 'none') return 'none';

  const match = /^(\d{2,4})px$/.exec(trimmed);
  if (!match) return '720px';

  const pixels = Number(match[1]);
  if (!Number.isFinite(pixels) || pixels < 560 || pixels > 1600) return '720px';
  return `${pixels}px`;
}

function setHeadingLevel(editor: Editor, level: number): boolean {
  if (!Number.isInteger(level) || level < 1 || level > 6) return false;

  const { state, view } = editor;
  const depth = textblockDepth(state.selection.$from);
  if (depth === null || depth <= 0) return false;
  if (splitTextblockAroundHardBreaks(editor, depth)) {
    return setHeadingLevel(editor, level);
  }

  const node = state.selection.$from.node(depth);
  const headingType = state.schema.nodes.heading;
  const paragraphType = state.schema.nodes.paragraph;
  if (!headingType || !paragraphType || !node.isTextblock) return false;

  const position = state.selection.$from.before(depth);
  const baseAttrs: Record<string, unknown> = { ...(node.attrs as Record<string, unknown>) };
  delete baseAttrs.level;

  const isSameHeading = node.type === headingType && node.attrs.level === level;
  const nextType = isSameHeading ? paragraphType : headingType;
  const nextAttrs = isSameHeading ? baseAttrs : { ...baseAttrs, level };
  const tr = state.tr.setNodeMarkup(position, nextType, nextAttrs).scrollIntoView();
  view.dispatch(tr);
  view.focus();
  return true;
}

function setParagraph(editor: Editor): boolean {
  const { state, view } = editor;
  const depth = textblockDepth(state.selection.$from);
  if (depth === null || depth <= 0) return false;
  if (splitTextblockAroundHardBreaks(editor, depth)) {
    return setParagraph(editor);
  }

  const node = state.selection.$from.node(depth);
  const paragraphType = state.schema.nodes.paragraph;
  if (!paragraphType || !node.isTextblock) return false;
  if (node.type === paragraphType) {
    view.focus();
    return true;
  }

  const position = state.selection.$from.before(depth);
  const baseAttrs: Record<string, unknown> = { ...(node.attrs as Record<string, unknown>) };
  delete baseAttrs.level;
  const tr = state.tr.setNodeMarkup(position, paragraphType, baseAttrs).scrollIntoView();
  view.dispatch(tr);
  view.focus();
  return true;
}

function textblockDepth($pos: ResolvedPos): number | null {
  for (let depth = $pos.depth; depth >= 0; depth -= 1) {
    if ($pos.node(depth).isTextblock) return depth;
  }
  return null;
}

function splitTextblockAroundHardBreaks(editor: Editor, depth: number): boolean {
  const { state, view } = editor;
  const node = state.selection.$from.node(depth);
  if (!node.isTextblock || node.childCount === 0) return false;

  let sawHardBreak = false;
  let current: ProseMirrorNode[] = [];
  const pieces: ProseMirrorNode[] = [];
  node.forEach((child) => {
    if (child.type.name !== 'hardBreak') {
      current.push(child);
      return;
    }
    sawHardBreak = true;
    pieces.push(node.type.create(
      node.attrs,
      current.length > 0 ? Fragment.fromArray(current) : undefined,
    ));
    current = [];
  });
  if (!sawHardBreak) return false;

  pieces.push(node.type.create(
    node.attrs,
    current.length > 0 ? Fragment.fromArray(current) : undefined,
  ));

  const from = state.selection.$from.before(depth);
  const to = from + node.nodeSize;
  const tr = state.tr.replaceWith(from, to, Fragment.fromArray(pieces)).scrollIntoView();
  view.dispatch(tr);
  view.focus();
  return true;
}

function headingLevelFromArgs(args: unknown[]): number | null {
  const first = args[0];
  if (typeof first !== 'object' || first === null) return null;
  const rawLevel = (first as { level?: unknown }).level;
  return typeof rawLevel === 'number' && Number.isInteger(rawLevel) ? rawLevel : null;
}

function toggleEpdocCodeBlock(editor: Editor): boolean {
  const { state } = editor;
  const { from, to, empty, $from, $to } = state.selection;
  if (empty) {
    return editor.chain().focus().toggleCodeBlock().run();
  }

  const selectedText = state.doc.textBetween(from, to, '\n').trimEnd();
  if (selectedText.length === 0) {
    return editor.chain().focus().toggleCodeBlock().run();
  }

  const { schema } = state;
  const codeBlockType = schema.nodes.codeBlock;
  const paragraphType = schema.nodes.paragraph;
  if (!codeBlockType || !paragraphType) {
    return editor.chain().focus().toggleCodeBlock().run();
  }

  const codeBlock = codeBlockType.create(
    { language: 'swift' },
    schema.text(selectedText),
  );
  const paragraph = paragraphType.create();
  const blockRange = $from.blockRange($to);
  const replaceFrom = blockRange?.start ?? from;
  const replaceTo = blockRange?.end ?? to;
  let tr = state.tr.replaceWith(replaceFrom, replaceTo, codeBlock);
  const paragraphPosition = tr.mapping.map(replaceFrom) + codeBlock.nodeSize;
  tr = tr.insert(paragraphPosition, paragraph);
  tr = tr.setSelection(TextSelection.near(tr.doc.resolve(paragraphPosition + 1)));
  editor.view.dispatch(tr.scrollIntoView());
  editor.view.focus();
  return true;
}

function insertEpdocFrontmatter(editor: Editor): boolean {
  if (documentStartsWithFrontmatter(editor)) {
    editor.commands.focus('start');
    return true;
  }

  const created = new Date().toISOString().slice(0, 10);
  const source = [
    '---',
    'title: Untitled',
    'status: draft',
    'tags: []',
    `created: ${created}`,
    '---',
  ].join('\n');

  return editor.chain().focus('start').insertContentAt(0, [
    {
      type: 'codeBlock',
      attrs: { language: 'yaml' },
      content: [{ type: 'text', text: source }],
    },
    { type: 'paragraph' },
  ]).run();
}

function documentStartsWithFrontmatter(editor: Editor): boolean {
  const first = editor.state.doc.firstChild;
  if (!first || first.type.name !== 'codeBlock') return false;
  const text = first.textContent.trimStart();
  return text.startsWith('---\n') && /\n---\s*$/.test(text);
}

function postDocumentStats(editor: Editor): void {
  postBridge({
    type: 'documentStatsChanged',
    epoch: currentLoadEpoch(editor.state),
    wordCount: editor.storage.characterCount.words(),
    characterCount: editor.storage.characterCount.characters(),
  });
}

function postDocumentSnapshot(
  editor: Editor,
  postContentSnapshot?: (editor: Editor) => void,
  postMarkdownSnapshot?: (editor: Editor) => void,
): void {
  const epoch = currentLoadEpoch(editor.state);
  if (postContentSnapshot) {
    postContentSnapshot(editor);
  } else {
    postBridge({
      type: 'contentDidChange',
      epoch,
      json: JSON.stringify(editor.getJSON()),
    });
  }
  if (typeof editor.getMarkdown === 'function') {
    if (postMarkdownSnapshot) {
      postMarkdownSnapshot(editor);
    } else {
      postBridge({
        type: 'markdownDidChange',
        epoch,
        markdown: editor.getMarkdown(),
      });
    }
  }
}

function runEditorCommand(editor: Editor, name: string, args: unknown[]): boolean | null {
  if (name === 'undo' || name === 'redo') {
    const historyCommand = (editor.commands as Record<string, unknown>)[name];
    if (typeof historyCommand === 'function') {
      return Boolean((historyCommand as (...a: unknown[]) => boolean)(...args));
    }
    return null;
  }

  const chain = editor.chain().focus() as unknown as Record<string, unknown>;
  const chainedCommand = chain[name];
  if (typeof chainedCommand === 'function') {
    const result = (chainedCommand as (...a: unknown[]) => unknown).apply(chain, args);
    if (isRunnable(result)) return result.run();
  }

  const command = (editor.commands as Record<string, unknown>)[name];
  if (typeof command === 'function') {
    return Boolean((command as (...a: unknown[]) => boolean)(...args));
  }
  return null;
}

function isRunnable(value: unknown): value is { run: () => boolean } {
  return typeof value === 'object'
    && value !== null
    && typeof (value as { run?: unknown }).run === 'function';
}

function linkHrefFromArgs(args: unknown[]): string | null {
  const first = args[0];
  if (typeof first !== 'object' || first === null) return null;
  const href = (first as { href?: unknown }).href;
  if (typeof href !== 'string') return null;
  const trimmed = href.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function imageArgs(args: unknown[]): { src: string; alt?: string; title?: string } | null {
  const first = args[0];
  if (typeof first !== 'object' || first === null) return null;
  const src = (first as { src?: unknown }).src;
  if (typeof src !== 'string') return null;
  const trimmed = src.trim();
  if (trimmed.length === 0) return null;
  const alt = (first as { alt?: unknown }).alt;
  const title = (first as { title?: unknown }).title;
  return {
    src: trimmed,
    alt: typeof alt === 'string' ? alt : '',
    title: typeof title === 'string' ? title : '',
  };
}

function imageAssetResponseArgs(args: unknown[]): { requestID: string; src: string } | null {
  const first = args[0];
  if (typeof first !== 'object' || first === null) return null;
  const requestID = (first as { requestID?: unknown }).requestID;
  const src = (first as { src?: unknown }).src;
  if (typeof requestID !== 'string' || typeof src !== 'string') return null;
  const trimmedRequestID = requestID.trim();
  const trimmedSrc = src.trim();
  if (trimmedRequestID.length === 0 || trimmedSrc.length === 0) return null;
  return { requestID: trimmedRequestID, src: trimmedSrc };
}
