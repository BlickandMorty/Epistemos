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

export const EpdocCodeBlock = CodeBlockLowlight.configure({
  lowlight,
  defaultLanguage: 'swift',
  HTMLAttributes: {
    'data-epdoc-code-block': 'true',
    spellcheck: 'false',
  },
});
