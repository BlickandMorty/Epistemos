# Post-Merge Guards - 2026-05-02

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
