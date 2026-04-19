# Epistemos Master Plan — April 19 2026 sprint

Single source of truth for everything the user flagged during the long session on `codex/runtime-input-audit`. Updates as batches land. Ordered by priority, not chronology.

---

## 1 · What's already committed (this sprint)

Each commit is independently reviewable, each passed its focused test sweep.

### Chat routing + picker UX
| SHA | What |
|-----|------|
| [254312cd](commits/254312cd) | A · routing UX popover, Codex GPT-5.4 preservation, Settings↔picker sync |
| [18664605](commits/18664605) | B · Codex backend drops GPT-5 native controls (typo-heavy prose fix) |
| [209491a7](commits/209491a7) | O · GPT-5.4 migration + observable cloud-model refresh |

### Chat transparency data + UI
| SHA | What |
|-----|------|
| [06cc013e](commits/06cc013e) | C · agent `.thinkingDelta` wired through AgentChatState |
| [9cf31cf7](commits/9cf31cf7) | D · empty-stream guard surfaces real error instead of ghost bubble |
| [526b7279](commits/526b7279) | G · main-chat thinking lifecycle test coverage |
| [5ddd6db9](commits/5ddd6db9) | I · `ChatMessage.resolvedModelLabel` + `effectiveModelLabel` helper |
| [cfad9a99](commits/cfad9a99) | J · EffectiveModelBadge under every assistant reply |
| [55e1543a](commits/55e1543a) | U · badge simplified to plain Text (scroll stutter) |
| [049aa4aa](commits/049aa4aa) | CC · OpenAI `reasoning_content` no longer leaks as chat reply |
| [3fb03219](commits/3fb03219) | Q · typed error enum + `classify()` |
| [da1d13d4](commits/da1d13d4) | W · error bubble recovery buttons for `authFailure` / `modelNotReady` |
| [7235802f](commits/7235802f) | X · click-through routing-rationale popover on the model badge |
| [7ea2edfe](commits/7ea2edfe) | Y · pre-submit preview in context side panel |
| [8d98661c](commits/8d98661c) | S · side panel "Brain" → "Context" rename |
| [3187f820](commits/3187f820) | BB · Claude Code-style collapsible sections on Context panel |

### Theme + editor polish
| SHA | What |
|-----|------|
| [f3718b7f](commits/f3718b7f) | N · code editor syntax colors source from active theme |
| [eecc2538](commits/eecc2538) | V · native NSVisualEffectView restored for note canvas on system-appearance themes |
| [55004728](commits/55004728) | Z · code editor inherits prose background + drops gutter/folding |
| [4b7f6e78](commits/4b7f6e78) | AA · near-OLED `#1E1E20` for notes sidebar + note window on dark themes only |

### Performance + model stack
| SHA | What |
|-----|------|
| [0eb97f9e](commits/0eb97f9e) | P · vault mutation epoch stops the 5-minute idle manifest churn |
| [98897428](commits/98897428) | H · QwQ 32B flagship reasoning model added to catalog |
| [8c65bf83](commits/8c65bf83) | T · Gemma 4 hidden from picker + auto-migrate stale pins |

### Data layer for next batches
| SHA | What |
|-----|------|
| [c9916176](commits/c9916176) | DD.1 · ChatReasoningTier enum + `@AppStorage` persistence |

### Docs
| SHA | What |
|-----|------|
| [eb5a0edb](commits/eb5a0edb) | Chat transparency P1/P2/P3 plan |
| [dd0b3caa](commits/dd0b3caa) | AGENT_PROGRESS + MASTER_MODEL_STACK_PLAN updates |

**Research briefs landed (in-repo notes):**
- Internal chat-audit (15 ranked issues, cited `file:line`)
- External landscape: Perplexity / Goose / Aider / Cline / OpenHands / RouteLLM / etc.
- Native reasoning controls: OpenAI / Anthropic / Google wire-level
- Agent transparency UX: Claude Code / Cursor / Perplexity / o1 / Claude.ai / Aider / Goose / OpenHands / Devin / NotebookLM
- Tool surface audit + target state recommendations

