# Epistemos Agent Deep Verification Manual

Date: 2026-03-29
Status: Canonical deep-verification, runtime-audit, and release-readiness handoff for agent work

## Purpose

This is the single operator manual for deeply verifying Epistemos agent work.

Use it when you need more than "tests pass."
Use it when you need to know:

- whether the runtime is truly wired correctly
- whether routing and fallbacks are honest
- whether UI behavior matches logs
- whether computer-use actions actually worked
- whether note and vault integrity survived real use
- whether there are crashes, silent failures, race conditions, or fake-success paths
- whether the branch is actually safe to hand off, merge, or release

h
This manual combines:

- the repo's `Epistemos Release Audit` skill
- the repo's `Recursive App Audit` skill
- the current `AGENT_TEST_PLAN.md`
- the current `AGENT_BENCHMARKS.md`
- the repo's scripted verification tools
- manual runtime and screenshot-driven verification

## Non-Negotiable Rules

1. Do not trust prior green claims.
2. Do not trust screenshots alone.
3. Do not trust logs alone.
4. Do not trust a single passing run.
5. A behavior is verified only when code, logs, runtime behavior, and persisted results all agree.
6. If a bug is fixed during the audit, reset the recursive pass counter to `0`.
7. No `READY` verdict without 3 uninterrupted zero-fail passes.
8. Unsupported modes must disappear, not merely fail after selection.
9. Computer-use success must be verified through both semantic state and visible outcome.
10. If the app "looks fine" but logs show fallback, cancellation, permission denial, decode failure, or hidden retry loops, the test is not a pass.

## Skills To Invoke

If the auditing agent supports repo skills, explicitly use both:

- `Epistemos Release Audit`
- `Recursive App Audit`

The release-audit skill establishes the evidence standard.
The recursive-audit skill establishes the 3-pass zero-fail loop.

## Current Repo Read Order

Read these before auditing:

1. `CLAUDE.md`
2. `docs/AGENT_PROGRESS.md`
3. `docs/HERMES_INTEGRATION_RESEARCH.md`
4. `AGENT_REPLACEMENT_PLAN.md`
5. `AGENT_RUNTIME_ARCHITECTURE.md`
6. `AGENT_MIGRATION_MATRIX.md`
7. `AGENT_TEST_PLAN.md`
8. `AGENT_BENCHMARKS.md`
9. `docs/agent-system/AGENT_ARCHITECTURE.md`
10. `docs/PROGRESS.md`
11. `docs/sprint-sessions/sprint-agent-3-mcp.md`

Then read the live code seams:

### Rust runtime and bridge

- `agent_core/src/agent_loop.rs`
- `agent_core/src/providers/claude.rs`
- `agent_core/src/bridge.rs`
- `agent_core/src/routing.rs`
- `agent_core/src/storage/vault.rs`

### MCP and computer use

- `omega-mcp/src/dispatcher.rs`
- `omega-mcp/src/catalog.rs`
- `omega-mcp/src/vault.rs`
- `omega-ax/src/ax_tree.rs`
- `omega-ax/src/input.rs`

### Swift app and local agent

- `Epistemos/Omega/MCPBridge.swift`
- `Epistemos/Omega/Inference/DeviceAgentService.swift`
- `Epistemos/Omega/Vision/VisualVerifyLoop.swift`
- `Epistemos/Omega/Inference/DualBrainRouter.swift`
- `Epistemos/Omega/Inference/ConstrainedDecodingService.swift`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `Epistemos/LocalAgent/LocalToolGrammar.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/LocalAgent/ConfidenceRouter.swift`
- `Epistemos/ViewModels/AgentViewModel.swift`
- `Epistemos/Views/Omega/OmegaPanel.swift`
- `Epistemos/Views/OmegaPanel.swift`

### Hermes internals

