# Agentic Loop + Pro Harness Plan — 2026-06-16

Status: living design doc. Captures the diagnosis + two-lane decision from the
2026-06-16 "it feels dumb / less dynamic" session, grounded in the actual code.

## The real diagnosis (proven, not guessed)

The app felt "dumb / less smart / can't do loops" **even on a cloud model**. The
cause is NOT the host language (Rust/Swift vs TS/Python) and NOT the model — it
is **agent-loop depth**.

Evidence (`ChatCoordinator.cloudToolBudget`, before this session):

| Mode  | Tier      | maxTurns (was) |
|-------|-----------|----------------|
| Fast  | chat_lite | **1**          |
| Think | chat_lite | **1**          |
| Pro   | chat_pro  | **3**          |
| Agent | (managed) | 25             |

With `maxTurns = 1` the Rust agent loop (`agent_loop.rs`) gives the model ONE
call: the instant it emits a tool call and needs a second turn to read the
result, `turn_count > max_turns` trips `MaxTurnsExceeded`. So the everyday
Fast/Think chat was effectively single-shot Q&A even with Claude Opus. Only the
hidden Agent mode got the real 25-turn loop. Codex/Claude Code feel relentless
because they have a **high ceiling** and stop early via `stop_reason == end_turn`
— simple turns stay fast, hard tasks loop.

Second contributor: the system prompt (`CapabilityManifestBuilder`) had only
DEFENSIVE rules (don't over-claim tools). Nothing invited agentic behavior. So
even with budget, the model wasn't told to use tools, work in steps, or persist.

### Fixed this session (native app)
- Loop ceilings raised: Fast 1→5, Think 1→10, Pro 3→15 (under the 25 Agent
  ceiling for the bounded-execution review posture). `stop_reason==end_turn`
  keeps simple turns instant. (`fa83d5b86`)
- Positive agentic directive added to the capability manifest, only when tools
  exist: "use them; gather real data before answering; work iteratively; keep
  going until done; verify with a tool over asserting from memory." Honesty
  rules retained.
- Gemma reasoning separated from the answer (`[Start thinking]`/`[End thinking]`
  markers) + ChatGPT-style thinking box. (`5d0ee337b`)
- Gemma held out of automatic routing so a user pick is never silently swapped.
  (`1ebcc77dc`)

## The two-lane decision

"Smart" is loop+tools+model+harness, which the native app can have. "Dynamic"
for HARDCORE agent work (write code on the fly, `pip/npm install` mid-task,
hot-reload the harness, tap a huge tool ecosystem) genuinely favors TS/Python —
not for aesthetics, but because that pattern collides with the MAS sandbox +
hardened runtime + recompile-to-change-the-loop reality. So: **both lanes, by
strength**, not either/or.

### Lane A — Native app (Rust/Swift), the daily driver
- Polished chat / notes / graph; native streaming UI; honest local tools.
- Model lineup (owner decision 2026-06-16): **pure Gemma 4 ×4** (E2B, E4B,
  12B-QAT, 12B-coder), Gemma 4 default; remove other LOCAL models from Settings.
  Cloud models stay (they are the honest agent/tool backbone).
- Modes: **Fast / Think / Pro**, all tool-capable.
- Honest "tools for every local model incl. Gemma" via **grammar-constrained
  decoding**: `llama-cli` supports `--grammar` / `--json-schema`, and a
  `generateConstrained(prompt:grammarJson:)` seam already exists (stub today).
  Constrained decoding forces VALID tool-call JSON even from Gemma (whose
  free-form tool calls are malformed) — real capability, not faked gating.
  `LocalToolGrammar.swift` builds schemas; `MCPBridge` provides the catalog.

### Lane B — Pro harness (TS/Python), the hardcore lane
- OpenCode/Hermes-style agent for dynamic code-exec / dep-install / long-horizon
  work the sandbox can't host. Lives outside the MAS app.
- Integrates with Lane A via MCP: the harness consumes the same vault/tool
  catalog the native app hosts, so memory/notes/graph stay shared.
- Scoped, not started — see "Next steps."

## Honest-capability boundary (unchanged doctrine)
- MAS build: bounded execution, no hot-path subprocess, review-safe. Local =
  Gemma chat + grammar-constrained tools; cloud = real agent loop.
- Pro build / Lane B: full autonomy (shell, code exec, dep install, long-horizon).
- Never fake agent capability; constrained decoding is the honest way to make a
  weak tool-caller reliable.

## Next steps (sequenced)
1. (Native) Wire `generateConstrained` → `llama-cli --json-schema` through the
   Rust FFI (`run_local_gguf_generation` gains an optional schema), so the GGUF
   lane can emit valid tool JSON. Cargo-testable.
2. (Native) Local Pro tool loop: build the tool schema from `LocalToolGrammar` +
   MCP catalog, constrained-generate the call, execute via MCP, loop. Gemma
   becomes honestly tool-capable in Pro.
3. (Native) Lineup simplification to pure Gemma 4 ×4 once #1–2 land (so default
   Gemma has tools, no tool gap). Reverse the auto-routing default to Gemma.
