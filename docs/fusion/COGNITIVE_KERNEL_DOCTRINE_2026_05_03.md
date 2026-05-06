---
state: canon
canon_promoted_on: 2026-05-03
frontmatter_added_on: 2026-05-06
covers: kernel + renderer + syscall + sandbox-exec + capability layers; one agent loop, one memory store, one binary; Phases 1-7
---

# Epistemos Cognitive Kernel Doctrine — One Kernel, One Binary — 2026-05-03

> **Doctrinal entry-point.** This document is canon. Every PR that touches the
> agent loop, skills system, procedural memory, provenance ledger, tool
> dispatcher, code execution, or the Core/Pro tier boundary must cite the
> section it complies with — or amend the doctrine first. No fragmentation
> regressions. No parallel implementations. No subprocess for inference. No
> mockup overrides canon.

> **Module-name reconciliation note (2026-05-05, audit item A6).** This
> doctrine refers throughout to `agent_core::hermes::*`. The actual module
> shipped on 2026-05-05 (Hermes subprocess removal series) is named
> `agent_core::agent_runtime` — same modules (`prompt_format`,
> `function_call`, `skills`, `procedural_memory`, `self_evolution`), same
> responsibilities, only the path prefix changed. Per `CLAUDE.md`, the
> `Hermes` prefix is reserved for the Hermes-3 model's prompt format
> (Swift `HermesPromptBuilder.swift`, kept), not the in-process runtime.
> When reading this doctrine, mentally substitute `agent_core::hermes/` →
> `agent_core::agent_runtime/` for every code reference. Doctrine content
> + responsibilities are unchanged; only the import path differs. The
> rename commit is `77de8196`.

---

## 0. The framing

**Today there are five agent loops in the Epistemos tree.**

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Today (fragmented):                                                     │
│                                                                          │
│  Swift LocalAgentLoop ──────┐                                            │
│  Rust agent_core agent_loop ┼─── five orchestrators tripping over each   │
│  omega-mcp dispatcher ──────┤    other; five state stores; five memory   │
│  Python hermes-agent (XPC) ─┤    models; five provenance trails          │
│  AgentXPC / ProviderXPC ────┘                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

Each one carries its own state, its own memory model, its own provenance, its
own skill registry, its own tool dispatch. From outside the user sees one app.
From inside, five orchestrators are racing for the same buffer.