---

## 2 · Batch HH — URGENT tool-path fix ✅ COMPLETE

All four sub-batches shipped. "Find my note X" on Pro + cloud GPT-5.4
now has a wired path from user input → intent classifier → Rust agent
loop → ChatPro-tier tools → `vault_search` / `vault_read` → real
answer. No more hallucinations about notes the model couldn't see.

| Sub | SHA | What |
|-----|------|------|
| HH.1 | [2e0e095f](commits/2e0e095f) | Intent classifier recognizes "find the note / look up / search for" as agent signals |
| HH.2 | [965782a5](commits/965782a5) | `FileBackedAgentAuthorityPersistence` — allow/ask/deny survives relaunch |
| HH.3 | [3b8e1386](commits/3b8e1386) | `vault_write` / `patch` / `memory` downgrade to ChatPro tier |
| HH.4 | [7d2ffa66](commits/7d2ffa66) | Pro + cloud routes through Rust agent loop with chat_pro tools |

### (legacy) HH plan (kept for reference)

The biggest root-cause finding from Research 3: **the "find my note" / "what am I working on" failures have a single-line root cause.** Pro mode on a cloud brain drops into a path with zero tools, so GPT-5.4 hallucinates about notes it has no way to actually look up.

### HH.1 — Intent classifier nudges toward Agent mode for note lookups
`Epistemos/Engine/AgentHarness/ChatCapability.swift:141` currently has `create/delete/update/install/run/automate/send/open-the-app` in the agent-signal list but is missing the LOOKUP signals. Add: `"find the note"`, `"find a note"`, `"look up"`, `"search for"`, `"locate"`, `"show me"`, `"open the note"`, `"which note"`, `"summarize my note"`. **~10 line change.**

### HH.2 — Persist AgentAuthority decisions across launches
`Epistemos/Engine/AgentHarness/AgentAuthority.swift:152` uses `InMemoryAgentAuthorityPersistence` as the default. User allow/ask/deny choices don't survive restart. Swap to JSON-file backing keyed on a vault-relative path. **Medium, contained to one file.**

### HH.3 — Downgrade safe-write tools from Agent to ChatPro
In `agent_core/src/tools/registry.rs:483` (`apply_tier_overrides`), move `vault_write`, vault-relative `patch`, and `memory` from `Agent` to `ChatPro`. A notetaking app whose AI can't save a note from Pro mode is exactly what the user hit.

Gate: still require single-confirm on first use per session (existing AgentAuthority pattern).

### HH.4 — Pro-mode-on-cloud gets tools
`Epistemos/Engine/PipelineService.swift:302-304` — the `guard case .localMLX` gates every cloud-model Pro turn to a zero-tools direct stream. Fix: route Pro+cloud through the Rust agent loop with `ChatPro` tier (bounded `max_turns=3`, `max_tool_calls=8` — already in `ResolvedExecutionPolicy`).

`Epistemos/App/ChatCoordinator.swift:1201` — the `operatingMode == .agent` condition also needs to allow `.pro` with cloud models.

**Highest risk + highest impact of HH sub-batches.** Save for last, land behind a shadow-test that asserts Pro+cloud can emit at least one tool call on a benchmark prompt.

---

## 3 · Batch DD — native reasoning controls (in progress)

Data layer shipped as DD.1. Per the research brief, the app taxonomy is 3-tier (Off / Standard / Extended) — honest across all three providers.

### DD.2 — OpenAI wire-up
Extend `openAIResponseControls` in `LLMService.swift` to honor `inference.chatReasoningTier`:
- `.off` → `reasoning.effort: "none"`, `text.verbosity: "low"`
- `.standard` → `reasoning.effort: "medium"`, `reasoning.summary: "auto"`, `text.verbosity: "medium"`
- `.extended` → `reasoning.effort: "high"`, `reasoning.summary: "detailed"`, `text.verbosity: "high"`

