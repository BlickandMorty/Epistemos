---
id: B9AC101E-11C2-4F9C-B79E-07462A3B1A00
title: SS-H — Cross-engine native tool/skill SHARING (2026-06-19)
---

# SS-H — Cross-engine native tool/skill SHARING (2026-06-19)

Read-only research (subagent), code-grounded. Feeds SETTINGS_SIMPLIFICATION_HUB + the SKILLS/TOOLS/SUPERPOWERS-  
WORK-EVERYWHERE ledger item. Owner's demand: *"the loop, skills, superpowers — all working in local AND cloud*  
*models in chat; and Osaurus/Goose/Open Code/OpenClaw have access to the app's native tools + skills + the*  
*Claude/Anthropic + Vercel + Google skills."*

> [!INFO]
> **✅ VERIFIED-CODE UPDATE 2026-06-20 (loop) — the KEYSTONE (plan #1) and AUTO-ROUTE**  
> **(plan #4) are already LANDED + TESTED; this doc's "gap" framing for them is stale.**  
> `PipelineService.chatLiteSkillsCatalogBlock(operatingMode:)` (`:415`) builds a real  
> ChatLite tool/skill catalog and is appended to the DIRECT (tool-loop-less) system  
> prompt (`:1140-1145`) — so a small tool-less Gemma now SEES the skills (plan #1,  
> the keystone). `shouldUseToolLoop` PART 2 (`:388-401`) routes a non-agent model's  
> tool-needing queries to a *fitting* agent-capable model (`fittingLocalAgentTextModelID`,  
> no OOM swap) instead of degrading to a tool-less stream (plan #4), gated by  
> `EPISTEMOS_AUTO_TOOL_ROUTE_V0` (ON by default). Witnessed by  
> `EpistemosTests/SkillsKeystoneTests.swift` (+ `AutoToolRouteWiringTests`,  
> `SkillInjectionTests`). **Remaining SS-H = the cloned-engine binding only:** plan #2  
> (bind Osaurus `ActOsaurusBridge` to the registry), #3 (Goose/Work), #5 (omega-mcp  
> dedupe), #6 (OpenClaw) — those engines stay honest-but-inert, and the higher-value  
> "skills work in local AND cloud CHAT" half is done. The plan below is the original  
> research, kept for provenance.

## Headline

**The shared capability registry is REAL and already serves BOTH local and cloud chat** — one `ToolRegistry`  
type with a `ToolTier` ladder, bound per-engine via the `ToolTierBridge` → `list_tools_for_tier` /  
`execute_tool_call` FFI seam; skills (incl. imported Anthropic/Vercel/Google SKILL.md files) flow through the  
same registry from ONE on-disk `~/.epistemos/skills/` dir. **The gaps are two:** (a) local chat silently drops  
to a tool-less/skill-less stream whenever the selected local model isn't `canRunLocalAgentLoop` and no  
agent-capable model fits memory (the "chats never enter the tool loop" keystone), and (b) the cloned engines  
(Osaurus/Goose/OpenClaw) have honest but **INERT** chat seams that never bind the native registry.

## Already REAL

- **One registry, tier ladder.** `ToolRegistry` + `ToolTier{None<ChatLite<ChatPro<Agent<Full}` (`registry.rs :241-253`); gate `is_tool_permitted` (`:699-709`) enforced in `get_definitions()` (`:735-761`) AND `execute()`  
(`:814-816`); all tools register via `register_default_tools()` (`:923-1023`); chat-safe ones downgraded to  
ChatLite/ChatPro in `apply_tier_overrides()` (`:1100-1177`).
- **"Act ⊇ Chat by tier; each engine binds its OWN instance; no cross-call."** Every site builds a FRESH  
instance via `ToolRegistry::with_tier(vault,bash,root,tier)` — agent FFI `bridge.rs:978`, chat-tier FFI  
`:3155/:3219`, command center `command_center.rs:423`, OpenAI provider `providers/openai.rs:1189`. No global  
mutable registry — engines share **schema+handler-logic by re-instantiation**, not a shared object. (This IS  
the engine-isolation rule: shared registry-by-value, per-engine loop logic.)
- **Local AND cloud chat both get tools today.** Cloud: agent loop takes `tool_registry: Arc<ToolRegistry>`  
(`agent_loop.rs:155`). Local: `ToolTierBridge` (`ToolTierBridge.swift:374`) calls `listToolsForTier`  
(`bridge.rs:3145`) for schemas + routes execution through `executeToolCall`→`execute_tool_call` (`:3208`);  
`PipelineService.swift:603-605` (tool list) + `:674-709` (executor + `loop.run`) wire it into `LocalAgentLoop`.  
Mode→tier: `ChatToolTier.from(operatingMode:)` fast/thinking→chatLite, pro→chatPro, agent→agent  
(`ToolTierBridge.swift:361-368`).
- **Skills reach the chat tiers.** `skills_list`/`skill_view`/`skill_manage` register `registry.rs:1662-1696`  
(promoted to MAS 2026-06-19), `skills_list`/`skill_view` downgraded to ChatLite (`:1133-1134`) so even  
Fast-mode local models discover skills. ONE dir: `default_skills_dir()` = `EPISTEMOS_SKILLS_DIR` or  
`~/.epistemos/skills/` (`tools/skills.rs:460-466`). SKILL.md + TF-IDF router `skill_router.rs:159-189`;  
imported Anthropic/Vercel/Google skills = SKILL.md files dropped in that dir, directly portable.
- **Isolation doctrine in practice:** `LocalProviderNotAllowed` wall (`agent_loop.rs:166-171`); separate  
`AgentProvider` impls; registry shared-by-value, loop logic per-engine.

## The gaps

- **KEYSTONE — local chat falls OUT of the tool loop.** `shouldUseToolLoop` returns `false` when the model's  
`canRunLocalAgentLoop==false` AND `fittingLocalAgentTextModelID==nil` (`PipelineService.swift:342-346, 364-388`). `canRunLocalAgentLoop = canActAsAgent && LocalToolGrammar.supportsLocalAgentLoop`  
(`InferenceState.swift:471-473`). So a small GGUF/Gemma with no agent-capable backup fitting memory →  
**tool-less, skill-less direct stream.** The seam exists; the routing gate closes it for the smallest models.
- **Cloned engines DON'T bind the registry.** Osaurus (`ActOsaurusBridge.swift:12-32`) = OpenAI-compatible  
`runTurn` chat seam, default `InertActOsaurusBridge` (`:63-70`) — never calls `listToolsForTier`/  
`execute_tool_call`, so an Osaurus turn has NO native tools/skills. Goose/Work (`WorkBackend.swift:30-39`) =  
`runWorkSession(objective:workspace:)` protocol, `NoopWorkBackend` default, NO tool seam at all. OpenClaw =  
doc-only (`SKILL_PORTING_GUIDE.md`), not wired.
- **omega-mcp has a SEPARATE registry (true duplicate).** `omega-mcp/src/registry.rs:23` defines its own  
`ToolRegistry` over `ToolDefinition` (`:5-6`), unrelated to agent_core's — the MCP peer-bridge path does NOT  
draw from the native tier registry. The one place "per-engine duplicate" is literally true.

## How sharing should work (shared registry + shared memory, NEVER shared logic)

Each cloned engine connects via exactly two seams already present:

1. **Shared CAPABILITY registry** — call existing FFI `list_tools_for_tier(vault,tier)` (`bridge.rs:3145`) for  
 schemas + `execute_tool_call(vault,tier,name,json)` (`:3208`) for execution, exactly as `ToolTierBridge`  
 does (`ToolTierBridge.swift:405-487`). No engine re-implements a tool; each gets its own tier-bound instance.
2. **Shared MEMORY** — same `vaultPath` + `~/.epistemos/skills/` dir → every engine sees the same skills/notes,  
 no shared loop logic.  
Smallest honest wiring: hand each engine a `ToolTierBridge` (tier from its honest capability gate); its  
turn-driver invokes `bridge.toolExecutor()` between generations — Osaurus/Goose drive their own loop, but tool  
*resolution* + skill *discovery* come from the one Rust registry.

## Honest gating (preserve)

- **MAS vs Pro:** Pro-only tools (action.bash/terminal/scheduling/custom_tools/Apple apps/iMessage/computer-use/  
delegate_task/mixture_of_minds) compile out under `#[cfg(feature="pro-build")]` (`registry.rs:933-1016`); MAS  
runtime preflight hard-denies forbidden/destructive/unscoped-mutating tools (`:142-175`); Swift mirror  
`coreAppStoreAllowedToolNames` (`ToolTierBridge.swift:194-235`).
- **local-never-agent-tier:** `LocalProviderNotAllowed` (`agent_loop.rs:166`) keeps local out of the cloud agent  
loop; local chat tools cap at ChatLite/ChatPro. Any Osaurus/Goose wiring inherits this — bind at honest tier,  
NEVER Agent/Full for a local runtime.

## Ordered plan (smallest honest wiring first)

1. **[S] Close the keystone for skills-only** — always inject the ChatLite skills catalog (`skills_list`) into  
 the local-chat system prompt even when `shouldUseToolLoop==false`, so a small Gemma at least SEES skills.  
 (`PipelineService.swift:316-388`.)
2. **[S] Bind Osaurus to the registry** — give `ActOsaurusBridge.runTurn` a `ToolTierBridge` (chatLite/chatPro)
  - run `toolExecutor()` between turns. (`ActOsaurusBridge.swift:27-31`.)
3. **[M] Bind Goose/Work to the registry** — add a tool seam to `WorkBackend.runWorkSession` backed by  
 `ToolTierBridge`; keep `NoopWorkBackend` honest. (`WorkBackend.swift:30-39`.)
4. **[M] Auto-route fallback when model can't loop** — when `canRunLocalAgentLoop==false`, route tool-needing  
 queries to the *fitting* agent-capable backup (half-wired via `fittingLocalAgentTextModelID`,  
 `PipelineService.swift:346`) instead of degrading to a tool-less stream.
5. **[L] Unify omega-mcp onto the native registry** (or bridge it) so the MCP peer path draws from  
 `agent_core::tools::registry`. (`omega-mcp/src/registry.rs`, `dispatcher.rs:25`.)
6. **[L] OpenClaw seam** — build the OpenClaw engine bridge against the same FFI (doc-only today).

## Unverified

OpenClaw is doc-only (no wired engine). Whether imported Anthropic/Vercel/Google skills are actually *present*
in `~/.epistemos/skills/` at runtime is a deployment fact, not confirmable from source.

Key files: `agent_core/src/tools/registry.rs` (tier `:241-253`, gate `:699-709`, `register_default_tools :923-1023`, overrides `:1100-1177`, skills `:1645-1697`) · `agent_core/src/agent_loop.rs` (wall `:166-171`,
sig `:151-159`) · `agent_core/src/bridge.rs` (agent build `:978`, `list_tools_for_tier:3145`,
`execute_tool_call:3208`) · `Bridge/ToolTierBridge.swift` (seam `:374-487`, tier map `:361-368`, MAS allowlist
`:194-235`) · `Engine/PipelineService.swift` (keystone `shouldUseToolLoop:316-388`, wiring `:603-605/:674-709`)
· `State/InferenceState.swift` (`canRunLocalAgentLoop:471-473`) · `tools/skills.rs` (`default_skills_dir :460-466`) · `skill_router.rs` (`:159-189`) · `ActOsaurus/ActOsaurusBridge.swift` (inert `:12-70`) ·
`Work/WorkBackend.swift` (`:30-39`) · `omega-mcp/src/registry.rs` (duplicate `:23-34`) · `SKILL_PORTING_GUIDE.md`.