**Tomorrow there is one cognitive kernel.**

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Tomorrow (unified):                                                     │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │              SWIFT RENDERER                                     │    │
│   │  (UI · MLX-Swift inference · macOS APIs · WKWebView editor)     │    │
│   └────────────────────────────┬────────────────────────────────────┘    │
│                                │ UniFFI (in-process, zero-copy)         │
│   ┌────────────────────────────▼────────────────────────────────────┐    │
│   │              COGNITIVE KERNEL  (agent_core, Rust)               │    │
│   │  Agent Loop · Hermes Runtime · Skills · Procedural Memory       │    │
│   │  Tool Registry · Prompt Manager · Resonance Gate · MutationEnv  │    │
│   │  Provenance Ledger · Capability Lattice · Compaction · Cache    │    │
│   └─────┬────────────────────────────────────────────────┬──────────┘    │
│         │                                                │               │
│   ┌─────▼──────────────┐                       ┌─────────▼──────────┐    │
│   │  XPC SYSCALL       │                       │  WASM SANDBOX-EXEC │    │
│   │  AgentXPC          │                       │  wasmtime + WASI   │    │
│   │  ProviderXPC       │                       │  Pyodide / QuickJS │    │
│   └────────────────────┘                       └────────────────────┘    │
│         │                                                                │
│   ┌─────▼─────────────────────────────────────────────────────────┐      │
│   │  SOVEREIGN GATE  (single LAContext, action-class biometric)   │      │
│   └───────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────┘
```

**Same shape as Linux + userspace + syscalls + seccomp + capabilities,
applied to cognition.** The kernel does the work. The renderer shows the
result. The syscall boundary mediates sandbox crossings. The exec sandbox
runs untrusted code. The capability gate decides what gets to happen.

This is what "one binary" actually means.

---

## 1. The doctrine — five rules

### Rule 1 — One agent loop

`agent_core::agent_loop` is the only agent loop in the binary. Swift does not
contain a parallel loop; Python does not contain a parallel loop; XPC services
are pass-through dispatchers, not loops. If a feature needs orchestration, it
extends the kernel loop or composes higher-order tools that the kernel loop
calls.

### Rule 2 — One memory store

Every memory tier (L0 Exact Hot through L_SE Self-Evolving) lives in
agent_core. Procedural memory, episodic memory, semantic memory, working
memory, KV cache — all owned by Rust, exposed via UniFFI to Swift for
read-only display. Swift `@Observable` services are *projections* of kernel
state, never the source of truth.

### Rule 3 — One provenance ledger

`AgentEvent` (Rust) is the only provenance enum. Every action — tool call,
skill invocation, model call, mutation, capability grant — emits an
`AgentEvent` to the ring buffer. The Provenance Console is a Swift renderer
over the kernel's ring. No parallel `AgentProvenanceEvent`, no parallel ring
in Swift, no parallel log in Python.

### Rule 4 — One skill registry

`agent_core::hermes::skills` is the only skill registry. The existing
`agent_core::tools::registry` becomes its substrate (a Skill is a higher-order
Tool composed of multiple Tool calls). The Python hermes-agent's skill folder
becomes a *data source* the Rust registry reads from, not a parallel runtime.

### Rule 5 — One privilege boundary

`Epistemos/Sovereign/SovereignGate.swift` is the only `LAContext` owner.
Every privileged action (delete companion, rotate keys, mutate vault under
locked profile, send via iMessage, execute shell) routes through the action-
class matrix in doctrine §A.7. No parallel `BiometricGate`. No `LAContext`
calls outside `Epistemos/Sovereign/`.

---

## 2. The fragmentation audit

Codex must produce `docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_03.md` before
any Phase-2 work. The audit table:

| Loop / Registry / Store                              | Path                                                      | Verdict     | Action |
|---|---|---|---|
| Rust `agent_core::agent_loop`                        | `agent_core/src/agent_loop.rs`                            | **Canon**   | Keep, extend. |
| Swift `LocalAgentLoop`                               | `Epistemos/LocalAgent/LocalAgentLoop.swift`               | **Parallel** | Collapse — convert to thin Swift caller of kernel loop via UniFFI. |
| omega-mcp dispatcher                                 | `omega-mcp/src/dispatcher.rs`                             | **Distinct** | Keep — MCP protocol is an *interface*, not a loop. Verify it doesn't cache state the kernel should own. |
| Python hermes-agent loop (subprocess)                | `hermes-agent/` submodule                                 | **Parallel** | Collapse — port the four valuable parts to `agent_core::hermes` (Phase 2). Mark subprocess path `cfg(feature = "hermes_subprocess")`. |
| AgentXPC service                                     | `XPCServices/AgentXPC/`                                   | **Pass-through (target)** | Implement as pass-through to kernel UniFFI; verify no shadow state. |
| ProviderXPC service                                  | `XPCServices/ProviderXPC/`                                | **Pass-through (target)** | Same — pass-through to kernel provider router. |
| Rust `tools::registry`                               | `agent_core/src/tools/registry.rs`                        | **Canon**   | Keep, becomes substrate for Skills. |
| Python hermes skill registry                         | `hermes-agent/skills/`                                    | **Data source** | Read-as-data into `agent_core::hermes::skills`; no Python execution. |
| Swift `IncrementalToolCallDetector`                  | `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`  | **Mirror**  | Keep as Swift mirror of kernel parser; verify byte-for-byte parity. |
| Swift `HermesPromptBuilder`                          | `Epistemos/LocalAgent/HermesPromptBuilder.swift`          | **Mirror**  | Keep as Swift mirror; canonical builder lives in `agent_core::hermes::prompt_format`. |
| `agent_core::events::AgentEvent`                     | `agent_core/src/events/`                                  | **Canon**   | Keep, extend with the 6 v1.6 forward variants per H6. |
| Kimi mockup `Events/AgentProvenanceEvent.swift`      | `kimis deep research/epistenos/.../Events/`               | **Reject**  | Reference only; never imported. |
| `agent_core::resonance`                              | `agent_core/src/resonance/`                               | **Canon**   | Keep — committed `06230e8d` + `07e33fed`. |
| Kimi mockup `ResonanceServiceWired.swift`            | `kimis deep research/epistenos/.../ResonanceServiceWired` | **Reference** | Read for FFI swap pattern; apply in canonical `Epistemos/Engine/ResonanceService.swift`. |
| `Epistemos/Sovereign/SovereignGate.swift`            | `Epistemos/Sovereign/SovereignGate.swift`                 | **Canon**   | Keep — single LAContext owner. |
| Kimi mockup `BiometricGate.swift`                    | `kimis deep research/epistenos/.../BiometricGate.swift`   | **Reject**  | Reference only; never imported. |

The audit doc must contain this table populated against the actual repo state
(grep verified) and any additional parallel implementations Codex finds.

---

## 3. The kernel ABI — what agent_core exposes

The kernel exposes one UniFFI interface. Swift consumes it. XPC services
consume it. There is no second-tier API.

```rust
// agent_core/src/bridge.rs — additions for the unified kernel

// Loop control
fn start_session(profile_id: String) -> Result<SessionHandle, AgentErrorFFI>;
fn submit_turn(handle: SessionHandle, turn: TurnInputFFI) -> Result<TurnIdFFI, AgentErrorFFI>;
fn cancel_turn(turn_id: TurnIdFFI) -> Result<(), AgentErrorFFI>;
fn end_session(handle: SessionHandle) -> Result<(), AgentErrorFFI>;

// Skills (new — Phase 2)
fn list_skills(profile_id: String) -> Result<Vec<SkillDescriptorFFI>, AgentErrorFFI>;
fn invoke_skill(profile_id: String, skill_name: String, args: String) -> Result<SkillResultFFI, AgentErrorFFI>;
fn record_skill_outcome(skill_name: String, outcome: SkillOutcomeFFI) -> Result<(), AgentErrorFFI>;

// Procedural memory (new — Phase 2)
fn recall_procedure(skill_name: String, context_hash: String) -> Result<Option<ProcedureFFI>, AgentErrorFFI>;
fn write_procedure(procedure: ProcedureFFI) -> Result<(), AgentErrorFFI>;

// WASM exec (new — Phase 3)
fn exec_wasm(module_id: String, args: String, policy: WasmPolicyFFI) -> Result<WasmResultFFI, AgentErrorFFI>;
fn exec_python_wasm(source: String, policy: WasmPolicyFFI) -> Result<WasmResultFFI, AgentErrorFFI>;
fn exec_javascript_wasm(source: String, policy: WasmPolicyFFI) -> Result<WasmResultFFI, AgentErrorFFI>;

