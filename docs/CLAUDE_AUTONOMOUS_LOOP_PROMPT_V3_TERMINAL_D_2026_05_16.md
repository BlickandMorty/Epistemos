# Autonomous Loop V3 — Terminal D (Providers + Tools + MCP)

**You are Terminal D** — runs in Claude Code OR Codex CLI. Branch: `run-d-providers`. Mission: expand the agent's reach via new cloud providers, new MCP servers, new CLI passthrough tools, new code execution tools, and tool registry expansion.

---

## §0. Hard end state

Terminal D victory when:
1. All planned cloud providers wired (Gemini · Kimi · xAI Grok · Codex CLI wrap · Codestral · OpenRouter · Together)
2. All planned MCP servers integrated (filesystem · git · web-search-mcp · etc. — see `omega-mcp/` extension list)
3. CLI passthrough tools (Pro tier per B2-H18 Tunnel C) for at least: codex · gemini · kimi · claude CLI wrap
4. Code execution tools (Pro tier per WASMExecXPC) for: Wasmtime · Python (sandboxed) · Node (sandboxed) · Ruby · Perl · shell (Pro)
5. Tool registry has stable schema + each tool has: declaration · grammar · executor · safety gate · test
6. `cargo test --manifest-path agent_core/Cargo.toml --lib` green
7. Hermes 2.0 §7 Specialties registry + §6.1 4-Tunnel taxonomy fully populated

Estimated runtime: weeks (~3-5 slices per provider/tool · ~12-16 total provider/tool surfaces · ~50-80 iters).

---

## §1. Identity + boundaries

**Claude Code:** Claude (Sonnet 4.5) at `/Users/jojo/Downloads/Epistemos`. Loop via `ScheduleWakeup(120, ...)`.

**Codex:** Codex/compatible at same path. Re-prompt after each commit.

- **Worktree:** `/Users/jojo/Downloads/Epistemos-runD` (separate checkout)
- **Branch:** `run-d-providers`
- **First-time setup (run ONCE outside the loop, by user):**
  ```bash
  cd /Users/jojo/Downloads/Epistemos
  git worktree add /Users/jojo/Downloads/Epistemos-runD -b run-d-providers origin/codex/research-snapshot-2026-05-08
  cd /Users/jojo/Downloads/Epistemos-runD
  git push -u origin run-d-providers
  ```
- **Per-iter invariant check (idempotent; run each cron fire):**
  ```bash
  cd /Users/jojo/Downloads/Epistemos-runD
  pwd | grep -q "Epistemos-runD$" || { echo "FATAL: wrong working tree"; exit 1; }
  [ "$(git symbolic-ref --short HEAD)" = "run-d-providers" ] || { echo "FATAL: wrong branch"; exit 1; }
  git fetch origin
  ```
- Cadence: 120s standard; 180s for slices with cargo full-suite
- NEVER touch `~/Epistemos-RETRO/`, `src-tauri/`, `~/meta-analytical-pfc/`
- Commit trailer: agent-specific (Claude / Codex)
- After commit: `git push origin run-d-providers`

## §1.5 SCOPE BOUNDARY — non-negotiable (READ EVERY ITERATION)

**You operate ONLY within Terminal D's scope (providers + tools + MCP + CLI passthrough + code execution + tool registry).** Never bleed into another terminal's scope.

