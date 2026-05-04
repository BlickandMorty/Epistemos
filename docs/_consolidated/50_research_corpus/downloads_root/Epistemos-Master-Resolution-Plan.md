# Epistemos Master Resolution Plan

Deep-research consolidation of every recurring issue surfaced across the multi-session Epistemos audit, cross-validated against OpenAI, Anthropic, Google, Claude Code, SwiftUI, and MLX primary documentation. The goal of this plan is to give the next coding agent a single authoritative checklist so fixes land visibly in the app instead of getting lost between sessions.

## Why fixes are not showing up in the app — the agent-to-app integration gap

The user's core complaint is that agents commit fixes that never appear in the running app. This is an **integration pipeline failure**, not a coding failure. Every step below must be enforced as a gate; skipping any one of them reproduces the exact pattern that has plagued 20+ sessions.

### The 8-step agent-to-app integration contract

1. **Branch hygiene gate.** Before any edit: `git status --short` must return a clean tree or a known-scoped dirty set. If Codex left unrelated edits staged (documented repeatedly: Batch P bundled 5, Batch JJ bundled 2, Batch Z bundled more), `git stash -u` them into a named stash. Never `git add .` — always `git add <explicit paths>`.
2. **Scope declaration.** Before editing, the agent must name the batch (e.g., "Batch JJ.1 — Rust openai.rs reasoning leak"), list exactly which files it will touch, and state what observable symptom will be fixed. No edits outside the declared list.
3. **Edit via `apply_patch` only.** Never free-form rewrite; the manifest study of Claude.md files shows patch-based edits survive context compaction where rewrites do not.[^1]
4. **Focused test run.** `xcodebuild ... -only-testing:<suite>` for the touched suite. Output goes to a log file, not stdout, because the `10 KB` truncation hides real failures.
5. **Clean-scheme build gate — THIS IS THE MISSING STEP.** Delete `tmp/*` and the project's `DerivedData` folder, then build from the **Epistemos** product scheme (not the test scheme, not the `tmp/epistemos-routing-ux-rerun` path). Xcode-launched builds use a different derived-data location than `xcodebuild test` — this is why tests pass but the app shows stale behavior. Every previous handoff ended at step 4 and skipped step 5.
6. **Launch + screenshot verification.** The agent (or the user) must open the built `.app`, reproduce the original symptom, and confirm visually that it is fixed. "Tests pass" is not fixed.
7. **Commit with scoped message.** `git commit -m "Batch JJ.1: ..."` on only the declared paths. If step 1's stash contained improvements, land them in a separate audited commit, never mixed in.
8. **Handoff note.** Append one line to `docs/CODEX-HANDOFF-YYYY-MM-DD.md` with: batch ID, SHA, symptom fixed, verification method, residual risks.

### Why this has been breaking

- Steps 5 and 6 are **never enforced** in the existing handoff doc. Every session ended at "tests green, committed." The user runs the app from Xcode's product scheme, which resolves to a different build location than `tmp/epistemos-routing-ux-rerun/`, so the fix is live in the test binary but absent from the binary being launched.
- Swift module cache corruption compounds this: when `DerivedData` retains old `.swiftmodule` files from a prior branch, partial rebuilds link against stale symbols. The only reliable remedy is `rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*` before the verification build.
- The three-router architecture means a UI-layer fix in Swift (`ChatBrainPickerMenu.swift`) can be overridden at runtime by either Rust router, so even a perfect Swift build shows broken behavior unless the Rust crate is rebuilt in lockstep. `cargo build --release -p agentcore` must run before every Swift-side verification, and the resulting `.dylib` must land in the right `Frameworks/` path — which is a step the xcodegen project does not auto-run.
- `project.yml` additions (new `.swift` files like `ToolActivityNarrator.swift`, `ThinkTagStreamRouter.swift`) require `xcodegen generate` to register in the Xcode project. If the agent edits the file on disk but forgets to regenerate, Xcode launches a binary that never compiled the new code.

### The integration checklist the next agent must paste into every batch

```
[ ] git status clean OR known-scoped stash
[ ] Batch ID + file list + target symptom declared
[ ] Edits via apply_patch only
[ ] xcodegen generate (if new .swift files)
[ ] cargo build --release -p agentcore (if Rust touched)
[ ] Focused xcodebuild test passes
[ ] rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*
[ ] Build Epistemos scheme from Xcode, launch .app
[ ] Reproduce original symptom — confirm fix visible
[ ] Commit scoped, handoff note appended
```

