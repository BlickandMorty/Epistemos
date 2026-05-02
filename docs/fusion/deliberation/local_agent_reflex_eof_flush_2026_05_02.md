# LocalAgent Reflex EOF Flush Deliberation - 2026-05-02

## Slice

Adopt and verify the LocalAgent reflex streaming EOF fix already present in the
worktree. When reflex streaming ends without a tool-call detection,
`LocalAgentLoop` now drains `IncrementalToolCallDetector.flushOnStreamEnd()` so
safe plaintext held for tag-prefix disambiguation is emitted instead of being
silently dropped.

## Gate

Allowed write set for this slice:

- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/local_agent_reflex_eof_flush_2026_05_02.md`

Forbidden for this slice:

- Model routing, provider calls, tool parsing, tool execution, repair semantics,
  approval policy, UI, Rust, generated bindings, EventStore schema, graph,
  OpLog, GraphEvent, AgentEvent, and Xcode project changes.

## Evidence

- Green: `/tmp/epistemos-local-agent-reflex-eof-flush-green-20260502.log`.
  The focused `LocalAgentLoopTests` Swift Testing suite passed 34 tests. Xcode
  still printed the known vendored CodeEdit SwiftLint package-plugin failures
  after `TEST SUCCEEDED`; those are not acceptance blockers for this slice.

## Decision

Approved as a local-agent streaming correctness fix. It preserves hidden
scratchpad/tool-call privacy semantics because the detector still drops unclosed
hidden tags and malformed tool opens at EOF, while visible plaintext tag-prefix
characters are now delivered exactly once.
