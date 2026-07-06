# KINDRED_SPINE — EPI-RP-05-KINDRED

ID: EPI-RP-05-KINDRED · Codename: KINDRED

The Companions layer: ONE living agent identity across four surfaces — landing Farm
roster, 1Code main agent, Epdoc mascot bubble, Epdoc sidebar minichat — that jumps to
wherever it is actually working, and on the editor *feels like a real creature editing
your document*. 1Code/Experimental only. MAS shows no companion surface.

This is a **code spine**: real files, real contracts, `// TODO:` where bodies go. It plugs
into the LUMENLENS spine (EPI-RP-02) as an external interface — it does not re-implement it.

## The non-negotiables baked into these files
- **1Code-only gate.** Every companion file is `#if KINDRED_ENABLED`; a leak-detector CI
  row proves no companion symbol reaches the MAS build.
- **Skin over real state.** `CompanionAnimationState` maps 1:1 to real `RunState` from
  `agent_core`. No emote exists without a backing run event. Fake "thinking" is forbidden.
- **Honest gating.** A companion MAY hold a persona preamble + a persona-scoped vault-MCP
  READ binding + chat. Tools / file writes / network / destructive ops require per-turn
  approval. See `authority/gating.rs`.
- **Editor integrity.** Companion edits enter through the LUMENLENS `SuggestionAdapter` as
  suggestion-marked ProseMirror transactions. Never a shadow editor, never blind setContent.
- **Provenance is real.** "Press mascot -> see edits" reads the LUMENLENS provenance ledger.
- **Platform hygiene.** @Observable (not ObservableObject); UniFFI callbacks hop
  DispatchQueue.main.async (never .sync); keys in Keychain, never UserDefaults.

## File map
- `agent_core/src/companion/run_state.rs` — the run-state enum + real event source.
- `agent_core/src/companion/presence.rs` — CompanionPresence CRDT (Yjs-awareness style:
  one entry, monotonic clock, last-writer-wins, coalesced fan-out) + PresenceSink trait.
- `agent_core/src/companion/authority/gating.rs` — the bound-vs-per-turn authority boundary.
- `Epistemos/State/Companion/CompanionState.swift` — @Observable presence consumer.
- `Epistemos/Models/Companion/CompanionModel.swift` — SwiftData model + authority doctrine.
- `Epistemos/Models/Companion/CompanionAnimationState.swift` — emote skin over RunState.
- `Epistemos/Views/Landing/Farm/*` — roster, cell, glyph (Rive native render path).
- `Epistemos/ExperimentalAgent/MinichatDock.swift` — the 1code-fork extraction seam.
- `js-editor/src/companion/embodied-presence.ts` — coordsAtPos sprite, rAF transform-only.
- `js-editor/src/companion/presence-bridge.ts` — WebView side of the state bus.
- `mascot/companion.riv.README.md` — the single Rive artifact (both render paths).

## Depends on (external seams, EPI-RP-02-LUMENLENS)
- `SuggestionAdapter.ingestAgentEdit` — companion token stream entry point.
- provenance ledger (`ledger.rs` / `replay.rs`) — press-mascot-to-see-edits + revert-turn.
- epoch-stamped Epdoc bridge — carries presence + the embodied sprite's edit position.
