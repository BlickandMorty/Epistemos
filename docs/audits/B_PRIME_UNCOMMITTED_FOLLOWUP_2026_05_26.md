# B-Prime Uncommitted Follow-up Preservation - 2026-05-26

Branch: `phase2-terminal-b-prime-chat-citations-2026-05-24`

Preserved patch:

```text
/tmp/b-prime-uncommitted-final.patch
```

## Classification

### Belongs to Chat Citation / VaultRecall Provenance

No additional uncommitted files remain in this category after commit `2b80187417c6` (`Add production vault recall search traces`).

That commit moved the remaining B-prime provenance work into PR #79:

- `Epistemos/Sync/SearchIndexService.swift`: production `VaultRecallTrace` builders for search-index and RRF results.
- `Epistemos/Sync/VaultSyncService.swift`: replacement of scaffold `VaultRecallBridge.trace(query:)` breadcrumbs with measured production trace recording behind `VaultRecallFlags`.

### Unrelated But Valuable Follow-up

- HTML Workspace / document surface:
  - `Epistemos/Engine/HTMLWorkspaceDocument.swift`
  - `Epistemos/Engine/HTMLWorkspacePDFExporter.swift`
  - `Epistemos/Engine/HTMLWorkspacePatchRouter.swift`
  - `Epistemos/Models/DocumentSurface.swift`
  - `Epistemos/Models/HTMLWorkspacePackage.swift`
  - `Epistemos/Views/HTMLWorkspace/*`
  - related plist, `ChatTypes`, `ChatCoordinator`, `MiniChat`, `NotesMentionDropdown`, and document-controller wiring.
- Settings truth floor / substrate health:
  - `Epistemos/Views/Settings/*HealthRow.swift`
  - `Epistemos/Views/Settings/SettingsView.swift`
  - `Epistemos/Views/Settings/SubstrateHealthPanel.swift`
  - `Epistemos/Views/Settings/SettingsSurfaceComponents.swift`
  - `docs/audits/SETTINGS_TRUTH_FLOOR_2026_05_24.md`
  - `docs/audits/SUBSTRATE_HEALTH_ROW_EXPANSION_2026_05_24.md`
  - `docs/audits/user-decisions/T0-verified-floor-xcode-verification-2026-05-24.md`
- Ambient frequency/audio and theme/UI refinement:
  - `Epistemos/Engine/AmbientFrequencyAudioGenerator.swift`
  - `Epistemos/Engine/AmbientFrequencyLivePlayer.swift`
  - `Epistemos/State/AmbientFrequencyPlaybackState.swift`
  - related tests, settings, theme, landing, graph, and sidebar changes.
- Local agent / tool repair:
  - `Epistemos/Bridge/ToolTierBridge.swift`
  - `Epistemos/LocalAgent/LocalAgentLoop.swift`
  - `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`
  - `Epistemos/Omega/Inference/ToolCallParser.swift`
  - related tests.
- Eidos/search-index follow-up:
  - remaining `Epistemos/Sync/SearchIndexService.swift` hunks mirror search-index pages into Eidos when open.
  - `EpistemosTests/EidosBridgeProductionTests.swift` adds coverage for that path.
- Doctrine/docs/artifact follow-up:
  - `agent_core/src/bin/epistemos_doctrine_lint.rs`
  - `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
  - `docs/fusion/NO_COMPROMISE_DOCUMENT_WORKSPACE_IMPLEMENTATION_PLAN_2026_05_25.md`
  - `artifacts/lattice-coordinate-explainer/index.html`

### Generated / Bundle Output

- `Epistemos/Resources/Editor/editor.css.br`
- `Epistemos/Resources/Editor/editor.js.br`
- `Epistemos/Resources/Editor/vendor/mermaid/mermaid.min.js.br`
- `Epistemos/Resources/Editor/vendor/mermaid/mermaid.min.js.LICENSE.txt`
- `js-editor/package-lock.json`

### Accidental Or Obsolete

Likely obsolete as standalone artifacts after the HTML Workspace editor direction replaced Mermaid document graphs:

- `js-editor/scripts/check-document-graph.mjs`
- `js-editor/src/extensions/mermaid-node.ts`
- `js-editor/src/graph/document-graph.ts`

These were not discarded. They are included in `/tmp/b-prime-uncommitted-final.patch` and should be reviewed with the HTML Workspace/editor follow-up before deletion is accepted.

## Preservation Action

The non-B-prime changes should be moved out of the active PR worktree before validation. They are preserved by the binary patch above and by a local stash created during this cleanup pass.
