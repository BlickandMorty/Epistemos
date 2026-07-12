# MAS C Local Source Anchors

ID: `MAS-C-LOCAL-SOURCE-ANCHORS-2026-07-08`

This map records current repo anchors for MAS C implementation agents. It is a
starting map, not a completion claim. Agents must still read the files and
nearby call sites before editing.

## Refresh Rule

Refresh this file when a feature moves from planning to implementation or when
new research changes the file map. Use focused `rg`/`rg --files` searches, then
update only the affected section.

Useful refresh searches:

```bash
rg -n "AtomicVaultWriter|EditorProvenanceStore|JuneEpdocAssist|EpdocCopilotDockView|JuneAgentGateway|GooseInProcessACPServer|hermes_bridge|VaultMCPServer|AppSurface|EPISTEMOS_APP_STORE|MAS_SANDBOX|network.server" Epistemos EpistemosTests project.yml scripts docs/prompts
rg --files Epistemos EpistemosTests scripts docs/prompts agent_core | rg "(Vault|Provenance|June|Epdoc|Copilot|Assist|AppStore|PrivacyInfo|entitlements|Release|Archive|Arxiv|Research|Capture|Sync|Dataset|Table|Reckoner)"
```

## Q1/Q2 - Keelstone And Release Pruning

Primary anchors:

- `project.yml`
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos/Resources/PrivacyInfo.xcprivacy`
- `Epistemos/App/AppSurface.swift`
- `scripts/keelstone-release-gate.sh`
- `scripts/scan_appstore_bundle.sh`
- `scripts/xcodebuild_epistemos.sh`
- `EpistemosTests/AppStoreHardeningTests.swift`
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`

Classification notes:

- `project.yml` owns App Store target membership, build scripts, macros, schemes,
  and privacy manifest/resource inclusion.
- `Epistemos/Epistemos-AppStore.entitlements` currently carries the App Store
  entitlement surface, including the `network.server` key that MAS C requires
  agents to justify or remove.
- `scripts/keelstone-release-gate.sh` already checks many release and data-safety
  witnesses; agents should extend this rather than creating an unrelated release
  gate.
- `scripts/scan_appstore_bundle.sh` is the focused bundle scan anchor for
  prohibited runtime strings, symbols, and resources.

## Q1/Q6/Q9 - Vault, Storage, Sync

Primary anchors:

- `Epistemos/Sync/AtomicVaultWriter.swift`
- `Epistemos/Sync/CoordinatedVaultFileMutation.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `Epistemos/Sync/ReadableBlocksProjector.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Sync/iCloudMaterializer.swift`
- `Epistemos/Sync/VaultImportFileCopier.swift`
- `Epistemos/Vault/VaultChatMutator.swift`
- `Epistemos/Vault/AgentApprovalPolicyStore.swift`
- `Epistemos/Vault/AgentSessionLineageStore.swift`
- `Epistemos/Vault/VaultLifecycleService.swift`
- `Epistemos/Vault/SkillVaultFileIO.swift`
- `Epistemos/Engine/EpdocMarkdownWriteThrough.swift`
- `Epistemos/Engine/VaultNoteEditor.swift`
- `Epistemos/Engine/EpdocBlockTemplateStore.swift`
- `EpistemosTests/VaultSyncServiceAuditTests.swift`
- `EpistemosTests/VaultIndexActorTests.swift`
- `EpistemosTests/VaultChatMutatorTests.swift`
- `EpistemosTests/VaultNoteEditorTests.swift`
- `EpistemosTests/EpdocMarkdownWriteThroughTests.swift`

Classification notes:

- `AtomicVaultWriter` is the current central write-safety anchor.
- `VaultSyncService`, `VaultIndexActor`, `SearchIndexService`, and
  `ReadableBlocksIndex` are the first source paths to read before changing
  storage truth, indexing, rebuild, or sync behavior.
- `ConflictCardView` is the current visible conflict UI anchor:
  `Epistemos/Views/Vault/ConflictCardView.swift`.

## Q3 - MAS June

Primary anchors:

- `Epistemos/JuneAgent/JuneAgentGateway.swift`
- `Epistemos/JuneAgent/JuneAgentBridge.swift`
- `Epistemos/JuneAgent/JuneSessionStore.swift`
- `Epistemos/JuneAgent/JuneAgentSurfaceView.swift`
- `Epistemos/JuneAgent/JuneAgentChrome.swift`
- `Epistemos/JuneAgent/JuneAgentApprovalRegistry.swift`
- `Epistemos/JuneAgent/JuneAgentCoreVaultScope.swift`
- `Epistemos/JuneAgent/JuneCloudEngine.swift`
- `Epistemos/JuneAgent/JuneSchemeHandler.swift`
- `Epistemos/JuneAgent/JuneWebAssets.swift`
- `Epistemos/Goose/GooseInProcessACPServer.swift`
- `Epistemos/Goose/GooseRuntimeSupervisor.swift`
- `EpistemosTests/AppStoreJuneHardeningTests.swift`
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`
- `EpistemosTests/AppStoreJuneSourceGuard.swift`
- `EpistemosTests/JuneWorkspaceAgentSourceGuardTests.swift`

Classification notes:

- `JuneAgentGateway.swift` currently references a Goose-named in-process helper;
  classify this through `legacy-name`, `active-mas`, or `forbidden-mas-runtime`
  before editing.
- `JuneAgentBridge.swift` contains `hermes_bridge_*` handler names. MAS C treats
  these as classification targets, not automatic deletion targets.
- App Store June hardening tests already encode several bridge and substrate
  expectations; extend them when changing June bridge behavior.

## Q4/Q5 - Epdoc Assist And LumenLens

Primary anchors:

