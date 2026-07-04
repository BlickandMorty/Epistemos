---
id: 872A5036-2ADF-40C3-9F39-3E6CF4E1F2D7
title: Agent-Stack Convergence Research (2026-06-21)
---

# Agent-Stack Convergence Research (2026-06-21)

Deep, grounded convergence research for the owner's directive (addendum  
§"AGENT-STACK CONVERGENCE", `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md:90-99`):  
*"all logic we clone/pull … must DEEPLY serve the app — no dead clones, no clashes …*  
*maintain ONE agent-loop/runtime of record; dedup capabilities … favor Osaurus on*  
*clashes; fix the dual-MLX clash (vmlx-swift vs mlx-swift-lm)."*

**ANTI-HALLUCINATION:** every in-repo claim below was read from the actual file this  
session (paths cited). Web claims are labeled **[verified web]** (primary/official  
source) vs **[inferred]**. No capability is invented. The plan docs are the authority  
(memory: "PLAN_V2 is authority; fix code to match plan, not the reverse").

---

## 0. Scope, sources, and the one big correction

**Stacks covered:** (1) Osaurus = *act*; (2) Goose = *work*; (3) OpenCode = *work, but*  
*a separate stack from Goose*; (4) OpenClaw = *selective hardening patterns, not a*  
*clone*; (5) Hermes / the legacy in-process agent runtime = *the existing brain*.

**Primary sources (web, verified):**

- Osaurus — `github.com/osaurus-ai/osaurus`, `docs.osaurus.ai`, `docs.osaurus.ai/security`. **[verified web]** MIT, native macOS Swift, MLX, Apple Containerization Linux-VM sandbox, full MCP server + 20+ plugins, every chat is an agent loop. (The old `dinoki-ai/osaurus` is archived.)
- Goose — `github.com/block/goose`, `deepwiki.com/block/goose`. **[verified web]** Apache-2.0, **Rust** Cargo workspace (`goose` core, `goose-mcp`, `goose-cli`, `goose-server`) + a TypeScript/Electron desktop; subagents are `Agent::new()` instances each with `TaskConfig{provider,max_turns,extensions}`; 15+ providers; recipes (YAML); MCP client to 70+ extensions.
- OpenCode — `github.com/sst/opencode`, `opencode.ai/docs/server`, `deepwiki.com/sst/opencode`. **[verified web]** MIT, **TypeScript/Bun** (NOT Rust, NOT Go — one secondary blog mislabels it "Go"; the repo `package.json` is TS), client/server with a persistent background **server** (OpenAPI 3.1 → generated SDK), TUI is one of several clients, **40+ LSP** servers auto-loaded for code intelligence, 75+ providers.
- OpenClaw — `docs.openclaw.ai` (`/tools/loop-detection`, `/reference/session-management-compaction`, `/concepts/agent-runtimes`). **[verified web]** A gateway/agent-runtime; documents convergence-detection (≥85% semantic similarity across iterations), boredom detection, context-pressure checks, compaction-retry loop guard, checkpoint/resume.

