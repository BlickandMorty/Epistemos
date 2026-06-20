# SS-L — OpenAI/Cursor skills + PROVIDER AGENTS on chat (2026-06-19)

Read-only research (subagent), code-grounded + web + claude-api reference. Feeds SETTINGS_SIMPLIFICATION_HUB +
the OMNIBUS ledger item (OpenAI/Cursor skills; OpenAI/Google/Claude agents on chat) **and the owner's
2026-06-19 PROVIDER-AGENT-DEPTH question** ("at what level is an agent created — file structure? installable
skill? — it failed before; harden it").

## ‼️ THE OWNER'S "AT WHAT LEVEL IS AN AGENT CREATED" ANSWER
**An agent is NOT a new file-structure, NOT an installable skill, NOT a separate "agent type."** In Epistemos
an agent = the **cell `(operating-mode = .agent) × (provider)`** running on the **agent loop that already
exists**: `agent_core/src/agent_loop.rs:151 run_agent_loop(provider: Arc<dyn AgentProvider>)`, with
Claude/Gemini/OpenAI each implementing `AgentProvider` (`providers/{claude,gemini,openai}.rs`). So "an OpenAI
agent / Google agent / Claude agent on chat" = **selecting that provider as the agent backend** — not building
a new agent. **The piece is ~80% already built.** Why it "failed before": the failure was never a missing
agent-creation level — it was (a) the provider not promoted to **agent-tier** (`supportsAgentTier`), (b) the
provider's **hosted tools not wired**, and/or (c) **no agent-identity label** so the user couldn't tell they'd
selected an agent. Hardening = fix those three + honest gating, NOT invent an agent-definition format.

The four candidate "levels" an agent could live at, and which Epistemos uses:
| Level | What it is | Epistemos? |
|---|---|---|
| (a) file-structure / AGENTS.md blueprint | a config defining identity/instructions | `AgentBlueprint.swift` IS this — the **identity/persona** layer, NOT the capability |
| (b) installable SKILL/pack | a skill that adds tools | NO — skills add *tools*, they don't make an agent |
| (c) provider hosted runtime (OpenAI Agents-SDK / Assistants, Anthropic Managed Agents, Google ADK) | a *cloud* hosted agent loop + container | **REJECT as default** — contradicts no-sidecar; Epistemos hosts its OWN loop |
| (d) in-process agent loop parameterized by provider | the ReAct loop + tool exec, provider swapped in | **THIS** — `run_agent_loop` + provider trait |
**Design rule: an Epistemos provider-agent = (d) the in-process loop + (a) an AgentBlueprint for identity,
NEVER (c) a hosted foreign runtime.** Harden by wiring per-provider hosted *tools* into the request body, not
by importing a foreign agent runtime.

## Already REAL (in code today)
- Provider-backed cloud agent loop: `run_agent_loop:151`; ReAct + tool exec + compaction (`:300`) + streaming.
- **Cloud-only gate enforced in Rust:** `agent_loop.rs:166` rejects `ProviderRuntime::Local` →
  `LocalProviderNotAllowed` (local models can't fake agent capability — CLAUDE.md non-negotiable). **This is
  the isolation seam.**
- Chat surface already dispatches by provider: `ChatCoordinator.swift:464` — mode `.agent` + `.cloud(provider)`
  → `runCommandCenterRustAgentPath` (`:476`); local → `runCommandCenterLocalAgentPath` (`:467`); Apple
  Intelligence explicitly refused for agent (`:494`).
- Agent-tier gate per provider: `InferenceState.swift:1347 supportsAgentTier` → **OpenAI + Anthropic = true;
  Google/Z.AI/Kimi/MiniMax/DeepSeek = false.**
- OpenAI: Responses API (`openai.rs:28`), Codex/ChatGPT-account OAuth (`:29/:39/:662` — notable, already wired),
  function-calling (`tool_schema_to_responses_json :124`). Claude: server-side `web_search_20250305`
  (`claude.rs:252`) + computer_use (`:260`). Gemini: googleSearch grounding (`gemini.rs:128`) + computer_use.
- Shared brain picker (`ChatBrainPickerMenu.swift` + `ChatInputBar.swift`) already exposes mode × provider.

## What's genuinely NEW (all small wiring, no new infra)
1. **[S ½-1d, highest leverage] Wire OpenAI hosted `web_search`** through the SAME `config.enable_web_search`
   seam Claude/Gemini use. Today `openai.rs:460 supports_web_search:false`; the Responses `tools` array
   (`build_openai_responses_body :125`) just doesn't add `{"type":"web_search"}` the way `claude.rs:251-260` /
   `gemini.rs:128-134` do.
2. **[S ~1d] Promote Google to agent-tier** — flip `supportsAgentTier` for `.google` (`InferenceState.swift
   :1350`); Gemini already implements the provider trait + computer_use + grounding. (ADK is Python — adopt
   *patterns*/MCP, not the lib.) Note: the 2026-06-19 `cloudChatToolsAllProvidersArmed` flag (`:1375`) already
   gave Google chat-turn tools; agent-tier is the remaining promotion.
3. **[S ~1d] Agent-identity label on the picker** — when mode=`.agent`, surface the provider AS the agent
   ("OpenAI Agent · gpt-5.x") and honestly grey out providers where `supportsAgentTier==false` (like AFM is
   refused at `ChatCoordinator.swift:494`). **This is the fix for "the user couldn't tell it was an agent."**
4. **[S ½d] Cursor `.mdc` → SKILL.md import shim** — reuse SS-I's frontmatter shim: `description`→skill (routes
   via `parse_skill skill_router.rs:189`); `alwaysApply`→AGENTS.md/system-prompt config (not a skill);
   `globs`→Cursor-specific, drop or Epistemos extension. Third-party rule packs still clear ProvenanceGate.
5. **[M ~2-3d] OpenAI `file_search`/`code_interpreter` as hosted tools** — Pro + sandbox-gated, **never local**
   (code_interpreter contradicts no-sidecar; exec belongs to the Osaurus VM, not an in-process OpenAI sandbox).

## Skills reality (honest)
**Only Anthropic is a true SKILL.md source** (SS-I). **OpenAI has NO SKILL.md catalog** — its "skills/
superpowers" = Responses **hosted tools** (web_search/file_search/code_interpreter) + Agents-SDK *patterns*
(Epistemos already has the in-process equivalent: `agent_loop` ReAct + `delegate_task.rs` sub-agents — do NOT
import the SDK, no Swift SDK + no-sidecar). **Cursor has NO separate skill format** — "superpowers" = Cursor
Rules (`.cursor/rules/*.mdc`), which is config; a rule with a `description`+body converts to a SKILL.md, an
`alwaysApply`/`globs` rule is config not a skill.

## Gating (preserve)
Cloud agent = **Pro + keys/OAuth** (per-provider `apiKeyKeychainKey`/`oauthKeychainKey` `InferenceState
.swift:1302-1324`, Keychain never UserDefaults). Local = never agent-tier (Rust-enforced `:166`). OpenAI
`code_interpreter`/computer_use = extra gate (no-sidecar; exec = Osaurus VM). MAS: remote skill install + stdio
MCP = Pro; local-path import + URL MCP = MAS-eligible (SS-I). **REJECT** Anthropic Managed Agents / OpenAI
Assistants hosted-container as default — Epistemos hosts its own loop; engine-isolation preserved (each
provider a separate `AgentProvider` behind `routing.rs`, no shared cross-provider logic, local lane stays
Swift `LocalAgentLoop`, the `LocalProviderNotAllowed` wall is the seam).

## Real-vs-aspirational
REAL: the provider-backed loop, OpenAI Responses+Codex-auth+function-calling, Claude/Gemini server-side
web_search+computer_use, agent-tier gate, chat-surface agent dispatch, shared picker, SKILL.md quarantine path,
MCP stdio+URL. NEW-SMALL: OpenAI web_search wiring (1), Google agent-tier (2), agent label (3), `.mdc` shim (4).
NEW-TEMPLATED: OpenAI file_search/code_interpreter hosted+Pro+sandbox (5). DEFER: OpenAPI→ToolSchema importer;
**REJECT**: hosted Managed-Agent containers, importing Agents-SDK/ADK as libs, treating Cursor as a SKILL.md
source, any in-process provider code-exec.

Key files: `agent_core/src/agent_loop.rs` (`run_agent_loop:151`, gate `:166`) · `providers/openai.rs`
(Responses `:28`, Codex `:29/:39/:662`, web_search gap `:460`, computer_use `:462`, body `:124`) ·
`providers/claude.rs` (`:252/:260`) · `providers/gemini.rs` (`:82/:128`) · `State/InferenceState.swift`
(`CloudModelProvider:1281`, `supportsAgentTier:1347/:1350`, `cloudChatToolsAllProvidersArmed:1375`,
`EpistemosOperatingMode:2776`, keychain `:1302-1324`) · `App/ChatCoordinator.swift` (dispatch `:464-546`, AFM
refusal `:494`) · `Views/Chat/ChatBrainPickerMenu.swift` + `ChatInputBar.swift` (picker) · `AgentBlueprint.swift`
(identity layer) · `agent_core/src/tools/skills.rs` (SKILL.md path) · SS-I doc.