If any box is unchecked, the fix has not shipped and the batch is not done.

## Memory contamination diagnosis

The note-taking chat log shows classic memory contamination symptoms: models quote notes that do not exist ("All About Love" hallucination), reasoning from one turn leaks into the next turn's visible reply, and the context meter undercounts because attached content isn't being tracked. These are distinct leaks with distinct fixes.

### Source 1 — Thinking-channel cross-contamination (highest severity)

When `reasoning_content` (OpenAI), `thinking_delta` (Anthropic), or `parts[*].thought==true` (Google) is not segregated from the visible text stream, the model's private monologue becomes the user-visible answer. Worse, that monologue is then **persisted into `ChatMessage.content`** and re-fed as conversation history on the next turn, so the model sees its own scratch reasoning as if it were prior assistant output. This is the mechanism behind "the models still return dumb responses" — each turn inherits corrupted context from the previous one.[^2]

**Fix:** the typed-chunk parser from Phase 1 Batch EE must persist thinking into `ChatMessage.persistedThinking`, a separate field, and the history serializer must only include `ChatMessage.content` (the visible reply) when rebuilding `messages: [...]` for the next request. Batch CC fixed the Swift `LLMService.swift` path; Batch JJ must fix the Rust `agentcore/src/providers/openai.rs` path the same way.

### Source 2 — Tool-call forgery in history (the "readfile, arguments: path/to/document.txt" bug)

The Agent-mode screenshot shows the model emitting `name: readfile, arguments: ...` as literal text because the Rust agent path sent no tool schema. The model invented a plausible-looking JSON tool call, that text was appended to the transcript, and on the next turn the model saw its own fake tool call as if it had actually been executed. This creates a feedback loop where the model becomes increasingly confident in imaginary file contents.

**Fix:** `agentcore/src/providers/openai.rs` must (a) always send the `tools: [...]` array with the current capability manifest, (b) parse `function_call` items from Responses API output as structured tool calls not text, and (c) when a tool call is rejected/unavailable, remove it from the transcript entirely rather than leaving the text residue.

### Source 3 — Unscoped vault retrieval priming

