# Codex -> Claude handoff · April 22 2026 · live runtime finish + architecture asks

> **Index status**: CANONICAL-HISTORICAL — Session handoff; kept for state recovery (30-day minimum). No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Purpose: this is the source-of-truth handoff for Claude to continue the
real-app walkthrough on the current Xcode build, finish the remaining
runtime blockers, and then pick up the user's next product asks without
losing the actual evidence gathered so far.

If any older handoff conflicts with this one, prefer this file plus the
latest repo state.

---

## 0. Read first

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-20-codex-to-claude-full-thread-handoff.md`
4. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-20-codex-to-claude-release-blockers-handoff.md`
5. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-20-claude-to-codex-verification.md`
6. This file

Branch:
- `codex/runtime-input-audit`

Current commit when this handoff was written:
- `9dbe4707`

Mandatory rule:
- treat this as release-audit work, not a casual smoke pass
- logs and runtime evidence are required
- do not call the app ready without repeated zero-fail verification

Project-file rule:
- the user still wants the Xcode project aligned through generation
- prefer generated-project flow if project membership changes are needed
- do not hand-maintain `project.pbxproj` unless there is no alternative

---

## 1. What the user wants next

Claude should treat these as the active directives, in order:

1. Use the new Xcode-run app, not an older copied app bundle.
2. Do another real walk-through with Computer Use on the current build.
3. Test all local models installed on this laptop that the app can
   honestly support on this hardware.
4. Test the curated cloud set only:
   - OpenAI: `GPT-5.4`, `GPT-5.4 Mini`
   - Anthropic: `Claude Opus 4.7`, `Claude Sonnet 4.6`
   - Google: `Gemini 3.1 Pro`, `Gemini 3 Flash`
5. Verify tool use across Main Chat and Mini Chat, including the user's
   baseline expectations:
   - read/write files
   - read/write inside vault
   - create/read/update notes
   - operate on folders where supported
   - read/write outside the vault where intended
   - approval deny path
   - no weird raw tool leakage in UI
6. Test the full tool surface, which the user believes is `33` tools
   plus related skills/native controls.
7. Make the app more minimal and honest:
   - keep only the important cloud providers surfaced
   - keep the model selector simpler
   - hide unsupported or subpar options instead of letting them fail
8. Continue the product work the user described:
   - worker-style execution, not just chat
   - app-managed diff/history and recovery without requiring git
   - vault-visible chat transcripts
   - model vault visibility in Notes sidebar
   - persistent model/provider "involvement" memory and authorship

Important nuance from the user:
- Google is rate-limited right now, so Anthropic/OpenAI/local should be
  the priority for live validation.
- The user believes Anthropic and OpenAI keys are already configured on
  the current build.
- The user wants the app to feel minimal, but not stripped-down or
  broken.

---

## 2. Current repo and worktree reality

The tree is dirty. Do not broadly stage or revert.

At handoff time, `git status --short` showed these modified files:

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/RootView.swift`
- `Epistemos/Engine/AgentHarness/ChatCapability.swift`
- `Epistemos/Engine/Extensions.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Graph/EmbeddingService.swift`
- `Epistemos/Graph/GraphState.swift`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Models/ChatTypes.swift`
- `Epistemos/State/AgentChatState.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/State/ThreadState.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Views/MiniChat/MiniChatView.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/AuditFixRegressionTests.swift`
- `EpistemosTests/BlockEmbeddingTests.swift`
- `EpistemosTests/ChatCapabilityIntentTests.swift`
- `EpistemosTests/CloudProviderAuthServiceTests.swift`
- `EpistemosTests/HermesPromptBuilderTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/MiniChatViewAuditTests.swift`
- `EpistemosTests/OmegaToolCallParserTests.swift`
- `EpistemosTests/PipelineServiceTests.swift`
- `EpistemosTests/ProductionHardeningTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/TriageServiceTests.swift`
- `EpistemosTests/UserFacingModelOutputTests.swift`
- `agent_core/src/providers/claude.rs`
- `docs/architecture/PERF_REPAIR_REPORT_2026_04_21.md`
- `scripts/launch_audit_app.sh`

Do not assume all of these belong to one clean batch. Read before
touching. Preserve user work.

---

## 3. What Codex already changed in this pass

### 3.1 Curated cloud surface and simplified model exposure

Files:
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- `Epistemos/App/RootView.swift`
- `agent_core/src/providers/claude.rs`

What changed:
- visible cloud providers in normal UI were pared down to:
  - Anthropic
  - OpenAI
  - Google
- visible cloud models were pared down to:
  - Anthropic: `Claude Opus 4.7`, `Claude Sonnet 4.6`
  - OpenAI: `GPT-5.4`, `GPT-5.4 Mini`
  - Google: `Gemini 3.1 Pro`, `Gemini 3 Flash`
- Anthropic provider IDs were updated to the new models
- settings/runtime controls now route through the curated lists instead
  of the larger old catalog

### 3.2 Qwen 3 picker simplification

File:
- `Epistemos/State/InferenceState.swift`

What changed:
- Qwen fast and thinking variants were reworked toward a unified `Qwen
  3` presentation with mode-aware routing
- intended behavior is one simplified entry with fast/thinking behavior
  exposed cleanly instead of two confusing near-duplicates

This is not fully live-verified yet. See section 7.

### 3.3 Local tool-loop repair work

Files touched in this area:
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/Extensions.swift`
- related tests under `EpistemosTests/`

