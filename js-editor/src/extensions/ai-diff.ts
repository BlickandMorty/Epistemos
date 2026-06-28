import { Extension, type Editor } from '@tiptap/core';
import type { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Transform } from '@tiptap/pm/transform';
import { Decoration, DecorationSet } from '@tiptap/pm/view';
import { ChangeSet, simplifyChanges, type Change } from 'prosemirror-changeset';

export interface EpdocAIDiffStageRequest {
  markdown: string;
  claimId: string;
  batchId: string;
  settled: true;
}

export interface EpdocAIDiffChangeData {
  claimId: string;
  batchId: string;
}

export interface EpdocAIDiffSpanPreview {
  from: number;
  to: number;
  text: string;
  claimId: string;
  batchId: string;
}

export interface EpdocAIDiffPreview {
  metadata: EpdocAIDiffChangeData;
  changes: readonly Change<EpdocAIDiffChangeData>[];
  insertions: EpdocAIDiffSpanPreview[];
  deletions: EpdocAIDiffSpanPreview[];
}

type EpdocAIDiffPluginState = {
  originalDoc: ProseMirrorNode;
  proposedDoc: ProseMirrorNode;
  preview: EpdocAIDiffPreview;
  decorations: DecorationSet;
} | null;

type EpdocAIDiffMeta =
  | { type: 'stage'; value: Exclude<EpdocAIDiffPluginState, null> }
  | { type: 'clear' };

export const EPDOC_AI_DIFF_KEY = new PluginKey<EpdocAIDiffPluginState>('epdocAIDiff');

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    epdocAIDiff: {
      stageEpdocAIDiff: (request: EpdocAIDiffStageRequest) => ReturnType;
      acceptEpdocAIDiff: () => ReturnType;
      rejectEpdocAIDiff: () => ReturnType;
      clearEpdocAIDiff: () => ReturnType;
    };
  }
}

export const EpdocAIDiff = Extension.create({
  name: 'epdocAIDiff',

  addCommands() {
    return {
      stageEpdocAIDiff: (request: EpdocAIDiffStageRequest) => ({ editor, state, dispatch }) => {
        const normalized = normalizeEpdocAIDiffStageRequest(request);
        if (!normalized || !editor.markdown) return false;

        let proposedDoc: ProseMirrorNode;
        try {
          const proposedJSON = editor.markdown.parse(normalized.markdown);
          proposedDoc = state.schema.nodeFromJSON(proposedJSON);
        } catch (error) {
          console.warn('[epdoc ai-diff] unable to parse staged Markdown', error);
          return false;
        }

        const preview = buildEpdocAIDiffPreview(state.doc, proposedDoc, {
          claimId: normalized.claimId,
          batchId: normalized.batchId,
        });
        if (preview.changes.length === 0) {
          if (dispatch) dispatch(state.tr.setMeta(EPDOC_AI_DIFF_KEY, { type: 'clear' } satisfies EpdocAIDiffMeta));
          return false;
        }

        if (dispatch) {
          const staged = {
            originalDoc: state.doc,
            proposedDoc,
            preview,
            decorations: buildAIDiffDecorations(state.doc, preview),
          };
          dispatch(state.tr.setMeta(EPDOC_AI_DIFF_KEY, { type: 'stage', value: staged } satisfies EpdocAIDiffMeta));
        }
        return true;
      },

      acceptEpdocAIDiff: () => ({ editor, state, dispatch }) => {
        const staged = EPDOC_AI_DIFF_KEY.getState(state);
        if (!staged || !staged.originalDoc.eq(state.doc)) return false;
        if (dispatch) {
          const tr = state.tr
            .replaceWith(0, state.doc.content.size, staged.proposedDoc.content)
            .setMeta(EPDOC_AI_DIFF_KEY, { type: 'clear' } satisfies EpdocAIDiffMeta)
            .scrollIntoView();
          dispatch(tr);
        }
        editor.view.focus();
        return true;
      },

      rejectEpdocAIDiff: () => ({ editor, state, dispatch }) => {
        const staged = EPDOC_AI_DIFF_KEY.getState(state);
        if (!staged) return false;
        if (dispatch) dispatch(state.tr.setMeta(EPDOC_AI_DIFF_KEY, { type: 'clear' } satisfies EpdocAIDiffMeta));
        editor.view.focus();
        return true;
      },

      clearEpdocAIDiff: () => ({ state, dispatch }) => {
        if (!EPDOC_AI_DIFF_KEY.getState(state)) return false;
        if (dispatch) dispatch(state.tr.setMeta(EPDOC_AI_DIFF_KEY, { type: 'clear' } satisfies EpdocAIDiffMeta));
        return true;
      },
    };
  },

  addProseMirrorPlugins() {
    return [
      new Plugin<EpdocAIDiffPluginState>({
        key: EPDOC_AI_DIFF_KEY,
        state: {
          init: () => null,
          apply(tr, value) {
            const meta = tr.getMeta(EPDOC_AI_DIFF_KEY) as EpdocAIDiffMeta | undefined;
            if (meta?.type === 'stage') return meta.value;
            if (meta?.type === 'clear') return null;
            if (tr.docChanged && value) return null;
            return value;
          },
        },
        props: {
          decorations(state) {
            return EPDOC_AI_DIFF_KEY.getState(state)?.decorations ?? DecorationSet.empty;
          },
        },
      }),
    ];
  },
});