// Provenance (read-only projections)
fn provenance_subscribe(filter: ProvenanceFilterFFI) -> Result<ProvenanceStreamHandle, AgentErrorFFI>;
fn provenance_recent(filter: ProvenanceFilterFFI, limit: u32) -> Result<Vec<AgentEventFFI>, AgentErrorFFI>;

// Resonance (already shipped — 07e33fed)
fn compute_resonance_signature_core(claim_json: String) -> Result<String, AgentErrorFFI>;

// Capability lattice (Phase 6)
fn current_profile() -> PolicyProfileFFI;
fn capability_for(symbol: String) -> Result<TierFFI, AgentErrorFFI>;
fn is_permitted(symbol: String) -> bool;
```

**Anything not in this ABI is internal kernel detail.** Swift does not reach
into Rust's tool registry directly; Swift calls `submit_turn` and the kernel
dispatches. Swift does not own the procedural memory store; Swift queries it
via `recall_procedure`. The kernel decides; the renderer reflects.

---

## 4. Hermes-in-Rust — the four valuable parts

NousResearch Hermes is a *prompt format + runtime + skills + memory*
discipline, originally written in Python. The valuable parts are
language-agnostic. The Python is incidental. We rewrite the four pieces in
Rust inside `agent_core::hermes`:

### 4.1 Prompt format (`agent_core/src/hermes/prompt_format.rs`)

```
canonical Hermes-Function-Calling system prompt builder
  ├── input: tools list, user system prompt, persona block, vault context
  ├── output: byte-exact match to NousResearch Hermes-Function-Calling
  │           format so Hermes-trained models behave identically
  └── tests: round-trip vs reference fixtures (pull canonical examples
            from NousResearch repo, store as test corpus, assert byte-equal)
```

**Why byte-exact.** Hermes-3 and Hermes-4 are fine-tuned to the prompt
format. Drift breaks tool-call accuracy. Cross-compat is mandatory.

### 4.2 Function-call parser (`agent_core/src/hermes/function_call.rs`)

```
parse <tool_call>...</tool_call> XML-ish blocks from streaming output
  ├── streaming: incremental — emit ToolCall events as soon as JSON closes
  ├── error recovery: malformed JSON → log + skip + continue stream
  ├── verify against existing IncrementalToolCallDetector in Swift —
  │   the Swift mirror reads from this canonical parser via FFI
  └── tests: 30+ fixtures covering happy path, partial JSON, nested objects,
           escaped strings, multi-call turns, malformed-then-recovered
```

### 4.3 Skills registry (`agent_core/src/hermes/skills.rs`)

```
Skill = higher-order Tool composed of multiple Tool calls
  ├── storage: ~/.epistemos/skills/<name>.json + ~/Library/Application
  │            Support/Epistemos/skills/<name>.json (App Group path on MAS)
  ├── schema: name · description · trigger_patterns · steps[Tool calls] ·
  │           expected_outcome · success_criteria · failure_recovery
  ├── invocation: skill_dispatch(name, args) → kernel agent_loop with the
  │               steps as a pre-canned sub-plan
  ├── composition: a Skill can call other Skills (recursion-bounded)
  └── tests: skill registration, dispatch, composition, recursion limit,
           failure recovery
```

**Skill is a Tool.** Skills register into the same `tools::registry` that
ad-hoc Tools register into. The agent doesn't see a "Skill vs Tool"
distinction — it sees a unified callable surface where some entries happen
to be composed of other entries. This is the unification.

### 4.4 Procedural memory (`agent_core/src/hermes/procedural_memory.rs`)

```
SQLite-backed store: (skill_name, invocation_context_hash) →
                     {steps_taken, outcomes, durations, error_modes}
  ├── retrieval: embedding similarity over invocation_context_hash —
  │              given a new context, find the closest 3 prior procedures
  ├── write: every successful skill invocation appends an outcome record
  ├── decay: outcomes older than N days lose retrieval weight (configurable)
  └── tests: write/read round-trip, embedding similarity, decay, schema
           migration, concurrent access from multiple turns
```

### 4.5 Self-evolution (`agent_core/src/hermes/self_evolution.rs`)

```
when a sequence of Tool calls completes successfully and is repeated
across N turns, propose a new Skill that captures the sequence
  ├── detection: Tool-call sequence pattern matcher over the AgentEvent ring
  ├── proposal: synthesize a Skill draft (name, description, steps)
  ├── confirmation: surface to the user for review (Sovereign Gate
  │                 threshold: implicit consent within session, explicit
  │                 biometric for cross-session persistence)
  ├── promotion: on confirm, write to the skill registry
  └── tests: sequence detection, proposal synthesis, confirmation flow,
           promotion + rollback