4. (Native) Verify the agentic-loop feel end-to-end on cloud + Gemma; tune
   ceilings if needed.
5. (Lane B) Stand up the TS/Python Pro harness behind an MCP bridge to the vault.

## Grammar-constrained tools — precise wiring (turnkey for the next increment)

The `--json-schema` capability is the foundation; here is the exact seam chain so
the follow-on is mechanical:

1. **Rust provider (DONE this session, cargo-tested):**
   `GgufCliProvider::with_json_schema(schema)` + `constrained_args()` →
   `--json-schema <schema>` added to the llama-cli command. Empty/blank schema =
   unconstrained (defensive). `agent_core/src/providers/gguf_cli.rs`.
2. **Rust FFI:** add `json_schema: Option<String>` to `run_local_gguf_generation`
   (+ `_inner`) in `bridge.rs`; pass it to `GgufCliProvider::with_json_schema`
   when `Some`. Requires UniFFI regen (build-agent-core.sh). Honest-handle-FFI:
   it's an additive optional param; keep the old call sites working by defaulting
   `None` in Swift.
3. **Swift seam:** `LocalGGUFEngine` (`LocalGGUFClient.swift:186`) currently
   exposes `generate`/`stream: (String, String?, Int) -> …`. Add a
   `generateConstrained: (String, String?, Int, String /*schema*/) -> String`
   closure (separate from chat generate — keeps the plain-chat path untouched).
   Build it in `LocalGgufCliRuntime.engineBuilderIfEnabled()` by passing the
   schema into `streamLocalGgufText` → `invokeLocalGgufGeneration` → the new FFI
   param. Wire the existing `LocalGgufTextStreamDelegate.generateConstrained`
   stub to it.
4. **Local Pro tool loop:** in the local-agent loop, when mode==Pro and tools
   exist: build the JSON Schema for the tool-call envelope from
   `LocalToolGrammar` + the MCP catalog (`MCPBridge`), call `generateConstrained`
   with it, parse the guaranteed-valid JSON, dispatch the tool via MCP, append
   the result, loop until done. This is what flips Gemma's `canActAsAgent` from
   false (malformed free-form) to true (constrained-valid) — honestly.

## Files touched / relevant
- `Epistemos/App/ChatCoordinator.swift` — `cloudToolBudget` (loop ceilings).
- `Epistemos/Engine/CapabilityManifestBuilder.swift` — agentic directive.
- `agent_core/src/agent_loop.rs` — the loop (correct; honors end_turn).
- `agent_core/src/providers/gguf_cli.rs` — GGUF llama-cli provider (+schema TBD).
- `Epistemos/Bridge/LocalGgufRuntimeBridge.swift` — `generateConstrained` seam.
- `Epistemos/LocalAgent/LocalToolGrammar.swift` — tool schemas.
- `Epistemos/Omega/MCPBridge.swift` — MCP catalog.
