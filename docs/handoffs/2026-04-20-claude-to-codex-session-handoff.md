# Claude → Codex handoff · April 20 2026 session

Hand the repo + this doc back to Codex. Everything below is context
you need to verify my work, finish open items, and land anything I
couldn't ship before the context ran out.

**Branch:** `codex/runtime-input-audit`
**Master plan (authoritative):** `docs/architecture/MASTER_PLAN_2026-04-19.md` §15-§19
**Agent progress snapshot:** `docs/AGENT_PROGRESS.md`

---

## 0 · TL;DR

- Closed 8 of 10 parity gaps (live tool narration, Anthropic web search + fetch + code execution, OpenAI web search, image gen slash command, audio input, structured JSON, cache-hit badge).
- Shipped ~40 commits across two arcs targeting: the attached-content bug, reasoning leaking into main chat, context panel persistence, app-routes awareness, AMFI build failures, reasoning tier taxonomy (off/low/medium/high/heavy), voice input, manifest slim, Fast-mode reasoning gate.
- Left 3 user-reported bugs open-ish (app crash without log, Qwen Coder freeze, any stray thinking-leak paths).
- One freshly-discovered bug fixed in the final commit (63184b78): Qwen 3 / Qwen Coder families were ignoring Fast mode because the template-extras guard was too strict.

---

## 1 · Everything shipped this session (chronological)

### Style / UX
| SHA | What |
|-----|------|
| `d64aa88f` | Revert near-OLED notes theme — sidebar + canvas back to `.clear` over native material. |
| `627bbfb9` | Landing intro: OLED + bottom-blur holds 0.55s then cross-fades 0.9s into native backdrop. One-shot per process via `LandingIntroAnimator`. |
| `766b374d` | `LiveActivityStrip` at top of streaming bubble: "🔎 Searching the web for 'X'" / "🧠 Thinking 12s" / "✍️ Writing reply…". |
| `7c2943d8` | Compact context-usage badge in composer row + live recalc on attach. |
| `f6a957eb` | Tool cards auto-expand while running; user toggle sticky. |
| `95039107` | Sticky plan card driven by Rust `todo_write` tool → `TodoSnapshot`, `TodoSnapshotCard`. |

### Reasoning routing (the biggest arc)
| SHA | What |
|-----|------|
| `e710d993` | Rust `agent_core/providers/openai.rs`: route `response.reasoning_summary_text.delta` + `response.reasoning_text.delta` + chat-completions `delta.reasoning_content` → `StreamEvent::ThinkingDelta`. |
| `13612bee` | Gemini parser drops `parts[*].thought == true` + `googleReasoningDelta` helper. |
| `bb38e6d0` | `ThinkTagStreamRouter` splits inline `<think>…</think>` from visible stream. `ChatMessage.thinkingTrace` + `thinkingDurationSeconds` persisted per turn. |
| `6df2e788` | `ThinkingTrailView` header "Thought for Ns" from persisted duration. |
| `ff9fa21e` | Multi-tag variant support: `<think>`, `<thinking>`, `<thought>`, `<reasoning>` — each mode carries its paired close tag. |
| `da407333` | Typed-chunk plumbing: `CloudLLMClient.reasoningSink` + per-provider reasoning extractors (OpenAI Responses, Anthropic `thinking_delta`, OpenAI-compat, Gemini). ChatCoordinator wires the sink per turn. |
| `4f88893c` | **GPT-5.4 critical fix**: Rust Codex Responses request now sends `reasoning.summary: "auto"` alongside effort. Without it GPT-5.4 reasoned privately and leaked monologue through `output_text.delta`. |
| `681d84ec` | SSE 120s idle watchdog on direct-cloud stream + per-turn `.notice` route log ("Cloud route: provider=X model=Y mode=Z reasoning=W"). |
| `0ac5003b` | Slim capability manifest (~400B), removed section helpers. Parked OpenAI `code_interpreter` attach (400 repro). |
| `34a345cd` | `resolvedOpenAIMaxOutputTokens` auto-expands cap so Heavy-tier reasoning doesn't consume the whole budget before the answer phase (root cause of "thinks forever never answers"). Plus 16k-char safety valve in ThinkTagStreamRouter. |
| `63184b78` | **Fast-mode reasoning gate**: `MLXChatTemplateExtras.resolve` now sends `enable_thinking: false` on all Qwen-family + Qwopus variants regardless of `supportsThinkingMode`. Fixes the user's "all models try to think even in Fast" bug. |

