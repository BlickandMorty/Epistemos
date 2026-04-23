# Epistemos — Implementation Plan Synthesized from the Four-Model Council

**Sources:** Gemini paper (v1 + v2 synthesis), Perplexity paper (+ master synthesis), Claude paper, GPT paper, PLAN_V2 (claude advice.md), Meta-prompt for Claude brainstorming, live-code audit.
**Status date:** 2026-04-22.
**Author context:** synthesis produced after reading all source documents end-to-end and running a live-code audit to align the plan with what is already built.

## Change log

- **2026-04-22 (v1):** initial synthesis based on 4 source papers + PLAN_V2 + live audit.
- **2026-04-22 (v1.1):** integrated Gemini's v2 synthesis plan (which now agrees MAS = dead end, Developer ID primary, Docker opt-in default-off, CLI-subprocess demoted to fallback-not-primary). Added **Appendix A** containing concrete specs for MCP tool surface, router decision table, session bootstrap sequence, CLAUDE.md template, 25-component palette, kill switch ownership chain, 9B planner decision, security/approval ladder, GRDB observability schema, and a 50-task golden seed set.
- **2026-04-22 (v1.2):** integrated the **CLI Config Compilation Research** (copied into [docs/CLI_CONFIG_COMPILATION_RESEARCH.md](CLI_CONFIG_COMPILATION_RESEARCH.md)). This research is now the **single source of truth** for Phase G. Ran a drift audit — see new §0.5 — and fixed four specific errors in my v1.1 Appendix A.4 templates. Added **Appendix B — Anti-Drift Reference Card** (pinned April 2026 facts with citations) and **Appendix C — Executable Claude Code build brief** (copy-pasteable session prompts for each phase).
- **2026-04-22 (v1.3):** integrated the GPT UX synthesis on fusing "tools chat" into normal chat. Added **§4.3a Composer controls** (Mode × Effort × Tools — three orthogonal axes) and **Phase I — Chat/Agent mode fusion** between Phases D and E (4 committable sub-phases: backend unification, Smart Chat profile, Agent first-class with promotion, Workbench demotion). Added **Appendix D — New Session Bootstrap Prompt** (lightweight copy-pasteable context loader for any Claude Code / Codex / chat session on this project). Final completeness audit — nothing of value from the 7 source documents is missing.
- **2026-04-22 (v1.4):** added the **unified knowledge graph + per-model native memory** vision. Updated §4.2 Knowledge Layer to make every chat (regular, note-attached, group, agent session) a first-class graph node alongside notes, entities, and model vaults. Added **Phase J — Unified Knowledge Graph + Per-Model Native Memory** with explicit regression-safety rules (additive schema, existing queries unaffected, existing write paths untouched). Each model now gets a memory folder engineered to its native format: Claude → CLAUDE.md + `.claude/rules/*` + `.claude/skills/*` + `plans/` (auto-memory) + structured `facts/*.json`; Codex → AGENTS.md + `rules/` + `skills/` + `sessions/*.jsonl`; Gemini → GEMINI.md + `memory/` (memoryTool format) + `rules/` + `skills/`; Qwen → CORE.md + `facts.yaml` + `few-shot/*.jsonl` + MLX-backed embedding store. Shared memory layer sits above per-model folders with provenance links into the knowledge graph.
- **2026-04-22 (v1.5):** added **Phase K — iMessage Channel Unification (OpenClaw-style dispatch)**. Clarified that iMessage is currently wired as a **tool** (outbound from agent) but not as a **channel** (inbound to agent). The OpenClaw-inspired channel implementation design exists in [docs/BEST_OF_CLAW_AND_OPENCLAW.md §9](BEST_OF_CLAW_AND_OPENCLAW.md) but isn't wired. Phase K wires the existing design into the unified AgentRuntime (not directly to CLIs) so inbound iMessage routes through the same Router as regular Chat, with workspace-scoped dispatch profiles (allowed senders × tool allowlist × approval tier per workspace). iMessage chats become `Chat(kind="imessage")` graph nodes (extends Phase J). This is a STRICTLY BETTER architecture than Claude Code's Remote-Control/Channels pattern because it works offline via Qwen, applies Epistemos's approval/validation layer, and supports multiple workspaces with distinct permissions.
- **2026-04-22 (v1.6):** final completeness pass. Added **§0.4 Document Map** — canonical navigation for any new session, codifies the "rule of five" (≤5 docs loaded per session). Completed **Appendix C** with prompts for Phases D (Qwen three-tier), I (Chat/Agent fusion), J (unified graph + per-model memory), and K (iMessage channel) — previously only 0/A/B/C/G had prompts. Added stub prompts for Phases E/F/H. Unified the prompt framework: Appendix D is the BASE context load for all sessions, Appendix C phase prompts EXTEND D without duplicating drift alarms or always-load files. Added **explicit supersession note** in Appendix D marking MASTER_SESSION_PROMPT.md (2026-03-30) as historical; Appendix D is canonical from 2026-04-22 forward. Every phase in §5 now has a corresponding Appendix C prompt or stub.
- **2026-04-22 (v1.7):** verification pass. Fixed four internal inconsistencies: (1) §4.2 Settings pane escalation threshold now explicitly distinguishes Chat (3 hops) vs Agent (8 hops) profile to match §4.3a and Phase D; (2) §4.3 routing table "Multi-step agent" row now shows the 3-hop-for-Chat / 10-hop-for-Agent ceiling per profile; (3) §7.1 renamed "Phase I (Omega demolition)" to **"Phase Ω (Omega demolition)"** to avoid collision with the Chat/Agent fusion Phase I added in v1.3; (4) every cross-reference to "v1.5" updated to "v1.7". Inlined **three executable code primitives** previously only prosed: Rust `AgentEvent` enum + `AgentEventSink` UniFFI callback interface in new §4.6 (Phase A reference code), Rust ReAct loop template in Phase D.2 (so future sessions don't need the Claude paper), and Swift `iMessageChannel` actor skeleton in Phase K.1 (so the agent can copy-paste the right shape directly). Plan is now self-contained — no paper references required to execute any phase.

## 0.4 Document Map — where everything lives

Any session (human, Claude Code, Codex, ChatGPT) should be able to navigate this project using only this map. Files are listed in priority order within each category — read from the top down.

### Canonical plan docs (read for agent/runtime/UX work)

| Doc | Purpose | When to read |
|---|---|---|
| `CLAUDE.md` (repo root) | Non-negotiable project rules, stack map, hard NO's | Always, first |
| `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md` | Auto-memory index (user profile, pinned feedback, accumulated context) | Always, second (auto-loaded by Claude Code) |
| `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` (THIS DOC) | v1.7 synthesized plan — 12 phases, 4 appendices, drift-proof, code-snippet-inlined | Any agent/runtime/settings/chat/graph/memory/iMessage work |
| `docs/AGENT_PROGRESS.md` | Live state: what's done, what's in progress | Always, third |

### Research docs (read when touching the referenced surface)

| Doc | Purpose | When to read |
|---|---|---|
| `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` | April-2026 ground truth for CLAUDE.md / `.claude/` / `.mcp.json` / `.codex/config.toml` / `.gemini/settings.json` schemas + `EpistemosManifest` Rust struct | Phase G, and any CLI-config work |
| `docs/BEST_OF_CLAW_AND_OPENCLAW.md` | OpenClaw-inspired patterns: auto-discovery, skills system, iMessage channel (§9), cron keepalive, auth rotation | Phase K (iMessage), Phase I.4 (Workbench), auto-discovery work |
| `docs/PLAN_V2.md` | Canonical roadmap covering editor architecture (§23), agent streaming (§24), graph zero-copy (§25), anti-pattern register (§27), BoltFFI audit (§22), workspace/profile ontology (§19) | Editor, BoltFFI, graph-engine, Phase K workspaces |
| `~/Downloads/Advice/*.pdf` / `*.md` | The four original model papers (Claude, Gemini, Perplexity, GPT) + syntheses | Historical — only re-read if the synthesis in §2 is questioned |

### Sprint + legacy session docs (reference only)

| Doc | Status | Note |
|---|---|---|
| `docs/MASTER_SESSION_PROMPT.md` | **SUPERSEDED 2026-04-22** | Historical. Appendix D of this plan is the canonical bootstrap prompt going forward. MASTER_SESSION_PROMPT.md remains useful for its March 30 state summary (completed OpenClaw safety work, FFI hardening) — reference it only for "what was already built before 2026-04-22." |
| `docs/AGENT_INTEGRATION_SESSION_PLAN.md` | Partially superseded | Phase 1-7 content is live (per `project_phase_1_7_complete.md` memory). Remaining items mapped into this plan's §5 where relevant. |
| `docs/sprint-sessions/*.md` | Active | The current sprint file is referenced from CLAUDE.md startup protocol. Read when a sprint is in progress. |
| `docs/handoffs/*` | Historical | Release-prep snapshots; only read if working on a release gate. |
| `docs/APP_ISSUES_AUTO_FIX.md` | Active | Runtime issues discovered during use. Per CLAUDE.md, check on every session start for `Status: Open` issues to opportunistically fix. |

### Memory (auto-loaded, editable)

Files in `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/` — see `MEMORY.md` for the index. Key entries:

- `user_profile.md`, `user_hardware.md` — user context
- `feedback_*.md` — pinned behavior rules (minimal-fixes, commit-after-change, doc-verbosity, etc.)
- `project_advice_council_2026_04_22.md` — four-model synthesis verdict
- `project_unified_graph_and_memory.md` — Phase J vision
- `project_imessage_channel.md` — Phase K vision
- `project_release_pivot.md`, `project_model_profiles.md`, `project_agent_integration_status.md` — active project state

### Code docs (rarely needed, read for specific deep-dive)

`docs/AGENT_RUNTIME_ARCHITECTURE.md`, `docs/AGENT_MIGRATION_MATRIX.md`, `docs/AGENT_BENCHMARKS.md`, `docs/AGENT_COMMAND_CENTER_UX_HANDOFF.md`, `docs/CONTROL_PLANE_RESEARCH.md`, `docs/CODE_EDITOR_*.md`, `docs/ARCHITECTURE_MAP.md`, etc. — consult when touching the specific subsystem.

### The rule of five

A new session should be able to load everything it needs in **≤5 docs**:
1. `CLAUDE.md` (always)
2. `MEMORY.md` index (always, auto-loaded)
3. `AGENT_PROGRESS.md` (always)
4. `IMPLEMENTATION_PLAN_FROM_ADVICE.md` — the relevant phase only
5. One task-scoped doc (CLI_CONFIG, BEST_OF_CLAW, PLAN_V2, or the current sprint file)

Anything more is probably over-loading context. Anything less is probably missing something the plan explicitly flagged. Appendix D codifies this rule.

---

## 0.5 Drift audit — v1.1 plan vs CLI config research

After the CLI config research landed, I re-read my v1.1 Appendix A templates and found four specific errors. All are now corrected or annotated. This section exists so any future session can verify the plan has not re-drifted from the research.

| Plan v1.1 claim | April 2026 ground truth (citation) | Status | Fix |
|---|---|---|---|
| `.claude/settings.json` is where MCP servers go | `mcpServers` in `settings.json` is **silently ignored**. Must live in project `.mcp.json` or user `~/.claude.json`. [Issue #24477](https://github.com/anthropics/claude-code/issues/24477) | **DRIFT** | Appendix A.4 now references the research; Phase G compiler emits a separate `.mcp.json` file. |
| Codex MCP key is `mcp.servers.<id>` | Correct key is top-level `[mcp_servers.<id>]` TOML table. Silent fail bug: [openai/codex#3441](https://github.com/openai/codex/issues/3441) | **DRIFT** | Research §2.4 is the source of truth; compile() must emit the correct form. |
| Codex `approval_policy = "on-failure"` | **Deprecated.** Current options: `untrusted`, `on-request`, `never`, or `{granular = {...}}`. | **DRIFT** | Use `on-request` for interactive, `never` for CI. |
| Gemini `mcp: { servers: {...} }` | Correct: `mcpServers: {...}` at top level; `mcp: { allowed: [], excluded: [] }` is separate. | **DRIFT** | Research §3.2 is the source of truth. |
| "deny rules are authoritative" | Claude `permissions.deny[]` is reported as **flaky**. Must pair with a `PreToolUse` hook returning exit code 2 for truly sensitive patterns. [settings docs](https://code.claude.com/docs/en/settings) | **DRIFT** | Phase F verification now mandates the defense-in-depth hook. |
| CLAUDE.md is one monolithic file | CLAUDE.md should be a thin index + `@.claude/rules/*.md` imports; single files cap at ~40K chars before truncation. | **PARTIAL** | See Appendix A.4 correction below. |
| Claude Code hooks = "SessionStart, PreToolUse, PostToolUse" | **21 events** exist as of the 2026 rework. [hooks docs](https://code.claude.com/docs/en/hooks). | **UNDERSPECIFIED** | Appendix B pins the full event inventory. |
| Qwen planner on 16GB = Apple Foundation Models (§A.7) | Correct — unchanged. | OK | — |
| Event streaming pipeline uses `AgentEvent` enum with text_delta/tool_use/etc. variants | Correct — unchanged. | OK | — |
| Docker opt-in default-off | Correct — unchanged. | OK | — |

**Anti-drift principle:** whenever this plan contradicts [CLI_CONFIG_COMPILATION_RESEARCH.md](CLI_CONFIG_COMPILATION_RESEARCH.md) in the Phase G / CLI integration surface, **the research wins.** That doc is pinned to vendor documentation URLs; this plan is synthesis prose.

---

## 0. How to read this document

This is not a replacement for `docs/PLAN_V2` or `docs/AGENT_RUNTIME_ARCHITECTURE.md`. It is a **decision document** that:

1. Resolves where the four models agreed and where they conflicted.
2. Grounds each recommendation against what is already live in the Epistemos codebase (so no work is duplicated).
3. Answers the Mac App Store / sandbox question directly — with a specific shipping recommendation.
4. Produces a **phased implementation plan** whose every phase is either (a) greenfield, or (b) a minimal-scope addition on top of existing code — no large refactors.
5. Defers contested optimizations behind benchmarks, in line with the existing anti-pattern register.

The four-model council is treated as advisory. Where two or more models converge, the recommendation is strong. Where a single model disagreed with the consensus and was right (Claude paper on sandbox/PTY, Gemini paper on few-shot prompting), that dissent is preserved. Where a single model disagreed and was wrong (Gemini paper mandating Docker + React/Tauri), it is overridden with reasoning.

---

## 1. The Mac App Store / Sandbox Question — Decisive Call

### 1.1 The hard constraint

You asked: *"Can we bypass the sandbox and still get on the Mac App Store?"*

**Short answer: no — not for the app you described. Yes — for a stripped-down sibling edition.**

This is the one question where the four models had unambiguously different answers, and the Claude paper was the only one that got the facts right. Gemini and Perplexity hand-waved it, and GPT touched it briefly. Here is the unambiguous truth as of April 2026:

Apple's App Store Review Guidelines combined with the App Sandbox spec require:

1. Any executable your app spawns must be signed with `com.apple.security.app-sandbox` and `com.apple.security.inherit`.
2. Node-based CLIs installed via npm (`claude-code`, `@openai/codex`, `@google/gemini-cli`) are unsigned by npm. They cannot inherit your sandbox.
3. Even the official `modelcontextprotocol/swift-sdk` example explicitly notes that **stdio MCP servers require disabling sandboxing**.
4. JIT memory (`com.apple.security.cs.allow-jit`) is allowed in MAS but is only strictly needed for MLX Metal compilation — not the blocker.
5. `com.apple.security.cs.allow-unsigned-executable-memory` is a non-starter for MAS.

The Epistemos product, as you've described it, inherently spawns the user's unsigned `claude` / `codex` / `gemini` CLIs, hosts stdio MCP servers, and wants shell/Docker exec capability. **That combination is disqualifying for MAS.** No entitlement combination fixes this.

### 1.2 What to ship — the two-edition strategy

| Edition | Distribution | Sandbox | Spawns CLIs | MCP stdio | Shell/Docker | Customers |
|---|---|---|---|---|---|---|
| **Epistemos** (primary) | Developer ID + notarized, direct download | **No App Sandbox** | Yes | Yes | Yes | Power users, devs, the actual audience |
| **Epistemos Lite** (MAS) | Mac App Store, sandboxed | Yes (App Sandbox) | No | HTTP MCP only | No | Users who only trust MAS; trial funnel |

Both editions share the same Swift + Rust + MLX codebase. The MAS edition is produced by a **single compile-time feature flag** (`--features mas-sandbox`) that:

- Disables the CLI subprocess path (`cli_passthrough.rs` compiled out)
- Disables Bash/MultiEdit/shell tools
- Disables stdio MCP (keeps HTTP/SSE MCP clients)
- Disables Docker code paths (when/if added)
- Hides the "Power mode" toggle from Settings
- Requires API key entry (no CLI auth reuse)

This is how Cursor, Zed, Warp, Raycast, and Aider-Desktop all ship. None of them appear on the Mac App Store for their flagship product. Some ship a neutered sibling. **This is not a hack — this is the industry-standard posture for this class of tool.**

### 1.3 The specific entitlements you need for the primary edition

From the Claude paper, verified against Apple's 2026 notarization docs:

```xml
<!-- Hardened Runtime: YES. App Sandbox: NO. -->
<key>com.apple.security.cs.allow-jit</key> <true/>        <!-- MLX Metal compilation -->
<key>com.apple.security.cs.disable-library-validation</key> <true/>  <!-- mlx-lm + child Node CLIs -->
<key>com.apple.security.network.client</key> <true/>      <!-- provider APIs -->
<!-- Explicitly DO NOT include com.apple.security.app-sandbox -->
<!-- Explicitly DO NOT include com.apple.security.cs.allow-unsigned-executable-memory -->
```

Verify with `codesign -d --entitlements - <path>` after build and log to CI. This is exactly what Cursor ships.

### 1.4 Framing for users

From the Claude paper's legal read, which is correct: **never describe Epistemos as "rerouting" a user's Claude Pro/Max subscription through your backend.** Anthropic's ToS prohibits third parties from offering Claude.ai login for business use. The safe framing is:

> "Epistemos launches your existing Claude Code with a prompt you author."

Implement this by always spawning `claude -p` with the `--bare` flag so Epistemos never accidentally picks up keychain OAuth in a way that looks like rerouting, and always surface the provider badge on every message ("routed to: Claude Code CLI · Pro subscription").

### 1.5 Verdict (now unanimous across all four models)

Ship Epistemos as Developer ID notarized, no App Sandbox. Optionally ship Epistemos Lite on MAS for trial acquisition. Do not fight Apple's rules — the industry converged on this posture because it is the only one that works.

**Consensus note:** Claude paper called this first. GPT paper touched it briefly. Perplexity paper didn't address it. Gemini paper v1 hand-waved; **Gemini paper v2 explicitly agrees: "you must abandon the Mac App Store … You will sign with your Apple Developer ID and use Apple Notarization with the Hardened Runtime. This is the exact path taken by Cursor, VS Code, and Obsidian."** All four models now converge.

---

## 2. Per-Model Deliberation

Each of the four papers provided a prompt for me plus a paper. Here is what each proposed, what is right about it, what is wrong, and what to take.

### 2.1 Gemini's path — "Zero-Copy, Sandboxed-Native, Protocol-Driven" (v1 → v2 synthesis)

**What it proposed (v1):** BoltFFI-mandatory FFI (1000× faster than UniFFI), Bollard + portable-pty + rexpect PTY abstraction, Docker-per-session, Qwen 3.5 4B on MLX (158 t/s, 73% tool accuracy), A2UI catalog, React/Tailwind/Shadcn frontend.

**What it changed in v2:** Gemini's updated synthesis plan now **agrees with the Claude paper on distribution** — MAS is a dead end, Developer ID + Hardened Runtime + Notarization is the correct posture. It also **softened on Docker** to "Native PTY default, Docker opt-in" (matches Phase H below). It **kept SwiftUI + Rust + BoltFFI + MLX-Swift as the primary stack** (explicit demotion of React/Tauri to "future web companion"). It **demoted CLI subprocess piggyback to a fallback power-mode, not the primary API integration** — this is a meaningful shift and is adopted in the updated Phase D below. Qwen 3.5 4B is confirmed as the 16GB ceiling, with an explicit **3-loop max** for bounded execution (tighter than Claude paper's 8-hop budget).

**What is right:**
- Qwen 3.5 4B at 4-bit MLX is the correct local baseline — the numbers check out against Qwen's own release notes.
- BoltFFI's zero-copy wins are real, especially for 100–300 tok/s streaming.
- Dynamic Few-Shot Prompting stored in GRDB (2–3 past successful tool calls injected into prompt at runtime) is a technique the other three papers missed. This alone can raise small-model tool accuracy by double digits.
- MCP with OAuth 2.0 for enterprise is correct.
- `--network=none` + `readonly_rootfs` is the right Docker posture.

**What is wrong:**
- **Docker as mandatory is wrong for a macOS PKM app.** Docker Desktop is a 600MB+ dependency, eats 1–2GB of RAM idle, and is a non-starter for "plug and play." On macOS the correct sandbox substrate for subprocess tools is the user's shell + an allowlisted command gate, not full container isolation. Docker should be **optional**, available behind a settings toggle for users who want it.
- **React/Tailwind/Shadcn is the wrong frontend for this app.** Epistemos is already 137K lines of SwiftUI. A rewrite is not a minimal fix — it is a multi-month project with no user-visible value. The Gemini paper implicitly assumes Tauri as the shell; Epistemos is a native macOS app and should stay that way.
- **PTY is not required for subprocess mode.** The Claude paper is correct: `claude -p` and `codex exec` detect non-TTY and skip the interactive TUI. Pipes are sufficient. PTY only matters if you want to embed the full TUI in a terminal panel, which is not a stated requirement.

**What to take from Gemini:**
- ✅ Qwen 3.5 4B at 4-bit MLX as the local baseline.
- ✅ Dynamic Few-Shot Prompting from a GRDB-backed successful-tool-call store.
- ✅ MCP OAuth 2.0 patterns for when Epistemos-as-MCP-server is built.
- ✅ The `--network=none` + `readonly_rootfs` posture for the **optional** Docker-per-session feature (matches Phase H).
- ✅ The v2 doctrine: CLI subprocess is a power-mode fallback, **native API is primary integration.** Rationale: raw API is Anthropic/OpenAI/Google's stable public surface; `stream-json` from CLIs is undocumented and brittle to upstream changes.
- ✅ 3-loop max for bounded local execution (tighter, safer, explicit).
- ❌ Reject: BoltFFI-mandatory (defer behind benchmarks), Docker-mandatory (it's opt-in), PTY-mandatory (not needed for `-p`/`exec`), React frontend.

### 2.2 Perplexity's path — "DevContainer + Claude Agent SDK + json-render"

**What it proposed:** DevContainer spec with `postCreateCommand` auto-provisioning, Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`) as the primary integration, Tauri sidecar for CLI piggyback, Vercel `json-render` (React + Shadcn catalog) for generative UI, Qwen-Agent MCP integration.

**What is right:**
- The root-cause diagnosis is correct: **the app feels dead because it waits for the final answer instead of streaming every NDJSON event.** Stream `--output-format stream-json --verbose` and parse every line. This is the single most impactful fix in the whole council.
- Persistent subprocess pre-warming (keep `claude` alive between turns using `--input-format stream-json` + persistent stdin) eliminates the ~12-second Node cold start. This is a production-grade insight.
- The `CLAUDECODE=1` env var filter when spawning Claude SDK inside a Claude Code session — a real bug with a documented workaround.
- `@autoview` as a code-generator for the **initial implementation** of schema-bound components is clever: use it once to generate the SwiftUI boilerplate, then polish and lock in.

**What is wrong:**
- The **Claude Agent SDK is TypeScript/Python only** — there is no first-party Swift or Rust SDK. The Rust `claude-agent-sdk` crate wraps the CLI (Path A), and `claude-agent` is pure API (Path B). Neither is the TypeScript SDK. Perplexity paper treats them as interchangeable; they're not.
- **Vercel `json-render` is React.** For a SwiftUI app, the right target is A2UI v0.9's SwiftUI renderer (per Claude paper, planned by Google) or a hand-written SwiftUI component palette that matches A2UI's JSON envelope. `json-render` is architecturally identical but wrong framework.
- **DevContainer as the default onboarding is wrong for a shipped macOS app.** DevContainer assumes VS Code or a compatible host, assumes Docker, and is a developer-first workflow. End users don't open DevContainers.

**What to take from Perplexity:**
- ✅ The NDJSON event pipeline architecture — every line becomes a typed `AgentEvent`, Swift renders each variant immediately.
- ✅ Persistent subprocess pre-warming at app launch.
- ✅ The `CLAUDECODE=1` filter gotcha.
- ✅ `@autoview` for bootstrapping the SwiftUI component palette code.
- ✅ Runtime detection at app launch (`which claude` + known paths).
- ❌ Reject: Claude Agent SDK as primary (you are on Swift/Rust), json-render / React (you are on SwiftUI), DevContainer-default.

### 2.3 Claude's path — "Four-path matrix + schema-first + Developer ID"

**What it proposed:** Four integration paths ranked (Subprocess CLI, Official SDK/API, MCP dual-role, Hybrid adaptive), schema-driven SwiftUI generative UI (A2UI v0.9 compatible), Qwen3-4B + Qwen3.6-35B-A3B as planner/executor pair, Rig (`rig-core`) + `claude-agent` + `rmcp` crates, Developer ID non-sandboxed shipping, comprehensive settings toggle design.

**What is right:**
- The four-path matrix is the correct mental model. Every other paper reduces to "pick one or two" — Claude paper's matrix says "ship all four behind a single toggle."
- The sandbox doctrine is the only correct one in the council. Already adopted above.
- Schema-driven UI primary, MCP Apps iframe as the constrained escape hatch, SwiftUI codegen explicitly **off the table** for distribution reasons — the decision tree is exactly right.
- The component palette (~25 SwiftUI components matching A2UI's flat node structure) is the right shape.
- The settings toggle UX (Local / Auto / Manual with per-task overrides) is implementation-ready.
- The `rig-core` + `claude-agent` + `rmcp` crate selection is pragmatic and correct for Rust.
- The file layout for `epistemos-core` is usable as-is.

**What is wrong (or debatable):**
- **Qwen3.6-35B-A3B (262K native context) may be too memory-hungry for a 16GB M2 Pro baseline.** Claude paper caveats this (`~8-15 tok/s on 32GB`), but for a 16GB baseline user you cannot realistically load a 35B-class model even with MoE 3B-active. Memory states `4-bit 7-8B is the sweet spot` — the planner/executor split should be Qwen3-4B as executor and Qwen3-8B or Gemma 3n E4B as planner, not Qwen3.6-35B-A3B.
- **UniFFI 0.28 async callbacks are fine for non-streaming, but the Perplexity paper's point about high-frequency token streaming stands.** The right answer is UniFFI everywhere except the hot agent-event stream, which coalesces to frame-aligned 16ms batches and can later migrate to BoltFFI if benchmarks justify.

**What to take from Claude:**
- ✅ Four-path matrix verbatim as the runtime architecture.
- ✅ Schema-first UI strategy with MCP Apps iframe as the bounded escape hatch.
- ✅ The full settings toggle design (Local / Auto / Manual).
- ✅ `rig-core` + `claude-agent` + `rmcp` crate selection for Rust additions.
- ✅ The Rust `epistemos-core` file layout (append to existing crate, don't recreate).
- ✅ Developer ID + Hardened Runtime + no-sandbox shipping posture.
- 🟡 Modify: Use Qwen3-8B or Gemma 3n E4B as planner (not 35B-A3B) to respect the 16GB baseline.

### 2.4 GPT's path — "Host runtime / Workspace OS"

**What it proposed:** Epistemos as the host runtime (owns sessions, approvals, vaults, UI, MCP), providers as interchangeable runtimes, Docker as substrate not brain, project manifest compiler (single config → CLAUDE.md / .codex / .gemini), three-tier local-model strategy with cloud escalation, schema-first UI with DSL-to-components as advanced tier.

**What is right:**
- **The mental model is the single most important contribution of the council.** "Epistemos owns the workspace; providers plug into it; MCP is the universal tool cable." Every implementation decision flows from this. The other three papers agree but don't state it as the center of gravity.
- **The project manifest compiler is a killer feature none of the other papers fully developed.** One canonical `epistemos.project.json` → materializes `CLAUDE.md`, `.claude/settings.json`, `.codex/config.toml`, `.gemini/settings.json`, `mcp.json`, vault metadata. This is what makes "new session" genuinely plug-and-play.
- MCP dual-role (Epistemos as both client and server) is correct.
- Three-tier Qwen strategy matches Claude paper and both are right.

**What is wrong:**
- Light on implementation specifics. The prompt intentionally asked for "opinionated architecture" without file layouts or crate selections. Use it as doctrine, not as code.
- "Bounded local agent tier" is slightly under-specified; Claude paper fills this in.

**What to take from GPT:**
- ✅ The host-runtime mental model as doctrine.
- ✅ The project manifest compiler as a first-class subsystem.
- ✅ MCP dual-role (server + client).
- ✅ "Native integrations first → installed CLI second → desktop piggybacking last" priority order.

### 2.5 The disagreement resolution matrix

| Topic | Verdict | Source |
|---|---|---|
| **Ship on MAS?** | No, Developer ID primary, MAS Lite secondary | Claude paper |
| **PTY for subprocess?** | Not needed for `-p`/`exec`; pipes sufficient | Claude paper |
| **Primary frontend** | SwiftUI (existing) — do not rewrite to React | Codebase reality |
| **FFI** | UniFFI for control, coalesced UniFFI for streaming; BoltFFI deferred behind benchmarks | PLAN_V2 §22 + Claude paper |
| **Local baseline model** | Qwen 3.5 4B 4-bit MLX | All four papers agree |
| **Local planner (Tier 2)** | Qwen3-8B or Gemma 3n E4B — NOT 35B-A3B | Memory constraint |
| **Event pipeline** | NDJSON → typed AgentEvent → UniFFI callback → SwiftUI | Perplexity + Claude papers |
| **Generative UI primary** | Schema-driven SwiftUI palette (A2UI-shaped JSON) | Claude + GPT papers |
| **Generative UI escape** | MCP Apps iframe in locked WKWebView — never raw SwiftUI codegen | Claude paper |
| **Docker** | Optional, behind toggle, only for the Bash/shell tool path — NOT mandatory | Consensus override |
| **Project manifest compiler** | Build it — it's the plug-and-play differentiator | GPT paper |
| **MCP dual role** | Build the server surface (greenfield) | GPT + Claude papers |
| **Dynamic few-shot prompting** | Build it as a first-class subsystem for Qwen | Gemini paper dissent |

---

## 3. What is Already Built — Grounding the Plan

The live-code audit (summarized in `EpistemosTests/` and `agent_core/` source) confirms:

| Subsystem | Status | Notes |
|---|---|---|
| **UniFFI 0.28 boundary** | ✅ Done | `agent_core` cdylib+staticlib; bridging verified live |
| **Provider adapters** | ✅ Done | Claude / OpenAI / Gemini / Perplexity all stream via direct API in `agent_core/src/providers/` |
| **Claude CLI + Codex CLI subprocess** | ✅ Done | `tools/cli_passthrough.rs` with candidate PATH resolution, 5m default timeout, streaming stdout |
| **MLX local inference (Qwen 3.5 / 3.6)** | ✅ Done | `MLXInferenceService.swift` with `enable_thinking` Jinja template |
| **MCP client (stdio + HTTP/SSE)** | ✅ Done | `agent_core/src/mcp/` + `omega-mcp` |
| **MCP server (app exposes its tools)** | 🔴 Greenfield | `ChunkedMCPFraming.swift` is the only trace |
| **Agent loop in Rust** | 🟡 Scaffold | `agent_loop.rs` exists but Swift `OrchestratorState` still owns orchestration per `AGENT_RUNTIME_ARCHITECTURE.md` |
| **Settings — agent control** | ✅ Done | `AgentControlSettingsView.swift`, but missing 3-mode Intelligence toggle |
| **Docker / PTY** | 🔴 Greenfield | Zero integration |
| **Schema-driven UI palette** | 🔴 Greenfield | Zero matches for Widget/ComponentRegistry/A2UI |
| **Project manifest compiler** | 🔴 Greenfield | CLAUDE.md is hand-written per CLAUDE.md in repo root |
| **Event streaming pipeline** | 🟡 Partial | `StreamingDelegate.swift` exists but the UI is NOT rendering ToolCallCards / ThinkingTrace / bash live per user feedback |
| **Few-shot prompt store** | 🔴 Greenfield | No GRDB table for successful tool calls |

**This changes the plan materially:** the three big greenfield pieces (schema-driven UI, MCP server, project manifest compiler) are the high-leverage work. Everything else is integration of what exists.

---

## 4. The Synthesized Architecture

### 4.1 One-page doctrine

```
┌──────────────────────────────────────────────────────────┐
│  SwiftUI (Epistemos — existing 137K lines)               │
│  ├─ Chat / Vault / Graph / Code / Notes                  │
│  └─ GenerativeSurface renderer  ← A2UI-shaped JSON       │
│                                                           │
│  MLX-Swift (Qwen 3.5 4B + Qwen 3-8B or Gemma 3n E4B)     │
│  └─ @Generable on macOS 26+ for schema-constrained gen   │
├──────────────────────────────────────────────────────────┤
│                UniFFI 0.28 (async + callbacks)           │
│  Streaming events coalesced to 16ms frames; BoltFFI      │
│  deferred behind benchmark proof                          │
├──────────────────────────────────────────────────────────┤
│  Rust — agent_core + epistemos-core                      │
│  ├─ AgentRuntime (ReAct loop, budget, termination)       │
│  ├─ Router  (per-task policy → provider matrix)          │
│  ├─ Providers                                             │
│  │   ├─ subprocess/ (claude CLI, codex CLI, gemini CLI)  │
│  │   ├─ api/        (existing claude/openai/gemini/perp) │
│  │   ├─ local/      (MLX via LocalLLMProvider callback)  │
│  │   └─ mcp/        (rmcp client + server)               │
│  ├─ Tools (Read/Edit/Write/Bash/Glob/Grep/WebFetch)      │
│  ├─ ProjectManifest compiler (NEW)                       │
│  ├─ FewShotStore (NEW — GRDB table of successful calls)  │
│  ├─ Persistence (GRDB interop via SQLite)                │
│  └─ Telemetry (OpenTelemetry → local sqlite)             │
└──────────────────────────────────────────────────────────┘
```

### 4.2 The settings toggle (Claude paper's design, copied verbatim)

```
Settings → Intelligence
───────────────────────────────────────────
 Mode:    ( ) Local only
          (•) Auto (recommended)
          ( ) Manual

 Detected providers:
  ✓ Claude Code 2.3.1 (/opt/homebrew/bin/claude)
    Using your Claude Pro subscription
  ✓ Codex 0.91 (/usr/local/bin/codex)
    Signed in as jojo@…
  ✓ Gemini CLI 3.2 (OAuth)
  ✓ Anthropic API key (env)
  ✓ Qwen3-4B MLX 4-bit (local)
  ✓ Qwen3-8B MLX 4-bit (local, planner)

 Budget cap   $ [   5.00   ] / day
 Escalate on  ☑ low confidence  ☑ Chat step ≥ 3  ☑ Agent step ≥ 8
              ☑ validator failure

 ▶ Advanced: per-task routing
 ▶ Advanced: MCP servers (N configured)
 ▶ Allow subprocess CLIs          [ on / off ]
 ▶ Share Epistemos as MCP server  [ on / off ]
 ▶ Enable Docker sandbox          [ on / off ]  (optional)
```

Every assistant message has a footer badge showing the chosen provider, latency, and cost. Clicking it opens the router trace. This single affordance converts "which model answered?" from guesswork into inspection — it is the most important trust primitive in the whole product.

### 4.3a Composer controls — three independent axes (Mode × Effort × Tools)

The composer has three **orthogonal** axes. Conflating them creates UX drift and user confusion ("should I use normal chat or tools chat?"). Keep them separate.

| Axis | Values | What it controls |
|---|---|---|
| **Mode** (autonomy) | `Chat` \| `Agent` | Interaction contract — bounded autonomy (conversational, inline tool use, ≤3 hops) vs extended autonomy (planner, approvals, multi-file, resume/checkpoint) |
| **Effort** (reasoning budget) | `Auto` \| `Quick` \| `Deep` | Latency vs reasoning depth. Independent of Mode. Auto biases toward Quick in Chat, Balanced-to-Deep in Agent. |
| **Tools** (capabilities) | always-on, gated by tier (A.8) | What the runtime may touch. Permission tier decides; Mode sets the hop budget. Tools are NEVER a user-visible mode. |

**Button-label change** on Mode switch: `Send` → `Run` in Agent. Words teach the product — "run" signals process, "send" signals message.

**Agent composer expansion** (inline, not popover): when Agent is selected, reveal `Scope` chips (`This note` | `Folder` | `Workspace`) and `Access` dropdown (`Ask first` | `Can edit` | `Shell ask`). After Run is pressed, the full run UI (planner, approvals, terminal, checkpoint) appears.

**Promotion from Chat → Agent** is offered (not forced) when any of these fire: ≥3 tool hops needed, multi-file edit requested, shell/package-manager command detected, validator failure with retry, or the request lexically matches `fix|investigate|build|refactor|install|migrate`.

**Legacy "tools chat" is NOT a third axis.** It's the same backend runtime as normal chat, historically surfaced as a separate top-level tab. Phase I below collapses this split: the runtime stays, the user-facing split goes away, and the old tools chat becomes a hidden `Workbench` for debug/eval only.

### 4.3 The default routing policy

Taken from Claude paper §1.4.2 with Qwen memory-constraint adjustment:

| Task kind | Mode-profile ceiling | Preferred | Fallbacks |
|---|---|---|---|
| Chitchat / quick note | Chat, ≤3 hops | Qwen3-4B local | Haiku API → Gemini Flash API |
| Note write / rewrite | Chat, ≤3 hops | Qwen3-4B local | Sonnet API |
| Vault search / graph walk | Chat, ≤3 hops | Qwen3-4B + local tools | (always local) |
| Single-file edit | Chat, ≤3 hops (validator-gated) | Claude Code CLI (if installed) | Anthropic API (claude-agent) → Codex API |
| Multi-step agent | Agent, ≤10 hops | Claude Code CLI | Anthropic API w/ checkpointing → Codex CLI `--resume` |
| Long-horizon agent | Agent, checkpoint-resumable, no hard ceiling | Anthropic API w/ checkpointing | Codex CLI `--resume` |
| Code refactor (multi-file) | Agent, ≤10 hops, test-gated | Claude Code CLI | Anthropic API → Codex API |
| "This is too complex" escalation | Agent, user-approved | Claude Opus class | GPT-5.4 → Gemini 3 Pro |

**Ceiling legend:** Chat-profile tasks enforce the 3-hop limit (Gemini v2 ceiling, per §4.3a + Phase D.2). Agent-profile tasks run up to 10 hops by default; beyond 10, Long-horizon mode takes over with checkpoint/resume. Hops per profile are user-editable in Settings → Intelligence → Advanced.

### 4.4 Unified knowledge graph — chats, sessions, and memory are first-class nodes

**The vision:** every interaction surface becomes a node in a single knowledge graph. When you attach a note to a chat, when you chat on a note, when you chat on a group, when an agent runs a session — all of it lands in the graph alongside the notes, entities, and model vaults. The graph becomes the unified index over the entire app.

**Node types (additive; existing schema unchanged):**

| Node | Fields | Why it's in the graph |
|---|---|---|
| `Chat` | id, kind (`regular` \| `note_attached` \| `group` \| `agent_session`), model_id, vault_id, created_at | Every chat is addressable and traversable |
| `Message` | id, chat_id, role, content_ref, parent_id, created_at | Message-level provenance for quoting/backlinks |
| `Session` | id, parent_chat_id, task_kind, provider, total_cost_usd, stop_reason, started_at, ended_at | Agent-run observability (also in GRDB per A.9) |
| `ToolCall` | id, session_id, tool_name, input_ref, output_ref, is_error | Links sessions to the notes/files they touched |
| `Attachment` | id, chat_id, target_id (note_id, file_path, url) | What a chat was grounded in |
| `ModelVault` | id, model_id, kind (`claude` \| `codex` \| `gemini` \| `qwen3_4b` \| `qwen3_8b` \| ...) | Each model has its own vault space |
| `MemoryEntry` | id, model_id, format (`claude_md` \| `agents_md` \| `gemini_md` \| `qwen_yaml` \| `shared`), body_ref, provenance_refs | Per-model native memory units |

**Edges (additive):**

```
Chat          -[IN_VAULT]->          ModelVault
Chat          -[HAS_MESSAGE]->       Message
Chat          -[ATTACHES]->          Note | File | URL
Chat          -[PROMOTED_TO]->       Session           (Chat→Agent promotion path)
Session       -[CHILD_OF]->          Chat
Session       -[USES_TOOL]->         ToolCall
ToolCall      -[AFFECTS]->           Note | File       (what the tool touched)
Message       -[MENTIONS]->          Entity
Message       -[QUOTES]->            Note | Message    (backlinks across chats)
GroupChat     -[INCLUDES_NOTE]->     Note[]            (notes attached to a group chat)
ModelVault    -[OWNS_MEMORY]->       MemoryEntry[]
ModelVault    -[OWNS_CHATS]->        Chat[]
MemoryEntry   -[GROUNDED_IN]->       Note | ToolCall   (every memory has provenance)
MemoryEntry   -[DERIVED_FROM]->      MemoryEntry[]     (shared→per-model consolidation tree)
```

**Regression-safety rules (non-negotiable):**
1. **Additive only.** No existing node or edge type is renamed or removed.
2. **Existing queries still return existing shapes.** New node types are not visible unless callers opt into them via a query flag.
3. **Write paths unchanged.** Chat creation still uses `SDChat.save()`; the graph index is built *from* the existing canonical source in a separate write (observer pattern), not as a replacement.
4. **Idempotent indexing.** Re-indexing a chat produces identical graph state. Safe to re-run.
5. **Backfill is opt-in and rate-limited.** Historical chats are indexed on a background queue at ≤50 chats/sec to avoid disrupting live interactions.
6. **Rollback path exists.** A single feature flag `EPISTEMOS_GRAPH_INDEX_CHATS=0` disables new indexing and hides new node types from queries. Old app behavior restored.

**The payoff:** asking "show me every conversation that touched this note" becomes a single graph query. Asking "what has Claude learned about this project?" walks `ModelVault(claude) → MemoryEntry[] → GROUNDED_IN → Note`. Asking "which sessions produced regressions?" walks `Session → ToolCall → AFFECTS → Note` filtered by subsequent Note-edit history. The graph becomes the unified substrate for meaning, memory, and action.

### 4.5 Per-model native memory — engineered per model's real conventions

Each model has its own memory folder at `~/.epistemos/memory/<model>/` in a format *native to how that model consumes memory*. The shared canonical truth lives in `~/.epistemos/memory/shared/`; a compiler materializes per-model views on session start.

**Shared layer (canonical source of truth):**
```
~/.epistemos/memory/shared/
├── user-profile.md              # always-relevant facts about the user
├── vault-conventions.md         # note format, link grammar, tagging
├── facts.yaml                   # structured facts with provenance IDs
└── successful-interactions.jsonl  # few-shot exemplars (cross-model)
```

**Per-model views (each engineered to its native conventions):**

| Model | Primary entry file | Rules dir | Skills dir | Auto-memory / working memory | Structured facts |
|---|---|---|---|---|---|
| **Claude** | `~/.epistemos/memory/claude/CLAUDE.md` | `claude/rules/*.md` (YAML-frontmatter path-scoped) | `claude/skills/*/SKILL.md` | `claude/plans/*.md` (Claude Code v2.1.59+ `autoMemoryDirectory`) | `claude/facts/*.json` (Anthropic Memory Tool `memory_20250818` shape) |
| **Codex** | `~/.epistemos/memory/codex/AGENTS.md` (vendor-neutral, also read by Cursor/Aider) | `codex/rules/*.md` | `codex/skills/*/SKILL.md` (cross-CLI format per CLI research §1.3) | `codex/sessions/*.jsonl` (rollout history; Codex's native pattern) | — (facts folded into AGENTS.md) |
| **Gemini** | `~/.epistemos/memory/gemini/GEMINI.md` | `gemini/rules/*.md` | `gemini/skills/*/SKILL.md` | `gemini/memory/*.md` (Gemini's `memoryTool` extension format) | — (facts folded into GEMINI.md) |
| **Qwen3 (local)** | `~/.epistemos/memory/qwen/CORE.md` (system prompt + identity) | `qwen/rules/*.md` | `qwen/skills/*/SKILL.md` | `qwen/few-shot/*.jsonl` (Gemini-paper dynamic few-shot store) | `qwen/facts.yaml` + `qwen/embeddings.sqlite` (MLX-backed semantic index) |
| **Apple FoundationModels** (macOS 26+) | `~/.epistemos/memory/foundation/CORE.md` | `foundation/rules/*.md` | — | — (stateless, composed from shared + relevant rules) | Embedded via `@Guide` in structured prompts |

**Native design notes (why each format matches its model):**

- **Claude CLAUDE.md + rules + skills + plans:** mirrors Claude Code's five-level scope hierarchy (managed→CLI→local→project→user). Recursive `@path` imports up to 5 levels. Path-scoped rules reduce context cost. `plans/` captures Claude's own auto-memory writes (opt-in per `autoMemoryEnabled`). See CLI research §1.2–§1.3.
- **Codex AGENTS.md:** vendor-neutral, widely read by Codex/Cursor/Aider. Session rollouts in `sessions/` mirror Codex's native `~/.codex/sessions/*.jsonl` pattern and make `codex exec --resume` work against Epistemos-tracked runs.
- **Gemini GEMINI.md + memory/:** GEMINI.md is Gemini's native `contextFileName`. The `memory/` folder matches Gemini's `memoryTool` extension format (a user says "remember X", it lands as a markdown file with structured front matter). See CLI research §3.3.
- **Qwen CORE.md + few-shot + facts + embeddings:** Qwen has no native memory system, so Epistemos provides one. `CORE.md` is the identity + system prompt. `few-shot/*.jsonl` stores successful tool-call exemplars (Gemini paper's Dynamic Few-Shot Prompting dissent — this is where 40% of small-model tool failures recover). `facts.yaml` is structured. `embeddings.sqlite` is a MLX-backed semantic store for retrieval.

**Cross-cutting rules (all model folders):**
- Every memory entry has a `provenance` field pointing to source `Note | Chat | Session | ToolCall` IDs in the knowledge graph (per §4.4).
- Compiler writes atomically (`.tmp` → `fsync` → `rename`) with `<!-- BEGIN EPISTEMOS AUTOGEN -->` fences protecting user hand-edits.
- Shared memory entries propagate to per-model views on save; per-model edits by the model itself are captured under that model's folder only (never leak cross-model without a user-visible consolidation step).
- Deletion is first-class: remove an entry from shared memory → all model views regenerate without it on next session start.

### 4.6 Reference code: AgentEvent enum + AgentEventSink callback (Phase A primitive)

This is the canonical event primitive Phase A depends on. Inlined so future sessions don't need to rediscover it. Every NDJSON line from any provider CLI/API is normalized into one of these variants; Swift implements `AgentEventSink` and renders each variant immediately.

```rust
// agent_core/src/runtime/events.rs
use uniffi::export;

/// The canonical event primitive. Every NDJSON line from Claude Code,
/// Codex, Gemini, or the Anthropic/OpenAI/Google APIs gets normalized
/// into exactly one variant of this enum before crossing UniFFI.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum AgentEvent {
    /// Incremental text delta from the model. Coalesced to 16ms batches
    /// in Rust before crossing UniFFI (never per-token to Swift).
    TextDelta { session_id: String, text: String },

    /// Incremental thinking/reasoning delta (Claude extended thinking,
    /// Qwen /think, etc). Same coalescing rules as TextDelta.
    ThinkingDelta { session_id: String, text: String },

    /// Tool-use invocation requested by the model. UI renders this as
    /// an animated ToolCallCard with a spinner.
    ToolCallRequested {
        id: String,
        name: String,
        input_json: String,  // canonical JSON per tool schema
    },

    /// Tool-use result. UI resolves the spinning card to ✅ or ❌
    /// with a collapsible output preview.
    ToolCallResult {
        id: String,
        output: String,
        is_error: bool,
    },

    /// Bash/shell output line. UI streams into a TerminalOutputCard.
    BashLine { session_id: String, line: String },

    /// Router chose a provider. UI shows a RouterDecisionBadge pill.
    RouterDecision {
        session_id: String,
        provider: String,        // e.g. "claude_code_cli"
        reason: String,          // e.g. "task=MultiStepAgent, budget=60%"
    },

    /// Persist-this-state event. Fires every 30s or on every
    /// RouterDecision. Consumer writes to GRDB.
    SessionCheckpoint {
        session_id: String,
        total_cost_usd: f64,
    },

    /// Provider is rate-limited and will retry after N seconds.
    RateLimitRetry {
        session_id: String,
        wait_seconds: u32,
    },

    /// Turn complete. stop_reason is one of: end_turn, max_tokens,
    /// tool_use, stop_sequence, cancelled, error.
    SessionComplete {
        session_id: String,
        stop_reason: String,
        total_cost_usd: f64,
        cancelled: bool,
    },

    /// Unrecoverable error. NEVER coalesced, NEVER dropped.
    Error {
        session_id: String,
        code: String,
        message: String,
    },
}

/// Swift implements this trait. Rust calls it on the main actor via
/// DispatchQueue.main.async (NEVER .sync — deadlock risk).
#[uniffi::export(callback_interface)]
pub trait AgentEventSink: Send + Sync {
    fn on_event(&self, event: AgentEvent);
}
```

**Critical rules (CLAUDE.md non-negotiable alignment):**
- `Error`, `ToolCallRequested` (approval gate), and `SessionComplete` are **never coalesced** and **never dropped**, even during cancellation. Only `TextDelta` and `ThinkingDelta` coalesce.
- Swift's `AgentEventSink` implementation dispatches via `DispatchQueue.main.async` (per CLAUDE.md line 28 — `.sync` causes deadlock).
- When `stop_reason == "tool_use"`, the upstream provider call must preserve the full content array including thinking blocks + signatures before sending tool-use result back (CLAUDE.md line 17). `ToolCallResult` must carry enough info for the provider call to round-trip.

**Swift side minimal shape:**

```swift
// Epistemos/Bridge/AgentEventRouter.swift
import Foundation

@MainActor
final class AgentEventRouter: AgentEventSink {
    weak var chatCoordinator: ChatCoordinator?

    nonisolated func onEvent(event: AgentEvent) {
        // UniFFI delivers off-main — hop to main BEFORE touching @Observable state.
        DispatchQueue.main.async { [weak self] in
            self?.handleOnMain(event)
        }
    }

    @MainActor
    private func handleOnMain(_ event: AgentEvent) {
        switch event {
        case .textDelta(let sessionId, let text):
            chatCoordinator?.appendAssistantText(sessionId: sessionId, text: text)
        case .thinkingDelta(let sessionId, let text):
            chatCoordinator?.appendThinking(sessionId: sessionId, text: text)
        case .toolCallRequested(let id, let name, let inputJson):
            chatCoordinator?.insertToolCallCard(id: id, name: name, inputJson: inputJson)
        case .toolCallResult(let id, let output, let isError):
            chatCoordinator?.resolveToolCallCard(id: id, output: output, isError: isError)
        case .bashLine(let sessionId, let line):
            chatCoordinator?.appendTerminalLine(sessionId: sessionId, line: line)
        case .routerDecision(let sessionId, let provider, let reason):
            chatCoordinator?.setProviderBadge(sessionId: sessionId, provider: provider, reason: reason)
        case .sessionCheckpoint(let sessionId, let totalCostUsd):
            chatCoordinator?.persistCheckpoint(sessionId: sessionId, costUsd: totalCostUsd)
        case .rateLimitRetry(let sessionId, let waitSeconds):
            chatCoordinator?.showRateLimitNotice(sessionId: sessionId, wait: waitSeconds)
        case .sessionComplete(let sessionId, let stopReason, let totalCostUsd, let cancelled):
            chatCoordinator?.finalizeSession(sessionId: sessionId, stopReason: stopReason,
                                              costUsd: totalCostUsd, cancelled: cancelled)
        case .error(let sessionId, let code, let message):
            chatCoordinator?.surfaceError(sessionId: sessionId, code: code, message: message)
        }
    }
}
```

This is the Phase A target. If the current `StreamingDelegate.swift` doesn't match this shape, Phase A's first commit reshapes it.

---

## 5. Phased Implementation Plan

Each phase is scoped to a single multi-day session. Every phase has explicit **verification**, explicit **NOT-in-scope**, and is **committable in one PR**. The phases are ordered so each one makes the next easier.

### Phase 0 — Verify live state and Session 0 prep (1 day)

**Why first:** Memory says `feedback_minimal_fixes` — release-oriented fixes, not refactors. The audit above flagged "Omega layer still owns orchestration per docs" but the audit is based on docs. Confirm against live code before the plan commits.

**Deliverable:**
- Read `Epistemos/State/OrchestratorState.swift` + `Epistemos/Services/OmegaPlanningService.swift` and reconcile with `docs/AGENT_RUNTIME_ARCHITECTURE.md`.
- Reconcile `CODE_EDITOR_FEATURE_AUDIT.md` drift (called out in PLAN_V2 §23.1) if not already done.
- Log: the specific Swift→Rust orchestration handoffs that still go through Swift today.

**NOT in scope:** any code changes.

### Phase A — Event streaming pipeline completion (2–4 days, HIGHEST LEVERAGE)

**Why this first (after Phase 0):** The Perplexity paper's root-cause diagnosis is correct. The single biggest UX improvement comes from rendering every NDJSON event as it arrives. `StreamingDelegate.swift` exists but based on your feedback ("I'm eager to brainstorm ideas"), UI-side rendering of tool-call cards and thinking traces is not complete. Fix this before anything else — every subsequent feature inherits "feels alive" automatically.

**Deliverable:**
1. **Rust:** audit `agent_core/src/agent_loop.rs` and `providers/claude.rs` to confirm every NDJSON variant (text_delta, thinking_delta, tool_use, tool_result, bash_output, session_checkpoint, rate_limit_retry, router_decision) produces a distinct typed event.
2. **Rust:** coalesce token-level events to 16ms frame-aligned batches (per PLAN_V2 §24.2). Never coalesce errors/approvals/completion.
3. **Swift:** add the component set that renders each variant:
   - `ToolCallCard` (animated with spinner, resolves to ✅/❌)
   - `ThinkingTraceView` (collapsible, live-updating)
   - `TerminalOutputCard` (ANSI-aware, streams lines)
   - `RouterDecisionBadge` (inline pill)
4. **Swift:** wire these into the chat view so they render as `AgentEvent` variants arrive via the `UniFFI` callback interface `AgentEventSink`.

**Verification:**
- Send a Claude Agent message that uses 2+ tools → every tool-call shows a card that appears spinning and resolves.
- Send a Qwen message with thinking enabled → thinking trace streams live into collapsed panel.
- Benchmarks: <5% main-thread utilization during streaming (PLAN_V2 §24.5 target).

**NOT in scope:** BoltFFI migration (deferred per PLAN_V2 §22.7), generative UI palette, new providers.

### Phase B — Settings: 3-mode Intelligence toggle (1 day)

**Deliverable:** extend `AgentControlSettingsView.swift` with the exact Claude-paper Settings pane (section 4.2 above).

**Verification:**
- Mode toggles persist across app restarts.
- Mode change triggers router policy reload without restart.
- `Local only` disables all network provider calls (verified by network proxy test).

**NOT in scope:** implementing the providers the toggle references — those exist already.

### Phase C — Provider discovery + 24h cache (1 day)

**Deliverable:** `epistemos-core/src/discovery.rs` that:
- Probes `claude`, `codex`, `gemini`, `mcp` via `which` + known paths (`/opt/homebrew/bin`, `~/.npm-global/bin`, `~/.bun/bin`, `~/.volta/bin`, `~/.local/bin`, `~/.nvm/versions/node/*/bin`).
- Probes env vars: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, plus macOS Keychain entries.
- Probes MLX model cache at `~/.cache/epistemos/mlx/`.
- Emits `ProviderMatrix` struct via UniFFI.
- Caches in GRDB with 24h TTL; invalidates on launch if binary `stat mtime` changed.

**Verification:** Settings pane (Phase B) shows real detected providers with actual paths.

### Phase D — Qwen three-tier agentic loop hardening (3–5 days)

**Deliverable:**
1. **Tier 1 — Native tool calling:** existing path; add structured output via Apple `@Generable` on macOS 26+ or two-step re-prompt validation on older.
2. **Tier 2 — Structured ReAct in Rust:** implement the loop template below in `agent_core/src/agent_loop.rs` (if not already). Validator after each tool call. Tool allowlist enforcement. **Max 3 hops** per Gemini v2's tighter ceiling — reduces the risk of Qwen drifting on a 5-hop chain that could have escalated at hop 3.

   **Loop template (inlined from Claude paper §2.2, adapted for Gemini v2 3-hop ceiling):**

   ```rust
   // agent_core/src/agent_loop.rs — bounded ReAct loop, stateless per turn
   pub async fn run_react_turn(
       ctx: &RuntimeCtx,
       task: &Task,
       policy: &Policy,
       sink: &dyn AgentEventSink,
   ) -> Result<TurnOutcome, RuntimeError> {
       let mut state = AgentState::new(task, AgentBudget {
           max_steps: 3,                    // Gemini v2 ceiling for Chat profile
           max_wall_ms: 60_000,
           max_spent_usd: policy.turn_cap_usd(),
       });
       let few_shots = ctx.few_shot_store
           .retrieve_relevant(&task.prompt, top_k = 3).await?;

       loop {
           // Hop budget check — escalate BEFORE taking another step.
           if state.step_count >= state.budget.max_steps {
               return Ok(TurnOutcome::Escalate(EscalationReason::HopsExceeded));
           }
           if state.spent_usd >= state.budget.max_spent_usd {
               return Ok(TurnOutcome::Escalate(EscalationReason::BudgetExceeded));
           }

           // 1. One LLM call. Prompt = system + few-shots + state.render().
           let step = ctx.model
               .step(&state.render_prompt(&few_shots))
               .await
               .map_err(RuntimeError::Model)?;
           state.record_thought(step.thought.clone());

           // 2. Emit thinking delta immediately (coalesced in sink).
           sink.on_event(AgentEvent::ThinkingDelta {
               session_id: task.session_id.clone(),
               text: step.thought.clone(),
           });

           // 3. Parse action. If Finish, return.
           match step.action {
               Action::Finish(answer) => return Ok(TurnOutcome::Done(answer)),
               Action::Tool { name, input } => {
                   // 4. Tool allowlist gate. Fail CLOSED on unknown tools.
                   if !policy.tool_allowed(&name) {
                       return Ok(TurnOutcome::Escalate(EscalationReason::ToolNotAllowed(name)));
                   }

                   // 5. Emit tool-call requested (may trigger UI approval for T3).
                   let tool_id = uuid();
                   sink.on_event(AgentEvent::ToolCallRequested {
                       id: tool_id.clone(),
                       name: name.clone(),
                       input_json: serde_json::to_string(&input)?,
                   });

                   // 6. Execute inside sandbox. PermissionManager gates T2/T3.
                   let observation = ctx.tools
                       .execute(&name, &input, &policy.sandbox)
                       .await?;

                   // 7. Validator pass — re-read state, diff expected vs actual.
                   let validation = ctx.validators
                       .validate(&name, &input, &observation).await;

                   sink.on_event(AgentEvent::ToolCallResult {
                       id: tool_id,
                       output: observation.render_summary(),
                       is_error: observation.is_error() || validation.is_err(),
                   });

                   // 8. Validator disagreement = escalate signal.
                   if validation.is_err() {
                       return Ok(TurnOutcome::Escalate(EscalationReason::ValidatorFailed));
                   }

                   // 9. Record observation, loop.
                   state.record_observation(observation);
                   state.step_count += 1;
                   state.spent_usd += step.cost_usd;
               }
           }
       }
   }
   ```

   Key patterns (do not deviate):
   - **Fail-closed on unknown tools** — never "best-effort" invoke a tool not in the allowlist.
   - **Validator runs after EVERY tool call** — re-read the file, diff against expected; on mismatch, escalate rather than retry.
   - **Budget checked BEFORE the step**, not after — prevents "one more hop" drift.
   - **Dynamic few-shot injection** — top-3 relevant past invocations from the GRDB store, prepended to the prompt.
   - **Thinking + tool-call events emit live** — UI stays alive even if the final answer takes 20 seconds.
3. **Tier 3 — Cloud escalation:** four uncertainty signals OR-ed: logprob threshold, self-consistency disagreement, validator disagreement, turn count ≥ 3 (per Gemini v2) or user-editable up to 8.
4. **Dynamic Few-Shot store (Gemini paper dissent):** new GRDB table `successful_tool_calls (prompt_embedding, tool_json, timestamp)`. At runtime, kNN retrieve top-3 relevant past invocations and inject into system prompt.
5. **Planner/executor split:** Qwen3-8B or Gemma 3n E4B as planner (first turn — emits JSON task list). Qwen3-4B as executor (subsequent turns — one task at a time). Respect 16GB memory budget — never load both simultaneously; swap via weak references to MLX context.

**Verification:**
- 200-task internal golden set (per Claude paper §2.6) runs nightly; success rate ≥ 85% at 95% CI on Tier 1 tasks.
- Memory watermark never exceeds 11GB during agentic runs.

**NOT in scope:** LoRA fine-tuning on Claude traces (Claude paper §2.3 — that's Phase 4 research).

### Phase I — Chat/Agent mode fusion (UX migration, 7–10 days) — NEW in v1.3

**Why this exists:** The app today has two chat surfaces — "regular chat" and "tools chat." They share the agent runtime at the Rust level, but the UX split leaks implementation into the product surface. This creates duplicated context logic, duplicated approvals, and a "which chat do I use?" question users should never have to answer. The architectural call (converged across all 4 research papers + the GPT UX synthesis) is: **one runtime, two autonomy profiles, one composer.** Keep 80% of the tools-chat engine; delete 80% of the tools-chat UX distinction.

**Prerequisites:** Phase A (event streaming), Phase B (Intelligence settings), Phase D (Qwen three-tier — gives you the task classifier needed for promotion). Phase C recommended.

**Deliverable (4 sub-phases, committable independently):**

#### I.1 — Backend unification (2–3 days)

Extract from the current tools-chat code path and expose as a single `AgentRuntime` facade usable from either surface:

- Tool registry
- Approval manager (respects A.8 tier ladder)
- Task classifier + router (uses A.2 decision table)
- Provider selection + matrix
- Execution ledger (GRDB `agent_turns` + `tool_calls` + `router_decisions` — A.9)
- Tool-call card emission (shared via Phase A's `AgentEventSink`)
- Session persistence + checkpoint/resume
- Budget tracking (soft + hard caps from Intelligence settings)

**NO UI changes in this sub-phase.** The two existing surfaces keep working; they now call into the unified runtime.

Verification: both surfaces execute identical tool sequences given identical prompts; both surfaces hit the same `PermissionManager`; both surfaces write to the same `agent_turns` table.

#### I.2 — Smart Chat profile (2–3 days)

Normal chat becomes tool-enabled with a bounded Chat profile:

- Max **3 tool hops** (the Gemini-v2 / Qwen ceiling, enforced by router).
- Allowlist: `Read`, `Glob`, `Grep`, `WebSearch`, `mcp__epistemos__vault_search`, `mcp__epistemos__embed_search`, `mcp__epistemos__backlinks`, `mcp__epistemos__daily_note`, `mcp__epistemos__note_create` (T2 approval), `mcp__epistemos__note_update` (T2 approval).
- Denied in Chat: `Bash` (except the pre-approved git-diff/log/status subset), `WebFetch`, `MultiEdit`, `mcp__epistemos__note_delete`.
- Inline tool-call cards (Phase A), no full planner panel.
- On complexity spike (classifier says `MultiStepAgent`/`LongHorizonAgent` or ≥3 hops needed or validator failure): **suggest promotion** instead of looping or silently escalating.

Verification: a turn classified as `Chitchat`/`NoteWrite`/`VaultSearch`/`SingleFileEdit` stays in Chat and renders inline tool cards; a turn classified `MultiStepAgent`+ shows the promotion chip and does not auto-escalate.

#### I.3 — Agent mode first-class + promotion affordance (3–4 days)

**Composer UX** (per §4.3a mental model):
- Pill-style mode switch `[Chat|Agent]` above the text field. Always visible, not hidden in a popover.
- `[Effort: Auto ▾]` popover adjacent, accessible in both modes.
- When Agent is selected, inline run-strip reveals: `Scope: [This note] [Folder] [Workspace]` + `Access: [Ask first ▾]`.
- Send-button label changes: `Send` (Chat) → `Run` (Agent).
- **First-time-in-Agent explainer** (one-shot modal): "Agent mode can plan, edit files, and run tools with your approval." Buttons: `Got it` / `Learn more`. Never shown again unless user resets onboarding.

**Three entry paths to Agent** (all must work):
1. **Direct:** user taps `Agent` → types goal → `Run`.
2. **Promotion chip:** when Chat classifier detects an agent-shaped task (lexical or semantic match on `fix|investigate|build|refactor|install|migrate|deploy|multi-file|across`), show chip at the bottom of the current message: `"This looks like an agent task. Run with plan + approvals?"` Buttons: `Stay in Chat` / `Run as Agent`. Promotion preserves the current message and context into the new Agent run.
3. **Auto-escalation suggestion:** after ≥2 tool uses in Chat that hit validator failure, retry loops, or require shell/multi-file, surface a subtle inline suggestion (not a blocking chip): `"Switch to Agent for this kind of task?"`

**Agent run UI** (revealed only after `Run` is pressed — not before, to keep setup lightweight):
- Phase indicator: `Planning → Reading → Editing → Running → Waiting for approval → Done`
- Plan / todo list (from the planner's first-turn output)
- Approval queue (T3 tools pending user OK)
- Stop button (wires into kill-switch per A.6)
- Terminal output panel when Bash is in use
- Checkpoint/resume affordance (`agent_turns.stop_reason` + session ID for `--resume`)

**Inline-expansion default, side-panel escape hatch:** Agent mode expands the composer inline by default. User preference in Settings can switch to side-panel mode for users who prefer it. Do NOT open a full-screen modal on every Run.

Verification:
- Composer shows `[Chat|Agent]` pill always, with `[Effort]` popover always.
- Switching to Agent expands inline within 1 frame; send button re-labels to `Run`.
- Promotion chip appears within 500ms of classifier decision, not after the model finishes.
- First-time explainer fires exactly once per vault.
- ⌘. cancels an in-flight Agent run in <200ms (A.6 SLO).

#### I.4 — Workbench demotion (1–2 days)

Rename the current "Tools chat" nav entry to **`Workbench`** and move it out of the main nav:
- Accessible via `Settings → Advanced → Open Workbench`.
- Also accessible via the developer menu when `EPISTEMOS_SHOW_WORKBENCH=1` env var or `--workbench` CLI flag is set.
- Default install: Workbench is hidden from the main sidebar.

Workbench retains (these are internal/debug surfaces, not product features):
- Raw tool-call replay
- Router trace viewer with full signal breakdown (logprob, self-consistency, validator disagreement, turn count)
- Provider handshake debug panel
- Regression/eval run harness (A.10 golden set trigger)
- `.mcp.json` / `.codex/config.toml` / `.gemini/settings.json` live preview (read-only)

Verification: new user install sees only one chat surface; power user with flag set sees Workbench in an explicit "Advanced" section. No way to reach Workbench by accident.

**Phase I verification across all sub-phases (deferred until I.4 lands):**
1. Single-surface dogfooding: 10 real tasks from A.10 golden set execute correctly, choosing Chat or Agent based on classifier; 5 of them promote from Chat to Agent.
2. Approval audit: no tool executes outside the A.8 tier gates in either mode.
3. Session continuity: a Chat turn that promotes to Agent preserves the full conversation context into the agent_turns row.
4. Observability: every mode switch, every promotion offer, every accept/decline is logged in GRDB.

**NOT in scope:**
- New generative UI components (that's Phase E, which runs after I)
- New providers
- Raw SwiftUI codegen from LLM (permanently prohibited per §1.5)
- Redesigning the main chat visual; this phase is about composer-level mode switching, not a chat redesign.

---

### Phase J — Unified knowledge graph + per-model native memory (7–10 days) — NEW in v1.4

**Why this exists:** §4.4 and §4.5 describe the vision — every chat, session, tool call, and model memory is a first-class graph node; every model has a memory folder engineered to its native conventions. This is the phase that makes it real. The payoff is profound: any question that crosses chat ↔ note ↔ session ↔ model-memory becomes a single graph query instead of a cross-table join across unrelated tables.

**Prerequisites:** Phase A (event streaming — need `AgentEvent` variants to emit graph-write events), Phase D (Qwen three-tier — the Qwen memory folder depends on the few-shot store landed in D.4), Phase G (project manifest compiler — we reuse its atomic-write + fence-preservation machinery).

**Regression-safety preamble (read this first, enforce in every sub-phase):**

> Nothing in this phase may rename, remove, or change the shape of any existing node type, edge type, or persisted table. All indexing is **additive** and gated behind feature flag `EPISTEMOS_GRAPH_INDEX_CHATS` (default ON in dev, OFF in release until all sub-phases land). Existing graph queries (graph_walk, backlinks, frontlinks, embed_search, vault_search) must return byte-identical results with the flag OFF and with an unchanged input set. If any verification step shows a regression, stop and investigate — do not proceed to the next sub-phase.

**Deliverable (4 sub-phases, committable independently):**

#### J.1 — Chat/session/attachment graph indexing (2–3 days)

Extend the graph-engine schema with the additive node and edge types from §4.4. Index every new chat on creation via an observer subscribed to `SDChat.save()` — no changes to the existing save path.

Touches:
- `agent_core/src/graph/schema.rs` — add node types `Chat`, `Message`, `Session`, `ToolCall`, `Attachment`, `ModelVault` (additive variants in existing enums; do NOT change existing variants).
- `agent_core/src/graph/index.rs` — new `ChatGraphIndexer` observing `SDChat::save_did_complete` via existing notification center hook.
- NEW `agent_core/src/graph/backfill.rs` — one-shot migration that walks existing `SDChat` rows and emits indexing events; rate-limited to 50/sec.
- Swift: `Epistemos/State/ChatState.swift` — emit a `chatSaved` notification post-save (already exists per the live audit; confirm and reuse).

What this enables:
- `graph_walk(start=chat_id, depth=2)` returns the chat's messages, attachments, and derived session.
- `backlinks(note_id)` now returns chats that attached the note, in addition to notes that link it.
- Historical chats are retroactively indexed (backfill job runs on first launch after upgrade, with a progress HUD).

Verification:
1. Flag OFF: existing `graph_walk`/`backlinks`/`embed_search` calls produce byte-identical results to the pre-phase snapshot (diff-test in CI).
2. Flag ON + fresh chat: the chat appears as a `Chat` node within 100ms of save; attached notes show `ATTACHES` edges.
3. Backfill: 10,000 existing chats index in <5 minutes with <5% CPU.
4. Rollback: setting the flag OFF after backfill hides new node types from queries; re-setting ON re-exposes them without re-indexing.

NOT in scope: per-model memory folders (J.2); the graph-query UI surfacing new node types (that lands naturally when the generative UI palette in Phase E renders them).

#### J.2 — Per-model memory folder compiler (2–3 days)

Implement the `PerModelMemoryCompiler` trait in Rust that takes the canonical shared memory state + per-model `ModelVault` state and materializes each model's folder per the table in §4.5. Reuse Phase G's atomic-write + fence infrastructure.

Touches:
- NEW `epistemos-core/src/memory/mod.rs` — `PerModelMemoryCompiler` trait + `MemoryEntry` / `ModelMemoryView` types.
- NEW `epistemos-core/src/memory/claude.rs` — emits CLAUDE.md + rules + skills + plans + facts/*.json (Anthropic Memory Tool shape).
- NEW `epistemos-core/src/memory/codex.rs` — emits AGENTS.md + rules + skills + sessions/*.jsonl (Codex rollout shape).
- NEW `epistemos-core/src/memory/gemini.rs` — emits GEMINI.md + rules + skills + memory/*.md (Gemini memoryTool shape).
- NEW `epistemos-core/src/memory/qwen.rs` — emits CORE.md + few-shot + facts.yaml + embeddings.sqlite (MLX-backed index).
- NEW `epistemos-core/src/memory/foundation.rs` — emits CORE.md + rules for Apple FoundationModels (macOS 26+ only).
- NEW `epistemos-core/src/memory/shared.rs` — canonical source-of-truth layer.

Regeneration policy (mirrors Phase G §G.4 table):
- `shared/*` → regenerate only on user save (explicit).
- `<model>/*` primary entry file → session start for the model (when that model is first invoked in a session).
- `<model>/rules/*` → on manifest/shared change.
- `<model>/skills/*` → manifest change only.
- `<model>/plans/*`, `<model>/sessions/*.jsonl`, `<model>/memory/*.md`, `<model>/few-shot/*.jsonl` → append-only, written by the runtime during active sessions, never regenerated.

Verification:
1. Fresh install: `~/.epistemos/memory/` exists with all five model folders (claude/codex/gemini/qwen/foundation) and the shared/ root.
2. User edits `shared/user-profile.md` → next session start re-emits `claude/CLAUDE.md`, `codex/AGENTS.md`, `gemini/GEMINI.md`, `qwen/CORE.md` with the new content between AUTOGEN fences.
3. User edits `claude/CLAUDE.md` OUTSIDE the fences → next regeneration preserves the edit.
4. Deleting a shared fact → all per-model views regenerate without it.
5. Per-model append files (plans, sessions, memory, few-shot) are never touched by regeneration — only by live runtime writes.

NOT in scope: RAG retrieval over the memory folders (that's a natural extension via `embed_search` but not part of this sub-phase).

#### J.3 — Memory ↔ graph bidirectional indexing (2–3 days)

Every `MemoryEntry` landed in a per-model folder gets indexed as a graph node with `GROUNDED_IN` edges to its provenance sources. Conversely, every graph node (Note, Chat, Session, ToolCall) can be queried for the memory entries that reference it.

Touches:
- `agent_core/src/graph/index.rs` — add `MemoryGraphIndexer` observing the memory compiler's write events.
- `agent_core/src/memory/provenance.rs` — canonical provenance resolver (`MemoryEntry ↔ {Note, Chat, Session, ToolCall}`).
- Graph queries extended: `memory_for(node_id)`, `nodes_for_memory(memory_id)`.

Verification:
1. A memory entry derived from Note X has `GROUNDED_IN → Note(X)` in the graph.
2. Deleting Note X and regenerating memory → the entry is deleted or flagged as orphaned with a TODO(provenance-broken) marker.
3. Round-trip: `memory_for(note_id) → entries`, then `nodes_for_memory(entry_id)` returns the original note.

#### J.4 — Cross-model memory federation (1–2 days)

Sometimes a fact learned by Claude should be available to Codex and Gemini. Build a **consolidation** pipeline that takes model-specific memory edits, projects them into the shared layer (with attribution), and flows them back into other model folders.

Explicitly NOT automatic. The user sees a "Share this across models?" chip on any non-trivial model-specific memory write. User approves → shared memory updated → other model views regenerate on next session start.

Touches:
- NEW `epistemos-core/src/memory/federation.rs` — consolidation proposer + user-approval gate.
- Swift UI: a lightweight "promote to shared memory" affordance in the memory-viewer (part of the Workbench in Phase I.4, or accessible via a new Settings pane).

Verification:
1. Claude writes a fact to `claude/facts/x.json`; consolidation chip offers to promote.
2. User accepts → `shared/facts.yaml` updated with attribution; next session start `codex/AGENTS.md` and `gemini/GEMINI.md` include the fact.
3. User declines → fact stays in `claude/` only; no cross-model leakage.

**Phase J verification across all sub-phases (before closing the phase):**
1. Regression harness: 1000 pre-phase graph queries (captured as test fixtures) produce byte-identical results with the flag OFF.
2. Backfill completeness: every chat in the SDChat table has exactly one corresponding `Chat` graph node.
3. Per-model folder integrity: all five folders present; primary entry files regenerate idempotently; append-only files never touched by regeneration.
4. Provenance integrity: every `MemoryEntry` has at least one `GROUNDED_IN` edge OR is explicitly marked `self-authored`.
5. Cross-model federation: shared memory changes propagate to all model views within one session-start; user approval gates are enforced.
6. **No regression in existing features.** Run the full existing test suite (2,679 tests per CLAUDE.md) — all pass.

---

### Phase K — iMessage channel unification + workspace dispatch (4–6 days) — NEW in v1.5

**Why this exists:** iMessage is currently a **tool** the agent can use (`agent_core/src/tools/imessage.rs` — send/list/read/recent/unread/search landed with Phase 1-7), but inbound iMessage does **not** trigger the Epistemos agent. The OpenClaw-inspired channel design already exists in [docs/BEST_OF_CLAW_AND_OPENCLAW.md §9](BEST_OF_CLAW_AND_OPENCLAW.md) with working Swift implementation code (`iMessageChannel` actor with FSEvents-driven `chat.db` polling + AppleScript sender). Phase K wires that design into the unified AgentRuntime and adds workspace-scoped dispatch so different senders can invoke different permission envelopes — the OpenClaw pattern applied to a PKM host runtime.

**Architecture call (explicit, to prevent drift):** iMessage does NOT wire to `cli_passthrough.rs`. It wires to `AgentRuntime`. The Router then decides whether the response comes from local Qwen, Claude CLI (Power Mode), Claude API, Codex, or Gemini — per the same §4.3 routing policy as normal chat. Claude Code's Remote Control and Channels features remain available as an OUTBOUND routing target (Epistemos → spawn `claude -p` with the inbound iMessage as prompt) but never as an inbound bypass.

**Prerequisites:** Phase A (event streaming — for response rendering), Phase C (provider discovery — so the Router can pick a provider), Phase I (chat/agent mode fusion — iMessage responses use the same bounded Chat profile by default). Phase J recommended (for graph indexing of iMessage chats as first-class nodes).

**Deliverable (3 sub-phases):**

#### K.1 — Wire the iMessage channel actor to AgentRuntime (1–2 days)

Implement the `iMessageChannel` actor from [BEST_OF_CLAW_AND_OPENCLAW.md §9](BEST_OF_CLAW_AND_OPENCLAW.md) as-specified (Swift actor, FSEvents on `~/Library/Messages/chat.db`, SQLite read for inbound, AppleScript for outbound, echo-cache to prevent self-loops, DM allow-list for security).

Route inbound to AgentRuntime, NOT to any specific provider. The actor skeleton:

```swift
// Epistemos/Channels/iMessageChannel.swift
// Adapted from BEST_OF_CLAW_AND_OPENCLAW.md §9. Kept minimal — full
// SQLite read, AppleScript send, echo cache, and DM allow-list land
// in K.1. This skeleton is the contract.
import Foundation
import SQLite3

actor iMessageChannel {
    private let chatDbPath = NSHomeDirectory() + "/Library/Messages/chat.db"
    private var lastMessageRowId: Int64 = 0
    private var sentMessageCache: Set<String> = []    // echo prevention
    private var allowedSenders: Set<String> = []       // empty by default — SECURITY!
    private let workspaceRouter: WorkspaceRouter
    private let agentRuntime: AgentRuntime

    init(workspaceRouter: WorkspaceRouter, agentRuntime: AgentRuntime) {
        self.workspaceRouter = workspaceRouter
        self.agentRuntime = agentRuntime
    }

    /// Begin watching chat.db for inbound messages.
    func startMonitoring() {
        let fd = open(chatDbPath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { await self?.drainInbound() }
        }
        source.resume()
    }

    /// Poll new inbound messages, route each through the workspace
    /// router, dispatch into AgentRuntime. DOES NOT call any CLI directly.
    private func drainInbound() async {
        for incoming in await readNewMessages() {
            // SECURITY: empty allow-list = nobody is authorized.
            guard allowedSenders.contains(incoming.sender) else {
                await auditLog.drop("unauthorized sender", incoming.sender)
                continue
            }
            // Echo cache: skip messages we sent ourselves.
            if sentMessageCache.contains(incoming.text.prefix(100).description) {
                continue
            }

            // Resolve which workspace's dispatch profile applies.
            let workspaceId = await workspaceRouter.resolve(
                sender: incoming.sender,
                chatIdentifier: incoming.chatId
            )

            // THIS IS THE CRITICAL RULE:
            //   Route into AgentRuntime.handleChannelDispatch().
            //   NOT into cli_passthrough.rs.
            //   NOT into a provider SDK directly.
            //   The Router inside AgentRuntime will pick the provider per §4.3.
            let dispatch = ChannelDispatchRequest(
                kind: .imessage,
                senderIdentifier: incoming.sender,
                chatIdentifier: incoming.chatId,
                text: incoming.text,
                workspaceId: workspaceId,
                timestamp: incoming.date
            )
            await agentRuntime.handleChannelDispatch(dispatch)
        }
    }

    /// Called by AgentRuntime when a turn completes. Sends the final
    /// assistant message back via AppleScript + caches to prevent echo.
    func sendReply(_ text: String, to recipient: String) async throws {
        try await sendViaAppleScript(text: text, recipient: recipient)
        sentMessageCache.insert(text.prefix(100).description)
    }

    /// Settings-driven: user explicitly adds authorized senders.
    /// Default is empty — NO sender is authorized on fresh install.
    func addAllowedSender(_ sender: String) {
        allowedSenders.insert(sender)
    }

    // readNewMessages() and sendViaAppleScript() are implementation
    // detail — full code in BEST_OF_CLAW_AND_OPENCLAW.md §9.
    private func readNewMessages() async -> [IncomingMessage] { /* SQLite read */ [] }
    private func sendViaAppleScript(text: String, recipient: String) async throws { /* NSAppleScript */ }
}
```

**Contract checks (will be tested in K.1 verification):**
- `allowedSenders` is empty on init. A fresh install responds to zero iMessages.
- `drainInbound` NEVER calls `cli_passthrough.rs` or any provider SDK directly.
- Every inbound message that passes the allow-list emits exactly one `AgentRuntime.handleChannelDispatch()` call.
- Echo cache prevents our own outbound messages from re-entering the pipeline.

`AgentRuntime.handleChannelDispatch` internally:
1. Classifies the task (TaskClassifier from A.2).
2. Selects provider via Router.
3. Creates a `Chat(kind="imessage")` record (writes through the same canonical path as normal chat — observed by ChatGraphIndexer in Phase J).
4. Runs the turn.
5. Emits `AgentEvent` stream (Phase A).
6. On completion, sends the final assistant message via `iMessageChannel.send()`.

**Security defaults (non-negotiable):**
- DM allow-list is empty by default — NO sender is authorized until the user explicitly approves them in Settings.
- Group-chat dispatch is opt-in per-group (user must enable `"respond-in-group"` flag for each group chat).
- Sender identity verification: Epistemos refuses to dispatch from a phone number that doesn't have a known contact record (via `imessage_contacts.db` — already landed).

Verification:
1. Send yourself an iMessage → Epistemos writes a `Chat(kind="imessage")` record and produces a response.
2. Send from a non-allowlisted number → no response, log line appears in the audit ledger.
3. The inbound iMessage causes NO direct CLI spawn; `ps aux | grep claude` before and after shows no new `claude` processes unless the Router happens to pick Power Mode.
4. Echo cache: Epistemos's own outbound messages don't re-enter the pipeline as inbound.

#### K.2 — Workspace-scoped dispatch profiles (OpenClaw pattern) (2–3 days)

Add a `Workspace` concept (leverages PLAN_V2 §19 workspace/profile ontology if not already built). Each workspace has:

```rust
pub struct WorkspaceDispatchProfile {
  pub workspace_id: String,
  pub allowed_imessage_senders: Vec<String>,  // phone numbers / Apple IDs
  pub allowed_groupchats: Vec<String>,         // chat_identifier patterns
  pub model_preference: ProviderPreference,    // e.g. "claude_code_cli_first"
  pub tool_allowlist: Vec<String>,             // subset of the global allowlist
  pub approval_tier_override: Option<ApprovalTier>, // can downgrade T1→T2 for this workspace
  pub budget_cap_usd_daily: Option<f64>,
  pub response_style: ResponseStyle,           // "terse", "full", "voice-friendly"
}
```

A `WorkspaceRouter` resolves an inbound iMessage to a workspace based on sender identity + optional chat-identifier patterns. The Router then uses that workspace's profile when dispatching.

UI:
- Settings → Channels → iMessage Dispatch shows a table of workspaces with their allow-lists, provider preference, and tool allowlist.
- Per-message test: "Send test dispatch to [workspace]" button that simulates an inbound iMessage and shows the resolved routing trace (which workspace matched, which provider picked, which tools allowlisted).
- Approval flow: when a tool call from an iMessage-originated session hits T3 approval, the approval request is delivered BACK to the sender via iMessage ("Epistemos wants to run `git push origin main`. Reply YES to approve, NO to deny."). Response parsed, approval granted/denied in Rust.

Example workspace configurations (ships as presets):

| Preset | Senders | Provider | Tools | Tier |
|---|---|---|---|---|
| "Work (read-mostly)" | allow-listed work contacts | Claude Code CLI → Sonnet | Read, vault_search, daily_note, summarize | T2 |
| "Personal" | family/friends | Qwen3-4B local | note_create, search, daily_note | T1 |
| "Research" | approved collaborators | Sonnet → Opus | full toolset + WebFetch | T2-T3 |
| "Client: <name>" | specific client email | Claude CLI | Read + summarize only | T3 |

Verification:
1. Configure two workspaces with different allow-lists and models; send iMessages from each workspace's contacts; verify different providers chosen per routing trace.
2. Tool outside a workspace's allowlist is refused with a user-visible "tool not permitted in this workspace" message.
3. Approval-via-iMessage round-trip: tool call triggers approval, user replies YES via iMessage, action proceeds and completes.

#### K.3 — Graph indexing + provenance (1 day)

Extends Phase J:
- Every `Chat(kind="imessage")` is linked to its `Workspace` via `IN_WORKSPACE` edge.
- Every iMessage message is indexed as a `Message` node with sender as an `Entity`.
- Every tool call triggered from an iMessage dispatch is indexed (Phase J.1 already covers the `Session → USES_TOOL → ToolCall → AFFECTS → Note` chain; Phase K.3 just tags the originating channel).
- `MemoryEntry` records "what the user said via iMessage" with provenance back to the original iMessage timestamp and sender — so Claude knows "Sarah said on April 10 that she wants these notes to stay private" and won't expose them in a different workspace.

Verification:
1. Graph query `walks from Chat(kind="imessage", id=X)` returns the full conversation, attached notes, resulting sessions, and any tool calls made.
2. Cross-workspace leak test: a memory entry learned from workspace-A iMessage does NOT surface in workspace-B's model context.

**Phase K verification across sub-phases:**
1. Inbound iMessage produces a response via the Epistemos runtime; response arrives as iMessage.
2. No direct CLI spawn unless the Router explicitly chooses Power Mode.
3. Workspace isolation: memory, tool allowlist, and approval tier differ across workspaces as configured.
4. Audit: `SELECT * FROM agent_turns WHERE trigger_channel = 'imessage'` shows the full dispatch history including provider selection and cost.
5. Security: default-closed allow-list; unauthorized senders get no response, audit logs the attempt.

**NOT in scope:**
- SMS support (out of scope for v1; iMessage only).
- BlueBubbles bridge (possible later; use Apple-native iMessage first per privacy posture).
- Voice-message-to-iMessage (future Phase 6 work per PLAN_V2 §6).

---

### Phase E — Schema-driven generative UI palette (5–7 days, GREENFIELD)

**Deliverable:**
1. Define the A2UI v0.9-compatible `EpisWidgetSpec` schema in Rust (`epistemos-core/src/ui/palette.rs`) using `schemars::JsonSchema`.
2. Generate JSON Schema at build time → embed in system prompt (~3K tokens, per Claude paper §3.1.4).
3. Build the SwiftUI component palette — ~25 components covering `VStack`, `HStack`, `Grid`, `Section`, `Card`, `Disclosure`, `Text`, `Heading`, `Markdown`, `Code`, `Label`, `Badge`, `Progress`, `TextField`, `Button`, `Toggle`, `TodoList`, `TerminalOutput`, `ThinkingTrace`, `NoteRef`, `GraphEdge`, `VaultSearch`, `ToolCallCard`. Use `@autoview` to generate initial SwiftUI boilerplate (Perplexity paper's tool).
4. Implement the `GenerativeView`/`ComponentRenderer` from Claude paper §3.1.3.
5. Wire the renderer to receive `AsyncSequence<A2UIEvent>` events over UniFFI — progressive rendering with skeleton shimmer on not-yet-delivered nodes.
6. GRDB cache: persist `(prompt_hash, surface_json)`; on repeat, render-from-cache + background regenerate + diff.

**Verification:**
- User asks "create a to-do list for my research tasks" → `TodoList` component renders in chat inline, progressively.
- User asks "build a scratchpad for the Stripe integration" → `Scratchpad` renders.
- Validation failure path shows raw LLM output as Markdown with "regenerate" button (not a broken component).

**NOT in scope:** MCP Apps iframe escape hatch (Phase F.2), raw SwiftUI codegen (permanently off-limits per Claude paper §3.0).

### Phase F — MCP dual-role (3–5 days, GREENFIELD for server)

**Deliverable:**
1. **Server role:** expose Epistemos vault/graph/tool APIs as an MCP server using `rmcp` crate, HTTP/SSE transport preferred (sandbox-friendly), stdio transport secondary. Enables users with Claude Desktop / Cursor / Zed / VS Code to drive Epistemos from those clients.
2. **Client role:** existing `agent_core/src/mcp/` — confirm it reads `~/.claude/mcp.json` and `~/.codex/config.toml` to reuse user's existing MCP server configs (GPT paper §1.3.2).
3. **OAuth 2.1 for server role** (per Gemini paper §5.5 — OAuth is mandatory as of March 2025 MCP spec).
4. **MCP Apps iframe escape hatch:** for the <5% of UI cases where the palette is insufficient, render MCP Apps content inside a locked-down `WKWebView` with `navigationDelegate` preventing external navigation and only the audited `postMessage` channel.

**Verification:**
- Open Claude Desktop, add Epistemos's MCP server URL, confirm vault tools appear and work.
- Open Epistemos; MCP servers configured in `~/.claude/mcp.json` appear in settings automatically.

**NOT in scope:** Claude Desktop extension packaging (future phase).

### Phase G — Project manifest compiler (3–5 days, GREENFIELD, THE GPT-PAPER DIFFERENTIATOR)

**Authoritative spec:** [docs/CLI_CONFIG_COMPILATION_RESEARCH.md](CLI_CONFIG_COMPILATION_RESEARCH.md). Phase G is an execution plan; when it disagrees with the research, the research wins.

**Scope boundary vs Phase J:** Phase G compiles **project-scoped** CLI config (per-vault `CLAUDE.md`, `.claude/`, `.codex/`, `.gemini/`, `.mcp.json`, `GEMINI.md`). Phase J compiles **user-scoped per-model memory folders** (`~/.epistemos/memory/<model>/`). The two compilers share the same `AtomicWriteWithFence` helper and fence convention but produce different artifact sets for different consumers. Do not merge them — they have different regeneration triggers and different ownership semantics (project docs are versioned with the vault; user memory is personal and cross-project).

**Deliverable:** `epistemos-core/src/manifest/` implementing the canonical Rust struct and compiler from research §6.3:

```rust
// Epistemos manifest — single source of truth
// See docs/CLI_CONFIG_COMPILATION_RESEARCH.md §6.3 for full field docs
pub struct EpistemosManifest {
  pub project_name: String,
  pub vault_root: PathBuf,
  pub models: BTreeMap<String, ModelRef>,      // planner/writer/fast/reasoning_heavy/summary
  pub approval: ApprovalPolicy,                // Untrusted | OnRequest | Never
  pub sandbox: SandboxProfile,                 // ReadOnly | WorkspaceWrite | WorkspaceWriteNet | DangerFullAccess
  pub permissions: Permissions,                // allow[], ask[], deny[], additional_dirs[]
  pub mcp_servers: Vec<McpServer>,             // Stdio | Http variants
  pub skills: Vec<PathBuf>,                    // cross-CLI SKILL.md dirs
  pub rules: Vec<RuleFile>,                    // .claude/rules/*.md with path globs
  pub hooks: BTreeMap<String, Vec<HookCommand>>,
  pub env_allow: Vec<String>,
  pub env_deny: Vec<String>,
  pub output_style: Option<String>,
  pub budget_cap_usd: Option<f64>,
  pub personal_notes: Option<PathBuf>,
}

pub fn compile(m: &EpistemosManifest) -> Result<CompiledFiles, CompileError>;

pub struct CompiledFiles {
  pub claude_md:       String,
  pub claude_local_md: Option<String>,
  pub claude_settings: serde_json::Value, // → ./.claude/settings.json (NO mcpServers here)
  pub mcp_json:        serde_json::Value, // → ./.mcp.json (mcpServers lives ONLY here)
  pub codex_config:    String,            // TOML → ./.codex/config.toml
  pub gemini_settings: serde_json::Value, // → ./.gemini/settings.json
  pub gemini_md:       String,            // → ./GEMINI.md
  pub rule_files:      Vec<(PathBuf, String)>, // → ./.claude/rules/*.md
}
```

Materialization targets on session boot (per research §6.4 regeneration policy):

| File | Regenerate on | Preserves user edits? |
|---|---|---|
| `CLAUDE.md`, `GEMINI.md` | session-start + manifest change | Yes — checksum-detected + fenced |
| `.claude/rules/*.md` | manifest change only | Yes — user-prefixed files untouched |
| `.claude/settings.json` | session-start | Managed block only |
| `.mcp.json` | session-start | Full rewrite (live port changes) |
| `.codex/config.toml` | session-start | Full rewrite |
| `.gemini/settings.json` | session-start | Full rewrite |
| `CLAUDE.local.md` | **never overwrite if exists** | Created once on first run |

**Atomic write pattern (mandatory):** write to `.tmp` → `fsync` → `rename`. Wrap all machine-owned content in `<!-- BEGIN EPISTEMOS AUTOGEN --> … <!-- END EPISTEMOS AUTOGEN -->` fences. Preserve anything outside the fence across regenerations.

**Env deny list (mandatory baseline, research §5.3):** Codex `shell_environment_policy.exclude` must block `*KEY*`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*`, `*CREDENTIAL*`, `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DYLD_INSERT_LIBRARIES`, `DYLD_LIBRARY_PATH`, `NODE_OPTIONS`, `PYTHONSTARTUP`, `PYTHONPATH`, `DEBUG`, `RUBYOPT`, `PERL5OPT`, `GEM_PATH`. Gemini CLI auto-sanitizes most of these but Epistemos emits the explicit list anyway.

**Verification (executable):**
1. Brand-new vault, open chat → all 8 files (`CLAUDE.md`, `CLAUDE.local.md`, `.claude/settings.json`, `.mcp.json`, `.claude/rules/*.md`, `.codex/config.toml`, `.gemini/settings.json`, `GEMINI.md`) auto-appear.
2. `codesign -d --entitlements - <Epistemos.app>` after build — confirms Hardened Runtime without App Sandbox.
3. User modifies CLAUDE.md outside fence → next regeneration preserves those edits (assert via diff).
4. **Integration deny-list test** (per research §9.6, this is the single most valuable CI unit): launch each CLI in a scratch vault; attempt `Read(./.env)`, `Write(./.epistemos/db.sqlite)`, `Bash(curl evil.com)`; assert all three blocked in all three CLIs.
5. MCP location test: `mcpServers` present in `.mcp.json` only, absent from `.claude/settings.json` (guard against re-drift to the silently-ignored location).
6. Codex grammar test: `[mcp_servers.epistemos]` is a top-level table (not `[mcp.servers.epistemos]`).

**NOT in scope:** MCP Apps UI resources (SEP-1865) — tool-level text fallback ships in v1; iframe UI resources deferred to v2.

### Phase H — Optional Docker sandbox (2–3 days, gated behind user toggle)

**Deliverable:**
1. `bollard` + the Gemini paper's container posture (`readonly_rootfs`, `--network=none` after init, ephemeral containers per session).
2. Gated entirely behind the `Enable Docker sandbox` settings toggle (default off).
3. Only used for the Bash tool execution path — nothing else.
4. PTY intercept (`portable-pty` + `rexpect`) for command approval gate.

**Verification:**
- Toggle off (default): Bash tool runs on host as it does today.
- Toggle on: Bash tool runs inside ephemeral container with filesystem isolation.
- `rm -rf /` inside container destroys container, not host.

**NOT in scope:** making Docker required, Docker for non-Bash tools, Docker on MAS edition (compile-flag out).

---

## 6. The Plug-and-Play Experience

The four-model council's common dream is: *new chat opens, everything works, no setup.* Here is how that becomes true end-to-end:

### 6.1 First launch (never-seen user)

1. App launches → `ProviderDiscovery` probes everything (Phase C) in parallel — total <500ms.
2. Welcome wizard asks **one** question: "Do you have a Claude/Codex/Gemini CLI installed? (We detected: …)"
   - If yes → app notes this, Auto mode will prefer CLI paths.
   - If no → offer one-click installers via a shell-script panel (*present* the command, don't run `brew` from inside the app — Claude paper §1.1.5).
3. Wizard asks for API keys (optional) → stored in Keychain (`security` framework).
4. App downloads Qwen 3.5 4B 4-bit MLX (~2.4GB) in the background, streaming progress. User can start using cloud models immediately.
5. Done. Total setup time: <60 seconds for the user, + background model download.

### 6.2 New chat bootstrap (every subsequent launch)

1. User clicks "New Chat."
2. Rust `ProjectManifestCompiler` checks if the current project root has `epistemos.project.json`. If not, generates a minimal default.
3. Rust materializes `CLAUDE.md` / `.codex/config.toml` / `.gemini/settings.json` / `mcp.json` into the project root (Phase G).
4. Rust warms a persistent `claude` subprocess if Power mode is enabled (Perplexity paper's insight — kills the 12-second cold start).
5. Rust warms the Qwen MLX session (if Local mode or Auto mode with local preferred).
6. UI receives "ready" event and shows input pane.
7. Total time: <3 seconds on warm cache, <8 seconds on cold.

### 6.3 Per-message flow

1. User types a message.
2. Rust `Router` classifies the task and picks a provider per the default policy table.
3. `RouterDecision` event fires → badge appears ("routing: Claude Code CLI · Pro subscription").
4. Rust spawns the provider.
5. Every NDJSON line fires a typed `AgentEvent` → Swift renders a component immediately (Phase A).
6. Tool-call cards animate in and resolve.
7. Final answer fills the chat bubble.
8. `SessionCheckpoint` event persists state to GRDB every 30s or every `RouterDecision`.

This is what makes the app feel alive.

---

## 7. Open Questions / Risks

### 7.1 The Omega orchestrator debt (Phase Ω, distinct from Phase I)

PLAN_V2 §21 states: "Rust is the sole control-plane authority." The live audit found `OrchestratorState.swift` and `OmegaPlanningService.swift` still own orchestration. Phase A above mentions this but does not remove it. **Recommendation:** add an explicit **Phase Ω (Omega orchestrator demolition)** after Phase A lands and every event renders live — that way you can verify the Rust loop is functionally complete before removing the Swift duplicate. NOTE: this is distinct from Phase I (Chat/Agent mode fusion, added in v1.3 — see §5 Phase I). To avoid naming collision, the Omega demolition is tracked as **Phase Ω** and can run in parallel with Phase I.1 (backend unification) since both work on the same Rust runtime facade.

### 7.2 The UniFFI vs BoltFFI decision

PLAN_V2 §22 says BoltFFI migration is benchmark-gated. Phase A above uses UniFFI with 16ms coalescing. **This is the right order.** Do not introduce BoltFFI for streaming until Phase A's benchmarks prove UniFFI + coalescing is insufficient. The BoltFFI toolchain adds build complexity and is premature if coalesced UniFFI meets the 5% main-thread utilization target.

### 7.3 Qwen3.6-35B-A3B vs Qwen3-8B

Claude paper recommended the 35B-A3B MoE model as planner. Memory says "16GB is the ceiling" and the 35B model quantized is ~18GB before KV cache. **Recommendation:** confirm with a benchmark harness on your M2 Pro. If 35B-A3B fits with bounded context, use it. If not, Qwen3-8B 4-bit MLX (~5.1GB) or Gemma 3n E4B 4-bit (~3.5GB) is the fallback.

### 7.4 The `simplify` skill

Memory's `feedback_minimal_fixes` and the `simplify` skill both point to the same discipline: every phase above should end with running the `simplify` skill on the touched code. This is an automation responsibility, not a plan content item, but don't skip it.

### 7.5 LoRA distillation (Claude paper §2.3)

Phase D above says LoRA fine-tuning on Claude Code traces is Phase 4 research. This is the right deferral — distillation is a V2 feature, not MVP. But start logging Claude Code traces (filtered for safety + PII) to a GRDB table now so the training data is available when Phase 4 arrives.

---

## 8. Concrete First Steps (this week)

If you were starting Monday, the sequence is:

1. **Today:** Run Phase 0 audit — confirm live state matches this document. Update `docs/AGENT_PROGRESS.md` if discrepancies found.
2. **Day 1–2:** Phase A — NDJSON event pipeline + ToolCallCard/ThinkingTrace/TerminalOutput components. Single PR.
3. **Day 3:** Phase B — Settings toggle. Single PR.
4. **Day 4:** Phase C — Provider discovery. Single PR.
5. **Day 5–7:** Phase D — Qwen Tier 1 + validator + few-shot store. Single PR (or two).

At the end of that week: the app feels alive, settings have a clear three-mode Intelligence pane, detected providers show up in real time, and Qwen's tool-calling is measurably better.

Everything after that (schema UI, MCP server, project manifest compiler, optional Docker) are the high-leverage additions that turn Epistemos from "an excellent PKM with AI" into "a workspace OS that AI runtimes plug into."

---

## 9. What to do next

You chose to read all four papers before asking for code. That was correct — the council is unanimous on the architecture and the differences were in the implementation details. This document resolves those details.

Suggested next action: **review Section 1 (sandbox/MAS) and Section 2 (per-model verdict) and either accept or push back.** Once you accept the architecture, Phase A is the first actionable PR.

If you want me to start Phase 0 (audit live state vs this doc) right now, tell me and I'll begin. If you want to modify this plan first — add, remove, or reorder phases — tell me what to change.

---

## Appendix A — Concrete specs for the 10 deep-dive questions

These are the implementable details behind the phased plan. Each section answers one of the questions the meta-prompt (second round of research) surfaced. The specs are intentionally opinionated; every phase above references one or more of these.

### A.1 — The MCP tool surface Epistemos should expose (Phase F.1)

When Epistemos runs as an MCP server, a user in Claude Desktop / Cursor / Zed / ChatGPT Desktop should be able to drive Epistemos remotely. The tool surface:

| Tool name | Purpose | Inputs | Outputs | Auth |
|---|---|---|---|---|
| `epistemos.vault.search` | Full-text + semantic search across vault | `query: string`, `limit: int = 20`, `include_graph_context: bool = false` | `results: [{ note_id, title, snippet, score, backlinks? }]` | session |
| `epistemos.note.read` | Fetch note body + metadata + backlinks | `note_id: string` OR `path: string` | `body: markdown`, `frontmatter`, `backlinks`, `forward_links`, `tags` | session |
| `epistemos.note.create` | Create a new note at vault path | `path: string`, `body: markdown`, `frontmatter?: object`, `tags?: string[]` | `note_id`, `path`, `created_at` | per-call |
| `epistemos.note.edit` | Edit existing note (full or diff) | `note_id: string`, `mode: "replace"|"diff"`, `content: string` | `note_id`, `version`, `updated_at` | per-call |
| `epistemos.graph.walk` | Traverse knowledge graph from a node | `start_node: string`, `depth: int = 2`, `edge_types?: string[]` | `nodes`, `edges`, `paths` | session |
| `epistemos.graph.neighbors` | Get immediate neighbors of a node | `node_id: string`, `limit: int = 50` | `nodes`, `edges` | session |
| `epistemos.tasks.list` | Enumerate open tasks across vault | `filter?: { status, tag, due_before }` | `[{ id, text, status, source_note }]` | session |
| `epistemos.tasks.create` | Create a task (free-floating or linked) | `text: string`, `linked_note_id?: string`, `due?: ISO8601`, `priority?: "low"|"med"|"high"` | `task_id` | per-call |
| `epistemos.session.log` | Append a journal entry to today's session | `entry: string`, `tags?: string[]` | `entry_id`, `timestamp` | session |
| `epistemos.model.ask` | Forward a prompt to Epistemos's own router (useful when remote client wants local Qwen) | `prompt: string`, `tier?: "local"|"auto"|"cloud"` | streamed text | per-call |
| `epistemos.tool.catalog` | Enumerate tools the local Epistemos agent can execute (transparency) | `session_id?: string` | `[{ tool_name, schema, category, approval_policy }]` | always |
| `epistemos.ui.render` | Ask Epistemos to render an A2UI widget spec in its chat pane | `spec: A2UIEnvelope` | `surface_id`, `rendered_at` | session |

**Transport:** HTTP/SSE with OAuth 2.1 (sandbox-friendly, auth-ready). Stdio reserved for trusted local dev only. All per-call tools route through the same `PermissionManager` as internal tool calls — no second approval plane.

### A.2 — Router decision table (Phase C + Phase D + Phase A)

Task classification is done by a lightweight Rust classifier (`TaskClassifier` trait) on first token of user input + context features (file extension in focus, vault state). The classifier emits a `TaskKind`, which combined with `ProviderMatrix` + `Budget` yields an ordered preference list.

```rust
enum TaskKind {
  Chitchat,        // <200 tok input, no tool use expected
  NoteWrite,       // summarize, rephrase, generate body
  VaultSearch,     // read-heavy, tool-use bounded
  SingleFileEdit,  // code edit on one file
  MultiStepAgent,  // <=3 hops (Gemini v2 ceiling)
  LongHorizonAgent,// >3 hops, plan needed
  CodeRefactor,    // spans multiple files
  HighStakes,      // destructive, financial, irreversible
}
```

| TaskKind | 1st preference | Fallback 1 | Fallback 2 | Escalation trigger |
|---|---|---|---|---|
| Chitchat | Qwen3-4B local | Haiku API | Gemini Flash | >512 tok response needed |
| NoteWrite | Qwen3-4B local | Sonnet API | Haiku API | Validator disagreement on schema |
| VaultSearch | Qwen3-4B + local tools | (always local) | (always local) | Never — vault data must not egress |
| SingleFileEdit | Claude Code CLI (if installed) | Anthropic API (claude-agent) | Codex API | Validator: re-read and diff mismatch |
| MultiStepAgent | Claude Code CLI | Anthropic API w/ checkpointing | Codex CLI `--resume` | Hops ≥ 3 + low confidence |
| LongHorizonAgent | Anthropic API w/ checkpointing | Codex CLI `--resume` | N/A | N/A — already escalated |
| CodeRefactor | Claude Code CLI | Anthropic API | Codex API | Test suite exit code ≠ 0 |
| HighStakes | User approval required before any model call | N/A | N/A | Always gate on UI approval |

**Uncertainty signals (all OR-ed):**
- **Logprob threshold:** mean logprob of final 32 tokens < −2.5 (config-tunable).
- **Self-consistency:** sample 3 responses at temp 0.7; if majority tool-call differs, escalate.
- **Validator:** `Edit` tool re-reads file and diffs; mismatch = escalate.
- **Turn count:** ≥ 3 for bounded, ≥ 8 for long-horizon (user-editable in Settings).

**Budget enforcement:** when daily USD cap reaches 80% consumed, `Auto` mode force-downgrades to local-only. At 100%, network is blocked and a modal appears. Aggregate via each provider's usage field (`total_cost_usd` from Claude, `usage.total_tokens` from OpenAI, `stats.tokens.total` from Gemini) in Rust.

**User-visible trace:** every message footer badge — `Local · Qwen3-4B · 1.2s · free` or `Claude Code CLI · Pro subscription · 8.4s` or `Anthropic API · Sonnet · 3.1s · $0.023`. Click to override for this message or pin the provider for the chat.

### A.3 — New-session bootstrap sequence (Phase G + Phase A)

When user clicks ⌘N, executed in parallel where marked:

1. **[parallel]** `ProviderDiscovery::probe()` from cache (24h TTL). If stale, re-probe.
2. **[parallel]** `MLXEngine::warm()` — preload Qwen3-4B weights into MLX context if Local/Auto mode.
3. **[parallel]** `ClaudeSubprocess::ensure_warm()` — if Power mode on and `claude` installed, spawn persistent `claude -p --bare --input-format stream-json` and keep stdin open (Perplexity paper's fix to 12s cold start).
4. **[parallel]** `ProjectManifestCompiler::reconcile()` — check `epistemos.project.json`, regenerate provider-specific files if drift detected. Uses `<!-- epistemos:BEGIN --><!-- epistemos:END -->` block convention to preserve user hand-edits.
5. **[parallel]** `MCPServer::start()` — if MCP-server role enabled, bind HTTP/SSE listener.
6. **[parallel]** `MCPClients::connect()` — for each server in user's `~/.claude/mcp.json` + `~/.codex/config.toml` + internal config, establish connection.
7. **[parallel]** `VaultIndex::hot_load()` — mmap FTS5 + graph snapshot (already instant if warm).
8. **[serial]** After all of above, `SessionState::new()` creates the GRDB row, `RouterDecision` badge becomes live, UI shows input pane.

**Target:** <3s warm, <8s cold (first launch after reboot). Run as `tokio::join!` in Rust for parallel legs.

### A.4 — The auto-generated provider config files (Phase G)

**⚠️ This section was rewritten in v1.2. The v1.1 stub templates contained four schema errors (see §0.5). Do not use the v1.1 shapes.**

The authoritative templates, schemas, and compilation spec live in [docs/CLI_CONFIG_COMPILATION_RESEARCH.md](CLI_CONFIG_COMPILATION_RESEARCH.md). That document is vendor-citation-pinned and covers:

- **CLAUDE.md** drop-in vault template (§7.2) — thin index that `@`-imports `.claude/rules/*.md`
- **`.claude/rules/vault-conventions.md`** with path-scoped YAML frontmatter (§7.3)
- **CLAUDE.local.md** personal-overrides template (§7.4)
- **`.claude/settings.json`** — `permissions.allow/ask/deny`, hook paths, env, output style, `enableAllProjectMcpServers` (§7.5)
- **`.mcp.json`** — project-scope MCP server definitions (§7.5 companion) — **NOT in settings.json**
- **`.codex/config.toml`** — including the correct `[mcp_servers.<id>]` grammar, `[sandbox_workspace_write]`, `[shell_environment_policy]`, `[permissions.workspace.filesystem]`, profiles (§7.6)
- **`.gemini/settings.json`** — with `mcpServers: {}` (top-level), `mcp: { allowed }`, `contextFileName: "GEMINI.md"`, sandbox config (§7.7)
- **GEMINI.md** mirroring CLAUDE.md with inlined rules (§7.7)

**Phase G implementation rule:** the compiler MUST emit exactly what the research document specifies. Any deviation requires a documented reason and a corresponding research update. Do not author new template shapes in this plan — update the research first, then reference.

**Regeneration policy (research §6.4):**
- `CLAUDE.md` / `GEMINI.md` → session start + manifest change (drift-protected by checksum)
- `.claude/rules/*.md` → manifest change only
- `.claude/settings.json` / `.mcp.json` / `.codex/config.toml` / `.gemini/settings.json` → every session start (live ports/paths)
- `CLAUDE.local.md` → **never** overwrite; create on first run only

**Atomicity:** write to `.tmp`, `fsync`, `rename`. Wrap Epistemos-owned blocks with `<!-- BEGIN EPISTEMOS AUTOGEN -->` / `<!-- END EPISTEMOS AUTOGEN -->`; preserve anything outside.

### A.5 — The 25-component A2UI palette (Phase E)

Every component is a SwiftUI view taking a typed `Props` struct. The palette is the contract — if a widget isn't in this list, the fallback renderer shows raw JSON with a "regenerate" button.

| Category | Component | Props (pseudo-Swift) | PKM surface |
|---|---|---|---|
| Container | `VStack` | `spacing: CGFloat?, children: [NodeId]` | universal |
| Container | `HStack` | `spacing: CGFloat?, alignment: VAlign?, children: [NodeId]` | universal |
| Container | `Grid` | `columns: Int, children: [NodeId]` | planner |
| Container | `Section` | `title: String?, children: [NodeId]` | structured surfaces |
| Container | `Card` | `elevation: Int?, children: [NodeId]` | note card, tool-call card |
| Container | `Disclosure` | `label: String, expandedByDefault: Bool, children: [NodeId]` | thinking trace |
| Primitive | `Text` | `content: String, style: TextStyle?` | universal |
| Primitive | `Heading` | `text: String, level: 1...6` | headings in generated notes |
| Primitive | `Markdown` | `source: String` | scratchpad, note body |
| Primitive | `Code` | `source: String, language: String?` | terminal output, code blocks |
| Primitive | `Label` | `text: String, color: SemanticColor?` | tags |
| Primitive | `Badge` | `text: String, variant: BadgeVariant` | status, priority |
| Primitive | `Progress` | `value: Double (0.0-1.0), label: String?` | long operations |
| Primitive | `Divider` | `(none)` | layout |
| Input | `TextField` | `binding: String, placeholder: String?` | ask-followup forms |
| Input | `TextArea` | `binding: String, minHeight: CGFloat?` | scratchpad writes |
| Input | `Button` | `label: String, onTap: Action, variant: BtnVariant` | approvals, navigation |
| Input | `Toggle` | `binding: Bool, label: String` | settings within GenUI |
| Input | `Picker` | `binding: String, options: [String]` | tool choice UI |
| Interactive | `ToolCallCard` | `toolName: String, input: JSON, status: ToolStatus, output: String?` | every tool call |
| Interactive | `ThinkingBubble` | `steps: [{ thought, action?, observation? }]` | reasoning traces |
| Interactive | `StreamingText` | `stream: AsyncSequence<String>` | token-by-token render |
| PKM | `NoteRef` | `noteId: String, title: String, preview: String?` | backlinks, graph jumps |
| PKM | `GraphEdge` | `from: NodeRef, to: NodeRef, label: String?` | relation visualization |
| PKM | `VaultSearch` | `query: String, results: [NoteRef]` | search result list |
| PKM | `TodoItem` | `id: String, text: String, done: Bool, priority: Priority?` | task lists |

**Schema size:** ~2.8K tokens when fully expanded as JSON Schema — fits comfortably in Qwen3-4B's context budget and any cloud model's system prompt allowance.

**Action semantics:** every `Button`'s `onTap: Action` routes through `PermissionManager`. A UI-emitted `{"type":"Button","props":{"onTap":"Bash:rm -rf …"}}` is treated identically to a model-emitted tool call — approval gate applies.

### A.6 — Kill switch ownership chain (required for <200ms ⌘.)

The cancellation cascade when ⌘. is pressed:

1. **Swift:** `ChatCoordinator.cancel()` fires on main actor (<1ms).
2. **Swift → Rust (UniFFI):** `agentSession.cancel()` async call — takes a `CancellationToken` that Rust already issued.
3. **Rust:** `CancellationToken::cancel()` sets `AtomicBool` to true (instant).
4. **Rust `tokio::select!` arms** in every await point check the token; active tasks drop their futures immediately:
   - HTTP streams: `hyper::Body` is dropped, TCP connection closed, server stops sending.
   - Subprocess: `Command::kill()` sends SIGTERM to child; after 2s SIGKILL.
   - MLX calls: Swift `LocalLLMProvider::cancel()` callback fires (UniFFI callback interface); Swift `mlxSession.interrupt()` stops token generation.
   - MCP: `rmcp::Client::cancel()` sends JSON-RPC cancel; drops reader.
   - Tools: in-flight `Tool::execute()` futures receive cancellation; `Bash` SIGKILLs its child.
5. **Rust:** emits `AgentEvent::SessionComplete { cancelled: true }`.
6. **Swift:** UI updates badges to "cancelled" in <16ms (one frame).

**Measured SLO target:** full chain completes in <200ms even with 3 parallel tool calls in flight. Tested nightly via integration test that spawns a session with a deliberately slow 10s subprocess, fires cancel at t+500ms, asserts completion before t+700ms.

**Critical pattern:** never use `.blocking_recv()` or `std::thread::sleep` in any await path. Every I/O call must be pollable by `tokio::select!`. Memory `project_macos26_global_event_monitor_bug` is a reminder that sync work in hot paths is a footgun.

### A.7 — Local model tiering for 16GB vs 32GB

| RAM | Executor (Tier 1/2) | Planner (Tier 2 first turn) | Fallback planner |
|---|---|---|---|
| **16GB** | Qwen 3.5 4B 4-bit MLX (~2.4GB) | Apple Foundation Models via `@Generable` (macOS 26+, 0 incremental RAM) | Haiku API — or self (Qwen 3.5 4B in planner role, accepting accuracy penalty) |
| **32GB** | Qwen 3.5 4B 4-bit MLX (~2.4GB) | Qwen3.6-35B-A3B 4-bit MLX (~18GB, MoE 3B active) | Apple Foundation Models |
| **48GB+** | Qwen 3.5 9B 4-bit MLX (~5.1GB) | Qwen3.6-35B-A3B 4-bit MLX (~18GB) | Claude Opus API |

**Never load planner + executor simultaneously on 16GB** — swap via weak-reference handoff. The planner emits the task list as JSON, then MLX unloads the planner weights, then the executor loads and runs. First-turn planner latency trades for stable memory ceiling.

On macOS 26+, **Apple Foundation Models** (`@Generable` + `@Guide`) is the right planner for 16GB because it adds zero incremental RAM and natively supports schema-constrained decode — exactly what planner output needs.

### A.8 — Security & approval ladder

Five tiers of approval, assigned per tool at registration time. Tool author cannot override; user can override via Settings → Tool Policy.

| Tier | Name | Default | Example tools |
|---|---|---|---|
| T0 | Always auto | User cannot disable | `epistemos.vault.read` (local only) |
| T1 | Auto with telemetry | Session-scoped grant after first use | `WebFetch`, `WebSearch`, `epistemos.note.read` |
| T2 | Approve per session | One OK per session per tool | `epistemos.note.create`, `epistemos.note.edit` |
| T3 | Approve per call | Every invocation | `Bash`, `MultiEdit`, `epistemos.tool.execute` |
| T4 | Always blocked in Local-Only mode | Network egress, payments, cloud LLM calls | Claude/OpenAI/Gemini API calls |

**Paranoid Mode** (settings toggle): promotes everything to T3. Useful for sensitive vaults or corporate Macs.

**Local-Only Mode:** T4 blocked at the network layer (egress filter in Rust, not app-level). Verified by proxy test.

### A.9 — GRDB observability schema (Phase D + permanent)

Every agent action queryable after the fact. Tables:

```sql
-- every user message + resulting agent turn
CREATE TABLE agent_turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  turn_index INTEGER NOT NULL,
  user_message_id TEXT,
  task_kind TEXT,                -- classification output
  classifier_confidence REAL,
  selected_provider TEXT,        -- e.g. "claude_code_cli"
  fallback_chain TEXT,           -- JSON array
  started_at DATETIME,
  ended_at DATETIME,
  total_cost_usd REAL,
  tokens_in INTEGER,
  tokens_out INTEGER,
  stop_reason TEXT,              -- end_turn, max_tokens, cancelled, error
  cancelled BOOLEAN,
  error_code TEXT
);
CREATE INDEX idx_turns_session ON agent_turns(session_id, turn_index);

-- every tool call Rust executed
CREATE TABLE tool_calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  turn_id INTEGER REFERENCES agent_turns(id),
  tool_name TEXT NOT NULL,
  input_json TEXT NOT NULL,
  output_json TEXT,
  started_at DATETIME,
  ended_at DATETIME,
  approval_tier INTEGER,         -- 0-4
  approved_by TEXT,              -- 'auto', 'user', 'session_grant'
  is_error BOOLEAN,
  error_message TEXT,
  cost_usd REAL
);
CREATE INDEX idx_tools_turn ON tool_calls(turn_id);
CREATE INDEX idx_tools_name ON tool_calls(tool_name);

-- router decisions (why this provider?)
CREATE TABLE router_decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  turn_id INTEGER REFERENCES agent_turns(id),
  decided_at DATETIME,
  reason TEXT NOT NULL,          -- "budget_at_80_percent", "low_confidence", etc
  signal_json TEXT,              -- the feature vector
  previous_provider TEXT,
  new_provider TEXT
);

-- escalations (crossed from local to cloud)
CREATE TABLE escalations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  turn_id INTEGER REFERENCES agent_turns(id),
  from_provider TEXT,
  to_provider TEXT,
  trigger TEXT,                  -- logprob, self_consistency, validator, turn_count, user
  context_token_count INTEGER,
  escalated_at DATETIME
);

-- the few-shot store (Gemini paper dissent, Phase D.4)
CREATE TABLE successful_tool_calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  prompt_text TEXT NOT NULL,
  prompt_embedding BLOB,         -- f16 vector for kNN
  tool_name TEXT NOT NULL,
  tool_input_json TEXT NOT NULL,
  tool_output_json TEXT,
  created_at DATETIME,
  used_as_fewshot_count INTEGER DEFAULT 0
);
CREATE INDEX idx_fewshot_tool ON successful_tool_calls(tool_name);
```

**Example queries for "why did Epistemos do X last Tuesday?":**

```sql
-- all turns in a session with their routing
SELECT t.turn_index, t.task_kind, t.selected_provider,
       r.reason, COUNT(tc.id) as n_tools, t.total_cost_usd
FROM agent_turns t
LEFT JOIN router_decisions r ON r.turn_id = t.id
LEFT JOIN tool_calls tc ON tc.turn_id = t.id
WHERE t.session_id = ? AND t.started_at > ?
GROUP BY t.id ORDER BY t.turn_index;
```

### A.10 — The 50-task golden set seed (categories + ratios)

| Category | Count | Examples |
|---|---|---|
| Note create | 6 | "Create a note about X", "new daily log entry", "capture a meeting summary" |
| Note rewrite | 5 | "Rewrite this paragraph more formally", "shorten this note", "convert to bullet list" |
| Vault search | 8 | "Find notes mentioning Y", "search for tagged :project:", "what notes link to Z" |
| Graph walk | 4 | "Show me the neighborhood of node Z", "2-hop from this note" |
| Tag extraction | 3 | "Extract tags from this note", "suggest tags for this" |
| Single-file edit | 6 | "Add a `created` field to this note frontmatter", "fix the typo on line 4" |
| Multi-step agent | 6 | "Plan my week from these 3 note-lists", "research X and summarize across N notes" |
| Code edit | 4 | "Rename this var", "add this import", "refactor this function to async" |
| Command execution | 3 | "Run the tests", "format this file", "show git status" (guarded) |
| Clarification | 3 | Ambiguous prompts where model should ask for clarification |
| Refusal | 2 | Requests that should be refused (destructive without context) |

**Run nightly against every configured provider.** A provider is accepted for a category only if golden-set success ≥ 85% at 95% CI; otherwise it's a fallback, not a preference. This is the defensible empirical basis for the router policy table in §A.2.

**Automation:** `cargo test --test golden_set -- --release` runs the full 50 across every provider overnight. Results go into a new `golden_set_runs` GRDB table and are summarized in a morning HTML report.

---

## Appendix B — Anti-Drift Reference Card (pinned April 2026)

This card exists so future sessions (Claude Code, Codex, or humans) cannot rediscover the hard-won schema facts the wrong way. Every entry is pinned to vendor documentation. When the vendor docs change, update this card and increment the date in the header. **Do not allow the plan to drift from this card.**

Last-verified-against-docs date: **2026-04-22**. Re-verify every 90 days or when any provider's docs page changes.

### B.1 Claude Code (CLAUDE.md / .claude / .mcp.json)

- **Scope precedence (highest → lowest):** Managed → CLI args → Local → Project → User. [settings](https://code.claude.com/docs/en/settings)
- **`mcpServers` ONLY lives in `~/.claude.json` or project `.mcp.json`.** Writing it to `.claude/settings.json` is silently ignored. [Issue #24477](https://github.com/anthropics/claude-code/issues/24477)
- **Array fields merge via concat+dedupe across scopes.** `permissions.allow[]`, `hooks[]`, `enabledMcpjsonServers[]`. Scalars override. [Vincent's blog](https://blog.vincentqiao.com/en/posts/claude-code-settings-intro/)
- **CLAUDE.md caps at ~40,000 chars** (`MAX_MEMORY_CHARACTER_COUNT`). Keep root project CLAUDE.md ≤ 200–300 lines.
- **`@path` imports recurse 5 levels deep.** First-time external imports trigger an approval dialog.
- **`.claude/rules/*.md` auto-loads** at project/user memory. YAML frontmatter `paths:` glob list scopes when it applies.
- **21 hook events** (2026 rework): `SessionStart/End`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `PreCompact`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `SubagentStart/Stop`, `TaskCreated/Completed`, `TeammateIdle`, `WorktreeCreate/Remove`, `CwdChanged`, `Notification`, `ConfigChange`, `FileChanged`. Handler types: `command`, `http`, `prompt`, `agent`. [hooks](https://code.claude.com/docs/en/hooks)
- **Command hook exit codes:** `0` = success (stdout may be JSON `{allow|deny|ask|additionalContext}`); `2` = block on `PreToolUse`/`PermissionRequest`; other non-zero = generic failure.
- **Permission modes:** `default`, `acceptEdits`, `plan`, `bypassPermissions`. `disableBypassPermissionsMode: "disable"` at managed scope to prevent bypass.
- **`deny` rules are reported as flaky.** Always pair sensitive denies with a `PreToolUse` hook returning exit code 2.
- **Skills:** `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `disable-model-invocation?`, `allowed-tools?`). Descriptions should be "pushy" — Claude undertriggers by default. Cross-compatible with Codex, Gemini, Cursor as of early 2026.
- **`claude --bare`:** SDK/orchestration only. Skips `.claude/`, `CLAUDE.md`, `.mcp.json`. Do not use for interactive sessions.
- **`--add-dir`:** adds file access but does NOT load `.claude/` from those dirs, EXCEPT `.claude/skills/` which IS auto-loaded. CLAUDE.md from added dirs needs `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`.
- **Auto memory:** `autoMemoryEnabled`, `autoMemoryDirectory` (default `~/.claude/plans`), kill-switch `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.

### B.2 OpenAI Codex CLI (.codex/config.toml)

- **Precedence (highest → lowest):** Requirements → Managed defaults → CLI flags / `-c` → Profile → Project config (only if trusted) → User config → System → Built-in defaults. [config-basic](https://developers.openai.com/codex/config-basic)
- **Project `.codex/config.toml` requires the vault to be trusted** (first `codex` run in the dir, or config UI). Otherwise only user config applies.
- **MCP grammar:** `[mcp_servers.<id>]` top-level tables. NOT `[mcp.servers.<id>]` (silent-fail bug [openai/codex#3441](https://github.com/openai/codex/issues/3441)).
- **`approval_policy = "on-failure"` is DEPRECATED.** Current: `untrusted`, `on-request`, `never`, or `{granular = {sandbox_approval, rules, mcp_elicitations, request_permissions, skill_approval}}`.
- **Sandbox modes:** `read-only`, `workspace-write`, `danger-full-access`. Config table `[sandbox_workspace_write]` controls `writable_roots`, `network_access`, `exclude_tmpdir_env_var`, `exclude_slash_tmp`.
- **Protected paths inside writable roots:** `.git/` and `.codex/` are auto-prompted. Epistemos should also protect `.epistemos/`, `*.env`, `*.key`, `*.pem` via `[permissions.workspace.filesystem]`.
- **Env policy:** `[shell_environment_policy]` with `inherit = "core"|"all"|"none"`, `include_only[]`, `exclude[]`, `ignore_default_excludes` (default false — keeps KEY/SECRET/TOKEN filtering on).
- **`codex exec` flags:** `--full-auto` (workspace-write + on-request), `--yolo`/`--dangerously-bypass-approvals-and-sandbox`, `--json` (NDJSON stream), `--output-schema <file>`, `--output-last-message <file>`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, `-a never`, `-c key=value`.
- **`codex mcp serve`** runs Codex itself as an MCP server — orthogonal to Epistemos registering its server with Codex.
- **`auth.json` is machine-bound.** Epistemos MUST NOT generate, copy, or touch it.
- **Skills:** `[[skills.config]]` per-skill overrides; same SKILL.md format as Claude Code since late 2025.

### B.3 Google Gemini CLI (.gemini/settings.json)

- **Scope:** user `~/.gemini/settings.json` + project `.gemini/settings.json`. Extensions can add `mcpServers`; local always vetoes via `excludeTools`.
- **`mcpServers` lives at TOP LEVEL** as an object map (key = server id). `mcp: { allowed: [], excluded: [] }` is SEPARATE (global MCP allowlist).
- **Context file:** `GEMINI.md` by default. Path configurable via `contextFileName`. Loads hierarchically from cwd upward.
- **Env auto-sanitization:** Gemini strips `*TOKEN*`, `*SECRET*`, `*PASSWORD*`, `*KEY*`, `*AUTH*`, `*CREDENTIAL*`, cert/private-key patterns from MCP subprocess env UNLESS explicitly listed in server's `env` block (counts as informed consent).
- **Tool restriction merge:** `excludeTools` unions across sources (any block sticks); `includeTools` intersects; `excludeTools` always wins over `includeTools`.
- **Sandbox:** `sandbox: true | "docker" | "podman" | false` + `sandboxImage`.
- **CI flags:** `gemini -p "<prompt>"`, `--output-format json`, `--yolo`, `--non-interactive`, `--sandbox`.

### B.4 MCP (Model Context Protocol)

- **Current stable spec:** November 2025. No new version cut in 2026 as of April. SEPs continue to land. [2026 roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)
- **Transports:** stdio (preferred for local), Streamable HTTP (current remote standard), SSE (still accepted, discouraged for new deployments).
- **OAuth 2.1 for MCP:** production-stable. Codex: `codex mcp login`. Gemini: OAuth 2.0 for remote servers. Claude: `type: "http"` + `headers.Authorization: "Bearer ${TOKEN}"` or browser OAuth if server advertises.
- **MCP Apps (SEP-1865) finalized 2026-01-26.** Extension ID `io.modelcontextprotocol/ui`. Content type `text/html;profile=mcp-app` in sandboxed iframes. Clients shipped: ChatGPT, Claude, Goose, VS Code. Always include text fallback per spec.

### B.5 Cross-cutting shipping constraints (all four models converge)

- **Distribution:** Developer ID + Hardened Runtime + Notarization. **NO App Sandbox.** Like Cursor/Zed/Warp/Raycast/Aider/Obsidian.
- **Entitlements (primary edition):** `com.apple.security.cs.allow-jit` (MLX Metal), `com.apple.security.cs.disable-library-validation` (mlx-lm + child Node CLIs), `com.apple.security.network.client` (provider APIs). Explicitly **NOT** `com.apple.security.app-sandbox` or `com.apple.security.cs.allow-unsigned-executable-memory`.
- **Never generate/touch** `~/.claude.json` user scope, `~/.codex/auth.json`, Keychain entries on behalf of the user. Only project-scoped files.
- **Always spawn `claude -p --bare`** for programmatic calls to avoid rerouting Pro/Max OAuth. Framing: "Epistemos launches your existing Claude Code with a prompt you author."
- **Anthropic ToS:** personal subprocess spawn is fine; offering Claude.ai login as a service is prohibited.
- **16GB M2 Pro ceiling:** Qwen 3.5 4B 4-bit MLX (~2.4GB weights, 30-50 tok/s decode, 200-400 tok/s prefill). Anything >8B risks "swap death." 32GB recommended; 48GB+ for Qwen 3.5 9B.
- **Never coalesce or drop** error, approval, completion, or cancellation events. Only text/thinking deltas coalesce to 16ms frame batches.

---

## Appendix C — Executable Claude Code build brief

This appendix exists for a specific audience: **a future Claude Code / Codex agent** (or you running one) that needs to execute the phases without re-synthesizing. Each phase below has:

- the exact working directory + files it may touch
- the exact session prompt to paste into Claude Code
- the exact verification command

**Unified prompt framework:** every phase prompt assumes the operator has already run **Appendix D's bootstrap prompt** first. Do not duplicate the always-load files or the drift-alarms in a phase prompt — they are in Appendix D and the agent has them loaded. If the operator skipped Appendix D, the phase prompt will fail early when it references files the agent hasn't read.

**Phase coverage:** C.0 (Phase 0), C.1 (Phase A), C.2 (Phase B), C.3 (Phase C), C.4 (Phase D), C.5 (Phase I), C.6 (Phase J), C.7 (Phase K), C.8 (Phase G), C.9 (Phases E/F/H — stubs, activate later), C.10 (running Claude Code against this plan), C.11 (drift response).

Run phases in order per the master sequence in §5. Do not skip Phase 0. Commit after each phase (per memory `feedback_commit_after_change`).

### C.0 Phase 0 — Truth audit (no code changes)

**Working dir:** `/Users/jojo/Downloads/Epistemos`
**Read-only. No writes except `docs/AGENT_PROGRESS.md` if discrepancies are found.**

**Session prompt:**
```
Read CLAUDE.md in the repo root, docs/AGENT_PROGRESS.md,
docs/AGENT_RUNTIME_ARCHITECTURE.md, and docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md.

Then grep for live-code truth on five claims:
1. Does agent_core/src/agent_loop.rs exist and implement a multi-turn
   loop, or is it scaffold?
2. Does Epistemos/State/OrchestratorState.swift still drive orchestration,
   or has it been demoted to UI-only?
3. Does cli_passthrough.rs spawn `claude -p --bare --output-format
   stream-json`, or a different invocation?
4. Is there ANY A2UI / Widget / ComponentRegistry pattern in Epistemos/?
5. Does any Swift code render ToolCallCard / ThinkingTraceView /
   TerminalOutputCard components in the chat view?

For each claim, cite file:line as evidence.
If any claim in IMPLEMENTATION_PLAN_FROM_ADVICE.md §3 is wrong per your
evidence, append a "DRIFT FOUND" section to docs/AGENT_PROGRESS.md with
the specifics. Do not edit other files. Report in under 400 words.
```

**Verification:** `git status` should show either no changes OR only `docs/AGENT_PROGRESS.md` touched.

### C.1 Phase A — Event streaming pipeline

**Working dir:** `/Users/jojo/Downloads/Epistemos`
**Touches:** `agent_core/src/agent_loop.rs`, `agent_core/src/providers/claude.rs`, `Epistemos/Bridge/StreamingDelegate.swift`, NEW `Epistemos/Views/Chat/ToolCallCard.swift`, NEW `Epistemos/Views/Chat/ThinkingTraceView.swift`, NEW `Epistemos/Views/Chat/TerminalOutputCard.swift`, NEW `Epistemos/Views/Chat/RouterDecisionBadge.swift`.

**Session prompt:**
```
Goal: make the app feel alive by rendering every NDJSON event from the
agent loop as a live SwiftUI component. Read
docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase A (§5 Phase A) and
docs/PLAN_V2.md §24 (Agent Streaming Data Plane).

1. Audit agent_core/src/agent_loop.rs + providers/claude.rs and confirm
   every NDJSON variant surfaces as a distinct AgentEvent enum variant:
   text_delta, thinking_delta, tool_use, tool_result, bash_output,
   session_checkpoint, rate_limit_retry, router_decision,
   session_complete, error. Fix any missing variants.
2. Add 16ms frame-aligned coalescing in Rust for text_delta + thinking_delta
   ONLY. Never coalesce errors, approvals, completion, cancellation.
   Emit a TelemetryEvent when backpressure activates.
3. Extend UniFFI AgentEventSink callback interface with onToolCallRequested,
   onToolCallResult, onBashLine, onRouterDecision if not already present.
4. Create the four SwiftUI components listed in this prompt's touched-files
   list. ToolCallCard animates with a spinner, resolves to checkmark or
   red-X with output preview. ThinkingTraceView is collapsed by default,
   streams into collapsed panel. TerminalOutputCard is ANSI-aware.
   RouterDecisionBadge shows "routed to: <provider> · <subscription>".
5. Wire them into the chat view so they render on each AgentEvent variant.

Do NOT migrate to BoltFFI. Do NOT add generative UI palette. Do NOT
touch routing or approval logic. Single-PR scope.
```

**Verification (measurable):**
- `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify` passes.
- `cargo test --manifest-path agent_core/Cargo.toml` passes.
- Send a Claude Agent message that uses 2+ tools → both tool-call cards animate and resolve.
- `os_signpost` trace shows main-thread utilization <5% during streaming (PLAN_V2 §24.5 target).

### C.2 Phase B — Intelligence settings toggle

**Touches:** `Epistemos/Views/Settings/AgentControlSettingsView.swift` (extend), NEW `Epistemos/State/IntelligenceSettingsState.swift`.

**Session prompt:**
```
Goal: add the three-mode Intelligence toggle to AgentControlSettingsView.
Spec is in docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §4.2.

The three modes are: Local only | Auto (default) | Manual. Below the
modes, show detected providers (placeholder for Phase C which will probe
them for real), a budget cap slider ($/day), escalation triggers
(low confidence, step >= 3, validator failure), and three advanced
toggles: "Allow subprocess CLIs", "Share Epistemos as MCP server",
"Enable Docker sandbox". All toggles default to the values in §4.2.

Persist via @AppStorage; on mode change, post a
NotificationCenter notification that the router (Phase C) will
subscribe to. Do NOT implement the router logic itself; just the UI
and state.
```

**Verification:** mode toggles persist across app restart; `Local only` disables a placeholder network call (real block lands in Phase C); UI matches §4.2 mock.

### C.3 Phase C — Provider discovery + cache

**Touches:** NEW `epistemos-core/src/discovery.rs`, `epistemos-core/src/lib.rs` (export), Swift settings pane wiring.

**Session prompt:**
```
Goal: probe installed CLIs and API keys, cache in GRDB with 24h TTL,
expose via UniFFI to the Settings pane.

Spec: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase C + §4.2 +
Appendix B.5 cross-cutting constraints.

Probe in parallel (tokio::join!):
- `which claude`, `which codex`, `which gemini` + known paths:
  /opt/homebrew/bin, /usr/local/bin, ~/.npm-global/bin, ~/.bun/bin,
  ~/.volta/bin, ~/.local/bin, ~/.nvm/versions/node/*/bin.
- Env vars: ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY.
- macOS Keychain entries (via `security` framework) for same three.
- MLX model cache at ~/.cache/epistemos/mlx/.

Emit ProviderMatrix { cli_available, api_keys, local_models,
mcp_servers } via UniFFI. Cache in GRDB table `provider_discovery`
with columns (probed_at, binary_path, binary_mtime, version).
Invalidate cache entry on launch if binary stat mtime changed.

Settings pane now shows real data. `Local only` mode blocks all
provider HTTP in Rust, not just UI.

Do NOT add the router policy itself; just the provider matrix.
```

**Verification:** open Settings → detected providers list matches `which claude && which codex && which gemini` output in a terminal, with actual version numbers.

### C.4 Phase D — Qwen three-tier agentic loop + few-shot store

**Touches:** `agent_core/src/agent_loop.rs` (if not production yet), NEW `agent_core/src/memory/few_shot.rs`, `agent_core/src/routing.rs` (escalation triggers), NEW GRDB migration for `successful_tool_calls` table, Swift `MLXInferenceService.swift` (planner/executor swap on 16GB).

**Session prompt:**
```
Goal: make Qwen 3.5 4B genuinely agentic via three tiers with cloud escape
hatches. Spec: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §5 Phase D + Appendix
A.2 (router table), A.7 (16GB planner: Apple Foundation Models on macOS 26+),
and Appendix B.5 (Qwen 3.5 4B is the ONLY sensible local model for 16GB).

1. Tier 1 native tool calling — ensure MLX-Swift exposes tool schemas as JSON
   function defs; on macOS 26+ use Apple Foundation Models @Generable for
   schema-constrained output; on older macOS use two-step validate-and-retry.
2. Tier 2 structured ReAct in Rust — implement the loop template from the
   plan §5 Phase D.2 with max 3 hops (Gemini v2 ceiling). Validator after
   each tool call: re-read edited file, diff against expected; on mismatch
   feed "file didn't match; expected X, got Y" into next observation.
   Enforce tool allowlist from Appendix A.8.
3. Tier 3 cloud escalation — four signals OR-ed: mean logprob of final 32
   tokens < -2.5, self-consistency disagreement across 3 samples at
   temp 0.7, validator disagreement, turn count >= 3 (user-editable up
   to 8 in Settings).
4. Few-shot store — new GRDB table successful_tool_calls per Appendix A.9.
   On every successful tool call, embed the prompt via MLX, store
   (prompt_text, prompt_embedding, tool_name, tool_input_json,
   tool_output_json). At request time, kNN-retrieve top-3 and inject into
   system prompt. This is the Gemini-paper Dynamic Few-Shot Prompting
   dissent — it measurably raises small-model tool accuracy.
5. Planner/executor split — first turn uses planner (Qwen3-8B or Apple
   Foundation Models on macOS 26+, NEVER 35B-A3B on 16GB). Subsequent
   turns use Qwen 3.5 4B executor. Enforce memory ceiling: never load
   both simultaneously; swap via weak-reference handoff.

Verification: nightly 200-task golden-set run (Appendix A.10) achieves
>= 85% success at 95% CI on Tier 1 tasks. Memory watermark never
exceeds 11GB during runs. cargo test --manifest-path agent_core/Cargo.toml
passes. xcodebuild builds clean.

Do NOT: fine-tune Claude Code traces (Phase 4 research — out of scope).
```

### C.5 Phase I — Chat/Agent mode fusion (UX migration, 4 sub-phases)

**Touches (across sub-phases):** `agent_core/src/runtime/mod.rs` (unified facade), existing Swift chat view controllers, NEW `Epistemos/Views/Composer/ModePillView.swift`, NEW `Epistemos/Views/Composer/AgentRunStripView.swift`, NEW `Epistemos/Views/Agent/PromotionChipView.swift`, NEW `Epistemos/Views/Workbench/WorkbenchView.swift`, existing settings to hide Workbench behind flag.

**Session prompt (split into 4 commits, one per sub-phase):**
```
Goal: collapse "tools chat" vs "regular chat" into one runtime with two
autonomy modes. Spec: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §4.3a +
Phase I (4 sub-phases I.1-I.4).

I.1 Backend unification — no UX change. Extract from tools-chat code path
and expose unified AgentRuntime facade (tool registry, approval manager,
router, provider selection, execution ledger, tool-call card emission,
session persistence, checkpoint/resume, budget tracking). Both existing
surfaces call into it. Commit.

I.2 Smart Chat profile — normal chat gets tools with a 3-hop ceiling,
allowlist Read/Glob/Grep/WebSearch/vault_search/embed_search/backlinks/
daily_note/note_create (T2)/note_update (T2). On complexity spike,
suggest promotion instead of looping. Inline tool cards via Phase A
(no full planner panel). Commit.

I.3 Agent mode first-class — pill-style [Chat|Agent] above composer
(always visible, NOT in a popover). Separate [Effort: Auto ▾] popover
accessible in both modes. When Agent selected: inline run-strip reveals
Scope chips [This note|Folder|Workspace] + Access dropdown
[Ask first|Can edit|Shell ask]. Send button label changes: "Send" (Chat)
→ "Run" (Agent). First-time-in-Agent explainer modal (one-shot per vault).
Three entry paths: direct (tap Agent → Run), promotion chip
("This looks like an agent task..."), auto-escalation suggestion.
Agent run UI revealed AFTER Run pressed: phase indicator,
plan/todo list, approval queue, stop button, terminal panel when
Bash in use, checkpoint affordance. Commit.

I.4 Workbench demotion — rename "Tools chat" nav entry to "Workbench".
Move to Settings→Advanced→"Open Workbench" OR dev menu with env
EPISTEMOS_SHOW_WORKBENCH=1. Default install: hidden from main sidebar.
Retains raw tool-call replay, router trace, regression test UI, MCP
config live preview. Commit.

Verification per sub-phase: I.1 two surfaces execute identical tools
given identical prompts. I.2 classifier correctly distinguishes
Chitchat/NoteWrite/VaultSearch/SingleFileEdit from MultiStepAgent+.
I.3 mode switch persists, promotion chip fires within 500ms of
classifier decision, kill switch cancels Agent run in <200ms.
I.4 Workbench unreachable without the flag or advanced nav.
```

### C.6 Phase J — Unified knowledge graph + per-model native memory (4 sub-phases)

**Touches:** `agent_core/src/graph/schema.rs` (additive enums), NEW `agent_core/src/graph/index.rs`, NEW `agent_core/src/graph/backfill.rs`, NEW `epistemos-core/src/memory/{mod,claude,codex,gemini,qwen,foundation,shared,federation,provenance}.rs`, feature flag plumbing for EPISTEMOS_GRAPH_INDEX_CHATS.

**Session prompt (split into 4 commits, one per sub-phase):**
```
Goal: make every chat/session/tool-call/memory a first-class graph node;
give each model a memory folder in its native format. Spec: docs/
IMPLEMENTATION_PLAN_FROM_ADVICE.md §4.4, §4.5, Phase J.

CRITICAL REGRESSION-SAFETY RULES (non-negotiable):
- Additive schema only — no existing node/edge type is renamed or removed.
- Existing graph queries (graph_walk, backlinks, frontlinks, embed_search,
  vault_search) return BYTE-IDENTICAL results with flag OFF.
- Write paths unchanged; graph index is observer-pattern on existing
  SDChat.save() — not a replacement.
- Idempotent indexing; backfill rate-limited to 50/sec.
- Feature flag EPISTEMOS_GRAPH_INDEX_CHATS provides full rollback.
- Full 2,679-test suite must pass before the phase closes.

J.1 Chat/session/attachment graph indexing — add additive node types
Chat, Message, Session, ToolCall, Attachment, ModelVault. New
ChatGraphIndexer observes SDChat save notifications. Backfill job
walks existing chats at 50/sec. Commit.

J.2 Per-model memory folder compiler — PerModelMemoryCompiler trait.
claude.rs emits CLAUDE.md + rules/*.md (YAML-frontmatter path-scoped)
+ skills/*/SKILL.md + plans/ (autoMemoryDirectory) + facts/*.json
(Anthropic Memory Tool memory_20250818 shape). codex.rs emits
AGENTS.md + rules + skills + sessions/*.jsonl. gemini.rs emits
GEMINI.md + rules + skills + memory/*.md (memoryTool format).
qwen.rs emits CORE.md + rules + skills + few-shot/*.jsonl (shared
with Phase D store) + facts.yaml + embeddings.sqlite (MLX-backed).
foundation.rs emits CORE.md + rules only (stateless, macOS 26+).
shared/ is canonical source of truth. All atomic writes
(.tmp → fsync → rename) with <!-- BEGIN EPISTEMOS AUTOGEN -->
fences. Commit.

J.3 Memory <-> graph bidirectional — MemoryGraphIndexer observes
memory-compiler writes; every MemoryEntry gets GROUNDED_IN edges to
Note/Chat/Session/ToolCall sources. New queries memory_for(node_id)
and nodes_for_memory(memory_id). Orphan detection on source deletion.
Commit.

J.4 Cross-model federation — user-approved consolidation chip
surfaces on non-trivial per-model writes. "Share across models?"
buttons: approve → shared/facts.yaml updated with attribution →
per-model views regenerate. Default: NO automatic cross-model leak.
Commit.

Verification across all sub-phases: 1000 pre-phase graph query
fixtures produce byte-identical results with flag OFF. Backfill
completeness: every SDChat row has exactly one Chat graph node.
All 5 per-model folders exist with primary entry file. Provenance
integrity: every MemoryEntry has >= 1 GROUNDED_IN edge or
self-authored flag. Full 2,679-test suite passes.
```

### C.7 Phase K — iMessage channel unification + workspace dispatch

**Touches:** NEW `Epistemos/Channels/iMessageChannel.swift` (from BEST_OF_CLAW_AND_OPENCLAW §9 design), NEW `agent_core/src/channels/mod.rs`, NEW `agent_core/src/workspace/{dispatch,router}.rs`, existing `agent_core/src/tools/imessage_contacts.rs` (reuse), Swift Settings pane for Channels.

**Session prompt:**
```
Goal: wire inbound iMessage as a channel into AgentRuntime with
workspace-scoped dispatch profiles (OpenClaw pattern). Spec: docs/
IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase K + docs/
BEST_OF_CLAW_AND_OPENCLAW.md §9 (has the Swift implementation code).

ARCHITECTURE RULE (non-negotiable): inbound iMessage routes into
AgentRuntime.handleChannelDispatch(), NOT to cli_passthrough.rs or any
specific provider SDK. Router decides provider per §4.3 policy. This is
how "dispatch like Claude" works but better than Claude Code's
Remote Control — it works offline via Qwen, applies Epistemos's
approval layer, supports workspace-scoped dispatch.

K.1 Wire the iMessageChannel actor — implement as-specified in
BEST_OF_CLAW_AND_OPENCLAW §9 (FSEvents on ~/Library/Messages/chat.db,
SQLite read for inbound, AppleScript for outbound, echo cache,
DM allow-list). On inbound message, build iMessageDispatchRequest
with resolved workspaceId from WorkspaceRouter and call
AgentRuntime.shared.handleChannelDispatch(). AgentRuntime internally:
classifies task, selects provider via Router, creates
Chat(kind="imessage") record, runs turn, emits AgentEvent stream
(Phase A), on completion sends final assistant message via
iMessageChannel.send(). Commit.

Security defaults (NON-NEGOTIABLE):
- DM allow-list EMPTY by default — no sender authorized until user
  explicitly adds them in Settings.
- Group-chat dispatch opt-in per-group.
- Sender identity verified against imessage_contacts.db.
- Echo cache prevents self-loops.

K.2 Workspace-scoped dispatch profiles — add Workspace concept (leverages
PLAN_V2 §19 if already built). WorkspaceDispatchProfile struct with
allowed_imessage_senders, allowed_groupchats, model_preference,
tool_allowlist, approval_tier_override, budget_cap_usd_daily,
response_style. WorkspaceRouter resolves inbound to workspace. UI:
Settings→Channels→iMessage Dispatch shows workspace table, per-message
test button, approval-via-iMessage round-trip for T3 tools (user
replies YES/NO in iMessage). Ship 4 preset workspace configs:
"Work (read-mostly)", "Personal", "Research", "Client: <name>". Commit.

K.3 Graph indexing + provenance — extends Phase J. Every
Chat(kind="imessage") gets IN_WORKSPACE edge. MemoryEntry derived
from iMessage has provenance back to original sender + timestamp.
Cross-workspace leak test: memory from Work-workspace NOT in
Personal-workspace context. Commit.

Verification: inbound iMessage produces response via Epistemos runtime;
no direct CLI spawn unless Router picks Power Mode. Workspace isolation
verified by cross-workspace leak test. Security defaults enforced.
Audit trail: SELECT * FROM agent_turns WHERE trigger_channel = 'imessage'
shows full dispatch history with provider + cost.
```

### C.8 Phase G — Project manifest compiler (defer if not ready)

**Working dir:** `/Users/jojo/Downloads/Epistemos`
**Touches:** NEW `epistemos-core/src/manifest/mod.rs`, `manifest/schema.rs`, `manifest/compile.rs`, `manifest/templates/` (embed templates), existing `epistemos-core/src/lib.rs` (export).

**Session prompt:**
```
Goal: implement the Epistemos manifest → {CLAUDE.md, CLAUDE.local.md,
.claude/settings.json, .mcp.json, .claude/rules/*.md, .codex/config.toml,
.gemini/settings.json, GEMINI.md} compiler.

SPEC: docs/CLI_CONFIG_COMPILATION_RESEARCH.md is the single source of
truth. Read §1 (Claude), §2 (Codex), §3 (Gemini), §4 (MCP), §5 (sandbox),
§6 (manifest compilation pattern), §7 (Epistemos-specific content).

Also read docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase G + Appendix B
(anti-drift card) for the pinned schema facts.

Implement:
1. Struct EpistemosManifest per research §6.3 (copy verbatim). Derive
   schemars::JsonSchema + serde.
2. Function `pub fn compile(m: &EpistemosManifest) -> Result<CompiledFiles, CompileError>`.
3. Embed the templates from research §7.2–§7.7 as `include_str!`ed
   Handlebars templates with `{{VAULT_ROOT}}`, `{{PROJECT_NAME}}`,
   `{{APP_BUNDLE}}`, `{{EPISTEMOS_PORT}}`, `{{BUDGET}}` placeholders.
4. Atomic write: `.tmp` → `fsync` → `rename`. Wrap managed content
   in `<!-- BEGIN EPISTEMOS AUTOGEN --> … <!-- END EPISTEMOS AUTOGEN -->`.
5. Regeneration policy matches research §6.4 table exactly.
6. UniFFI-export a top-level `regenerate_manifest(manifest_json: String,
   vault_root: String) -> ResultCode`.

CRITICAL ANTI-DRIFT CHECKS (will be tested):
- `mcpServers` appears in `.mcp.json` ONLY. NOT in `.claude/settings.json`.
- Codex TOML uses `[mcp_servers.epistemos]` (top-level table), NOT
  `[mcp.servers.epistemos]` (this is the silently-failing form).
- Codex `approval_policy` is one of {untrusted, on-request, never,
  {granular=...}}. Never emit `"on-failure"` (deprecated).
- Gemini `mcpServers` is top-level; `mcp.allowed`/`mcp.excluded` is
  separate.
- Env deny-list includes all of: *KEY*, *TOKEN*, *SECRET*, *PASSWORD*,
  *CREDENTIAL*, LD_PRELOAD, LD_LIBRARY_PATH, DYLD_INSERT_LIBRARIES,
  DYLD_LIBRARY_PATH, NODE_OPTIONS, PYTHONSTARTUP, PYTHONPATH, DEBUG,
  RUBYOPT, PERL5OPT, GEM_PATH.

Add the six verification tests listed in IMPLEMENTATION_PLAN_FROM_ADVICE
Phase G → Verification section as real cargo tests in
epistemos-core/tests/manifest/.
```

**Verification:**
```bash
# In a scratch vault directory:
cargo test --manifest-path epistemos-core/Cargo.toml --test manifest
# Assert: all 6 anti-drift checks pass.

# Deny-list integration test (the single most valuable CI unit per
# research §9.6):
cd /tmp/scratch-vault && claude -p "Read ./.env" 2>&1 | grep -q "denied"
cd /tmp/scratch-vault && codex exec "Read ./.env" 2>&1 | grep -q "denied"
cd /tmp/scratch-vault && gemini -p "Read ./.env" 2>&1 | grep -q "denied"
```

### C.9 Phases E / F / H — stubs (activate when predecessors land)

These phases are further out in the execution order. Full prompts are kept brief here; expand them when the predecessor phases are confirmed green.

**Phase E (Schema-driven generative UI palette) — activate after Phase I.** Prompt stub:
```
Goal: implement A2UI-v0.9-compatible EpisWidgetSpec schema in Rust +
SwiftUI component palette (~25 components per §5 Phase E and Appendix
A.5). Use @autoview (Perplexity paper) to generate initial boilerplate
from the TypeScript-style props types, then polish and lock into the
design system. Validation gate: schemars::JsonSchema on Rust side;
fallback renderer shows raw LLM output as Markdown with "regenerate"
button on schema validation failure. GRDB cache keyed by
(prompt_hash, surface_json) with 90%+ expected hit rate.

Streaming: AsyncSequence<A2UIEvent> over UniFFI — ComponentAdded,
ComponentPatched, RenderingBegan, RenderingComplete. Skeleton
shimmer for referenced-but-not-yet-delivered child nodes.

Do NOT: ship a path that compiles arbitrary SwiftUI at runtime
(permanently prohibited per §1.5). MCP Apps iframe is the escape
hatch for <5% novel layouts (Phase F).
```

**Phase F (MCP dual role) — activate after Phase G (manifest compiler).** Prompt stub:
```
Goal: expose Epistemos as MCP server (HTTP/SSE preferred, stdio for
local trusted) so Claude Desktop / Cursor / Zed / ChatGPT Desktop can
drive Epistemos's vault; consume user's existing MCP configs from
~/.claude/mcp.json and ~/.codex/config.toml. Expose the 12-tool
surface from Appendix A.1. Implement MCP Apps SEP-1865 iframe escape
hatch for non-palette UI (WKWebView with navigationDelegate locked
down, audited postMessage channel).

Integration deny-list test is the single most valuable CI unit: launch
each CLI in a scratch vault; attempt Read(./.env),
Write(./.epistemos/db.sqlite), Bash(curl evil.com); assert all three
blocked across Claude, Codex, Gemini CLIs.
```

**Phase H (Optional Docker sandbox) — activate only when a user requests it or a threat model demands it.** Prompt stub:
```
Goal: add optional Docker sandbox gated behind user toggle (default OFF)
for the Bash tool execution path only. Use bollard + readonly_rootfs
+ --network=none (after init phase) + ephemeral per-session containers
per Gemini paper §Core Infrastructure. Command interception via
portable-pty + rexpect for destructive patterns before exec. Host
secrets NEVER enter the container.

NOT for other tools; Read/Edit/Write still run on host. NOT for MAS
edition (compile-flag out via --features mas-sandbox).
```

### C.10 Running Claude Code against this plan

To hand the plan to Claude Code directly:

```bash
cd /Users/jojo/Downloads/Epistemos
claude -p "Read docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md and
docs/CLI_CONFIG_COMPILATION_RESEARCH.md. Execute Phase 0 per
Appendix C.0. Stop when done."
```

After Phase 0 lands a clean audit, run Phase A, B, C, then G — in that order — using the corresponding Appendix C prompt. Commit between each phase.

**Do not batch phases.** Each phase is scoped to a single PR and a single `claude -p` session for a reason: smaller diffs = safer review + easier rollback if drift appears.

### C.11 If a phase drifts

If Claude Code produces output that violates Appendix B's pinned facts (e.g., puts `mcpServers` in `.claude/settings.json`, or uses `on-failure`, or hardcodes an `mcp.servers.epistemos` TOML key):

1. **Do not ship.** Reject the PR.
2. Update the session prompt in Appendix C with an explicit counter-example pointing to the Appendix B entry that was violated.
3. Re-run the phase.
4. Open a bug in [docs/APP_ISSUES_AUTO_FIX.md](APP_ISSUES_AUTO_FIX.md) with "Drift detected: [which fact] in phase [N]" so the issue is tracked cross-session.

---

**End of implementation plan v1.2 executable build brief.**

---

## Appendix D — New Session Bootstrap Prompt (canonical as of 2026-04-22)

Copy the prompt below verbatim into any new Claude Code / Codex / Claude web / ChatGPT session working on Epistemos. It is intentionally short so a smaller model (Qwen3-4B, Haiku, Gemini Flash) can also execute it. It loads only the docs that matter for the current task.

**Supersession note:** this prompt supersedes [docs/MASTER_SESSION_PROMPT.md](MASTER_SESSION_PROMPT.md) (dated 2026-03-30). MASTER_SESSION_PROMPT remains useful as historical record of what was built before 2026-04-22 (OpenClaw safety work, FFI hardening, MCP bridge, etc.) — consult it only when you need to confirm "was X already built before 2026-04-22?" For all new work, Appendix D + the relevant phase prompt from Appendix C is the canonical entry point.

**Interaction with Appendix C:** Appendix D defines the BASE context load for any session. Appendix C defines PHASE-SPECIFIC extensions. When executing a phase, run Appendix D's prompt first, then append the relevant Appendix C phase prompt. Do not duplicate the always-load files or the drift alarms across the two.

---

```text
# Epistemos session start

You are working on Epistemos — a macOS-native PKM app at
/Users/jojo/Downloads/Epistemos. Stack: Swift 6 SwiftUI + Rust (UniFFI)
+ MLX-Swift + Metal + GRDB. ~137K Swift + ~94K Rust. Developer ID
distribution only (no Mac App Store). Do the context load before any
work.

## 1. Always load (small, always relevant)

1. Read CLAUDE.md — project rules + non-negotiable constraints.
2. Read ~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md
   — user profile, hardware, pinned feedback. Follow each pointed-to file
   only if the task is in that memory's scope.
3. Read docs/AGENT_PROGRESS.md — what's done, what's next. Treat this as
   ground truth over planning docs.

## 2. Task-scoped (read only what applies)

- Agent runtime / routing / providers / settings work →
  docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §4-5 + Appendix B (anti-drift)
  + Appendix C (executable build brief for your phase).
- CLI config compilation (CLAUDE.md / .claude / .codex / .gemini / .mcp.json) →
  docs/CLI_CONFIG_COMPILATION_RESEARCH.md (authoritative spec).
- Chat/Agent mode UX fusion →
  docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §4.3a + Phase I.
- Code editor / syntax / BoltFFI / graph → docs/PLAN_V2.md §22-25.
- Sprint-specific work → docs/sprint-sessions/<current-sprint>.md.

## 3. Vendor docs (ONLY if §1+§2 don't answer a specific question)

- Claude Code: https://code.claude.com/docs/en/{settings,memory,hooks,skills,sandboxing}
- Codex CLI:  https://developers.openai.com/codex/{config-reference,mcp,concepts/sandboxing,cli/reference}
- Gemini CLI: https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html
- MCP spec:   https://modelcontextprotocol.io + 2026-01-26 MCP Apps SEP-1865
- MLX-Swift:  https://github.com/ml-explore/mlx-swift (README + CHANGELOG only)

## 4. Top-5 drift alarms — violating ANY of these blocks the PR

1. mcpServers goes in .mcp.json ONLY — NEVER in .claude/settings.json
   (silently ignored, Issue #24477).
2. Codex MCP = [mcp_servers.<id>] — NEVER [mcp.servers.<id>]
   (silent-fail bug openai/codex#3441).
3. Codex approval_policy: on-request (interactive) or never (CI).
   "on-failure" is DEPRECATED.
4. Gemini: mcpServers is top-level object map; mcp.{allowed,excluded}
   is a separate key.
5. No App Sandbox. Developer ID + Hardened Runtime. Never add
   com.apple.security.app-sandbox to entitlements.

## 5. Pinned workflow rules

- COMMIT after each feature/fix — never batch (user has lost work to this).
  Use a HEREDOC commit message with the Co-Authored-By: Claude line.
- Minimal targeted fixes — not refactors. Don't widen scope casually.
- xcodegen for .xcodeproj changes — never edit .xcodeproj directly.
- Swift 6 + Rust + UniFFI + MLX-Swift is the stack. No React/Tauri/Python
  in the runtime path. Hermes subprocess is ORCHESTRATION, not inference.
- Stream every token (no buffering). Preserve thinking blocks + signatures
  when stop_reason == "tool_use". Honor stop_reason for termination.
- API keys in macOS Keychain. Never UserDefaults, never plaintext config.
- DispatchQueue.main.async in UniFFI callbacks, never .sync (deadlock).

## 6. Before reporting done

1. Run the phase's verification command (Appendix C) or the generic:
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   cargo test --manifest-path agent_core/Cargo.toml
2. If UI changes: launch the app and dogfood the feature once in the
   browser/native UI. Type checks are not feature checks.
3. Commit with Co-Authored-By line.
4. If a phase advanced: update docs/AGENT_PROGRESS.md with ✅ + today's date.
5. Report in ≤200 words: what changed, what verified, what blocks the next phase.

Now tell me: what are you working on today? Load §1 + applicable §2 docs
before answering.
```

---

**End of implementation plan v1.3. Total scope: 10 phases (0, A–H + I), seven concrete verification gates, two cited research docs, one anti-drift card, one executable build brief, one bootstrap prompt. Every piece of value from the 4 model papers + 2 syntheses + 1 CLI config research + 1 UX fusion advice is now captured in this document or its authoritative companion.**
