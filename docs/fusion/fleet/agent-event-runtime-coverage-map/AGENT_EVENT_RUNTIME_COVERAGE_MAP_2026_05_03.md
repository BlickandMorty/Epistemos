# AgentEvent Runtime Coverage Map — 2026-05-03

> **Purpose.** Read-only inventory of which `Epistemos/Bridge/*.swift` and adjacent runtime surfaces already emit `AgentToolProvenanceRecorder.recordToolEvent` and which do not, plus the next safe PR slice for each gap. Codex can pick from the **Recommended next slices** section in §3 without redoing the inspection.
>
> Doctrine §7 lane: Core open — broader runtime AgentEvent coverage. Generated per `CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md` P6.

---

## 1. Inspection method

`grep -n 'AgentToolProvenanceRecorder\|recordToolEvent\|AgentProvenanceEvent' Epistemos/Bridge/*.swift Epistemos/Omega/*.swift Epistemos/LocalAgent/*.swift`. No code edits. No production patches. Phase7Bridge.swift and Phase5Bridge.swift are in Codex's reservation set for round 73 (PR36 + PR37) and are flagged **reserved/in-flight** — do not touch.

---

## 2. Per-file coverage table

| # | File | Already instruments? | Sensitive payload risk | Reservation | Notes |
|---|---|---|---|---|---|
| 1 | `Epistemos/Bridge/Phase7Bridge.swift` | ✅ yes | medium (NightBrain trigger metadata) | **reserved/in-flight** Codex round 73 PR36 | Codex is wiring `nightbrain.trigger` provenance now |
| 2 | `Epistemos/Bridge/Phase5Bridge.swift` | ✅ yes | medium (SSM state actions) | **reserved/in-flight** Codex round 73 PR37 | Codex is wiring `ssm.state.*` provenance next |
| 3 | `Epistemos/Omega/MCPBridge.swift` | ✅ yes | low (denial metadata only) | open | Already records `tools/list` / `tools/call` policy denials with full event lifecycle (requested + denied) |
| 4 | `Epistemos/LocalAgent/LocalAgentLoop.swift` | ✅ yes | high (tool argumentsJSON + result) | open | Records local tool execution lifecycle; sanitization burden lives here |
| 5 | `Epistemos/Bridge/ToolTierBridge.swift` | indirect | low (tool name only) | open | Bridges to Rust `agent_core` which emits via FFI; Swift side itself does not call `recordToolEvent` because the executor closure runs in Rust |
| 6 | `Epistemos/Bridge/StreamingDelegate.swift` | indirect | n/a | open | Central FFI delegate; routes events to specific bridges. Direct instrumentation here would double-count what individual bridges record |
| 7 | `Epistemos/Bridge/ComputerUseBridge.swift` | ❌ no | **HIGH** (screenshots, keystrokes, mouse coords, AX trees) | open | **Highest-value gap.** Currently fire-and-forget — no audit trail for screenshot/click/type/scroll/key/drag actions. Pro/Research-only path |
| 8 | `Epistemos/Bridge/Phase4Bridge.swift` | ❌ no | **HIGH** (AX trees, screenshot paths, app names) | open | `perceive`, `interact`, `screen_watch` — all macOS native specialty surfaces with no provenance row today. Pro/Research-only |
| 9 | `Epistemos/Bridge/ClarifyPromptBridge.swift` | ❌ no | medium (user's free-form answer) | open | NSAlert clarify-question surface. Should emit `clarify.ask.requested` / `clarify.ask.completed` with `response` redacted by default |
| 10 | `Epistemos/Bridge/ChunkedMCPFraming.swift` | ❌ no | n/a (transport only) | open / N/A | Pipe accumulator — transport layer, not a tool dispatcher. **Recommend: do NOT instrument.** AgentEvents belong above this layer at the MCP call site (already covered by `MCPBridge.swift`) |
| 11 | `Epistemos/Bridge/CoTStreamInterceptor.swift` | ❌ no | low (token IDs) | open / N/A | Token-level `<think>...</think>` parser. Streamed via `StreamingDelegate.onThinkingDelta`. **Recommend: do NOT instrument** — thinking blocks are not tool events; instrumenting them as tool events confuses the timeline |

---

## 3. Recommended next safe slices

In priority order. Each slice is a single PR that adds `recordToolEvent` calls to one bridge, plus a sanitization-pair test (sensitive fields redacted) and a lifecycle-pair test (requested → started → completed/failed/denied). All slices are file-disjoint from Codex's round-73 reservation set (Phase5/Phase7 + their tests + their fleet folders).

### Slice CUB-1 — ComputerUseBridge AgentEvent provenance
- **Why first:** every other unwired bridge has lower payload-risk and lower exposure. ComputerUseBridge handles user keystrokes and full-screen captures; running without provenance means an audit can't reconstruct what the agent saw or did.
- **Files (new + edit, all small):**
  - Edit `Epistemos/Bridge/ComputerUseBridge.swift` — inject `AgentToolProvenanceRecorder`, emit lifecycle events around `execute(actionJSON:)` per action kind (`computer.screenshot`, `computer.click`, `computer.type`, `computer.scroll`, `computer.key`, `computer.drag`).
  - New `EpistemosTests/ComputerUseBridgeAgentEventTests.swift` — fixture tests for sanitization (typed text + screenshot paths must be redacted in metadata) + lifecycle (requested → started → completed/failed).
- **Tier:** Pro/Research only — already gated by `#if !EPISTEMOS_APP_STORE`.
- **Sanitization invariants the test must enforce:**
  - `argumentsJSON` for `.type` events does NOT contain the raw text (only length + locale).
  - `argumentsJSON` for `.screenshot` events does NOT contain the image path or coordinates of in-image pixels (only display id + width/height).
  - `result` for any action does NOT contain base64 image bytes (only a short metadata blob).
- **Reservation safety:** disjoint from Phase5/Phase7 + their tests; disjoint from `MCPBridge.swift` (different file).

### Slice P4-PERCEIVE — Phase4Bridge.perceive AgentEvent provenance
- **Why next:** perceive returns AX trees + OCR snippets — second-highest payload risk after ComputerUseBridge.
- **Files:**
  - Edit `Epistemos/Bridge/Phase4Bridge.swift` — wire `perceive(appName:depth:)` lifecycle.
  - New `EpistemosTests/Phase4BridgePerceiveAgentEventTests.swift` — fixture tests.
- **Tier:** Pro/Research only — already gated by `#if !EPISTEMOS_APP_STORE`.
- **Sanitization invariants:** AX text bodies and OCR text bodies must be **omitted** from event metadata (only counts + element kinds + latency).
- **Reservation safety:** disjoint from Codex round 73 reservation set.

### Slice P4-INTERACT — Phase4Bridge.interact AgentEvent provenance
- **Files:**
  - Edit `Epistemos/Bridge/Phase4Bridge.swift` — wire `interact(actionJson:)` lifecycle.
  - New `EpistemosTests/Phase4BridgeInteractAgentEventTests.swift`.
- **Sanitization invariants:** typed-text and password-field-like values must be redacted; actions on AX elements must record the element kind + coords but not the full AX subtree.

### Slice P4-WATCH — Phase4Bridge.screen_watch AgentEvent provenance
- **Files:**
  - Edit `Epistemos/Bridge/Phase4Bridge.swift` — wire `startScreenWatch(watchJson:)` lifecycle.
  - New `EpistemosTests/Phase4BridgeScreenWatchAgentEventTests.swift`.
- **Notes:** screen_watch is a long-lived poll, so the provenance shape is `started` (once) + `completed/cancelled` (once) — no per-frame events (those would flood the AgentEvent table).

### Slice CPB-1 — ClarifyPromptBridge AgentEvent provenance
- **Files:**
  - Edit `Epistemos/Bridge/ClarifyPromptBridge.swift` — wire `ask(questionJson:)` lifecycle.
  - New `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift`.
- **Sanitization invariants:** the user's free-form `response` must be redacted in metadata by default (length + answered-bool only). Choice-button index can be recorded.
- **Tier:** Core + Pro — Core needs this too because clarify is a Core surface.

---

## 4. Explicitly NOT recommended (instrumentation here would be wrong)

| File | Reason to skip |
|---|---|
| `Epistemos/Bridge/ChunkedMCPFraming.swift` | Transport-layer pipe accumulator. AgentEvents already record at the MCP call site (`MCPBridge.swift`). Adding a row per pipe chunk would 100×–10000× the AgentEvent table and confuse audit consumers. |
| `Epistemos/Bridge/CoTStreamInterceptor.swift` | Token-level parser of `<think>…</think>` deltas. Thinking is streamed via `StreamingDelegate.onThinkingDelta`, not a tool. Recording it as an AgentEvent would conflate cognition with action. |
| `Epistemos/Bridge/StreamingDelegate.swift` | Central FFI multiplexer. Direct instrumentation here would double-count what each downstream bridge already records. The delegate must remain a thin router. |
| `Epistemos/Bridge/ToolTierBridge.swift` | The Swift side never executes the tool — the closure runs in Rust `agent_core`. The Rust side already emits AgentEvents via FFI. Adding Swift-side rows would create a double-write race. |

---

## 5. Sensitive-payload sanitization checklist (all slices in §3)

Every AgentEvent emitted by a §3 slice must be auditable against:

1. **No raw user text.** Free-form text the user typed (clarify answer, .type action, search query) must be redacted to `length: N, locale: "..."` or omitted entirely.
2. **No screenshot bytes.** Image paths may appear in metadata if the path is to a sandboxed temp file; raw base64 image bytes must never appear in `argumentsJSON` or `result`.
3. **No AX subtree dumps.** AX element kinds + counts only; never the full text content of every leaf.
4. **No password-field values.** Detect AX elements with `role: AXSecureTextField` and skip their value entirely.
5. **No surrounding chat context.** Every event references `runID` + `traceID` + `toolCallID` so a downstream consumer can join — the event itself does NOT inline the prompt or prior conversation.

A slice that instruments without satisfying §5.1–§5.5 must be returned for revision. Sanitization tests are non-negotiable for any slice with `Sensitive payload risk` ≥ medium in §2.

---

## 6. Reservation respect

This map was generated without editing any of:

- `Epistemos/Bridge/Phase7Bridge.swift` (Codex PR36 in flight)
- `Epistemos/Bridge/Phase5Bridge.swift` (Codex PR37 in flight)
- `EpistemosTests/Phase7BridgeAgentEventTests.swift`
- `EpistemosTests/Phase5BridgeAgentEventTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`

Every recommended §3 slice is also disjoint from Codex's round-73 reservation set per `PARALLEL_WORK_MANIFEST.md`.