Disable the control on non-reasoning models (hard 400 otherwise). Only apply on `/v1/responses` — Chat Completions rejects the nested object.

### DD.3 — Anthropic wire-up
Migrate `anthropicExtendedThinkingEnabled` + `anthropicThinkingBudgetTokens` to the tier:
- `.off` → omit `thinking`
- `.standard` → Opus 4.7+/Mythos: `thinking:{type:"adaptive", effort:"medium"}`; older: `thinking:{type:"enabled", budget_tokens: 4096}`
- `.extended` → adaptive `high`; older manual: `budget_tokens: 16000` + `anthropic-beta: interleaved-thinking-2025-05-14` header when tools are in play

Keep the existing Settings sliders visible for power users; the tier drives the default, slider overrides per chat.

### DD.4 — Google thinkingConfig (pure gap)
Add `thinkingConfig` to `generationConfig` in Google requests:
- `.off` → 3.x: `thinkingLevel:"minimal"` if supported else omit; 2.5 Flash/Lite: `thinkingBudget:0`; 2.5 Pro: not supported
- `.standard` → 3.x: `thinkingLevel:"medium"`; 2.5: `thinkingBudget:-1` (dynamic); always `includeThoughts:true`
- `.extended` → 3.x: `thinkingLevel:"high"`; 2.5: `thinkingBudget:16384`; `includeThoughts:true`

Validate: `thinkingLevel` and `thinkingBudget` in one request is a hard 400 — pick one per model.