- `hermes-agent/run_agent.py`
- `hermes-agent/agent/context_compressor.py`
- `hermes-agent/agent/prompt_builder.py`
- `hermes-agent/agent/prompt_caching.py`
- `hermes-agent/agent/smart_model_routing.py`
- `hermes-agent/agent/anthropic_adapter.py`
- `hermes-agent/tools/mcp_tool.py`
- `hermes-agent/tools/approval.py`
- `hermes-agent/tools/skills_guard.py`
- `hermes-agent/agent/redact.py`
- `hermes-agent/gateway/session.py`
- `hermes-agent/hermes_state.py`
- `hermes-agent/cron/scheduler.py`

### Focused Swift test surfaces

- `EpistemosTests/HermesPromptBuilderTests.swift`
- `EpistemosTests/LocalToolGrammarTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `EpistemosTests/ConfidenceRouterTests.swift`
- `EpistemosTests/DeviceAgentServiceTests.swift`
- `EpistemosTests/VisualVerifyLoopTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/ResearchModeTests.swift`
- `EpistemosTests/OmegaAgentTests.swift`
- `EpistemosTests/TriageServiceTests.swift`
- `EpistemosTests/NoteChatStateTests.swift`
- `EpistemosTests/NoteFileStorageTests.swift`
- `EpistemosTests/MappedNoteBodyTests.swift`
- `EpistemosTests/VaultIndexActorTests.swift`

### Audit scripts

- `scripts/audit/verify.sh`
- `scripts/audit/release_preflight.sh`
- `scripts/audit/watch_runtime_signals.sh`
- `scripts/audit/native_cleanup_scan.sh`

## Evidence Standard

Every verification pass must produce durable evidence in four buckets:

1. Automated output
   - build logs
   - test logs
   - script output
2. Runtime/log output
   - app logs
   - runtime diagnostics
   - crash logs if any
3. Manual/runtime evidence
   - screenshots before and after critical actions
   - notes on visible behavior
   - permission-prompt outcomes
4. Auditor judgment
   - code-level reasoning
   - risk classification
   - explicit pass/fail verdict per surface

Recommended artifact layout:

```text
docs/audits/
  YYYY-MM-DD-agent-pass-1.md
  YYYY-MM-DD-agent-pass-2.md
  YYYY-MM-DD-agent-pass-3.md
  artifacts/YYYY-MM-DD/
    pass-1/
      screenshots/
      logs/
    pass-2/
      screenshots/
      logs/
    pass-3/
      screenshots/
      logs/
```

## The Recursive Audit Loop

### Pass 0: Orientation

Before running any audit pass:

- inspect branch, commit, and worktree status
- note whether the task is:
  - runtime regression audit
  - feature verification
  - release-readiness audit
  - Hermes-integration audit
  - computer-use audit
- note whether the branch includes new agent work, new UI work, or new transport/process work
- identify which legacy claims may now be stale

### Pass 1: Full verification

Run all required automated checks.
Perform code audit.
Perform manual/runtime checks.
Record failures.

### Pass 2: Determinism check

Re-run the same evidence chain without code changes.
Look for:

- flaky tests
- timing-dependent failures
- transient permission issues
- intermittent routing drift
- non-deterministic UI state

### Pass 3: Solidification

Re-run the critical path one more time.
Only after 3 clean passes with no code changes between them can the branch be called stable.

### Reset rule

If any issue is fixed, or if any new issue is found, reset the pass counter to `0`.

## Automated Verification Ladder

Start with the scripts that capture the broadest repo truth.

### 1. Repo preflight

```bash
./scripts/audit/release_preflight.sh
```

### 2. Strict verification script

```bash
./scripts/audit/verify.sh --fix-format
```

This script already checks:

- legacy ban gates
- native cleanup scan
- Rust formatting and clippy
- graph-engine tests
- strict-concurrency Swift build
- targeted runtime validation

### 3. Full app build and tests

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cargo test --manifest-path graph-engine/Cargo.toml
cargo test --manifest-path omega-mcp/Cargo.toml
cargo test --manifest-path omega-ax/Cargo.toml
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path epistemos-core/Cargo.toml
```

