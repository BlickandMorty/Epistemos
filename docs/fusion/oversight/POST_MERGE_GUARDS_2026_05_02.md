# Post-Merge Guards - 2026-05-02

## sovereign-gate-settings-vault-disconnect-pr16

- grep: `rg -n "vaultDisconnect\\(name:|requestVaultDisconnectAuthorization\\(vaultURL:|isVaultDisconnectAuthorizationInFlight|guard vaultSync\\.vaultURL\\?\\.standardizedFileURL == vaultURL\\.standardizedFileURL else \\{ return \\}" Epistemos/Views/Settings/SettingsView.swift EpistemosTests/SovereignGateTests.swift`
- forbidden grep: `rg -n "LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy" Epistemos/Views/Settings/SettingsView.swift`
- staged guard: `git diff --cached -- Epistemos/Views/Settings/SettingsView.swift | rg -n 'BackgroundIndexingHealthRow|SearchFusionHealthRow|Read-only health probes.*Halo backend'` must return no matches.
- log: `/tmp/epistemos-sovereign-gate-settings-vault-disconnect-pr16-green-20260502-rerun.log`
- log: `✔ Test "Settings vault disconnect maps to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Settings vault disconnect routes through Sovereign Gate" passed`
- log: `✔ Test run with 33 tests in 1 suite passed`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test`

## sovereign-gate-settings-workspace-delete-pr15

- grep: `rg -n "savedWorkspace\\(name:|requestSavedWorkspaceDeleteAuthorization\\(|deleteSavedWorkspace\\(" Epistemos/Views/Settings/SettingsView.swift EpistemosTests/SovereignGateTests.swift`
- forbidden grep: `rg -n "LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy" Epistemos/Views/Settings/SettingsView.swift`
- log: `/tmp/epistemos-sovereign-gate-settings-workspace-pr15-green-20260502.log`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateTests test`

## graph-event-trace-inspector-projection-pr9

- grep: `graphProjectionReport|loadTask?.cancel()|GraphEventAuditProjectionService().auditReport(limit: 100)|Graph projection`
- grep: `nonisolated final class GraphEventAuditProjectionService: @unchecked Sendable`
- forbidden grep: `saveGraphEvent|saveMutationEnvelope|graphEvents\(|MutationOpLog|OpLog|HaloController|GraphEventVisibilityRow|Timer|DispatchSourceTimer|repeatForever|while !Task\.isCancelled`
- staged guard: `git diff --cached --name-only -- Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core epistemos-core Epistemos/State/EventStore.swift Epistemos/Models/MutationEnvelope.swift Epistemos/Views/Settings Epistemos.xcodeproj` returns empty.
- log: `✔ Test "trace inspector exposes read-only GraphEvent projection summary" passed`
- log: `✔ Test run with 4 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-graph-event-trace-inspector-pr9-green-20260502.log`; Xcode exited 0 and printed `** TEST SUCCEEDED **` after the focused `GraphEventAuditProjectionTests` run.
- test: `GraphEventAuditProjectionTests`

## graph-event-audit-visibility-pr8

- grep: `GraphEventAuditProjectionService().auditReport(limit: 100)`
- grep: `graphEventProjectionSnapshot(limit:)`
- forbidden grep: `saveGraphEvent|saveMutationEnvelope|graphEvents\(|Timer|DispatchSourceTimer`
- log: `GraphEvent audit visibility hardened source guard passed`
- test/log: `✔ Test "GraphEvent visibility row is read-only and mounted in Settings" passed`

## agent-grep-agent-event-pr14

- grep: `toolName: "agent_grep.search"`
- grep: `agentGrepSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|resultJSON.*snippet|resultJSON.*vaultRelativePath|resultJSON.*provenance`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine Epistemos/Views Epistemos/Omega Epistemos.xcodeproj Epistemos/State/EventStore.swift`
- log: `✔ Test "search records sanitized AgentEvents" passed`
- test: `AgentGrepService (Wave 9.9 base)`

## agent-query-engine-agent-event-pr15

- grep: `toolName: name`
- grep: `agentQueryEngineToolArgumentsJSON`
- forbidden grep: `argumentsJSON.*prompt|argumentsJSON.*history|argumentsJSON.*cwd|resultJSON.*output|resultJSON.*text|toolInput`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine Epistemos/Views Epistemos/Omega Epistemos.xcodeproj Epistemos/State/EventStore.swift Epistemos/App/ChatCoordinator.swift Epistemos/Engine/PipelineService.swift Epistemos/LocalAgent/LocalAgentLoop.swift Epistemos/Engine/LLMService.swift`
- log: `✔ Test "AgentQueryEngine records sanitized backend tool AgentEvents" passed`
- test: `AgentQueryEngine AgentEvent provenance`

## instant-recall-agent-event-pr16

- grep: `toolName: "instant_recall.search"`
- grep: `instantRecallSearchArgumentsJSON`
- forbidden grep: `argumentsJSON.*query|argumentsJSON.*text|argumentsJSON.*doc|resultJSON.*query|resultJSON.*text|resultJSON.*doc|resultJSON.*body`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine Epistemos/Views Epistemos/Omega Epistemos.xcodeproj Epistemos/State/EventStore.swift Epistemos/App/ChatCoordinator.swift Epistemos/Engine/PipelineService.swift Epistemos/LocalAgent/LocalAgentLoop.swift Epistemos/Engine/LLMService.swift Epistemos/Engine/ShadowSearchService.swift Epistemos/Engine/HaloController.swift Epistemos/Engine/HaloEditorBridge.swift`
- log: `✔ Test "Search records sanitized AgentEvents" passed`
- test: `InstantRecall — Service`

## instant-recall-async-agent-event-pr17

- grep: `instant-recall-async-`
- grep: `instant-recall-search-async`
- grep: `surface: "instant_recall_async"`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage).*(query_text|queryText|note_id|noteId|note_body|noteBody|snippet|embedding|score|raw_json|localizedDescription)`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine Epistemos/Views Epistemos/Omega Epistemos.xcodeproj Epistemos/State/EventStore.swift Epistemos/App/ChatCoordinator.swift Epistemos/Engine/PipelineService.swift Epistemos/LocalAgent/LocalAgentLoop.swift Epistemos/Engine/LLMService.swift Epistemos/Engine/ShadowSearchService.swift Epistemos/Engine/HaloController.swift Epistemos/Engine/HaloEditorBridge.swift`
- log: `✔ Test "Async search records sanitized AgentEvents" passed`
- log: `✔ Test "Async search records completed AgentEvents for valid zero-hit results" passed`
- log: `✔ Test "Cancelled async search records terminal AgentEvent" passed`
- test: `InstantRecall — Service`

## shadow-search-agent-event-pr18

- grep: `toolName: "shadow_search.search"`
- grep: `surface: "shadow_search"`
- grep: `shadow-search:`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage|metadata).*(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\(describing:.*error)`
- staged guard: `git diff --cached --name-only -- agent_core graph-engine epistemos-shadow Epistemos/Views Epistemos/Graph Epistemos/State/EventStore.swift Epistemos/Models/AgentProvenanceEvent.swift Epistemos/Engine/RustShadowFFIClient.swift Epistemos/Engine/ShadowFFIClient.swift Epistemos.xcodeproj`
- log: `✔ Test "ShadowSearchService.search records sanitized AgentEvents" passed`
- log: `✔ Test "ShadowSearchService.search records completed AgentEvents for valid zero-hit results" passed`
- log: `✔ Test "Cancelled ShadowSearchService.search records terminal failed AgentEvent" passed`
- test: `Shadow service actors (Wave 8.3)`

## search-index-service-fused-async-agent-event-pr19

