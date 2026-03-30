# EPISTEMOS ARCHITECTURAL GAP ANALYSIS
## Cross-Document Audit of All 8 Specification Files

**Methodology**: Every type, trait, struct, and function referenced in EPISTEMOS_REAL_AGENTS.md (3,935 lines), MASTER_BUILD_SPEC.md, v1.md, v1.1_ADDENDUM.md, and the 4 research documents was traced to its definition. Items referenced but never defined are gaps. Items defined but with structural flaws are improvements.

---

## CRITICAL GAPS (Block Week 1 Completion)

### Gap 1: `VaultBackend` Trait — Referenced 12 times, never defined

**Referenced in**: `ToolRegistry::new()`, `bootstrap_context()`, `vault_search()`, `vault_read()`, `vault_write()`, `hybrid_search()`

The entire tool system depends on this trait. Without it, no tool handler compiles.

**Required interface** (inferred from all call sites):
```
- search(query, limit) → Vec<String>
- hybrid_search(query, limit, tags) → Vec<SearchResult>
- read(path) → String
- write(path, content, tags, append) → ()
- list(path_prefix) → Vec<String>
- exists(path) → bool
```

**Status**: ❌ Not defined anywhere

---

### Gap 2: `SessionStore` / `GLOBAL_SESSIONS` — Referenced, never implemented

**Referenced in**: `cancel_agent_session()` calls `GLOBAL_SESSIONS.cancel(&session_id)`

The cancellation system depends on a global session registry that maps session IDs to `CancellationToken` instances. Without it, users cannot stop a running agent.

**Status**: ❌ Not defined anywhere

---

### Gap 3: `AgentConfig::from_ffi()` — Called, never implemented

**Referenced in**: `run_agent_session()` at line 2587: `let config = AgentConfig::from_ffi(&agent_config);`

Converts `AgentConfigFFI` (UniFFI-safe flat struct) to `AgentConfig` (rich Rust struct with enums). Without this, the bridge doesn't compile.

**Status**: ❌ Not defined anywhere

---

### Gap 4: HTTP Error Recovery / Retry Logic — Completely absent

The `ClaudeProvider` has zero retry logic. A single 429 (rate limit) or 500 (server error) kills the entire agent session.

Production requirement: exponential backoff with jitter for 429/500/502/503, immediate fail on 400/401/403.

**Status**: ❌ Not implemented

---

### Gap 5: `OmegaPanel` SwiftUI View — Partially sketched, not complete

The ViewModel is solid (lines 2800-2990) but the actual SwiftUI view that renders thinking/tools/response with phase-based transitions is only mentioned, never written.

**Status**: ❌ Incomplete

---

## STRUCTURAL FLAWS (Compile but produce bugs)

### Flaw 1: Context Compaction Uses `Debug` Format

Line 819: `format!("{:?}", m)` to serialize messages for compaction.
`Debug` output is not valid JSON. Claude would receive garbled Rust struct syntax as the "conversation to summarize." This silently produces garbage summaries.

**Fix**: Use `serde_json::to_string(m)` for proper JSON serialization.

---

### Flaw 2: AsyncStream `.unbounded` Buffering

Line 2832: `AsyncStream<AgentEvent>.makeStream(bufferingPolicy: .unbounded)`

If a long agent run produces thousands of events faster than SwiftUI can render, memory grows without bound. On a 10-minute Opus session with interleaved thinking, this could reach hundreds of MB.

**Fix**: `.bufferingNewest(256)` — drop oldest events if consumer is slow. Token deltas are additive so dropping old ones just means the UI catches up.

---

### Flaw 3: `wait_for_permission` Has No Timeout

Line 2770: `semaphore.wait()` blocks the tokio thread indefinitely.

If the user never responds (closes the window, app crashes), the tokio thread is permanently blocked. With enough pending permissions, the entire tokio runtime starves.

**Fix**: `semaphore.wait(timeout: .seconds(120))` — auto-deny after 2 minutes.

---

### Flaw 4: `Task.detached` Loses Cancellation Propagation

Line 2856: `Task.detached(priority: .userInitiated)` starts the Rust bridge call.

`Task.detached` creates an unstructured task that doesn't propagate cancellation from the parent. The `stop()` method calls `currentTask?.cancel()` but this only sets a flag — the Rust side doesn't check Swift's cancellation, only its own `CancellationToken`.

**Fix**: The cancellation token must be stored per-session and `stop()` must call both `currentTask?.cancel()` AND `cancelAgentSession(sessionId:)`.

---

### Flaw 5: `ToolDefinition` Type Collision

