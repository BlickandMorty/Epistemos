# Claude → next session handoff · 2026-04-20 · remaining runtime work

Purpose: pick up where this Claude session left off. 15 commits landed
on `codex/runtime-input-audit` during this pass, but the user still sees
at least one major symptom live (GPT-5.4 Thinking shows fake 5.7 s
"thinking" whose content duplicates the answer) plus a number of
scoped-out items the user wants done.

Read `AGENTS.md`, `CLAUDE.md`, `.agents/skills/epistemos_release_audit/SKILL.md`,
and `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`
before touching code. Do not hand-edit `Epistemos.xcodeproj/project.pbxproj`
— use `project.yml` + `xcodegen generate`. Commit after each fix; do
not batch unrelated work into a single commit.

---

## 0 · What already landed this session (do NOT regress)

15 commits on `codex/runtime-input-audit`:

```
58396678 Open the graph with a crystal→constellation→chaos cycle and padded camera
b09d9da2 Expand folder attachments into full per-note context at turn time
da8a4994 Request reasoning summaries from OpenAI + route large context to cloud
5674c764 Prefer cloud for Thinking turns when auto-route is enabled
70322eb1 Stop silently reverting cloud chat selections to local
09d4b653 Compact pill width on side chats and always honor cloud model pick
ccccf023 Compact single-popover toolbar for mini/note/graph chat
95155e78 Surface cloud errors first when both cloud and local paths fail
284687e4 Relax MLX memory preflight for realistic small-model loading
7a5f7e8a Fix self-contradictory LocalInferenceRoutingError messages
ba9c91b3 Defer Apple Intelligence availability probe inside Command Center Task
08dd7c6f chore: gitignore SwiftPM workspace metadata
4e70a3dd Honor explicit model pins over auto-route in Pro and Agent modes
918d7166 Preserve late reasoning deltas after visible answer begins
23d0f93b Fix Fast-mode OpenAI stream corruption (dropped async stream chunks)
```

All verified green via `xcodebuild build` and focused test suites where
applicable. Full context in each commit body.

### Key invariants to preserve

- `InferenceState.setPreferredChatModelSelection` must NOT silently
  swap `.cloud(model)` → `.localMLX(...)` when there's no API key. The
  startup-load path in `InferenceState.init` must NOT do it either.
  The commit that removed both swaps (`70322eb1`) is what made
  picking GPT-5.4 actually route to GPT-5.4.
- Cloud-model picker (`RootView.swift` around line 1623-1646) must
  always call BOTH `setPreferredCloudModel(model)` AND
  `setPreferredChatModelSelection(.cloud(model))`. Don't restore the
  old auto-route-conditional branch.
- `userFacingStream` in TriageService must NOT gate `reasoningSink`
  at the TriageService layer. Only gate at the ChatCoordinator layer
  for Fast mode's provider-native reasoning sink. The old
  TriageService gate broke 7 Pipeline / NoteChatState tests because
  inline `<think>` tag extraction goes through that sink too.
- `UserFacingModelOutput.finalVisibleText` must fail OPEN (return
  cleaned text) when heuristics can't cleanly split reasoning from
  answer and the text doesn't look like a pure reasoning dump.
  `reasoningParagraphPrefixes` must NOT contain `topic:`, `query:`,
  `comparison:`, `user query:`, or `instructions:` — those are
  legitimate answer field labels.
- `preferredOrder` lists in `preferredLocalTextModel` (TriageService
  around lines 620-705) should keep small models first for Fast
  simple-ask intents. Don't reintroduce "QwQ 32B first" for Thinking
  default intent without also raising `minimumRecommendedInteractiveMemoryGB`
  awareness.
- `GraphOverlayPhysicsPolicy` is now a 3-stage timeline by default
  (crystal → constellation → chaos). The initial camera magnifies
  to 0.72 for breathing room. Don't revert `schedulerMode = .timeline`
  or the `timelineSteps` array defaults in `GraphState`.

---

## 1 · The biggest thing still broken: GPT-5.4 Thinking is fake

