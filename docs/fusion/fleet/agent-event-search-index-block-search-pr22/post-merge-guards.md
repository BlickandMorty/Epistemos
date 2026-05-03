# Post-Merge Guards — agent-event-search-index-block-search-pr22

- grep: `rg -n 'search_index\.search_blocks|search_index\.search_blocks_async|recordBlockSearch' Epistemos/Sync/SearchIndexService.swift EpistemosTests/SearchIndexServiceFusionTests.swift`
- log: `/tmp/epistemos-agent-event-search-index-block-pr22-green-pipefail-20260503.log` contains `** TEST SUCCEEDED **`
- test: `EpistemosTests/SearchIndexServiceFusionTests` and `EpistemosTests/SearchIndexServiceAgentEventSourceGuardTests`