- `Epistemos/JuneAgent/JuneEpdocAssist.swift`
- `Epistemos/Views/Epdoc/EpdocCopilotDockView.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `Epistemos/Views/Notes/EditorProvenanceStore.swift`
- `Epistemos/Engine/EpdocEditorBridge.swift`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Engine/EpdocAIDiffReview.swift`
- `Epistemos/Engine/AgentNoteEditProvenance.swift`
- `Epistemos/Engine/RustProvenanceLedgerClient.swift`
- `EpistemosTests/EpdocCopilotSurfaceTests.swift`
- `EpistemosTests/EditorProvenanceStoreTests.swift`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosTests/EpdocEndToEndSmokeTests.swift`
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`

Classification notes:

- Epdoc Assist is already present as a native dock path; do not route it through
  a separate agent surface.
- `EditorProvenanceStore.swift` and its tests are the first provenance anchors
  before changing suggestion/writeback behavior.

## Q7 - Reckoner

Primary anchors found:

- `docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`
- `docs/prompts/PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_9_RECKONER.md`
- `Epistemos/Engine/DataviewBlockRunner.swift`
- `Epistemos/Engine/DataviewService.swift`
- `Epistemos/Engine/EpdocDatabase.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift`
- `EpistemosTests/DataviewBlockRunnerTests.swift`
- `EpistemosTests/DataviewServiceTests.swift`
- `EpistemosTests/EpdocDatabaseTests.swift`
- `EpistemosTests/HTMLWorkspaceDataFeedContextSourcesTests.swift`

Grounding gap:

- The focused local search did not surface obvious `IronCalc`, `Univer`, or
  `Reckoner` implementation source files. Treat Reckoner as plan/research plus
  adjacent data-view infrastructure until a future agent proves exact current
  source ownership.

## Q8 - Embercatch

Primary anchors:

- `docs/prompts/PROMPT_PLAN_6_QUICKCAPTURE.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_6_QUICKCAPTURE.md`
- `Epistemos/Engine/TextCapturePipeline.swift`
- `Epistemos/Engine/MeetingNoteCaptureService.swift`
- `Epistemos/Engine/UnavailableAudioCapture.swift`
- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `Epistemos/Engine/LiveVoiceInputService.swift`
- `Epistemos/Engine/ComposerVoiceInputService.swift`
- `Epistemos/Engine/VoicePreferences.swift`
- `Epistemos/Views/Capture/QuickCaptureView.swift`
- `Epistemos/Views/Capture/QuickCaptureReadBack.swift`
- `Epistemos/Views/Capture/TraceInspectorView.swift`
- `EpistemosTests/TextCapturePipelineTests.swift`
- `EpistemosTests/MeetingNoteCaptureServiceTests.swift`
- `EpistemosTests/QuickCaptureVoiceHonestyTests.swift`
- `EpistemosTests/SSQCQuickCaptureReadBackTests.swift`

Classification notes:

- Text capture should be proven before voice capture.
- Voice work must be checked against privacy manifest, permissions, and honest
  unavailable-state behavior.

## Q10 - Lodestar And Research Sources

Primary anchors:

- `docs/prompts/PROMPT_PLAN_8_RESEARCHHUB.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_8_RESEARCHHUB.md`
- `Epistemos/Arxiv/ArxivClient.swift`
- `Epistemos/Arxiv/ArxivIngestService.swift`
- `Epistemos/Arxiv/ArxivPullGateStatus.swift`
- `Epistemos/Views/Arxiv/ArxivSearchView.swift`
- `Epistemos/Engine/DeepResearchGateStatus.swift`
- `Epistemos/Engine/DeepResearchReport.swift`
- `Epistemos/Engine/VaultSemanticBacklinks.swift`
- `Epistemos/Views/Settings/DeepResearchHealthRow.swift`
- `EpistemosTests/ArxivPlan3Tests.swift`
- `EpistemosTests/ResearchModeTests.swift`
- `EpistemosTests/DeepResearchGateStatusTests.swift`
- `EpistemosTests/DeepResearchReportRendererTests.swift`

Release-pruning watchlist surfaced by local search:

- `Epistemos/Resources/Pyodide/`
- `Epistemos/Resources/opencode-runtime/`
- `Epistemos/Resources/experimental-runtime/`

These resources require target-membership and archive-scan classification before
any MAS release claim.

## Q11 - Capabilities

Primary anchors:

- `Epistemos/Security/CapabilityBridge.swift`
- `Epistemos/Bridge/ToolTierBridge.swift`
- `Epistemos/VaultMCP/VaultMCPServer.swift`
- `Epistemos/VaultMCP/VaultMCPHost.swift`
- `Epistemos/VaultMCP/VaultMCPCore.swift`
- `Epistemos/VaultMCP/VaultMCPTokenStore.swift`
- `Epistemos/Views/Settings/VaultMCPServerSettingsRow.swift`
- `EpistemosTests/VaultMCPServerLifecycleTests.swift`
- `EpistemosTests/VaultMCPCoreTests.swift`
- `scripts/vault-mcp-smoke.swift`

Classification notes:

- Vault MCP and loopback behavior are entitlement-sensitive. Classify as
  MAS-safe loopback, parked/pro-only, or blocker before implementation edits.

## Q12 - Sigilry And Visible MAS Shell

Primary anchors:

- `Epistemos/App/RootView.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/Views/Landing/LandingFeatureButtons.swift`
- `Epistemos/JuneAgent/JuneAgentChrome.swift`
- `Epistemos/JuneAgent/JuneAgentNavBar.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Epdoc/EpdocEditorToolbar.swift`
- `Epistemos/Views/Shared/AssistantResponseChrome.swift`
- `Epistemos/Resources/`

Classification notes:

- Sigilry needs screenshot evidence. Source anchors alone cannot prove native
  quality, text fit, state truth, or visual coherence.

