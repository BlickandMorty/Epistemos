// Tracks whether the native host has loaded package content into the
// editor. Tiptap extensions can mutate the boot placeholder document
// before Swift pushes the real .epdoc payload; those updates must never
// autosave over the package.
//
// LUMENLENS L0 layers a loadEpoch guard onto that boolean gate. The
// loader still passes emitUpdate:false as a belt, but correctness lives
// in this ProseMirror filter because Tiptap #1715/#4828 show that
// programmatic loads can still emit updates or empty-doc churn.

import { Extension } from '@tiptap/core';
import {
  Plugin,
  PluginKey,
  type EditorState,
  type Transaction,
} from '@tiptap/pm/state';

export type LoadEpoch = number & { readonly __brand: 'LoadEpoch' };

export interface DocumentLoadState {
  epoch: LoadEpoch;
  loading: boolean;
  suppressUntil: number;
}

export const INITIAL_LOAD_EPOCH = 0 as LoadEpoch;
export const LOAD_SUPPRESSION_MS = 32;
export const EPOCH_META = 'epdoc:loadEpoch';
export const HOST_LOAD_META = 'epdoc:hostLoad';
export const USER_INPUT_META = 'epdoc:userInput';
export const loadStateKey = new PluginKey<DocumentLoadState>('epdoc-load-state');

let hostDocumentLoaded = false;
let hostDocumentLoadEpoch = INITIAL_LOAD_EPOCH;

export function markHostDocumentLoaded(epoch: LoadEpoch = hostDocumentLoadEpoch): void {
  hostDocumentLoaded = true;
  hostDocumentLoadEpoch = epoch;
}

export function hasHostDocumentLoaded(): boolean {
  return hostDocumentLoaded;
}

export function currentHostLoadEpoch(): LoadEpoch {
  return hostDocumentLoadEpoch;
}

export function nextEpoch(prev: LoadEpoch): LoadEpoch {
  return ((prev as number) + 1) as LoadEpoch;
}

export function currentLoadEpoch(state: EditorState): LoadEpoch {
  return loadStateKey.getState(state)?.epoch ?? currentHostLoadEpoch();
}

export function isDocumentLoadSettling(state: EditorState): boolean {
  const loadState = loadStateKey.getState(state);
  if (!loadState) return false;
  return loadState.loading || performance.now() < loadState.suppressUntil;
}

export function loadStatePlugin(initial: LoadEpoch = INITIAL_LOAD_EPOCH): Plugin<DocumentLoadState> {
  return new Plugin<DocumentLoadState>({
    key: loadStateKey,
    state: {
      init: (): DocumentLoadState => ({
        epoch: initial,
        loading: false,
        suppressUntil: 0,
      }),
      apply(tr: Transaction, value: DocumentLoadState): DocumentLoadState {
        const meta = tr.getMeta(loadStateKey) as Partial<DocumentLoadState> | undefined;
        return meta ? { ...value, ...meta } : value;
      },
    },
    filterTransaction(tr: Transaction, state: EditorState): boolean {
      const loadState = loadStateKey.getState(state);
      if (!loadState) return true;
      if (tr.getMeta(HOST_LOAD_META) === true) return true;

      const userInput = tr.getMeta(USER_INPUT_META) === true;
      const epoch = tr.getMeta(EPOCH_META) as LoadEpoch | undefined;
      if (!userInput && epoch !== undefined && epoch !== loadState.epoch) return false;

      if (!tr.docChanged) return true;
      if (loadState.loading) return false;
      if (!userInput && performance.now() < loadState.suppressUntil) return false;

      return true;
    },
  });
}

export const LoadStateExtension = Extension.create({
  name: 'epdocLoadState',
  addProseMirrorPlugins() {
    return [loadStatePlugin()];
  },
});

export function beginLoad(
  view: { state: EditorState; dispatch: (tr: Transaction) => void },
  suppressMs: number = LOAD_SUPPRESSION_MS,
  requestedEpoch?: LoadEpoch,
): LoadEpoch {
  const current = loadStateKey.getState(view.state);
  const epoch = requestedEpoch ?? nextEpoch(current?.epoch ?? currentHostLoadEpoch());
  const tr = view.state.tr
    .setMeta(loadStateKey, {
      epoch,
      loading: true,
      suppressUntil: performance.now() + suppressMs,
    } satisfies Partial<DocumentLoadState>)
    .setMeta(HOST_LOAD_META, true)
    .setMeta(EPOCH_META, epoch);
  view.dispatch(tr);
  markHostDocumentLoaded(epoch);
  return epoch;
}

export function endLoad(view: { state: EditorState; dispatch: (tr: Transaction) => void }): LoadEpoch {
  const epoch = currentLoadEpoch(view.state);
  const tr = view.state.tr
    .setMeta(loadStateKey, { loading: false } satisfies Partial<DocumentLoadState>)
    .setMeta(HOST_LOAD_META, true)
    .setMeta(EPOCH_META, epoch);
  view.dispatch(tr);
  return epoch;
}
