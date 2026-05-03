# AgentEvent Runtime Coverage Map — PR42 Delta — 2026-05-03

> **Purpose.** Delta against `AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md`. Marks the five bridge slices Codex closed in PR39–PR43, then re-ranks the remaining safe slices. The original map is **not edited** — read it for full per-file rationale; read this delta for what changed.
>
> Doctrine §7 lane: Core open — broader runtime AgentEvent coverage. Generated per `PARALLEL_WORK_MANIFEST.md` round-82 P1.

---

## 1. What changed since 2026-05-03T15:33Z

Codex closed five bridge slices between rounds 75 and 83. All five match the slice plan in §3 of the original map.

| Slice from original §3 | Closed by | Commit | Bridge file | Test file |
|---|---|---|---|---|
| **CUB-1** ComputerUseBridge AgentEvent provenance | PR39 | `92b40126` Record ComputerUseBridge AgentEvents | `Epistemos/Bridge/ComputerUseBridge.swift` (+381) | `EpistemosTests/ComputerUseBridgeAgentEventTests.swift` (+212) |
| **P4-PERCEIVE** Phase4Bridge.perceive AgentEvent provenance | PR40 | `f41efb05` Record Phase4 perceive AgentEvents | `Epistemos/Bridge/Phase4Bridge.swift` (+171) | `EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift` (+161) |
| **P4-INTERACT** Phase4Bridge.interact AgentEvent provenance | PR41 | `3c9ee48f` Record Phase4 interact AgentEvents | `Epistemos/Bridge/Phase4Bridge.swift` (+462) | `EpistemosTests/Phase4BridgeInteractAgentEventTests.swift` (+191) |
| **P4-WATCH** Phase4Bridge.screen_watch AgentEvent provenance | PR42 | `29717395` Record Phase4 screen watch AgentEvents | `Epistemos/Bridge/Phase4Bridge.swift` (+288) | `EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift` (+158) |
| **CPB-1** ClarifyPromptBridge AgentEvent provenance | PR43 | `d6f8908b` Record ClarifyPromptBridge AgentEvents | `Epistemos/Bridge/ClarifyPromptBridge.swift` | `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift` |