- grep: `search-index-fused-async-`
- grep: `toolName: "search_index.fused_search_async"`
- grep: `"surface": "fused_search_async"`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage|metadata).*(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\(describing:.*error|sanitized)`
- forbidden grep: `(log\.|os_log|Logger).*\(error`
- forbidden grep: `Task\s*(\.detached)?\s*\{[^\n]*(recordToolEvent|AgentToolProvenanceRecorder)`
- forbidden sync grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"` returns empty
- staged guard: `git diff --cached --name-only -- agent_core graph-engine epistemos-shadow Epistemos/Views Epistemos/Graph Epistemos/State/EventStore.swift Epistemos/Models/AgentProvenanceEvent.swift Epistemos/Sync/RRFFusionQuery.swift Epistemos/Sync/VaultSyncService.swift Epistemos/Engine/QueryRuntime.swift Epistemos.xcodeproj`
- log: `✔ Test "fusedSearchAsync provenance surface stays bounded and sync fusedSearch remains direct" passed`
- log: `✔ Test run with 55 tests in 5 suites passed after 0.063 seconds.`
- note: expanded verification log `/tmp/epistemos-search-fusion-substrate-pr19-green-20260502.log` covered `RRFFusionQueryTests`, `ReadableBlocksIndexTests`, `ReadableBlocksProjectorTests`, and `SearchIndexService AgentEvent source guards`; `SearchIndexService — RRF Fusion (Phase 5)` runtime tests compile but are skipped on this host by the pre-existing FTS5 availability gate.
- test: `RRFFusionQueryTests + ReadableBlocksIndexTests + ReadableBlocksProjectorTests + SearchIndexService AgentEvent source guards`

## oplog-replay-bundle-export-pr5

- grep: `MutationOpLogReplayBundle`
- grep: `exportMutationReplayBundle`
- forbidden grep: `sourcePayloadJSON.*Record|source_payload_json.*Record|oplog_append_payload_json|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows`
- staged guard: `git diff --cached --name-only -- Epistemos/State/EventStore.swift Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Views graph-engine epistemos-shadow agent_core Epistemos.xcodeproj`
- log: `✔ Test "Mutation OpLog replay exports deterministic ReplayBundle JSON" passed`
- test: `OpLog Swift Bridge`

## oplog-incremental-replay-pr6

- grep: `MutationOpLogReplay.applyIncremental`
- grep: `incrementalReplayMutationProjections`
- forbidden grep: `oplog_append_payload_json|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows`
- staged guard: `git diff --cached --name-only -- Epistemos/State/EventStore.swift Epistemos/Engine/RustOpLogFFIClient.swift Epistemos/Engine/MutationOpLogProjector.swift Epistemos/Engine/MutationOpLogProjectionWorker.swift Epistemos/Views graph-engine epistemos-shadow agent_core Epistemos.xcodeproj`
- log: `✔ Test "Mutation OpLog incremental replay matches full replay" passed`
- log: `✔ Test "Mutation OpLog incremental ReplayBundle remains privacy safe" passed`
- test: `OpLog Swift Bridge`

## oplog-replay-bundle-production-visibility-pr7

- grep: `MutationOpLogReplayBundleVisibilityReport`
- grep: `ReplayBundle`
- forbidden grep: `oplog_open_at|oplog_append_payload_json|oplog_iter_all_json|exportMutationReplayBundle\(|claimMutationProjectionOutboxRows\(|recordMutationProjectionOutboxFailure\(|markMutationProjectionOutboxProjected\(|Button\(|Timer|DispatchSourceTimer|\.task \{|while !Task\.isCancelled`
- staged guard: `git diff --cached --name-only -- Epistemos/Views/Notes Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core epistemos-shadow Epistemos.xcodeproj`
- log: `✔ Test "OpLog projection diagnostics row is read-only and mounted in Settings" passed`
- log: `✔ Test "Mutation OpLog ReplayBundle visibility report summarizes counts" passed`
- log: `✔ Test "Mutation OpLog ReplayBundle visibility report loads read-only" passed`
- log: `✔ Test run with 17 tests in 2 suites passed`
- test: `OpLogFFIBoundaryGuardTests + OpLogSwiftBridgeTests`

## hermes-gateway-evidence-return-policy-pr7

- grep: `HermesGatewayEvidenceReturn`
- grep: `requiresStructuredEvidenceReturn`
- grep: `evidenceReturn: .structuredEvidenceProvenance`
- forbidden grep: `Process\.|URLSession|MCPBridge|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy`
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core Epistemos.xcodeproj`
- log: `✔ Test "external gateway surfaces require structured evidence provenance" passed`
- log: `✔ Test "evidence return follows the gateway route" passed`
- log: `✔ Test run with 11 tests in 1 suite passed`
- test: `Hermes Gateway Policy`

## agent-event-sync-recorder-enabler-pr0

- grep: `final class AgentToolProvenanceSyncRecorder`
- grep: `private let sequenceLock = NSLock()`
- grep: `AgentToolProvenanceEventFactory.makeToolEvent`
- forbidden grep: `DispatchQueue\.main\.sync|MainActor\.assumeIsolated|Task\.detached|Task \{` in `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- forbidden sync grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"` returns empty
- hunk-scoped tier grep: `git diff -- Epistemos/Engine/AgentToolProvenanceRecorder.swift EpistemosTests/CognitiveSubstrateTests.swift | rg -n 'Hermes|MCP|stdio_subprocess|docker|cli_passthrough|computer_use|_ANEClient|MTLBuffer.*contents|disable-library-validation'` returns empty for this slice's hunks
- log: `✔ Test "Agent tool provenance sync recorder persists ordered lifecycle events" passed`
- log: `✔ Test "Agent tool provenance sync recorder preserves payload semantics and EventStore schema" passed`
- log: `✔ Test "Agent tool provenance sync recorder refuses incomplete identities" passed`
- log: `✔ Test "Agent tool provenance sync recorder source stays non bridged" passed`
- log: `✔ Test run with 38 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-sync-recorder-enabler-pr0-green-20260502.log`; Xcode printed `** TEST SUCCEEDED **` followed by the known SwiftLint plugin footer noise.
- test: `EventStoreSchemaTests`

## search-index-service-fused-sync-agent-event-pr20

- grep: `search-index-fused-sync-`
- grep: `toolName: "search_index.fused_search"`
- grep: `"surface": "fused_search"`
- grep: `AgentToolProvenanceSyncRecorder`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage|metadata).*(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\(describing:.*error|sanitized|pageWeight|blockWeight)`
- forbidden sync grep: `git grep -n -A 45 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | rg "Task|DispatchQueue\.main\.sync|MainActor\.assumeIsolated"` returns empty
- staged guard: `git diff --cached --name-only -- agent_core graph-engine epistemos-shadow Epistemos/Views Epistemos/Graph Epistemos/State/EventStore.swift Epistemos/Models/AgentProvenanceEvent.swift Epistemos/Sync/RRFFusionQuery.swift Epistemos/Sync/VaultSyncService.swift Epistemos/Engine/QueryRuntime.swift Epistemos.xcodeproj`
- log: `✔ Test "fusedSearch provenance surfaces stay bounded" passed`
- log: `✔ Test run with 19 tests in 2 suites passed`
- note: focused verification log `/tmp/epistemos-search-index-fused-sync-agent-event-pr20-green-20260502.log`; `SearchIndexService — RRF Fusion (Phase 5)` runtime tests compile but are skipped on this host by the pre-existing FTS5 availability gate, so the non-gated source guard is the live verification floor for PR20 here.
- test: `SearchIndexServiceFusionTests + SearchIndexServiceAgentEventSourceGuardTests`

## sovereign-gate-model-vault-delete-pr9

- grep: `ModelVaultDeletionSovereignGate`
- grep: `requestDeleteAuthorization(target)`
- grep: `AppBootstrap.shared?.sovereignGate.confirm(`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "Model vault deletes map to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Model vault delete alert routes through captured Sovereign Gate target" passed`
- log: `✔ Test run with 19 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-model-vault-pr9-green-r2-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## sovereign-gate-custom-tool-delete-pr10

- grep: `AgentControlSettingsDeletionSovereignGate`
- grep: `requestCustomToolDeleteAuthorization`
- grep: `AppBootstrap.shared?.sovereignGate.confirm(`
- forbidden grep: `LocalAuthentication|LAContext|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Settings/AgentControlSettingsView.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "Agent control custom tool deletes map to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Agent control custom tool delete routes through Sovereign Gate" passed`
- log: `✔ Test run with 21 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-custom-tool-pr10-green-r2-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## sovereign-gate-notes-vault-disconnect-pr11

- grep: `case vaultDisconnect(name: String)`
- grep: `requestVaultDisconnectAuthorization(vaultURL:)`
- grep: `isVaultDisconnectAuthorizationInFlight`
- grep: `guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }`
- forbidden grep: `LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Notes/NotesSidebar.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "Notes sidebar vault disconnect maps to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Notes sidebar vault disconnect routes through Sovereign Gate" passed`
- log: `✔ Test run with 23 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-notes-vault-disconnect-pr11-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## sovereign-gate-authority-reset-pr12

- grep: `AuthoritySettingsSovereignGate`
- grep: `requestResetToDefaultsAuthorization()`
- grep: `requestQuickSetupAuthorization(preset)`
- grep: `?? .denied(.authenticationFailed)` in `Epistemos/Views/Settings/AuthoritySettingsView.swift`
- forbidden grep: `LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Settings/AuthoritySettingsView.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "Authority settings batch policy changes map to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Authority settings batch policy changes route through Sovereign Gate" passed`
- log: `✔ Test run with 25 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-authority-reset-pr12-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## sovereign-gate-overseer-history-reset-pr13

- grep: `OverseerSettingsSovereignGate`
- grep: `requestHistoryResetAuthorization()`
- grep: `resetHistory()`
- grep: `?? .denied(.authenticationFailed)` in `Epistemos/Views/Settings/OverseerSettingsView.swift`
- forbidden grep: `LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Settings/OverseerSettingsView.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "Overseer history reset maps to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Overseer history reset routes through Sovereign Gate" passed`
- log: `✔ Test run with 27 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-overseer-history-pr13-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## sovereign-gate-settings-reset-everything-pr14

- grep: `SettingsViewDestructiveActionSovereignGate`
- grep: `requestResetEverythingAuthorization()`
- grep: `resetEverything()`
- grep: `?? .denied(.authenticationFailed)` in `Epistemos/Views/Settings/SettingsView.swift`
- forbidden grep: `LocalAuthentication|LAContext|LAError|LABiometryType|LAPolicy|canEvaluatePolicy|evaluatePolicy` in `Epistemos/Views/Settings/SettingsView.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- staged guard: `git diff --cached -- Epistemos/Views/Settings/SettingsView.swift | rg -n 'BackgroundIndexingHealthRow|SearchFusionHealthRow|Read-only health probes.*Halo backend'` must return no matches.
- log: `✔ Test "Settings reset everything maps to destructive Sovereign Gate requirements" passed`
- log: `✔ Test "Settings reset everything alert routes through Sovereign Gate" passed`
- log: `✔ Test run with 29 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-sovereign-gate-settings-reset-pr14-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `SovereignGateTests` run.
- test: `SovereignGateTests`

## hermes-provider-surface-policy-pr8

- grep: `cloudProviderSurfaces`
- grep: `case openAIProvider`
- grep: `case anthropicProvider`
- grep: `case googleProvider`
- grep: `case openAICompatibleProvider`
- grep: `case codexAccountProvider`
- grep: `externalGatewaySurfaces: [Self] = cloudProviderSurfaces`
- forbidden grep: `URLSession|Process\.|MCPBridge|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy|CloudLLMClient|CloudProviderAuthService|LLMService|TriageService` in `Epistemos/LocalAgent/HermesGatewayPolicy.swift` and `EpistemosTests/HermesGatewayPolicyTests.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Engine Epistemos/Omega Epistemos/Views Epistemos/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "named cloud provider surfaces are gateway only" passed`
- log: `✔ Test "external gateway surfaces compose all cloud provider surfaces" passed`
- log: `✔ Test run with 13 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-hermes-provider-surface-pr8-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `HermesGatewayPolicyTests` run, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `HermesGatewayPolicyTests`

## tool-surface-policy-core-mas-pr1

- grep: `coreAppStoreAllowedToolNames`
- grep: `isCoreAppStoreBuild`
- grep: `APP_SANDBOX_CONTAINER_ID`
- grep: `route_private` must not appear in `Epistemos/Bridge/ToolTierBridge.swift`
- grep: `sandboxEnvironmentForcesCoreAppStorePolicy`
- forbidden grep: `Process\(\)|Foundation\.Process|URLSession|MCPBridge|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy|CloudLLMClient|CloudProviderAuthService|LLMService|TriageService` in `Epistemos/Bridge/ToolTierBridge.swift` and `EpistemosTests/ToolSurfacePolicyTests.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Engine Epistemos/Omega Epistemos/Views Epistemos/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- log: `✔ Test "coreAppStoreHiddenGatewayToolsDisappearFromVisibleToolSurfaces()" passed`
- log: `✔ Test "sandboxEnvironmentForcesCoreAppStorePolicy()" passed`
- log: `✔ Test run with 7 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-tool-surface-policy-core-mas-pr1-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `ToolSurfacePolicyTests` run, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `ToolSurfacePolicyTests`

## omega-tool-registry-core-planning-pr1

- grep: `planningSchemas(distribution:`
- grep: `planningSchemasJson(distribution:`
- grep: `catalogJson(distribution:`
- grep: `planningPromptBlock(distribution:`
- grep: `builtinCatalogJson(distribution:`
- grep: `builtinToolsJson()` must remain inside `OmegaToolRegistry.catalogJson(distribution:)`
- forbidden grep: `Process\(\)|Foundation\.Process|URLSession|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy|CloudLLMClient|CloudProviderAuthService|LLMService|TriageService` in `Epistemos/Omega/MCPBridge.swift` and `EpistemosTests/OmegaToolSchemaGrammarTests.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Engine Epistemos/Views Epistemos/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Omega/MCPBridge.swift` is allowed under `Epistemos/Omega` for this slice.
- log: `✔ Test "Omega Core App Store planning schemas hide Pro gateway tools" passed`
- log: `✔ Test "MCP Bridge Core App Store catalog hides Pro gateway tools" passed`
- log: `✔ Test "MCP Bridge Pro catalog preserves Rust source of truth" passed`
- log: `✔ Test "Omega planning schemas stay backed by the visible catalog" passed`
- log: `✔ Test run with 18 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-omega-tool-registry-core-planning-pr1-green-final-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after the focused `ToolSchemaGrammarTests` run, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `ToolSchemaGrammarTests`

## omega-dispatch-core-execution-gate-pr1

- grep: `resolvedDistribution(_ distribution: Distribution) -> Distribution` in `Epistemos/Bridge/ToolTierBridge.swift`
- grep: `func dispatch(`
- grep: `distribution: ToolSurfacePolicy.Distribution = .currentBuild`
- grep: `policyGateResponse`
- grep: `jsonRpcError`
- grep: `Omega Core App Store dispatch denies Pro gateway tool calls`
- forbidden grep: `registerBuiltinTools|McpDispatcher\\(|builtinToolsJson\\(\\)|URLSession|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy|CloudLLMClient|CloudProviderAuthService|LLMService|TriageService` in the staged diff for `Epistemos/Omega/MCPBridge.swift` and `EpistemosTests/OmegaToolSchemaGrammarTests.swift`, except pre-existing unchanged lines in `MCPBridge.swift`.
- staged guard: `git diff --cached --name-only -- Epistemos/Engine Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Bridge/ToolTierBridge.swift` and `Epistemos/Omega/MCPBridge.swift` are allowed app-code files for this slice.
- log: `✔ Test "Omega Core App Store dispatch list hides Pro gateway tools" passed`
- log: `✔ Test "Omega Pro Research dispatch list preserves full registered tools" passed`
- log: `✔ Test "Omega Core App Store dispatch denies Pro gateway tool calls" passed`
- log: `✔ Test "Omega Core App Store dispatch still allows Core-safe tool calls" passed`
- log: `✔ Test run with 22 tests in 1 suite passed`
- log: `✔ Test run with 7 tests in 1 suite passed`
- note: focused verification logs `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-green-r2-20260502.log` and `/tmp/epistemos-omega-dispatch-core-execution-gate-pr1-tool-surface-green-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **` after both runs, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `ToolSchemaGrammarTests`
- test: `ToolSurfacePolicyTests`

## command-center-tool-surface-policy-pr1

- grep: `toolSurfaceDistribution`
- grep: `isBuiltInAgentContextProviderVisible`
- grep: `coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools`
- grep: `coreAppStoreManualExternalMentionDoesNotResolve`
- forbidden staged grep: `MCPBridge|dispatch\\(|URLSession|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy|CloudLLMClient|CloudProviderAuthService|LLMService|TriageService|agent_core|graph-engine` in `Epistemos/State/AgentCommandCenterState.swift` and `EpistemosTests/AgentCommandCenterStateTests.swift`
- staged guard: `git diff --cached --name-only -- Epistemos/Omega Epistemos/Engine Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/State/AgentCommandCenterState.swift` and the Round 42 hunks in `EpistemosTests/AgentCommandCenterStateTests.swift` are allowed app/test files for this slice.
- log: `✔ Test coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools() passed`
- log: `✔ Test coreAppStoreManualExternalMentionDoesNotResolve() passed`
- log: `✔ Test run with 42 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-command-center-tool-surface-pr1-green-r3-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `AgentCommandCenterStateTests`

## r15-true-rust-callback-loop-pr10

- grep: `run_r15_true_rust_callback_loop_benchmark`
- grep: `R15TrueRustCallbackLoopBenchmarkFFI`
- grep: `runR15TrueRustCallbackLoopBenchmark`
- grep: `true_rust_to_swift_loop`
- grep: `not_true_rust_to_swift_loop` must remain for the PR5 generated-handle baseline.
- forbidden staged grep: `graph-engine/src/renderer.rs|MetalGraphView.swift|MLXInferenceService.swift|LocalMLXClient|GraphEngine\\(|render_frame_rate|mlx_live_token_throughput` in the staged diff, except pre-existing unchanged docs/test references.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine Epistemos/Engine Epistemos/Omega Epistemos.xcodeproj`
- staged allow: only the PR10 hunk in `agent_core/src/bridge.rs`, benchmark tests/ledger/source guard, the new true-Rust JSON artifact, and Round 43 docs are allowed.
- log: `✔ Test "true Rust callback loop runner writes finite decodable report" passed`
- log: `✔ Test "R15 PR10 true Rust callback loop baseline uses the Rust export honestly" passed`
- log: `✔ Test "committed R15 benchmark ledger names only closed evidence" passed`
- log: `✔ Test "open R15 live baseline claims remain explicitly open" passed`
- log: `test result: ok. 34 passed; 0 failed; 0 ignored; 0 measured; 769 filtered out`
- note: focused verification logs `/tmp/epistemos-r15-true-rust-callback-pr10-green-final-20260502.log` and `/tmp/epistemos-r15-true-rust-callback-pr10-cargo-bridge-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `UniFFICallbackThroughputTests`
- test: `BenchmarkHarnessSourceGuardTests`
- test: `R15BenchmarkEvidenceLedgerTests`
- test: `cargo test --manifest-path agent_core/Cargo.toml --lib bridge::tests`

## r15-renderer-fps-baseline-pr11

- grep: `GraphRendererFPSBaselineRunner`
- grep: `renderer_fps_thermal_soak`
- grep: `live_graph_renderer_frame_rate_fixture`
- grep: `GraphEngine.render(width:height:)`
- grep: `not_five_min_thermal_soak`
- forbidden staged grep: `graph-engine/src/renderer.rs|MetalGraphView.swift|HologramController.swift|Epistemos/Graph/GraphEngine.swift|mlx_live_token_throughput|MLXInferenceService|LocalMLXClient` in the staged diff, except pre-existing unchanged docs/test references.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine Epistemos/Engine Epistemos/Omega Epistemos.xcodeproj build-rust`
- staged allow: only benchmark tests/source guard/evidence ledger, the new renderer FPS JSON artifact, and Round 44 docs are allowed.
- log: `✔ Test "renderer FPS baseline writes finite decodable report when explicitly enabled" passed`
- log: `✔ Test "renderer FPS baseline rejects invalid counts" passed`
- log: `✔ Test "R15 PR11 renderer FPS baseline uses live GraphEngine render path honestly" passed`
- log: `✔ Test "committed R15 benchmark ledger names only closed evidence" passed`
- log: `✔ Test "open R15 live baseline claims remain explicitly open" passed`
- log: `✔ Test run with 5 tests in 1 suite passed`
- note: focused verification logs `/tmp/epistemos-r15-renderer-fps-pr11-green-20260502.log` and `/tmp/epistemos-r15-renderer-fps-pr11-artifact-suite-20260502.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`, followed by known CodeEdit SwiftLint package-plugin footer noise. The committed artifact records p50 `119.65399546442954` fps, p95 `119.8709496648827` fps, and `thermal_soak_status=not_five_min_thermal_soak`.
- test: `GraphFFIBenchmarkTests`
- test: `BenchmarkHarnessSourceGuardTests`
- test: `R15BenchmarkEvidenceLedgerTests`

## graph-event-query-projection-pr10

- grep: `GraphEventProjectionHint`
- grep: `graphEventProjectionSnapshotProvider`
- grep: `EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1`
- forbidden grep: `saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Timer|DispatchSourceTimer|repeatForever` in `Epistemos/Engine/QueryRuntime.swift` returns no matches.
- staged guard: `git diff --cached --name-only -- Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core epistemos-core Epistemos/Views/Notes/ProseEditor*.swift Epistemos.xcodeproj`
- staged allow: only the PR10 hunks in `Epistemos/Engine/QueryRuntime.swift`, `EpistemosTests/QueryRuntimeTests.swift`, and Round 47 docs are allowed.
- log: `✔ Test "GraphEvent projection hint only reorders existing equal-score candidates" passed`
- log: `✔ Test "retrieval runtime applies GraphEvent projection hint only to existing full-text candidates" passed`
- log: `✔ Test "GraphEvent projection hint stays out of indexes and renderer" passed`
- log: `✔ Test run with 32 tests in 2 suites passed`
- note: focused verification log `/tmp/epistemos-graph-event-query-projection-pr10-green-20260502-r2.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `QueryRuntimeTests`
- test: `GraphEventAuditProjectionTests`

## core-mas-tooltier-execution-symbol-gate-pr2

- grep: `distribution: ToolSurfacePolicy.Distribution`
- grep: `executionPolicyDenial`
- grep: `toolExecutorDeniesCoreAppStoreHiddenToolsBeforeBindings`
- grep: `Tool not found:`
- forbidden staged grep: `git diff --cached --name-only | rg '^(Epistemos/Omega/|Epistemos/App/ChatCoordinator.swift|Epistemos/Engine/PipelineService.swift|agent_core/|graph-engine/|Epistemos.xcodeproj|.*entitlements|Epistemos/Views/Notes/ProseEditor|Epistemos/Views/Graph/)'` returns no matches.
- staged allow: only `Epistemos/Bridge/ToolTierBridge.swift`, `EpistemosTests/ToolSurfacePolicyTests.swift`, Round 49 blocked R15 evidence docs, Round 50 fleet/deliberation/preflight docs, this guard file, current-state docs, and workcard docs are allowed for this commit.
- log: `✔ Test toolExecutorDeniesCoreAppStoreHiddenToolsBeforeBindings() passed`
- log: `✔ Test toolExecutionPolicyPreservesAllowedAndProResearchPaths() passed`
- log: `✔ Test run with 9 tests in 1 suite passed`
- log: `✔ Test run with 62 tests in 2 suites passed`
- log: `✔ Test run with 22 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-core-mas-tooltier-execution-pr2-green-20260503.log`; guard log `/tmp/epistemos-core-mas-tooltier-execution-pr2-guard-green-20260503.log`; schema log `/tmp/epistemos-core-mas-tooltier-execution-pr2-schema-green-20260503.log`. Xcode exited `0` and printed `** TEST SUCCEEDED **` for all three, followed by known CodeEdit SwiftLint package-plugin footer noise.
- test: `ToolSurfacePolicyTests`
- test: `AgentCommandCenterStateTests`
- test: `AppStoreHardeningTests`
- test: `ToolSchemaGrammarTests`

## agent-event-search-index-direct-page-pr21

- grep: `toolName: "search_index.search"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `toolName: "search_index.search_async"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `surface: "search"` in the direct page `limitedSearchMetadata` call in `Epistemos/Sync/SearchIndexService.swift`
- grep: `surface: "search_async"` in the direct page `limitedSearchMetadata` call in `Epistemos/Sync/SearchIndexService.swift`
- grep: `nonisolated private let directPageSyncSearchToolSequence = Mutex<UInt64>(0)`
- grep: `private var directPageAsyncSearchToolSequence: UInt64 = 0`
- forbidden grep: `search_index.search_blocks|search_index.search_blocks_async` in `Epistemos/Sync/SearchIndexService.swift`
- forbidden direct-sync grep: `AgentToolProvenanceRecorder|Task \\{|Task\\.detached|DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated|search_index\\.search_async` inside the `search(query:limit:)` body.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Sync/SearchIndexService.swift`, `EpistemosTests/SearchIndexServiceFusionTests.swift`, Round 52 fleet/deliberation/preflight docs, this guard file, current-state docs, and workcard docs are allowed for this commit.
- log: `✔ Test "fusedSearch provenance surfaces stay bounded" passed`
- log: `✔ Suite "SearchIndexService AgentEvent source guards" passed`
- log: `✔ Test run with 24 tests in 2 suites passed`
- note: focused verification log `/tmp/epistemos-agent-event-search-index-page-pr21-green-pipefail-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The runtime RRF Fusion suite still compiles but remains skipped by the pre-existing FTS5 availability gate on this host.
- test: `SearchIndexServiceAgentEventSourceGuardTests`

## agent-event-search-index-block-search-pr22

- grep: `toolName: "search_index.search_blocks"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `toolName: "search_index.search_blocks_async"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `surface: "search_blocks"` in the block `limitedSearchMetadata` call in `Epistemos/Sync/SearchIndexService.swift`
- grep: `surface: "search_blocks_async"` in the block `limitedSearchMetadata` call in `Epistemos/Sync/SearchIndexService.swift`
- grep: `nonisolated private let blockSyncSearchToolSequence = Mutex<UInt64>(0)`
- grep: `private var blockAsyncSearchToolSequence: UInt64 = 0`
- forbidden block-sync grep: `AgentToolProvenanceRecorder|Task \\{|Task\\.detached|DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated|search_index\\.search_blocks_async` inside the `searchBlocks(query:limit:)` body.
- forbidden block metadata grep: query text, sanitized FTS query, block ids, page ids, titles, snippets, ranks, document bodies, vault paths, SQL, GRDB error strings, localized descriptions, arbitrary error text, direct-page tool names, and fused-search tool names are not persisted in block-search AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Sync/SearchIndexService.swift`, `EpistemosTests/SearchIndexServiceFusionTests.swift`, Round 53 fleet/deliberation/preflight docs, this guard file, current-state docs, and workcard docs are allowed for this commit.
- log: `✔ Test "block search async records sanitized AgentEvents" passed` when the host FTS5 gate is available; on this host the runtime RRF Fusion suite compiled but was skipped behind the pre-existing FTS5 availability probe.
- log: `✔ Suite "SearchIndexService AgentEvent source guards" passed`
- log: `✔ Test run with 29 tests in 2 suites passed`
- note: focused verification log `/tmp/epistemos-agent-event-search-index-block-pr22-green-pipefail-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The runtime RRF Fusion suite still compiles but remains skipped by the pre-existing FTS5 availability gate on this host.
- test: `SearchIndexServiceAgentEventSourceGuardTests`

## agent-event-mlx-image-generation-pr23

- grep: `toolName: "image_generate.mlx"` in `Epistemos/Engine/MLXImageGenerationService.swift`
- grep: `runID = "mlx-image-generation-` in `Epistemos/Engine/MLXImageGenerationService.swift`
- grep: `AgentProvenanceActor.agent(id: "mlx-image-generation-service", modelID: nil)` in `Epistemos/Engine/MLXImageGenerationService.swift`
- grep: `source": "mlx_image_generation_service"` in `Epistemos/Engine/MLXImageGenerationService.swift`
- grep: `prompt_char_count` in `Epistemos/Engine/MLXImageGenerationService.swift`
- forbidden source grep: `Hermes|MCP|stdio_subprocess|docker|cli_passthrough|computer_use|_ANEClient|MTLBuffer.*contents|disable-library-validation|LAContext|LocalAuthentication|URLSession|Process\.` in `Epistemos/Engine/MLXImageGenerationService.swift` and `EpistemosTests/MLXImageGenerationServiceTests.swift` returns no matches.
- forbidden metadata grep: prompt text, generated image path, model id, FAL hints, localized descriptions, arbitrary error text, cloud routing, filesystem paths, Hermes, MCP, subprocesses, ANE/private API, and real Flux wiring are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/MLXImageGenerationService.swift`, `EpistemosTests/MLXImageGenerationServiceTests.swift`, Round 54 fleet/deliberation/preflight docs, this guard file, current-state docs, and workcard docs are allowed for this commit.
- log: `✔ Test "successful MLX image generation records sanitized AgentEvents" passed`
- log: `✔ Test "unavailable MLX pipeline records terminal failed AgentEvent" passed`
- log: `✔ Test run with 2 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-mlx-image-generation-pr23-green2-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`.
- test: `MLXImageGenerationServiceTests`

## agent-event-local-gguf-generate-pr24

- grep: `toolName: "local_generate.gguf"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `runID: "local-gguf-generate-` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `AgentProvenanceActor.agent(id: "local-gguf-client", modelID: nil)` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"source": "local_gguf_client"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"provider": "local_gguf"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"prompt_char_count"` and `"system_prompt_char_count"` in `Epistemos/Engine/LocalGGUFClient.swift`
- forbidden source grep: `Hermes|MCP|stdio_subprocess|docker|cli_passthrough|computer_use|_ANEClient|MTLBuffer.*contents|disable-library-validation|LAContext|LocalAuthentication|URLSession|Process\.` in `Epistemos/Engine/LocalGGUFClient.swift` and `EpistemosTests/LocalGGUFClientTests.swift` returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in `Epistemos/Engine/LocalGGUFClient.swift` and `EpistemosTests/LocalGGUFClientTests.swift` returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, generated output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/LocalGGUFClient.swift`, `EpistemosTests/LocalGGUFClientTests.swift`, Round 55 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "gguf client generate records sanitized AgentEvents" passed`
- log: `✔ Test "gguf client generate records sanitized failed AgentEvent" passed`
- log: `✔ Test run with 7 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-gguf-generate-pr24-green-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`.
- test: `LocalGGUFClientTests`

## overseer-core-mas-tool-permission-fallback-pr1

- grep: `nonisolated static func fallbackToolPermissions(` in `Epistemos/Engine/OverseerProtocol.swift`
- grep: `ToolSurfacePolicy.isSurfacedToolName($0.toolName, distribution: distribution)` in `Epistemos/Engine/OverseerProtocol.swift`
- grep: `return Self.fallbackToolPermissions(distribution: .currentBuild)` in the private `toolPermissions(for:)` fallback body.
- forbidden route-body grep: `OverseerToolPermission(toolName: "run_command"` between `private func toolPermissions(for route:` and `private func permissionMode(for tool:` returns no matches; `run_command` is allowed only in the shared Pro/Research-preserving helper and negative/Core tests.
- forbidden source grep: provider, MCP, Omega, Rust, generated transport, entitlement, project, graph, view, and execution bridge paths are not staged for this slice.
- staged allow: only `Epistemos/Engine/OverseerProtocol.swift`, `EpistemosTests/OverseerProtocolTests.swift`, Round 56 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "Core App Store fallback permissions hide Pro gateway tools" passed`
- log: `✔ Test "Pro Research fallback permissions preserve explicit ask tools" passed`
- log: `✔ Test run with 7 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-overseer-core-mas-tool-permission-fallback-pr1-green2-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The first green attempt log `/tmp/epistemos-overseer-core-mas-tool-permission-fallback-pr1-green-20260503.log` failed because the source-shape Swift test hung the hosted app process after real permission assertions passed; that source-shape proof moved to the shell guard above.
- test: `OverseerProtocolTests`

## agent-event-local-backend-stream-pr25

- grep: `toolName: "local_backend.stream"` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `runID: "local-backend-stream-` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `AgentProvenanceActor.agent(id: "local-backend-llm-client", modelID: nil)` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `"source": "local_backend_llm_client"` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `"provider": "local_backend"` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `"prompt_char_count"` and `"system_prompt_char_count"` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in `Epistemos/Engine/LocalBackendLLMClient.swift` and `EpistemosTests/LocalBackendLLMClientTests.swift` returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in `Epistemos/Engine/LocalBackendLLMClient.swift` and `EpistemosTests/LocalBackendLLMClientTests.swift` returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, streamed output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/LocalBackendLLMClient.swift`, `EpistemosTests/LocalBackendLLMClientTests.swift`, Round 57 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "backend stream records sanitized AgentEvents" passed`
- log: `✔ Test "backend stream records sanitized failed AgentEvent" passed`
- log: `✔ Test run with 7 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-backend-stream-pr25-green-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The red log `/tmp/epistemos-agent-event-local-backend-stream-pr25-red-20260503.log` failed before implementation because `agentProvenanceRecorder` and `.fast` contextual typing were not yet present at the test callsite.
- test: `LocalBackendLLMClientTests`

## agent-event-local-runtime-recorder-mount-pr26

- grep: `let localRuntimeAgentProvenanceRecorder = AgentToolProvenanceRecorder()` in `Epistemos/App/AppBootstrap.swift`
- grep: `agentProvenanceRecorder: localRuntimeAgentProvenanceRecorder` appears in both `LocalGGUFClient` and `LocalBackendLLMClient` constructor argument blocks in `Epistemos/App/AppBootstrap.swift`
- forbidden staged-diff grep: no new EventStore schema, graph, Rust, Hermes/MCP, LocalAuthentication, ANE/private API, subprocess, or Xcode project edits.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/App/AppBootstrap.swift`, `EpistemosTests/LocalBackendLLMClientTests.swift`, Round 58 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "bootstrap mounts local runtime AgentEvent recorder" passed`
- log: `✔ Test run with 8 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-runtime-recorder-mount-pr26-green-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The red log `/tmp/epistemos-agent-event-local-runtime-recorder-mount-pr26-red-20260503.log` failed before implementation with the expected missing mount assertions.
- test: `LocalBackendLLMClientTests`

## agent-event-local-mlx-generate-pr27

- grep: `toolName: "local_generate.mlx"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `runID: "local-mlx-generate-` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `AgentProvenanceActor.agent(id: "local-mlx-client", modelID: nil)` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"source": "local_mlx_client"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"provider": "local_mlx"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"prompt_char_count"` and `"system_prompt_char_count"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `agentProvenanceRecorder: localRuntimeAgentProvenanceRecorder` appears in the `LocalMLXClient` constructor argument block in `Epistemos/App/AppBootstrap.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in PR27 staged source/test hunks returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in PR27 staged source/test hunks returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, generated output, model id, artifact id, image URLs, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/MLXInferenceService.swift`, `Epistemos/App/AppBootstrap.swift`, `EpistemosTests/LocalBackendLLMClientTests.swift`, Round 59 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "local mlx generate records sanitized AgentEvents" passed`
- log: `✔ Test "local mlx generate records sanitized failed AgentEvent" passed`
- log: `✔ Test run with 10 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-mlx-generate-pr27-green-20260503.log`; Xcode exited `0` under `pipefail`, printed `** TEST SUCCEEDED **`, and contained no `panicked` or `Can't lift flat errors` text. The red log `/tmp/epistemos-agent-event-local-mlx-generate-pr27-red-20260503.log` failed before implementation because `LocalMLXClient` did not yet accept the provenance recorder.
- test: `LocalBackendLLMClientTests`

## agent-event-local-mlx-stream-pr28

- grep: `toolName: "local_stream.mlx"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `runID: "local-mlx-stream-` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `AgentProvenanceActor.agent(id: "local-mlx-client", modelID: nil)` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"source": "local_mlx_client"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"surface": "stream"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"provider": "local_mlx"` in `Epistemos/Engine/MLXInferenceService.swift`
- grep: `"chunk_count"` in `Epistemos/Engine/MLXInferenceService.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in PR28 staged source/test hunks returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in PR28 staged source/test hunks returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, streamed output, model id, artifact id, image URLs, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/MLXInferenceService.swift`, `EpistemosTests/LocalBackendLLMClientTests.swift`, Round 60 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "local mlx stream records sanitized AgentEvents" passed`
- log: `✔ Test "local mlx stream records sanitized failed AgentEvent" passed`
- log: `✔ Test "local mlx stream records sanitized cancelled AgentEvent" passed`
- log: `✔ Test run with 13 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-mlx-stream-pr28-green2-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The same log still contains the existing runtime-control-plane UniFFI cancellation cleanup message `Can't lift flat errors` after AgentEvent cancellation is recorded; that runtime-contract issue is outside PR28 and should be handled as a separate slice.
- test: `LocalBackendLLMClientTests`

## agent-event-local-backend-generate-pr29

- grep: `local_backend.generate` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `local-backend-generate` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `"surface": surface.metadataValue` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `"output_char_count"` in `Epistemos/Engine/LocalBackendLLMClient.swift`
- grep: `backendGenerateRecordsSanitizedAgentEvents` in `EpistemosTests/LocalBackendLLMClientTests.swift`
- grep: `backendGenerateRecordsSanitizedRoutingFailureAgentEvent` in `EpistemosTests/LocalBackendLLMClientTests.swift`
- grep: `backendGenerateRecordsSanitizedBackendFailureAgentEvent` in `EpistemosTests/LocalBackendLLMClientTests.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in PR29 staged source/test hunks returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in PR29 staged source/test hunks returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, generated output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in router-level AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/LocalBackendLLMClient.swift`, `EpistemosTests/LocalBackendLLMClientTests.swift`, Round 61 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "backend generate records sanitized AgentEvents" passed`
- log: `✔ Test "backend generate records sanitized routing failure AgentEvent" passed`
- log: `✔ Test "backend generate records sanitized backend failure AgentEvent" passed`
- log: `✔ Test run with 16 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-agent-event-local-backend-generate-pr29-green2-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. The same log still contains the existing runtime-control-plane UniFFI cancellation cleanup message `Can't lift flat errors` from the older MLX stream cancellation test; that runtime-contract issue is outside PR29 and should be handled as a separate slice.
- test: `LocalBackendLLMClientTests`

## runtime-contract-error-class-bridge-pr30

- grep: `string? error_class` appears for both `RuntimeGenerationSummary` and `RuntimeGenerationEvent` in `epistemos-core/uniffi/epistemos_core.udl`
- grep: `string error_class` appears for `finish_failed` in `epistemos-core/uniffi/epistemos_core.udl`
- grep: `pub error_class: Option<String>` appears for runtime generation summary/event payloads in `epistemos-core/src/runtime_contract.rs`
- grep: `error_class: Some(error_class)` appears in `RuntimeControlPlane.finish_failed`
- grep: `errorClass: errorClass.rawValue` appears in `Epistemos/Engine/BackendRuntimeContract.swift`
- grep: `BackendRuntimeContractError.init(rawValue:)` appears for generated event/summary lifting in `Epistemos/Engine/BackendRuntimeContract.swift`
- forbidden FFI payload grep: `RuntimeContractError? error_class` and `RuntimeContractError error_class` return no matches in `epistemos-core/uniffi/epistemos_core.udl`
- log: `✔ Test "failed and cancelled runtime events carry error classes across FFI" passed`
- log: `✔ Test run with 16 tests in 1 suite passed`
- log: `test result: ok. 378 passed; 0 failed` in `/tmp/epistemos-runtime-contract-error-class-bridge-pr30-cargo-20260503.log`
- log: no `Can't lift flat errors` in `/tmp/epistemos-runtime-contract-error-class-bridge-pr30-green3-20260503.log`
- note: focused verification log `/tmp/epistemos-runtime-contract-error-class-bridge-pr30-green3-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. Rust verification log `/tmp/epistemos-runtime-contract-error-class-bridge-pr30-cargo-20260503.log` passed `cargo test` for `epistemos-core`. The red log `/tmp/epistemos-runtime-contract-error-class-bridge-pr30-red-20260503.log` failed before implementation with the expected `.rustPanic("Can't lift flat errors")`.
- test: `BackendRuntimeContractTests`

## local-agent-reflex-detector-eof-flush-completion-pr31

- grep: `flushOnStreamEnd` in `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`
- grep: `Flushes trailing tag-prefix plaintext at stream end` in `EpistemosTests/IncrementalToolCallDetectorTests.swift`
- grep: `Drops unterminated hidden and tool buffers at stream end` in `EpistemosTests/IncrementalToolCallDetectorTests.swift`
- grep: `reflex mode flushes trailing tag-prefix plaintext once at stream end` in `EpistemosTests/LocalAgentLoopTests.swift`
- forbidden staged-path guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`, `EpistemosTests/IncrementalToolCallDetectorTests.swift`, Round 63 fleet/deliberation/preflight docs, this guard file, current-state docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "Flushes trailing tag-prefix plaintext at stream end" passed`
- log: `✔ Test "Drops unterminated hidden and tool buffers at stream end" passed`
- log: `✔ Test "reflex mode flushes trailing tag-prefix plaintext once at stream end" passed`
- log: `✔ Test run with 55 tests in 2 suites passed`
- note: focused verification log `/tmp/epistemos-local-agent-reflex-detector-eof-flush-pr31-green-20260503.log`; Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`. Claude red-team timed out with no usable output and was marked failed; Codex red-team approved the brief with no P0/P1 attacks.
- test: `IncrementalToolCallDetectorTests`
- test: `LocalAgentLoopTests`

## agent-event-local-gguf-stream-pr32

- grep: `toolName: "local_stream.gguf"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `runID: "local-gguf-stream-` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `toolCallID: nextToolCallID(for: .stream)` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `AgentProvenanceActor.agent(id: "local-gguf-client", modelID: nil)` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"source": "local_gguf_client"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"surface": surface.metadataValue` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"provider": "local_gguf"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `"chunk_count"` in `Epistemos/Engine/LocalGGUFClient.swift`
- grep: `ggufClientStreamRecordsSanitizedAgentEvents` in `EpistemosTests/LocalGGUFClientTests.swift`
- grep: `ggufClientStreamRecordsSanitizedFailedAgentEvent` in `EpistemosTests/LocalGGUFClientTests.swift`
- grep: `ggufClientStreamRecordsSanitizedCancelledAgentEvent` in `EpistemosTests/LocalGGUFClientTests.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in PR32 staged source/test hunks returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in PR32 staged source/test hunks returns no matches.
- forbidden metadata grep: prompt text, system prompt text, steering hint JSON, streamed output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in direct GGUF stream AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/LocalGGUFClient.swift`, `EpistemosTests/LocalGGUFClientTests.swift`, Round 64 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✘ Test "gguf client stream records sanitized AgentEvents" failed` in `/tmp/epistemos-agent-event-local-gguf-stream-pr32-red2-20260503.log` before implementation because no direct stream AgentEvents were recorded.
- log: focused verification log `/tmp/epistemos-agent-event-local-gguf-stream-pr32-green4-20260503.log`; Xcode exited `0` under `pipefail` with isolated DerivedData at `/tmp/epistemos-dd-pr32`. The earlier rerun logs exposed stale Xcode build database contention, not a code failure, and stale build processes were cleaned up before the isolated pass.
- test: `LocalGGUFClientTests`

## agent-event-apple-intelligence-generate-pr33

- grep: `toolName: "apple_intelligence.generate"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `runID: "apple-intelligence-generate-` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `return "apple-intelligence-generate:\(generateToolSequence)"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `AgentProvenanceActor.agent(id: "apple-intelligence-service", modelID: nil)` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `"source": "apple_intelligence_service"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `"surface": "generate"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `"provider": "apple_intelligence"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `"augmented_system_prompt_present"` in `Epistemos/Engine/AppleIntelligenceService.swift`
- grep: `generateRecordsSanitizedAgentEvents` in `EpistemosTests/AppleIntelligenceServiceAgentEventTests.swift`
- grep: `generateRecordsSanitizedFailedAgentEvent` in `EpistemosTests/AppleIntelligenceServiceAgentEventTests.swift`
- forbidden source grep: `Hermes|MCP|browser|computer|LAContext|LocalAuthentication|_ANEClient|EventStore|GraphEvent|OpLog|subprocess|Process\(` in PR33 staged source/test hunks returns no matches.
- forbidden zero-copy/single-binary grep: `memcpy|memmove|\.copyMemory|Data\(bytes:|\.withUnsafeBytes.*copy|storageModeManaged|storageModePrivate|Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command` in PR33 staged source/test hunks returns no matches.
- forbidden metadata grep: prompt text, system prompt text, augmented vault context, generated output, localized descriptions, arbitrary backend error text, Hermes, MCP, subprocesses, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details are not persisted in AgentEvent JSON.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/AppleIntelligenceService.swift`, `EpistemosTests/AppleIntelligenceServiceAgentEventTests.swift`, Round 65 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✘ Test "Apple Intelligence generate records sanitized AgentEvents" failed` in `/tmp/epistemos-agent-event-apple-intelligence-generate-pr33-red-20260503.log` before implementation because `AppleIntelligenceService` still exposed only its private no-argument initializer.
- log: focused verification log `/tmp/epistemos-agent-event-apple-intelligence-generate-pr33-green-r3-20260503.log`; Xcode exited `0` under `pipefail` with isolated DerivedData at `/tmp/epistemos-dd-pr33`.
- test: `AppleIntelligenceServiceAgentEventTests`

## query-runtime-rrf-fused-fulltext-pr34

- grep: `RRFFusionFlags.isEnabled && scope == .all` in `Epistemos/Engine/QueryRuntime.swift`
- grep: `searchIndex.fusedSearch(` in `Epistemos/Engine/QueryRuntime.swift`
- grep: `FusionWeights(maxResults: limit)` in `Epistemos/Engine/QueryRuntime.swift`
- grep: `Falling back to legacy per-index dispatch` in `Epistemos/Engine/QueryRuntime.swift`
- grep: `case searchReadable` in `Epistemos/Models/QueryTypes.swift`
- grep: `.searchReadable` in `Epistemos/Models/QueryTypes.swift`, `Epistemos/Sync/ReadableBlocksIndex.swift`, and `EpistemosTests/QueryRuntimeTests.swift`
- forbidden implementation grep: `fusedSearchAsync\(|saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Process\(|DispatchSourceTimer|repeatForever|Epistemos/Views/Graph` returns no matches in `Epistemos/Engine/QueryRuntime.swift`, `Epistemos/Models/QueryTypes.swift`, and `Epistemos/Sync/ReadableBlocksIndex.swift`
- forbidden zero-copy/single-binary grep: `LAContext|LocalAuthentication|_ANEClient|storageModeManaged|storageModePrivate|memcpy|memmove|copyMemory|Data\(bytes:|Foundation\.Process|std::process::Command|swift-subprocess` returns no matches in implementation files
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Engine/QueryRuntime.swift`, `Epistemos/Models/QueryTypes.swift`, `Epistemos/Sync/ReadableBlocksIndex.swift`, `EpistemosTests/QueryRuntimeTests.swift`, Round 66 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "reactive query scopes search invalidation by index domain" passed`
- log: `✔ Test "retrieval runtime preserves legacy full-text results when RRF fused path falls back" passed`
- log: `✔ Test "retrieval runtime keeps page and block scopes on legacy search when RRF flag is enabled" passed`
- log: `✔ Test "QueryRuntime RRF fused path stays flag-gated and falls back" passed`
- log: `✔ Test run with 32 tests in 1 suite passed`
- log: `✔ Test run with 16 tests in 1 suite passed`
- note: QueryRuntime focused verification log `/tmp/epistemos-query-runtime-rrf-fused-fulltext-pr34-green-r3-20260503.log`; ReadableBlocksIndex focused verification log `/tmp/epistemos-query-runtime-rrf-fused-fulltext-pr34-readable-green-20260503.log`. Both Xcode runs exited `0` and printed `** TEST SUCCEEDED **`; the known SwiftLint package-plugin lines appear after success.
- test: `QueryRuntimeTests`
- test: `ReadableBlocksIndexTests`

## rrf-search-fusion-health-row-pr35

- grep: `SearchFusionHealthRow()` in `Epistemos/Views/Settings/SettingsView.swift`
- grep: `SearchFusionMetrics.didChangeNotification` in `Epistemos/Views/Settings/SearchFusionHealthRow.swift`
- grep: `NotificationCenter.default.post(` in `Epistemos/Sync/RRFFusionQuery.swift`
- grep: `Search Fusion shows live latency + per-source hit distribution` in `Epistemos/Views/Settings/SettingsView.swift`
- forbidden polling grep: `while !Task\.isCancelled|Timer|DispatchSourceTimer|repeatForever` returns no matches in `Epistemos/Views/Settings/SearchFusionHealthRow.swift`
- forbidden default-flag grep: `setenv\("EPISTEMOS_RRF_FUSION_V1"` returns no matches in `Epistemos/Views/Settings/SearchFusionHealthRow.swift`, `Epistemos/Views/Settings/SettingsView.swift`, and `Epistemos/Sync/RRFFusionQuery.swift`
- forbidden implementation grep: `saveGraphEvent|saveMutationEnvelope|GraphEventAuditProjectionService|InstantRecallService|MeaningAnchorService|Process\(|DispatchSourceTimer|repeatForever|Epistemos/Views/Graph` returns no matches in PR35 implementation files.
- staged guard: `git diff --cached --name-only -- Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Sync/RRFFusionQuery.swift`, `Epistemos/Views/Settings/SearchFusionHealthRow.swift`, the Search Fusion mount hunk in `Epistemos/Views/Settings/SettingsView.swift`, `EpistemosTests/SearchFusionHealthRowTests.swift`, `docs/RRF_FUSION_DESIGN.md`, Round 68 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "Search Fusion Health row is mounted in Settings diagnostics" passed`
- log: `✔ Test "Search Fusion Health row is read-only and event-driven" passed`
- log: `✔ Test "Search Fusion metrics summarize latency, hits, and errors" passed`
- log: `✔ Test "Search Fusion metrics publish change notifications" passed`
- log: `✔ Test run with 4 tests in 1 suite passed`
- note: focused verification log `/tmp/epistemos-rrf-search-fusion-health-row-pr35-green-r2-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`. The known SwiftLint package-plugin lines appear after success.
- test: `SearchFusionHealthRowTests`

## agent-event-v16-forward-variants-pr34

- grep: `steerRequested|summaryStarted|summaryDelta|summaryCompleted|vaultCreated|vaultArchived` in `Epistemos/Models/AgentProvenanceEvent.swift`
- grep: `forward_variant_only` in `EpistemosTests/AgentEventV16ForwardVariantTests.swift`
- forbidden staged-path guard: `git diff --cached --name-only -- Epistemos/Bridge agent_core epistemos-core graph-engine Epistemos/Views Epistemos.xcodeproj`
- staged allow: only `Epistemos/Models/AgentProvenanceEvent.swift`, `EpistemosTests/AgentEventV16ForwardVariantTests.swift`, Round 70 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `✔ Test "AgentEvent kind vocabulary includes simulation v1.6 forward variants" passed`
- log: `✔ Test "simulation v1.6 forward variants round-trip through Codable" passed`
- log: `✔ Test "EventStore persists simulation v1.6 forward variant events" passed`
- note: focused verification log `/tmp/epistemos-agent-event-v16-forward-variants-pr34-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`. This slice is forward vocabulary only, not live dispatch-panel steering, helper summarizer, or multi-vault runtime.
- test: `AgentEventV16ForwardVariantTests`

## mcpbridge-tools-call-denial-provenance-pr35

- grep: `recordToolCallPolicyDenial|mcp_bridge_policy_gate|policy_gate` in `Epistemos/Omega/MCPBridge.swift` and `EpistemosTests/MCPBridgeAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: requestJson|resultJSON: gateResponse|params\["arguments"\]` returns no matches in `Epistemos/Omega/MCPBridge.swift`
- tier-leakage grep: `Hermes|MCP|stdio_subprocess|docker|cli_passthrough|computer_use|_ANEClient|MTLBuffer.*contents|disable-library-validation` returns expected MCPBridge filename/comment hits only; no new subprocess, provider, computer-use, ANE, or Metal buffer surfaces are introduced.
- Sovereign grep: `LAContext|canEvaluatePolicy|evaluatePolicy|deviceOwnerAuthentication|TouchID|biometric` returns no matches in touched source/test files.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Omega/MCPBridge.swift`, `EpistemosTests/MCPBridgeAgentEventTests.swift`, Round 72 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit.
- log: `Static member 'jsonRpcSuccess' cannot be used on instance of type 'MCPBridge'` in `/tmp/epistemos-mcpbridge-tools-call-denial-provenance-pr35-redgreen-20260503.log` before the compile fix.
- log: `✔ Test "Core policy denied tools call records sanitized requested and denied events" passed`
- log: `✔ Test "Core safe and Pro tool calls do not emit policy denial provenance" passed`
- log: `✔ Test "MCPBridge policy provenance source avoids raw JSON RPC payload persistence" passed`
- note: focused verification log `/tmp/epistemos-mcpbridge-tools-call-denial-provenance-pr35-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- note: compatibility verification log `/tmp/epistemos-mcpbridge-tools-call-denial-provenance-pr35-tool-schema-green-20260503.log`; existing `ToolSchemaGrammarTests` ran 22 tests, preserving Core/Pro catalog and dispatch behavior.
- test: `MCPBridgeAgentEventTests`
- test: `ToolSchemaGrammarTests`

## phase7-nightbrain-trigger-provenance-pr36

- grep: `recordNightBrainTriggerEvent|phase7-nightbrain-trigger|nightbrain_trigger|bootstrapProvider|requested_job_supported|failure_class|priority_class` in `Epistemos/Bridge/Phase7Bridge.swift` and `EpistemosTests/Phase7BridgeAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: jobType|argumentsJSON: priority|resultJSON: response|errorMessage: message|params\[|raw|localizedDescription` returns no unsafe persistence matches in `Epistemos/Bridge/Phase7Bridge.swift`; expected hits are the safe `job.rawValue` canonical enum value and test comments.
- tier-leakage grep: `Hermes|MCP|subprocess|browser|computer-use|LocalAuthentication|LAContext|AppleNeuralEngine|_ANEClient|storageModeManaged|storageModePrivate|memcpy|Z3|Kani|Lean|Kissat|cvc5` returns no matches in the touched source/test files.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Bridge/Phase7Bridge.swift`, `EpistemosTests/Phase7BridgeAgentEventTests.swift`, Round 73 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, parallel manifest, and the fleet registry are allowed for this commit.
- log: `✘ Test "Unsupported NightBrain jobs record sanitized requested and failed events before bootstrap lookup" failed` in `/tmp/epistemos-phase7-nightbrain-trigger-provenance-pr36-redgreen-20260503.log` before the test expectation was tightened to require unknown priority for injected priority text.
- log: `✔ Test "Unsupported NightBrain jobs record sanitized requested and failed events before bootstrap lookup" passed`
- log: `✔ Test "Supported NightBrain job without AppBootstrap records bounded bootstrap failure" passed`
- log: `✔ Test "Phase7Bridge provenance source does not persist raw NightBrain request strings" passed`
- log: `✔ Test "Existing Phase7 job aliases stay intact" passed`
- note: focused verification log `/tmp/epistemos-phase7-nightbrain-trigger-provenance-pr36-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `Phase7BridgeAgentEventTests`

## phase5-ssm-state-provenance-pr37

- grep: `recordSsmStateEvent|phase5-ssm-state|ssm_state_manage|action_class|model_scope|failure_class|live_cache_action_unavailable|boundedKeepCount` in `Epistemos/Bridge/Phase5Bridge.swift` and `EpistemosTests/Phase5BridgeAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: actionJson|resultJSON: response|resultJSON: jsonString\(\[|errorMessage: error|localizedDescription|params\[|state_path|url\.path|session_id` returns no unsafe AgentEvent persistence matches; expected hits are the test poison payload, the unchanged external `list` response fields, the pre-existing constrained-generation error path, and the bounded `errorMessage` recorder parameter.
- tier-leakage grep: `Hermes|MCP|subprocess|browser|computer-use|LocalAuthentication|LAContext|AppleNeuralEngine|_ANEClient|storageModeManaged|storageModePrivate|memcpy|Z3|Kani|Lean|Kissat|cvc5` returns no matches in the touched source/test files.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `Epistemos/Bridge/Phase5Bridge.swift`, `EpistemosTests/Phase5BridgeAgentEventTests.swift`, Round 74 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent test files such as `EpistemosTests/CoreMASBoundarySourceGuardTests.swift` are intentionally excluded.
- log: `Phase5Bridge' initializer is inaccessible due to 'private' protection level` in `/tmp/epistemos-phase5-ssm-state-provenance-pr37-red-20260503.log` before the injection seam was added.
- log: `✔ Test "Phase5 SSM total size records sanitized requested started and completed events" passed`
- log: `✔ Test "Phase5 SSM unsupported actions record sanitized failed events" passed`
- log: `✔ Test "Phase5 SSM service unavailable records bounded bootstrap failure" passed`
- log: `✔ Test "Phase5 SSM invalid JSON records bounded failed events" passed`
- note: focused verification log `/tmp/epistemos-phase5-ssm-state-provenance-pr37-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `Phase5BridgeAgentEventTests`

## graph-event-consumer-projection-guard-pr38

- grep: `graphEventProjectionSnapshot|GraphEventAuditProjectionService|Graph projection idle|EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1` in `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift`
- forbidden implementation grep: `saveGraphEvent|saveMutationEnvelope|GraphState|GraphStore|SearchIndexService|DispatchSourceTimer|repeatForever|graph-engine|OpLog` returns no matches in the guarded consumer contexts named by the test.
- staged guard: `git diff --cached --name-only -- Epistemos/Views Epistemos/Graph graph-engine agent_core omega-mcp epistemos-core Epistemos.xcodeproj`
- staged allow: only `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift`, Round 76 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files such as `EpistemosTests/GraphEventProjectionFixtureTests.swift` are intentionally excluded.
- log: first focused build reported `Call to main actor-isolated global function 'loadMirroredSourceTextFile' in a synchronous nonisolated context` before the source-guard suite dropped `nonisolated`.
- log: `✔ Test "EventStore projection consumer remains a bounded read-only fold" passed`
- log: `✔ Test "audit projection service stays read-only and UI-free" passed`
- log: `✔ Test "settings projection row stays appear-refresh only" passed`
- log: `✔ Test "Halo projection ribbon stays panel-open read-only" passed`
- log: `✔ Test "Trace Inspector and QueryRuntime projection consumers stay bounded and non-mutating" passed`
- note: focused verification log `/tmp/epistemos-graph-event-consumer-projection-guard-pr38-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- note: the focused verification also required a compile-order repair in the parallel-agent-created `EpistemosTests/GraphEventProjectionFixtureTests.swift`; that file remains outside this commit.
- test: `GraphEventConsumerProjectionGuardTests`

## computer-use-bridge-agent-event-pr39

- grep: `recordComputerActionEvent|computer\\.type|coordinate_bucket|text_length_bucket` in `Epistemos/Bridge/ComputerUseBridge.swift` and `EpistemosTests/ComputerUseBridgeAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: actionJSON|argumentsJSON: input|resultJSON: result,|errorMessage: errorResult|localizedDescription` returns no unsafe AgentEvent persistence matches in `Epistemos/Bridge/ComputerUseBridge.swift`; the expected `localizedDescription` hit remains in the unchanged external screenshot error response, not in AgentEvent JSON.
- tier-leakage grep: no new Core/MAS tool allowlist, MCP/Hermes routing, subprocess launcher, LocalAuthentication, ANE/private API, graph, or hot-path Metal buffer changes are introduced by the staged source/test files.
- staged allow: only `Epistemos/Bridge/ComputerUseBridge.swift`, `EpistemosTests/ComputerUseBridgeAgentEventTests.swift`, Round 77 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files such as `EpistemosTests/HermesGatewayEvidenceContractTests.swift` are intentionally excluded.
- log: `✘ Test "ComputerUseBridge provenance source never stores raw action payloads or raw results" failed` in `/tmp/epistemos-computer-use-bridge-agent-event-pr39-redgreen-20260503.log` before the source guard narrowed the unsafe raw-result pattern.
- log: `✔ Test "Trusted computer actions record sanitized requested started and completed events" passed`
- log: `✔ Test "Accessibility denial records sanitized requested and failed events before action execution" passed`
- log: `✔ Test "Invalid computer action JSON records bounded failed events" passed`
- log: `✔ Test "Unknown computer actions do not persist raw action names" passed`
- log: `✔ Test "ComputerUseBridge provenance source never stores raw action payloads or raw results" passed`
- note: focused verification log `/tmp/epistemos-computer-use-bridge-agent-event-pr39-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `ComputerUseBridgeAgentEventTests`

## phase4-perceive-agent-event-pr40

- grep: `recordPhase4PerceiveEvent|phase4\\.perceive|depth_class|app_scope|interactive_count|ocr_count` in `Epistemos/Bridge/Phase4Bridge.swift` and `EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: appName|argumentsJSON: depth|resultJSON: payload|errorMessage: errorJson|ax_tree_json` returns no unsafe AgentEvent persistence matches in the new recorder path; the expected `ax_tree_json` hits remain in the unchanged external perception response and source guard only.
- tier-leakage grep: no new Core/MAS tool allowlist, MCP/Hermes routing, subprocess launcher, LocalAuthentication, ANE/private API, graph, or hot-path Metal buffer changes are introduced by the staged source/test files.
- staged allow: only `Epistemos/Bridge/Phase4Bridge.swift`, `EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift`, Round 79 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `✔ Test "Phase4 perceive records sanitized requested started and completed events" passed`
- log: `✔ Test "Phase4 perceive unavailable records bounded failed events" passed`
- log: `✔ Test "Phase4 perceive source never stores AX tree OCR text app names or raw results" passed`
- note: focused verification log `/tmp/epistemos-phase4-perceive-agent-event-pr40-redgreen-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `Phase4BridgePerceiveAgentEventTests`

## phase4-interact-agent-event-pr41

- grep: `recordPhase4InteractEvent|phase4\\.interact|action_class|route_class|target_scope|value_length_bucket` in `Epistemos/Bridge/Phase4Bridge.swift` and `EpistemosTests/Phase4BridgeInteractAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: actionJson|argumentsJSON: payload|resultJSON: response|resultJSON: jsonString|errorMessage: errorJson|errorMessage: errorMessage as\\? String` returns no unsafe AgentEvent persistence matches in the new recorder path.
- tier-leakage grep: no new Core/MAS tool allowlist, MCP/Hermes routing, subprocess launcher, LocalAuthentication, ANE/private API, graph, or hot-path Metal buffer changes are introduced by the staged source/test files.
- staged allow: only `Epistemos/Bridge/Phase4Bridge.swift`, `EpistemosTests/Phase4BridgeInteractAgentEventTests.swift`, Round 80 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `✔ Test "Phase4 interact computer route records sanitized requested started and completed events" passed`
- log: `✔ Test "Phase4 interact AX press records sanitized completed events" passed`
- log: `✔ Test "Phase4 interact invalid and unsupported actions record bounded failed events" passed`
- log: `✔ Test "Phase4 interact source never stores raw action JSON target values or raw results" passed`
- note: focused verification log `/tmp/epistemos-phase4-interact-agent-event-pr41-redgreen-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `Phase4BridgeInteractAgentEventTests`

## phase4-screen-watch-agent-event-pr42

- grep: `recordPhase4ScreenWatchEvent|phase4\\.screen_watch|mode_class|timeout_bucket|poll_interval_bucket|target_scope` in `Epistemos/Bridge/Phase4Bridge.swift` and `EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: watchJson|argumentsJSON: payload|resultJSON: response|resultJSON: jsonString|errorMessage: errorJson|localizedDescription` returns no unsafe AgentEvent persistence matches in the new recorder path.
- tier-leakage grep: no new Core/MAS tool allowlist, MCP/Hermes routing, subprocess launcher, LocalAuthentication, ANE/private API, graph, or hot-path Metal buffer changes are introduced by the staged source/test files.
- staged allow: only `Epistemos/Bridge/Phase4Bridge.swift`, `EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift`, Round 81 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `✔ Test "Phase4 screen watch timeout records sanitized requested started and completed events" passed`
- log: `✔ Test "Phase4 screen watch file exists records target-scope without path" passed`
- log: `✔ Test "Phase4 screen watch invalid JSON records bounded failed event" passed`
- log: `✔ Test "Phase4 screen watch source never stores raw watch JSON paths" passed`
- note: focused verification log `/tmp/epistemos-phase4-screen-watch-agent-event-pr42-redgreen-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `Phase4BridgeScreenWatchAgentEventTests`

## clarify-prompt-bridge-agent-event-pr43

- grep: `recordClarifyPromptEvent|clarify\\.ask|input_mode|question_scope|response_length_bucket|choice_count_bucket` in `Epistemos/Bridge/ClarifyPromptBridge.swift` and `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift`
- forbidden raw-payload grep: `argumentsJSON: questionJson|argumentsJSON: parsed\\.question|resultJSON: response|resultJSON: answer\\.response|errorMessage: error` returns no unsafe AgentEvent persistence matches in the new recorder path.
- tier-leakage grep: no new Core/MAS tool allowlist, MCP/Hermes routing, subprocess launcher, LocalAuthentication, ANE/private API, graph, or hot-path Metal buffer changes are introduced by the staged source/test files.
- staged allow: only `Epistemos/Bridge/ClarifyPromptBridge.swift`, `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift`, Round 83 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `ClarifyPromptAnswer` missing and `ClarifyPromptBridge` initializer private in `/tmp/epistemos-clarify-prompt-bridge-agent-event-pr43-red-20260503.log` before the presenter seam was added.
- log: `✔ Test "Clarify free-form answer records sanitized requested started and completed events" passed`
- log: `✔ Test "Clarify choice answer records selected index without raw choices" passed`
- log: `✔ Test "Clarify invalid JSON and cancelled answer remain bounded" passed`
- log: `✔ Test "Clarify source never stores raw question JSON answers or choices" passed`
- note: focused verification log `/tmp/epistemos-clarify-prompt-bridge-agent-event-pr43-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `ClarifyPromptBridgeAgentEventTests`

## bridge-no-double-count-source-guards-pr44

- grep: `AgentEventBridgeNoDoubleCountSourceGuardTests` in `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift`
- forbidden bridge grep: `AgentToolProvenanceRecorder\\(|recordToolEvent\\(` returns no matches in `Epistemos/Bridge/ChunkedMCPFraming.swift`, `Epistemos/Bridge/CoTStreamInterceptor.swift`, `Epistemos/Bridge/StreamingDelegate.swift`, and `Epistemos/Bridge/ToolTierBridge.swift`.
- staged allow: only `EpistemosTests/AgentEventBridgeNoDoubleCountSourceGuardTests.swift`, Round 85 fleet/deliberation/preflight docs, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `✔ Suite "AgentEvent Bridge No-Double-Count Source Guards" passed`
- note: focused verification log `/tmp/epistemos-bridge-no-double-count-source-guards-pr44-green-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `AgentEventBridgeNoDoubleCountSourceGuardTests`

## ghost-computer-agent-reachability-guard-pr45

- grep: `GhostComputerAgentReachabilityGuardTests` in `EpistemosTests/GhostComputerAgentReachabilityGuardTests.swift`
- forbidden route grep: production Swift must not instantiate `GhostComputerAgent(` outside `Epistemos/LocalAgent/GhostComputerAgent.swift`.
- forbidden adapter grep: production Swift must not call `GhostComputerAgent.mcpSee`, `mcpClick`, `mcpType`, `mcpKeys`, `mcpScroll`, or `mcpScreenshot`.
- shipping route grep: `Phase4Bridge.swift` and `StreamingDelegate.swift` keep computer-use dispatch on `ComputerUseBridge.shared.execute(actionJSON:)`, while `agent_core/src/agent_loop.rs` keeps `name == "computer"` delegated through the native computer callback.
- LocalAgent reflex audit: `flushOnStreamEnd()` returns plaintext only, fallback parsing routes tool calls into `executeToolCall`, and Kimi found no requested-without-terminal event path.
- staged allow: only the PR45 fleet detector, Kimi audit artifact, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this closure commit. Parallel-agent production/test work remains intentionally excluded.
- log: `✔ Suite "GhostComputerAgent Reachability Guards" passed`
- note: focused verification log `/tmp/epistemos-ghost-computer-agent-reachability-guard-pr45-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `GhostComputerAgentReachabilityGuardTests`

## hermes-capability-registry-pr1

- grep: `HermesCapabilityRegistry` in `Epistemos/LocalAgent/HermesCapabilityRegistry.swift` and `EpistemosTests/HermesCapabilityRegistryTests.swift`.
- parity grep: every command row in `docs/fusion/fleet/hermes-capability-pass-through/HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` must have a registry row, enforced by `HermesCapabilityRegistryTests`.
- tier-leakage grep: `HermesCapabilityRegistry.capabilities(for: .coreAppStore)` exposes only `.core` / `.nativeCore` rows with no network, no subprocess, and no structured external evidence.
- staged allow: only `Epistemos/LocalAgent/HermesCapabilityRegistry.swift`, `EpistemosTests/HermesCapabilityRegistryTests.swift`, this guard file, current-state docs, workcard docs, and the fleet registry are allowed for this commit. Parallel-agent files remain intentionally excluded.
- log: `✔ Suite "Hermes Capability Registry" passed`
- note: focused verification log `/tmp/epistemos-hermes-capability-registry-pr1-20260503.log`; Xcode exited `0` and printed `** TEST SUCCEEDED **`.
- test: `HermesCapabilityRegistryTests`
