import './code-editor.css';

import { autocompletion, closeBrackets, closeBracketsKeymap, completionKeymap } from '@codemirror/autocomplete';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import { cpp } from '@codemirror/lang-cpp';
import { css } from '@codemirror/lang-css';
import { html } from '@codemirror/lang-html';
import { javascript } from '@codemirror/lang-javascript';
import { json } from '@codemirror/lang-json';
import { markdown } from '@codemirror/lang-markdown';
import { python } from '@codemirror/lang-python';
import { rust } from '@codemirror/lang-rust';
import { tags as highlightTags } from '@lezer/highlight';
import { bracketMatching, defaultHighlightStyle, foldGutter, foldKeymap, HighlightStyle, indentOnInput, StreamLanguage, syntaxHighlighting } from '@codemirror/language';
import { swift } from '@codemirror/legacy-modes/mode/swift';
import { lintKeymap } from '@codemirror/lint';
import { highlightSelectionMatches, searchKeymap } from '@codemirror/search';
import { Compartment, EditorState, Extension } from '@codemirror/state';
import { crosshairCursor, drawSelection, dropCursor, EditorView, highlightActiveLine, highlightActiveLineGutter, highlightSpecialChars, keymap, lineNumbers, rectangularSelection } from '@codemirror/view';

declare global {
  interface Window {
    epistemosCodeEditor?: {
      setState(state: unknown): void;
      selectRange(location: number, length: number): void;
    };
  }
}

type CodeEditorState = {
  text?: string;
  language?: string;
  theme?: string;
  backgroundColor?: string;
  foregroundColor?: string;
  mutedColor?: string;
  lineColor?: string;
  gutterColor?: string;
  selectionColor?: string;
  cursorLineColor?: string;
  accentColor?: string;
  caretColor?: string;
  fontSize?: number;
  wrapLines?: boolean;
  showLineNumbers?: boolean;
};

const root = document.documentElement;
const mount = document.getElementById('editor');

if (!mount) {
  throw new Error('Epistemos CodeMirror mount missing');
}
const editorMount = mount;

const languageCompartment = new Compartment();
const themeCompartment = new Compartment();
const wrapCompartment = new Compartment();
const gutterCompartment = new Compartment();
const epistemosHighlightStyle = HighlightStyle.define([
  { tag: highlightTags.keyword, class: 'tok-keyword' },
  { tag: [highlightTags.string, highlightTags.special(highlightTags.string)], class: 'tok-string' },
  { tag: [highlightTags.comment, highlightTags.lineComment, highlightTags.blockComment], class: 'tok-comment' },
  { tag: [highlightTags.number, highlightTags.integer, highlightTags.float, highlightTags.bool], class: 'tok-number' },
  { tag: [highlightTags.typeName, highlightTags.className, highlightTags.namespace, highlightTags.atom], class: 'tok-typeName' },
  { tag: [highlightTags.propertyName, highlightTags.attributeName], class: 'tok-propertyName' },
  { tag: [highlightTags.variableName, highlightTags.definition(highlightTags.variableName)], class: 'tok-variableName' },
  { tag: [highlightTags.punctuation, highlightTags.operator, highlightTags.derefOperator, highlightTags.compareOperator, highlightTags.logicOperator], class: 'tok-punctuation' },
]);

let view: EditorView | null = null;
let lastState: CodeEditorState = {};
let isApplyingSwiftState = false;
let changeTimer = 0;

function post(payload: Record<string, unknown>) {
  window.webkit?.messageHandlers?.epistemosCodeEditor?.postMessage(payload);
}

function languageExtension(language: string | undefined): Extension {
  const normalized = (language || '').toLowerCase();
  if (normalized.includes('swift')) return StreamLanguage.define(swift);
  if (normalized.includes('typescript') || normalized === 'ts' || normalized === 'tsx') return javascript({ typescript: true, jsx: normalized.includes('tsx') });
  if (normalized.includes('javascript') || normalized === 'js' || normalized === 'jsx') return javascript({ jsx: normalized.includes('jsx') });
  if (normalized.includes('html') || normalized.includes('xml')) return html();
  if (normalized.includes('css') || normalized.includes('scss') || normalized.includes('less')) return css();
  if (normalized.includes('json')) return json();
  if (normalized.includes('markdown') || normalized === 'md') return markdown();
  if (normalized.includes('python') || normalized === 'py') return python();
  if (normalized.includes('rust') || normalized === 'rs') return rust();
  if (normalized.includes('c++') || normalized.includes('cpp') || normalized.includes('c ') || normalized === 'c' || normalized === 'h' || normalized === 'hpp') return cpp();
  return [];
}

function themeExtension(state: CodeEditorState): Extension {
  const fontSize = Math.max(8, Math.min(32, Number(state.fontSize || 15)));
  return EditorView.theme({
    '&': {
      fontSize: `${fontSize}px`,
    },
    '.cm-scroller': {
      fontFamily: '"SF Mono", "SFMono-Regular", ui-monospace, Menlo, Monaco, Consolas, monospace',
    },
    '.cm-content': {
      minHeight: '100%',
      fontVariantLigatures: 'none',
      fontFeatureSettings: '"liga" 0, "calt" 0',
    },
    '&.cm-focused': {
      outline: 'none',
    },
  });
}

