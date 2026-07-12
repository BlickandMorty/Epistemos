import { Extension, Mark, mergeAttributes } from '@tiptap/core';
import type { MarkSpec } from '@tiptap/pm/model';
import { addSuggestionMarks, suggestChanges } from '@handlewithcare/prosemirror-suggest-changes';
import { EpdocSuggestionDocument } from './document';

export { EpdocSuggestionDocument } from './document';

export const SUGGESTION_MARK_NAMES = ['insertion', 'deletion', 'modification'] as const;

export const InsertionSuggestionMark = Mark.create({
  name: 'insertion',
  inclusive: false,
  excludes: 'deletion modification insertion',

  addAttributes() {
    return {
      id: {
        default: null,
        parseHTML: element => parseSuggestionId(element.getAttribute('data-id')),
        renderHTML: attributes => serializedSuggestionIdAttribute(attributes.id),
      },
    };
  },

  parseHTML() {
    return [{ tag: 'ins[data-id]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['ins', mergeAttributes(HTMLAttributes, { 'data-inline': 'true' }), 0];
  },
});

export const DeletionSuggestionMark = Mark.create({
  name: 'deletion',
  inclusive: false,
  excludes: 'insertion modification deletion',

  addAttributes() {
    return {
      id: {
        default: null,
        parseHTML: element => parseSuggestionId(element.getAttribute('data-id')),
        renderHTML: attributes => serializedSuggestionIdAttribute(attributes.id),
      },
    };
  },

  parseHTML() {
    return [{ tag: 'del[data-id]' }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['del', mergeAttributes(HTMLAttributes, { 'data-inline': 'true' }), 0];
  },
});

export const ModificationSuggestionMark = Mark.create({
  name: 'modification',
  inclusive: false,
  excludes: 'deletion insertion',

  addAttributes() {
    return {
      id: {
        default: null,
        parseHTML: element => parseSuggestionId(element.getAttribute('data-id')),
        renderHTML: attributes => serializedSuggestionIdAttribute(attributes.id),
      },
      type: {
        default: null,
        parseHTML: element => element.getAttribute('data-mod-type'),
        renderHTML: attributes => dataAttribute('data-mod-type', attributes.type),
      },
      attrName: {
        default: null,
      },
      previousValue: {
        default: null,
        parseHTML: element => parseJSONAttribute(element.getAttribute('data-mod-prev-val')),
        renderHTML: attributes => jsonDataAttribute('data-mod-prev-val', attributes.previousValue),
      },
      newValue: {
        default: null,
        parseHTML: element => parseJSONAttribute(element.getAttribute('data-mod-new-val')),
        renderHTML: attributes => jsonDataAttribute('data-mod-new-val', attributes.newValue),
      },
    };
  },

  parseHTML() {
    return [
      { tag: 'span[data-type="modification"]' },
      { tag: 'div[data-type="modification"]' },
    ];
  },

  renderHTML({ HTMLAttributes }) {
    return ['span', mergeAttributes(HTMLAttributes, { 'data-type': 'modification' }), 0];
  },
});

export const SuggestChangesExtension = Extension.create({
  name: 'suggestChanges',

  addProseMirrorPlugins() {
    return [suggestChanges()];
  },
});

export const epdocSuggestionExtensions = [
  EpdocSuggestionDocument,
  InsertionSuggestionMark,
  DeletionSuggestionMark,
  ModificationSuggestionMark,
  SuggestChangesExtension,
];

export function buildSuggestionMarks(baseMarks: Record<string, MarkSpec>): Record<string, MarkSpec> {
  return addSuggestionMarks(baseMarks);
}

function serializedSuggestionIdAttribute(value: unknown): Record<string, string> {
  if (value === null || value === undefined) return {};
  return { 'data-id': JSON.stringify(value) };
}

function parseSuggestionId(value: string | null): string | number | null {
  if (!value) return null;
  return parseJSONAttribute(value) as string | number | null;
}

function parseJSONAttribute(value: string | null): unknown {
  if (value === null) return null;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function jsonDataAttribute(name: string, value: unknown): Record<string, string> {
  if (value === null || value === undefined) return {};
  return { [name]: JSON.stringify(value) };
}

function dataAttribute(name: string, value: unknown): Record<string, string> {
  if (typeof value !== 'string' || value.length === 0) return {};
  return { [name]: value };
}