### 4. Focused agent and runtime suites

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test \
  -only-testing:EpistemosTests/HermesPromptBuilderTests \
  -only-testing:EpistemosTests/LocalToolGrammarTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests \
  -only-testing:EpistemosTests/ConfidenceRouterTests \
  -only-testing:EpistemosTests/DeviceAgentServiceTests \
  -only-testing:EpistemosTests/VisualVerifyLoopTests \
  -only-testing:EpistemosTests/RuntimeValidationTests \
  -only-testing:EpistemosTests/ResearchModeTests \
  -only-testing:EpistemosTests/OmegaAgentTests \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/NoteChatStateTests \
  -only-testing:EpistemosTests/NoteFileStorageTests \
  -only-testing:EpistemosTests/MappedNoteBodyTests \
  -only-testing:EpistemosTests/VaultIndexActorTests
```

### 5. Sanitizer passes when doing true release or crash-hardening work

```bash
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableAddressSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableThreadSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableUndefinedBehaviorSanitizer YES
```

### 6. Runtime signal watcher

Run this before manual app testing:

```bash
./scripts/audit/watch_runtime_signals.sh
```

This gives live evidence for:

- session lifecycle
- warnings/errors/faults
- runtime diagnostics snapshots
- unified logs from subsystem `com.epistemos`

## Code Audit Sweep

Passing tests are the start, not the end.

### Crash safety

Search for:

- `try!`
- force unwraps
- reachable `fatalError`
- unsafe FFI without guards
- `Int(Float.nan)` or unguarded non-finite conversion paths

### Concurrency safety

Audit for:

- correct `@MainActor @Observable` ownership
- background work not mutating UI state directly
- cancellation support on long-lived tasks
- sendability and actor hops
- tool or stream tasks that can outlive the session incorrectly

### Routing honesty

Verify:

- local/cloud decisions are explainable from current code
- unsupported modes are hidden
- fallback paths do not silently degrade without surfacing it
- the provider actually selected matches the logs

### Runtime ownership

Verify:

- Rust owns the living loop where intended
- Swift is not secretly orchestrating work that docs claim Rust owns
- Omega shim paths are accurately classified as transitional if still present

### Tooling and MCP truth

Verify:

- tool catalog lives where the code claims it lives
- Swift is not maintaining a shadow copy of tool truth unless explicitly intended
- vault, AX, input, and browser tools are actually wired to executable code
- destructive paths still gate approval

### Persistence truth

Verify:

- session artifacts persist when claimed
- vault writes actually reach disk
- note AI accept/discard produces correct saved state
- reload/open flows reflect saved truth, not in-memory illusion

## Runtime Logging Protocol

Always correlate UI behavior with logs.

While the app is open:

1. keep `watch_runtime_signals.sh` running
2. keep a terminal ready for targeted grep over the runtime diagnostics
3. record timestamps for each manual test step
4. if something visually succeeds, confirm logs do not show:
   - permission denial
   - retry storm
   - fallback to another provider
   - cancellation
   - decode failure
   - silent parse failure

If the app is launched from Xcode, also retain the debug console output as evidence.

## Screenshot and Computer-Use Verification Protocol

This is mandatory for UI actions, computer-use actions, and permission-driven behavior.

### Rules

1. Capture a before screenshot.
2. Capture the relevant AX snapshot or semantic state if available.
3. Perform the action.
4. Capture the after screenshot.
5. Capture the post-action AX snapshot or semantic state.
6. Confirm logs match the observed result.
7. Record whether the action changed the intended target only.

### If using Claude computer use

If Claude can operate the app via computer-use tools, require it to record for each step:

- the target surface
- the intended action
- the actual action performed
- the before screenshot
- the after screenshot
- the logs observed during the action
- whether AX and screenshot verification agreed

Computer-use does not remove the need for manual review.
It only helps execute and document the flow.

### If using shell-based screenshots

Example capture flow:

```bash
mkdir -p docs/audits/artifacts/$(date +%F)/pass-1/screenshots
screencapture -x docs/audits/artifacts/$(date +%F)/pass-1/screenshots/01-before.png
screencapture -x docs/audits/artifacts/$(date +%F)/pass-1/screenshots/01-after.png
```

### Action-verification rule

A UI action is only a pass when all four agree:

- intended action
- visible screenshot result
- AX or semantic state result
- runtime logs

## Manual Runtime Verification Matrix

Use a disposable test vault for destructive note or training checks.

### 1. Launch and boot stability

Do:

- cold-launch the app 3 times
- quit and relaunch from a built `.app`
- open from Xcode and from Finder if possible

Verify:

- no crash on boot
- no missing dylib or asset failures
- expected boot logs appear
- runtime diagnostics initialize cleanly

Evidence:

- launch screenshots
- boot logs
- any crash reports

### 2. Model and mode wiring

Do:

- inspect visible model list
- switch between supported local models
- verify `Fast`, `Thinking`, `Agent`, and `Research` affordances

Verify:

- unsupported modes are hidden
- supported modes are selectable
- routing logs match the chosen mode
- no blank-output path on thinking-capable models

Evidence:

- screenshots of each model/mode surface
- logs showing route/model selection

### 3. Local inference path

Do:

- send a simple prompt in `Fast`
- send a reasoning prompt in `Thinking` where supported
- cancel a running generation
- quickly submit another prompt after cancellation

Verify:

- first token arrives promptly
- no fake buffered streaming
- cancellation really cancels
- follow-up prompt is not contaminated by the previous run

Evidence:

- screenshots during stream
- logs for start/stop/cancel
- persisted transcript if applicable

### 4. Research and Omega entry points

Do:

- trigger research from the UI button
- trigger research using `/research ...`
- verify Omega panel visibility
- verify planning and execution steps render

Verify:

- research handoff does not disappear into plain chat
- Omega panel actually appears
- planning state is visible
- execution updates are visible and useful

Evidence:

- before/after screenshots
- logs showing research route
- visible step rendering

### 5. MCP and tool execution

Do:

- list tools if the surface allows it
- execute safe read-only tools first
- execute one permission-gated path
- verify tool results are surfaced correctly

Verify:

- tool schemas and catalog agree with code expectations
- read-only tools can run without hidden failures
- destructive or sensitive tools request approval
- results are bounded and intelligible

Evidence:

- tool-call screenshots
- logs for tool start/result/failure
- any saved output or transcript evidence

### 6. Computer use: AX, click, type, key, fallback

Do:

- query AX tree
- resolve one semantic target
- click it
- type into a field
- issue one key action
- trigger fallback verification if applicable

Verify:

- AX query returns stable structure
- action hits intended target
- post-action verification prefers AX/semantic truth
- screenshot fallback is used only when needed
- uncertain actions stay gateable

Evidence:

- before/after screenshots
- AX snapshots or action metadata
- verification logs

### 7. Note AI integrity

Do:

- start a note AI stream
- accept the response
- repeat and discard the response
- close and reopen the note
- switch notes mid-session if relevant

Verify:

- divider protection holds
- accept strips the divider and preserves intended text
- discard removes the AI region cleanly
- reopen shows correct persisted state
- no orphaned divider or stale inline artifact remains

Evidence:

- note screenshots before and after
- saved file content if needed
- logs showing stream and cleanup

### 8. Vault and file integrity

Do:

- read a note
- edit a note
- reopen it from disk-backed state
- test a Unicode or UTF-16 note if corruption is in scope

Verify:

- file reads are correct
- writes persist
- no gibberish false-corruption presentation
- vault index/search reflects the updated note

Evidence:

- note file excerpts
- logs for read/write/index
- screenshots of reopened content

### 9. Session persistence and recovery

Do:

- complete a short agent session
- stop or cancel a session mid-flight
- relaunch the app if session persistence exists

Verify:

- transcript persists when expected
- cancellation does not masquerade as completion
- reload uses durable state, not just in-memory UI

Evidence:

- persisted session artifacts
- logs for session lifecycle
- reopen screenshots

### 10. Permissions and approval UX

Do:

- trigger Accessibility-related flow
- trigger screen-recording-related flow if needed
- trigger Apple Events or browser automation flow if applicable

Verify:

- prompts are understandable
- denial is handled honestly
- approval-required actions do not run silently when denied

Evidence:

- screenshots of permission UI
- logs for denied/granted outcomes

### 11. Settings honesty

Do:

- inspect model/mode descriptions
- inspect advanced/experimental labels
- inspect automation/research/agent descriptions

Verify:

- no overclaiming
- experimental surfaces are labeled
- unsupported capabilities are not marketed as real

Evidence:

- settings screenshots
- references to exact UI copy

### 12. Packaging and release readiness

Do this for final release work:

- run `release_preflight.sh`
- verify codesign on built artifact
- inspect bundle contents
- confirm privacy and distribution files exist

Verify:

- required dylibs exist
- required resources exist
- no unexpected plug-ins
- entitlements and privacy files are present

Evidence:

- preflight output
- bundle inspection output
- codesign verification output

### 13. Hermes integration checks when implemented

If the branch includes Hermes integration, additionally verify:

- MLX HTTP shim responds on the expected local endpoint
- Hermes subprocess starts and stays healthy
- Hermes restart-on-crash behavior works
- MCP initialize handshake succeeds
- Swift can list and call Hermes tools
- Hermes can call back into Epistemos MCP servers
- offline fallback to local or Rust fallback loop is honest

Do:

- start Hermes path
- list tools
- run one harmless tool through Hermes
- simulate Hermes unhealthy state
- confirm fallback route changes

Verify:

- no inference sidecar violations for local inference
- subprocess orchestration does not block the main thread
- fallback route is visible in logs and behavior

Evidence:

- subprocess logs
- MCP handshake output
- before/after screenshots of route behavior

## Stress and Chaos Checks

Run these on any branch that changes runtime, routing, or persistence.

### Interaction stress

- rapid send/cancel cycles
- repeated Omega open/close
- repeated mode switching
- multiple research triggers in a short span

### Persistence stress

- repeated note edits during AI activity
- accept/discard sequences back-to-back
- close/reopen after each save

### Permission stress

- deny, retry, then grant
- revoke a permission and re-test the surface

### Failure-path stress

- bad network or offline cloud route if relevant
- unavailable model
- unavailable tool target
- malformed or empty tool output

### Computer-use stress

- action on a moving target
- action on ambiguous AX target
- screenshot fallback when AX confidence is low

## Performance Verification

Use `AGENT_BENCHMARKS.md` as the source of truth for target numbers.

At minimum, measure and record:

- first streaming event latency
- tool-use round-trip time
- session reload time
- AX query latency
- action + verification latency
- screenshot fallback latency
- provider fallback decision latency

If no benchmark harness exists for a surface, record manual timing plus logs and clearly label it as provisional evidence.

## Failure Classification

Every issue found during audit must be classified:

- `Release blocker`
- `Runtime correctness bug`
- `Data integrity risk`
- `Crash risk`
- `Misleading UI / overclaim`
- `Performance regression`
- `Documentation drift`
- `Non-blocking follow-up`

For each issue record:

- exact surface
- steps to reproduce
- logs observed
- whether it reproduces deterministically
- root cause if known
- fix status

## Exit Criteria

The branch is only deeply verified when:

1. required automated checks pass
2. code audit finds no unaddressed critical structural flaw
3. manual/runtime matrix has been executed on relevant surfaces
4. screenshots and logs support the claims
5. 3 uninterrupted passes complete with no code changes between them
6. the final report honestly distinguishes:
   - verified
   - inferred
   - not yet tested

## Final Report Format

Every final audit report should contain:

1. Branch and commit audited
2. Worktree state
3. Commands run
4. Scripts run
5. Focused tests run
6. Manual tests run
7. Log-derived findings
8. Screenshot evidence summary
9. Bugs fixed during audit
10. Remaining blockers
11. Benchmark notes
12. Final verdict

Allowed verdicts:

- `READY FOR FURTHER RESEARCH HANDOFF`
- `READY FOR IMPLEMENTATION`
- `READY FOR DIRECT RELEASE`
- `READY FOR DIRECT RELEASE, MAS LITE ONLY`
- `NOT READY`

## Copy-Paste Prompt For Claude

Use the prompt below when you want Claude to perform the full deep verification pass.

```text
You are performing the deepest possible verification audit for Epistemos.

