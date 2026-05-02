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
