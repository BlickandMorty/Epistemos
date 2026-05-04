# EPISTEMOS: THIS IS WHERE YOU ARE
## Unified State Assessment — All Worktrees, All Branches, All Nuance Preserved

**Date**: 2026-05-02 | **Assessment Version**: 2.0 (post-worktree audit)
**Branches Analyzed**: `feature/landing-liquid-wave` (main/Codex), `simulation` (worktree), `claude/vigorous-goldberg` (Quick Capture), plus `epistemos-shadow`, `omega-mcp`, `graph-engine`
**Total Test Coverage Across All Crates**: 3,832 Rust tests | **Total Clippy Warnings**: 39 (agent_core, down from 118)

---

# THE EXECUTIVE TRUTH

## What Is Real

You do not have one branch. You have a **constellation of five Rust crates**, three active worktrees, and approximately **3,832 passing tests** across the workspace. The "true progress" is not just the Codex work on `feature/landing-liquid-wave` — it is the entire workspace, but critically, **most of it lives in worktrees that have diverged from each other**.

**The canonical substrate spine** (agreed by all branches):

```
TypedArtifact → MutationEnvelope → RunEventLog → AgentEvent → GraphEvent → Halo / Graph / Theater / Audit
```

This is the unified substrate. Everything else is a surface on top of this spine.

## The Three-Layer Reality

| Layer | What It Is | Status |
|-------|-----------|--------|
| **Core/MAS** | App Store-safe, local-first, vault-scoped | OpLog + ETL + provenance DONE on main |
| **Pro** | Full autonomy: Hermes CLI, MCP tunnels, browser, computer-use | CLI unfinished. MCP (omega-mcp) has 131 tests. Browser tools exist in v2 catalog |
| **Research** | Neural-kernel, KV snapshots, activation steering | Not started (correctly gated) |

## The Honest Assessment: Where You Actually Are

You are **not** at "substrate 85% done, need Governor." You are at:

- **Substrate layer**: Provenance (OpLog, TypedArtifact, MutationEnvelope) is **production-grade**
- **Agent layer**: `agent_core` has 762 tests, 56+ tools in v2 catalog, agent loop, provider routing — this is **substantially built**
- **Tool layer**: `LEGACY_TO_V2_ALIASES` table maps 56 underscored tool names to dotted v2 names. Tool dispatch routes through `Tool::invoke`
- **Memory layer**: sqlite-vec + petgraph foundation exists, FSRS scheduler implemented, Contextual Shadows V0 operational
- **Simulation layer**: `simulation` worktree has DOCTRINE v1.6, Metal theater, pixel-art mascots, knowledge-brick sidebar — **frozen, not merged**
- **Search layer**: `epistemos-shadow` (45 tests) provides shadow search FFI
- **MCP layer**: `omega-mcp` (131 tests) provides Model Context Protocol integration
- **Graph layer**: `graph-engine` (2,508 tests) is the largest crate — full graph system

**The gap is not "missing substrate." The gap is "unmerged worktrees and a missing CLI."**

---

# PART I: THE WORKTREE INVENTORY

## 1.1 `feature/landing-liquid-wave` — The Main Branch (Codex)

**Status**: Active. This is where Codex has been working.

**What exists**:
- OpLog Swift Bridge (PR1): 16 Rust + 3 Swift tests, BLAKE3 prev_hash chain
- EventStore→OpLog Projection (PR2): 11 Swift + 3 boundary tests, idempotent projection
- Lease/Retry (PR3A): 13 Swift tests, owner-guarded lease clearing
- Dead-Letter (PR3B): 14 Swift tests, bounded dead-lettering
- Worker Scheduling (PR3C): Worker dispatch, drain path
- Diagnostics (PR3D): Health rows, EventStore diagnostics API
- ETL Queue (R16 PR2 + PR3a-d): Apalis SQLite queue, typed jobs, AFM sidecar generation
- KIVI KV Cache (W9.30): Opt-in, unit tests pass, blocked on MLX metallib runtime
- FSRS Decay State (R12): Rust bridge, GRDB persistence, retrievability computation
- sqlite-vec + petgraph (R13): Vector search + graph database foundation
- Contextual Shadows V0 (Halo): Shadow backend route, 17 Swift tests
- Conversation State Dispatch (W10.16): 11 Swift tests, stable `conversationStateId`
- Benchmark JSON Recorder (R15): 2 Swift tests, machine-readable output

**Files**: 34 changed, +3,471/-116 lines

**Assessment**: The provenance and ETL substrate is **genuinely production-grade**. This is not "prototype" code — it has lease semantics, dead-lettering, worker dispatch, and diagnostics. It is the most solid foundation in the entire workspace.

## 1.2 `simulation` Worktree — Frozen

**Status**: Frozen per Claude's directive. DO NOT continue coding here.

