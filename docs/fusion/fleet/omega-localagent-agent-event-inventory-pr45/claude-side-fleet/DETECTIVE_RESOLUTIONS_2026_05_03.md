# Omega + LocalAgent Detective Resolutions — 2026-05-03

> **Purpose.** Resolves the five detective questions (C-1 through C-5) and one verified-gap candidate (Gap-2) opened by `OMEGA_LOCALAGENT_AGENT_EVENT_INVENTORY_2026_05_03.md`. Pure read-only audit — no code edits, no canon-in-flight touches, no `xcodebuild`. Generated as the natural follow-up to round 86's Omega/LocalAgent inventory so Codex can make the next-slice decision without re-research.
>
> Doctrine §7 lane: Core open — broader runtime AgentEvent coverage. Authority: current code + grep > inventory candidate ranking.

---

## Headline

**Of 5 ambiguities + 1 candidate gap, ZERO are real instrumentation gaps. Three are dead code, two are properly out-of-scope, and one (Gap-2 LocalAgent reflex/EOF) is already covered by PR11.** The Bridge AgentEvent layer (PR39–PR44) plus the existing instrumented files in the inventory §1 (LocalAgentLoop, AgentQueryEngine, MCPBridge, iMessageDriver, ReasoningLoop, DriverChannel) are functionally complete for current production paths.

**The next AgentEvent decision is no longer "instrument what?"** It is "**delete dead code**" (4 candidates) or "open a dedicated lane for Omega knowledge memory wiring" — but neither is a Bridge-style provenance slice.

---

## C-1 — Is `Epistemos/Omega/Agents/GhostComputerAgent.swift` reachable in production?

### Verdict: **NO — dead code, superseded by `ComputerUseBridge.swift` (PR39).**

### Evidence

`grep -rn 'GhostComputerAgent(\|GhostComputerAgent\.shared' Epistemos/ --include='*.swift'` returns **zero hits.** The file defines the class but no production code instantiates it.

The same grep for `ComputerUseBridge` returns four hits:

| File:line | Use |
|---|---|
| `Epistemos/AppStore/AppStoreComputerUseStubs.swift:173` | App Store stub `static let shared = ComputerUseBridge()` |
| `Epistemos/Bridge/ComputerUseBridge.swift:26` | Pro/Research definition `static let shared = ComputerUseBridge()` |
| `Epistemos/Bridge/StreamingDelegate.swift:453` | `await ComputerUseBridge.shared.execute(actionJSON: actionJson)` |
| `Epistemos/Bridge/Phase4Bridge.swift:53` | `await ComputerUseBridge.shared.execute(actionJSON: actionJson)` |

The canonical computer-use entrypoint is `ComputerUseBridge.shared`. `GhostComputerAgent` is a parallel implementation that nothing reaches.

### Recommended action

Open a separate **cleanup** slice (not an AgentEvent slice) that deletes `Epistemos/Omega/Agents/GhostComputerAgent.swift`. Allowed write set: that one file. Forbidden: instrument it (would chase a dead path), wire it (would reintroduce the dual-architecture problem PR39 closed).

### Reservation note

Cleanup of `GhostComputerAgent.swift` is the **only** safe action — instrumenting it would be P1 anti-pattern (dead code with provenance is worse than dead code without).

---

## C-2 — Is `AgentGraphMemory.recordExecution` upstream-covered?

### Verdict: **NO — dead code; `recordExecution` has zero call sites.** `distillMemory` has one caller (`NightBrainService.swift:290`) which IS upstream-covered.

### Evidence

`grep -rn 'recordExecution' Epistemos/ --include='*.swift'` returns one hit — the definition itself at `Epistemos/Omega/Knowledge/AgentGraphMemory.swift:44`. Nothing calls it.