### DD.5 — Settings → Inference picker UI
Segmented control: Off / Standard / Extended with the `summary` string below. Per-model reasoning capability gate (disable the control with a subtitle when the active model doesn't support reasoning).

---

## 4 · Batch EE — route reasoning into the thinking popover

Batch CC stopped the OpenAI reasoning leak; the reasoning now simply drops into a void. This batch threads it back into the existing thinking popover.

- New `PipelineEvent.reasoningDelta(String)` sibling of `.textDelta`.
- `LLMService` streaming parsers surface reasoning per provider:
  - OpenAI: `openAICompatibleReasoningDelta` (already added in CC)
  - Anthropic: `content_block_delta.delta.type == "thinking_delta"` path (preserve `signature_delta` for tool continuation)
  - Google: `parts[*].thought == true` (requires `includeThoughts:true` from DD.4)
- `ChatCoordinator` routes `.reasoningDelta` → `ChatState.appendStreamingThinking` so the existing `ThinkingPopoverView` lights up.
- Live stream then collapse to "Thought for Ns" pill per research 2 consensus.

---

## 5 · Batch FF — Claude Code-style agent transparency

Inline surfaces so the user can see what the agent is doing without leaving the chat.

### FF.1 — TodoWrite sticky card
Render `TodoWrite` tool calls as a special card that sticks to the top of the current assistant turn (not just a collapsible tool card in the stream). Three states per item: pending / in_progress / done. One in-progress at a time per research 2 consensus. Strikethrough on done.

### FF.2 — Context meter bottom-bar
Per-chat bar showing `tokens used / model limit`, three-segment breakdown (system / tools / messages / free), auto-compact threshold marker. Claude Code's `/context` widget is the only documented precedent; no app does "what's about to be evicted" — that's open territory.

### FF.3 — Scratchpad as `think`-tool card
Anthropic's `think` tool already exists in `agent_core`. Render its output as a distinct "Notes to self" card type in the transcript — collapsed by default, expandable, explicitly marked as non-authoritative.

### FF.4 — Stream the thinking drawer live
Claude.ai pattern. `DisclosureGroup` that auto-expands while the assistant is thinking (shows the live stream from Batch EE), auto-collapses to "Thought for 8s" when the first text delta arrives. Already have the state on `ChatState` from Batches C/D/G — just need the animated surface.

---

## 6 · Batch GG — optional polish surfaces

Not critical for release but high-value per research 3.

### GG.1 — Embedded terminal view
PTY plumbing already exists in `omega-mcp/src/pty.rs` + `agent_core/src/pty.rs` — no UI surface today. One tab that tails the latest `terminal` tool call's stdout with ANSI rendering. Matches Cursor/Claude Code inline terminal.

### GG.2 — Bundle `rg` and `fd` binaries
For faster vault search and agent-side find operations. `search_files` uses `grep-searcher` in-process today (fine), but shelling out to `rg` via `terminal` for user-typed queries unlocks power-user speed once HH.3+HH.4 enable the terminal tool.

### GG.3 — Memory diff card
No shipping app does this today — genuine first. After each turn that updated persistent memory, render a post-turn card: "Remembered 2 new things, updated 1." Each with accept/reject/edit affordances. Anthropic's user-editable memory is the closest prior art.

### GG.4 — "Loaded vs attended" provenance
Hardest. No app ships this. Would require agent_core to annotate which context blocks it actually used per answer, then render citation-chip-links back to the attended notes. Park as R&D until attention-tracking is reliable.

---

## 7 · Deeper memory reduction (Rust-side, deferred)

Baseline is now 300MB idle (down from 741MB) — audit agent confirmed stable. Remaining 250MB reduction targets are all Rust:

- Graph engine buffer release on `pauseEngine` (80-150MB estimated)
- SearchIndex FTS5 lazy unload after N minutes idle (50-100MB)
- Rust agent_core retained sessions cleanup (variable)

These need careful Rust changes with `cargo test` validation and are deliberately after the UX priorities.

---

## 8 · Open questions for the user

These shape the implementation and should be answered before the related batches land.

1. **HH.4 risk tolerance** — Pro+cloud routing through Rust agent loop: you want this on by default, or behind a feature flag for one release cycle?
2. **FF.2 context meter position** — bottom-bar or pinned to the top of the composer? Claude Code uses a `/context` slash command; Cursor has a micro-bar in the composer footer.
3. **Reasoning tier default** — Standard (current DD.1 default) or Off so users opt in?
4. **DD.5 picker location** — Settings only, or also in the main chat picker next to the model row?

---

## 9 · What gets flagged as "fine, leave alone"

From user's own words — surfaces I'm deliberately not touching:
- **Prose editor** — "the most polished part of the app, needs to stay that way." Batches V + AA change only the paint background on dark; rendering/typing/wikilinks untouched.
- **Light mode** — "should not be changed at all." Near-OLED is dark-only; light themes fall through to existing code at every call site.
- **Graph hologram physics** — pause/resume wiring stays; no touches to the Metal/Rust render loop.
- **MLX idle unload** — already correct (1-5s delay, verified). No work needed.

---

## 10 · Commit cadence rules (reminder for future batches)

Learned from tonight's misses:
- **Never `git add <file>` without checking `git diff --staged` first** — that's how the pre-existing dirty-tree edits bundled into Batch P. Use targeted `git add -p` or stage specific hunks when a file has mixed ownership.
- **One concern per commit.** If a test breaks after landing, it's always clear which commit to revert.
- **Failed test = fix or revert, never skip.** No `--no-verify`, no test-shape relaxation without explanation.
- **User's "don't break what's polished" constraint** is load-bearing. Every batch that touches `Epistemos/Views/Notes/` specifically has to prove no prose-editor regression.

---

*Last updated: 2026-04-19. Append-only below this line; future batches add their rows to sections 1-6.*

---

## 11 · Added 2026-04-19 evening — "app feels dead" crux

User's exact language: *"for tool use and searching things online my app does not have ui for that everything just feels dead... that is the crux of the entire plan."* The app is engineered well but invisible during the moments users most need to feel it working — tool calls, web searches, agent steps. Three linked threads:

### 11A — Capability manifest (pending research)
Research agent dispatched to answer: what shape should a dynamic capability document take so each model reads it before every turn and knows exactly what it can do right now? Candidates: markdown `.agents/CAPABILITIES.md` (Claude Code precedent), YAML per-mode, JSON injected as system prompt. Scope, format, and injection timing to be decided from the brief.

### 11B — Capability parity audit (pending research)
User wants UI for **every** capability OpenAI / Anthropic / Google expose. Research agent building a matrix: rows = capabilities (streaming / multimodal in/out / file upload / code interpreter / web browse / web fetch / computer use / document gen / tool calling / structured output / memory / projects / reasoning / agent runtime / vision / audio / TTS / batch / long context / caching / moderation / fine-tune / embeddings). Columns = providers. Plus a third pane: does Epistemos surface it today (Shipped / Engineered-but-hidden / Gap)? Ends with top-10 UI gaps ranked by impact.

### 11C — Live tool-use / web-search status UI
Right now when an agent fires a tool, the user sees roughly nothing: `activeToolName` is a string, `isAgentExecuting` is a bool, and the StreamingIndicator is a single spinner. Compared to Perplexity ("Searching 3 sources... Reading article... Synthesizing"), Claude Code (live stdout streaming), and Cursor (tool panel) — Epistemos is silent during the exact seconds it's doing the most work.

Minimum-viable "live tool status" UX to design:
- A compact narration strip above the streaming indicator: `▸ Searching your vault — "bell hooks"`
- Tool cards that animate in the moment the tool event arrives, showing args, live stdout (for shell/terminal tools), and completion state
- For web-enabled turns, a Perplexity-style "Searching / Reading / Synthesizing" narration tied to PipelineEvent types
- Sources rail — citations attach to the assistant reply inline + aggregate

Lands as Batch **FF extended** — originally planned as TodoWrite checklist + context meter, now expanded to include this live-narration + animated tool cards work.

---

## 12 · Open questions (added by user 2026-04-19 evening)

5. **Capability manifest scope** — should it be user-editable (like `.cursorrules` / `CLAUDE.md`) or auto-generated by the app from the active tier + tool toggles + configured provider, or both (auto-generated base + user-authored overrides)?
6. **Parity audit threshold** — should the app aim to expose every capability each provider offers, or a curated PKM-scoped subset (vault-read / vault-write / web search / embeddings / long context / reasoning — skip code interpreter, TTS, image gen)?
7. **Live narration verbosity** — per-step ("Searching vault → 3 hits → Reading note 1…") or summary ("Searching vault…"). Perplexity does per-step for Pro Search and summary for regular.
8. **Tool-status card permanence** — collapse to summary after completion, or keep expanded so the user can see what was run?

---

## 13 · Research 4 findings (landed 2026-04-19 evening)

Primary-source research is back on all three threads. Full brief is in the agent transcript (`a9a4fc222a59517cf`); action items below.

### 13A · Capability manifest — recommended shape

- **File**: `~/Library/Application Support/Epistemos/runtime/Capabilities.md` — regenerated per turn by a `CapabilityManifestBuilder`.
- **Format**: Markdown narrative + tool JSON schemas appended separately. Models read prose far better than structured data for descriptive context.
- **Sections**: Who you are / Vault state / Enabled tools / Disabled-unavailable / Skills registry / User preferences / How to act.
- **Cache**: stable prefix wrapped in `cache_control: ephemeral` for Anthropic (90% discount) and as `instructions` for OpenAI Responses.
- **Authoring split**: header/identity/tools auto-generated; "How to act" user-editable (`~/Library/Application Support/Epistemos/Capabilities.md.user`).
- **Precedent**: Claude Code's `CLAUDE.md` + `AGENTS.md` loaded into system prompt; Cursor's `.cursorrules`; Aider's repo-map + `CONVENTIONS.md`. MCP has no document pattern — the wire protocol is the manifest.

### 13B · Parity matrix — top 10 UI gaps ranked by impact

1. **Live tool-status narration during web search** — the "app feels dead" fix (see 13C)
2. **Provider-hosted web search for Anthropic + Google** — today only OpenAI `web_search` has a toggle
3. **Web fetch / single-URL grounding** — Anthropic `web_fetch` beta, OpenAI `web_search` URL mode
4. **Code interpreter** — OpenAI `code_interpreter` was removed (regression); add Anthropic `code_execution_20250825` beta
5. **Image generation surface** — `MLXImageGenerationService` wired but invisible; add `/image` slash command + result card
6. **Audio input (transcription)** — mic button in composer → Whisper / Gemini transcription
7. **Native PDF upload to providers** — currently text-extracted; switch to provider native PDF blocks
8. **Structured output / JSON schema** — toggle when Pro/Agent mode active
9. **Batch processing queue** — 50% cost savings for bulk vault ops
10. **Prompt-cache hit indicator** — badge on assistant message showing cache hit %

### 13C · "App feels dead" — diagnosis and MVP fix

**Rust backend already emits every event needed**: `onThinkingDelta`, `onToolStarted`, `onToolInputDelta` (streaming), `onToolCompleted`, `onTurnStarted`, `onContextCompacting`, `onContextCompacted`, `onPermissionRequired`. The `StreamingDelegate` has 14 distinct event types.

**UI just doesn't listen loudly enough.** Today between `toolStarted` and `toolCompleted`, the user sees a static status chip + tool name. Long-running tools (web search 3-8s, code execution 5-20s) fill that gap with silence = "dead".

**Three-layer MVP (no Rust changes, no FFI changes — pure Swift)**:

1. **`ToolActivityNarrator`** — humanized status line above the streaming response:
   - `web_search` + partial query → "Searching the web for '…'..."
   - `web_fetch` + url → "Reading example.com..."
   - `vault_read` → "Looking up 'Daily brief'..."
   - `bash` → "Running ls..."
   - generic → "Using \(prettifiedToolName)..."
   - Updates from `onToolInputDelta`; becomes "Searched for '…' (N results)" on complete.

2. **Auto-expanded active tool card** — `ToolExecutionPreviewCard` defaults to expanded while `result == nil && isStreaming`. Shows tool name + icon + running timer (`TimelineView(.periodic)`) + live input stream + cancel button. For `bash` / `code_execution`, render stdout line-by-line.

3. **Web-search-specific `WebSearchProgressView`** — three phases: Querying (shows query + rotating globe), Reading sources (each URL appears as favicon+hostname chip as it's pulled), Synthesizing (fades into normal text). Citations parsed from `web_search_tool_result` into `sourceReferences` on complete.

**State additions to `ChatState`** (no new FFI): `activeToolPhase: Phase`, `activeToolStartedAt: Date`, `activeToolPartialInput: String`, `activeToolCitations: [WebCitation]`.

**Principle**: every event `StreamingDelegate` emits must become a visible, humanized UI pulse within 100ms. Silence during tool execution is the bug — not the backend, just the UI.

This becomes **Batch FF (expanded)** — originally TodoWrite checklist + context meter, now also these three live-tool layers.

---

## 14 · Refreshed batch priority (post-HH + post-research-4)

1. **DD.2-5** — reasoning tier wire-up for OpenAI/Anthropic/Google + Settings picker. Spec is fully documented in §3; just implementation.
2. **Batch EE** — route reasoning streams into the thinking popover (pairs with DD.2-4; adds the live "Thinking..." surface).
3. **Batch FF (expanded)** — TodoWrite checklist + context meter + live tool narration + animated tool cards (the "app feels dead" fix).
4. **Batch II** — capability manifest `Capabilities.md` + top-10 parity gap fills (starting with #2 Anthropic/Google web_search since that's the quickest ship).
5. **Batch GG** — embedded terminal view + bundled rg/fd (optional polish, only after FF lands).

Each batch stays on the same cadence: small commits, each tested, no mixing.

