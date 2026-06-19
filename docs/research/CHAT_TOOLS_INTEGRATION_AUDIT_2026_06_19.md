# CHAT ↔ SKILLS/TOOLS end-to-end audit (S4, 2026-06-19)

Read-only research (subagent). Feeds DEEP_PLAN_AUDIT_HUB + the TOOLS/SKILLS ledger repair.

## BOTTOM LINE (the real root cause — differs from the marshaling assumption)
The arg-marshaling bug (`notes array required`) was real but is **now defensively repaired**
(`normalize_tool_input` + `extract_note_paths`) and is **NOT** why tools/skills look broken
in-app. The actual breakage is **upstream of the tool code: the chat never ENTERS a tool
loop for the owner's common model selections, so no tool calls fire, so the UI boxes (sourced
only from tool events) never render.** Tool *implementations* are mostly sound; the
wiring/gating and the skills *data plumbing* are the failures. All shipped auto-route fixes
are **flag-gated OFF**, so none are live.

## The breaks (grounded)
1. **LOCAL Gemma gated out of the tool loop.** `canRunLocalAgentLoop == canActAsAgent`, and
   Gemma 3/4 (incl GGUF), Mistral/Devstral → `canActAsAgent=false` (`InferenceState.swift:458-461`).
   `PipelineService.shouldUseToolLoop` (`:316`) only loops a Gemma pick if a fitting backup Qwen
   exists (`:342-347`); on a memory-constrained machine → no loop → plain toolless stream → no
   tools, no boxes, "no vault retrieval." **This is the owner's reported case.**
2. **Non-OpenAI/Anthropic cloud never gets tools for plain chat.** `ChatCoordinator.runCommandCenterRustAgentPath`
   (`:650`) is reached only if `cloudProvider.supportsAgentTier`, true ONLY for OpenAI/Anthropic
   (`InferenceState.swift:1347-1352`). Plain chat on Google/Z.AI/Kimi/MiniMax/DeepSeek falls to the
   toolless `else` (`:555`) despite the prompt advertising vault access. **"Cloud should automatically
   know" fails for every non-OpenAI/Anthropic provider.**