```

**This is the NousResearch hermes-agent-self-evolution pattern, ported.**
The Python implementation was a research artifact; the Rust implementation
becomes a shipping product feature.

---

## 5. WASM exec — the MAS unlock

### 5.1 The sandbox-vs-subprocess problem

**Apple App Sandbox forbids arbitrary subprocess.** Specifically:

| Sandbox rule                                                                  | Effect on Epistemos                                                          |
|---|---|
| `NSTask` / `posix_spawn` / `fork+exec` of arbitrary binaries                  | Blocked unless target binary is co-signed and sandboxed by the same team    |
| Loading dylibs from arbitrary paths                                           | Blocked unless `com.apple.security.cs.disable-library-validation` granted   |
| Running interpreters (Python, Node, Ruby) bundled in app                      | *Technically* permitted as static binaries, but Python's stdlib + C-ext compat is brittle under sandbox; reviewers flag |
| JIT compilation                                                               | Requires `com.apple.security.cs.allow-jit` (Hardened Runtime entitlement) |
| Subprocess spawned BY a bundled interpreter                                   | Blocked — same NSTask rule applies recursively                              |

**Conclusion:** the native subprocess path for Python/Node/Ruby code execution
is incompatible with MAS. We need an in-process, sandbox-friendly alternative.

### 5.2 The wasmtime answer

**WASM execution is in-process.** No fork, no exec, no NSTask. The wasmtime
runtime is a Rust crate that links into agent_core. WASI gives controlled
filesystem and network access via per-execution policy.

```
agent_core/src/exec/
  ├── mod.rs
  ├── wasm_runtime.rs   (wasmtime engine, configured for MAS:
  │                      strategy = Compiler::Winch (single-pass, faster
  │                                 than interpreter, no JIT optimization),
  │                      epoch interruption for time limits,
  │                      fuel-based instruction limits,
  │                      memory limits via ResourceLimiter)
  ├── pyodide_loader.rs (load bundled Pyodide WASM from
  │                      Resources/Wasm/pyodide-core.wasm,
  │                      cache compiled module across invocations)
  ├── quickjs_loader.rs (load bundled QuickJS WASM for JS user code)
  └── policy.rs         (per-execution: max_memory_mb, max_fuel,
                         max_wall_secs, fs_preopens: Vec<PathBuf>,
                         net_allowed: bool)
```

### 5.3 Bundled WASM modules in `Resources/Wasm/`

| Module                       | Purpose                                  | Size (approx) |
|---|---|---|
| `pyodide-core.wasm`          | Python user code (numeric, text, JSON)   | ~12 MB compressed |
| `quickjs.wasm`               | JavaScript user code (lighter than Pyodide) | ~1 MB |
| `epistemos-tools.wasm`       | Pre-compiled Epistemos tool modules      | ~3 MB |

**Total bundle weight added: ~16 MB.** Negligible vs the model files
(gigabytes). Worth it for the MAS unlock.

### 5.4 The JIT entitlement question

Wasmtime's default Cranelift compiler uses JIT. Under Hardened Runtime + MAS:

**Option A — Winch single-pass compiler (no JIT optimization, but still uses
JIT entitlement for code generation).** Requires
`com.apple.security.cs.allow-jit`. MAS reviewers approve JIT for legitimate
runtimes (Safari, scripting engines). Justification: "Sandboxed execution of
user-provided computational code via WebAssembly. The JIT entitlement is
required by the wasmtime runtime to compile WASM bytecode to native code at
load time."

**Option B — Wasmtime in pulley-interpreter mode (no JIT).** No entitlement
required. ~10–50× slower than Winch. Acceptable for non-hot paths.

**Doctrinal choice:** ship Option A by default with `allow-jit` requested.
Fall back to Option B at runtime if JIT entitlement is rejected (defensive).
Both code paths covered by tests.

### 5.5 Tool registry exposure

```rust
// agent_core/src/tools/registry.rs — Phase 3 additions

register_tool("exec_python_wasm",  Tier::Core, exec::python_wasm);
register_tool("exec_javascript",   Tier::Core, exec::javascript_wasm);
register_tool("exec_wasm",         Tier::Core, exec::raw_wasm);

#[cfg(feature = "pro")]
register_tool("exec_shell",        Tier::Pro,  exec::native_shell);
#[cfg(feature = "pro")]
register_tool("exec_python_native", Tier::Pro, exec::native_python);
#[cfg(feature = "pro")]
register_tool("exec_node_native",  Tier::Pro, exec::native_node);
```

**Core gets bounded code execution.** Pro keeps native subprocess for users
who need shell, Docker, real CLIs, or full Python with arbitrary C extensions.

---

## 6. In-process bundled MCP

### 6.1 The MCP-vs-sandbox problem

Today omega-mcp dispatches to MCP servers. When a server is bundled (vault
ops, search, fetch, think, todo, calc), we still spawn it as a subprocess
over stdio. **Subprocess for bundled servers is wasted complexity** — we own
the code, we ship it in the same binary, we can call it as a function.

### 6.2 The collapse

```
omega-mcp/src/
  ├── inproc/
  │   ├── mod.rs
  │   ├── vault_ops.rs   (was: spawned subprocess; is: Rust module called directly)
  │   ├── search.rs
  │   ├── fetch.rs
  │   ├── think.rs
  │   ├── todo.rs
  │   └── calc.rs
  ├── external/         (subprocess MCP — Pro only, for user-installed MCPs)
  │   └── mod.rs        (cfg(feature = "pro"))
  └── dispatcher.rs     (routes by name: bundled → inproc::call;
                                           external → external::spawn)
