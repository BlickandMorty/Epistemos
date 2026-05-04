# Epistemos Agent Test Plan

Date: 2026-03-29
Status: Target test plan for the replacement runtime

Companion operator manual:
- `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` is the canonical runtime-audit, manual-testing, screenshot-evidence, and recursive 3-pass verification workflow.

## Test Levels

### Rust unit tests

- provider streaming parsers
- provider request blueprint generation
- tool registry validation
- policy gate decisions
- transcript append and replay
- summary and bounded-result logic
- memory search selection
- subagent scope enforcement

### Rust integration tests

- multi-turn tool loop continuity
- parallel tool execution
- provider fallback
- session reload
- subagent orchestration

### Swift integration tests

- `AsyncStream` event bridging
- approval UI handoff
- computer-use bridge behavior
- screenshot verification path

### End-to-end tests

- orchestrator + memory + tool + transcript
- orchestrator + subagent + provider routing
- orchestrator + computer-use + verification + approval

## Required Test Cases

1. Agent loop continuity across multiple tool turns
   - assistant thinking/tool blocks survive into the next turn

2. Thinking/text/tool event streaming
   - first events arrive before completion
   - no buffered “fake streaming”

3. Independent tool calls run in parallel
   - total wall time proves fan-out, not serial execution

4. Tool-result bounding
   - oversized results are truncated/summarized before reinjection

5. Transcript persistence to disk
   - JSONL lines written after each message/tool-result turn

6. Session reload
   - runtime rebuilds session state from JSONL + summary

7. Memory search call path
   - runtime can invoke memory search as a first-class tool

8. Provider routing selection
   - Claude selected for orchestration tasks
   - Perplexity selected for current-info grounding
   - local path selected for private/offline work

9. Fallback behavior on provider failure
   - provider error promotes a controlled fallback or surfaced failure

10. Real API request blueprint generation
   - Claude request targets the Messages API and carries thinking/MCP fields
   - Perplexity request targets the Agent API
   - OpenAI request targets the Responses API

11. Local vs remote MCP handling
   - local stdio MCP stays host-managed
   - remote HTTP/SSE MCP is the only class attached to remote-provider requests

12. Subagent scope isolation
   - researcher cannot write
   - critic cannot mutate
   - computer tools are not exposed to unrelated roles

13. AX query behavior
   - tree retrieval returns stable structured output

14. AX action behavior
   - semantic click/type path resolves intended target

15. CGEvent execution path correctness
   - event posting succeeds on the supported host path

16. Screenshot verification path
   - fallback verification can detect state change or non-change

17. Destructive action approval gate
   - destructive tools cannot auto-run without explicit approval

18. End-to-end orchestration task
   - objective
   - memory lookup
   - tool use
   - bounded tool result
   - transcript persisted
   - final response emitted

## Current Gaps To Close

- no real test for provider tool-loop continuity beyond the scaffold runtime
- no true parallel tool execution test in the live runtime
- no session reload implementation test yet
- no real subagent tests because subagents do not exist yet
- no end-to-end Rust-owned computer-use orchestration tests yet

## Acceptance Rule

The replacement cannot be called complete until every required case above exists and passes against the new runtime, not against Omega shims.