**What exists**:
- DOCTRINE.md v1.6: 361 lines of doctrine covering simulation mode
- IMPLEMENTATION.md v1.6: Plan version 1.6 with 11 sections
- Landing Farm (S5): Metal-rendered pixel-art companion farm
- Graph Live Theater (S7): Multi-room theater, one room per active session
- Notes Sidebar (S6): Knowledge-brick design language, three-level picker (Company → Model → Agent)
- Hermes Landing Ritual (S9): 7-phase opulent canonical sequence
- Provider Brand Icon System (S5.6): LobeHub icon fetcher, color/mono Swift consumers
- Metal rendering pipeline: Nearest-neighbor sampling, integer scale, snap-to-pixel (I-16)
- 6 new `AgentEvent` variants: `SteerRequested`, `SummaryStarted`, `SummaryDelta`, `SummaryCompleted`, `VaultCreated`, `VaultArchived`
- Pixel-art mascot system: Tamagotchi-style companions at agent leaves
- Multi-vault UI: Per-entity `vault/` + `vaults/` sibling directories

**Donor value**: The simulation DOCTRINE and design language are **valuable reference material**. The Metal rendering contracts (I-16 bit-perfect pixel) are hard-won. The multi-room theater architecture is sophisticated. The knowledge-brick sidebar language can inform the main app's UI.

**Merge risk**: HIGH. The simulation worktree touches MTKView, Metal pipelines, pixel-art atlases, and a completely separate render thread. Do NOT merge raw. Extract patterns and design language only.

## 1.3 `claude/vigorous-goldberg` — Quick Capture Worktree

**Status**: Frozen. Used as prototype/reference only.

**What exists**:
- `LEGACY_TO_V2_ALIASES`: 56-entry table mapping underscored tool names to dotted v2 names
- `execute_v2` alias resolution: Legacy names route through `Tool::invoke` instead of legacy `execute()`
- TodoHandler native `Tool` impl (Phase 2G-4a): First non-test handler implementing `Tool` directly
- 742 lib tests passing in `agent_core`
- Pattern documented for replicating across ~24 remaining files
- `build_v2_catalog` constructs handlers directly via `Box::new(<Handler>) as Box<dyn Tool>`

**Donor value**: The v2 tool catalog migration is **critical architecture**. The alias table ensures backward compatibility while moving to the new `Tool::invoke` dispatch. The TodoHandler canary demonstrates the conversion pattern. This should be extracted and rebuilt on main cleanly.

**Merge risk**: MEDIUM. The alias table and canary pattern are self-contained. The remaining ~54 `impl ToolHandler` blocks across 24 files need file-by-file conversion — this is mechanical but touches many files.

## 1.4 `epistemos-shadow` Crate

**Status**: Independent crate. 45 tests passing. 7 clippy warnings.

**What exists**:
- `shadow_insert_json`: FFI for document insertion
- `shadow_remove_json`: FFI for document removal
- `shadow_search_json`: FFI for search (returns JSON-encoded hits)
- `shadow_free_string`: Memory management for FFI returns
- `shadow_open_at`: Backend initialization
- All unsafe FFI functions have `# Safety` markdown docs (fixed in hardening pass)
- W9.21 known-failure fixed: `borrow_preserves_refcount` was reading freed memory due to `&Arc::from_raw` temporary misuse

**Assessment**: This is a **functional search backend** with FFI boundaries. The shadow system provides the "vault search" capability that tools rely on. It is not scrapped — it is a real crate that should be integrated.

## 1.5 `omega-mcp` Crate

**Status**: Independent crate. 131 tests. 13 clippy warnings.

**What exists**:
- Model Context Protocol implementation
- JSON-RPC over stdio and Streamable HTTP
- MCP discovery, tool advertisement, capability negotiation

**Assessment**: MCP is the **Pro tunnel architecture**. It enables external tools (browser, computer-use, Docker) to connect to the app through a protocol boundary. This is correctly positioned as Pro-tier, not Core.

## 1.6 `graph-engine` Crate

**Status**: Independent crate. **2,508 tests**. This is the largest crate.

**What exists**:
- Full graph database engine
- Entity-relationship graph operations
- Graph queries, navigation, neighbor traversal
- Likely the backend for `GraphEvent` processing

**Assessment**: The graph engine is **massive and well-tested**. It is a core substrate component, not scrapped. The dirty files in `graph-engine/**` that Codex has been working around are in this crate.

## 1.7 `epistemos-core` Crate

**Status**: Independent crate. 366 tests. 59 clippy warnings.

**What exists**:
- Core types and FFI exports
- UniFFI UDL definitions
- Swift bridge foundations

**Assessment**: This is the **FFI backbone**. It connects Swift UI to Rust backend. The `epistemos-core/uniffi/epistemos_core.udl` file defines the interface contract.

## 1.8 `substrate-core` Crate

**Status**: Independent crate. 7 tests. 6 clippy warnings.

**What exists**: Foundation substrate types and utilities.

---

# PART II: WHAT HAS ACTUALLY BEEN BUILT

## The Full Workspace Test Matrix

| Crate | Tests Passing | Clippy Warnings | Notes |
|-------|--------------|-----------------|-------|
| `agent_core` | 762 lib + 13 integration | 39 (was 118) | The heart. Tools, agent loop, providers, registry |
| `epistemos-shadow` | 45 | 7 (was 12) | Search FFI backend |
| `omega-mcp` | 131 | 13 | MCP protocol integration |
| `graph-engine` | 2,508 | (not swept) | Graph database — largest crate |
| `epistemos-core` | 366 | 59 | FFI bridge, UDL |
| `substrate-core` | 7 | 6 | Foundation types |
| **Total** | **3,832** | **~124 total** | Zero compiler warnings, zero test failures |