```

**Bundled MCPs become Core-tier, MAS-eligible.** External MCPs (user-installed
third-party servers) stay Pro because they require subprocess.

### 6.3 The MCP protocol stays

We still expose the MCP protocol externally. Other MCP-aware clients can
connect to Epistemos and consume our bundled servers. The protocol is the
*interface*; the implementation is just no-longer-spawned-as-subprocess.

---

## 7. The Pro → Core migration matrix

Every capability gets one row. Tier transition ("From → To") plus the
sandbox / entitlement rule that permits or forbids it.

| Capability                                            | From | To       | Permitting / forbidding rule                                                        |
|---|---|---|---|
| Native tool exec (calc, file, search, fetch)          | Core | Core     | In-process Rust; no entitlement needed                                               |
| Cloud API providers (Claude, OpenAI, Perplexity)      | Core | Core     | `com.apple.security.network.client`                                                  |
| Local MLX inference (in-process)                      | Core | Core     | In-process Swift; UMA shared memory                                                  |
| Multi-step agent loop (in-process)                    | Core | Core     | In-process Rust                                                                      |
| Sovereign Gate biometric                              | Core | Core     | LocalAuthentication framework; no special entitlement                                |
| Resonance Gate ternary                                | Core | Core     | In-process Rust                                                                      |
| Companion Farm + Simulation v1.6                      | Core | Core     | In-process SwiftUI                                                                   |
| Provenance Console                                    | Core | Core     | In-process; reads kernel ring                                                        |
| AgentXPC / ProviderXPC services                       | Core | Core     | XPC services co-signed by same team; permitted under sandbox                         |
| Hermes prompt + function-call parse                   | Pro  | **Core** | In-process Rust kernel (Phase 2)                                                     |
| Skills registry + procedural memory                   | Pro  | **Core** | In-process Rust kernel + SQLite (Phase 2)                                            |
| Self-evolution auto-skill discovery                   | Pro  | **Core** | In-process Rust kernel (Phase 2)                                                     |
| Code execution — Python user snippets                 | Pro  | **Core** | wasmtime + Pyodide-WASM in-process; `com.apple.security.cs.allow-jit`               |
| Code execution — JavaScript user snippets             | Pro  | **Core** | wasmtime + QuickJS-WASM in-process; `com.apple.security.cs.allow-jit`               |
| Code execution — generic WASM modules                 | Pro  | **Core** | wasmtime in-process; `com.apple.security.cs.allow-jit`                              |
| MCP client — bundled servers                          | Pro  | **Core** | In-process Rust modules (Phase 4); no spawn                                          |
| LSP — bundled language servers                        | Pro  | **Core** | In-process Rust crates (e.g. `tree-sitter`, `syn`); no spawn                        |
| Long-horizon agent loops                              | Pro  | **Core** | In-process Rust kernel; bounded by Sovereign Gate action class                       |
| MCP client — external user-installed MCP servers      | Pro  | Pro      | App Sandbox `NSTask` restriction                                                     |
| Shell execution (`/bin/sh`)                           | Pro  | Pro      | App Sandbox `NSTask` restriction                                                     |
| Docker / container exec                               | Pro  | Pro      | Subprocess + privileged daemon access                                                |
| Native CLI passthrough (claude/codex/gemini/kimi)     | Pro  | Pro      | App Sandbox `NSTask` restriction                                                     |
| Native Python / Node / Ruby subprocess                | Pro  | Pro      | App Sandbox `NSTask` restriction                                                     |
| iMessage send via osascript                          | Pro  | Pro      | App Sandbox + `NSAppleEventsUsageDescription`; osascript bridge requires temp exception |
| iMessage send via Messages framework (research)       | Pro  | (Core?)  | TBD — Messages framework partially restricted under sandbox; needs investigation     |
| Computer Use (AXorcist + ScreenCaptureKit)            | Pro  | Pro      | TCC Accessibility + ScreenCapture entitlements; user-prompted                        |
| ScreenCaptureKit (capture only)                       | Pro  | Pro      | TCC ScreenCapture                                                                    |
| Generic file write (outside sandbox container)        | Pro  | Pro      | App Sandbox `com.apple.security.files.user-selected.read-write` only                |
| Vault file write (inside App Group container)         | Core | Core     | `com.apple.security.application-groups`                                              |

**Net Core expansion:** Hermes runtime, skills, procedural memory,
self-evolution, Python-via-WASM, JavaScript-via-WASM, generic WASM, bundled
MCP, in-process LSP, long-horizon loops. **That's a roughly 60 % expansion of
Core's effective capability surface.**

---

## 8. The capability lattice — single source of truth

Every Tool, Skill, Command, View, and FFI entry point declares its tier:

```rust
// agent_core/src/capability/tier.rs

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Tier {
    Core,        // Always available; MAS + Pro
    Pro,         // Pro build only; never compiled into MAS
    Research,    // Research builds only; behind cfg(feature = "research")
    Both,        // Same as Core (alias for clarity at declaration sites)
    All,         // Same as Core; reserved for kernel-level entry points
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PolicyProfile {
    AppStore,    // MAS build; Tier::Core only
    Pro,         // Pro build; Tier::Core + Tier::Pro
    Research,    // Research build; all tiers
}
```

**Filter at the registry, not at the call site.** When `PolicyProfile ==
AppStore`, the registry never even *exposes* Tier::Pro entries. The agent
loop literally cannot invoke them because they don't exist in the registered
map. This is structural — not enforced by `if` statements that can drift.

```rust
// agent_core/src/tools/registry.rs

pub fn registered_for(profile: PolicyProfile) -> &'static HashMap<String, ToolEntry> {
    match profile {
        PolicyProfile::AppStore => &CORE_REGISTRY,
        PolicyProfile::Pro      => &PRO_REGISTRY,    // CORE + PRO entries
        PolicyProfile::Research => &RESEARCH_REGISTRY, // all entries
    }
}
```

**`HermesCommandDispatcher.parseCore`** (already shipped this session)
enforces the equivalent on the Swift side: in MAS builds, Pro-only commands
return a structured "tier_unavailable" rejection.

---

## 9. The five anti-patterns — what MUST NOT regress

These are non-negotiable. Any PR that introduces one of them is a doctrine
violation; the audit step rejects it.

### 9.1 No subprocess for inference

Never. Cloud API calls are HTTP, not subprocess. Local inference is in-process
MLX-Swift via `MLXInferenceService`. The hermes-agent Python subprocess does
not perform inference; if a future change makes it perform inference, that's a
violation. The exception in CLAUDE.md (oMLX bridge for oversized models) is
the *only* exception.

### 9.2 No parallel agent loops

Five loops today. One loop tomorrow. Any PR that introduces a new loop
("just for this feature") is a violation. New features extend the kernel
loop or compose higher-order tools the kernel calls.

### 9.3 No parallel skill registries

One Rust registry. The Swift `LocalAgentLoop` skill paths get migrated to
read from the Rust registry via UniFFI. The Python hermes-agent skill
folder becomes a *data source* read into the Rust registry, not a parallel
runtime.

### 9.4 No parallel provenance ledgers

One `AgentEvent` enum in Rust. One ring buffer in Rust. The Swift
Provenance Console is a renderer over the kernel's ring. Kimi's
`Events/AgentProvenanceEvent.swift` mockup is reference-only; never
imported.

### 9.5 No parallel Sovereign Gate

One `LAContext` owner: `Epistemos/Sovereign/SovereignGate.swift`. Kimi's
`BiometricGate.swift` and `Security/SovereignGate.swift` mockups are
reference-only; never imported. Any Swift code that calls `LAContext`
directly outside `Epistemos/Sovereign/` is a violation.

---

## 10. Verification gates — greppable invariants

These run after every Phase. They are mechanical, not subjective. CI must
enforce them.

```bash
# 10.1 — Kernel loop singularity
grep -rn 'fn agent_loop\|class.*AgentLoop\|def agent_loop' \
  agent_core/ Epistemos/ hermes-agent/ \
  --include='*.rs' --include='*.swift' --include='*.py' \
  | grep -v 'agent_core/src/agent_loop.rs' \
  | grep -v 'cfg(feature = "hermes_subprocess")'
