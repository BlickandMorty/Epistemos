// marks.ts — EPI-RP-02-LUMENLENS · Fork A (BINDING).
// The hwc schema: three marks (insertion / deletion / modification) plus the
// "block-mark trick" — the doc node must ALLOW these as block marks so a whole new
// block (e.g. an inserted list item) can be suggestion-marked.
//
// Reference: @handlewithcare/prosemirror-suggest-changes exposes addSuggestionMarks()
// and requires `marks: "insertion modification deletion"` on the doc node.

import { Schema, type MarkSpec } from "prosemirror-model";
import { addSuggestionMarks } from "@handlewithcare/prosemirror-suggest-changes";

/**
 * Provenance attrs we attach to the suggestion marks. The hwc marks natively key only
 * on a numeric id; we widen them with author + turnId so a mark points straight into
 * the agent_core provenance ledger. (Confirm exact attr merge against the installed
 * package's dist/schema.js — open question in the research; treat as inferred.)
 */
export const provenanceAttrs: MarkSpec["attrs"] = {
  suggestionId: {},                 // numeric or ULID; FK into the ledger
  author: { default: "user" },      // companion-id | "june" | "user"
  turnId: { default: null },
};

export function buildSchema(baseNodes: Record<string, unknown>, baseMarks: Record<string, unknown>): Schema {
  const nodes = {
    ...baseNodes,
    doc: { ...(baseNodes.doc as object), marks: "insertion modification deletion" },
  };
  const marks = addSuggestionMarks(baseMarks as never);
  return new Schema({ nodes: nodes as never, marks: marks as never });
  // TODO: merge provenanceAttrs into the insertion/modification/deletion mark specs
  //       returned by addSuggestionMarks (or fork the schema builder if it does not
  //       accept extra attrs).
}