## The `agent_core` v2 Tool Catalog

The following tools exist in the v2 catalog (from `LEGACY_TO_V2_ALIASES` and test verification):

### Knowledge & Vault
- `vault.search` / `vault.read` / `vault.write`
- `knowledge.recall` / `knowledge.contradiction_check` / `knowledge.neural_recall` / `knowledge.session_search`
- `memory.curated`

### File & Workspace
- `file.read` / `file.write` / `file.patch` / `file.search`
- `workspace.search` / `workspace.find_symbol` / `workspace.get_function_source` / `workspace.get_dependencies` / `workspace.get_dependents` / `workspace.get_change_impact`
- `chunk.reduce`

### Action & System
- `action.bash` / `action.terminal`
- `system.todo` / `system.cron` / `system.process`

### Web & Communication
- `web.search` / `web.extract` / `web.crawl` / `web.fetch`
- `communication.send_message` / `communication.imessage` / `communication.imessage_contacts` / `communication.channel_contacts`

### Apple Ecosystem
- `apple.notes` / `apple.reminders` / `apple.calendar` / `apple.mail`

### Media & Vision
- `media.vision_analyze` / `media.image_generate` / `media.text_to_speech`

### Discovery
- `discovery.mcp_discover` / `discovery.model_catalog`

### Intelligence & Reasoning
- `intelligence.self_evolve` / `intelligence.mixture_of_minds`
- `reason.think`

### Browser
- `browser.navigate` / `browser.snapshot` / `browser.click` / `browser.type` / `browser.scroll` / `browser.back` / `browser.press` / `browser.close` / `browser.get_images` / `browser.vision` / `browser.console`

### Graph
- `graph.neighbors` / `graph.query` / `graph.vault_navigate`

### Trajectory & Skills
- `trajectory.export`
- `skills.list` / `skills.view` / `skills.manage`

### Delegate-Bound (Pro-tier)
- `clarify.ask` / `macos.perceive` / `macos.interact` / `macos.screen_watch`
- `inference.ssm_resume` / `inference.constrained_generate` / `inference.route_private`
- `intelligence.nightbrain_trigger` / `intelligence.inline_partner`

**Total**: 56+ tools across 15 categories. This is not "no Agent Runtime." This is a **substantial agent system** with comprehensive tool coverage.

## What the Agent Runtime Actually Has

From the `agent_core` crate analysis:

- **Agent loop**: `agent_loop.rs` — multi-turn loop with state management
- **Provider routing**: `providers/claude.rs`, `providers/openai.rs`, etc. — provider-specific stream handling
- **Tool dispatch**: `tools/registry.rs` — v2 catalog with 56+ tools, alias resolution, permission gating
- **Context loading**: `context_loader.rs` — vault-root based context assembly with tagged layers
- **Raw thoughts**: `storage/raw_thoughts.rs` — persistent thought storage
- **Session insights**: `session_insights.rs` — analytics, tool breakdown, notable sessions
- **Security**: `security.rs` / `tirith.rs` — threat assessment, sandboxing
- **Evolution**: `evolution/mutation_proposer.rs` — self-modification proposals with frontmatter parsing
- **Replay**: `provenance/replay.rs` — deterministic replay (Phase-1 keystone)
- **Ledger**: `provenance/ledger.rs` — audit ledger with force-unwrap denied

**Assessment**: The Agent Runtime is **not missing**. It exists in `agent_core` and is extensively tested. What is missing is the **Swift-side UI integration** and the **Hermes CLI tunnel**.

---

# PART III: THE CLI STATUS — UNFINISHED

## What Claude Started

The CLI integration was started by Claude (not Codex) in a previous session. From the conversation log, the CLI was intended to be:

- Hermes CLI Tunnel V1/V2
- Local coding agent interface
- Read/change/run code in selected directory
- MCP protocol integration for external tools

## What Codex Never Finished

Codex was supposed to continue the CLI work but never did. From the current branch analysis, the CLI-related files are:

- `agent_core/src/security.rs::harden_cli_subprocess` — subprocess hardening helpers exist
- `SUBPROCESS_ALLOWLIST` — 10 environment variables (PATH, HOME, USER, etc.)
- Output-bound caps on `cli_passthrough.rs` and `registry.rs` bash subprocess paths (10 MiB cap)
- Doctrine names "Codex 1.8GB stdout regression" as one of the 13 hardest problems

**The CLI passthrough exists but is hardened, not expanded.**

## What Needs to Happen

The CLI is a **Pro-tier capability tunnel**. It should:
1. Use MCP protocol (omega-mcp crate) for tool advertisement
2. Connect to external agents (Claude Code, Codex) through stdio/Streamable HTTP
3. Maintain the same provenance spine (TypedArtifact → MutationEnvelope → RunEventLog)
4. Be gated behind Pro entitlement

**Status**: Architecture defined, subprocess hardening in place, but **the actual CLI server/listener is not implemented**.

---

