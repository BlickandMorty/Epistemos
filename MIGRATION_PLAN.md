# Migration Plan

## Phase 1

- keep BTK as default
- keep knowledge-core behind `epistemos.knowledgeCore.shadow`
- feed representative note/query workloads into shadow mode

## Phase 2

- add parity harnesses:
  - outline rows
  - task rows
  - property rows
  - link rows

## Phase 3

- eliminate repeated payload validation / row-level FFI chatter
- add real query and parser benchmarks
- add fuzz coverage for ring and archived payloads

## Phase 4

- integrate staged diffs into non-authoritative UI models behind a feature flag
- compare latency, allocation, and correctness against live runtime

## Cutover condition

Only consider replacement when:

- feature parity is proven
- end-to-end latency beats BTK path
- failure observability is improved
- no-go risks in the register are retired