Read and follow these files first, in order:
1. /Users/jojo/Downloads/Epistemos/CLAUDE.md
2. /Users/jojo/Downloads/Epistemos/docs/AGENT_DEEP_VERIFICATION_MANUAL.md
3. /Users/jojo/Downloads/Epistemos/docs/AGENT_PROGRESS.md
4. /Users/jojo/Downloads/Epistemos/docs/HERMES_INTEGRATION_RESEARCH.md
5. /Users/jojo/Downloads/Epistemos/AGENT_REPLACEMENT_PLAN.md
6. /Users/jojo/Downloads/Epistemos/AGENT_RUNTIME_ARCHITECTURE.md
7. /Users/jojo/Downloads/Epistemos/AGENT_MIGRATION_MATRIX.md
8. /Users/jojo/Downloads/Epistemos/AGENT_TEST_PLAN.md
9. /Users/jojo/Downloads/Epistemos/AGENT_BENCHMARKS.md
10. /Users/jojo/Downloads/Epistemos/docs/agent-system/AGENT_ARCHITECTURE.md

If repo skills are available, use both:
- Epistemos Release Audit
- Recursive App Audit

Non-negotiable requirements:
- Do not trust prior green claims.
- Logs are mandatory evidence.
- Screenshots are mandatory for manual/runtime/UI verification.
- If using computer use, capture before and after screenshots and correlate them with logs.
- Unsupported modes must disappear, not merely fail.
- A visible success with contradictory logs is a failed verification.
- If any issue is fixed, reset the recursive pass counter to 0.
- No readiness verdict without 3 uninterrupted zero-fail passes.

