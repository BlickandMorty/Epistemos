# Epistemos Agent Benchmarks

Date: 2026-03-29
Status: Benchmark targets for the replacement runtime

## Core Targets

| Metric | Target |
|---|---|
| First streaming event latency | `< 500ms` local, `< 900ms` cloud |
| Transcript append latency | `< 10ms` per JSONL write |
| Memory search latency | `< 20ms` for hot-path vault retrieval |
| Provider request build latency | `< 5ms` p50 for local request assembly |
| Parallel tool fan-out gain | better than serial baseline by `>= 30%` on 3 independent tools |
| Session reload latency | `< 150ms` for normal recent sessions |
| Summary/compaction latency | `< 1.5s` cloud, `< 300ms` local summary path |
| AX tree query | `< 50ms` p50, `< 150ms` p95 |
| AX action + verification | `< 250ms` p50 for semantic actions |
| Screenshot fallback cycle | `< 2.0s` p50 |
| Provider fallback decision | `< 100ms` once failure is known |

## Benchmark Buckets

### Runtime

- session creation
- transcript write throughput
- event fan-out latency
- tool result bounding cost

### Provider

- request build latency
- first token latency
- full-turn latency
- tool-use round-trip latency
- fallback recovery latency

### Memory

- summary generation time
- memory search latency
- resume-from-session latency

### Computer Use

- AX query latency
- click/type latency
- verification latency
- screenshot fallback latency

## Measurement Plan

- add Rust microbench harnesses for session store, tool registry, and memory store
- add integration timing tests around provider/tool loops
- add Swift instrumentation for UI event arrival time
- add computer-use timing logs for query, action, verify, and fallback paths

## Reporting Format

Each benchmark run should emit:

- timestamp
- git commit
- machine profile
- benchmark name
- p50
- p95
- max
- sample count

The benchmark output should be append-only and auditable.

## Current State

The current codebase does not yet have a benchmark suite that proves a Rust-owned agent runtime.
Existing timings are scattered across unrelated services and are not sufficient for a ship claim.