function wrappingExtension(wrapLines: boolean | undefined): Extension {
  return wrapLines ? EditorView.lineWrapping : [];
}

function gutterExtension(showLineNumbers: boolean | undefined): Extension {
  return showLineNumbers === false
    ? []
    : [
      lineNumbers(),
      highlightActiveLineGutter(),
      foldGutter({
        openText: '⌄',
        closedText: '›',
      }),
    ];
}

function setCSSVars(state: CodeEditorState) {
  root.dataset.theme = state.theme || 'light';
  const vars: Record<string, string | undefined> = {
    '--epi-code-bg': state.backgroundColor,
    '--epi-code-fg': state.foregroundColor,
    '--epi-code-muted': state.mutedColor,
    '--epi-code-line': state.lineColor,
    '--epi-code-gutter': state.gutterColor,
    '--epi-code-selection': state.selectionColor,
    '--epi-code-cursor-line': state.cursorLineColor,
    '--epi-code-keyword': state.accentColor,
    '--epi-code-type': state.accentColor,
    '--epi-code-property': state.accentColor,
    '--epi-code-caret': state.caretColor,
  };
  for (const [name, value] of Object.entries(vars)) {
    if (value) root.style.setProperty(name, value);
  }
}

function cursorInfo(editor: EditorView = requireView()) {
  const head = editor.state.selection.main.head;
  const line = editor.state.doc.lineAt(head);
  return {
    line: line.number,
    column: head - line.from + 1,
  };
}

function requireView(): EditorView {
  if (!view) throw new Error('Epistemos CodeMirror view missing');
  return view;
}

function sendCursor(editor: EditorView = requireView()) {
  post({
    kind: 'cursor',
    ...cursorInfo(editor),
  });
}

function sendChange(editor: EditorView = requireView()) {
  window.clearTimeout(changeTimer);
  changeTimer = window.setTimeout(() => {
    const doc = editor.state.doc;
    post({
      kind: 'change',
      text: doc.toString(),
      lineCount: doc.lines,
      ...cursorInfo(editor),
    });
  }, 120);
}

function baseExtensions(): Extension[] {
  return [
    highlightSpecialChars(),
    history(),
    drawSelection(),
    dropCursor(),
    indentOnInput(),
    syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
    syntaxHighlighting(epistemosHighlightStyle),
    bracketMatching(),
    closeBrackets(),
    autocompletion(),
    rectangularSelection(),
    crosshairCursor(),
    highlightActiveLine(),
    highlightSelectionMatches(),
    keymap.of([
      indentWithTab,
      ...closeBracketsKeymap,
      ...defaultKeymap,
      ...searchKeymap,
      ...historyKeymap,
      ...foldKeymap,
      ...completionKeymap,
      ...lintKeymap,
    ]),
    EditorView.updateListener.of((update) => {
      if (update.selectionSet) sendCursor(update.view);
      if (update.docChanged && !isApplyingSwiftState) {
        sendChange(update.view);
      }
    }),
  ];
}

function createEditor(state: CodeEditorState) {
  setCSSVars(state);
  const startState = EditorState.create({
    doc: state.text || '',
    extensions: [
      ...baseExtensions(),
      languageCompartment.of(languageExtension(state.language)),
      themeCompartment.of(themeExtension(state)),
      wrapCompartment.of(wrappingExtension(state.wrapLines)),
      gutterCompartment.of(gutterExtension(state.showLineNumbers)),
    ],
  });
  view = new EditorView({
    state: startState,
    parent: editorMount,
  });
  lastState = { ...state };
  sendCursor(view);
}

function applyState(state: CodeEditorState) {
  if (!view) {
    createEditor(state);
    return;
  }

  setCSSVars(state);
  const effects = [];
  if (state.language !== lastState.language) effects.push(languageCompartment.reconfigure(languageExtension(state.language)));
  if (state.fontSize !== lastState.fontSize || state.theme !== lastState.theme) effects.push(themeCompartment.reconfigure(themeExtension(state)));
  if (state.wrapLines !== lastState.wrapLines) effects.push(wrapCompartment.reconfigure(wrappingExtension(state.wrapLines)));
  if (state.showLineNumbers !== lastState.showLineNumbers) effects.push(gutterCompartment.reconfigure(gutterExtension(state.showLineNumbers)));

  const currentText = view.state.doc.toString();
  const nextText = state.text || '';
  const changes = currentText === nextText
    ? undefined
    : { from: 0, to: currentText.length, insert: nextText };

  if (effects.length || changes) {
    isApplyingSwiftState = true;
    view.dispatch({ effects, changes });
    isApplyingSwiftState = false;
  }
  lastState = { ...state };
}

window.epistemosCodeEditor = {
  setState(state: unknown) {
    applyState((state || {}) as CodeEditorState);
  },
  selectRange(location: number, length: number) {
    const editor = requireView();
    const docLength = editor.state.doc.length;
    const start = Math.max(0, Math.min(docLength, location));
    const end = Math.max(start, Math.min(docLength, start + Math.max(0, length)));
    editor.focus();
    editor.dispatch({
      selection: { anchor: start, head: end },
      scrollIntoView: true,
    });
    sendCursor(editor);
  },
};

post({ kind: 'ready' });