Each PR also updated `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `AGENT_BUILD_WORKCARDS_2026_05_01.md`, and added a deliberation file + per-slice fleet folder + oversight POST_MERGE_GUARDS row + PREFLIGHT row. All canonical follow-through is in place.

---

## 2. Updated coverage table (delta-only)

The file-by-file table from the original map §2 stays valid for every entry **except these five**, which now read:

| # | File | Already instruments? | Sensitive payload risk | Reservation | Notes |
|---|---|---|---|---|---|
| 7 | `Epistemos/Bridge/ComputerUseBridge.swift` | ✅ **yes (PR39)** | high | done-committed | Sanitization invariants enforced by `ComputerUseBridgeAgentEventTests.swift` |
| 8a | `Epistemos/Bridge/Phase4Bridge.swift` (perceive) | ✅ **yes (PR40)** | high | done-committed | AX trees + OCR text omitted from event metadata per sanitization invariants |
| 8b | `Epistemos/Bridge/Phase4Bridge.swift` (interact) | ✅ **yes (PR41)** | high | done-committed | Typed-text + AXSecureTextField redaction enforced |
| 8c | `Epistemos/Bridge/Phase4Bridge.swift` (screen_watch) | ✅ **yes (PR42)** | high | done-committed | Lifecycle-only events; no per-frame rows |
| 9 | `Epistemos/Bridge/ClarifyPromptBridge.swift` | ✅ **yes (PR43)** | high | done-committed | Free-form answers, prompt text, choices, and raw errors omitted from event metadata |

All other rows in the original §2 table remain accurate. Re-read those rows for context — they aren't reproduced here.

---

## 3. Re-ranked recommended next safe slices

The original §3 listed five slices: CUB-1, P4-PERCEIVE, P4-INTERACT, P4-WATCH, CPB-1. All five are now closed. No bridge implementation slice remains open from the original map.

### 3.1 Closed bridge slice from the original map

#### Slice CPB-1 — ClarifyPromptBridge AgentEvent provenance — **DONE by Codex (PR43)**

- **Status:** done-committed by Codex PR43, commit `d6f8908b`.
- **Files closed by PR43:**
  - `Epistemos/Bridge/ClarifyPromptBridge.swift`
  - `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift`
  - `docs/fusion/fleet/clarify-prompt-bridge-agent-event-pr43/`
  - `docs/fusion/deliberation/clarify_prompt_bridge_agent_event_pr43_deliberation_2026_05_03.md`
  - `docs/fusion/oversight/PREFLIGHT_83_2026_05_03.md`
- **Sanitization invariants from the original map §3 (CPB-1) are enforced** — the user's free-form `response`, prompt text, choices, raw question JSON, and arbitrary errors are omitted from event metadata. Choice-button index and response-length bucket can be recorded.
- **Tier:** Core + Pro — Core needs this too because clarify is a Core surface.
- **Optional next:** run focused verification of `ClarifyPromptBridgeAgentEventTests.swift` only; do not patch production unless a future deliberation opens a new slice.

### 3.2 Remaining unclassified Bridge gaps after PR43 closure

The original map's bridge inventory is empty for high-payload-risk surfaces. The only remaining `Epistemos/Bridge/*.swift` files that could host AgentEvents are:

- `Epistemos/Bridge/StreamingDelegate.swift` — **explicit no-instrument** per §4 (router; would double-count).
- `Epistemos/Bridge/ChunkedMCPFraming.swift` — **explicit no-instrument** per §4 (transport; events live at MCP call site).
- `Epistemos/Bridge/CoTStreamInterceptor.swift` — **explicit no-instrument** per §4 (parser; thinking ≠ tool action).
- `Epistemos/Bridge/ToolTierBridge.swift` — **explicit no-instrument** per §4 (Rust executor emits via FFI; Swift double-write would race).
- `Epistemos/Bridge/Phase5Bridge.swift` — already instrumented (pre-CUB-1).
- `Epistemos/Bridge/Phase7Bridge.swift` — already instrumented (pre-CUB-1).
- `Epistemos/Bridge/ComputerUseBridge.swift` — done (PR39).
- `Epistemos/Bridge/Phase4Bridge.swift` — done (PR40+PR41+PR42).
- `Epistemos/Bridge/ClarifyPromptBridge.swift` — done (PR43).

**After PR43, the Bridge layer's high-payload-risk AgentEvent coverage is functionally complete.** The next safe AgentEvent expansion lane is **Omega runtime + LocalAgent**, not Bridge.

### 3.3 Next-tier candidates outside Bridge

These were not in the original map's §3 because the §3 was Bridge-scoped. They are now the natural successors. **Each requires a fresh inventory pass to confirm current instrumentation state — the delta below is a candidate list, not a verified gap list.**

| Candidate | File (likely) | Sensitive payload risk | Tier | Pre-slice action required |
|---|---|---|---|---|
| Omega DispatcherCore execution lifecycle | `Epistemos/Omega/Dispatcher*.swift` (verify) | medium | Pro/Research | Inventory pass — confirm not already covered by `MCPBridge.swift` policy gate |
| Omega Catalog tool resolution | `Epistemos/Omega/Catalog*.swift` (verify) | low | Both | Inventory pass — likely no-instrument (catalog lookup, not tool execution) |
| LocalAgent reflex/EOF flush completion | `Epistemos/LocalAgent/LocalAgentLoop.swift` | high | Core | Already partially covered (LocalAgentLoop has recorder); confirm reflex EOF path emits `completed` not just `requested` |
| Omega SovereignGate execution gate | `Epistemos/Sovereign/SovereignGate.swift` | medium | Both | Inventory pass — would need a new event kind (`sovereignGateConfirmed/Denied`); design before code |

A parallel agent should **not** open any of the §3.3 candidates without a fresh inventory pass first — the original map's research did not cover Omega/Sovereign exhaustively.

---

## 4. Preserved no-instrument rationale (unchanged from original §4)

These four files remain explicitly off-limits for direct AgentEvent instrumentation. Adding rows here would double-count, flood the timeline, or race the Rust FFI. The full rationale lives in the original map §4; the entries are reproduced here for at-a-glance scanning.

| File | Reason to skip |
|---|---|
| `Epistemos/Bridge/ChunkedMCPFraming.swift` | Transport-layer pipe accumulator. AgentEvents already record at the MCP call site (`MCPBridge.swift`). Adding a row per pipe chunk would 100×–10000× the AgentEvent table. |
| `Epistemos/Bridge/CoTStreamInterceptor.swift` | Token-level `<think>…</think>` parser. Streamed via `StreamingDelegate.onThinkingDelta`, not a tool. Recording it as an AgentEvent would conflate cognition with action. |
| `Epistemos/Bridge/StreamingDelegate.swift` | Central FFI multiplexer. Direct instrumentation would double-count what each downstream bridge already records. The delegate must remain a thin router. |
| `Epistemos/Bridge/ToolTierBridge.swift` | The Swift side never executes the tool — the closure runs in Rust `agent_core`. The Rust side already emits AgentEvents via FFI. Adding Swift-side rows would create a double-write race. |

The PARALLEL_WORK_MANIFEST round-82 P5 ("AgentEvent Bridge No-Double-Count Source Guards") proposes a Swift Testing suite that locks these four "no-instrument" conclusions as source guards. That slice is now the natural next safety net because PR43 is closed.

---

## 5. Sanitization checklist (unchanged from original §5)

Every AgentEvent emitted by a §3.x slice must remain auditable against the five invariants in the original map §5: no raw user text, no screenshot bytes, no AX subtree dumps, no password-field values, no surrounding chat context. PR39 + PR40 + PR41 + PR42 + PR43 satisfied these in their respective test files.

---

## 6. Reservation respect

This delta was generated before PR43 closed and was amended by Codex after commit `d6f8908b` to reflect done-committed state. It was generated without editing any of:

- `Epistemos/Bridge/ClarifyPromptBridge.swift` (closed by Codex PR43)
- `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift` (closed by Codex PR43)
- `docs/fusion/fleet/clarify-prompt-bridge-agent-event-pr43/`
- `docs/fusion/deliberation/clarify_prompt_bridge_agent_event_pr43_deliberation_2026_05_03.md`
- `docs/fusion/oversight/PREFLIGHT_83_2026_05_03.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- The original `AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md` (read-only)
- Any Phase4Bridge.swift, ComputerUseBridge.swift, or their test files (committed by Codex; safe to read)
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.
