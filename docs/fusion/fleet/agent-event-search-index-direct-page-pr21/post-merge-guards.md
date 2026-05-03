# Post-Merge Guards — agent-event-search-index-direct-page-pr21

- grep: `toolName: "search_index.search"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `toolName: "search_index.search_async"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `directPageSearchMetadata(surface: "search"` in `Epistemos/Sync/SearchIndexService.swift`
- grep: `directPageSearchMetadata(surface: "search_async"` in `Epistemos/Sync/SearchIndexService.swift`
- forbidden grep: `search_index.search_blocks|search_index.search_blocks_async` in `Epistemos/Sync/SearchIndexService.swift`
- forbidden direct-sync grep: `AgentToolProvenanceRecorder|Task \{|Task\.detached|DispatchQueue\.main\.sync|MainActor\.assumeIsolated|search_index\.search_async`
- log: `✔ Test "fusedSearch provenance surfaces stay bounded" passed`
- log: `✔ Suite "SearchIndexService AgentEvent source guards" passed`
- test: `SearchIndexServiceAgentEventSourceGuardTests`

Verification log:

- `/tmp/epistemos-agent-event-search-index-page-pr21-green-pipefail-20260503.log`

Notes:

- Xcode exited `0` under `pipefail` and printed `** TEST SUCCEEDED **`.
- The runtime RRF Fusion tests compile but remain skipped on this host behind
  the suite's pre-existing FTS5 availability gate.