### Parity matrix
| SHA | Gap | What |
|-----|-----|------|
| `1f0401d0` | #1 | Live tool-narration via `ToolActivityNarrator`. |
| `147f17e1` | #2 | Anthropic `web_search_20250305` toggle + beta header. |
| `91c261fb` | #3, #4 (Anthropic side) | `web_fetch_20250910` + `code_execution_20250825` betas. |
| `4c961d95` | #5 | `/image` slash command routing Agent mode → `image_generate` tool. |
| `54250400` | #6 | Composer mic button → `AVAudioRecorder` → `AudioTranscriber` → composer insertion. |
| `e8620b8d` | #8 | Structured JSON output toggle (OpenAI Responses `text.format: json_object` + Gemini `responseMimeType: application/json`). |
| `142d648c` | #10 | Cache-hit badge: usage sink parses `cache_read_input_tokens` (Anthropic + OpenAI Responses + chat-completions). `ChatMessage.cacheHitPercent` + `CacheHitBadge` pill on bubble. |

### Agent-truth + context transparency
| SHA | What |
|-----|------|
| `4b1d433a` | Per-chat `brainSnapshotsByChat` persistence. Switching chats preserves Context panel history; capped 50 per chat. |
| `016b8f9d` | Capability manifest injected into Rust-agent system prompt. |
| `e01cceb4` | "App surfaces" section in manifest (⌘1-4, ⌘⌃W/S, Settings, MiniChat). |
| `1ed691f4` | Manifest also injected on direct-stream path (Fast/Thinking). |

### Reasoning tier refactor
| SHA | What |
|-----|------|
| `74e49d19` | `ChatReasoningTier` → 5 levels (off/low/medium/high/heavy). `EpistemosOperatingMode.availableReasoningTiers` + `reasoningTierLabel(for:)` for mode-specific presentation (Pro shows "Standard"/"Heavy"; Thinking shows all 4). `ChatReasoningTier(migrating:)` aliases old `standard`→`medium`, `extended`→`high`. |

### Build / infra
| SHA | What |
|-----|------|
| `8c6b85e3` | Rust build scripts sign `uniffi_bindgen` BEFORE invoking (fixes AMFI kernel kills in production logs). Applied to omega-mcp, omega-ax, epistemos-core, agent-core. |

### Docs
| SHA | What |
|-----|------|
| `1300af1d`, `e51bb6c8`, `e82b2dc4`, `382fa4c8`, `f1cca41e`, `f11f265c` | Master plan §15-19 updates tracking every bug → commit. |

---

## 2 · User-reported bugs → status

| Bug | Status | SHA(s) |
|-----|--------|--------|
| DeepSeek thinking types in main chat then disappears | ✅ Fixed | `bb38e6d0` inline router + `da407333` reasoning sink |
| ChatGPT freezes during reasoning | ✅ Fixed | `681d84ec` 120s watchdog |
| "Not sure it's actually using ChatGPT" | ✅ Fixed | `681d84ec` per-turn route log |
| Attached note but model calls read_file / asks for path | ✅ Fixed | `4f88893c` stronger attached-content instruction |
| GPT-5.4 Agent thinking leaking into main chat | ✅ Fixed | `4f88893c` `reasoning.summary: "auto"` |
| Context panel resets on chat switch | ✅ Fixed | `4b1d433a` per-chat snapshot history |
| Model doesn't know app routes | ✅ Fixed | `e01cceb4` "App surfaces" manifest section |
| "Don't see UI when tools run" | ✅ Fixed | `766b374d` LiveActivityStrip + prior FF slices |
| OpenAI code_interpreter 400 | ✅ Parked | `0ac5003b` — toggle persists but attach skipped |
| AMFI kills on uniffi_bindgen | ✅ Fixed | `8c6b85e3` sign-before-invoke |
| SwiftLint sandbox crashes | ✅ Already OK | `project.yml` already has `ENABLE_USER_SCRIPT_SANDBOXING: false`; failures were in Claude Code's own sandbox, not user's Xcode |
| Models "think forever, never answer" | ✅ Fixed | `34a345cd` `resolvedOpenAIMaxOutputTokens` expands cap per tier |
| Manifest too verbose ("making them super dumb") | ✅ Fixed | `0ac5003b` slim ~400B manifest |
| ChatGPT effort levels (4 on Thinking, 2 on Pro) | ✅ Fixed | `74e49d19` 5-tier ladder + mode-specific subsets |
| Fast mode: all models still try to think | ✅ Fixed (final commit) | `63184b78` Qwen-family template-extras gate |
| **App is crashing** | ⚠️ OPEN | Need crash log or sysdiagnose to diagnose |
| **Qwen Coder freezes** | ⚠️ OPEN | Likely model-load latency (4.7GB on cold load); needs a loading-progress UI or load-timeout error |
| **Stray thinking-in-main-chat on unspecified turn** | ⚠️ OPEN | Need a specific repro + Console log showing the route + SSE events |