# expected: zero hits (or only callers, never definitions)

# 10.2 — No subprocess outside Pro-gated modules
grep -rn 'Process()\|NSTask\|Command::new\|posix_spawn\|fork\|exec' \
  Epistemos/ agent_core/ XPCServices/ \
  --include='*.swift' --include='*.rs' \
  | grep -v 'cfg(feature = "pro")' \
  | grep -v '// PRO_ONLY:' \
  | grep -v '// SAFETY:'
# expected: every remaining hit must be inside a Pro-gated module or
#           an explicit allowlist comment

# 10.3 — Sovereign single-owner
grep -rn 'LAContext\|canEvaluatePolicy\|evaluatePolicy' \
  Epistemos/ \
  --include='*.swift' \
  | grep -v 'Epistemos/Sovereign/'
# expected: zero hits

# 10.4 — Canonical naming (no Epistenos typo)
grep -rn 'Epistenos\|epistenos' \
  Epistemos/ agent_core/ XPCServices/ omega-mcp/ \
  --include='*.swift' --include='*.rs'
# expected: zero hits

# 10.5 — Provenance ledger singularity
grep -rn 'enum AgentProvenanceEvent\|enum.*ProvenanceEvent\|class.*ProvenanceRing' \
  Epistemos/ agent_core/ \
  --include='*.swift' --include='*.rs' \
  | grep -v 'agent_core/src/events/'
# expected: zero hits

# 10.6 — Build matrix
xcodebuild -scheme Epistemos          -destination 'platform=macOS' build 2>&1 | xcbeautify
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build 2>&1 | xcbeautify
cargo build --manifest-path agent_core/Cargo.toml --lib --no-default-features --features ""
cargo build --manifest-path agent_core/Cargo.toml --lib --no-default-features --features "pro"
cargo build --manifest-path agent_core/Cargo.toml --lib --no-default-features --features "pro,research"
# expected: all four pass

# 10.7 — Test matrix
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features ""
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features "pro"
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features "pro,research"
# expected: all three pass with zero regressions