What was addressed:
- the earlier parser/repair-path issue is no longer the main blocker
- focused local-agent tests around repair/tool-loop behavior passed
- raw fenced language junk like dangling code-fence markers was patched
  so it is less likely to leak as visible output

Important:
- code-side repair is better, but the remaining blocker is still the
  live runtime behavior in the actual app

### 3.4 Test expectation repairs for the simplified model surface

Files:
- `EpistemosTests/LocalModelInfrastructureTests.swift`
- `EpistemosTests/TriageServiceTests.swift`

What changed:
- updated expectation mismatches around the simplified model/mode
  catalog so the focused assertions line up with the new curated
  behavior

---

## 4. What is verified green already

These claims are based on actual live checks or direct verification,
not guesses.

### 4.1 Current build path exists

Verified app bundle path:
- `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`

Claude should prefer the app the user launches from Xcode. If a copied
app bundle is used for convenience, it must be refreshed from this
current build, not an older stale copy.

### 4.2 Curated provider/model surface is live in the app

Using Computer Use on the updated build, the regular settings surface
showed only:

- Anthropic
- OpenAI
- Google

And model lists were narrowed to:

- Anthropic: `Claude Opus 4.7`, `Claude Sonnet 4.6`
- OpenAI: `GPT-5.4`, `GPT-5.4 Mini`
- Google: `Gemini 3.1 Pro`, `Gemini 3 Flash`

Older cloud providers such as DeepSeek/Z.AI/Kimi/MiniMax were no longer
present in the normal user-facing picker flow.

### 4.3 Anthropic key is valid

This was verified outside the app:

- keychain item exists under service `app.epistemos`
- Anthropic API key account is `epistemos.anthropic.apiKey`
- direct request to Anthropic `GET /v1/models` returned `HTTP 200`
- returned model IDs included:
  - `claude-opus-4-7`
  - `claude-sonnet-4-6`

Interpretation:
- the Anthropic key is not inherently broken
- if the app still says it was never used or not verified, that is app
  validation/UI state behavior, not proof of a bad key

### 4.4 Some live file-tool behavior worked

Earlier live smoke results on an updated build showed:

- Mini Chat in-vault `write_file` + `read_file` round-trip succeeded
- Main Chat in-vault `write_file` + `read_file` round-trip succeeded

Those successful runs were also corroborated via real tool-execution
records, not just chat text.

Tool execution DB path:
- `/Users/jojo/Library/Application Support/Epistemos/omega_executions.db`

---

## 5. What is still failing or not trustworthy

These are still open and should be treated as ship blockers until
verified otherwise.

### 5.1 Local live tool loop is not fully stable

The remaining problem is no longer "parser cannot understand tool
calls." The remaining problem is:

- live local model turns can still produce unusable output
- the model/tool round-trip can stall
- the app can fall into a bad runtime state during the real loop