`distillMemory` has exactly one caller: `Epistemos/State/NightBrainService.swift:290` (`graphMemory.distillMemory()`). NightBrain is a scheduled background service whose job IS the distillation; this isn't a tool dispatch event, it's a maintenance pass. Per the inventory §3 "knowledge helpers" rationale, it should remain `no-instrument` (it's the work, not a tool the user invoked).

### Recommended action

- For `recordExecution`: same as C-1 — separate cleanup slice to either delete the dead method or wire it to a real call site (TBD by user). Either way, instrumenting dead code is wrong.
- For `distillMemory`: confirmed `no-instrument`. NightBrain's own observability (already present via `Log` calls in NightBrainService) is sufficient.

---

## C-3 — Is `ShadowGitCheckpoint.checkpoint/rollback` user-tool-exposed?

### Verdict: **NO — dead code; `.checkpoint(filePath:)` and `.rollback(filePath:)` have zero call sites in current source.**

### Evidence

`grep -rn 'ShadowGitCheckpoint\|shadow_git\|ShadowGit' Epistemos/ --include='*.swift'` returns only:
- `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` (the file itself — class definition + Logger references)
- The `#endif` comment at line 175 noting the file is gated `#if !EPISTEMOS_APP_STORE` because it spawns `/usr/bin/git`

No production code calls `ShadowGitCheckpoint.shared.checkpoint(...)` or `.rollback(...)`. The file is scaffolding awaiting a wiring site that never landed.

### Recommended action

Two paths the user must choose:

1. **If shadow-git checkpoint is still planned** (likely — `Sovereign Gate Surface Map §4` references rollback as a candidate Sovereign-routed tool): keep the file, open a deliberation for the wiring slice. The wiring would then need its own AgentEvent provenance because `rollback(filePath:)` is a destructive user-facing action.
2. **If shadow-git checkpoint has been deferred indefinitely**: cleanup slice to delete or move to a `docs/fusion/research/parking-lot/` reference doc.

Either way: **no-instrument now.** Instrumenting dead code is wrong.

---

## C-4 — Should `VisualVerifyLoop.verify(...)` emit lifecycle events?

### Verdict: **NO — `verify(...)` has zero callers from the Bridge layer. The instance is constructed in `AppBootstrap.swift:847` but no current production code calls `.verify(...)` on it.**

### Evidence

`grep -rn 'visualVerifyLoop\|\.verify(' Epistemos/Omega/ Epistemos/Bridge/ Epistemos/Engine/` filtered against `AppStoreComputerUseStubs` and the file itself:

- `Epistemos/App/AppBootstrap.swift:822` (comment), 844 (`private var _visualVerifyLoop: VisualVerifyLoop?`), 845 (`var visualVerifyLoop: VisualVerifyLoop`), 847 (lazy construction), 1658 (comment).
- `Epistemos/Omega/Vision/AXMutationDetector.swift:11` (comment: "intentionally cheaper than `VisualVerifyLoop`").

That's it. The lazy var exists; nothing reads it; nothing calls `.verify()`. The visual-verify subsystem is wired into AppBootstrap but unconsumed.

### Recommended action

- **No-instrument until a caller wires `.verify(...)`.** If/when ComputerUseBridge or Phase4Bridge or a future `ComputerUseAgent` calls it, instrument at the wiring site, not inside `VisualVerifyLoop` itself (per the coverage-map §4 "internal helper" rationale).
- Optional: add a parallel-work item to **either** wire the verify loop into `ComputerUseBridge.execute(actionJSON:)` to close the post-action verification gap **or** delete the lazy var to remove the unused init from AppBootstrap. The user's call.

---

## C-5 — Are there reasoning rounds in `ReasoningLoopService.swift` that bypass PR7 instrumentation?

### Verdict: **DEFERRED — needs a deeper code read of every `return` from `runRound`. Inventory rated this as "low likelihood" of a gap; resolving it requires reading ~600 lines of ReasoningLoopService and tracing 4-6 return paths.**

### Why deferred

The inventory ambiguity came from the file's size (`ReasoningLoopService.swift` is ~600 lines and has multiple `return` paths in `runRound`/early-exit flows). Doing this audit thoroughly requires reading every branch. PR7 closed the canonical instrumentation; the open question is only whether early-exit branches drop the trailing `completed` event.

### Recommended action

- **Open as its own audit slice** if Codex hits a missing-completion event in production logs (red-flag signal: `requested` rows without paired `completed` for ReasoningLoop run IDs).
- Until then: defer. Symptom-driven, not speculative.

---

## Gap-2 — LocalAgent reflex/EOF flush completion path

### Verdict: **NOT A GAP — the EOF flush at `LocalAgentLoop.swift:587-592` is a TEXT stream completion, not a tool event. PR11's `recordToolEvent` at line 1084 fires from `executeToolCall`, which is reached from the tool-detection branch (line 596+), not the EOF-flush branch.**

### Evidence

Reading `runReflexTurn` lines 519-640:

```swift
// Line 587-592: EOF flush (no tool detected — purely text completion)
if reflexDetection == nil {
    let flushed = detector.flushOnStreamEnd()
    if !flushed.isEmpty {
        await onToken(flushed)
    }
}

// Line 596+: tool-call branch (this is what PR11 covers)
if let detection = reflexDetection {
    // ... canonicalize, repair-check, executeToolCall ...
    let result = await executeToolCall(toolCall, runID: runID)  // → emits recordToolEvent at line 1084
}
```

The two branches are **mutually exclusive**:
- `reflexDetection == nil` → no tool was ever requested → no AgentEvent expected (correct).
- `reflexDetection != nil` → tool path runs `executeToolCall` → emits per PR11 (correct).

The original ambiguity was a hedge from the inventory; the actual code is correct.

### Recommended action

**No code change needed. No new slice.** PR11 + the existing reflex flow are complete. Update the PR42 delta map's §3.3 to remove this candidate (it was speculative, not real).

---

## Cleanup queue surfaced by this resolution

These four candidates are all "delete or wire, never instrument as-is":

| # | File | Action | Effort | Why now |
|---|---|---|---|---|
| 1 | `Epistemos/Omega/Agents/GhostComputerAgent.swift` | Delete (superseded by ComputerUseBridge PR39) | S | Avoids future agents re-discovering it as a "gap" |
| 2 | `AgentGraphMemory.recordExecution` (lines 44-120) | Delete or wire to a real caller | S | Method is unreachable; deleting clarifies the surface |
| 3 | `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` | Wire to rollback tool OR delete | S–M | Currently scaffolding; user decides path |
| 4 | `VisualVerifyLoop` lazy var in `AppBootstrap.swift:844-847` | Wire `.verify(...)` into ComputerUseBridge OR delete the lazy var | S–M | Currently constructed-but-unused |

Each is **its own cleanup slice**. None blocks Codex's next AgentEvent or Sovereign Gate work. Each is parallel-safe with whatever Codex is reserving.

---

## Reservation respect

This audit was generated without editing any of:

- `Epistemos/Bridge/ClarifyPromptBridge.swift` (Codex round-86 reservation, if still in flight)
- All currently instrumented files (`MCPBridge.swift`, `iMessageDriverService.swift`, `ReasoningLoopService.swift`, `DriverChannelControlPlane.swift`, `LocalAgentLoop.swift`, `AgentQueryEngine.swift`)
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- The original inventory `OMEGA_LOCALAGENT_AGENT_EVENT_INVENTORY_2026_05_03.md` (read-only source)
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.

## Usefulness

usefulness: +1
usefulness_reason: Resolves 5 of 5 detective questions + 1 candidate gap from the prior round's inventory with definitive verdicts (4 dead-code, 1 already-correct, 1 deferred). Surfaces a 4-item cleanup queue with effort estimates so the user can pick what to delete/wire next.