# 10.8 — Hot-path verification
python3 scripts/verify_hotpath.py --profile mas
python3 scripts/verify_hotpath.py --profile pro
# expected: both pass
```

---

## 11. The kernel composition order

When wiring, sequence matters. This is the dependency-correct order:

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1 — Foundation (already mostly shipped)                   │
│  - agent_core::events::AgentEvent  (canonical enum)             │
│  - agent_core::resonance           (committed 06230e8d, 07e33fed)│
│  - agent_core::effect::receipt     (Capability::BiometricSession)│
│  - Epistemos/Sovereign/SovereignGate.swift                      │
└─────────────────────────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2 — Capability lattice  (Phase 6 — earliest possible)     │
│  - agent_core::capability::tier                                 │
│  - agent_core::capability::lattice                              │
│  - registry filtering by PolicyProfile                          │
└─────────────────────────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3 — In-process bundled MCP  (Phase 4)                     │
│  - omega-mcp::inproc::*  (vault, search, fetch, think, todo,    │
│                           calc as Rust modules)                 │
│  - subprocess MCP path moved behind cfg(feature = "pro")        │
└─────────────────────────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4 — WASM exec sandbox  (Phase 3)                          │
│  - agent_core::exec::wasm_runtime                               │
│  - Resources/Wasm/ bundled modules                              │
│  - Tool registry: exec_python_wasm, exec_javascript, exec_wasm  │
│  - JIT entitlement added to MAS scheme                          │
└─────────────────────────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 5 — Hermes-in-Rust kernel  (Phase 2 — biggest)            │
│  - agent_core::hermes::prompt_format                            │
│  - agent_core::hermes::function_call                            │
│  - agent_core::hermes::skills                                   │
│  - agent_core::hermes::procedural_memory                        │
│  - agent_core::hermes::self_evolution                           │
│  - hermes-agent Python subprocess moved behind                  │
│    cfg(feature = "hermes_subprocess") — removed in next pass    │
└─────────────────────────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 6 — Loop unification  (final collapse)                    │
│  - Swift LocalAgentLoop becomes thin caller of kernel via UniFFI │
│  - AgentXPC/ProviderXPC verified as pass-through (no shadow      │
│    state)                                                        │
│  - omega-mcp dispatcher verified as protocol-only (no caching)   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12. The closing commitment

One agent loop. One memory store. One provenance ledger. One skill registry.
One privilege boundary. One binary. Five layers stacked, not five orchestrators
racing.

The Linux analogy is not metaphor. It's structural:

- Agent loop = scheduler
- Skills + tools = syscall table
- Procedural memory = page cache
- Provenance ledger = audit subsystem (auditd)
- Capability lattice = capabilities(7)
- Sovereign Gate = sudo + biometric
- WASM exec = bpf / userspace VM
- XPC services = privilege-separated helpers
- MLX-Swift in-process = hardware fast path
- Resonance Gate = the truth oracle that the kernel itself reads

When this lands, Epistemos is not "a Mac app with AI in it." It's a sovereign
cognitive substrate where every action has an event, every event has a
provenance, every provenance has a verdict, every verdict has a witness, and
every witness lives inside the same binary the user double-clicks. The
kernel does the work, the renderer shows the result, the gate enforces the
trust, the sandbox holds the chaos.

> One kernel. One binary. One sovereign substrate. Build it.

---

## 13. The Cognitive DAG synthesis (§§3-12 collapse into one structure)

Sections 3 through 12 describe seven coexisting subsystems: agent loop, skills
registry, procedural memory, tool registry, vault, provenance ledger,
resonance gate, capability lattice, companions, WASM exec. They live in one
binary — but they're seven *things* in one binary. That's a legitimate
unification. It's not the deepest one.

**The deepest unification: collapse all seven into one typed,
content-addressed cognitive DAG.** Same data structure, different node and
edge types. Every subsystem becomes a *traversal pattern* over the DAG, not
a separate store with its own state.

### 13.1 The schema

```
NODES (every node is a content-addressed BLAKE3-hashed blob)
  ├── Note          (vault content; user authorship)
  ├── Claim         (Resonance Gate truth-bearing assertion)
  ├── Evidence      (citation, retrieval result, screenshot, tool output)
  ├── Skill         (named subgraph: composes Tools + other Skills)
  ├── Tool          (leaf — Rust function or WASM module reference)
  ├── Procedure     (procedural memory entry: skill invocation trace)
  ├── Event         (AgentEvent: every action ever taken)
  ├── Companion     (LoRA-light identity attached to root + base Model)
  ├── Capability    (typed grant: scope, expiry, witness, biometric class)
  └── Model         (weight set; LoRAs are diff nodes pointing back to base)

EDGES (typed; every edge is a Merkle-signed pointer)
  ├── derives_from  (Claim → Evidence — what supports a claim)
  ├── contradicts   (Claim → Claim — incompatible truth-bearing pair)
  ├── invokes       (Skill → Tool / Skill — composition)
  ├── witnessed_by  (Event → Capability — what authorized the action)
  ├── authorized_by (Capability → Sovereign Gate session)
  ├── recorded_by   (Procedure → Event[] — trace)
  ├── owned_by      (Companion → Procedure[] / Skill[] — personality state)
  ├── deforms       (Companion → Model + LoRA diff)
  └── caches        (MemoryTier → Node[] — retrieval index, not source)