### 5.2 Outside-vault access is not yet trustworthy

Earlier live manual results showed:

- Mini Chat outside-vault read did not execute a real tool call and
  ended with a turn-limit failure
- Main Chat outside-vault read stalled before a real tool execution

So:
- in-vault file tooling has evidence
- outside-vault behavior still needs real validation or fixes

### 5.3 Note creation is not trustworthy yet

Earlier live check:
- Main Chat answered as if it created a note
- no note was actually found in the vault afterward
- the vault-side evidence did not support the assistant claim

Interpretation:
- there may still be note-tool hallucination, failed note persistence,
  or incorrect success reporting

### 5.4 Final in-app Anthropic verification is incomplete

Direct API verification succeeded, but the clean in-app `Check Access`
flow was not finished due the live runtime issues described below.

### 5.5 Qwen 3 unified picker is not fully verified live

The logic is in code, but the live build session that was checked only
surfaced `DeepSeek R1 7B` as the active local runtime. The expected
collapsed `Qwen 3` selector did not appear in that session.

This still needs:
- discovery verification
- install/selection verification
- fast/thinking visibility verification
- actual tool-use verification on the surfaced Qwen variants

### 5.6 Broader test sweep is not green yet

Focused runs improved, but the broader test/build story is still not
clean enough for a ship claim.

Observed state:
- focused local-agent/tool tests passed earlier in the session
- focused model/auth tests no longer showed the two assertion
  mismatches that were repaired
- but `xcodebuild` still ended with exit code `65` because of existing
  SwiftLint script-phase failures

Do not collapse this into "tests are green."

---

## 6. Exact runtime blocker discovered in the real app

This is the biggest remaining release blocker from the latest live pass.

During the walkthrough on the rebuilt app:

- Xcode showed the app around `98-100% CPU`
- memory climbed from about `3.3 GB` to `4.0 GB`
- the app became effectively unresponsive
- Xcode console logged repeated:
  - `Internal inconsistency in menus`
- memory-pressure warnings also appeared

A process sample was captured here:
- `/tmp/Epistemos_2026-04-22_155736_eHeO.sample.txt`

High-level interpretation from the sample:
- the main thread was stuck in SwiftUI layout/update work
- this did not look like a harmless attach glitch

The runaway process was then terminated to stop it chewing the machine.

This is the main blocker Claude should investigate before trusting any
final manual-validation outcome.

---

## 7. Local model inventory notes

Model assets exist on disk under:
- `/Users/jojo/Library/Application Support/Epistemos/Models/text/hub`

Confirmed local model directories included at least:

- `models--Qwen--Qwen3-4B-MLX-4bit`
- `models--mlx-community--Qwen3-4B-Thinking-2507-4bit`
- `models--Qwen--Qwen3-8B-MLX-4bit`
- `models--mlx-community--Qwen3-Coder-Next-4bit`
- `models--mlx-community--Qwen3.5-4B-4bit`
- `models--mlx-community--Qwen3.5-9B-4bit`
- `models--mlx-community--DeepSeek-R1-Distill-Qwen-7B-4bit`
- `models--mlx-community--gemma-3-4b-it-qat-4bit`
- `models--mlx-community--gemma-4-e4b-it-4bit`
- `models--mlx-community--gemma-4-26b-a4b-it-4bit`
- `models--dealignai--Gemma-4-31B-JANG_4M-CRACK`
- `models--mlx-community--Llama-3.2-3B-Instruct-4bit`

Implication:
- local assets are present
- live availability and picker exposure still need to be verified in the
  running app profile

User intent:
- Claude should test all local models that the laptop can realistically
  run and that the app exposes honestly
- if a local model cannot support tools or certain modes, the UI should
  make that explicit or hide unsupported states cleanly
- the user is okay deprioritizing the coder model if it is still a
  memory-risk outlier, but that should be an explicit choice, not a
  silent failure

---

## 8. Anthropic key clarification

This should be treated as settled unless live evidence contradicts it:

- the Anthropic key is stored in keychain
- the direct Anthropic API probe succeeded
- the "never used" / "saved but not verified" state is likely because
  the app only marks the provider verified after its own live
  `Check Access` request succeeds

If the app still claims Anthropic is not verified after a real in-app
validation attempt on a healthy runtime:
- that is an app bug in validation/state plumbing or UI messaging
- it is not evidence that the user's Anthropic API key is invalid

Claude should verify the live app path end-to-end and fix the in-app
truthfulness if needed.

---

## 9. Claude's live validation matrix

Use the user's new Xcode-run build. Do not test against a stale copied
app bundle.

### 9.1 Launch/runtime discipline

1. Have the user run the app from Xcode or attach to the current Xcode
   run target.
2. Use Computer Use on that live window only.
3. Keep logs open while testing.
4. Correlate visible tool behavior with:
   - runtime logs
   - tool execution records in
     `/Users/jojo/Library/Application Support/Epistemos/omega_executions.db`
   - actual filesystem/vault outcomes

### 9.2 Cloud model matrix

OpenAI:
- `GPT-5.4`
- `GPT-5.4 Mini`

Anthropic:
- `Claude Opus 4.7`
- `Claude Sonnet 4.6`

Google:
- `Gemini 3.1 Pro`
- `Gemini 3 Flash`

For each cloud model, verify at minimum:
- selection works
- provider-native controls render correctly
- control changes persist and are respected
- prompt/response works
- tool calls render cleanly
- no raw malformed tool text leaks
- approval flows are honest
- failures are surfaced honestly

Google note:
- user says Google is rate-limited right now
- do not block the rest of the pass on Google quota

### 9.3 Local model matrix

Test all local models that actually surface and are plausible on current
hardware. At minimum, prioritize:

- unified `Qwen 3` flow
- `DeepSeek R1 7B`
- other surfaced Qwen/Gemma/Llama variants

For each local model:
- verify install/detection state
- verify visible supported modes
- verify unsupported modes are hidden, not just broken
- verify prompt/response quality at a basic level
- verify whether tools work or are intentionally unsupported
- if tools are unsupported, the UI must make that clear

### 9.4 Surface matrix

Test both:
- Main Chat
- Mini Chat

If note-attached/agentic surfaces are part of the same tool stack in the
current branch, spot-check them too, but Main and Mini are the baseline.

### 9.5 Tool matrix

The user wants the full tool surface tested, which they believe is
`33` tools plus related skills/native actions.

At minimum validate these categories:

- file read/write
- folder create/list/mutate
- note create/read/update
- inside-vault operations
- outside-vault operations where intended
- approval allow path
- approval deny path
- tool result rendering
- no raw XML/fence/tool-call junk shown as final answer
- skill/native control invocation if those are exposed through the same
  runtime surface

Do not count a conversational claim as success. Check the side effects.

### 9.6 Specific smoke tests that must be rerun

1. Mini Chat in-vault `write_file` + `read_file`
2. Main Chat in-vault `write_file` + `read_file`
3. Mini Chat outside-vault read
4. Main Chat outside-vault read
5. Note creation from chat
6. Approval deny path
7. Anthropic `Check Access`
8. OpenAI live tool-use pass
9. Qwen 3 fast vs thinking live selector behavior
10. idle memory after model unload/use

---

## 10. Release-audit expectations for Claude

Do not stop at UI checking. The release-audit skill still applies.