# PART IV: RECONCILING THE ARCHITECTURES

## Four Architecture Documents Exist

| Document | Source | Status | Value |
|----------|--------|--------|-------|
| `EPISTEMOS_MASTER_ARCHITECTURE.md` | Kimi research synthesis | Superseded | Ternary/spectral/residency research is valid but the implementation plan is too abstract |
| `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md` | Claude fusion | **Canonical** | The "one substrate, gated surfaces" philosophy |
| `SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md` | Claude fusion | **Canonical** | What every source means and what can/can't ship |
| `CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md` | Claude fusion | **Canonical** | What the coding agent should do next |
| `DOCTRINE.md` v1.6 | Simulation worktree | **Donor** | Simulation design language, Metal contracts, knowledge-brick UI |
| `IMPLEMENTATION.md` v1.6 | Simulation worktree | **Donor** | Simulation build path — not the main app build path |
| `AGENTS.md`, `PLAN_V2.md`, `BOLTFFI_AUDIT` | Repo originals | **Canonical** | Verified-floor docs |

## The Unified Truth

**The real architecture is not the ternary-spectral-residency stack I researched.** That research is valuable as **future Research-tier direction**, but the buildable product is:

**Epistemos Verifiable Cognition Substrate**

A local-first cognitive workspace where:
- Every model, tool, note, raw thought, file edit, recall, artifact, and agent action becomes **typed**
- Every action is **provenance-linked** (BLAKE3 + Merkle chain)
- Every action is **retrievable** (sqlite-vec + petgraph + shadow search)
- Every action is **replayable** (deterministic event log)
- Every action is **policy-gated** (Core/MAS vs Pro vs Research)

**This is the buildable moat.** "Neural OS" is the future myth. "Verifiable cognition substrate" is what ships.

## What from My Research Applies

| Research Output | Applies How | Tier |
|-----------------|-------------|------|
| Ternary logic (Kleene K3, Belnap FDE) | **Future.** Add to ClaimState as formal logic operations | Research |
| Residency Governor (rate-distortion) | **Future.** Memory policy layer for Context Governor | Research |
| Spectral memory (Laplacian, Koopman) | **Future.** When graph engine needs real-time spectral features | Research |
| Golden scheduling (φ-intervals) | **Future.** Task scheduling optimization | Research |
| 5-tier verification (T0-T4) | **Partial now.** Proptest T2 can be added immediately. Kani/Z3 deferred | Core |
| QOFT/QDoRA adapters | **Future.** Continual learning for model specialization | Research |
| HCache brain-state checkpointing | **Future.** Fast context switching | Pro |
| FSRS scheduler | **NOW.** Already implemented in Rust bridge | Core |
| sqlite-vec + petgraph | **NOW.** Already implemented as foundation | Core |
| KIVI KV compression | **NOW (opt-in).** Blocked on MLX metallib, correctly gated | Pro |
| Biometric safety / Dark Node | **NOW.** Secure Enclave integration | Core |

**Key insight**: My deep research produced a **Research-tier architecture vision**. The actual codebase has been building **Core-tier substrate** with some Pro-tier tooling. The research is NOT wasted — it defines the 2-3 year evolution path. But the immediate build plan must match the actual codebase.

---

# PART V: THE CORRECTED GAP ANALYSIS

## What Is Actually Missing (Prioritized)

### 🔴 CRITICAL: Worktree Reconciliation

**The #1 problem is not missing code — it is divergent worktrees.**

| Worktree | Contains | Risk if Not Reconciled |
|----------|----------|----------------------|
| `simulation` | DOCTRINE v1.6, Metal theater, knowledge-brick | Permanently divergent UI architecture |
| `claude/vigorous-goldberg` | Tool v2 migration, 56 aliases, TodoHandler canary | Tool dispatch stays on legacy path |

**Solution**: Extract donor patterns, rebuild on main cleanly. Do NOT merge raw.

### 🔴 CRITICAL: CLI Unfinished

The Hermes/CLI tunnel is **the Pro-tier entry point**. Without it:
- No external agent integration (Claude Code, Codex)
- No browser/computer-use tools
- No Docker execution
- No MCP protocol value

**What exists**: omega-mcp crate (131 tests), subprocess hardening, MCP discovery tool
**What is missing**: The actual CLI server that listens for connections and routes to the agent runtime

### 🟡 HIGH: Context Governor (Not "Residency Governor")

The architecture needs a **Context Governor** — not the full spectral-residency system I specified, but a practical layer that:
- Decides what context to load for each turn (vault + raw thoughts + runs + sources)
- Uses hybrid retrieval (Model2Vec + usearch + Tantivy + RRF)
- Respects context window limits
- Tracks provenance of every loaded piece

This is **simpler than the Residency Governor** but solves the same user problem: "the local model always has the right context at the right time."

### 🟡 HIGH: Ternary Logic Formalization

`ClaimState` has `fits/waiting/falls` but lacks formal Kleene K3 operations. This is a **small, high-value addition** (~200 lines) that makes the epistemic system formally rigorous.

### 🟡 HIGH: Swift-Side Agent Runtime Integration