```

### 13.2 The seven subsystems as traversal patterns

| Subsystem (kernel framing)        | DAG framing                                                              |
|---|---|
| Agent loop                        | Graph traversal scheduler: BFS over `invokes`, fold tool outputs as new nodes |
| Vault                             | Persistent content-addressed blob store (the DAG's storage backend)       |
| Skills registry                   | Subgraph index keyed by skill name                                        |
| Procedural memory                 | `recorded_by` edge cache, retrieved by similarity over `Procedure` blobs  |
| Provenance ledger                 | The DAG itself, Merkle-rooted (event ledger = the DAG's natural history)  |
| Resonance Gate                    | Continuous truth re-evaluation propagating along `derives_from` and `contradicts` edges |
| Capability lattice                | `authorized_by` edge type system, statically checked                      |
| Companions                        | `deforms` nodes attached to root; lightweight per-companion LoRAs         |
| Memory tiers (L0-L_SE)            | Caching strategies over node access frequency                             |
| WASM exec                         | Deterministic leaf-node execution (Tool nodes referencing WASM modules)   |
| Sovereign Gate                    | Capability-issuance authority; sessions become DAG roots for grants       |

### 13.3 What this unlocks (the part that's actually new)

1. **Verifiable replay.** Every conversation is a DAG traversal trace. Hand someone a session export → they replay it byte-for-byte and verify outputs, tool calls, trust grants. No other personal-AI app has this.

2. **Cascading invalidation.** When evidence is retracted, Resonance flips that node's truth value and propagates along `derives_from` edges. Every dependent claim updates automatically. Spreadsheet for truth.

3. **Companions are KB, not GB.** Companion = `deforms(Model + LoRA-light)`. Base substrate is shared; only the LoRA diff is per-companion (~50MB). On a 16GB Mac, 50 companions can share one 4GB base model. Farm becomes economically real.

4. **Skills become git-portable.** Skill = subgraph. Export = serialize subgraph + content-addressed Tool refs. Import = verify hashes + register. Skill marketplace becomes possible because skills are *content-addressed verifiable artifacts*, not Python files you have to trust.

5. **Trust becomes compositional.** Capabilities are edges. They compose: "skill X invokable by companion Y on vault Z for the next hour." Macaroon-style bearer credentials applied to cognitive actions. Sovereign Gate becomes a typed grant calculus, not just a Touch ID prompt.

6. **The doctrine becomes a linter.** Rules like "no parallel agent loops" become *graph schema constraints* enforced at compile time. The doctrine is a Rust crate that rejects PRs violating the DAG schema. Architecture polices itself.

7. **Time travel for cognition.** DAG is append-only + Merkle-rooted = git for thought. `git bisect` your reasoning. `git revert` a compromised capability grant and the kernel recomputes affected state.

### 13.4 The single sentence

> **Epistemos is a typed cognitive DAG running in one binary, where every
> node is content-addressed, every edge is capability-gated, every truth
> value is continuously re-evaluated, every action is provenance-witnessed,
> and every personality is a lightweight deformation of one shared
> substrate.**

### 13.5 The implementation tax (honest)

This is one to two phases of additional Rust work on top of the §11 composition order. Specifically:

- `agent_core/src/cognitive_dag/mod.rs` — node + edge type definitions
- `agent_core/src/cognitive_dag/storage.rs` — content-addressed storage layer (BLAKE3 + sled or rocksdb backend)
- `agent_core/src/cognitive_dag/traversal.rs` — BFS / DFS / similarity-keyed retrieval
- `agent_core/src/cognitive_dag/merkle.rs` — Merkle root + signed edge verification
- `agent_core/src/cognitive_dag/macaroons.rs` — compositional capability calculus
- Resonance propagation along `derives_from` and `contradicts` edges (~400 LOC extension to existing `agent_core::resonance`)
- LoRA-light companion model (depends on MLX-Swift's adapter API; needs research spike)

Substantial work. **But it makes the seven-subsystem version simpler**, because each subsystem becomes a traversal helper instead of a separate store with its own persistence, indexing, and consistency rules. Net code is probably *less* than the seven-subsystem version, just denser.

### 13.6 Phase placement (do not disrupt current Codex sprint)

The DAG synthesis is **Phase 8**, not a replacement for Phases 1-7. Codex completes the kernel doctrine work first (audit → Hermes-in-Rust → WASM → in-proc MCP → migration matrix → capability lattice → doctrine doc). Phase 8 lands AFTER, as the deeper unification. Until then, the DAG framing is documented for forward visibility but not yet implemented; the seven subsystems remain the operating model.

### 13.7 Why ship the kernel doctrine first

Shipping the DAG schema before the seven subsystems are unified into one Rust kernel would require simultaneously refactoring across Swift, Rust, Python, and the in-tree research code — too many variables changing at once. The kernel doctrine collapses Swift/Python/parallel-Rust into one Rust kernel. Then the DAG synthesis collapses the unified Rust kernel's seven subsystems into one schema. Two compositions, one direction.

> First one binary. Then one DAG inside that binary. Then publish the paper.

---

## Appendix A — Doctrinal cross-references

```
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md   ← this doc (canon)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md (substrate framing)
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md     (Kimi/GPT as reference)
docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md     (foundational doctrine)
docs/fusion/JORDANS_RESEARCH_INDEX_2026_05_03.md       (research index)
docs/fusion/CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md (Codex catch-up)
docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md        (research authority)
docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md       (drift log)
CLAUDE.md                                              (NON-NEGOTIABLE constraints)
```

## Appendix B — Audit deliverable shape (Phase 1 output)

`docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_03.md` — produced by Codex in
Phase 1. Must include:

1. The fragmentation table from §2 above, populated against actual repo
   greps (file paths + line numbers + verdict + action).
2. The complete list of entry points the kernel ABI must expose (§3).
3. Every Tool currently registered in `agent_core::tools::registry` with its
   tier classification (Core / Pro / Research) cited from the migration
   matrix in §7.
4. Every Skill currently in the Python `hermes-agent/skills/` folder with a
   one-line summary of what it does and whether it should be ported into
   the Rust registry directly or re-derived for unification.
5. Every parallel implementation found in Swift / Python / Rust outside the
   canonical paths, with `keep | collapse | reject` verdict.
6. A "drift surfaces" section listing anything Kimi/GPT mockups proposed
   that conflicts with the doctrine — must be rejected per fusion handoff
   §3 conflict-resolution rules.

## Appendix C — Migration matrix deliverable shape (Phase 5 output)

`docs/fusion/PRO_TO_CORE_MIGRATION_2026_05_03.md` — produced by Codex in
Phase 5. Must include:

1. The full table from §7 above with one row per capability.
2. For every Core-migrated row: cite the in-tree commit or PR that
   implements the migration, plus the Apple entitlement (if any) it relies
   on.
3. For every stays-Pro row: cite the specific App Sandbox rule that
   forbids it, with link to Apple developer documentation.
4. A "review-readiness" checklist: every entitlement requested in the MAS
   build's `Epistemos-AppStore.entitlements` file with a one-paragraph
   justification suitable for App Review submission notes.
5. A "future MAS unlocks" section: capabilities currently Pro-only that
   could move to Core in V2 with additional engineering (e.g. iMessage via
   Messages framework, computer use via accessibility prompts).
