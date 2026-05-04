# Native Cleanup Scan

> **Index status**: CANONICAL-OPERATIONAL — Append-only audit log; needed for state reconstruction. No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



- Generated: Sat Mar 21 17:29:47 CDT 2026
- Root: `/Users/jojo/Epistemos`

## Tool Availability
- ast-grep: installed
- periphery: installed
- cargo-machete: installed
- cargo-udeps: installed

## Immediate Install Commands
```bash
brew install ast-grep peripheryapp/periphery/periphery
cargo install cargo-machete
cargo install cargo-udeps
rustup toolchain install nightly
```

## Rule Files
- `/Users/jojo/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-swift.yml`
- `/Users/jojo/Epistemos/scripts/audit/ast-grep/observable-object-ban-swift.yml`
- `/Users/jojo/Epistemos/scripts/audit/ast-grep/ffi-json-copy-ban-swift.yml`
- `/Users/jojo/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-rust.yml`

### ast-grep Swift Legacy Runtime Scan
```bash
ast-grep scan --rule '/Users/jojo/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-swift.yml' '/Users/jojo/Epistemos/Epistemos'
```

### ast-grep Swift ObservableObject Scan
```bash
ast-grep scan --rule '/Users/jojo/Epistemos/scripts/audit/ast-grep/observable-object-ban-swift.yml' '/Users/jojo/Epistemos/Epistemos'
```

### ast-grep Swift FFI JSON Copy Scan
```bash
ast-grep scan --rule '/Users/jojo/Epistemos/scripts/audit/ast-grep/ffi-json-copy-ban-swift.yml' '/Users/jojo/Epistemos/Epistemos/Engine' '/Users/jojo/Epistemos/Epistemos/Graph' '/Users/jojo/Epistemos/Epistemos/Views/Graph'
```

### ast-grep Rust Legacy Runtime Scan
```bash
ast-grep scan --rule '/Users/jojo/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-rust.yml' '/Users/jojo/Epistemos/graph-engine'
```