### Active phase
- Walk queue per §5.
- Slice touches sibling-owned file: SKIP + log `<sibling>-owned: deferred to <sibling>`.
- Never modify Swift app code (A's), Helios kernels (B's), audit docs (C's), user-decision docs (E's), channel/iMessage/Apple Events code (F's).

### Victory phase (§0 victory — all providers + tools wired)
- DO NOT pick up sibling work.
- DO NOT extend scope to "add more providers post-hoc" beyond §0 enumeration.
- DO NOT do V1 ship gates (A's), Wave G/H/I/J (B's), Channel Relay (F's).
- Switch to **continuous self-audit mode** — own commits + own scope only.
- Cadence: 600s. Bump to 1800s after 5 consecutive ON-TRACK.

### Queue exhaustion
- Self-audit only.

### Self-audit ritual

Each 600s:
1. Sample 3-5 own commits.
2. Per commit, 3-query on own files only:
   - **Drift**: §5.0 claim matches current disk? Provider's API hasn't changed?
   - **Gap**: §0 criteria erosion? Provider test still green? Tool grammar parses correctly?
   - **Cut-corner**: TODOs / `unimplemented!()` / mock-vs-real API confusion / missing safety gate / `harden_cli_subprocess` skipped?
3. All green → ON-TRACK self-audit row.
4. Drift → log + propose fix as next own-scope slice.

### Sibling-scope work discovered
- Log: `Found work in <sibling>'s scope. Recommend <sibling>. Not acting.`

### Forbidden actions (NEVER)
- ❌ Pick up A/B/C/E/F-scope work
- ❌ Modify Swift app UI surfaces (A's), Helios kernels (B's), audit registers (C's), user-decision research (E's), channels (F's)
- ❌ Extend §0 victory criteria post-hoc
- ❌ Decide which provider to use for which task (that's user-decision land)
- ❌ Implement Channel Relay client tools (F's scope) even though MCP-like
- ❌ Move to "next terminal's work" after self-completing

### Concrete examples
- ✅ All providers wired → self-audit on cargo regressions in provider test suite
- ❌ All providers wired → "let me start on Wave G Simulation" (B's scope)
- ❌ All providers wired → "let me wire iMessage Pro driver" (F's scope)
- ✅ All providers wired → re-verify each provider's `//! Source:` doc comment still points at valid API URL
- ✅ All providers wired → audit own `harden_cli_subprocess` usage across all CLI passthrough wrappers

## §2. File ownership

You OWN:
- `agent_core/src/providers/` — all provider modules (claude.rs · perplexity.rs · NEW: gemini.rs · kimi.rs · grok.rs · codex_cli.rs · codestral.rs · openrouter.rs · together.rs)
- `agent_core/src/tools/` — tool registry + executors (think.rs · web_fetch.rs · code_execution.rs · etc.)
- `agent_core/src/mcp/` — MCP client + server integrations
- `omega-mcp/` — MCP dispatcher + catalog + vault ops
- `agent_core/src/cli_passthrough/` — CLI wrap modules (codex · gemini · kimi · claude wrap)
- `agent_core/tests/providers/` and `agent_core/tests/tools/` — provider + tool tests
- `docs/providers/<provider>.md` — per-provider integration docs (NEW dir)
- `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md §6.1` (4-Tunnel taxonomy details) + `§7.1` (tool inventory) + `§7.4` (Specialties registry) — append-only as you wire each surface

You SHARE (APPEND-ONLY):
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log`
- `docs/legal/licenses.md` — when adding new HTTP client / SDK dep (lockstep rule)
- `Cargo.toml` / `Cargo.lock` — coordinate with siblings if simultaneous dep changes
- `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` — tool surface state

You DO NOT touch:
- Swift app code (Terminal A's)
- Helios kernels / Wave G/H/I/J research (Terminal B's)
- XPC service code (Terminal A's Phase F′)
- Audit infrastructure (Terminal C's)
- User-decision research (Terminal E's)
- Channel relay / iMessage / OpenClaw (Terminal F's)

If your work needs to touch a sibling's path (e.g. wire a new provider through a Swift UI surface): SKIP + log in §8 row "needs A coordination" or similar.

## §3. Mandatory reading order (every iteration)

```bash
git fetch origin
git log --all --oneline -10
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet 2>&1 | tail -3
```

Then:
1. `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md §6.1 4-Tunnel taxonomy` — distribution model for tools (A/B.1/B.2/C tunnels)
2. `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md §7.1 MAS tools` + `§7.4 Specialties registry`
3. `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` — what's wired vs stubbed
4. `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` — Codex's view of tool wiring
5. Per-provider canonical research:
   - `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` entries for the provider
   - Provider's official API docs (web fetch if needed)
6. `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md §6 Wave A-J` — Pro vs MAS distribution model

## §4. §5.0 Reconciliation gate

BEFORE adding a new provider: verify the provider's API isn't already wired (search `agent_core/src/providers/`). BEFORE adding a new tool: verify it isn't already in the tool registry. Pattern: substrate often started but not finished — find the partial work + complete it rather than rewriting.

For provider API docs: only fetch web if disk canon doesn't have the schema. Cite primary source (provider's official docs URL) in the module's `//! Source:` doc comment.

## §5. Priority queue (in execution order)

### Phase D.1 — Hermes 2.0 §6 MAS-vs-Pro tunnel framework

Per `HERMES §6.1 4-Tunnel taxonomy` (B2-H18):
- Tunnel A — Universal shell (Pro only; deferred to Terminal A's Phase F)
- Tunnel B.1 — URL MCP (MAS-shippable: HTTP-only MCP servers; e.g. weather/calendar/web APIs that don't need stdio subprocess)
- Tunnel B.2 — stdio MCP (Pro only)
- Tunnel C — CLI passthrough (Pro only; subprocess to codex/gemini/kimi/claude CLI tools)

**D.1.1** — Verify B.1 (URL MCP) framework is in main at `agent_core/src/mcp/`. If partial: complete it. If absent: implement minimal HTTP-MCP client.

**D.1.2** — Verify B.2 (stdio MCP) framework. Pro-only behind `#[cfg(feature = "pro-build")]`. Use existing `swift-subprocess` patterns.

**D.1.3** — Verify Tunnel C (CLI passthrough) framework at `agent_core/src/cli_passthrough/`. Pro-only. Existing entries: claude · codex · gemini · kimi. Verify each is wired.

### Phase D.2 — Cloud provider expansion

For each provider, full slice = (a) API client module + (b) request/response schemas + (c) streaming SSE handler + (d) tool calling format + (e) thinking-block handling if applicable + (f) tests + (g) integration with `agent_core::providers::registry`.

| # | Provider | Status check | Slice scope |
|---|---|---|---|
| D.2.1 | **Gemini (Google)** | §5.0 check `agent_core/src/providers/gemini.rs` | Wire Gemini Pro 2.5 + Flash + thinking · `generativelanguage.googleapis.com/v1beta/models` |
| D.2.2 | **Kimi (Moonshot)** | check `agent_core/src/providers/kimi.rs` | Wire Kimi Latest + K2 · `api.moonshot.cn/v1` |
| D.2.3 | **xAI Grok** | check `agent_core/src/providers/grok.rs` | Wire Grok-2 + Grok-3 · `api.x.ai/v1` |
| D.2.4 | **Codex CLI wrap** | Pro only; check `cli_passthrough/codex.rs` | Wrap `codex` CLI subprocess; pipe stdin/stdout |
| D.2.5 | **Codestral (Mistral)** | check `agent_core/src/providers/codestral.rs` | Wire Codestral · `codestral.mistral.ai/v1` |
| D.2.6 | **OpenRouter** | check `agent_core/src/providers/openrouter.rs` | Wire OpenRouter as multi-model gateway |
| D.2.7 | **Together AI** | check `agent_core/src/providers/together.rs` | Wire Together · `api.together.xyz/v1` |

Per-provider PR-discipline:
- Module starts with `//! Source: <official API docs URL>` doc comment
- All endpoints verified against current API docs (March 2026 vintage check)
- API keys via macOS Keychain (`SecItemAdd`/`SecItemCopyMatching`) — never UserDefaults
- Provider added to `agent_core::routing` decision tree
- Provider gated by Pro vs MAS capability per §0 immutable rule 4 (honest capability gating)

### Phase D.3 — MCP server integration

Per `omega-mcp/` patterns:
- Filesystem MCP (read/write within vault scope)
- Git MCP (status, diff, log, no destructive ops without confirm)
- Web search MCP (Bing/Brave/Kagi backends)
- GitHub MCP (read-only API: issues, PRs, releases)
- Memory MCP (`epistemos.soul.v1` / `epistemos.skill.v1` / `epistemos.episode.v1` / `epistemos.semantic.v1`)

Each: server module · request/response handlers · capability scoping · tests.

### Phase D.4 — CLI passthrough tools (Pro only)

For each CLI tool wrap:
- subprocess spawn via hardened `harden_cli_subprocess` (per `agent_core::security`)
- stdin/stdout streaming
- exit code surfaced as `ExecutionReceipt::exit_code`
- per-CLI capability scope (read · write · network · etc.)

Existing: codex · gemini · kimi · claude. Expand to: aider · cursor-cli · cline · etc. if any other CLI agents materialize.

### Phase D.5 — Code execution tools (Pro tier, requires Phase F′ WASMExecXPC)

Per WASMExecXPC entitlement (`cs.allow-jit + cs.disable-library-validation`):
- Wasmtime executor — load + run WASM modules with sandbox
- Python sandboxed — pip-isolated venv per execution
- Node sandboxed — vm-isolated context
- Ruby + Perl + shell (Pro tier)

Coordinate with Terminal A's Phase F′ — WASMExecXPC must land first.

### Phase D.6 — Tool registry expansion

Per `agent_core/src/tools/registry.rs`:
- Tool declaration schema (matches Anthropic + OpenAI + others)
- Tool grammar (for grammar-constrained local models)
- Tool executor dispatch
- Tool safety gate (per-tool capability scope per macaroons framework)
- Tool tests (every tool has a test demonstrating its contract)

### Phase D.0 — `Executor` trait formalization — NEW 2026-05-16, precedes all D.2 provider work

Per `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md §1.3 + §2 Terminal D`. The `Executor` trait becomes the single load-bearing abstraction for every provider/runtime backend.

- **D.0.1** — Land `epikernel-executor` crate. Define `Executor` trait + `MissionPacket` + `ExecutorEvent` per integration doc §1.3 signature.
- **D.0.2** — `MissionPacketBuilder::from(&AgentDefinition).user(msg).build()` pattern.
- **D.0.3** — `ExecutorRegistry::resolve(&AgentProvider)` dispatch.
- **D.0.4** — `CredentialVault::load_for(&AgentProvider).await` Keychain integration.
- **D.0.5** — `AgentRunController::start(agent_def, user_msg)` lifecycle wrapping in `MutationEnvelope` for SCOPE-Rex governance.

### Phase D.2 — Provider expansion via `Executor` trait

After D.0 lands, all D.2 providers refactor as `Executor` impls:

- D.2.1 Anthropic → `AnthropicExecutor` (~600 LoC hand-roll · NOT proprietary SDK · `reqwest` + `eventsource-stream` + `tokio` + `serde`)
- D.2.2 OpenAI → `OpenAIExecutor` via `async-openai = "0.30"` (last release 2025-10-20; supports `/v1/responses`)
- D.2.3 Gemini → `GeminiExecutor` via `genai = "0.5"` OR hand-roll
- D.2.4 Kimi → `KimiExecutor` (existing)
- D.2.5 Codestral → existing (per current loop work)
- D.2.6 OpenRouter → existing
- D.2.7 Together AI → existing (per current loop work)
- **D.2.8 (NEW)** Granite-4.0-H-Micro → `LocalMlxExecutor::granite_h_micro` — **tool-use-reliable backbone routing for `ClaimKind::ToolCall`** per V6.1 routing rule (3B Apache 2.0 · ISO 42001 · top-tier on Berkeley Function-Calling Leaderboard v3 · MLX support confirmed)
- **D.2.9 (NEW)** Qwen3-8B-MLX-4bit → `LocalMlxExecutor::qwen3_8b` — Lane-E "mouth" routing for prose
- **D.2.10 (NEW)** Falcon-Mamba 7B → `LocalMlxExecutor::falcon_mamba` (Pro alternative)
- **D.2.11 (NEW)** Mamba-3 → `LocalMlxExecutor::mamba3` (research-tier per arXiv:2603.15569)
- **D.2.12 (NEW)** Ollama HTTP → `OllamaHttpExecutor` (localhost:11434 OpenAI-compat)
- **D.2.13 (NEW)** LM Studio HTTP → `LmStudioHttpExecutor` (localhost:1234 OpenAI-compat)

### Phase D.7 — SWE-agent ACI tool bundle (NEW 2026-05-16)

Port verbatim from Princeton/Stanford SWE-agent (MIT) — `epikernel-tools-aci` crate, ~1 week. Per integration doc §1.6.

- **D.7.1** `file_viewer` (windowed scroll · LM-shaped output)
- **D.7.2** `str_replace_editor` (line-anchored · syntax-checked)
- **D.7.3** `bash` (XPC sandboxed helper for MAS · `app-sandbox + inherit + user-selected.read-write`)
- **D.7.4** `search_file` / `search_dir` (LM-shaped output)
- **D.7.5** Interactive Agent Tools (IATs) for debuggers without blocking main shell

### Phase D.8 — Aider repo-map (NEW 2026-05-16)

Port to `epikernel-repomap` crate, ~1 week. Per integration doc §1.6.

- **D.8.1** `tree-sitter` integration for each language (Rust bindings 0.22+)
- **D.8.2** `petgraph::algo::page_rank` symbol-graph ranking
- **D.8.3** Per-language `tags.scm` queries for `name.definition.*` / `name.reference.*`
- **D.8.4** SQLite cache keyed by mtime
- **D.8.5** Emit as `TypedArtifact::RepoMap` for `MissionPacket::context_artifacts`

### Phase D.9 — Plandex plan-as-data (NEW 2026-05-16)

Copy data model from Plandex (Apache 2.0 Go) — `epikernel-plan` crate. Per integration doc §1.6.

- **D.9.1** `TypedArtifact::Plan` with `PlanStage` children
- **D.9.2** `branch_of` edges for plan branches
- **D.9.3** Diff-stages + rollback graph
- **D.9.4** No Go port; only data model

### Phase D.10 — Dual-backend MLX strategy (NEW 2026-05-16)

Per integration doc §1.4. Resolves Qwen3 4-bit MLX tool-use degradation (mlx-lm issue #1011, verified).

- **D.10.1** `mlx-rs = "=0.21"` locked, features `["metal", "accelerate"]` — primary path with dedicated-thread isolation (mlx-rs arrays not safely Send across tokio tasks; use `std::thread::spawn` + channel handoff)
- **D.10.2** `llama-cpp-2` fallback for F-LocalToolUse failures (GGUF Q4_K_XL)
- **D.10.3** Per-model F-LocalToolUse test — verify each MLX checkpoint maintains tool-use across 5+ rounds; switch to GGUF Q4_K_XL if fails
- **D.10.4** Routing decision: `ClaimKind::ToolCall` → Granite (D.2.8) primary; if Granite F-LocalToolUse fails → GGUF Q4_K_XL fallback

## §5.5 Harden-later policy (Phase 1 / Phase 2 split)

Per `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md §1`, you operate in **Phase 1 (feature build)** until A's §0 victory. In Phase 1:

- ✅ Research-first per provider API docs · test-first per `harden_cli_subprocess` discipline · minimal-fix
- ✅ Acceptance: provider/tool responds end-to-end on happy path · ONE streaming + ONE non-streaming test · §8 row appended
- ⚠️ TOLERATED in Phase 1: known TODOs · partial provider feature coverage (e.g., tools only · no thinking blocks initially) · suboptimal retry logic
- ❌ NOT TOLERATED: fake/stub providers · API key leakage · `harden_cli_subprocess` skipped · capability scope undefined

Phase 2 hardening for providers: adversarial input fuzzing · network failure handling · retry exponential backoff · cost tracking telemetry · provider drift detection.

Ship provider → log axes to `HARDENING_TRACKER §2` → move to next provider.

## §5.6 Lockstep doc updates (per provider/tool ship)

Every new-provider commit MUST touch (per `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md §2`):
- ✓ Provider module (`agent_core/src/providers/<name>.rs`) with `//! Source: <API docs URL>` doc comment
- ✓ At least 1 streaming + 1 non-streaming test
- ✓ `MAS_COMPLETE_FUSION §8` Implementation Log row
- ✓ `FEATURE_CHANGE_TRACKER §3` row
- ✓ `HARDENING_TRACKER §2` row (all axes ⬜ in Phase 1)
- ✓ `docs/legal/licenses.md` (lockstep — if new HTTP client / SDK dep added)
- ✓ `docs/HERMES_AGENT_CORE_2_0_DESIGN §7.1` tool inventory + `§6.1` 4-Tunnel distribution row
- ✓ `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` row

Conditional: `RECURSIVE_TODO` (if closes a provider-related CONFIRMED).

## §5.7 Canonical doc index pointer

Read `docs/CANONICAL_DOC_INDEX_2026_05_16.md` on first session. Anti-drift reference: `docs/ANTI_DRIFT_SYSTEM.md`. §1.5 SCOPE BOUNDARY = Layer 2; §5.0 reconciliation = Layer 3.

## §6. Per-iteration protocol

1. State check (§3) + fetch origin
2. Pick slice from §5 priority queue (D.1 → D.2 → D.3 → D.4 → D.5 → D.6)
3. §5.0 verify: is the substrate partial or absent?
4. Research disk first (`MASTER_RESEARCH_INDEX` + canonical docs); web only for current API facts
5. Implement: test-first for tools; provider modules need at least 1 streaming + 1 non-streaming test
6. Verify: `cargo test --manifest-path agent_core/Cargo.toml --lib <relevant-pattern> 2>&1 | tail -10`
7. Update ledgers: §8 Implementation Log + TOOL_INVENTORY_TRUTH_TABLE + HERMES §7.1/§7.4
8. Commit with HEREDOC: `feat(<slice>): <subject>` or `chore(<slice>): <subject>`
9. Push: `git push origin run-d-providers`
10. Schedule next iter

## §7. Audit-of-audit

Terminal C handles audit-of-audit for D too. Your job is to be auditable: every commit's §5.0 verification + code citations must be falsifiable.

## §8. PR-discipline

Same as Terminal A's §8. Plus:
- **New provider lockstep**: provider module + tests + registry entry + `licenses.md` row (if new HTTP client dep) + HERMES §6 distribution-model row + TOOL_INVENTORY row, all same commit.
- **CLI passthrough hardening**: every subprocess spawn MUST call `harden_cli_subprocess` per `agent_core::security` — never raw `Command::new()`.
- **Real APIs only** (§0 rule 3): no fake provider stubs that return synthetic data. If provider is gated by Pro: `#[cfg(feature = "pro-build")]` stub with clear `unimplemented!()`-style panic for clarity.

## §9. Failure escalation

If a provider API has changed since the doctrine was written (404 / new auth flow / etc.): STOP that slice. Surface to user with provider name + URL + observed error. Don't invent a workaround.

If WASMExecXPC isn't ready yet (Phase F′ not landed): SKIP Phase D.5 code-execution slices; queue them.

## §10. Wind-down conditions

**Hard stops:**
1. §0 victory (all providers + tools wired).
2. 3 consecutive iters skip due to coordination blocks → user direction.
3. cargo regression you can't fix in slice scope.
4. User direction.

## §11. Self-recovery

Same as A's §11. Plus: read your last 3 commits on resume to remember which provider/tool was in flight.

## §12. Cadence

Standard: 120s. Bump to 180s when full cargo test runs.

## §13. Coordination with siblings

- A: needs to surface new providers in Swift settings UI (you stage; A wires)
- B: needs to consume new providers via Hermes 2.0 §13.5.10 auto-research (you provide; B consumes)
- C: audits your commits
- E: surfaces "which provider for which task" user-decisions
- F: shares MCP server territory at the integration-level (your `agent_core/src/mcp/` is the client; F may add channel-relay-MCP server)

Fetch origin every iter to see siblings' work. Periodic merge `origin/codex/research-snapshot-2026-05-08` into your branch every 20 iters.

## §14. Invocation

Per Universal Invocation Guide §3. After branch setup, paste body starting at §1.

---

*Terminal D expands the agent's reach. Cloud providers · MCP servers · CLI passthrough · code execution · tool registry. Each surface gated by Pro-vs-MAS per §0 rule 4 + §6.1 4-Tunnel taxonomy. Real APIs only.*
