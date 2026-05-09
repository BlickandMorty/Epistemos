// Syntax-highlighted .epdoc code blocks.
//
// This keeps the V1.5 editor on the canonical Tiptap substrate while
// giving fenced/codeBlock nodes real IDE-like coloring. A full
// CodeMirror island is reserved for future in-block LSP/autocomplete
// work; lowlight is the smallest correct upgrade for authored docs.

import { CodeBlockLowlight } from '@tiptap/extension-code-block-lowlight';
import swift from 'highlight.js/lib/languages/swift';
import { common, createLowlight } from 'lowlight';

const lowlight = createLowlight(common);
lowlight.register('swift', swift);

export interface ClosingFenceLineRange {
  from: number;
  to: number;
}

export function closingFenceLineRange(text: string, cursorOffset: number): ClosingFenceLineRange | null {
  const offset = Math.max(0, Math.min(cursorOffset, text.length));
  const before = text.slice(0, offset);
  const after = text.slice(offset);
  const lineStart = before.lastIndexOf('\n') + 1;
  const nextLineBreak = after.indexOf('\n');
  const lineEnd = nextLineBreak >= 0 ? offset + nextLineBreak : text.length;
  const line = text.slice(lineStart, lineEnd);
  if (line.trim() !== '```') return null;
  const deleteFrom = lineStart > 0 && text[lineStart - 1] === '\n' ? lineStart - 1 : lineStart;
  return { from: deleteFrom, to: lineEnd };
}

export const EpdocCodeBlock = CodeBlockLowlight.extend({
  addKeyboardShortcuts() {
    const parentShortcuts = this.parent?.() ?? {};
    const runParentEnter = (): boolean => {
      const enter = parentShortcuts.Enter as unknown as (() => boolean) | undefined;
      return enter?.() ?? false;
    };
    return {
      ...parentShortcuts,
      Enter: () => {
        const { state } = this.editor;
        const { $from } = state.selection;
        if ($from.parent.type.name !== this.name) {
          return runParentEnter();
        }

        const range = closingFenceLineRange($from.parent.textContent, $from.parentOffset);
        if (!range) {
          return runParentEnter();
        }

        const deletedFence = this.editor.commands.command(({ tr, dispatch }) => {
          const from = $from.start() + range.from;
          const to = $from.start() + range.to;
          if (dispatch) dispatch(tr.delete(from, to));
          return true;
        });
        if (!deletedFence) return false;
        return this.editor.commands.exitCode();
      },
    };
  },
}).configure({
  lowlight,
  defaultLanguage: 'swift',
  HTMLAttributes: {
    'data-epdoc-code-block': 'true',
    spellcheck: 'false',
  },
});
