# MAS C Feature Plan - LumenLens

ID: `MAS-C-F03-LUMENLENS-2026-07-08`
Codename: `LUMENLENS`
Status: active after MAS June

## Intent

Make Epdoc the MAS writing and evidence workspace: edit, cite, accept/reject
suggestions, show provenance, and preserve note fidelity.

## Scope

- Epdoc editing and note/source/prose modes.
- Suggestion adapter and minimal-diff writeback.
- Provenance ledger and visible rationale.
- Notebook/container tabs for notes, sources, and datasets.
- Integration with MAS June and Epdoc Assist.

## Fabric Mapping

- F1 vault bus: reads/writes note files and source artifacts.
- F2 agent capability registry: exposes edit, summarize, cite, and transform
  capabilities through MAS June.
- F3 MAS status/provenance: shows editing, suggesting, blocked, and applied
  states.
- F4 graph: links notes, sources, datasets, and entities.
- F5 provenance: records edit rationale, source evidence, and acceptance state.
- F6 event bus: streams suggestion and writeback lifecycle.

## Phases

1. Inventory Epdoc editor, provenance store, and suggestion paths.
2. Prove minimal-diff writeback on fixture notes.
3. Wire MAS June suggestion actions through the same approval path.
4. Add notebook tab integration for notes/sources/datasets.
5. Harden fidelity, undo, and provenance UI.

## Parked Or Forbidden

- No private editor store that becomes truth.
- No unapproved agent writeback.
- No Kindred runtime dependency.
- No web-only redesign of native shell surfaces.

## Acceptance Evidence

- Fixture note before/after with minimal diff.
- Provenance entry for an accepted and rejected suggestion.
- Undo proof.
- MAS June tool-call proof.
- Manual UI proof for Epdoc, provenance, and notebook tabs.