Two different `ToolDefinition` types exist:
1. `agent_core::tools::registry::ToolDefinition` — has `handler` and `risk_level`
2. `agent_core::types::ToolDefinition` — just name/description/parameters (for API serialization)

`get_definitions()` at line 2066 creates the API type from the registry type, but the names collide. This requires disambiguation everywhere.

**Fix**: Rename the API type to `ToolSchema` to avoid collision.

---

### Flaw 6: Recipe Cache Hash Collision Risk

The normalization at line 3593 strips all punctuation, collapses whitespace, and lowercases. This means:
- "Write a Python function" and "write a python function!" hash identically ✓
- "Write a Python function" and "Write a Rust function" hash differently ✓
- But "Find my notes about X" and "Find my notes about Y" hash differently even when X and Y are semantically identical

**Fix**: Phase 2 improvement — use embedding-based semantic hashing with a similarity threshold instead of exact string hashing.

---

## MISSING FILES MANIFEST

To complete Week 1, these files must exist:

```
agent_core/src/
├── lib.rs                    ← crate root, module declarations
├── types.rs                  ✅ Defined in REAL_AGENTS §1.2
├── provider.rs               ✅ Defined in REAL_AGENTS §1.2
├── agent_loop.rs             ✅ Defined in REAL_AGENTS §2.2
├── bridge.rs                 ✅ Defined in REAL_AGENTS §5.1
├── context.rs                ✅ Defined in REAL_AGENTS §Pattern 6
├── prompts.rs                ❌ TOOL_PREFERENCE_RULES constant referenced, file not created
├── error.rs                  ❌ Retry logic, error classification
├── session.rs                ❌ GLOBAL_SESSIONS, CancellationToken registry
├── providers/
│   ├── mod.rs                ❌ Module declarations
│   ├── claude.rs             ✅ Defined in REAL_AGENTS §2.1
│   └── perplexity.rs         ❌ Mentioned, no code
├── tools/
│   ├── mod.rs                ❌ Module declarations  
│   ├── registry.rs           ✅ Defined in REAL_AGENTS §4.1
│   ├── vault_tools.rs        ✅ Partially defined in REAL_AGENTS §4.2
│   ├── bash_tool.rs          ✅ Partially defined in REAL_AGENTS §4.2
│   └── web_tool.rs           ❌ web_search handler not implemented
├── storage/
│   ├── mod.rs                ❌ Module declarations
│   ├── vault.rs              ❌ VaultBackend trait + VaultStore implementation
│   └── recipe_cache.rs       ✅ Defined in REAL_AGENTS §Pattern 5
└── routing.rs                ✅ Defined in REAL_AGENTS §Pattern 7

Swift side:
Epistemos/
├── Bridge/
│   └── StreamingDelegate.swift   ✅ Defined in REAL_AGENTS §5.2
├── ViewModels/
│   └── AgentViewModel.swift      ✅ Defined in REAL_AGENTS §5.3
├── Views/
│   └── OmegaPanel.swift          ❌ Not implemented
├── LocalAgent/
│   ├── HermesPromptBuilder.swift  ✅ Defined in REAL_AGENTS §3.1
│   ├── LocalToolGrammar.swift     ✅ Defined in REAL_AGENTS §3.2
│   ├── LocalAgentLoop.swift       ✅ Defined in REAL_AGENTS §3.3
│   └── ConfidenceRouter.swift     ✅ Defined in REAL_AGENTS §3.4
└── ComputerUse/
    └── ComputerUseProvider.swift  ❌ Protocol defined, no implementation
```

---

## BUILD ORDER VALIDATION

The REAL_AGENTS doc prescribes Week 1 as:
1. types.rs → 2. provider.rs → 3. claude.rs → 4. registry.rs → 5. loop.rs → 6. bridge.rs → 7. StreamingDelegate → 8. AgentViewModel → 9. OmegaPanel

**Actual dependency chain** (what must exist for compilation):

```
types.rs ← provider.rs ← claude.rs
                ↑
types.rs ← tools/registry.rs ← tools/vault_tools.rs
                ↑                       ↑
         storage/vault.rs ──────────────┘  (VaultBackend trait)
                
provider.rs + tools/registry.rs ← agent_loop.rs
                                       ↑
                                  bridge.rs ← session.rs (GLOBAL_SESSIONS)
                                       ↑
                                  error.rs (retry logic)

bridge.rs (Rust) → UniFFI codegen → StreamingDelegate.swift
                                  → AgentViewModel.swift
                                  → OmegaPanel.swift
```

**The critical path gap**: `storage/vault.rs` blocks `tools/vault_tools.rs` which blocks `tools/registry.rs` which blocks `agent_loop.rs`. Everything downstream is blocked.