The Rust `agent_core` has the agent loop. The Swift side has `ChatCoordinator.runRustAgentPath` which is basic single-turn. The **Swift UI needs to integrate the full multi-turn agent runtime** with:
- Tool result display
- Streaming response handling
- Session management
- Companion switching

### 🟡 MEDIUM: Graph Engine Dirty Files

`graph-engine/**` has pre-existing dirty files that Codex has been working around. These need a **dedicated cleanup gate** with deliberation docs.

### 🟡 MEDIUM: Simulation Mode Merge

The simulation worktree has valuable UI patterns (knowledge-brick sidebar, multi-room theater) but cannot be merged as-is. Extract:
1. Knowledge-brick design language (typography, density, motion rules)
2. Multi-vault UI pattern (vault/ + vaults/)
3. AgentEvent variants (`SteerRequested`, `Summary*`, `Vault*`)
4. Metal rendering contracts (I-16 bit-perfect pixel)

Leave behind:
1. The actual Metal theater code (rebuild on main when needed)
2. The pixel-art mascot atlas (rebuild with canonical assets)
3. The full DOCTRINE (reference only, not authority)

### 🟢 LOW: Additional Substrate Hardening

The hardening loop has converged: 3,832 tests, zero failures, zero compiler warnings, 39 clippy warnings (down from 118). This is **good enough**. Further hardening is substrate theater.

---

# PART VI: THE CORRECTED BUILD ORDER

## Phase 0: Inventory & Fusion (1 day)

**Goal**: Produce one canonical inventory document.

1. Verify all worktrees are on disk and accounted for
2. List every crate, its tests, its purpose, its merge status
3. Identify donor code vs canonical code
4. Produce `WORKTREE_INVENTORY_2026_05_02.md`
5. **Stop. No code edits.**

## Phase 1: Tool v2 Migration on Main (3-5 days)

**Goal**: Bring the Quick Capture worktree's v2 tool catalog to main.

1. Port `LEGACY_TO_V2_ALIASES` to `agent_core/src/tools/registry.rs` on main
2. Replicate TodoHandler canary pattern for the remaining ~54 handlers
3. File-by-file conversion: 25 sub-commits, mechanical but careful
4. Verify: all 56 tools resolve through `Tool::invoke`
5. Tests: 742+ passing

**Why first**: Tool dispatch is the **heart of the agent system**. Everything else depends on it.

## Phase 2: CLI Server (5-7 days)

**Goal**: Finish the Hermes/CLI tunnel.

1. CLI listener/server using MCP protocol (omega-mcp)
2. stdio and Streamable HTTP transports
3. Route external agent requests through the same provenance spine
4. Subprocess execution with hardened allowlist
5. Gated behind Pro entitlement

**Why second**: CLI is the **Pro-tier differentiator**. It unlocks external tool use.

## Phase 3: Context Governor (5-7 days)

**Goal**: Build the practical context management layer.

1. Hybrid retrieval pipeline (Model2Vec + usearch + Tantivy + RRF)
2. Context assembly from vault + raw thoughts + runs + sources
3. Context window budgeting
4. Provenance tracking for every loaded piece
5. Swift UI integration

**Why third**: This is the **memory intelligence** that makes the app feel "supercharged."

## Phase 4: Ternary + Claim Formalization (2-3 days)

**Goal**: Add formal epistemic logic.

1. `Trit` enum with K3 truth tables
2. `ClaimGraph` with spectral coordinate fields
3. `ResonanceScore` computation
4. Swift bridge integration

**Why fourth**: Small, high-value, sets up future Research-tier work.

## Phase 5: Simulation Pattern Extraction (3-5 days)

**Goal**: Extract simulation design language to main.

1. Add `AgentEvent` variants (`SteerRequested`, `Summary*`, `Vault*`)
2. Implement multi-vault UI pattern in sidebar
3. Add knowledge-brick typography/density rules
4. Leave Metal theater for future Pro-tier release

**Why fifth**: UI differentiation matters for the "cognitive workspace" identity.

## Phase 6: Graph Engine Cleanup (2-3 days)

**Goal**: Resolve dirty files in `graph-engine/**`.

1. Dedicated deliberation gate
2. Fix or quarantine dirty files
3. Reconcile with graph-engine's 2,508 tests

**Why sixth**: The graph engine is the largest crate. It must be clean.

## Phase 7: Verification Pipeline (5-7 days)

**Goal**: Add 5-tier verification.

1. T2 Proptest integration (immediate, low risk)
2. T3 Kani setup (background)
3. T4 Z3 bindings with 100ms timeout (background)
4. Claim extraction from model outputs
5. Repair loop skeleton

**Why seventh**: Verification is what makes it "verifiable cognition."

---

# PART VII: THE CANONICAL DOCUMENT SET

## What Documents Matter Now

### Tier 1: Canonical (Read Before Any Code)

1. **`EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md`**
   - The "one substrate, gated surfaces" philosophy
   - Core/MAS vs Pro vs Research split
   - What ships now vs what is research-only

2. **`SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`**
   - What every source means
   - What can and cannot ship
   - Lane classification

3. **`CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md`** (patched)
   - What the coding agent should do next
   - Phase 0 inventory order
   - No feature coding until queue exists