3. **Auto-route machinery is OFF.** `EPISTEMOS_AUTO_TOOL_ROUTE_V0` is never set to "1" anywhere
   (`PipelineService.swift:396-398`); with it OFF the detector is skipped (falls through to "loop-capable
   model always loops"), so the real gate is `canRunLocalAgentLoop` (break #1).
4. **UI boxes wire is INTACT** — `InlineToolTranscriptSegment` (`AssistantInlineTranscriptView.swift:401`,
   "Eidos" `:488`) + `ToolExecutionPreviewList` (`MessageBubble.swift:347`) render from `.toolUse`/`.toolResult`
   blocks; every emission site connected. **Boxes are gone only because no tool calls are emitted** — not a cut wire.
   (`GenUICardPresenter`/`GenUIDispatcher` are a separate subsystem; not the chat tool boxes.)

## Skills — 5 disjoint subsystems, 3 on-disk locations that never reconcile
- Swift KnowledgeFusion `SkillManifest`→`LocalAgentPromptBuilder` = the ONLY authored-skill→model path that fires (PASS).
- `SkillRouter` (TF-IDF, `<vault>/skills/`) + legacy `skills` CRUD tool (`~/.epistemos/skills`) = wired but **DATA-EMPTY** (no populated dir).
- `skills_list`/`skill_view`/`skill_manage` = **NOT registered in MAS build** (`#[cfg(pro-build)]` only).
- `skill_manage` v2 install = **FAIL** (schema omits `allow_remote_skill_install` + `additionalProperties:false` → installs unreachable).
- `EditorSkill` (7 Swift skills) = **FAIL** (UI selects, `.systemPrompt`/`.toolSubset` read by nothing).
- **CRITICAL:** the 7 authored `SKILL.md` files live in `.agents/skills/` — a path **NO loader reads** (`default_skills_dir`→`~/.epistemos/skills`; SkillRouter→`<vault>/skills/`). A skill the tool creates is invisible to router + Swift prompt.

## Tool schema↔impl drift sweep (latent — `ToolHandler.execute` has no compiler link to `*_schema()`)
PASS (key-verified): research_digest (now tolerant), filesystem/file_ops/workspace_search/find_symbol/think/vault*/graph_neighbors/contradiction_check/scoreevidence/session_search/neural_recall, create/edit/note_template/linker/citation/markdown_table.
**DRIFT/FAIL (latent — schema too narrow, impl reads undeclared keys; harmless today because the schema gate doesn't set `additionalProperties:false`, but breaks if promoted):** `vault_recall` reads undeclared `tags`; `eidos_query` reads undeclared `note_filter`; `collectsnippet`/`savecitation` read undeclared snake_case aliases.

## PRUNE list (dead/duplicate; safety noted)
`ConfidenceRouter.swift` (self-documented "never instantiated in production"; live routing = `TriageService.InferencePolicyEngine`) — safe; `skills_context()` — no caller; `SkillDiscovery::observe` + `self_evolution::propose_repeated_success_skill` — orphaned (wire or prune — decision needed); `format::SkillManifest` (skill.v1) — no producer/consumer; `epistemos-core::skill_engine/*` — unwired; `EditorSkill` prompt fields — read by nothing (wire or remove). Duplicate skill verb-sets (legacy `skills` vs `skill_manage`) — consolidate (don't blind-remove; CRUD is the only one in MAS). `.agents/skills/*.SKILL.md` vs loader paths — FIX the path, don't delete the authored files.

## Highest-leverage fixes (ordered) — the REAL repair
1. **Cloud auto-tool-use for plain chat (biggest visible win, lowest risk):** attach chatLite/chatPro tools for Fast/Thinking/Pro on ALL providers, not only `supportsAgentTier` (OpenAI/Anthropic) — or honestly gate per provider. Fix `ChatCoordinator.swift:503-555` / `InferenceState.swift:1347`. Tools already exist + execute.
2. **Local Gemma tool path:** land the Swift live-wiring of the already-shipped GGUF grammar-constrained tool-call FFI (`schemaGgufToolDispatchJson`) and allow `canActAsAgent=true` for the GGUF Gemma lane; until then surface honestly that Gemma chat is toolless instead of silently dropping the loop (`PipelineService.swift:342`).
3. **Skills data plumbing:** reconcile the 3 stores; point the loader at `.agents/skills/` (or migrate to `<vault>/skills/`) so the 7 authored skills load; register `skills_list`/`skill_view`/`skill_manage` in MAS or accept CRUD-only honestly.
4. **Close the 4 schema↔impl drifts** (add the read keys to declared schemas) — cheap, prevents future schema-gate breakage.
5. **Fix `skill_manage` v2** (expose `allow_remote_skill_install` / relax `additionalProperties:false`).
6. **Wire or prune `EditorSkill`** (UI presents capability that never reaches a model — honesty defect).

**One-liner for the owner:** the tool/skill code is largely correct; chats don't REACH it. Local Gemma is gated out of the tool loop, and non-OpenAI/Anthropic cloud never gets tools attached for plain chat — so no tool calls fire and the UI boxes have nothing to show. The marshaling fix was real but not the cause.

Key files: `Epistemos/Engine/PipelineService.swift` · `Epistemos/State/InferenceState.swift` · `Epistemos/App/ChatCoordinator.swift` · `Epistemos/LocalAgent/LocalToolGrammar.swift` · `agent_core/src/tools/{registry,note_tools,knowledge}.rs` · `agent_core/src/skill_router.rs` · `agent_core/src/tools/skills.rs` · `agent_core/src/tools_v2/v2_catalog/skills_manage.rs` · `Epistemos/Views/.../{AssistantInlineTranscriptView,MessageBubble}.swift` · `.agents/skills/*.SKILL.md`.
