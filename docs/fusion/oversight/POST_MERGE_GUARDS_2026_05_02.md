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
