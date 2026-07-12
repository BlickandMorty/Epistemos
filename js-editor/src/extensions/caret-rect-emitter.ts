// W7.17.a — caret-rect emitter (the bridge that lets SwiftUI dock its
// chrome panels next to the live document area).
//
// A ProseMirror plugin that listens for selection changes and pings the
// Swift host with the caret's screen-rect on every transaction. The
// Swift side (W7.17.a SwiftUI hybrid surface) consumes these to
// position the right-inspector / floating tools / complexity meter
// next to the active block.
//
// Throttled at one emission per animation frame so a flurry of edits
// (paste, bulk-replace, undo) doesn't flood the bridge.

import { Extension } from '@tiptap/core';
import { Plugin, PluginKey, type EditorState } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import type { ActiveMarksPayload, RectPayload, SelectionPayload } from '../bridge/outbound';

export interface CaretRectEmitterOptions {
  onChange?: (rect: DOMRect, selection: SelectionPayload, marks: ActiveMarksPayload) => void;
}

const CARET_RECT_KEY = new PluginKey('epdocCaretRect');
const MAX_SELECTION_TEXT_CHARACTERS = 4000;

export const CaretRectEmitter = Extension.create<CaretRectEmitterOptions>({
  name: 'epdocCaretRectEmitter',

  addOptions() {
    return { onChange: undefined };
  },

  addProseMirrorPlugins(): Plugin[] {
    let pendingFrame: number | null = null;
    let lastEmittedKey: string | null = null;
    const onChange = this.options.onChange;
    if (!onChange) return [];

    return [
      new Plugin({
        key: CARET_RECT_KEY,
        view(view: EditorView) {
          // Initial emission so the SwiftUI side has a starting position.
          schedule(view);
          return {
            update: (newView) => schedule(newView),
            destroy: () => {
              if (pendingFrame !== null) {
                cancelAnimationFrame(pendingFrame);
                pendingFrame = null;
              }
            },
          };
        },
      }),
    ];

    function schedule(view: EditorView): void {
      if (pendingFrame !== null) return;
      pendingFrame = requestAnimationFrame(() => {
        pendingFrame = null;
        emit(view);
      });
    }

    function emit(view: EditorView): void {
      const { from, to, empty } = view.state.selection;
      const marks = activeMarks(view.state);
      const selectedText = selectedTextForContext(view.state);
      const selectionKey = `${from}:${to}:${empty}:${selectedText}`;
      const key = `${selectionKey}:${activeMarksKey(marks)}`;
      if (key === lastEmittedKey) return;
      lastEmittedKey = key;

      // ProseMirror's coordsAtPos returns viewport coords (relative to
      // the WKWebView's content area). The SwiftUI host translates to
      // window coords via the WebView's frame.
      const start = view.coordsAtPos(from);
      const end = empty ? start : view.coordsAtPos(to);
      const rect = new DOMRect(
        Math.min(start.left, end.left),
        Math.min(start.top, end.top),
        Math.abs(end.left - start.left) + 2,    // 2 px caret width fudge
        Math.max(end.bottom - start.top, 16),   // line-height floor
      );
      const selection: SelectionPayload = selectedText.length > 0
        ? { from, to, empty, text: selectedText }
        : { from, to, empty };
      onChange!(rect, selection, marks);
    }
  },
});

function selectedTextForContext(state: EditorState): string {
  const { from, to, empty } = state.selection;
  if (empty || from >= to) return '';
  const boundedTo = Math.min(to, from + MAX_SELECTION_TEXT_CHARACTERS + 256);
  const text = state.doc
    .textBetween(from, boundedTo, '\n', '\n')
    .trim();
  if (text.length <= MAX_SELECTION_TEXT_CHARACTERS) return text;
  return `${text.slice(0, MAX_SELECTION_TEXT_CHARACTERS)}...`;
}

function activeMarks(state: EditorState): ActiveMarksPayload {
  return {
    bold: markIsActive(state, 'bold'),
    italic: markIsActive(state, 'italic'),
    strike: markIsActive(state, 'strike'),
    code: markIsActive(state, 'code'),
    highlight: markIsActive(state, 'highlight'),
    heading: activeHeadingLevel(state),
  };
}

function activeMarksKey(marks: ActiveMarksPayload): string {
  return [
    marks.bold,
    marks.italic,
    marks.strike,
    marks.code,
    marks.highlight,
    marks.heading ?? 'p',
  ].join(':');
}

function markIsActive(state: EditorState, markName: string): boolean {
  const markType = state.schema.marks[markName];
  if (!markType) return false;
  const { from, to, empty, $from } = state.selection;
  if (empty) {
    return Boolean(markType.isInSet(state.storedMarks ?? $from.marks()));
  }
  return state.doc.rangeHasMark(from, to, markType);
}

function activeHeadingLevel(state: EditorState): number | null {
  const { $from } = state.selection;
  for (let depth = $from.depth; depth > 0; depth -= 1) {
    const node = $from.node(depth);
    if (node.type.name === 'heading') {
      const level = Number(node.attrs.level);
      return Number.isInteger(level) && level >= 1 && level <= 6 ? level : null;
    }
  }
  return null;
}
