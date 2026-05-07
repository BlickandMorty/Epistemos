import type { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { Fragment } from '@tiptap/pm/model';
import type { EditorState } from '@tiptap/pm/state';
import { TextSelection } from '@tiptap/pm/state';

export interface InputRuleRange {
  from: number;
  to: number;
}

export function replaceInputWithBlockAndTrailingParagraph(
  state: EditorState,
  range: InputRuleRange,
  blockNode: ProseMirrorNode
): void | null {
  const paragraphNode = state.schema.nodes.paragraph?.create();
  if (!paragraphNode) return null;

  const tr = state.tr.replaceWith(
    range.from,
    range.to,
    Fragment.fromArray([blockNode, paragraphNode])
  );
  const cursorPosition = Math.min(range.from + blockNode.nodeSize + 1, tr.doc.content.size);
  tr.setSelection(TextSelection.near(tr.doc.resolve(cursorPosition)));
  tr.scrollIntoView();
}
