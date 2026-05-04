# Codex Continuation Prompt - 2026-04-18

> **Index status**: CANONICAL-OPERATIONAL — Codex continuation paste template for codex/runtime-input-audit branch; dirty tree warnings + model/runtime batch files.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



Paste the prompt below into a fresh Codex session in this repo.

---

You are continuing an in-progress Epistemos audit/fix session in `/Users/jojo/Downloads/Epistemos` on branch `codex/runtime-input-audit`.

Read these first:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/docs/CODEX_HANDOFF_2026-04-18.md`
3. `/Users/jojo/Downloads/Epistemos/docs/CODEX_CONTINUATION_PROMPT_2026-04-18.md`

Work in the current dirty tree. Do not revert or clean unrelated changes. Audit in small batches, test each batch, and commit as you go so the work remains reviewable.

## Current reality

- Branch: `codex/runtime-input-audit`
- The tree is very dirty with many pre-existing Codex changes. Treat unrelated modifications as off-limits unless they are part of the exact batch you are validating.
- There is an older staged runtime/model batch that was intentionally left separate. Do not accidentally mix it into the routing/UI commits.

Previously staged runtime/model batch that should stay separate until explicitly validated:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalRustRuntime.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/ModelDownloadManager.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/EngineTypes.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Models/SDMessage.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ModelAboutSheet.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalRuntimeSmokeSupport.swift`

Do not stage `/Users/jojo/Downloads/Epistemos/EpistemosTests/ThemePairTests.swift` with the current batch. It has unrelated dirty changes.

## User priorities

The user wants concrete fixes first, then a deeper cleanup plan.

Immediate product issues to fix and verify:

1. Chat routing/mode picker feels broken.
   - Selecting Fast / Thinking / Pro / Agent sometimes still looks stuck on Auto Route.
   - The chat surface needs a clear on/off auto-route toggle.
   - When auto-route is on, the UI should explicitly show the stack, for example:
     - fast local model
     - reasoning local model
     - cloud escalation model
   - When auto-route is off, the chat picker should react immediately and let the user explicitly choose local or cloud models without confusing hidden routing.
   - Settings and the in-chat picker must stay in sync.

2. One cloud model path is producing typo-heavy, incoherent replies.
   - Screenshot evidence showed malformed prose like dropped glue words and fused fragments.
   - Fix the most plausible backend/request-shaping cause first, with tests.

3. Longer-term UX cleanup to plan after the immediate regressions:
   - Unified chat currently feels like a black box.
   - The user wants a toggleable side panel that shows what is in context:
     - loaded context
     - ambient retrieval
     - other "brain of the app" inputs
   - They also want cleaner model-role assignment:
     - overseer / triage model
     - fast local
     - reasoning local
     - cloud reasoner
     - cloud agent
     - research/web role
  - They want Perplexity-like "things just work" behavior without losing beneficial retrieval/context.
   - Do not implement a huge architecture rewrite before stabilizing the regressions. Finish the audited fixes first, then write a concrete follow-up plan.

## In-flight fix batches already edited

### Batch A - routing UX / explicit stack / picker-state cleanup

These files already contain edits and need validation plus a clean commit if tests pass:

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ChatBrainPickerMenu.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/TriageServiceTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ChatPresentationTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`

What these edits do:

- Add `ChatSurfaceRouteDescription` so the UI can show the real route per operating mode.
- Persist `cloudAutoFallback`.
- Add:
  - `chatAutoRouteActive`
  - `chatSurfaceRouteDescription(for:)`
  - `cloudModels(for:)`
  - `setCloudAutoFallback(_:)`
  - `setPreferredCloudModel(_:)`
- Make the shared runtime popover in `RootView.swift` show:
  - `Auto-route local -> cloud`
  - `Auto-route on failure`
  - explicit route cards per mode
  - provider/model disclosures that behave differently when auto-route is on vs off
- Make `ChatBrainPickerMenu` delegate to the shared `LocalModelToolbarMenu` so main chat and landing match the other chat surfaces.
- Update Settings -> Inference to show the current stack when auto-route is on, and to bind cloud model selection to `preferredCloudModel(for:)` instead of silently reverting to provider defaults.
- Add/adjust tests for the new routing behavior and persistence.

Important note:

- `TriageServiceTests.swift` already includes a fixed persistence test for `cloudAutoFallback` that uses real `UserDefaults.standard` save/restore around the single key instead of the isolated helper that was masking persistence.

### Batch B - cloud reply quality / typo-heavy OpenAI Codex path

These files already contain edits and need validation plus a separate clean commit if tests pass:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/TriageService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CloudProviderAuthServiceTests.swift`

What these edits do:

- `LLMService.swift`
  - `openAIResponseControls(...)` now takes `credential`.
  - It only applies GPT-5 native `reasoning` / `text.verbosity` controls for real OpenAI API key requests.
  - It omits those controls for the ChatGPT/Codex account backend (`/backend-api/codex/responses`), which is the most plausible cause of degraded prose quality on that path.
- `TriageService.swift`
  - Adds `Use polished spelling and grammar.` to the shared cloud baseline system prompt.
- `CloudProviderAuthServiceTests.swift`
  - Adds a regression test asserting that OpenAI Codex account requests:
    - hit `/backend-api/codex/responses`
    - keep the GPT-5 model id
    - omit `reasoning`
    - omit `text`

Important compile note:

- A previous compile error in `LLMService.swift` was already fixed by changing the body of `openAIResponseControls(...)` to `return switch model { ... }` after the new credential guard.

## Most recent validation history

Known facts from the previous session:

1. A focused Swift run earlier exposed one real failure in the new routing work:
   - `cloudAutoFallback persists across inference state reloads`
   - that test has already been fixed in `TriageServiceTests.swift`

2. A later test run failed because the first `LLMService.swift` patch had an incomplete `switch`.
   - that compile issue was already fixed

3. After the compile fix, a new focused rerun was launched but its final result was not captured before the session became unstable.
   - Session id in the old terminal run was `83203`
   - Do not trust it blindly
   - Rerun the focused suites from scratch

## First actions in the new session

Do this in order:

1. Check `git status --short` and confirm the exact files above are still the intended in-flight batches.
2. Rerun the focused Swift validation from scratch:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-routing-ux-rerun \
  test \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/ChatPresentationTests \
  -only-testing:EpistemosTests/RuntimeValidationTests \
  -only-testing:EpistemosTests/CloudProviderAuthServiceTests
```

3. If that run fails:
   - fix only the exact reported failures
   - rerun the same focused set

4. If that run passes:
   - stage and commit Batch A first:
     - `InferenceState.swift`
     - `RootView.swift`
     - `ChatBrainPickerMenu.swift`
     - `SettingsView.swift`
     - `TriageServiceTests.swift`
     - `ChatPresentationTests.swift`
     - `RuntimeValidationTests.swift`
   - then stage and commit Batch B second:
     - `LLMService.swift`
     - `TriageService.swift`
     - `CloudProviderAuthServiceTests.swift`

5. Keep the older staged runtime/model batch separate unless you validate it in its own pass.

6. After those commits, continue auditing the rest of the dirty tree in intentional batches, testing and committing as you go.

## Commit sequencing guidance

The user explicitly asked for work to be audited in batches and committed gradually for coverage and traceability.

Follow that.

Good next order after the two current batches:

1. finish the routing UX + cloud-quality commits
2. validate and commit the older runtime/model batch if it is still the right next slice
3. continue through retrieval/indexing/workspace-context files as a separate audit slice
4. continue through remaining app/settings/note/graph clusters as separate slices
5. only after the regression cleanup, write the bigger unified-chat transparency plan

## Additional context to preserve

Architecture concern discovered earlier:

- The app effectively has multiple routing layers and the user experience now obscures too much of that complexity.
- The user wants the eventual fix direction to make routing feel trustworthy and visible, not magical-but-broken.

Do not lose this follow-up design brief:

- move toward explicit model roles
- make routing legible
- expose loaded context and retrieval in a "brain/context" side panel
- preserve local-first behavior where possible
- consider hybrid triage/orchestration if needed
- keep the UX simple and reactive, more like Perplexity's "just works" feel

But again: stabilize and audit the concrete regressions first.

## Communication / workflow rules

- Use short commentary updates while working.
- Before edits, explain what batch you are about to change.
- Prefer minimal fixes over refactors.
- Use `apply_patch` for manual code edits.
- Do not touch `~/Epistemos-RETRO/`, `src-tauri/`, or `~/meta-analytical-pfc/`.
- Do not use destructive git commands.
- Do not mix unrelated files into a commit.

## Definition of success for the resumed session

At minimum, the new session should:

1. validate and commit the two in-flight batches cleanly
2. confirm the routing UI now reacts correctly and explicitly explains the active stack
3. confirm the likely cause of typo-heavy cloud replies is mitigated and covered by test
4. keep building the audit trail with small, reviewable commits
5. finish by writing a concrete next-step plan for the bigger unified-chat "brain/context transparency" cleanup

---

If you need a one-line summary:

Resume the Epistemos audit on `codex/runtime-input-audit`, validate and commit the two existing routing/cloud-quality fix batches first, then continue auditing the dirty tree in small tested commits, and after the regressions are stabilized produce a concrete plan for making unified chat transparent, user-friendly, and role-driven instead of a black box.
