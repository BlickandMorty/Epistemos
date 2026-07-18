import type { Editor, JSONContent } from '@tiptap/core';
import type { Node as PMNode } from '@tiptap/pm/model';
import type { Transaction } from '@tiptap/pm/state';
import type { StepMap } from '@tiptap/pm/transform';
import { ChangeSet } from 'prosemirror-changeset';
import { HOST_LOAD_META } from '../bridge/document-load-state';
import {
  minimalWriteback,
  seedChangeSet,
  type WritebackRegion,
} from './minimal-diff-writeback';

interface WritebackChangeData {
  readonly source: 'user' | 'agent' | 'unknown';
}

export class MarkdownWritebackTracker {
  private baselineMarkdown = '';
  private currentSet: ChangeSet<WritebackChangeData> | null = null;
  private pendingBaseSet: ChangeSet<WritebackChangeData> | null = null;
  private pendingMaps: StepMap[] = [];

  reset(editor: Editor, markdown: string): void {
    this.baselineMarkdown = markdown;
    this.currentSet = seedChangeSet(editor.state.doc) as ChangeSet<WritebackChangeData>;
    this.pendingBaseSet = null;
    this.pendingMaps = [];
  }

  recordTransaction(editor: Editor, tr: Transaction): void {
    if (!tr.docChanged || tr.getMeta(HOST_LOAD_META)) return;
    if (!this.currentSet) {
      this.reset(editor, safeMarkdownSnapshot(editor));
      return;
    }

    const maps = tr.steps.map(step => step.getMap());
    if (maps.length === 0) return;
    this.pendingBaseSet ??= this.currentSet;
    this.currentSet = this.currentSet.addSteps(tr.doc, maps, { source: transactionSource(tr) });
    this.pendingMaps.push(...maps);
  }

  consume(editor: Editor, currentMarkdown?: string): WritebackRegion | null {
    if (!this.currentSet) {
      this.reset(editor, currentMarkdown ?? safeMarkdownSnapshot(editor));
      return null;
    }
    if (!this.pendingBaseSet || this.pendingMaps.length === 0) return null;

    const result = minimalWriteback({
      oldSet: this.pendingBaseSet,
      newSet: this.currentSet,
      maps: this.pendingMaps,
      oldMarkdown: this.baselineMarkdown,
      newDoc: editor.state.doc,
      serializeDoc: doc => serializeDoc(editor, doc),
    });
    if (!result) {
      this.reset(editor, currentMarkdown ?? safeMarkdownSnapshot(editor));
      return null;
    }

    this.baselineMarkdown = result.nextMarkdown;
    this.pendingBaseSet = null;
    this.pendingMaps = [];
    return result.region;
  }
}

function serializeDoc(editor: Editor, doc: PMNode): string {
  return editor.markdown?.serialize(doc.toJSON() as JSONContent) ?? '';
}

function safeMarkdownSnapshot(editor: Editor): string {
  return typeof editor.getMarkdown === 'function' ? editor.getMarkdown() : '';
}

function transactionSource(tr: Transaction): WritebackChangeData['source'] {
  const source = tr.getMeta('source');
  if (source === 'user' || source === 'agent') return source;
  return 'unknown';
}
