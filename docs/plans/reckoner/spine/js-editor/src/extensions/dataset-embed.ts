// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// 5 DEFECTS (all repo-verified against chart-node.ts / image-node.ts patterns):
//  1. `renderHTML … 0` content hole on an atom leaf — ProseMirror THROWS. Atom nodes render no hole.
//  2. Attr round-trip broken: declare data-dataset-id etc. per-attribute (parseHTML/renderHTML per
//     attr) or the node can't parse its own output.
//  3. `addNodeView() { return null as never }` is invalid — omit addNodeView in the stub, or return
//     a real NodeViewRenderer closure (chart-node.ts:90+ pattern).
//  4. NO markdown serialization: without markdownTokenName/parseMarkdown/renderMarkdown the node is
//     DROPPED by getMarkdown() — silent data loss into the .md truth. Non-negotiable to add.
//  5. Never registered in index.ts extensions array — dead code as shipped; and the "Tier B
//     registry" it cites is the tiers.ts CLASSIFIER contract, not a runtime API.
// GUARD PINS: adding a slash-menu item breaks EXACT pins — sourceCount("apply: (e)")==18
// (EpdocVisibilitySourceGuardTests:416), defaultCatalogue.count==19 + exact ID-set equality
// (EpdocSlashMenuViewTests:18,:34-45). Update those assertions IN THE SAME COMMIT, deliberately.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// The Tier-B note embed. THE NODE CARRIES A FILE REFERENCE, NEVER INLINE DATA —
// the note's markdown stays small, minimal-diff writeback stays minimal, and one
// dataset can live in many notes without duplication. Interior is not
// contentEditable; the payload is attrs only.
// (Dependencies / hand-off seam: serializer Tiers A/B/C and the js-editor node
// registry are owned by EPI-RP-02-LUMENLENS; this node registers into Tier B
// through that registry. Tiny static tables remain Tier-A markdown; "convert to
// dataset" promotes them to this node.)

import { Node, mergeAttributes } from "@tiptap/core";

export interface DatasetEmbedAttrs {
  datasetId: string;
  vaultPath: string;     // vault-relative; survives sync/move with the id
  viewSpec: string;      // JSON EmbedViewSpec
}

export const DatasetEmbed = Node.create({
  name: "datasetEmbed",
  group: "block",
  atom: true,

  addAttributes() {
    return {
      datasetId: { default: "" },
      vaultPath: { default: "" },
      viewSpec: { default: "{}" },
    };
  },

  parseHTML() {
    return [{ tag: "epistemos-dataset[data-dataset-id]" }];
  },

  renderHTML({ HTMLAttributes }) {
    return ["epistemos-dataset", mergeAttributes(HTMLAttributes), 0];
  },

  addNodeView() {
    // TODO: node view hosting embed-grid.mountEmbedGrid; "dataset not found —
    // relink?" placeholder on embedInvalidated; "Open in Data tab" affordance.
    return null as never;
  },
});

// Tier-B serialization contract: a fenced block carrying ONLY
// {datasetId, vaultPath, viewSpec}. Round-trip test: serialize(parse(x)) is
// byte-stable and contains zero cell data.