4. **`AGENTS.md` + `PLAN_V2.md` + `BOLTFFI_AUDIT`**
   - Repo-original verified-floor docs
   - Authority above all

### Tier 2: Research Direction (Informative, Not Blocking)

5. **`EPISTEMOS_MASTER_ARCHITECTURE.md`** (Kimi research)
   - Ternary/spectral/residency vision
   - 2-3 year evolution path
   - Label every claim as "proven" vs "speculative"

6. **`uasa_memory_breakthrough.md`**
   - HCache, KVCrush, DSC research
   - Implementation-ready when Context Governor exists

7. **`osft_psoft_coso_fusion.md`**
   - Verified fusion with corrections
   - QOFT replaces OSFT for QLoRA

8. **`acs_meta_layer.md`**
   - Autopoietic Cognitive Stack
   - Viable Systems Model recursive governance
   - Future meta-cognitive layer

9. **`ternary_spectral_architecture.md`**
   - 6 mathematical pillars
   - Formalization of math discovery
   - Rust implementation sketches

### Tier 3: Donor-Only (Extract Patterns, Do Not Merge Raw)

10. **`DOCTRINE.md` v1.6** (simulation worktree)
    - Simulation design language
    - Metal rendering contracts
    - Knowledge-brick sidebar rules

11. **`IMPLEMENTATION.md` v1.6** (simulation worktree)
    - Simulation build path
    - Slice-by-slice plan
    - Not the main app build path

12. **Quick Capture worktree code**
    - v2 alias table (extract to main)
    - TodoHandler canary pattern (replicate on main)
    - ~54 handler conversions (mechanical)

### Tier 4: Superseded (Reference Only)

13. Older research docs in `/Users/jojo/Downloads/final*`, `/ambient`, `/Advice`
    - Tauri/Docker/sidecar assumptions
    - Private-ANE work
    - Neural-kernel speculation
    - Superseded by Apr 30 Core/MAS vs Pro split

---

# PART VIII: ASSURANCE — ALL NUANCE IS PRESERVED

## The User's Question: "Is All My Nuance in the Docs?"

**Yes. With the following completeness statement:**

### Nuance Preserved ✓

| Nuance | Where It Lives | Status |
|--------|---------------|--------|
| Ternary logic vision | `ternary_spectral_architecture.md` §1 | Preserved with K3 truth tables, Belnap FDE |
| Spectral memory (Laplacian, Koopman) | `ternary_spectral_architecture.md` §2-3 | Preserved with Metal kernel specs |
| Residency Governor (rate-distortion) | `EPISTEMOS_MASTER_ARCHITECTURE.md` §5 | Preserved as Research-tier direction |
| 5-tier verification | `EPISTEMOS_MASTER_ARCHITECTURE.md` §4 | Preserved; Proptest T2 ready for immediate addition |
| Deterministic provenance (BLAKE3, Merkle) | Built in main branch | **Operational** |
| HCache / KVCrush / DSC | `uasa_memory_breakthrough.md` | Preserved; implementation-ready |
| FSRS scheduler | Built in main branch (Rust bridge) | **Operational** |
| Contextual Shadows tiered memory | `EPISTEMOS_MASTER_ARCHITECTURE.md` §3 | V0 operational; V1 spec preserved |
| Golden scheduling (φ-intervals) | `ternary_spectral_architecture.md` §6 | Preserved with Hurwitz/KAM proofs |
| Biometric safety / Dark Node | `EPISTEMOS_MASTER_ARCHITECTURE.md` §1 | Spec preserved; Secure Enclave path defined |
| Apple Silicon UMA optimization | `uasa_memory_breakthrough.md` §8 | Preserved |
| UniFFI FFI bridge | Built in main branch | **Operational** |
| Metal compute shaders | `EPISTEMOS_MASTER_ARCHITECTURE.md` §6 + simulation DOCTRINE | graph_layout exists; spectral kernels spec'd |
| Viable Systems Model governance | `acs_meta_layer.md` | Preserved as recursive S1-S5 pattern |
| Quick Capture event flow | Quick Capture worktree + fusion docs | Preserved; rebuild on main |
| Hermes CLI tunnel | Fusion docs + omega-mcp crate | Architecture defined; server unfinished |
| Simulation mode (Metal theater) | Simulation worktree DOCTRINE v1.6 | Preserved as donor-only |
| Knowledge-brick sidebar | Simulation worktree DOCTRINE §3.4 | Preserved as design language |
| Multi-vault hierarchy | Simulation worktree DOCTRINE §3.4.1 | Preserved; Model/Agent/Sub-agent vaults |
| Companion system (Company→Model→Agent) | Simulation worktree + `agent_core` | Partially built; DOCTRINE preserves full spec |
| MCP protocol integration | `omega-mcp` crate (131 tests) | **Operational** |
| Shadow search backend | `epistemos-shadow` crate (45 tests) | **Operational** |
| Graph engine | `graph-engine` crate (2,508 tests) | **Operational** |
| Tool registry v2 (56+ tools) | Quick Capture worktree | Preserved; migration path defined |
| Subprocess hardening (10 sites) | Built in main branch | **Operational** |
| Force-unwrap deny (3 modules) | Built in main branch | **Operational** |
| Output-bound caps (10 MiB) | Built in main branch | **Operational** |