Run this verification ladder:
1. ./scripts/audit/release_preflight.sh
2. ./scripts/audit/verify.sh --fix-format
3. Full build/test:
   - xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
   - xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
   - cargo test --manifest-path graph-engine/Cargo.toml
   - cargo test --manifest-path omega-mcp/Cargo.toml
   - cargo test --manifest-path omega-ax/Cargo.toml
   - cargo test --manifest-path agent_core/Cargo.toml
   - cargo test --manifest-path epistemos-core/Cargo.toml
4. Focused agent/runtime tests from AGENT_DEEP_VERIFICATION_MANUAL.md
5. Sanitizer passes if this is release or crash-hardening work
6. ./scripts/audit/watch_runtime_signals.sh before manual testing

Then perform a deep code audit and a full manual/runtime verification pass across:
- launch and boot
- model and mode wiring
- local inference
- research and Omega entry points
- MCP and tool execution
- computer use
- note AI integrity
- vault and file integrity
- session persistence and recovery
- permissions and approval UX
- settings honesty
- packaging and release readiness
- Hermes integration checks when present

For computer-use verification:
- capture a before screenshot
- capture semantic or AX state if available
- perform the action
- capture an after screenshot
- capture post-action semantic or AX state
- verify logs match the visible result

Your report must include:
- exact commands run
- exact tests run
- exact manual checks run
- log-derived findings
- screenshot-evidence summary
- any bugs fixed during the audit
- whether pass 1, pass 2, and pass 3 were clean
- final verdict

Allowed verdicts only:
- READY FOR FURTHER RESEARCH HANDOFF
- READY FOR IMPLEMENTATION
- READY FOR DIRECT RELEASE
- READY FOR DIRECT RELEASE, MAS LITE ONLY
- NOT READY

Be ruthless, honest, and evidence-driven.
```
