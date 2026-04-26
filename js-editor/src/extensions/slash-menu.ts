// W7.17.b — slash menu via @tiptap/suggestion.
//
// Listens for `/` typed in an empty paragraph context. When triggered,
// posts a requestSlashMenu message to the Swift host with the query
// string + caret anchor. The SwiftUI side renders the picker and
// dispatches insertSlashChoice(blockType) back through the inbound
// bridge — that command runs `editor.chain().focus().<commandName>().run()`
// for whichever entry the user picked.
//
// The list of available block types lives below in DEFAULT_SLASH_ITEMS;
// the SwiftUI side mirrors the catalogue for its picker UI.

import { Extension } from '@tiptap/core';
import Suggestion from '@tiptap/suggestion';
import type { SuggestionOptions } from '@tiptap/suggestion';
import type { Editor } from '@tiptap/core';
import { postBridge } from '../bridge/outbound';

export interface SlashMenuItem {
  /** Stable id matched by the inbound `insertSlashChoice` payload. */
  id: string;
  /** Display label rendered by the SwiftUI picker. */
  label: string;
  /** Tiptap chain command applied when the entry is picked. */
  apply: (editor: Editor) => void;
  /** SF Symbol name the SwiftUI picker uses. */
  icon: string;
  /** Optional shortcut hint (purely cosmetic). */
  hint?: string;
}

export const DEFAULT_SLASH_ITEMS: SlashMenuItem[] = [
  { id: 'heading-1', label: 'Heading 1', icon: 'h.square', hint: '⌘1',
    apply: (e) => { e.chain().focus().toggleHeading({ level: 1 }).run(); } },
  { id: 'heading-2', label: 'Heading 2', icon: 'h.square', hint: '⌘2',
    apply: (e) => { e.chain().focus().toggleHeading({ level: 2 }).run(); } },
  { id: 'heading-3', label: 'Heading 3', icon: 'h.square', hint: '⌘3',
    apply: (e) => { e.chain().focus().toggleHeading({ level: 3 }).run(); } },
  { id: 'bullet-list', label: 'Bulleted list', icon: 'list.bullet', hint: '⌘⇧8',
    apply: (e) => { e.chain().focus().toggleBulletList().run(); } },
  { id: 'numbered-list', label: 'Numbered list', icon: 'list.number', hint: '⌘⇧7',
    apply: (e) => { e.chain().focus().toggleOrderedList().run(); } },
  { id: 'task-list', label: 'Task list', icon: 'checklist', hint: '⌘⇧9',
    apply: (e) => { e.chain().focus().toggleTaskList().run(); } },
  { id: 'blockquote', label: 'Quote', icon: 'text.quote', hint: '⌘⇧.',
    apply: (e) => { e.chain().focus().toggleBlockquote().run(); } },
  { id: 'code-block', label: 'Code block', icon: 'curlybraces', hint: '⌘⇧C',
    apply: (e) => { e.chain().focus().toggleCodeBlock().run(); } },
  { id: 'math-display', label: 'Math (block)', icon: 'function',
    apply: (e) => {
      // Math-block inserts the canonical $$...$$ via the
      // @tiptap/extension-mathematics commands.
      const cmd = (e.commands as unknown as { insertBlockMath?: () => boolean }).insertBlockMath;
      if (typeof cmd === 'function') cmd();
    },
  },
  { id: 'mermaid', label: 'Mermaid diagram', icon: 'flowchart',
    apply: (e) => {
      const cmd = (e.commands as unknown as { insertMermaid?: () => boolean }).insertMermaid;
      if (typeof cmd === 'function') cmd();
    },
  },
  { id: 'callout-tip', label: 'Callout — Tip', icon: 'lightbulb',
    apply: (e) => { e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'tip' }, content: [{ type: 'paragraph' }] }).run(); } },
  { id: 'callout-warning', label: 'Callout — Warning', icon: 'exclamationmark.triangle',
    apply: (e) => { e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'warning' }, content: [{ type: 'paragraph' }] }).run(); } },
  { id: 'callout-danger', label: 'Callout — Danger', icon: 'octagon',
    apply: (e) => { e.chain().focus().insertContent({ type: 'callout', attrs: { kind: 'danger' }, content: [{ type: 'paragraph' }] }).run(); } },
  { id: 'table-3x3', label: 'Table 3×3', icon: 'tablecells',
    apply: (e) => { e.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(); } },
  { id: 'divider', label: 'Divider', icon: 'minus', hint: '⌘⇧R',
    apply: (e) => { e.chain().focus().setHorizontalRule().run(); } },
];

export function buildSlashMenu(opts: { onActivate: (query: string, anchor: DOMRect) => void } = { onActivate: () => {} }) {
  return Extension.create({
    name: 'epdocSlashMenu',
    addProseMirrorPlugins() {
      const editor = this.editor;
      const suggestionOptions: SuggestionOptions = {
        editor,
        char: '/',
        startOfLine: false,
        items: ({ query }) => filterSlashItems(query),
        render: () => ({
          onStart: ({ clientRect, query }) => {
            const rect = clientRect?.() ?? new DOMRect(0, 0, 0, 0);
            postBridge({
              type: 'requestSlashMenu',
              query,
              anchor: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
            });
            opts.onActivate(query, rect);
          },
          onUpdate: ({ clientRect, query }) => {
            const rect = clientRect?.() ?? new DOMRect(0, 0, 0, 0);
            postBridge({
              type: 'requestSlashMenu',
              query,
              anchor: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
            });
          },
          onKeyDown: ({ event }) => {
            // Escape collapses the SwiftUI picker; the plugin re-emits
            // requestSlashMenu with empty query so the host can hide.
            if (event.key === 'Escape') {
              postBridge({ type: 'requestSlashMenu', query: '', anchor: { x: 0, y: 0, w: 0, h: 0 } });
              return false;
            }
            return false;
          },
          onExit: () => {
            postBridge({ type: 'requestSlashMenu', query: '', anchor: { x: 0, y: 0, w: 0, h: 0 } });
          },
        }),
        command: ({ editor: ed, range, props }) => {
          const item = props as SlashMenuItem;
          // Drop the `/query` text the suggestion captured, then run the apply().
          ed.chain().focus().deleteRange(range).run();
          item.apply(ed);
        },
      };
      return [Suggestion(suggestionOptions)];
    },
  });
}

function filterSlashItems(query: string): SlashMenuItem[] {
  if (!query) return DEFAULT_SLASH_ITEMS;
  const needle = query.toLowerCase();
  return DEFAULT_SLASH_ITEMS.filter((item) =>
    item.label.toLowerCase().includes(needle) || item.id.includes(needle)
  );
}