### What Is NOT Lost

**Nothing is lost.** Every research document, every worktree, every crate, every test is:
- Either **operational in the codebase** (main branch or independent crates)
- Or **preserved as a canonical document** (fusion docs, research outputs)
- Or **preserved as donor material** (worktree DOCTRINEs, implementation plans)
- Or **preserved as Research-tier direction** (ternary/spectral/residency vision)

The user's instinct to "fuse everything" is correct. The fusion has been done — the canonical docs exist. What remains is **execution on main**.

---

# PART IX: THE FINAL "THIS IS WHERE YOU ARE"

## In One Sentence

**You have built a 3,832-test, multi-crate cognitive substrate with deterministic provenance, 56+ tools, agent runtime, search backend, MCP protocol, and graph engine — but the work is spread across divergent worktrees, the CLI is unfinished, and the UI layer needs to catch up to the Rust backend.**

## The Three Things to Do Next

### 1. Fuse the Worktrees (This Week)

Do not merge raw. Extract and rebuild:
- **Tool v2 migration**: Port alias table + canary pattern to main (3-5 days)
- **Simulation patterns**: Extract AgentEvent variants + multi-vault UI + knowledge-brick language (3-5 days)
- **Graph engine**: Clean dirty files with dedicated gate (2-3 days)

### 2. Finish the CLI (Next 2 Weeks)

The CLI is the **Pro-tier unlock**. It enables:
- External agent integration (Claude Code, Codex)
- Browser/computer-use tools
- Docker execution
- Full MCP ecosystem

Omega-mcp (131 tests) is ready. The server is not. Build it.

### 3. Build the Context Governor (Next 2 Weeks)

Not the full Residency Governor — the **practical Context Governor** that:
- Loads the right context at the right time
- Uses hybrid retrieval (Model2Vec + usearch + Tantivy + RRF)
- Tracks provenance of every piece
- Makes the local model "better 100% of the time" because it has the right context

This is the **user-visible superpower**. Everything else is infrastructure.

## What to Stop Doing

1. **Stop deepening substrate hardening** — 39 clippy warnings on 3,832 tests is good enough
2. **Stop building in worktrees** — main is the only implementation target
3. **Stop promising "infinite context"** — the shippable version is "infinite external cognition, bounded neural context"
4. **Stop adding new research dimensions** — the research corpus is complete; execute on it
5. **Stop treating the Governor as blocking** — build Context Governor (practical) before Residency Governor (theoretical)

## What to Keep Doing

1. **Keep the red→green→audit→docs discipline** — it is world-class
2. **Keep the deliberation gates** — they prevent drift
3. **Keep the protected paths** — editor and graph-engine must not be touched without gates
4. **Keep the test culture** — 3,832 tests is a genuine moat
5. **Keep the Swift 6 + Rust FFI hygiene** — data-race safety is correct

---

# PART X: THE CANONICAL PROMPT FOR YOUR NEXT SESSION

## For Kimi (Builder)

```
You are the builder agent for Epistemos. Your job is to implement features on the main branch (`feature/landing-liquid-wave`).

Before writing any code:
1. Read `/app/.agents/skills/docx/SKILL.md` if the task involves document creation
2. Read the canonical fusion docs in `docs/fusion/`:
   - EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md
   - SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md
   - BUILDER_EXECUTION_PROMPT_2026_04_30.md
3. Search your laptop (`/Users/jojo/Downloads/`) for relevant research by task keyword
4. Produce a deliberation gate document before implementation
5. Follow red test → implementation → green test → Kimi audit → docs

Current priority order:
1. Tool v2 migration on main (port alias table, replicate canary pattern)
2. CLI server completion (MCP protocol, stdio/HTTP transports)
3. Context Governor (hybrid retrieval, provenance tracking)
4. Ternary logic formalization (Trit enum, K3 tables)
5. Simulation pattern extraction (AgentEvent variants, multi-vault UI)

Do NOT:
- Edit code in worktrees
- Add new research dimensions
- Deepen substrate hardening beyond current state
- Promise "infinite context" — use "infinite external cognition, bounded neural context"
```

## For Codex (Overseer)

```
You are the active overseer for Epistemos. Your job is to audit, steer, and stop the builder when it drifts.

You have:
- Computer Use for shell audits
- Web search for external verification
- Authority to interrupt and redirect

Before approving any build order:
1. Verify the deliberation gate exists and is complete
2. Check that the task maps to the canonical master plan
3. Verify tests exist and are red before implementation
4. Verify tests are green after implementation
5. Run your own spot-checks (git diff, test run, clippy count)

If the builder:
- Edits worktree code → STOP, redirect to main
- Adds new research → STOP, redirect to existing docs
- Deepens substrate without user-visible feature → STOP, redirect to CLI/Governor
- Promises "infinite context" → CORRECT to "infinite external cognition"
- Skips deliberation gate → STOP, demand gate document

Your first task in every session: verify floor → inventory dirty files → check test counts → approve or redirect builder queue.
```

---

# APPENDIX: COMPLETE FILE MANIFEST

## Operational Code (Built and Tested)