### Periphery Swift Reachability Scan
```bash
cd '/Users/jojo/Epistemos' && periphery scan --project Epistemos.xcodeproj --schemes Epistemos --targets Epistemos --format xcode --retain-codable-properties --retain-objc-accessible
```
    * Inspecting project...
    * Building Epistemos...
    * Indexing...
    * Analyzing...
    
    /Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift:67:17: warning: Property 'localRuntimeObserverTokens' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift:68:17: warning: Property 'localModelRefreshThrottle' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift:73:9: warning: Property 'localMLXClient' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift:275:17: warning: Function 'gradeFromConfidence(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/App/AppCoordinator.swift:24:17: warning: Property 'notesUI' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/ChatCoordinator.swift:1187:17: warning: Function 'gradeFromConfidence(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/App/EpistemosApp.swift:267:9: warning: Property 'notesUI' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/RootView.swift:465:9: warning: Property 'label' is unused
    /Users/jojo/Epistemos/Epistemos/App/RootView.swift:471:9: warning: Property 'icon' is unused
    /Users/jojo/Epistemos/Epistemos/App/StatusBar.swift:13:17: warning: Property 'menu' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift:120:9: warning: Property 'usesFullWindow' is unused
    /Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift:176:10: warning: Function 'hide(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift:180:10: warning: Function 'toggle(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift:192:10: warning: Function 'isVisible(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/App/UtilityWindowManager.swift:207:18: warning: Function 'windowFor(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/DataDetectionService.swift:19:13: warning: Property 'text' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:91:16: warning: Property 'maxOpeningMarkerLength' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:95:16: warning: Property 'maxAnswerMarkerLength' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:253:17: warning: Function 'flushableReasoningPrefix(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:288:17: warning: Function 'likelyAnswerCandidate(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:465:5: warning: Function 'subscript(safe:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:471:22: warning: Function 'strippingThinkingBlocks()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:703:9: warning: Property 'uniqueStrings' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/Extensions.swift:706:25: warning: Class 'BorrowedUTF8StringCache' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Keychain.swift:11:6: warning: Enum 'Keychain' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:5:6: warning: Enum 'KnowledgeCoreDocumentFormat' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:37:6: warning: Enum 'KnowledgeCoreBackpressurePolicy' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:42:9: warning: Property 'code' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:43:9: warning: Property 'message' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:55:8: warning: Struct 'KnowledgeCoreTransportStatsSnapshot' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:63:9: warning: Property 'rowKind' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:64:9: warning: Property 'pageId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:65:9: warning: Property 'blockId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:66:9: warning: Property 'parentId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:67:9: warning: Property 'targetId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:68:9: warning: Property 'content' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:69:9: warning: Property 'propertyKey' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:70:9: warning: Property 'propertyValue' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:71:9: warning: Property 'taskMarker' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:72:9: warning: Property 'orderKey' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:73:9: warning: Property 'depth' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:74:9: warning: Property 'refType' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:75:9: warning: Property 'taskDone' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:78:8: warning: Struct 'KnowledgeCorePayloadSnapshot' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:98:8: warning: Struct 'KnowledgeCoreProjectionSnapshot' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:105:16: warning: Struct 'KnowledgeCoreSlotHeader' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:112:7: warning: Class 'KnowledgeCoreBridge' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:579:17: warning: Property 'bridge' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:581:17: warning: Property 'pollTaskBox' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:597:5: warning: Initializer 'init(peerId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:604:10: warning: Function 'subscribeOutline(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:611:10: warning: Function 'subscribeTasks(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:618:10: warning: Function 'subscribeProperties(pageId:key:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:626:10: warning: Function 'unsubscribe(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:633:10: warning: Function 'ingestDocument(pageId:format:text:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:644:10: warning: Function 'moveBlock(pageId:blockId:parentId:index:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:660:10: warning: Function 'drainPayloads(limit:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:664:10: warning: Function 'startIfNeeded(frameInterval:maxFramesPerBatch:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:684:10: warning: Function 'stop()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:689:18: warning: Function 'applyBatch(_:drainDurationNs:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:707:21: warning: Class 'PollTaskBox' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:715:28: warning: Struct 'KnowledgeCoreProjectionCacheStats' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:721:9: warning: Property 'rowKind' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:722:9: warning: Property 'pageId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:723:9: warning: Property 'blockId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:724:9: warning: Property 'parentId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:725:9: warning: Property 'targetId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:726:9: warning: Property 'propertyKey' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:727:9: warning: Property 'refType' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:730:28: warning: Struct 'KnowledgeCoreProjectedRow' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/KnowledgeCoreBridge.swift:740:33: warning: Class 'KnowledgeCoreProjectionCache' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:10:10: warning: Function 'testConnection()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:33:10: warning: Function 'generate(prompt:systemPrompt:maxTokens:reasoningMode:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:48:10: warning: Function 'stream(prompt:systemPrompt:maxTokens:reasoningMode:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:147:10: warning: Function 'testConnection()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:247:21: warning: Property 'raw' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:249:5: warning: Initializer 'init(raw:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:254:20: warning: Struct 'ProcessActivityManager' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:270:18: warning: Enum 'ProcessActivity' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:315:18: warning: Enum 'LLMError' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift:343:20: warning: Struct 'ConnectionTestResult' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:295:9: warning: Property 'key' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:296:9: warning: Property 'role' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:297:9: warning: Property 'displayName' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:298:9: warning: Property 'artifactID' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:299:9: warning: Property 'modelID' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:302:9: warning: Property 'expectedAdapterBaseModelID' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:303:9: warning: Property 'baseModelID' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:304:9: warning: Property 'baseSnapshotPath' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:305:9: warning: Property 'mergeOutputPath' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:308:9: warning: Property 'status' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:309:9: warning: Property 'trustRemoteCode' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:311:9: warning: Property 'resolvedAdapterPath' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:319:9: warning: Property 'resolvedMLXOutputPath' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:323:10: warning: Function 'matchesSidecarModelID(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:405:9: warning: Property 'hasPreparedAssetsConfigured' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:409:9: warning: Property 'requiresPreparedIndexBuild' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:466:9: warning: Property 'retrieverSourceRoot' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:467:9: warning: Property 'indexRoot' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:612:9: warning: Property 'requiresRebuild' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Log.swift:41:16: warning: Property 'learning' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Log.swift:44:16: warning: Property 'research' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Log.swift:47:16: warning: Property 'security' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/Log.swift:53:16: warning: Property 'graph' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:20:9: warning: Property 'reasoningMode' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:46:10: warning: Function 'unload()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:55:9: warning: Property 'totalBudget' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:66:9: warning: Property 'modelID' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:67:9: warning: Property 'coldLoad' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:68:9: warning: Property 'lowPowerModeEnabled' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:69:9: warning: Property 'appActive' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:70:9: warning: Property 'thermalState' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:71:9: warning: Property 'loadDurationMS' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:72:9: warning: Property 'firstTokenLatencyMS' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:73:9: warning: Property 'totalDurationMS' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:74:9: warning: Property 'outputCharacterCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:75:9: warning: Property 'chunkCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:76:9: warning: Property 'continuationCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:77:9: warning: Property 'stopReason' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:78:9: warning: Property 'memoryLimitBytes' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:79:9: warning: Property 'cacheLimitBytes' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:308:10: warning: Function 'testConnection()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:333:9: warning: Parameter 'reasoningMode' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:394:29: warning: Function 'formattedSystemPrompt(_:reasoningMode:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/MLXInferenceService.swift:591:10: warning: Function 'profilingSnapshot()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NLAnalysisService.swift:19:12: warning: Struct 'Entity' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NLAnalysisService.swift:31:29: warning: Function 'extractEntities(from:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NLAnalysisService.swift:73:29: warning: Function 'detectLanguage(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NLAnalysisService.swift:84:29: warning: Function 'sentiment(of:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NoteInsightService.swift:211:22: warning: Function 'fetchInsight(pageId:context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/NoteInsightService.swift:218:10: warning: Function 'debugPendingReanalyzeTaskCount()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift:17:18: warning: Enum 'PipelineError' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift:117:10: warning: Function 'executeReactive(query:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift:190:9: warning: Property 'query' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift:191:9: warning: Property 'resultCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/QueryEngine.swift:192:9: warning: Property 'timestamp' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:77:9: warning: Property 'source' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:94:9: warning: Parameter 'configuration' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:100:9: warning: Parameter 'configuration' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:101:9: warning: Parameter 'executionMode' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:108:9: warning: Parameter 'configuration' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:122:9: warning: Parameter 'configuration' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/QueryRuntime.swift:123:9: warning: Parameter 'executionMode' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:12:17: warning: Property 'runtime' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:13:17: warning: Property 'plan' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:14:17: warning: Property 'dependencies' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:15:17: warning: Property 'debounceTask' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:16:17: warning: Property 'lastResult' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:17:17: warning: Property 'cancellables' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:18:17: warning: Property 'continuation' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:22:17: warning: Property 'debounceInterval' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:24:5: warning: Initializer 'init(runtime:plan:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:31:10: warning: Function 'stream()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:71:18: warning: Function 'reevaluate()' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:85:10: warning: Function 'shouldInvalidate(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:92:18: warning: Function 'handleInvalidation(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:102:10: warning: Function 'isEquivalent(to:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:121:17: warning: Initializer 'init(runtime:ast:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/ReactiveQuery.swift:127:17: warning: Initializer 'init(runtime:query:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/SpotlightIndexer.swift:68:17: warning: Function 'reindexAll(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:119:9: warning: Property 'promptLength' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:127:9: warning: Property 'visibleThinkingRequested' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:141:9: warning: Property 'selectedReasoningMode' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:143:9: warning: Property 'reuseWarmModel' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:144:9: warning: Property 'complexityTier' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:145:9: warning: Property 'contextTier' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:146:9: warning: Property 'reasonCodes' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:148:9: warning: Property 'selectedLocalModelID' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:251:10: warning: Function 'localSelection(for:context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:311:13: warning: Parameter 'profile' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:313:9: warning: Parameter 'complexityTier' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:314:9: warning: Parameter 'contextTier' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:465:9: warning: Property 'isOnDevice' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:476:9: warning: Property 'icon' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:623:10: warning: Function 'triage(operation:contentLength:query:localReasoningMode:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:737:10: warning: Function 'triageGeneral(operation:contentLength:localReasoningMode:localSurface:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:1032:25: warning: Function 'explicitThinkingRequested(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift:1037:25: warning: Function 'explicitFastRequested(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:31:9: warning: Property 'id' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:49:12: warning: Struct 'EmbeddingCacheDebugSnapshot' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:66:17: warning: Property 'embeddingCacheHitCount' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:67:17: warning: Property 'embeddingCacheMissCount' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:217:10: warning: Function 'embedding(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:245:22: warning: Function 'computeBlockVectors(blocks:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:266:10: warning: Function 'computeFallbackSemanticClusters(store:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:275:10: warning: Function 'pushBlockEmbeddings(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:291:10: warning: Function 'embeddingCacheDebugSnapshot()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:302:10: warning: Function 'setEmbeddingCacheCapacityForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:307:10: warning: Function 'replaceEmbeddingCacheForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:311:10: warning: Function 'setDimensionForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:315:10: warning: Function 'waitForPendingComputationForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:344:18: warning: Function 'touchEmbeddingCacheEntry(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EmbeddingService.swift:370:18: warning: Function 'trimEmbeddingCacheIfNeeded()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/EntityExtractor.swift:13:13: warning: Class 'EntityExtractor' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/ExtractionTypes.swift:7:20: warning: Struct 'ExtractionResult' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/ExtractionTypes.swift:38:20: warning: Struct 'InsightExtractionResult' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/FilterEngine.swift:41:10: warning: Function 'showAllTypes()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/FilterEngine.swift:76:11: warning: Parameter 'edge' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphBuilder.swift:21:29: warning: Function 'resetBlockRefFetchDiagnosticsForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphBuilder.swift:27:29: warning: Function 'blockRefFetchBatchCountForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:26:10: warning: Enum 'NodeType' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:37:10: warning: Enum 'Mode' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:43:10: warning: Enum 'CenterMode' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:52:17: warning: Property 'btkStringCache' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:56:9: warning: Property 'rawHandle' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:62:5: warning: Initializer 'init(device:layer:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:79:10: warning: Function 'clear()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:92:10: warning: Function 'addNode(uuid:x:y:nodeType:linkCount:label:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:102:10: warning: Function 'addNode(uuid:x:y:nodeType:linkCount:label:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:112:10: warning: Function 'addEdge(sourceUUID:targetUUID:weight:edgeType:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:125:10: warning: Function 'commit(entrance:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:135:10: warning: Function 'render(width:height:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:147:10: warning: Function 'mouseDown(x:y:shiftHeld:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:153:10: warning: Function 'mouseMoved(x:y:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:159:10: warning: Function 'mouseUp()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:165:10: warning: Function 'scroll(deltaX:deltaY:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:171:10: warning: Function 'magnify(screenX:screenY:magnification:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:179:10: warning: Function 'setForceParams(linkDistance:chargeStrength:chargeRange:linkStrength:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:190:10: warning: Function 'setExtendedForceParams(velocityDecay:centerStrength:collisionRadius:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:202:10: warning: Function 'highlightNeighbors(uuid:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:208:10: warning: Function 'clearHighlight()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:215:10: warning: Function 'searchHighlight(query:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:221:10: warning: Function 'pollHaptic()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:227:10: warning: Function 'setSearchActive(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:233:10: warning: Function 'setLabParams(enableFluid:enableTorsion:enableElastic:fluidViscosity:edgeElasticity:torsionRigidity:boidsCohesion:windX:windY:enableOrbital:orbitalSpeed:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:259:10: warning: Function 'centerCamera()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:265:10: warning: Function 'centerOnNode(uuid:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:271:10: warning: Function 'zoomToFit()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:279:10: warning: Function 'pause()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:285:10: warning: Function 'resume()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:293:10: warning: Function 'setClusterParams(clusterStrength:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:299:10: warning: Function 'setCenterMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:305:10: warning: Function 'setCenterMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:313:10: warning: Function 'screenToWorld(screenX:screenY:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:324:10: warning: Function 'setNodeVisible(uuid:visible:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:330:10: warning: Function 'refreshVisibility()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:338:10: warning: Function 'setClearColor(r:g:b:a:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:344:10: warning: Function 'setMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:350:10: warning: Function 'setMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:356:10: warning: Function 'setAnchorRect(x:y:width:height:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:364:9: warning: Property 'hoveredNodeUUID' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:371:9: warning: Property 'selectedNodeUUID' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:378:9: warning: Property 'isSettled' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:384:9: warning: Property 'isStaticLayout' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:392:12: warning: Struct 'SearchResult' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:401:10: warning: Function 'search(query:limit:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:424:10: warning: Function 'setClusterIds(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:436:10: warning: Function 'setNodeEmbedding(uuid:vector:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:446:10: warning: Function 'clearSemanticEmbeddings()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:451:10: warning: Function 'semanticEmbeddingCount()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:456:10: warning: Function 'semanticEmbeddingDimension()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:462:10: warning: Function 'resetSemanticEmbeddingDimension(to:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:467:10: warning: Function 'recomputeSemanticNeighbors(k:threshold:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:480:12: warning: Struct 'BTKSubscriptionPayloadSummary' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:507:13: warning: Property 'pageId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:508:13: warning: Property 'blockId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:509:13: warning: Property 'parentId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:510:13: warning: Property 'targetId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:511:13: warning: Property 'content' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:512:13: warning: Property 'propertyKey' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:513:13: warning: Property 'propertyValue' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:514:13: warning: Property 'taskMarker' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:515:13: warning: Property 'orderKey' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:516:13: warning: Property 'depth' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:517:13: warning: Property 'refType' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:518:13: warning: Property 'taskDone' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:519:13: warning: Property 'hopCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:520:13: warning: Property 'key' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:522:9: warning: Initializer 'init(pageId:blockId:parentId:targetId:content:propertyKey:propertyValue:taskMarker:orderKey:depth:refType:taskDone:hopCount:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:561:12: warning: Struct 'BTKSubscriptionPayload' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:569:10: warning: Function 'btkSubscribeOutline(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:575:10: warning: Function 'btkSubscribeProperty(key:value:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:589:10: warning: Function 'btkSubscribeLinks(blockId:maxDepth:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:596:10: warning: Function 'btkUnsubscribe(id:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:601:10: warning: Function 'btkTakeSubscriptionUpdate(id:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:606:10: warning: Function 'btkSnapshotSubscription(id:version:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:613:9: warning: Property 'btkLatestSubscriptionSeq' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:618:18: warning: Function 'decodeBTKPayload(buffer:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:636:18: warning: Function 'decodeBTKSummary(base:count:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:654:18: warning: Function 'decodeBTKRows(section:rowCount:base:count:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:688:18: warning: Function 'decodeBTKRowsScalar(section:rowCount:base:count:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:706:18: warning: Function 'decodeBTKRow(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:724:18: warning: Function 'takeBTKBuffer(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:734:18: warning: Function 'decode(slice:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:742:17: warning: Property 'engine' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:743:17: warning: Property 'subscriptionId' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:752:5: warning: Initializer 'init(engine:outlinePageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:765:5: warning: Initializer 'init(engine:propertyKey:propertyValue:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:778:5: warning: Initializer 'init(engine:linkedBlockId:maxDepth:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:791:10: warning: Function 'startPolling(interval:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:801:10: warning: Function 'stopPolling()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:806:10: warning: Function 'pollNow()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:811:10: warning: Function 'snapshot(at:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:815:10: warning: Function 'close()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:820:18: warning: Function 'apply(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphEngine.swift:836:33: warning: Class 'BTKPayloadLease' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:32:16: warning: Property 'interactionMotionHoldSeconds' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:33:16: warning: Property 'interactionMotionAlphaTarget' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:35:17: warning: Function 'preset(afterElapsedSeconds:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:312:9: warning: Property 'preparedRetrievalRuntimeConfiguration' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:741:10: warning: Function 'computeSemanticClusters()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:763:10: warning: Function 'beginConnecting(from:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:810:10: warning: Function 'loadGraph(context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1012:10: warning: Function 'rustSearch(query:limit:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1171:10: warning: Function 'hybridSearch(query:limit:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1199:10: warning: Function 'searchHighlight(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1207:10: warning: Function 'setSearchActive(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1219:9: warning: Property 'selectedNode' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1245:10: warning: Function 'buildPageSubgraph(for:context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1297:18: warning: Function 'addEphemeralNode(id:type:label:parentId:edgeType:createdAt:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1319:18: warning: Function 'resolveWikilinkEdge(target:from:byteOffset:createdAt:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1370:18: warning: Function 'sanitizeLabel(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1381:10: warning: Function 'createNode(type:label:atWorldPosition:context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1426:10: warning: Function 'createConnectedNode(type:label:connectedTo:edgeType:atWorldPosition:context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift:1524:10: warning: Function 'scanVault(context:llmService:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:82:13: warning: Property 'sourceId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:83:13: warning: Property 'type' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:87:13: warning: Property 'query' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:88:13: warning: Property 'limit' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:96:12: warning: Struct 'SearchCacheDebugSnapshot' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:184:13: warning: Property 'count' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:187:13: warning: Property 'isEmpty' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:202:13: warning: Property 'count' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:205:13: warning: Property 'isEmpty' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:313:10: warning: Function 'load(context:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:493:10: warning: Function 'nodes(ofTypes:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:986:10: warning: Function 'searchCacheDebugSnapshot()' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/GraphStore.swift:995:10: warning: Function 'setSearchCacheNowProviderForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Graph/SemanticClusterService.swift:16:6: warning: Enum 'SemanticClusterService' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/AnalysisIntents.swift:8:36: warning: Property 'description' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/DailyBriefingIntent.swift:9:36: warning: Property 'description' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NavigationIntents.swift:8:8: warning: Struct 'OpenPanelIntent' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NavigationIntents.swift:28:8: warning: Struct 'OpenMiniChatIntent' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NoteActionIntents.swift:13:36: warning: Property 'description' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NoteActionIntents.swift:41:36: warning: Property 'description' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NoteActionIntents.swift:86:8: warning: Struct 'OpenVaultFileIntent' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NoteActionIntents.swift:105:8: warning: Struct 'MoveNoteToFolderIntent' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Custom/NoteActionIntents.swift:145:8: warning: Struct 'SearchDocumentsIntent' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Entities/FolderEntity.swift:14:40: warning: Property 'noteCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Entities/NoteEntity.swift:14:37: warning: Property 'content' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Entities/NoteEntity.swift:15:37: warning: Property 'createdAt' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Entities/NoteEntity.swift:16:37: warning: Property 'updatedAt' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Entities/PanelEntity.swift:24:5: warning: Initializer 'init(id:name:)' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:66:9: warning: Property 'message' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:69:9: warning: Property 'mediaItems' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:72:9: warning: Property 'entryDate' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:75:9: warning: Property 'location' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:99:9: warning: Property 'location' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/JournalIntents.swift:102:9: warning: Property 'mediaItems' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/SystemSearchIntent.swift:12:36: warning: Property 'description' is unused
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/WordProcessorIntents.swift:59:9: warning: Property 'creationDate' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/WordProcessorIntents.swift:62:9: warning: Property 'modificationDate' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Intents/Schemas/WordProcessorIntents.swift:94:5: warning: Initializer 'init(id:name:)' is unused
    /Users/jojo/Epistemos/Epistemos/Models/BrandedTypes.swift:14:29: warning: Function 'new()' is unused
    /Users/jojo/Epistemos/Epistemos/Models/EngineTypes.swift:61:8: warning: Struct 'StageResult' is unused
    /Users/jojo/Epistemos/Epistemos/Models/EngineTypes.swift:213:8: warning: Struct 'SignalUpdate' is unused
    /Users/jojo/Epistemos/Epistemos/Models/EngineTypes.swift:255:8: warning: Struct 'SignalHistoryEntry' is unused
    /Users/jojo/Epistemos/Epistemos/Models/QueryTypes.swift:123:9: warning: Property 'weight' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Models/QueryTypes.swift:205:17: warning: Function 'from(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Models/QueryTypes.swift:214:9: warning: Property 'dependencies' is unused
    /Users/jojo/Epistemos/Epistemos/Models/QueryTypes.swift:224:9: warning: Property 'dependencies' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDMessage.swift:82:10: warning: Function 'updateAnalysis(dualMessage:truthAssessment:confidence:evidenceGrade:mode:)' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:33:16: warning: Property 'pinnedPagesDescriptor' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:43:16: warning: Property 'journalDescriptor' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:70:17: warning: Function 'byStageDescriptor(stage:)' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:92:16: warning: Property 'templatesDescriptor' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:112:17: warning: Function 'byTypeDescriptor(type:)' is unused
    /Users/jojo/Epistemos/Epistemos/Models/SDPage+Queries.swift:125:16: warning: Property 'topLevelFoldersDescriptor' is unused
    /Users/jojo/Epistemos/Epistemos/Models/VaultManifest.swift:14:9: warning: Property 'generatedAt' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Models/VaultManifest.swift:24:13: warning: Property 'createdAt' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:40:9: warning: Property 'symbol' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:41:9: warning: Property 'crestLabel' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:47:9: warning: Property 'mood' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:51:19: warning: Function 'applyDecay(now:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:64:19: warning: Function 'recordInteraction(userText:now:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:83:19: warning: Function 'markOpened(now:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:94:25: warning: Function 'clamp(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:124:17: warning: Function 'fallback(nodeType:noteBody:linkedNodeCount:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:144:17: warning: Function 'tier(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:260:9: warning: Property 'archetype' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:262:9: warning: Property 'openingLine' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:264:9: warning: Property 'portrait' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:281:17: warning: Function 'derive(nodeId:label:nodeType:noteBody:linkedNodeLabels:insight:cachedSignals:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:355:10: warning: Function 'refreshed(noteBody:linkedNodeLabels:now:insight:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:378:19: warning: Function 'recordInteraction(userText:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:382:25: warning: Function 'resolveMood(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:390:25: warning: Function 'deriveArchetype(nodeType:body:tokens:linkedNodeLabels:ml:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:400:25: warning: Function 'deriveMood(body:tokens:richness:linkedNodeLabels:ml:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:410:25: warning: Function 'contentRichness(body:linkedNodeLabels:keywords:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:421:25: warning: Function 'depthResilience(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:431:25: warning: Function 'depthCuriosity(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:441:25: warning: Function 'portraitAsset(for:mood:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:445:25: warning: Function 'focusKeywords(in:linkedNodeLabels:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:472:25: warning: Function 'normalizedTokens(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:479:25: warning: Function 'questionSignalCount(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:484:25: warning: Function 'citationSignalCount(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:489:25: warning: Function 'ideaSignalCount(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:494:24: warning: Property 'stopWords' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:512:13: warning: Property 'role' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:515:26: warning: Enum case 'user' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:515:32: warning: Enum case 'assistant' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:535:37: warning: Property 'streamingTask' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:537:22: warning: Property 'streamBuffer' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:542:37: warning: Property 'typewriterTask' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:543:37: warning: Property 'nodeProfiles' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:547:10: warning: Function 'open(nodeId:label:nodeType:noteBody:linkedNodeLabels:insight:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:608:25: warning: Function 'cachedSignals(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:622:10: warning: Function 'close()' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:636:10: warning: Function 'submitQuery(noteBody:linkedNodeLabels:neighborContext:nodeType:insight:triageService:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:707:18: warning: Function 'appendStreamingText(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:711:18: warning: Function 'flushTokens()' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:717:18: warning: Function 'startTypewriter()' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:731:18: warning: Function 'buildPrompt(query:noteBody:linkedNodeLabels:neighborContext:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/DialogueChatState.swift:773:25: warning: Function 'buildRelatedNotesSection(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:12:10: warning: Enum case 'vaultPageDeleted(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:15:10: warning: Enum case 'custom(name:payload:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:46:10: warning: Function 'unsubscribe(id:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:52:10: warning: Function 'events()' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:85:10: warning: Function 'emitError(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/EventBus.swift:92:6: warning: Enum 'AnySendable' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:135:9: warning: Property 'prefersConstrainedLocalModel' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:139:9: warning: Property 'allowsAutomaticLocalRouting' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:159:9: warning: Property 'physicalMemoryBytes' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:233:22: warning: Function 'recommendedLocalTextModelID(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:332:10: warning: Function 'setInferenceMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:349:17: warning: Property 'supportedInstalledLocalTextModels' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:384:10: warning: Function 'localModelSelection(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:388:10: warning: Function 'canAutomaticallyRouteToLocalMLX(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/InferenceState.swift:395:10: warning: Function 'canRouteToLocalMLX(contentLength:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/PhysicsCoordinator.swift:40:10: warning: Function 'pulse()' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:61:10: warning: Function 'createThread(type:label:pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:68:10: warning: Function 'closeThread(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:76:10: warning: Function 'setActiveThread(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:94:10: warning: Function 'activeThread()' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:106:10: warning: Function 'updateActiveThreadLoadedNotes(ids:titles:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:126:10: warning: Function 'updateActiveThreadContextAttachments(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:131:10: warning: Function 'addActiveThreadContextAttachment(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/ThreadState.swift:151:10: warning: Function 'removeActiveThreadContextAttachment(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:171:9: warning: Property 'contentBackground' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:178:9: warning: Property 'overlayChromeBackground' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:374:10: warning: Function 'setPair(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:379:10: warning: Function 'setThemeMode(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:384:10: warning: Function 'setCustomThemesEnabled(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:409:10: warning: Function 'toggleCommandPalette()' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:415:10: warning: Function 'dismissCommandPalette()' is unused
    /Users/jojo/Epistemos/Epistemos/State/UIState.swift:458:10: warning: Function 'toggleMiniChat()' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/BlockParser.swift:169:29: warning: Function 'serialize(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/MappedNoteBody.swift:8:8: warning: Struct 'MappedNoteBody' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/NoteFileStorage.swift:104:29: warning: Function 'setStorageDirectoryOverrideForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/NoteFileStorage.swift:137:29: warning: Function 'readBodyData(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/NoteFileStorage.swift:181:29: warning: Function 'bodyExists(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/SearchIndexService.swift:366:22: warning: Function 'upsertBlock(blockId:pageId:content:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/SearchIndexService.swift:382:22: warning: Function 'deleteBlock(blockId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/SearchIndexService.swift:439:22: warning: Function 'delete(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/SearchIndexService.swift:853:29: warning: Function 'sanitizeFTS5Query(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:20:13: warning: Property 'changedPageCount' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:21:13: warning: Property 'willIndex' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:405:10: warning: Function 'reindexFile(at:vaultURL:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:478:59: warning: Parameter 'vaultURL' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:516:10: warning: Function 'handleFileDeletion(at:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:893:24: warning: Property 'vaultStopWords' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:916:10: warning: Function 'buildVaultContext(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultIndexActor.swift:1154:10: warning: Function 'spotlightReindexSnapshotForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:19:9: warning: Property 'title' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:20:9: warning: Property 'appBody' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:21:9: warning: Property 'diskBody' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:31:9: warning: Property 'bookmarkExists' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:180:10: warning: Function 'setVaultURLForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:184:10: warning: Function 'importVaultForTesting(from:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:191:10: warning: Function 'setExportPageOverrideForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:195:10: warning: Function 'setSearchDatabaseURLForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:199:10: warning: Function 'setAppSupportDirectoryURLForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:203:10: warning: Function 'setPreferencesFileURLForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:207:10: warning: Function 'setRecoverySnapshotRootURLForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:211:10: warning: Function 'setManagedBodyCountProviderForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:215:10: warning: Function 'setUserDefaultsForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:221:10: warning: Function 'setInitialImportCompletedForTesting(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:894:10: warning: Function 'buildVaultContext(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift:930:10: warning: Function 'searchFull(query:limit:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:393:13: warning: Property 'icon' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:829:10: warning: Function 'resolved(isDark:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:834:10: warning: Function 'dockIconResourceName(isDark:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:857:16: warning: Property 'xl' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:859:16: warning: Property 'xxxl' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:871:21: warning: Property 'fontName' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:926:21: warning: Property 'displayName' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:966:28: warning: Property 'fontName' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1057:17: warning: Function 'text(_:strongFontSize:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1083:17: warning: Function 'attributedString(_:strongFontSize:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1198:16: warning: Property 'epMono' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1206:16: warning: Property 'page' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1218:16: warning: Property 'elastic' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1219:16: warning: Property 'inertial' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/EpistemosTheme.swift:1223:16: warning: Property 'breathRate' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:6:8: warning: Struct 'FlatToGlassModifier' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:257:8: warning: Struct 'SiriPixelGlowModifier' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:272:9: warning: Property 'innerRadius' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:273:9: warning: Property 'controlRadius' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:431:9: warning: Property 'tintOpacity' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:434:9: warning: Property 'highlightOpacity' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:1141:10: warning: Function 'flatToGlass(isActive:flatBackground:cornerRadius:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:1156:10: warning: Function 'hoverGlassCapsule(flatBackground:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:1162:10: warning: Function 'siriGlow(cornerRadius:lineWidth:isActive:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/GlassModifiers.swift:1170:10: warning: Function 'pixelGlow(cornerRadius:isActive:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/NativeButtonStyles.swift:21:9: warning: Parameter 'isHovered' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/NativeButtonStyles.swift:287:8: warning: Struct 'ThemedToolbarButtonStyle' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/PhysicsModifiers.swift:123:8: warning: Struct 'PhysicsPressModifier' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/PhysicsModifiers.swift:261:10: warning: Function 'physicsPress()' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:13:13: warning: Property 'shadowDark' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:16:13: warning: Property 'textMuted' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:17:13: warning: Property 'accent' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:18:13: warning: Property 'selection' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:59:20: warning: Property 'small' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:63:10: warning: Enum 'Metrics' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/PlatinumTheme.swift:350:10: warning: Function 'platinumWindow(title:isActive:isDark:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift:26:76: warning: Parameter 'height' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift:60:10: warning: Function 'updateGlassToolbarTheme(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Theme/ToolbarGlass.swift:87:17: warning: Property 'effectView' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift:375:16: warning: Property 'lineHeight' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift:377:16: warning: Property 'maxHeight' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift:391:17: warning: Function 'clampedHeight(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift:674:16: warning: Struct 'ProviderBadge' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatView.swift:123:44: warning: Property 'ui' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatView.swift:126:51: warning: Property 'inference' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/ChatView.swift:132:17: warning: Property 'theme' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:23:9: warning: Property 'icon' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:70:9: warning: Property 'content' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:141:12: warning: Struct 'BlockCacheStats' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:148:17: warning: Function 'resetBlockCacheForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:157:17: warning: Function 'cachedBlockCount(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:161:17: warning: Function 'blockCacheStatsForTesting()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Chat/TaggedMarkdownTextView.swift:626:8: warning: Struct 'TagSummaryBar' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/GraphFloatingControls.swift:13:16: warning: Property 'showsPageModeToggle' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/GraphOverlayPanel.swift:47:14: warning: Initializer 'init(coder:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramController.swift:7:16: warning: Property 'pageModeEnabled' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramController.swift:112:9: warning: Property 'isVisible' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift:119:17: warning: Property 'queryEngine' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift:177:10: warning: Function 'toggle()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift:459:10: warning: Function 'showMini()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/HologramOverlay.swift:540:18: warning: Function 'createMiniPanel()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:37:9: warning: Property 'graphStateIdentity' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:38:9: warning: Property 'graphDataVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:39:9: warning: Property 'filterVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:40:9: warning: Property 'modeVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:41:9: warning: Property 'liteModeVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:42:9: warning: Property 'visualThemeVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:43:9: warning: Property 'forceConfigVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:44:9: warning: Property 'extendedForceConfigVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:45:9: warning: Property 'clusterConfigVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:46:9: warning: Property 'semanticForceConfigVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:47:9: warning: Property 'semanticClusterVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:48:9: warning: Property 'labConfigVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:49:9: warning: Property 'physicsFrozenVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:50:9: warning: Property 'pendingCenterNodeId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:51:9: warning: Property 'pendingRebuild' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:52:9: warning: Property 'selectedNodeId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:133:17: warning: Property 'task' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:356:8: warning: Struct 'MetalGraphView' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:453:29: warning: Property 'dialogueChatState' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:454:29: warning: Property 'uiState' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:462:9: warning: Property 'searchQuery' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:472:17: warning: Property 'mouseDownLocation' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:490:9: warning: Property 'currentEngineHandle' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:885:10: warning: Function 'resetCamera()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:938:10: warning: Function 'searchHighlight(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:1313:53: warning: Parameter 'clickWorldPos' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift:1612:76: warning: Parameter 'maxDepth' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:15:13: warning: Property 'nodeId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:16:13: warning: Property 'nodeUpdatedAt' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:17:13: warning: Property 'topologyVersion' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:60:66: warning: Parameter 'modelContext' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:453:81: warning: Parameter 'modelContext' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Graph/NodeInspectorState.swift:477:78: warning: Parameter 'modelContext' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteWindowController.swift:47:17: warning: Function 'isClear(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteWindowController.swift:86:16: warning: Parameter 'bootstrap' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Landing/LandingView.swift:20:17: warning: Function 'nsFont(weight:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Landing/LandingView.swift:658:8: warning: Struct 'LandingCommandRow' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Landing/LandingView.swift:752:9: warning: Property 'isHovered' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift:7:8: warning: Struct 'MiniChatView' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift:197:9: warning: Property 'tags' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift:224:9: warning: Property 'hasBody' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift:266:5: warning: Initializer 'init(id:title:bodyProvider:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift:275:5: warning: Initializer 'init(id:title:snapshot:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:14:17: warning: Property 'isConfigured' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:48:10: warning: Function 'configure(bootstrap:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:65:10: warning: Function 'toggle()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:74:10: warning: Function 'show()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:75:10: warning: Function 'hide()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatWindowController.swift:83:18: warning: Function 'showPanel()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/BlockRefAutocomplete.swift:90:30: warning: Parameter 'query' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/BlockRefAutocomplete2.swift:121:30: warning: Parameter 'query' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ClickableTextView.swift:70:17: warning: Property 'frozenWidth' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/EditableTransclusionView.swift:11:9: warning: Property 'sourcePageId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownContentStorage.swift:71:10: warning: Function 'applyStructuralStyleForTest(to:range:paraType:metadata:isLeadingDocumentHeading:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownContentStorage.swift:576:25: warning: Parameter 'group' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownContentStorage.swift:1072:10: warning: Function 'isLineInFoldedRange(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownLayoutFragment.swift:19:22: warning: Property 'codeTokens' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownLayoutFragment.swift:20:22: warning: Property 'fragmentTheme' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownLayoutFragment.swift:21:22: warning: Property 'languageId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownLayoutFragment.swift:24:17: warning: Property 'cachedImage' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownLayoutFragment.swift:43:10: warning: Function 'invalidateCache()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownTextStorage.swift:228:10: warning: Function 'reapplyStyles(in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownTextStorage.swift:805:25: warning: Parameter 'group' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownTextStorage.swift:985:25: warning: Function 'tableDataRowIndex(at:in:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/MarkdownTextStorage.swift:1382:17: warning: Function 'tableSeparatorParagraphStyle()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:113:16: warning: Property 'stripGlowBlurRadius' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:117:17: warning: Function 'stripGlowOpacity(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:134:16: warning: Property 'cornerRadius' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:146:16: warning: Property 'minimumEditorSize' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:147:16: warning: Property 'editorCornerRadius' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:148:16: warning: Property 'editorMaxWidth' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:149:16: warning: Property 'horizontalPadding' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:150:16: warning: Property 'topPadding' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:151:16: warning: Property 'bottomPadding' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:157:17: warning: Function 'editorCardSize(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:176:16: warning: Property 'showsBottomFade' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:201:9: warning: Property 'shortcut' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:281:16: warning: Property 'tableReadableMaxWidth' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:282:16: warning: Property 'tableEditorReadableMaxWidth' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:319:17: warning: Function 'readableWidth(for:defaultWidth:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:323:41: warning: Parameter 'markdown' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:598:47: warning: Property 'graphState' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:602:45: warning: Property 'eventBus' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1456:18: warning: Function 'navigateToWikilink(title:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteTableOfContents.swift:14:14: warning: Enum case 'citation' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteTableOfContents.swift:15:14: warning: Enum case 'source' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteTableOfContents.swift:48:17: warning: Function 'parseRichText(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift:77:17: warning: Property 'hostingController' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift:170:10: warning: Function 'navigateTo(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift:418:10: warning: Function 'window(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift:422:38: warning: Parameter 'window' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NoteWindowManager.swift:534:21: warning: Function 'newWindowForTab(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift:24:9: warning: Property 'journalDate' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift:58:9: warning: Property 'sortOrder' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift:301:16: warning: Property 'showsBottomOrganizerButton' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift:387:47: warning: Property 'graphState' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/PageStoragePool.swift:217:10: warning: Function 'remove(pageId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable.swift:1205:36: warning: Parameter 'query' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable2.swift:33:16: warning: Property 'maxReadableWidth' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorView.swift:25:9: warning: Property 'initialBodyOverride' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorView.swift:50:17: warning: Function 'initialBodySnapshot(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseTextView2.swift:33:17: warning: Property 'reparseTask' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseTextView2.swift:276:10: warning: Function 'applyLinkAttributesToStorage()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseTextView2.swift:1779:10: warning: Function 'insertCallout(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/ProseTextView2.swift:1827:10: warning: Function 'insertCodeFence()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayManager.swift:61:10: warning: Function 'refresh()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayManager2.swift:92:10: warning: Function 'refresh()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:10:9: warning: Property 'blockId' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:12:17: warning: Property 'accentBar' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:14:5: warning: Initializer 'init(blockId:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:23:18: warning: Function 'setupViews()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:69:10: warning: Function 'setContent(_:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/TransclusionOverlayView.swift:75:10: warning: Function 'setMissing()' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Notes/VaultOrganizerView.swift:9:8: warning: Struct 'VaultOrganizerView' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift:9:44: warning: Property 'ui' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift:417:51: warning: Property 'inference' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift:649:9: warning: Property 'theme' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift:914:44: warning: Property 'ui' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Settings/SettingsView.swift:916:17: warning: Property 'theme' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:128:29: warning: Function 'overlayOpacity(for:level:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:142:29: warning: Function 'overlayBlurRadius(for:)' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:248:16: warning: Property 'heading1' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:249:16: warning: Property 'headings123' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:250:16: warning: Property 'heading1AndBody' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:254:16: warning: Property 'headings123AndBody' is unused
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:647:9: warning: Property 'topEdgeWidth' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:648:9: warning: Property 'bottomEdgeWidth' is assigned, but never used
    /Users/jojo/Epistemos/Epistemos/Views/Shared/MarkdownTextView.swift:877:9: warning: Property 'content' is assigned, but never used
    
    * Seeing false positives?
     - Periphery only analyzes files that are members of the targets you specify.
       References to declarations identified as unused may reside in files that are members of other targets, e.g test targets.
     - Periphery is a very precise tool, false positives often turn out to be correct after further investigation.
     - If it really is a false positive, please report it - https://github.com/peripheryapp/periphery/issues.
    
    * Update Available
    Version 3.6.0 is now available, you are using version 2.21.2.
    Release notes: https://github.com/peripheryapp/periphery/releases/tag/3.6.0
    To disable update checks pass the --disable-update-check option to the scan command.

### cargo-machete Dependency Scan
```bash
cd '/Users/jojo/Epistemos/graph-engine' && cargo machete
```
    Analyzing dependencies of crates in this directory...
    cargo-machete didn't find any unused dependencies in this directory. Good job!
    Done!

### cargo-udeps Nightly Missing
```bash
printf 'cargo-udeps is installed but requires rustup nightly; run: rustup toolchain install nightly\n'
```
    cargo-udeps is installed but requires rustup nightly; run: rustup toolchain install nightly

