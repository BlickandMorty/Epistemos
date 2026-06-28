import { Extension, type Editor } from '@tiptap/core';
import type { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { Plugin, PluginKey, TextSelection } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';

interface FindMatch {
  from: number;
  to: number;
}

interface FindReplaceState {
  query: string;
  caseSensitive: boolean;
  matches: FindMatch[];
  selected: FindMatch | null;
}

type FindReplaceMeta =
  | { type: 'clear' }
  | {
      type: 'set';
      query: string;
      caseSensitive: boolean;
      selected?: FindMatch | null;
    };

interface FlatCharacter {
  value: string;
  position: number | null;
}

const EMPTY_FIND_STATE: FindReplaceState = {
  query: '',
  caseSensitive: false,
  matches: [],
  selected: null,
};

const FIND_REPLACE_KEY = new PluginKey<FindReplaceState>('epdocFindReplace');

export const EpdocFindReplace = Extension.create({
  name: 'epdocFindReplace',

  addProseMirrorPlugins() {
    return [
      new Plugin<FindReplaceState>({
        key: FIND_REPLACE_KEY,
        state: {
          init: () => EMPTY_FIND_STATE,
          apply(tr, value) {
            const meta = tr.getMeta(FIND_REPLACE_KEY) as FindReplaceMeta | undefined;
            if (meta?.type === 'clear') {
              return EMPTY_FIND_STATE;
            }
            if (meta?.type === 'set') {
              return buildFindState(tr.doc, meta.query, meta.caseSensitive, meta.selected ?? null);
            }
            if (tr.docChanged && value.query.length > 0) {
              const selected = value.selected
                ? { from: tr.mapping.map(value.selected.from), to: tr.mapping.map(value.selected.to) }
                : null;
              return buildFindState(tr.doc, value.query, value.caseSensitive, selected);
            }
            return value;
          },
        },
        props: {
          decorations(state) {
            const value = FIND_REPLACE_KEY.getState(state) ?? EMPTY_FIND_STATE;
            if (value.matches.length === 0) return DecorationSet.empty;

            const decorations = value.matches.map((match) => Decoration.inline(
              match.from,
              match.to,
              {
                class: sameMatch(match, value.selected)
                  ? 'epdoc-find-match epdoc-find-current'
                  : 'epdoc-find-match',
              },
            ));
            return DecorationSet.create(state.doc, decorations);
          },
        },
      }),
    ];
  },
});

export function setFindQuery(editor: Editor, query: string, caseSensitive: boolean): boolean {
  const normalized = normalizeQuery(query);
  if (normalized.length === 0) {
    clearFindQuery(editor);
    return false;
  }

  editor.view.dispatch(editor.state.tr.setMeta(FIND_REPLACE_KEY, {
    type: 'set',
    query: normalized,
    caseSensitive,
    selected: null,
  } satisfies FindReplaceMeta));
  return true;
}

export function clearFindQuery(editor: Editor): void {
  editor.view.dispatch(editor.state.tr.setMeta(FIND_REPLACE_KEY, { type: 'clear' } satisfies FindReplaceMeta));
}

export function findNext(editor: Editor, query: string, caseSensitive: boolean): boolean {
  return selectDirectionalMatch(editor, query, caseSensitive, 'next');
}

export function findPrevious(editor: Editor, query: string, caseSensitive: boolean): boolean {
  return selectDirectionalMatch(editor, query, caseSensitive, 'previous');
}

export function replaceCurrent(
  editor: Editor,
  query: string,
  replacement: string,
  caseSensitive: boolean,
): boolean {
  const normalized = normalizeQuery(query);
  if (normalized.length === 0) return false;

  const state = buildFindState(editor.state.doc, normalized, caseSensitive, null);
  const match = exactSelectionMatch(state.matches, editor.state.selection.from, editor.state.selection.to)
    ?? pickNextMatch(state.matches, editor.state.selection.from, editor.state.selection.to);
  if (!match) {
    dispatchFindState(editor, state, null);
    return false;
  }

  let tr = editor.state.tr.insertText(replacement, match.from, match.to);
  const insertedEnd = Math.min(match.from + replacement.length, tr.doc.content.size);
  const nextState = buildFindState(tr.doc, normalized, caseSensitive, null);
  const nextMatch = pickNextMatch(nextState.matches, insertedEnd, insertedEnd);
  if (nextMatch) {
    tr = tr.setSelection(TextSelection.create(tr.doc, nextMatch.from, nextMatch.to));
  } else {
    tr = tr.setSelection(TextSelection.near(tr.doc.resolve(insertedEnd)));
  }
  tr = tr.setMeta(FIND_REPLACE_KEY, {
    type: 'set',
    query: normalized,
    caseSensitive,
    selected: nextMatch,
  } satisfies FindReplaceMeta);
  editor.view.dispatch(tr.scrollIntoView());
  editor.view.focus();
  return true;
}

export function replaceAll(
  editor: Editor,
  query: string,
  replacement: string,
  caseSensitive: boolean,
): boolean {
  const normalized = normalizeQuery(query);
  if (normalized.length === 0) return false;

  const state = buildFindState(editor.state.doc, normalized, caseSensitive, null);
  if (state.matches.length === 0) {
    dispatchFindState(editor, state, null);
    return false;
  }

  let tr = editor.state.tr;
  for (const match of [...state.matches].reverse()) {
    tr = tr.insertText(replacement, match.from, match.to);
  }
  tr = tr.setMeta(FIND_REPLACE_KEY, {
    type: 'set',
    query: normalized,
    caseSensitive,
    selected: null,
  } satisfies FindReplaceMeta);
  editor.view.dispatch(tr.scrollIntoView());
  editor.view.focus();
  return true;
}

function selectDirectionalMatch(
  editor: Editor,
  query: string,
  caseSensitive: boolean,
  direction: 'next' | 'previous',
): boolean {
  const normalized = normalizeQuery(query);
  if (normalized.length === 0) {
    clearFindQuery(editor);
    return false;
  }

  const state = buildFindState(editor.state.doc, normalized, caseSensitive, null);
  const match = direction === 'next'
    ? pickNextMatch(state.matches, editor.state.selection.from, editor.state.selection.to)
    : pickPreviousMatch(state.matches, editor.state.selection.from, editor.state.selection.to);
  dispatchFindState(editor, state, match);
  return match !== null;
}

function dispatchFindState(editor: Editor, state: FindReplaceState, selected: FindMatch | null): void {
  let tr = editor.state.tr.setMeta(FIND_REPLACE_KEY, {
    type: 'set',
    query: state.query,
    caseSensitive: state.caseSensitive,
    selected,
  } satisfies FindReplaceMeta);
  if (selected) {
    tr = tr.setSelection(TextSelection.create(editor.state.doc, selected.from, selected.to)).scrollIntoView();
  }
  editor.view.dispatch(tr);
  if (selected) editor.view.focus();
}

function buildFindState(
  doc: ProseMirrorNode,
  query: string,
  caseSensitive: boolean,
  selected: FindMatch | null,
): FindReplaceState {
  const normalized = normalizeQuery(query);
  if (normalized.length === 0) return EMPTY_FIND_STATE;

  const matches = findMatches(doc, normalized, caseSensitive);
  const selectedMatch = selected ? matches.find((match) => sameMatch(match, selected)) ?? null : null;
  return {
    query: normalized,
    caseSensitive,
    matches,
    selected: selectedMatch,
  };
}

function findMatches(doc: ProseMirrorNode, query: string, caseSensitive: boolean): FindMatch[] {
  const flattened = flattenDocument(doc);
  const haystack = flattened.map((character) => character.value).join('');
  const searchableHaystack = caseSensitive ? haystack : haystack.toLowerCase();
  const needle = caseSensitive ? query : query.toLowerCase();
  const matches: FindMatch[] = [];

  let index = searchableHaystack.indexOf(needle);
  while (index !== -1) {
    const span = flattened.slice(index, index + query.length);
    const first = span[0]?.position;
    const last = span[span.length - 1]?.position;
    if (typeof first === 'number'
        && typeof last === 'number'
        && span.every((character) => typeof character.position === 'number')) {
      matches.push({ from: first, to: last + 1 });
    }
    index = searchableHaystack.indexOf(needle, index + Math.max(needle.length, 1));
  }

  return matches;
}

function flattenDocument(doc: ProseMirrorNode): FlatCharacter[] {
  const characters: FlatCharacter[] = [];
  doc.descendants((node, position) => {
    if (node.isTextblock && characters.length > 0 && characters[characters.length - 1].value !== '\n') {
      characters.push({ value: '\n', position: null });
    }

    if (node.isText && node.text) {
      for (let offset = 0; offset < node.text.length; offset += 1) {
        characters.push({ value: node.text[offset], position: position + offset });
      }
      return false;
    }

    if (node.type.name === 'hardBreak') {
      characters.push({ value: '\n', position: null });
      return false;
    }

    return true;
  });
  return characters;
}

function pickNextMatch(matches: FindMatch[], from: number, to: number): FindMatch | null {
  if (matches.length === 0) return null;
  return matches.find((match) => match.from > from || (match.from === from && match.to > to))
    ?? matches[0];
}

function pickPreviousMatch(matches: FindMatch[], from: number, to: number): FindMatch | null {
  if (matches.length === 0) return null;
  return [...matches].reverse().find((match) => match.from < from || (match.from === from && match.to < to))
    ?? matches[matches.length - 1];
}

function exactSelectionMatch(matches: FindMatch[], from: number, to: number): FindMatch | null {
  return matches.find((match) => match.from === from && match.to === to) ?? null;
}

function sameMatch(lhs: FindMatch | null, rhs: FindMatch | null): boolean {
  return lhs !== null && rhs !== null && lhs.from === rhs.from && lhs.to === rhs.to;
}

function normalizeQuery(query: string): string {
  return query.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}