### Symptom (latest screenshot, 2026-04-20 evening)

- Mode: Thinking · Model: GPT-5.4 · Effort: Medium · Provider: OpenAI · Cloud
- User types "analyze" with "All Things Must Go" note attached
- "Writing reply..." shell appears
- Pill inside bubble: **"Thought for 5.7s"**
- The expanded thinking block content is **identical to the main answer**
  ("# Overall assessment / This is a **strong, ambitious philosophy/neuroscience
  essay** with a clear central tension: ...")
- The answer below the thinking block is the SAME text
- Final answer appears instantly, no real reasoning time

### What I already tried (commit `da8a4994`)

Added `reasoningSummary: "auto"` to all reasoning-capable paths in
`openAIResponseControls` (GPT-5.4, GPT-5.4-Mini, GPT-5.4-Nano across
Fast / Thinking / Pro / Agent modes, plus the user-explicit low/high/heavy
tiers). In theory this makes the OpenAI Responses API stream back
`response.reasoning_summary_text.delta` events that populate the
thinking lane with real summaries rather than leaving it empty.

### What the screenshot proves is still wrong

The thinking lane is populated, but with **the same text as the answer**.
This is NOT "empty thinking backfilled from output" — it's the same
content rendered twice. So the bug is NOT just missing reasoning
summaries; it's something duplicating one stream into both lanes.

### Hypotheses to investigate (in order of likelihood)

1. **`userFacingStream` in TriageService is re-routing answer text as
   reasoning.** `TriageService.swift` around lines 2330-2370 uses
   `UserFacingModelOutput.streamingReasoningText(from: rawText)` to
   infer reasoning from prose prefixes. For a GPT-5.4 response that
   happens to start with "# Overall assessment" etc., the prose
   detection may classify the opening as reasoning, call
   `reasoningSink?(delta)` with it, AND the same chunks also flow
   through the visible path → both panels get the same text. Check:
   - Add a log at `TriageService.swift:2349` printing `delta` when
     `reasoningSink` is called via the inferred-reasoning path.
   - Check `UserFacingModelOutput.streamingReasoningText` triggers
     for the actual first tokens GPT-5.4 returns.

2. **`ChatState.appendStreamingText` is double-feeding the thinking
   lane via `ThinkTagStreamRouter`.** The router has state across
   calls. If a prior turn left the router in a partial-`<think>`
   state, the next turn's text would be partially routed to thinking.
   Verify the router is reset on every `startStreaming()` (it should
   be — `ChatState.swift` around line 470).

3. **OpenAI reasoning_summary_text actually IS streaming clean
   summaries, but the summary CONTENT naturally paraphrases the
   answer.** For simple queries, OpenAI's auto-summary can literally
   be the first paragraph of the answer. If so, this isn't a bug —
   it's a quirk of how summary-generation works for simple prompts.
   Test: ask a genuinely hard reasoning question ("prove the
   infinitude of primes") and see if the thinking summary is distinct
   from the answer.

4. **Swift `openAIResponsesReasoningDelta` extractor is matching
   `response.output_text.delta` too.** Unlikely but possible if
   there's a bug in the type check at `LLMService.swift:2889`. Verify
   the JSON type comparison.

### Additional clue: "Thought for 5.7s"

5.7 seconds is oddly specific. Either:
- GPT-5.4 actually reasoned for 5.7s (good), OR
- The UI's duration calculation is counting from first reasoning-delta
  to first answer-delta, which could include artificial gaps.

Find the duration calc in `ChatState.thinkingEndedAt` assignment and
verify it's anchored correctly.

### Minimum viable fix path

1. Add logging to both the reasoning-delta and text-delta paths for
   OpenAI in `TriageService.userFacingStream` so you can see what the
   model actually sends vs what the UI receives.
2. Run a cold Thinking turn and capture the log. This disambiguates
   hypotheses 1-4.
3. Fix based on evidence, not further speculation.

---

## 2 · Auto-route traversal (new user request)

### What the user wants

> "when on auto i want it to use fast or thinking by itself. so when
> it is on auto route it should traverse fast thinking for me auto
> route locals and to cloud fast and thinking are u able to do that
> safely and carefully?"

Parsed intent: when `Auto` routing is active, the system should
automatically pick **both** the operating mode (Fast vs Thinking) AND
the runtime (local vs cloud) based on the request's complexity /
context, without the user having to flip modes manually.

Concretely:
- Short, simple turn → Fast · local (cheapest, fastest)
- Complex reasoning turn → Thinking · cloud (best answer)
- Long-context turn → cloud regardless of mode (already implemented
  via `contextTier` escalation in commit `da8a4994`)

### What exists today

- `TriageService.routeDecisionForGeneral` already computes
  `complexityTier` (light / moderate / heavy / extreme) and
  `contextTier` (tiny / small / medium / large / oversized).
- `shouldAutoRouteToCloud` uses those tiers + operating mode to pick
  local vs cloud. This is the runtime dimension.
- `InferencePolicyEngine.reasoningMode` picks `.fast` vs `.thinking`
  based on `profile.explicitFastRequested` and
  `profile.explicitThinkingRequested`. This does NOT consider
  complexity — it's purely driven by the UI toggle.
- The UI has a `.fast / .thinking / .pro / .agent` operating mode
  picker that the user toggles explicitly.

### Gap

There's no "auto" operating-mode state. Users either pick Fast OR
Thinking. The user wants an "Auto" mode where the SYSTEM picks.

### Implementation plan

1. Add a new `.auto` case to `EpistemosOperatingMode` enum.
2. When `operatingMode == .auto`:
   - Compute `effectiveMode` from `complexityTier` + `contextTier`:
     - light + tiny/small context → `.fast`
     - moderate + small/medium → `.fast`
     - heavy OR large context → `.thinking`
     - extreme → `.thinking` AND force cloud
   - Pass `effectiveMode` to the rest of the routing pipeline
     INCLUDING `shouldAutoRouteToCloud`.
3. UI: the operating-mode picker should show `Auto` as the default
   and render the resolved effective mode as a subtle badge ("Auto
   → Thinking · Cloud") so the user sees what happened.
4. Tests: add cases in `TriageServiceTests` asserting:
   - short prompt + empty context → `.auto` resolves to `.fast`
   - long note attachment + reasoning query → `.auto` resolves to
     `.thinking`
   - preflight local fails under memory pressure → escalates to
     cloud regardless of chosen mode
5. Respect explicit pins: if user has `preferredChatModelSelection`
   pinned to a specific cloud model, auto-route still honors the
   pin (via the existing `userHasExplicitPin` check in
   `effectiveChatSurfaceSelection`). Auto-mode only removes the
   **operating-mode** guesswork, not the model-choice guesswork.

### Risk assessment

Medium. Adding a new enum case touches many exhaustive switches
(`availableReasoningTiers`, `capturesReasoningTrace`, UI labels,
LLMService default controls, etc.). Build will fail until every
`switch operatingMode` handles `.auto`. Plan for ~10-20 files.
Commit the enum case + handler in one commit so the build tree is
always green between commits.

---

## 3 · What the user explicitly asked for in the final message

Re-scoped from their message. Status per item:

| Item | Status | Next step |
|------|--------|-----------|
| Context-aware routing (cloud when attached context is large) | ✅ Done in `da8a4994` | User should test with a large folder attached; already should fire |
| Graph physics init sequence (crystal → chaos → compact, zoomed out) | ✅ Done in `58396678` | User should rebuild and see it; should be active on first graph open |
| Context panel mirror of actual model input | 🟡 Deferred this session | See §4 below |
| Folder attachment → load all notes | ✅ Done in `b09d9da2` | Needs UI entry point for attaching a folder (see §5) |
| Idle memory optimization (300 MB → 50 MB) | 🟡 Deferred this session | See §6 below |
| Hang Risk at EmbeddingService.swift:183 (priority inversion) | 🟡 Deferred this session | See §7 below |
| Thinking duplicates answer | 🔴 Still broken live | See §1 above |
| Auto-route traversing fast/thinking | 🔴 New request | See §2 above |

---

## 4 · Context panel mirror of actual model input (New A, deferred)

### User goal

The right-side "brain" panel in main chat should show the LITERAL
prompt that was sent to the model — system prompt, tools, message
history, attached context blocks. Not a summary or snapshot.

### Why deferred

The current `ChatBrainSnapshot` (in `ChatState.swift`) is captured
BEFORE `PipelineService.run` assembles the final prompt. Retrofitting
requires:

1. New struct `CapturedModelInput`:
   ```swift
   struct CapturedModelInput: Sendable, Equatable {
       let systemPrompt: String
       let userPrompt: String
       let messageHistory: [ChatMessage]
       let toolDefinitionsJSON: String
       let capturedAt: Date
   }
   ```
2. `PipelineService.run` must capture these values after prompt
   assembly and publish them to a new `ChatState.capturedModelInput:
   CapturedModelInput?` property.
3. `ChatView.ChatBrainPanelView` gets a new "FINAL MODEL INPUT"
   section that renders the captured input (collapsible, monospaced,
   scroll-able).
4. Tests assert the captured input matches what `streamGeneral`
   actually sends (wire-level validation).

### Estimated size

3-5 files, ~200-300 new lines, ~1 day of focused work with tests.

### Files to touch

- `Epistemos/State/ChatState.swift` — add `capturedModelInput` state
- `Epistemos/Engine/PipelineService.swift` — capture after prompt build
- `Epistemos/Models/ChatTypes.swift` — add `CapturedModelInput`
- `Epistemos/Views/Chat/ChatView.swift` (`ChatBrainPanelView`) — render
- `EpistemosTests/ChatPresentationTests.swift` — assert render
- `EpistemosTests/PipelineServiceTests.swift` — assert capture

---

## 5 · Folder attachment UI entry point

Commit `b09d9da2` added the data-model side: `.folder`
ContextAttachmentKind, manifest-driven expansion to per-note
attachments in `ChatCoordinator.expandFolderAttachments`. Attachments
of `.folder` kind are handled correctly at turn time.

### Missing UI work

No UI currently CREATES `.folder` attachments. `NotesMentionDropdown`
only offers `.note / .allNotes / .chat`. To let users attach a
folder, add one of:

1. **Option A — New dropdown row.** In `NotesMentionDropdown`,
   after the "All Notes" row, add folder rows pulled from the
   vault manifest (`manifest.entries.compactMap { $0.folderName }
   .uniqued()`). Selecting one creates `ContextAttachment(kind: .folder,
   title: folderName, ...)`.

2. **Option B — Drag-and-drop.** Allow dragging a Finder folder onto
   the chat composer. The composer creates a `.folder` attachment
   with the folder's name as title. This assumes the folder maps to
   a vault folder.

3. **Option C — Command palette.** Add `/folder <name>` slash command.

Simplest is Option A. Estimate: 1 file (`NotesMentionDropdown.swift`),
~30 lines, half a day.

### Until UI ships

Folder expansion logic is live and tested. Users just can't trigger
it from the UI yet, so the practical benefit is zero until one of
the above entry points is built.

---

## 6 · Idle memory 300 MB → 50 MB (deferred)

This is a profiling exercise, not a blind-fix job. The 300 MB idle
likely comes from several sources that compound; killing one won't
drop memory to 50 MB.

### Suspects (in order of typical impact)

1. **SwiftData `@Query` result caches.** Check `NotesSidebar`,
   `ChatView`, `NoteTabView` for `@Query` with large result sets
   that stay resident. Lazy the results or narrow the predicate.
2. **MLX `ModelContainer` retention.** The last loaded local model
   holds tokenizer + weight buffers in memory (~2-8 GB for loaded
   models, ~100-500 MB even for "unloaded" state after cache
   teardown). Check `MLXInferenceService.unload()` actually releases
   the reference.
3. **Graph texture atlases / vertex buffers.** `SDFLabelAtlas`,
   `MetalGraphView` buffers, `GraphEngine` Rust-side allocations.
   These are ~50-150 MB on a vault with many nodes.
4. **Tokenizer vocabs.** `TokenizerLoader` holds 100K+ token
   vocabularies in memory per model family.
5. **Retained event logs / diagnostics.** `RuntimeDiagnostics`,
   `StructuredDiagnosticLogger` accumulate. Check retention policy.
6. **Image caches.** Note thumbnails, model icon atlas, etc.
7. **Notification observer retain cycles.** Check `@ObservationIgnored`
   vs strong-captured closures in `NotificationCenter.default.addObserver`.

### Process

1. Run Instruments → Allocations on a launched-then-idle app.
2. Sort by "Persistent" size. Identify the top 10 retained objects.
3. For each, find the owner and either reduce retention or defer
   allocation until actually needed.

Without Instruments data, any fix is speculation.

---

## 7 · Hang Risk at EmbeddingService.swift:183 (deferred)

### Diagnostic details

```
Thread running at User-interactive quality-of-service class waiting on
a lower QoS thread running at Utility quality-of-service class.
Investigate ways to avoid priority inversions
```

Triggered at `DetachedEngineUseTracker.closeAndWait()` line 183:

```swift
func closeAndWait() {
    lock.lock()
    acceptsUse = false
    lock.unlock()
    group.wait()  // ← priority inversion here
}
```

Called from `EmbeddingService.prepareForEngineDestroy()` (line 401),
which is `nonisolated` and called synchronously from
`MetalGraphView.deinit` (line 2211). The sync wait is REQUIRED to
prevent use-after-free when destroying the graph engine.

### Why fixing cleanly is hard

`deinit` can't be `async`. The wait has to be synchronous. The OS's
dispatch subsystem detects the inversion and temporarily boosts the
waited-on work, so this is a performance **warning**, not a crash.

### Clean-fix options (any of these works)

1. **Promote the wait to user-interactive QoS.** In `closeAndWait`:
   ```swift
   DispatchQueue.global(qos: .userInteractive).sync { group.wait() }
   ```
   Adds a dispatch hop but clearly marks the wait's priority.

2. **Lifecycle refactor.** Move graph-engine destruction out of
   `deinit` into a dedicated teardown method called from a MainActor
   coordinator that can be async. `MetalGraphView` deinit only
   invalidates non-critical resources.

3. **Accept the warning.** Document with a comment that inversion
   is intentional during teardown and the OS handles it. Ship.

Option 1 is cheapest and resolves the warning without lifecycle
changes. Option 3 is zero effort. Option 2 is correct but expensive.

---

## 8 · Pre-existing warnings (user asked if I can fix)

Three warnings have been in the build since before this session:

1. `Epistemos/App/ChatCoordinator.swift:1527:73` — `??` on non-optional
   String. Find the `??` and remove it (the right-hand side is dead).
2. `Epistemos/Engine/LLMService.swift:2351:51` — trailing closure
   ambiguity. Wrap the closure in parentheses per Swift's suggestion.
3. `Epistemos/Engine/TriageService.swift:2331:21` — `var reasoningRouter`
   should be `let` (router is never reassigned; only mutated via
   reference semantics through the `ingest` method which doesn't
   require `var`).

All three are trivial. Can be one cleanup commit.

---

## 9 · Current uncommitted worktree state

```
git status --short
```

Should show (at session end):

```
 M Epistemos.xcodeproj/project.pbxproj       # Xcode auto-cleanup, don't stage
 M Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme  # same
 M syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib  # build artifact
?? docs/research/hermes-*.md                 # pre-existing research
?? docs/research/local-models-16gb-mac-april-2026.md
?? docs/handoffs/2026-04-20-claude-to-next-session-remaining-work.md  # this file
```

None of the `M` files were modified intentionally this session — they're
Xcode's own auto-regeneration during builds. Leave them uncommitted;
next session can decide.

---

## 10 · Xcode package-resolution quirk

User has repeatedly hit this cycle:

1. Delete `~/Library/Developer/Xcode/DerivedData/Epistemos-*` to get
   fresh state.
2. Reopen Xcode.
3. Xcode shows "Missing package product 'AXorcist' / 'GRDB' / 'MLX' / …".
4. Running `xcodebuild build` from terminal succeeds fine and
   populates the exact same DerivedData path.
5. Xcode GUI still shows errors.

Root cause: Xcode caches "missing package" state IN MEMORY when it
opens a project before packages are resolved. `File → Packages →
Reset Package Caches` only clears the download cache, NOT the
in-memory state.

**Reliable fix sequence:**

1. Quit Xcode completely (`⌘Q` or force-kill `Xcode`).
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*`
3. Delete artifacts: `rm -rf ~/Library/Caches/org.swift.swiftpm/artifacts`
4. From terminal: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' build`
   — this populates DerivedData from scratch.
5. Reopen Xcode. It will see resolved packages on disk and stop complaining.

Alternative (if the above doesn't work): delete
`Epistemos.xcodeproj/project.xcworkspace/xcuserdata` too.

---

## 11 · Priority order for the next session

1. **Diagnose the duplicated thinking text** (§1). Run a cold
   Thinking turn with logging added to `userFacingStream`. Find the
   actual source of duplication and fix. Without this, the user
   can't trust Thinking mode at all.

2. **Pre-existing warnings cleanup** (§8). Fast win, builds on the
   existing `da8a4994` / `918d7166` work.

3. **`.auto` operating mode** (§2). Medium-size feature. Worth doing
   in a clean session because it touches many exhaustive switches.

4. **Folder attachment UI entry point** (§5). Small feature that
   unblocks the already-landed folder expansion.

5. **Context panel mirror** (§4). Subsystem addition. Plan + tests
   before coding.

6. **Hang Risk fix** (§7). Pick option 1 (QoS promotion) as the
   cheapest clean fix.

7. **Idle memory profiling** (§6). Only after Instruments data in
   hand.

---

## 12 · Verification gates for the next session

Before any commit:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-next-session \
  build
```

After a state-file change (`ChatState`, `InferenceState`, `TriageService`):

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-next-session \
  test -only-testing:EpistemosTests/ChatPresentationTests \
       -only-testing:EpistemosTests/AgentChatStateTests \
       -only-testing:EpistemosTests/NoteChatStateTests \
       -only-testing:EpistemosTests/PipelineServiceTests \
       -only-testing:EpistemosTests/RuntimeValidationTests \
       -only-testing:EpistemosTests/TriageServiceTests
```

After a Rust change (not expected this cycle):

```bash
cargo test --manifest-path agent_core/Cargo.toml --lib
```

Before declaring anything done, launch the app and verify:

1. Cold Thinking-mode turn on GPT-5.4 with a multi-paragraph note.
   Thinking panel shows distinct content from the answer. Duration
   > 2s for non-trivial prompts.
2. Attach a vault folder (once §5 ships). Confirm all notes inside
   reach the model (check the cache-hit badge reflects total tokens
   approximating all notes combined).
3. `.auto` mode (once §2 ships) with a short query → routes Fast
   local. With a long attached folder → routes Thinking cloud.
4. Graph opens with crystal → constellation → chaos cycle over ~7s.
   Camera is zoomed out with breathing room.

---

## 13 · One-line summary

Fifteen commits fixed the OpenAI stream corruption, late-reasoning
dropping, cloud-pin silent reversion, compact toolbar, memory
preflight strictness, model picker honoring, folder expansion, and
graph opening cycle; the user still sees GPT-5.4 Thinking render
thinking content identical to the answer, wants an `.auto` operating
mode that picks Fast vs Thinking automatically based on complexity
and context, and has a backlog of deferred work (context panel
mirror, idle memory profile, Hang Risk QoS fix) that needs its own
focused session.
