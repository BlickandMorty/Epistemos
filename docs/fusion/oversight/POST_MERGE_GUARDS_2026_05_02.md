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
- grep: `directPageSearchMetadata(surface: "search"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `directPageSearchMetadata(surface: "search_async"` in `Epistemos/Sync/SearchIndexService.swift`
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