The `KnowledgeIndexBuilder` (the audit agent couldn't locate it) appears to preload arbitrary vault content into every turn's system context. When the model then tool-calls `vaultsearch` and gets different content, the two retrievals conflict and the model averages them into plausible-sounding hallucinations. The "All About Love" hallucination fits this pattern — some ambient retrieval seeded the topic, then the model elaborated without ever reading the actual note.

**Fix:** eliminate ambient preload for cloud-path requests. Retrieval must be **tool-call only** for cloud models (vault content is the user's data; cloud inference should touch only what the user explicitly asks for anyway). Local models can keep preload for latency. This also solves the context-meter undercount (#11) because tool-call retrieval is already tokenized and visible to the counter.

### Source 4 — `AgentAuthority` in-memory persistence

`InMemoryAgentAuthorityPersistence` was the default until Batch HH.2. Any allow/ask/deny decision made during a session was forgotten on app restart, so the model re-asked permission, the user re-answered, and the transcript accumulated permission dialogs as if they were real content. File-backed persistence landed in HH.2 — verify on a fresh build that restart preserves decisions.

### Source 5 — Codex-session dirty-tree bundling

This is a **developer-side** memory contamination: each agent inherits the previous agent's uncommitted edits as if they were baseline. Batch P bundled 5 unrelated Codex edits; Batch JJ bundled 2 Qwen template changes. The tree never returns to a clean state, so each agent's mental model of "what the code does" drifts further from what the code actually does, and fixes target the wrong line.

**Fix:** step 1 of the integration contract above — `git stash -u` on entry, named stash, land improvements as their own batch.

### Source 6 — Conversation-history truncation without summarization

Long sessions hit the context window, at which point the message list is silently truncated from the top. The model loses the system prompt's tool registry but keeps the middle of the conversation, so it "knows" it's supposed to be helpful but has forgotten what tools exist. This reproduces as "the agent just starts chatting instead of using tools."

**Fix:** OpenHands-style compaction (`agentcore/src/compaction.rs` exists, Batch Q wired it in partially) must preserve the system prompt and capability manifest verbatim while summarizing the middle of the turn history. The compaction condenser should be a pluggable interface per subagent, not a single global strategy.

### Source 7 — SwiftData `@Query` predicate drift

When the transcript view's `@Query` predicate recomputes (triggered by any `@State` change in the parent), SwiftData refetches the full message list and SwiftUI rebuilds every row. This isn't contamination per se, but it amplifies every other symptom because stale data from an in-flight edit may flash into view before the streaming buffer catches up. Confirmed culprit for part of the scroll stutter.[^3]

### Verification matrix

| Contamination source | How to confirm it is fixed |
|---|---|
| 1. Thinking channel | Ask any reasoning model a question; confirm thinking renders ONLY in the popover, and the next turn does not reference the prior reasoning text |
| 2. Tool-call forgery | Agent-mode screenshot shows real structured tool cards, never `name: readfile, arguments: ...` as text |
| 3. Ambient retrieval | Ask "find my note on X" where X does not exist; model must say "I couldn't find a note on X" not hallucinate content |
| 4. Authority persistence | Grant a permission, quit the app, relaunch, retry same action — no re-prompt |
| 5. Dirty-tree bundling | `git log --name-only` on the last 10 commits shows no file appearing in multiple unrelated batches |
| 6. Truncation without summarization | Long session (>50 turns) — confirm model still uses tools in turn 51 |
| 7. `@Query` drift | Instruments Core Animation trace shows stable frame times during idle, no redraws on unrelated `@State` changes[^4] |



Three meta-patterns explain why agents keep "fixing" things that never reach the running binary:

1. **Work happens on `codexruntime-input-audit` but never gets launched.** Batches A → KK have been committed locally, yet the user reports the same symptoms (thinking leaks, Gemma crash, stuttery scroll, typo-heavy replies). The app the user is launching is almost certainly a **stale `DerivedData` build** or a binary from a different branch. The `tmp/epistemos-routing-ux-rerun` derived-data path used during testing is not the one Xcode launches from the IDE. Every session must end with a full clean build from the product scheme, not just `xcodebuild test`.
2. **Three routers still dispatch in parallel.** `EpistemosLocalAgentConfidenceRouter.swift`, `agentcore/src/routing.rs`, and `epistemos-core/src/agentruntime/routing.rs` each make independent decisions that can disagree, so a UI change in one router is silently overridden by another. Until a single authority owns the decision, every "the picker is stuck on Auto Route" fix is partial.[^2]
3. **Agents bundle unrelated dirty-tree edits into commits** (documented in Batch P and Batch JJ). This keeps the branch perpetually dirty, which makes each subsequent agent hesitant to rebuild, which keeps the user on a stale binary. The cycle must be broken with a hard `git stash` + clean checkout before any new batch.

Stanford's 2025 agent-failure study catalogued this exact pattern: "agents had no understanding of the system they were trying to work on — they were operating blind". The fix is a capability manifest the agent reads **before every action**, which Epistemos already scaffolded in Batch II.1 but never wired into provider prompts.[^5]

## The canonical issue list

Every concrete complaint raised across the chat log, mapped to root cause and fix status.

| # | Symptom | Root cause | Batch landed | Still open |
|---|---------|------------|--------------|------------|
| 1 | Mode picker stuck on Auto Route | Three routers disagreeing, picker state not bound to active authority | A (UI), HH.4 (pro→agent-loop) | Router consolidation (P2) |
| 2 | Typo-heavy / incoherent cloud replies | `openAIResponseControls` applied GPT-5 reasoning+verbosity fields to the ChatGPT-Codex backend which rejects them and degrades prose | B | Covered |
| 3 | Thinking renders as main chat text, then disappears | `<think>` tags streamed inline for DeepSeek-R1 class; OpenAI `reasoning_content` fall-through; Google `parts.thought=true` not filtered | CC (OpenAI), GG (Google), think-tag stream router | Rust agentcore path (JJ) |
| 4 | GPT-5.4 picker won't stick | Legacy `gpt-5.2` pin + no observable refresh | O | Covered |
| 5 | Gemma 4 "Unsupported model type" | Swift MLX loader for Gemma-4 never ported; selector let user pin it | T | Swift loader port (deferred) |
| 6 | Side panel just says "Brain" | Label regression | S, BB (Claude-Code style) | Covered |
| 7 | Near-OLED notes sidebar + window | New `NotesNearOLEDPalette` | AA, then reverted in V per user | Re-applied as dark-mode-only in AA-redo |
| 8 | Scroll stutter in main chat | Per-row `HStack/Capsule/Image` badge and re-parsing of markdown | U (badge) | Re-parse caching, `.animation(...)` on hover, SwiftData `@Query` churn — need Instruments trace[^4][^3] |
| 9 | Idle 5-min CPU/memory churn | Vault manifest version-capture timer ran every 300 s even with no mutation | P | Covered |
| 10 | 2 GB peak → 300 MB idle memory | Normal startup (SwiftData load of 859 notes + Metal warmup + GRDB + search index). 300 MB idle is Rust-side `agentcore` sessions + FTS5 mmap + graph engine buffers | — | Rust-side buffer release; MLX `set(cacheLimit: 0)` option[^6] |
| 11 | Context meter stuck at "2/9/128.0K" when attaching notes | Token estimator counted only raw user text | KK | Covered |
| 12 | "Find my note X" hallucinates | `PipelineService.swift:302-304` drops Pro-cloud into a zero-tool path; classifier doesn't fire on "find/look up/show me"; `AgentAuthority` uses in-memory persistence that dies on restart; write tools gated at Agent tier only | HH.1-4 | Verify on a clean build |
| 13 | Agent-mode tool calls emitted as literal JSON text blobs | Rust `agentcore/src/providers/openai.rs` uses Chat Completions tool-call format instead of Responses API `function_call` items, or the tool schema is not sent | — | **Batch JJ — still open** |
| 14 | No native reasoning-effort picker (Standard/Extended) | OpenAI `reasoning.effort` (low/medium/high), Anthropic `thinking={type:enabled, budget_tokens:N}` or `{type:adaptive}`[^7][^8], Google `thinkingConfig.includeThoughts=true`[^9] were not exposed | DD.1-5 | Covered |
| 15 | No TodoWrite checklist / scratchpad / visible plan | Claude Code's sticky-to-top TodoWrite tool-card is the single highest-impact transparency lever[^10] | FF.1 (live narration) | FF.2 TodoWrite surface, FF.3 scratchpad drawer |
| 16 | "App feels dead" during tool use / web search | No tool-phase pill, no animated tool card, no search-phase progress | FF.1 | FF.4 animated tool cards, FF.5 search-phase pill |
| 17 | Capability parity with ChatGPT (web search, code interpreter, image gen, native PDF, file search) | Anthropic web-search beta header wired in II.2; 8 other parity gaps unwired | II.1-2 | II.3-10 |
| 18 | No terminal / bash / SSH | `omega-mcp/src/pty.rs` exists, no UI surface | — | GG: embedded terminal view + bundle `rg`/`fd` |
| 19 | ChatGPT froze mid-thinking | Watchdog never fires on silent stream stall; `LastActivityTracker` was added but no timeout surface | partial | EE timeout + retry UI |
| 20 | Code editor "two themes fighting" | Native-material canvas painted `.clear` while `CodeEditSourceEditor` painted solid `NSColor.textBackgroundColor`, creating a seam; gutter + folding ribbon had their own theme | N, V, Z | Confirm on fresh build |

## The three hard-truth architecture problems

These are the issues that keep regenerating as surface bugs. None of them are fatal — the primitives exist — but they must be unified, not patched.

### 1. Router consolidation (the #1 source of "nothing reacts")

The app has three routers making overlapping decisions. The fix is Claude Code's pattern verbatim: **subagent-with-model-override as the core primitive**, where each role (overseer, researcher, writer, fast-retrieval, vault-librarian) is a config bundle of `{system prompt, tool allowlist, preferred model, fallback model}`. Routing becomes a two-step question: which subagent handles this intent, then which model does that subagent run on right now.[^11][^12]

The winning pattern in the research literature is a **3-layer cascade**: (1) sub-millisecond intent semantic router (aurelio-labs pattern, no LLM call) classifies into the six PKM shapes (capture, ask-vault, synthesize, research, draft, meta-op); (2) FrugalGPT-style calibrated judger decides local-vs-escalate; (3) model-within-tier picker (RouteLLM's matrix factorization hits 95% GPT-4 quality at 26% cost).[^13]

The triage itself should be **hybrid**: local classifier first, escalate to Haiku 4.5 when local confidence is low. Nobody in PKM has shipped this yet, and it's the single biggest architectural differentiator available.

### 2. Reasoning streams must go to a dedicated panel, not inline text

The research confirms the exact event shapes that need parsing, which closes the "thinking leaks as main text" bug class definitively.

**OpenAI Responses API** (reasoning-capable models):[^14]
```
response.output_item.added (type=reasoning)
  → response.reasoning_summary_part.added
  → response.reasoning_summary_text.delta (append to thinking buffer)
  → response.reasoning_summary_text.done
  → response.reasoning_summary_part.done
response.output_item.added (type=message)
  → response.output_text.delta (this is the visible reply — and ONLY this)
```

Two distinct event names for summary deltas exist (`response.reasoning_summary_text.delta` and `response.reasoning_summary.delta`) and both must be handled. The parser must never fall through `reasoning_content` into visible text — that is the root cause of the "Okay, so I'm trying to figure out..." monologue bug.[^15][^16]

**Anthropic extended thinking**:[^7][^8]
```
content_block_delta with delta.type == "thinking_delta"   → thinking panel
content_block_delta with delta.type == "text_delta"       → visible reply
content_block_delta with delta.type == "signature_delta"  → preserve opaque, do not render
```
`thinking={"type":"adaptive","display":"summarized"}` for Opus 4.7; `{"type":"enabled","budget_tokens":N}` for older models.

**Google Gemini thinkingConfig**:[^9]
```python
ThinkingConfig(IncludeThoughts=True)
```
Each `candidates[*].content.parts[*]` has a `thought: bool` flag. `thought==true` routes to thinking panel, `thought==false` or absent routes to visible reply. `includeThoughts` can only be set when thinking is actually enabled on the model — setting it on a non-thinking model returns 400.[^17]

The cross-provider LLM-Rosetta research paper confirms this maps cleanly to a 10-type stream event IR spanning reasoning_delta, text_delta, tool_call, and signature — meaning one typed-chunk plumbing layer in `LLMService.swift` can serve all three providers instead of three parallel parsers.[^18]

### 3. Capability manifest + visible agent surface (the "app feels dead" fix)

The note-taking app equivalent of Claude Code's TodoWrite is the highest-impact transparency lever. The pattern:[^10]

- **Inline TodoWrite checklist**: three states (pending / in-progress / done), only one in-progress at a time, strikethrough on done, renders as a tool card that sticks to the top of the current turn.
- **Subagent dispatch via a `Task` tool** with `{description, prompt}`; the subagent receives the same system prompt plus environment details, cannot call further subagents.[^10]
- **Context meter bottom-bar** showing token breakdown by category (system, vault, tools, turn history) with auto-compact warning.
- **Scratchpad drawer** backed by Anthropic's `think` tool whose output renders as a "Notes to self" card.
- **Live tool narration** pill (Batch FF.1, already landed) must be complemented by animated tool cards and a web-search-phase progress strip so the user sees "searching vault → reading note → drafting" rather than a spinner.

The capability manifest (Batch II.1) must be injected into the system prompt so the model knows which tools are actually enabled. Without this, models hallucinate tools or cargo-cult JSON tool-call syntax — exactly what the Agent-mode screenshot showed with `name: readfile, arguments: ...` as literal text.

## The ordered execution plan for the next session

Each batch below is small enough to test and commit atomically. Stop after each and confirm in a **fresh Xcode build from the scheme** (not `tmp/`), because that is the whole reason fixes "aren't showing up."

### Phase 0 — Unblock the loop (must do first)

1. `git stash -u` any Codex dirty-tree edits that weren't yours.
2. `git clean -fdx tmp/` and let Xcode regenerate `DerivedData` from scratch.
3. Build from the **Epistemos** scheme, launch, and screenshot the current state for each of the 20 symptoms above. Without this baseline every subsequent "did it work?" question is unanswerable.

### Phase 1 — Close the open regressions (1-2 sessions)

4. **Batch JJ (Rust agentcore OpenAI repair)** — `agentcore/src/providers/openai.rs`: (a) stop routing `reasoning_content` into text stream, mirror the Swift `LLMService.swift` fix from Batch CC; (b) emit tool calls as Responses API `function_call` items with the tool schema actually sent in the request, not Chat Completions `tool_calls` arrays.
5. **Batch EE (reasoning → popover plumbing)** — wire the three typed reasoning streams (OpenAI `reasoning_summary_text.delta`, Anthropic `thinking_delta`, Google `parts[*].thought==true`) into the existing thinking popover component. Persist the trace into `ChatMessage.persistedThinking` so the user can click to replay historical reasoning.
6. **Batch HH verify** — confirm on a clean build that "find my note on X" now actually tool-calls `vaultsearch` + `vaultread` in Pro-cloud mode and quotes real note content, not hallucinations.

### Phase 2 — Make the agent legible (1 session)

7. **Batch FF.2 TodoWrite surface** — register a `TodoWrite` tool that writes to a sticky card above the current turn, three-state, strikethrough on done.
8. **Batch FF.3 scratchpad drawer** — Anthropic `think` tool as "Notes to self" disclosure group under the active turn.
9. **Batch FF.4-5 tool cards + search phase** — animated tool cards with durations, web-search phase pill (`searching → reading → synthesizing`).
10. **Batch II.3 capability manifest injection** — prepend `Capabilities.md` into the system prompt for every provider so models stop hallucinating unavailable tools.

### Phase 3 — Router consolidation (2 sessions, the real architecture work)

11. Collapse `EpistemosLocalAgentConfidenceRouter.swift` into a thin classifier feed.
12. Make `agentcore/src/routing.rs` the single authority; delete `epistemos-core/src/agentruntime/routing.rs` duplicate.
13. Introduce the subagent config bundle (`{system_prompt, tools, preferred_model, fallback_model}`) and rewrite the overseer/fast/reasoner/cloud-reasoner/cloud-agent roles as subagent configs.
14. Add hybrid triage: local classifier first, escalate to Haiku 4.5 on low confidence.
15. Emit the plan-before-dispatch (1-3 step) for research/agent intents, hide it for trivial intents.

### Phase 4 — Memory + perf (1 session with Instruments)

16. Profile main-chat scroll with **Time Profiler** (main-thread spikes), **Allocations** (per-row churn), and **Core Animation** (dropped frames). Without an Instruments trace this is guesswork.[^4][^3]
17. Likely culprits, in order: `TaggedMarkdownTextView` re-parse cache keyed on changing state, `.animation(.quick, value: isHovered)` on toolbar, `ToolExecutionPreviewList` inline formatting, SwiftData `@Query` predicate re-computation.
18. Rust-side memory: graph engine `pauseEngine` must actually free buffers, `SearchIndex` FTS5 needs lazy unload, `agentcore` session cleanup on idle.
19. MLX: `MLX.set(cacheLimit: 0)` trades some re-alloc cost for ~hundreds of MB RAM back on idle.[^6]

### Phase 5 — Parity gaps (ongoing)

20. II.3 web_fetch, II.4 code_interpreter, II.5 image_generation, II.6 audio_in, II.7 native_pdf, II.8 structured_output, II.9 batch_api, II.10 cache_hit_badge.
21. Embedded terminal view (GG) via the existing `omega-mcp/src/pty.rs`, bundled `rg`/`fd`. Skip dedicated SSH — once terminal is up, `ssh host cmd` works through it.

## What the next agent must NOT do

- **Do not start Phase 2/3/4 before Phase 0-1 is verified on a fresh build.** Every previous session drifted because Phase 2 polish was committed while Phase 1 regressions were still live in the binary the user was launching.
- **Do not bundle Codex dirty-tree edits into your commits.** Stash them first; improvements can ship as their own audited batch.
- **Do not touch** `Epistemos-RETRO/`, `src-tauri/`, or `meta-analytical-pfc/`.
- **Do not hide routing decisions in `.clear` backgrounds / silent backend switches.** The user explicitly wants the stack visible — "fast local → reasoning local → cloud escalation" as named cards.
- **Do not re-run `tmp/epistemos-routing-ux-rerun` as the success criterion.** The only success criterion is the user opens the built app and the symptom is gone.

## Why this plan is different from previous handoffs

Previous handoffs were organized by file touched ("Batch P bundled 5 Codex edits, here are the SHAs"). This plan is organized by **observable symptom → root cause → verified fix** and forces a fresh-build verification gate between every phase, which is the step that has been missing. Combined with (a) the typed reasoning-stream parsers above that map 1:1 to the three providers' published event schemas, (b) a single router authority modeled on Claude Code's subagent-with-model-override, and (c) TodoWrite + capability manifest as the transparency pair, the remaining work is mechanical — not architectural re-guessing.[^12][^9][^7][^14][^5][^10]

When Phase 0-2 are complete on a binary the user actually launches, the "agents are having a really hard time building this to actually make it show up" meta-problem disappears, because every fix will be provably live before the next batch begins.

---

## References

1. [On the Use of Agentic Coding Manifests: An Empirical Study of Claude Code](https://link.springer.com/10.1007/978-3-032-12089-2_40) - Agentic coding tools receive goals written in natural language as input, break them down into specif...

2. [Everyone's building AI agents wrong. Here's what actually happens ...](https://www.reddit.com/r/PromptEngineering/comments/1rgfg8l/everyones_building_ai_agents_wrong_heres_what/) - The one thing that breaks every agent system. Memory contamination. When Agent 3 has access to Agent...

3. [SwiftUI performance tuning for long lists: practical fixes - AppMaster](https://appmaster.io/blog/swiftui-performance-long-lists) - Baseline on a real device and use Instruments to find main-thread spikes and allocation surges durin...

4. [SwiftUI Performance: LazyVStack & List Optimization - iOS - SharpSkill](https://sharpskill.dev/en/blog/ios/swiftui-performance-lazyvstack-complex-lists) - Incorrect handling causes scroll stuttering ... Profiling with Instruments. Identifying performance ...

5. [AI Agents Can't Fix What They Can't See: Why Your AI Investment Is ...](https://futurify.io/blog/ai-agents-cant-fix-what-they-cant-see/) - The problem was that the agent had no understanding of the system it was trying to work on. It was o...

6. [GPU Memory/Cache Limit · Issue #66 · ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples/issues/66) - set(cacheLimit:) -- this controls the amount of memory that MLX will keep around after it is used (s...

7. [Streaming Messages - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/streaming) - For thinking content, a special signature_delta event is sent just before the content_block_stop eve...

8. [Building with extended thinking - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/extended-thinking) - When streaming is enabled for extended thinking, you receive thinking content via thinking_delta eve...

9. [Thinking | Generative AI on Vertex AI - Google Cloud Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/thinking) - Thinking models are trained to generate the "thinking process" the model goes through as part of its...

10. [Agent design lessons from Claude Code | Jannes' Blog](https://jannesklaas.github.io/ai/2025/07/20/claude-code-agent-design.html) - ... tools. TODO Lists. To plan its work and stick to the plan, Claude Code uses TODO lists, an examp...

11. [Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems](https://www.semanticscholar.org/paper/cb5357aaa71a993f2966b71a002ab55631d4a034) - Claude Code is an agentic coding tool that can run shell commands, edit files, and call external ser...

12. [Claude Code Subagents: How to Create, Use, and Debug Them](https://www.builder.io/blog/claude-code-subagents) - Claude Code subagents are specialized workers that run in separate context windows, each with their ...

13. [How to Fix Broken AI Agents: A Step-by-Step Guide - LinkedIn](https://www.linkedin.com/posts/ai-shift-media_how-to-fix-broken-ai-agents-your-agent-isn-activity-7397982198722666496-OzD_) - How to Fix Broken AI Agents Your agent isn't “smart.” It's just confused. And most teams never fix t...

14. [Responses API streaming - the simple guide to "events"](https://community.openai.com/t/responses-api-streaming-the-simple-guide-to-events/1363122) - This reference organizes every Server-Sent Event (SSE) you may see from the Responses API when strea...

15. [Two different responses events for reasoning summary? - API](https://community.openai.com/t/two-different-responses-events-for-reasoning-summary/1285333) - “Emitted when there is a delta (partial update) to the reasoning summary content.” What is the diffe...

16. [Responses API: reasoning_summary_part events (e.g. ... - GitHub](https://github.com/openai/openai-openapi/issues/444) - Responses API: reasoning_summary_part events (e.g. response.reasoning_summary_part.added) are not de...

17. [API Error: Thinking_config.include_thoughts when using gemini -m ...](https://github.com/google-gemini/gemini-cli/issues/1953) - When attempting to use gemini-2.5-flash-lite-preview-06-17 model, an API error occurs related to Thi...

18. [LLM-Rosetta: A Hub-and-Spoke Intermediate Representation for Cross-Provider LLM API Translation](https://www.semanticscholar.org/paper/48f49e0068a1bad323e042d71486514bdde752dd) - The rapid proliferation of Large Language Model (LLM) providers--each exposing proprietary API forma...