export function normalizeEpdocAIDiffStageRequest(raw: unknown): EpdocAIDiffStageRequest | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const request = raw as Partial<Record<keyof EpdocAIDiffStageRequest, unknown>>;
  const markdown = normalizeNonEmptyString(request.markdown);
  const claimId = normalizeNonEmptyString(request.claimId);
  const batchId = normalizeNonEmptyString(request.batchId);
  if (!markdown || !claimId || !batchId || request.settled !== true) return null;
  return { markdown, claimId, batchId, settled: true };
}

export function buildEpdocAIDiffPreview(
  originalDoc: ProseMirrorNode,
  proposedDoc: ProseMirrorNode,
  metadata: EpdocAIDiffChangeData,
): EpdocAIDiffPreview {
  const transform = new Transform(originalDoc).replaceWith(
    0,
    originalDoc.content.size,
    proposedDoc.content,
  );
  const maps = transform.steps.map(step => step.getMap());
  const changeset = ChangeSet
    .create<EpdocAIDiffChangeData>(originalDoc, (a) => a)
    .addSteps(transform.doc, maps, metadata);

  const changes = simplifyChanges(changeset.changes, proposedDoc) as Change<EpdocAIDiffChangeData>[];
  const insertions: EpdocAIDiffSpanPreview[] = [];
  const deletions: EpdocAIDiffSpanPreview[] = [];
  for (const change of changes) {
    if (change.fromB < change.toB) {
      insertions.push({
        from: change.fromB,
        to: change.toB,
        text: previewText(proposedDoc, change.fromB, change.toB, 'Inserted block'),
        claimId: metadata.claimId,
        batchId: metadata.batchId,
      });
    }
    if (change.fromA < change.toA) {
      deletions.push({
        from: change.fromA,
        to: change.toA,
        text: previewText(originalDoc, change.fromA, change.toA, 'Deleted block'),
        claimId: metadata.claimId,
        batchId: metadata.batchId,
      });
    }
  }

  return {
    metadata,
    changes,
    insertions,
    deletions,
  };
}

export function epdocAIDiffIsPreviewCommand(name: string): boolean {
  return name === 'stageEpdocAIDiff'
    || name === 'rejectEpdocAIDiff'
    || name === 'clearEpdocAIDiff';
}

function buildAIDiffDecorations(doc: ProseMirrorNode, preview: EpdocAIDiffPreview): DecorationSet {
  const decorations: Decoration[] = [];
  for (const change of preview.changes) {
    if (change.fromA < change.toA) {
      decorations.push(Decoration.inline(
        change.fromA,
        change.toA,
        {
          class: 'epdoc-ai-diff-delete',
          'data-claim-id': preview.metadata.claimId,
          'data-batch-id': preview.metadata.batchId,
        },
      ));
    }
    if (change.fromB < change.toB) {
      const insertionText = previewTextForChange(preview, change);
      decorations.push(Decoration.widget(
        change.fromA,
        () => insertedWidget(insertionText, preview.metadata),
        {
          side: 1,
          key: `epdoc-ai-insert-${preview.metadata.claimId}-${change.fromA}-${change.toB}`,
        },
      ));
    }
  }
  return DecorationSet.create(doc, decorations);
}

function previewTextForChange(preview: EpdocAIDiffPreview, change: Change<EpdocAIDiffChangeData>): string {
  return preview.insertions.find(insertion => insertion.from === change.fromB && insertion.to === change.toB)?.text
    ?? 'Inserted block';
}

function insertedWidget(text: string, metadata: EpdocAIDiffChangeData): HTMLElement {
  const node = document.createElement('span');
  node.className = 'epdoc-ai-diff-insert';
  node.dataset.claimId = metadata.claimId;
  node.dataset.batchId = metadata.batchId;
  node.textContent = text;
  return node;
}

function previewText(doc: ProseMirrorNode, from: number, to: number, fallback: string): string {
  const raw = doc.textBetween(from, to, '\n', '\n').replace(/\s+/g, ' ').trim();
  if (raw.length === 0) return fallback;
  return raw.length > 240 ? `${raw.slice(0, 237)}...` : raw;
}

function normalizeNonEmptyString(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function epdocAIDiffStaged(editor: Editor): boolean {
  return EPDOC_AI_DIFF_KEY.getState(editor.state) !== null;
}