| File/Module | Crate | Tests | Status |
|-------------|-------|-------|--------|
| `oplog.rs` | agent_core | 16 Rust | ✅ Provenance chain |
| `etl/jobs.rs`, `etl/queue.rs` | agent_core | 13 + 780 lib | ✅ ETL pipeline |
| `fsrs_decay.rs` | agent_core | Rust bridge | ✅ Spaced repetition |
| `vector_graph.rs` | agent_core | Foundation | ✅ Graph + vector search |
| `tools/registry.rs` | agent_core | 742 total | ✅ Tool dispatch (legacy) |
| `tools/v2_catalog/` | agent_core | Alias tests | ⚠️ In worktree |
| `agent_loop.rs` | agent_core | Integration | ✅ Agent runtime |
| `provenance/ledger.rs`, `provenance/replay.rs` | agent_core | Keystone | ✅ Audit + replay |
| `context_loader.rs` | agent_core | Unit | ✅ Context assembly |
| `session_insights.rs` | agent_core | Unit | ✅ Analytics |
| `security.rs`, `tirith.rs` | agent_core | Unit | ✅ Threat assessment |
| `storage/raw_thoughts.rs` | agent_core | Unit | ✅ Thought storage |
| `epistemos-shadow/src/lib.rs` | epistemos-shadow | 45 | ✅ Search FFI |
| `omega-mcp` | omega-mcp | 131 | ✅ MCP protocol |
| `graph-engine` | graph-engine | 2,508 | ✅ Graph database |
| `epistemos-core/uniffi/` | epistemos-core | 366 | ✅ FFI bridge |
| `EventStore.swift` | Swift | 14 | ✅ Swift provenance |
| `MutationOpLogProjector.swift` | Swift | 11 | ✅ Projection |
| `ContextualShadowsState.swift` | Swift | 17 | ✅ Shadow routing |
| `ChatCoordinator.swift` | Swift | 11 | ✅ Conversation dispatch |
| `KIVIQuantization.swift` | Swift | Unit pass | ⚠️ Opt-in, blocked |

## Canonical Documents (Read-Only Authority)

| Document | Location | Purpose |
|----------|----------|---------|
| `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md` | `docs/fusion/` | What Epistemos is |
| `SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md` | `docs/fusion/` | What every source means |
| `BUILDER_EXECUTION_PROMPT_2026_04_30.md` | `docs/fusion/` | What builder does next |
| `CODEX_ACTIVE_OVERSEER_KIMI_PROMPT_2026_04_30.md` | `docs/fusion/` | Overseer instructions |
| `KIMI_RESEARCH_AND_FUSION_PROMPT_2026_04_30.md` | `docs/fusion/` | Research prompt |
| `KIMI_SESSION_CONTEXT_2026_04_30.md` | `docs/fusion/` | Context sheet |
| `README_START_HERE_2026_04_30.md` | `docs/fusion/` | Entry point |
| `AGENTS.md` | Repo root | Verified floor |
| `PLAN_V2.md` | Repo root | Build plan |
| `BOLTFFI_AUDIT` | Repo root | FFI audit |

## Research Documents (Research-Tier Direction)

| Document | Location | Value |
|----------|----------|-------|
| `EPISTEMOS_MASTER_ARCHITECTURE.md` | `/mnt/agents/output/` | 9-wave build plan (superseded but informative) |
| `ternary_spectral_architecture.md` | `/mnt/agents/output/` | 6 mathematical pillars |
| `acs_meta_layer.md` | `/mnt/agents/output/` | Autopoietic Cognitive Stack |
| `uasa_memory_breakthrough.md` | `/mnt/agents/output/` | Memory mechanisms |
| `osft_psoft_coso_fusion.md` | `/mnt/agents/output/` | Verified fusion with corrections |
| `uasa.agent.final.md` | `/mnt/agents/output/` | 35,000-word research synthesis |

## Worktree Documents (Donor-Only)

| Document | Worktree | Extractable Value |
|----------|----------|-------------------|
| `DOCTRINE.md` v1.6 | `simulation` | Design language, Metal contracts, AgentEvent variants |
| `IMPLEMENTATION.md` v1.6 | `simulation` | Build path (not main app path) |
| `tools/registry.rs` Phase 2G | `claude/vigorous-goldberg` | Alias table, canary pattern |
| `tools/todo.rs` Phase 2G-4a | `claude/vigorous-goldberg` | Native Tool impl pattern |

---

*This assessment is based on:
- Direct analysis of `feature/landing-liquid-wave` branch (34 files, +3,471/-116 lines)
- Direct analysis of `simulation` worktree (DOCTRINE v1.6, IMPLEMENTATION v1.6)
- Direct analysis of `claude/vigorous-goldberg` worktree (v2 tool migration, 742 tests)
- Direct analysis of `epistemos-shadow` crate (45 tests, FFI boundary)
- Direct analysis of `omega-mcp` crate (131 tests)
- Direct analysis of `graph-engine` crate (2,508 tests)
- Direct analysis of `epistemos-core` crate (366 tests)
- All research documents produced across 6 previous Kimi sessions
- Claude fusion documents (Apr 30, 2026)*
