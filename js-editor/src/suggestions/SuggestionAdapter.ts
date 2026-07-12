import {
  applySuggestion as applyHwcSuggestion,
  revertSuggestion as revertHwcSuggestion,
  suggestChangesKey,
  transformToSuggestionTransaction,
  withSuggestChanges,
} from '@handlewithcare/prosemirror-suggest-changes';
import type { Node as ProseMirrorNode, Schema } from 'prosemirror-model';
import type { EditorState, Transaction } from 'prosemirror-state';
import type { EditorView } from 'prosemirror-view';
import type { SuggestionPayload } from '../bridge/suggestion-payload';

type SuggestionId = string | number;

export interface SuggestionAdapter {
  readonly name: string;
  decorateDispatch(base: EditorView['dispatch']): EditorView['dispatch'];
  applySuggestion(
    state: EditorState,
    id: string,
    dispatch: EditorView['dispatch'],
  ): boolean;
  revertSuggestion(
    state: EditorState,
    id: string,
    dispatch: EditorView['dispatch'],
  ): boolean;
  ingestAgentEdit(state: EditorState, payload: SuggestionPayload): Transaction;
}

export interface HwcSuggestionAdapterOptions {
  view?: () => Pick<EditorView, 'state' | 'dispatch' | 'updateState'> | null;
}

export class HwcSuggestionAdapter implements SuggestionAdapter {
  readonly name = 'handlewithcare/prosemirror-suggest-changes';

  private readonly view: (() => Pick<EditorView, 'state' | 'dispatch' | 'updateState'> | null) | undefined;

  constructor(options: HwcSuggestionAdapterOptions = {}) {
    this.view = options.view;
  }

  decorateDispatch(base: EditorView['dispatch']): EditorView['dispatch'] {
    const decorated = withSuggestChanges(base, suggestionIdFromDoc);
    return (tr: Transaction): void => {
      const view = this.view?.();
      if (!view) {
        base(tr);
        return;
      }
      decorated.call(view as EditorView, tr);
    };
  }

  applySuggestion(
    state: EditorState,
    id: string,
    dispatch: EditorView['dispatch'],
  ): boolean {
    return applyHwcSuggestion(normalizeSuggestionId(id))(state, dispatch);
  }

  revertSuggestion(
    state: EditorState,
    id: string,
    dispatch: EditorView['dispatch'],
  ): boolean {
    return revertHwcSuggestion(normalizeSuggestionId(id))(state, dispatch);
  }

  ingestAgentEdit(state: EditorState, payload: SuggestionPayload): Transaction {
    const range = normalizeSuggestionRange(state, payload);
    if (!range || payload.before === payload.after) return state.tr;

    const raw = state.tr.insertText(payload.after, range.from, range.to);
    const tracked = transformToSuggestionTransaction(
      raw,
      state,
      () => normalizeSuggestionId(payload.id),
    );
    return tracked
      .setMeta(suggestChangesKey, { skip: true })
      .setMeta('epdocSuggestion', {
        source: 'agent',
        id: payload.id,
        author: payload.author,
        turnId: payload.turnId,
      });
  }
}

export class NoopSuggestionAdapter implements SuggestionAdapter {
  readonly name = 'noop';

  decorateDispatch(base: EditorView['dispatch']): EditorView['dispatch'] {
    return base;
  }

  applySuggestion(): boolean {
    return false;
  }

  revertSuggestion(): boolean {
    return false;
  }

  ingestAgentEdit(state: EditorState): Transaction {
    return state.tr;
  }
}

function normalizeSuggestionRange(
  state: EditorState,
  payload: SuggestionPayload,
): { from: number; to: number } | null {
  const from = normalizePosition(payload.from, state.doc.content.size);
  const to = normalizePosition(payload.to, state.doc.content.size);
  if (from === null || to === null || from > to) return null;
  const selected = state.doc.textBetween(from, to, '\n', '\n');
  if (payload.before.length > 0 && selected !== payload.before) return null;
  return { from, to };
}

function normalizePosition(value: number, max: number): number | null {
  if (!Number.isFinite(value)) return null;
  const position = Math.trunc(value);
  if (position < 0 || position > max) return null;
  return position;
}

function normalizeSuggestionId(id: string): SuggestionId {
  const trimmed = id.trim();
  if (/^\d+$/.test(trimmed)) return Number(trimmed);
  return trimmed;
}

function suggestionIdFromDoc(schema: Schema, doc?: ProseMirrorNode): SuggestionId {
  const base = doc ? highestSuggestionNumber(schema, doc) + 1 : 1;
  return `agent-${base}`;
}

function highestSuggestionNumber(schema: Schema, doc: ProseMirrorNode): number {
  const marks = [schema.marks.insertion, schema.marks.deletion, schema.marks.modification]
    .filter((mark): mark is NonNullable<typeof mark> => Boolean(mark));
  let highest = 0;
  doc.descendants((node) => {
    for (const mark of node.marks) {
      if (!marks.includes(mark.type)) continue;
      const raw = mark.attrs.id;
      const candidate = typeof raw === 'number'
        ? raw
        : typeof raw === 'string' && /^agent-(\d+)$/.test(raw)
          ? Number(raw.slice('agent-'.length))
          : 0;
      highest = Math.max(highest, candidate);
    }
  });
  return highest;
}
