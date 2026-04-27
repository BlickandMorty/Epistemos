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
import { Plugin, PluginKey } from '@tiptap/pm/state';
import type { EditorView } from '@tiptap/pm/view';
import type { RectPayload, SelectionPayload } from '../bridge/outbound';

export interface CaretRectEmitterOptions {
  onChange?: (rect: DOMRect, selection: SelectionPayload) => void;
}

const CARET_RECT_KEY = new PluginKey('epdocCaretRect');

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
      const key = `${from}:${to}:${empty}`;
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
      const selection: SelectionPayload = { from, to, empty };
      onChange!(rect, selection);
    }
  },
});