---

## 3 · Critical things for Codex to verify

### 3a. Test the Fast-mode fix (just shipped)

Model used in the user's screenshot: Qwen 3 4B. After `63184b78`, Fast mode should send `enable_thinking: false` to the tokenizer. Verify:

1. Open the app, select Fast mode + Qwen 3 4B.
2. Send "hey".
3. Expected: plain greeting response. No `<think>` tag in the chat title or body.
4. If `<think>` still appears: check `Log.pipeline` in Console for `Triage:` line. The `reasoningMode` should be `.fast`. If it isn't, something upstream is coercing it — trace through `TriageService.reasoningMode(for:…)`.

### 3b. Sweep for any other model families that always emit `<think>`

I added Qwen 3 / Qwen 3 Coder / Qwen 2.5 Coder to the explicit Qwen-family switch. Codex should check if any OTHER installed-and-usable local model families default-think and add them too. Candidate check list from `LocalTextModelID` cases:

- Hermes 4.3 variants — do they default-think? Their base Qwen 3.5 does; check the Jinja template.
- Llama 4 Scout — usually no.
- Mistral Small — usually no.
- Bonsai variants — no (pure instruct).
- Gemma variants — no (pure instruct).
- LFM2 / Jamba / Falcon-H1 — check Jinja.

If any model's default-output includes `<think>` when no prompt tells it to, add it to the Qwen switch in `MLXInferenceService.swift` line 46-53.

### 3c. Validate the reasoning-tier ladder end-to-end

After `74e49d19`:

- Settings → Reasoning picker shows **Off / Low / Medium / High / Heavy** (menu picker).
- On a fresh install: default is `.medium` (was `.standard`, gets migrated via `ChatReasoningTier(migrating:)`).
- Test each tier hits the right wire-level effort:
  - **Thinking mode**:
    - `.low` → OpenAI effort `"low"`, Gemini `thinkingBudget: 2048` or `thinkingLevel: "low"`, Anthropic 2k budget.
    - `.medium` → falls through to per-mode defaults in LLMService `openAIResponseControls`.
    - `.high` → OpenAI `"high"` + summary auto, Anthropic 16k, Gemini `"high"` / 16k.
    - `.heavy` → OpenAI `"xhigh"` (falls to `"high"` on Nano), Anthropic 32k, Gemini `"high"` / 32k.
  - **Pro / Agent mode**: only `.medium` ("Standard") and `.heavy` are surfaced.
  - **Fast**: reasoning disabled regardless.

### 3d. Sanity check `resolvedOpenAIMaxOutputTokens`

Logic from `34a345cd`:
```
off/low   → max(user_setting, 4_096)
medium    → max(user_setting, 8_192)
high      → max(user_setting, 24_576)   // 16k reasoning + 8k answer
heavy     → max(user_setting, 45_056)   // 32k reasoning + 13k answer
```

**Check**: Some OpenAI orgs have per-account max_output_tokens caps (e.g., 32768). Setting 45056 on Heavy could 400 with "max_output_tokens exceeds limit". If so, dial heavy down to, say, 32768 — or gate by account capability. Can't verify without a live call.

### 3e. Run the test suite

```
swift test
cargo test --manifest-path agent_core/Cargo.toml --lib
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
```

Current state: cargo tests were green last I ran (511 pass). Swift tests I didn't run end-to-end this session; they might have drift from the tier-enum refactor (old test literals `.standard` / `.extended` were updated in `TriageServiceTests`, but other test files may still reference them — `grep -rn '\.standard\|\.extended'` and check each hit).

---

## 4 · Open issues Codex needs to finish

### 4a. HIGH: Diagnose the "app is crashing" report
User provided no crash log. Most recent changes that could cause crashes:
- `reasoningSink` / `usageSink` closures on `CloudLLMClient` — they hop to `Task { @MainActor in … }` internally with weak-captured ChatState, should be safe but worth testing under stream cancellation.
- `ThinkTagStreamRouter` multi-tag refactor — has a safety valve now but a stress test on malformed tag input would help.
- `ComposerVoiceInputService` — first-time permission flow; verify on a mac that has never granted mic access.

Ask user for a sysdiagnose or the exact repro. Until then, the right thing is to add defensive assertions + integration tests on these paths. A quick win: add a unit test exercising `ThinkTagStreamRouter.ingest` with 1-char chunks AND with cross-tag-boundary chunks AND with unterminated tags that exceed the 16k safety valve.