Minimum automated commands to rerun when appropriate:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd omega-mcp && cargo test
cd omega-ax && cargo test
```

Reality from this pass:
- full clean green was not achieved yet
- script-phase SwiftLint failures were still preventing a trustworthy
  all-green `xcodebuild test` exit

If Claude fixes anything:
1. explain root cause
2. rerun evidence
3. reset confidence
4. do not call the app ready until the rerun is clean

---

## 11. Architecture workstream A: worker mode, not just chat

The user asked for a mode closer to Claude/Codex desktop behavior:

- an actual worker
- can install things
- can run terminal commands
- can manipulate files and tools
- all from inside the app
- not "just a chat box"

Codex did not implement this yet in this pass.

Claude should treat this as a research-first product/architecture task.

Recommended direction:

1. Audit what already exists in:
   - `Epistemos/Engine/AgentHarness/`
   - `Epistemos/Omega/`
   - `Epistemos/State/AgentChatState.swift`
   - `Epistemos/App/ChatCoordinator.swift`
2. Define a real worker/session abstraction rather than stretching
   standard chat bubbles.
3. Prefer a design with:
   - persistent worker/job session identity
   - PTY/terminal execution ownership
   - explicit tool broker
   - permission/approval boundaries
   - artifact/log pane
   - durable session history
4. Keep the app surface minimal and native. The user wants power without
   bloat.

The right end state is likely closer to "task session with logs and
actions" than "super chat bubble."

---

## 12. Architecture workstream B: app-managed history, diff, and model memory

The user wants the app to become a place where thought never dies or
gets lost. They explicitly asked for:

- app-managed backup/diff per file/note/chat
- less dependence on git for day-to-day recovery/history
- every chat auto-materialized as a markdown transcript in the vault
- model-specific vaults visible in the Notes sidebar
- model/provider/family visibility in the Notes sidebar
- per-model "involvement" or authorship memory for substantive AI
  contributions
- strong user visibility and control
- minimal UI and no performance regression

Codex did not implement this yet in this pass.

### 12.1 Existing code that matters

Audit these first before designing anything new:

- `Epistemos/Vault/ConversationPersistence.swift`
- `Epistemos/Vault/SessionBrowser.swift`
- `Epistemos/Vault/VaultLifecycleService.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/State/ChatState.swift`
- `Epistemos/Views/Notes/NotesSidebar.swift`
- `Epistemos/Views/Notes/NotesBrowserView.swift`

Existing evidence:
- `ConversationPersistence` already appends structured turns and can
  generate companion markdown
- model vault directories already exist under app support on disk
- Notes sidebar is performance-sensitive and intentionally denormalized
  to avoid observation churn

### 12.2 Recommended implementation direction

Research first, then implement minimally.

Likely good direction:

1. Build an app-owned content history layer:
   - snapshot + diff ledger
   - explicit authored-change metadata
   - human/model/provider/model/tool provenance
2. Materialize vault-visible chat transcript notes automatically from
   the existing conversation persistence path.
3. Add a lightweight Notes sidebar surface for:
   - model vaults
   - provider buckets
   - transcript notes
   - "involvement" views
4. Avoid expensive live scans in sidebar rows. Reuse cached/value-style
   display patterns already present in `NotesSidebar.swift`.
5. Keep the UX minimal:
   - visible
   - inspectable
   - reversible
   - not cluttered

### 12.3 Product truthfulness requirement

If the app claims:
- a note was created
- a chat was transcribed
- a model authored a contribution
- a backup/diff exists

then Claude must verify the persisted artifact actually exists and is
visible where the UI says it is.

---

## 13. Suggested order of operations for Claude

1. Reopen the current Xcode-run app and reproduce the live hot-loop if
   possible.
2. Fix or isolate the hot-loop/runtime stall first.
3. Complete in-app Anthropic verification.
4. Re-run Main Chat and Mini Chat tool smoke passes.
5. Verify local-model surface exposure, especially unified `Qwen 3`.
6. Test the curated cloud set on healthy runtime.
7. Expand to the full tool matrix.
8. Only after runtime/tool truth is solid, begin the architecture
   expansion work for worker mode and durable history/memory.

Reason:
- otherwise Claude will be building new product layers on top of a live
  runtime that still cannot be trusted

---

## 14. Definition of done

Claude should not call this finished until:

1. the current Xcode-run app is the one actually tested
2. the hot-loop/hang path is fixed or crisply explained
3. Anthropic verifies in-app honestly
4. OpenAI and Anthropic cloud tool flows are verified on the live app
5. local model support is verified honestly per surfaced model
6. Main Chat and Mini Chat both pass real baseline tool operations
7. unsupported tools/modes are hidden or explicitly described
8. broader automated verification is rerun
9. the app-managed history/memory design is researched before coding
10. any implemented architecture work stays minimal and does not degrade
    Notes sidebar performance or overall UX

Until then, verdict remains:
- `NOT READY`