**THE BIG CORRECTION (carry to owner):** the plan docs repeatedly say  
*"Work = Goose/OpenCode"* and `GOOSE_S2_EXTRACTION_PLAN` says *"pull block/goose's*  
*RUST CORE … the full engine."* That is right for Goose (Rust) but **OpenCode is**  
**TypeScript, not Rust** — it CANNOT be vendored as a Cargo crate into `agent_core` the  
way Goose can. OpenCode and Goose are two *different* engines that happen to both  
target "work." Treating them as one importable thing is the kind of muddiness the  
owner warned about. See §4 for the recommended split: **Goose = the work engine of**  
**record (Rust, in-process); OpenCode = a *pattern/architecture source* (its LSP-for-**  
**agents idea maps onto Epistemos's existing in-process Rust LSP), not a code clone.**

---

## 1. Per-stack deep dives

### 1.1 Osaurus — ACT (confirmed role)

**What it is.** **[verified web + in-repo]** A complete native macOS Swift app  
(MIT). Vendored whole at `LocalPackages/osaurus/` (pinned `ae3a3c5d…`, `.git`  
stripped, take-control — `LocalPackages/osaurus/VENDOR.md`). The substrate to link is  
the SPM library `OsaurusCore` (`LocalPackages/osaurus/Packages/OsaurusCore/`).

**Agent-loop / engine design (read in-repo, grounded):**

- The loop is **Swift, in-process**, not a Rust/FFI loop. Core lives in  
`OsaurusCore/Services/Chat/`: `ChatEngine.swift` + `ChatEngineProtocol.swift`  
(the engine), `AgentToolLoop.swift` (the ReAct tool loop), `AgentTaskState.swift`,  
`ContextBudgetManager.swift` + `CompactionWatermark.swift` + `ContextSizeClass.swift`
  - `TokenEstimator.swift` (context budgeting/compaction), `SystemPromptComposer.swift`
  - `PromptBuilder.swift` + `PromptManifest.swift` + `SystemPromptTemplates.swift`  
  (tiered prompt assembly), `ChatToolChoicePolicy.swift`, `ResolvedToolset.swift`.
- "Every chat is an agent loop" driven by three tiny tools —  
`OsaurusCore/Tools/AgentLoopTools.swift`: `todo(markdown)`, `complete(summary)`,  
`clarify(question)` — *"smallest schema small local models can reliably call"*  
(read verbatim from the file header). Plus a full `ToolRegistry.swift`,  
`BuiltinSandboxTools.swift`, `MCPProviderTool.swift`, `SecretScrubber.swift`  
(the on-device privacy filter), `ToolOutputCompressor.swift`/`ToolOutputCaps.swift`.
- Inference: `OsaurusCore/Services/Inference/` — `MLXService.swift`,  
`FoundationModelService.swift` (Apple Intelligence), `CoreModelService.swift`,  
`ModelService.swift`. MLX via the consolidated `vmlx-swift` dependency  
(`OsaurusCore/Package.swift:` the single vMLX pin replaces separate MLX/tokenizer/  
transformer pins).
- Sandbox: `OsaurusCore/Services/Sandbox/` (`SandboxManager`, `SandboxProvisioner`,  
`LiveExecRegistry`, `ProcessHandle`, `SandboxSecurity`) — Apple Containerization  
Linux VM, `.package(url: apple/containerization)` in `OsaurusCore/Package.swift`.
- Server, identity/relay, MCP, 20+ plugins, SQLCipher-encrypted storage, telemetry —  
all present under `OsaurusCore/{Networking,Identity,Services/MCP,Tools/PluginABI, SQLCipher,Services/TelemetryService.swift}`.

**Unique benefits:** the only stack that is *already* a finished, in-process,  
Apple-Silicon-native Swift agent with serving + sandbox + MCP + plugins + privacy  
filter, all MIT. It is the closest thing to "as complex as a brain, as simple as an  
app." This is why the owner is "taking the entire app."

**MAS/licensing:** MIT → `direct_import` (ProvenanceGate green;  
`Epistemos/Vendor/Osaurus/OsaurusVendorProvenance.swift`). Per the deep entitlements  
research (`docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`, grounded  
against Apple docs): **~95% of Osaurus fits MAS by standard entitlements**; the ONE  
genuine MAS blocker is the **restricted** `com.apple.security.virtualization`  
entitlement for the Linux-VM sandbox. Owner decision (build-progress doc): **main app**  
**= direct-distribution (notarized, non-sandboxed) carrying the FULL Osaurus incl. the**  
**VM sandbox** — MAS is no longer a hard constraint; never cut osaurus-ness for it.

**Role in Epistemos: ACT.** Confirmed. `act = Osaurus` (addendum §90-99). The current  
seam is `Epistemos/ActOsaurus/ActOsaurusBridge.swift` (protocol +  
`InertActOsaurusBridge` honest default + `OsaurusActBridge` growth point that POSTs to  
the loopback `LocalModelServer`, throws `ActOsaurusError` rather than ever silently  
falling back — read in-repo; honors NON-NEGOTIABLE #1). Status: S1/S2 done, **S3 (link**  
**OsaurusCore) blocked only on the dual-MLX consolidation** (`OSAURUS_BUILD_PROGRESS_ 2026_06_21.md:21-40`).

### 1.2 Goose — WORK (confirmed role)

**What it is.** **[verified web]** Apache-2.0 Rust Cargo workspace from Block. Core  
crate `crates/goose/` (agent loop, providers, session, recipe, permission, skills,  
subagents); `goose-mcp` (built-in MCP servers); `goose-cli`, `goose-server`, and a  
TS/Electron desktop (NOT imported).

**Agent-loop / engine design [verified web]:** one `Agent` class; **subagents are**  
`Agent::new()` **instances**, each with its own isolated execution context + a  
`TaskConfig{provider, max_turns, extensions}` (subagents can use *different/cheaper*  
providers than the parent — cost-effective delegation). Recent "unify agent execution"  
work routes chat, scheduler, and recipes through ONE execution pipeline (agent-per-  
session, multiple sessions). Providers: 15+. Builtin extensions are zero-IPC,  
compiled-in. Streaming `MessageStream = Pin<Box<dyn Stream>>` (the  
`GOOSE_REPLACEMENT_STRATEGY.md` zero-copy note).

**Unique benefits (the "work" gaps Osaurus doesn't fill):** repo indexing over  
`source_roots`, git lifecycle, multi-file diffs, deterministic test-and-fix loop,  
parallel subagents, YAML recipes — the *software-engineering* agent surface. Goose is  
Rust, so it fuses into `agent_core` via UniFFI, matching the in-process doctrine.

**MAS/licensing:** Apache-2.0 → `direct_import` (`agent_core/src/work.rs`:  
`GOOSE_VENDOR_LICENSE="Apache-2.0"`, `GOOSE_VENDOR_SOURCE="block/goose"`). Leaf-first  
vendor already underway: `SourceRoot` (S2), `permission` types (S3), recipe  
`RecipeParameter` (S4), `Settings` (S5), `RepetitionGuard` clean-room (S6) — all  
**isolated under the** `work` **module**, GUARDRAIL-locked (nothing in `agent_loop`/  
`agent_runtime` references `work`; read `agent_core/src/work.rs` header).

**Role in Epistemos: WORK.** Confirmed. Surfaced ONLY through Work mode + flag  
`EPISTEMOS_WORK_GOOSE_V0` (`Epistemos/Work/WorkBackend.swift`: protocol +  
`InertWorkBackend` + `GooseWorkBackend` growth point, throws `WorkBackendError`, no  
silent fallback — read in-repo). **GOOSE GUARDRAIL: Chat (Epistemos) / Act (Osaurus)**  
**NEVER break** (`GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md:7`).

### 1.3 OpenCode — WORK (role CORRECTED: architecture source, not a Rust clone)

**What it is.** **[verified web]** MIT, **TypeScript/Bun**, from SST. Persistent  
background **server** (OpenAPI 3.1 → generated SDK `@opencode-ai/sdk`); TUI is one  
client of several (desktop beta, IDE ext, CI). 75+ providers. **40+ LSP servers**  
**auto-loaded** to give the agent diagnostics/hover/definition/references/call-hierarchy.

**Agent-loop / engine design [verified web + inferred]:** client/server; the agent  
logic runs server-side and clients connect over HTTP. Its standout is the **LSP-for-**  
**agents** layer — it auto-selects the right language server for the file context and  
feeds code intelligence into the agent loop.

**Unique benefit worth pulling:** the **LSP-into-the-agent-loop pattern**, and the  
**headless server + typed SDK** client/server shape (multiple front-ends over one  
server — which is exactly the owner's "every surface wired to one shared  
composer/engine" intent, addendum §24-29).

**MAS/licensing:** MIT, but **TypeScript** — it is NOT vendorable as a Cargo crate  
into `agent_core`, and shipping a Bun/Node server is a forbidden sidecar/subprocess on  
the MAS path (CLAUDE.md NO-SIDECAR). So OpenCode is **NOT a clone target**; it is a  
**design/pattern source.**

**Role in Epistemos: WORK (pattern source).** The "work" *engine of record* is **Goose**  
**(Rust, in-process)**, not OpenCode. From OpenCode, **clean-room the LSP-for-agents**  
**idea onto Epistemos's EXISTING in-process Rust LSP** (`agent_core/src/lsp_runtime/ mod.rs` — `LspKernel`, tree-sitter Rust/Swift, FFI via `bridge.rs`  
`lsp_send_message_json`; CLAUDE.md "Swift LSP (V2.3)"). Epistemos already has the LSP  
runtime; the OpenCode lift is *wiring its diagnostics/definitions into the work agent*  
*loop as tools*, not importing OpenCode. **[inferred]** This is the dedup win: don't  
clone a second LSP stack.

### 1.4 OpenClaw — SELECTIVE HARDENING (confirmed role; NOT a clone)

**What it is.** **[verified web]** An agent-runtime/gateway (`docs.openclaw.ai`). The  
in-repo intake (`docs/OPENCLAW_FEATURE_SPEC.md`, `docs/BEST_OF_CLAW_AND_OPENCLAW.md`)  
already distilled it into **discrete hardening patterns to rewrite in Swift** — never a  
full clone.

**The patterns (in-repo spec, web-verified they exist upstream):**

1. **Tool-loop detection** (`OPENCLAW_FEATURE_SPEC.md:23`) — upstream: convergence  
 detection (≥85% semantic similarity across iterations) + boredom detection (same  
 tool/params/output) + a compaction-retry loop guard **[verified web]**.
2. **Context budget manager** (`:139`) — subsystem-split budgets + post-tool-result  
 context-pressure check **[verified web]**.
3. **Execution checkpoint &amp; resume** (`:251`) — save long-task state, restore + re-inject  
 plan status to resume **[verified web]**.
4. **Agent depth limiter** (`:395`).
5. **Memory recall diversification (MMR)** (`:465`).
6. **Execution transcript repair** (`:588`).  
Plus the zero-config/auto-discovery philosophy (`BEST_OF_CLAW_AND_OPENCLAW.md` §2,  
"manual setup is a bug").

**MAS/licensing:** patterns only → **clean_room_rewrite in Swift/Rust**; no vendored  
code, no provenance import (record as `clean_room` if any lands).

**Role in Epistemos: selective runtime hardening, AFTER Osaurus** (addendum §90-99:  
*"OpenClaw = pull only the hardening patterns Osaurus/Goose don't already give (rewrite*  
*in Swift), not a full clone"*). Confirmed. **CRITICAL DEDUP (§3 table):** Osaurus  
*already ships* most of these in `OsaurusCore/Services/Chat/` — so most OpenClaw items  
are **already covered once Osaurus is linked** and should be SKIPPED.

### 1.5 Hermes / legacy in-process runtime — the EXISTING BRAIN (confirmed)

**What it is.** The Hermes namespace was fully purged from code 2026-05-05 (CLAUDE.md);  
the in-process runtime is now `agent_core::agent_runtime` (Rust) +  
`Epistemos/LocalAgent/*` (Swift). It is the canonical local-agent path:  
`LocalAgentLoop.swift` (the turn loop; generation injected as closures —  
`LocalAgentGenerationHandler`, read in-repo lines 3-30), `LocalAgentPromptBuilder.swift`,  
`LocalToolGrammar.swift`, `LocalAgentGatewayPolicy.swift` (honesty gating),  
`RuntimeRouter.swift` (intra-local lane chooser). Rust side: `agent_loop.rs`  
(cloud ReAct loop with `try_join_all` parallel tools + `CancellationToken`),  
`routing.rs`, `agent_runtime/{self_evolution,procedural_memory,prompt_format,skills, function_call}.rs`.

**Unique benefits = the owner's IP** that rides ON TOP of any engine: Eidos closed-  
citation, vault/Knowledge-Core tools, cognitive DAG, provenance ledger, honesty  
gating, the system prompts. Per the overlap research  
(`HERMES_OSAURUS_OVERLAP_AND_DESTINATION_2026_06_19.md`): of ~13 Hermes capabilities,  
**9 already covered, ~the rest excluded as Osaurus-overlap, only 4 genuinely unique**  
to lift (session-search→summarize; Swift summarizing compaction; named prompt tiers;  
richer auto-skill triggers) — and **none of the 4 lives on Osaurus**; they attach to  
the brain ABOVE the generation closure.

**Role in Epistemos: the existing in-process runtime / the BRAIN + driver.** Confirmed.  
**Forcing fact (read in-repo):** `agent_loop.rs:~147 LocalProviderNotAllowed` rejects  
local providers, so the rich Rust loop is **cloud-only**; the *local* loop control  
stays in Swift `LocalAgentLoop`. Hermes *algorithms* (provider-agnostic) live in  
`agent_runtime`, callable by both.

---

## 2. The convergence map — ONE coherent architecture

**Design principle (owner):** ONE agent-loop/runtime of record per *mode*, the owner's  
IP as a portable brain layer on top, engines swapped at a single decision point, no  
hidden fallbacks, favor-Osaurus on clashes, minimal Epistemos pixel-art reskin, every  
surface wired to a proven front-end.

```
                         ┌──────────────────────────────────────────────┐
   ONE shared pixel-art  │  Epistemos shared Act/Work composer (minimal  │
   front-end (addendum   │  pixel-art reskin; reused by main chat,        │
   §24-49: one composer  │  MiniChat, Note chat, Graph chat — discovery   │
   over ChatCoordinator) │  sweep: OSAURUS_SURFACE_DISCOVERY_SWEEP)       │
                         └───────────────┬──────────────────────────────┘
                                         │ single mode/engine decision
                                         │ (ChatCoordinator — NOT RuntimeRouter)
        ┌────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                  ▼
   ┌─────────┐                      ┌──────────┐                       ┌──────────┐
   │  CHAT   │                      │   ACT     │                      │   WORK    │
   │(quarant.│                      │ = Osaurus │                      │ = Goose   │
   │ legacy, │                      │  (engine  │                      │  (Rust    │
   │ never   │                      │ of record)│                      │  core via │
   │ deleted)│                      └────┬──────┘                      │  UniFFI)  │
   └─────────┘                           │                             └────┬─────┘
        │  IP/logic ported OUT of chat   │                                  │
        └──────────►  THE BRAIN LAYER (owner IP, in-process, engine-agnostic) ◄─┘
            LocalAgentLoop (Swift) + agent_core::agent_runtime (Rust):
            Eidos citation · vault/Knowledge-Core tools · cognitive DAG ·
            provenance ledger · honesty gating · system prompts · skills ·
            self-evolution · prompt tiers · summarizing compaction
                                         │
                         generation closure swap (the ONE wire):
              .osaurusLocal → ActOsaurusBridge.runTurn → OsaurusCore MLX serving
              (brain above the closure is byte-identical; only token-serving swaps —
               HERMES_OSAURUS_OPENCLAW_WIRING_R2:74-88)
```

**Single agent-loop/runtime of record:**

- **Per-mode engines, ONE brain.** Act's *engine* = OsaurusCore's Swift loop; Work's  
*engine* = Goose's Rust loop; but the **owner's IP brain is ONE layer** that rides on  
top of whichever engine (`LocalAgentLoop` + `agent_runtime`). There is exactly ONE  
brain; engines are interchangeable token-servers/executors beneath it.
- **No third route.** The engine decision lives at ONE site — the Act/Work dispatch in  
`Epistemos/App/ChatCoordinator.swift` (mirror `WorkBackendFactory.resolve()`).  
`RuntimeRouter` is *intra-local lane choice inside* an engine, NOT the engine picker —  
collapsing them creates the forbidden 3rd route (`OSAURUS_ACT_CONNECTION_MAP:49`,  
`HERMES_..._WIRING_R2:87` — `RuntimeLane` has NO `.osaurus` case, by design).

**What each stack contributes (no clash):**


| Stack         | Contributes                                                                     | Wires via                                                                                                        | Clash avoidance                                                                |
| ------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Osaurus       | Act engine: MLX serving, sandbox VM, MCP, plugins, privacy filter, server       | Link `OsaurusCore` (direct-dist build); `ActOsaurusBridge.runTurn`; sandbox/plugins as `LocalAgentToolExecutor`s | **Favor Osaurus on clashes** (addendum §50-64). Consolidate MLX on vmlx-swift. |
| Goose         | Work engine: repo index, git, multi-file diff, test-and-fix, subagents, recipes | Vendor `crates/goose` leaf-first into `agent_core::work`; UniFFI → `GooseWorkBackend`                            | Isolated `work` module; GUARDRAIL test asserts Chat/Act untouched.             |
| OpenCode      | LSP-for-agents pattern + headless-server/one-composer shape                     | Clean-room onto existing `agent_core::lsp_runtime` + the shared-composer design                                  | NOT cloned (TS) — pattern only → no dep clash, no sidecar.                     |
| OpenClaw      | Hardening patterns Osaurus/Goose lack (see §3)                                  | Clean-room Swift/Rust into the brain layer                                                                       | SKIP everything Osaurus already ships (§3).                                    |
| Hermes/legacy | The brain: IP, honesty, citations, DAG, provenance + the 4 unique lifts         | `LocalAgentLoop` + `agent_runtime` ABOVE the generation closure                                                  | Never moves into an engine; engine swap is below it.                           |


**THE DUAL-MLX CLASH — recommended consolidation (grounded, read both Package.swifts):**

- Confirmed: `LocalPackages/vmlx-swift/Package.swift` exports `MLX, MLXNN, MLXOptimizers, MLXLLM, MLXVLM, MLXLMCommon, MLXEmbedders` (plus `VMLXTokenizers`,  
`VMLXJinja`, …); `LocalPackages/mlx-swift-lm/Package.swift` exports  
`MLXLLM, MLXVLM, MLXLMCommon, MLXEmbedders`. **Two packages defining the same**  
`MLX*` **modules in one binary → duplicate-module link error.** OsaurusCore depends on  
`osaurus-ai/vmlx-swift` (its `Package.swift` pins it; the comment says vmlx  
"vendors the MLX/MLXLMCommon/MLXLLM/MLXVLM/Tokenizers/Jinja … Osaurus previously  
pulled from separate pins").
- **Recommendation (per favor-Osaurus + the entitlements doc):** **consolidate**  
**Epistemos onto** `vmlx-swift`**; drop** `mlx-swift-lm` **+ the upstream** `MLX`**/**`MLX-LM`  
**packages.** The 8 Epistemos MLX-importing files (`MLXInferenceService.swift`,  
`MLXConstrainedGenerator.swift`, `LocalToolGrammar.swift`, `SSMStateService.swift`,  
and the 4 KnowledgeFusion training files — grep-confirmed) map 1:1 because vmlx  
provides the same module names. Only TWO fixups per the build-progress doc:  
`import Tokenizers`→`VMLXTokenizers` (1 file: `NativeKTOTrainer.swift`) and the  
`#if canImport`-guarded `MLXStructured` (drops cleanly). This is **in-flight** on  
main (iter-8 WIP, `OSAURUS_BUILD_PROGRESS_2026_06_21.md:97-106`) — do it where the  
build can iterate; don't commit red.
- **Same pattern for SQLite/SQLCipher:** OsaurusCore vendors SQLCipher and already  
hand-patches the FTS5 typedef collision against system `SQLite3`; adopt its vendored  
SQLCipher rather than a second SQLite stack (entitlements doc §"Separate TECHNICAL  
clash"; `OsaurusCore/Package.swift` SQLCipher comment, read in-repo).

---

## 3. Overlap / dedup table — source of record per capability

Goal: never clone the same thing twice. **"Source of record"** = the one stack that  
owns the capability after convergence; ⛔ = do NOT re-port from the other stacks.


| Capability                         | Osaurus                                                         | Goose                                  | OpenClaw                     | Hermes/legacy                            | **Source of record**                                                                                            |
| ---------------------------------- | --------------------------------------------------------------- | -------------------------------------- | ---------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Agent loop (ReAct)                 | ✅ `ChatEngine`/`AgentToolLoop`                                  | ✅ `Agent`                              | ✅                            | ✅ `agent_loop.rs`/`LocalAgentLoop`       | **Per-mode engine** (Osaurus=act, Goose=work); brain on top                                                     |
| Tool calling / registry            | ✅ `ToolRegistry.swift`                                          | ✅                                      | ✅                            | ✅ `tools/registry.rs`+`LocalToolGrammar` | **Osaurus (act) / Goose (work)**; legacy already Hermes-3-compatible                                            |
| **Tool-loop / boredom detection**  | ✅ (loop tools + watermark)                                      | ✅ `RepetitionGuard` (S6 vendored)      | ✅ convergence+boredom        | partial                                  | **Goose `RepetitionGuard`** (already clean-roomed) + Osaurus; ⛔ OpenClaw clone                                  |
| **Context budgeting / compaction** | ✅ `ContextBudgetManager`+`CompactionWatermark`+`TokenEstimator` | ✅                                      | ✅ context-pressure check     | Swift TRUNCATES only (`trimHistory`)     | **Osaurus** for act; Hermes-lift #2 (Swift summarizing compaction) for the legacy/local brain; ⛔ OpenClaw clone |
| **Checkpoint / resume**            | ⚠️ session export/manager (`ChatSessionsManager`)               | ✅ session lifecycle                    | ✅ explicit checkpoint/resume | session store `session.rs`               | **OpenClaw pattern** = the genuine gap (only stack with explicit resume re-inject) → clean-room Swift           |
| Auto-discovery / zero-config       | partial (plugin recipes, onboarding)                            | extensions                             | ✅ strongest                  | —                                        | **OpenClaw pattern** (zero-config philosophy) → selective Swift, AFTER Osaurus                                  |
| Sandbox / code-exec                | ✅ Apple Containerization VM (headline)                          | ⚠️ exec via extensions                 | —                            | ⛔ (no-sidecar)                           | **Osaurus** (owns sandboxed exec; legacy code-exec EXCLUDED)                                                    |
| Model serving                      | ✅ `MLXService` + :1337 server                                   | provider HTTP                          | —                            | MLX-Swift `MLXInferenceService`          | **Osaurus** (act); consolidate MLX on vmlx-swift                                                                |
| MCP server/client                  | ✅ full MCP + 20+ plugins                                        | ✅ `goose-mcp` (70+)                    | —                            | `omega-mcp`+`MCPBridge`                  | **Osaurus** (act); ⛔ don't re-port Goose MCP into act                                                           |
| Subagents / delegation             | ⚠️                                                              | ✅ `Agent::new()` + `TaskConfig` (best) | depth limiter                | `delegate_task.rs` (depth≤2)             | **Goose** (work); legacy delegate for local                                                                     |
| Repo index / git / multi-file diff | —                                                               | ✅ (the work surface)                   | —                            | —                                        | **Goose** (work) — unique, the reason work=Goose                                                                |
| LSP-for-agents                     | —                                                               | —                                      | —                            | ✅ `lsp_runtime` exists                   | **Epistemos `lsp_runtime`** + OpenCode pattern (wire diagnostics into work loop)                                |
| MMR recall diversification         | —                                                               | —                                      | ✅                            | RRF fusion exists (`SearchIndexService`) | **OpenClaw pattern** (small) — but check if RRF fusion already suffices first                                   |
| Transcript repair                  | ✅ (tool envelopes)                                              | —                                      | ✅                            | —                                        | **Osaurus** likely covers; verify before porting OpenClaw                                                       |
| Session search → summarize         | ⚠️                                                              | session                                | —                            | ⚠️ ~70% built (`SessionSearchHandler`)   | **Hermes-lift #1** (wire to fused index) — genuine gap                                                          |
| Named prompt tiers                 | ✅ `PromptManifest`/`SystemPromptComposer`                       | recipes                                | ✅ subsystem budgets          | flat string                              | **Osaurus** for act; Hermes-lift #3 for legacy/Rust `prompt_format`                                             |
| Auto-skill / self-evolution        | ✅ `Skill` services                                              | ✅ skills                               | —                            | ✅ `self_evolution.rs`                    | **Hermes-lift #4** (richer triggers) into `agent_runtime`                                                       |


**OpenClaw items already covered by Osaurus/Goose → SKIP (do NOT clone in Swift):**

- **Tool-loop detection** — Goose `RepetitionGuard` is already vendored (S6) + Osaurus
has loop tools. ⛔ Skip the OpenClaw clone; keep only as a *cross-check spec*.
- **Context budget manager** — Osaurus `ContextBudgetManager`+`CompactionWatermark`+
`ContextSizeClass` is more complete. ⛔ Skip the OpenClaw Swift port for act.
- **Transcript repair** — Osaurus `ToolEnvelope`/`ToolErrorEnvelope`/`SchemaValidator`
likely cover it; **verify** before porting.

**OpenClaw items that ARE genuine gaps → clean-room in Swift (later/selective):**

- **Execution checkpoint &amp; resume** (explicit save→restore→re-inject plan) — no other
stack has the full resume re-injection; the strongest unique OpenClaw lift.
- **Agent depth limiter** — small; Goose `TaskConfig.max_turns` partly covers subagent
depth, but a global depth cap is worth a tiny clean-room.
- **Zero-config auto-discovery philosophy** — selective, after Osaurus settles.
- **MMR recall** — only if the existing RRF fusion (`SearchIndexService.fusedSearch`,
k=60) doesn't already give enough diversity (likely it does — verify first).

---

## 4. Sequencing recommendation

Consistent with the owner's standing order — **Osaurus-first, then harden; OpenClaw is
later/selective; substrate-health later-but-certain** (addendum §19; quarantine doc
§"STANDING SEQUENCING"; build-progress doc).

1. **NOW — finish the dual-MLX consolidation** (S3 unblock). Swap `project.yml` off
 `mlx-swift-lm`/`MLX`/`MLX-LM` onto `vmlx-swift`; apply the 2 import fixups; build to
 GREEN in an iterable checkout; only then commit. (In-flight WIP exists — don't ship
 red.) **This is the single gate for everything else** — OsaurusCore can't link until
 it's done.
2. **Link `OsaurusCore` (direct-distribution build)** → Act engine live; `isLive`
 reflects a real OsaurusCore service; RunEventLog + AnswerPacket; reskin one Act view
 to pixel-art (S3→S4).
3. **Act agent-turn through OsaurusCore** + the ONE generation-closure swap so
 `.osaurusLocal` serves tokens via OsaurusCore while the brain (IP) stays untouched
 (S4). Wire the shared composer across ALL chat surfaces (discovery sweep already
 enumerated 7) + "Epistemos Picks" model section.
4. **Port the 4 unique Hermes lifts** into the brain (session-search→summarize; Swift
 summarizing compaction; named prompt tiers; richer auto-skill triggers) — none
 touch Osaurus.
5. **WORK = Goose**: continue leaf-first vendor of `crates/goose` into `agent_core::  work` (S7 provider/message layer is the next real push) → FFI-export `run_work_  session` → `GooseWorkBackend`. Keep the GUARDRAIL test. Add the **OpenCode LSP-for-
 agents** pattern onto `agent_core::lsp_runtime` as work-loop tools.
6. **OsaurusCore VM sandbox + plugins + MCP + privacy filter** as additional
 `LocalAgentToolExecutor`s the brain routes to (S5/S6), each gated/logged.
7. **OpenClaw selective hardening (LATER)** — clean-room ONLY the genuine gaps
 (checkpoint/resume, depth limiter, zero-config), each verified-not-already-covered
 first. Skip everything Osaurus/Goose already ship.
8. **Substrate finalization + quarantined-chat IP porting cycles (further down, but
 CERTAIN)** — recurring port→verify cycles; retire (never delete) chat only after the
 4-part bar + owner OK.

---

## 5. Open questions for the owner

1. **Goose vs OpenCode for "work":** confirm **Goose (Rust, in-process) is the work
 engine of record** and **OpenCode is a pattern source only** (it's TypeScript and
 cannot be a clean Cargo/in-process clone). The plan docs lump them; this is the one
 real correction. OK to formalize?
2. **OpenCode LSP-for-agents:** wire Epistemos's existing `agent_core::lsp_runtime`
 (already in-process Rust + tree-sitter) into the *work* loop as the LSP layer, rather
 than importing anything from OpenCode — confirm that satisfies the OpenCode intent.
3. **Act loop ownership:** once OsaurusCore links, Act runs on *Osaurus's* Swift
 `ChatEngine`/`AgentToolLoop`. Should the owner's IP brain (Eidos/DAG/provenance/
 honesty) (a) ride on top via the generation-closure swap (current design — minimal,
 keeps IP out of Osaurus) or (b) be folded *into* a forked OsaurusCore loop? The docs
 favor (a); confirm.
4. **OpenClaw skip-list:** OK to SKIP the OpenClaw tool-loop-detection + context-budget
  - transcript-repair Swift ports because Osaurus/Goose already cover them, keeping
   only checkpoint/resume + depth-limiter + zero-config as genuine gaps?
5. **MMR vs RRF:** the app already has RRF fusion (k=60). Is OpenClaw's MMR recall worth
 a separate port, or does RRF already give enough recall diversity? (Recommend: verify
 empirically before porting.)
6. **vmlx-swift as the sole MLX stack:** consolidating onto vmlx-swift means the
 KnowledgeFusion training files (LoRA/KTO/AdapterApply) must reconcile against vmlx's
 API. Confirm those training paths are in-scope to migrate (vs. temporarily gated off)
 so the MLX swap can reach GREEN.
7. **Provenance for the 4 Hermes lifts + OpenClaw clean-rooms:** record as `clean_room`
 (mirror `OsaurusVendorProvenance`); confirm the quarantine-separately rule for the
 sibling Nous repos still stands.

---

## Sources

- **In-repo (read this session):** `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md` (+ 2026-06-21 owner directive), `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md`, `docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md`, `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md`, `docs/research/OSAURUS_ACT_CONNECTION_MAP_2026_06_19.md`, `docs/research/HERMES_OSAURUS_OPENCLAW_WIRING_R2_2026_06_19.md`, `docs/research/HERMES_OSAURUS_OVERLAP_AND_DESTINATION_2026_06_19.md`, `docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`, `docs/GOOSE_REPLACEMENT_STRATEGY.md`, `docs/GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md`, `docs/OPENCLAW_FEATURE_SPEC.md`, `docs/BEST_OF_CLAW_AND_OPENCLAW.md`, `CLAUDE.md`; code: `Epistemos/ActOsaurus/ActOsaurusBridge.swift`, `Epistemos/Work/WorkBackend.swift`, `agent_core/src/work.rs`, `agent_core/src/agent_loop.rs`, `agent_core/src/routing.rs`, `Epistemos/LocalAgent/LocalAgentLoop.swift`, `LocalPackages/osaurus/Packages/OsaurusCore/{Package.swift, Services/Chat/*, Tools/AgentLoopTools.swift, Managers/AgentManager.swift}`, `LocalPackages/vmlx-swift/Package.swift`, `LocalPackages/mlx-swift-lm/Package.swift`, `LocalPackages/osaurus/VENDOR.md`.
- **Web (primary/official):** [osaurus-ai/osaurus](https://github.com/osaurus-ai/osaurus) · [docs.osaurus.ai/security](https://docs.osaurus.ai/security) · [block/goose](https://github.com/block/goose) · [deepwiki block/goose](https://deepwiki.com/block/goose) · [sst/opencode](https://github.com/sst/opencode) · [opencode.ai/docs/server](https://opencode.ai/docs/server/) · [deepwiki sst/opencode LSP](https://deepwiki.com/sst/opencode/5.4-language-server-protocol-(lsp)) · [docs.openclaw.ai tool-loop](https://docs.openclaw.ai/tools/loop-detection) · [docs.openclaw.ai session/compaction](https://docs.openclaw.ai/reference/session-management-compaction) · [docs.openclaw.ai agent-runtimes](https://docs.openclaw.ai/concepts/agent-runtimes).

  