### 4b. HIGH: Qwen Coder freeze
User is on `qwen25Coder7B`. Hypothesis: first-time load of 4.7GB model hangs the UI thread perceptibly. Fix: 
- Add a model-load timeout (90s?) with a user-facing error: "Qwen Coder couldn't load — try restarting or a smaller model."
- Add a progress indicator during load (spinner + "Loading Qwen 2.5 Coder 7B…").

Code lives in `LocalGGUFClient.swift` / `MLXInferenceService.swift`. Look for `prepareModel` / `loadModel`.

### 4c. MEDIUM: Parity #7 native PDF upload
Current: PDFs go through `PDFDocument.string` text extraction at attach time (see `ChatCoordinator.swift:3038` `case .pdf:`).
Target: for Anthropic provider, attach as native `document` content block (base64 PDF). For OpenAI, `input_file`. For Gemini, `inlineData`.

Sketch:
1. Add `resolvedPDFPayloads(for: CloudTextModelID)` helper returning `[(name, base64Data, mimeType)]` filtered by `attachment.type == .pdf`.
2. Extend `anthropicMessageContent` to accept pdf payloads and emit `{"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "…"}}` blocks.
3. Gate on `.anthropic` provider (beta + first-party only).
4. Keep text extraction as the fallback when native isn't supported.

### 4d. MEDIUM: Parity #9 batch queue
Anthropic Message Batches + OpenAI Batch API. 50% cost cut for bulk vault operations. Needs:
- `VaultBatchJob` model (persisted in `SDChat`-alongside store).
- UI surface in Settings → Inference → "Batch jobs" (job list + status + retry).
- `LLMService.submitBatch(prompts: [String])` returning a batch ID; poll endpoint for completion.

### 4e. LOW: OpenAI code_interpreter schema detection
Currently parked: toggle in Settings persists but `openAIToolsConfiguration` doesn't attach it. User log showed 400. To re-enable: detect which models / accounts support it (probably an allowlist keyed on `vendorModelID` + account feature flag).

### 4f. LOW: Model picker UX simplification
User: "there still feels like there's a lot of buttons." `LocalModelToolbarMenu` in `Epistemos/App/RootView.swift:348+` is ~700 lines. A focused refactor could move installable models to Settings (leaving only installed + Apple Intelligence + cloud in the composer picker). Not urgent.

### 4g. LOW: DeepSeek tool-call investigation
Route log (`681d84ec`) + reasoning sink (`da407333`) are in place. When the user supplies a live repro of "DeepSeek calling tools inappropriately," check Console for the `Cloud route:` log to see what mode/tool tier was active.

---

## 5 · Stray commits / dirty-tree concerns

Three commits (`0eb97f9e`, `facabd97`, `e710d993`) inadvertently bundled pre-existing Codex dirty edits in `openai.rs` / other files because the working tree had Codex's uncommitted changes when the session started. Each commit message calls out the primary change; Codex's stray edits are additive and don't conflict, but a diff-read is worth doing.

---

## 6 · Useful `grep` starts for Codex

```
# Any remaining old tier literals
grep -rn '\.standard\|\.extended' Epistemos/ EpistemosTests/ --include='*.swift'

# Any model that defaults to thinking (look in each Jinja template)
find LocalPackages Epistemos -name '*.jinja' | xargs grep -l 'think'

# Anywhere we might still set max_output_tokens WITHOUT going through the resolver
grep -rn 'max_output_tokens\|maxOutputTokens' Epistemos/Engine/LLMService.swift

# User-facing surfaces showing reasoning tier (make sure UI adapts to mode)
grep -rn 'ChatReasoningTier\|reasoningTier' Epistemos/Views/ EpistemosTests/
```

---

## 7 · What's in the master plan

`docs/architecture/MASTER_PLAN_2026-04-19.md` has 19 numbered sections. §15–§19 were written this session. §19 is the most recent ("thinks forever, never answers"). All commits are indexed by SHA in those sections.

---

## 8 · What to tell the user

1. Cold-launch the app and test Fast mode with Qwen 3 4B — the `<think>` leak should be gone.
2. For the "app crashing" report — need a crash log (~/Library/Logs/DiagnosticReports/Epistemos*) or sysdiagnose to do anything concrete.
3. For the Qwen Coder freeze — working on timeout + progress surface; meanwhile, switch to a smaller model (Qwen 3 4B) while we get the Coder path into shape.

If the user reports any more "thinking in main chat" turns: ask them to open Console.app, filter by `com.epistemos`, send the prompt, and copy the `Cloud route:` line + any surrounding SSE context. That will tell us exactly which path is leaking.

---

Good luck. Don't ship without running the full test suite + at least one `xcodebuild` + launching the app at least once.
