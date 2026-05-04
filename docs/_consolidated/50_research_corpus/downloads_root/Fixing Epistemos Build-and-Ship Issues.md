# Resolving Common Build Issues So Epistemos Actually Shows Up in Your App

This playbook consolidates every recurring pitfall that has been making it hard for agents (Codex, Claude, etc.) to land working changes in your Epistemos Swift/Rust/SwiftUI app, and gives them a deterministic, step‑by‑step checklist to follow so that new code actually compiles, links into the running app, and becomes visible in the UI. It is synthesized from the full handoff history in your pasted session plus known‑good Xcode / XcodeGen / SwiftUI build practices.

## Why Your Agents Keep "Building" Things That Don't Show Up

Your session history reveals six failure modes that repeat across every handoff, not a single bug:

1. **New Swift files created but never registered with the target**, so `xcodebuild` compiles happily but the symbol is never linked into the app — the UI change is invisible at runtime.
2. **`xcodegen` is the source of truth but agents edit `.xcodeproj` directly** (or forget to re‑run `xcodegen`), so the next regeneration wipes their additions or silently drops new files.
3. **Stale `DerivedData` from aborted test runs** causes "DB lock" errors, ghost test failures, and "file exists but empty" outputs that the agent misreads as real failures (you hit exactly this with `bmm2bw7h3` in the handoff).
4. **Three parallel routers and two orchestration systems** (Swift `ConfidenceRouter`, `agent_core/src/routing.rs`, `epistemos-core/src/agent_runtime/routing.rs`, plus `omega-mcp` vs Hermes) mean a UI change wired to one path never fires because the active request went down a different path.
5. **Dirty working tree** — agents `git add .` and accidentally bundle 5–7 pre‑existing Codex edits into their "clean batch," contaminating commit history and making reverts dangerous (this happened in Batches P, KK, and the `openai.rs` reasoning fix).
6. **Empty streams / silently‑dropped deltas** — reasoning tokens and tool‑call deltas get parsed but never routed into the state the SwiftUI view observes, so the feature "ships" but looks broken (this was Batch C's root cause for agent reasoning, Batch D for empty responses, and JJ for Gemini `thought: true` leakage).

Each of these is individually fixable; the reason the app "still feels broken" is that your agents keep fixing one and regressing another because they don't run a uniform pre‑flight and post‑flight checklist.

## The Pre‑Flight Checklist (Every Agent, Every Batch)

Before an agent touches a single file, it must run through this sequence. Paste this verbatim into the next handoff so any agent — Codex, Claude Code, Cursor — performs the same gate.

```bash
# 1. Confirm branch + dirty-tree baseline
git status --short > /tmp/pre_batch_status.txt
git rev-parse HEAD > /tmp/pre_batch_head.txt

# 2. Identify pre-existing dirty files that MUST NOT be bundled
git diff --name-only > /tmp/pre_existing_dirty.txt

# 3. Regenerate project from source of truth
xcodegen -s project.yml

# 4. Nuke DerivedData for THIS project only (never -rf ~/Library/Developer/Xcode/DerivedData)
rm -rf /tmp/epistemos-batch-*
rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*

# 5. Verify cargo side compiles cleanly before Swift work
cargo check --manifest-path agent_core/Cargo.toml
cargo check --manifest-path epistemos-core/Cargo.toml

# 6. Baseline focused test — must be green before any new edit
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-baseline \
  test -only-testing:EpistemosTests/ChatPresentationTests
```

If step 6 fails on untouched code, stop and investigate before adding anything — you are not starting from green and every downstream "fix" will build on broken foundations. This is the single biggest reason your agents keep saying "tests pass" while the app feels regressed.

## The Six Failure Modes, With Deterministic Fixes

### 1. New files that never link into the target

Your project uses XcodeGen, which rebuilds `Epistemos.xcodeproj` from `project.yml`. When an agent creates `Epistemos/Engine/ToolActivityNarrator.swift` and runs `xcodebuild`, it appears to succeed only because `xcodebuild` uses the existing `.xcodeproj`, but the next `xcodegen` run will either (a) include the new file if its directory is globbed in `sources:` or (b) drop it if the directory is explicitly listed without the file.

**Rule for agents:** After any file creation, always run:

```bash
xcodegen -s project.yml
grep -c "ToolActivityNarrator.swift" Epistemos.xcodeproj/project.pbxproj
```

If the count is zero, the new file is not part of the target. Either fix the `sources:` glob in `project.yml` or confirm the directory is wildcard‑scanned. Your session already hit this when you had to "register the new file in project.yml so xcodegen picks it up."

### 2. XcodeGen eats `Package.resolved` and silently drops SPM dependencies

XcodeGen deletes `Package.resolved` on regeneration, and Xcode 15+ deletes it on open; together they can cause "missing package product" errors that look like random link failures. The standard fix is to commit `Package.resolved` to git and add a Makefile target that restores it after every `xcodegen` run:

```makefile
PACKAGE_FILE := Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

.PHONY: gen
gen:
	xcodegen -s project.yml
	@if [ ! -f "$(PACKAGE_FILE)" ]; then \
	  git restore "$(PACKAGE_FILE)"; \
	  xcodebuild -resolvePackageDependencies; \
	fi
```

This pattern is now standard practice across SwiftPM‑heavy teams and eliminates a class of "builds but won't run" errors that otherwise require reinstalling certificates or fully resetting DerivedData.

### 3. Stale DerivedData causes phantom failures

The "7 issues but every test passed" result you saw in the `bxr1k74e9` output is the classic Xcode 15+ pattern where a truncated log, stale `xcresult` bundle, or crashed background `swift-frontend` leaves teardown diagnostics that an agent misinterprets as failures. The robust fix is always a unique per‑batch `derivedDataPath`:

```bash
xcodebuild ... -derivedDataPath /tmp/epistemos-$(date +%s)-$RANDOM ...
```

Never reuse `/tmp/epistemos-routing-ux-rerun` across sessions — it is the exact path where your DB lock appeared. If an xcresult says "green summary, 2 failures," extract failures programmatically rather than tailing stdout:

```bash
xcrun xcresulttool get --path /tmp/epistemos-*/Logs/Test/*.xcresult \
  --format json | jq '.actions._values[].actionResult.testsRef'
```

### 4. Multiple routers, multiple orchestration layers

This is the root cause of your "selected Fast/Thinking/Pro but it still says Auto Route" regression. You have three routers that can disagree, and two tool systems (omega‑mcp + Hermes). Until one router owns the decision, every UI change is fighting two other decision authorities silently.

| Router | Location | What it decides |
|---|---|---|
| `ConfidenceRouter` | `Epistemos/LocalAgent/ConfidenceRouter.swift` | Binary local‑vs‑cloud |
| Rust orchestrator | `agent_core/src/routing.rs` | Complexity score → provider |
| Agent runtime | `epistemos-core/src/agent_runtime/routing.rs` | Different keyword list → provider |

The fix direction the external research agent already gave you — a 3‑layer cascade (semantic intent router → tier judger → model‑within‑tier) with one authoritative implementation in Rust and Swift feeding classification only — is the correct target architecture. Until it lands, adopt a feature‑flag contract: every request logs `router.decision.origin` and a test asserts that the origin is unique per request so silent disagreements fail loudly.

### 5. Dirty tree contamination in commits

Your agents keep running `git add .` and sweeping up 5–7 pre‑existing Codex edits. The deterministic fix is to never stage directory‑wide:

```bash
# WRONG: git add .
# RIGHT: explicit file list matching the batch plan
git add Epistemos/State/InferenceState.swift \
        Epistemos/App/RootView.swift \
        EpistemosTests/TriageServiceTests.swift
git diff --cached --name-only > /tmp/about_to_commit.txt
diff /tmp/about_to_commit.txt /tmp/batch_plan.txt || { echo "DRIFT"; exit 1; }
git commit -m "Batch A: routing UX"
```

The `diff /tmp/about_to_commit.txt /tmp/batch_plan.txt` guard would have caught every bundling incident in your session (Batches P, KK, and the `openai.rs` reasoning commit).

### 6. Streams parsed but never observed by the view

Empty responses, missing reasoning popovers, and the Gemini `thought: true` leakage all share a shape: the token is parsed in `LLMService` or `agent_core/providers/*.rs`, written to a state property, but the SwiftUI view binds to a different property. The deterministic test pattern is:

```swift
func test_thinkingDeltaReachesObservedStateProperty() async {
    let state = AgentChatState()
    let event = StreamEvent.thinkingDelta("hello")
    await state.ingest(event)
    #expect(state.streamingThinking == "hello")  // the EXACT property the view reads
}
```

Every stream‑event ingestion path needs one such test. Your Batch C fix for `.thinkingDelta` in `AgentChatState` is the template; apply it to every new delta type added under Batch DD/EE reasoning‑tier work.

## The "It Built But Doesn't Show Up in the App" Triage Flow

When an agent reports "tests pass but I don't see the change in the running app," walk the flow in order — stop at the first hit:

1. **Was `xcodegen` re‑run after the file was created?** `grep` the new symbol in `project.pbxproj`.
2. **Is the view actually mounted?** `grep -r "MyNewView(" Epistemos/` — if only the definition exists and no call site, it is orphaned (this happened to Batch J's earlier `EffectiveModelBadge` drafts).
3. **Is the state property the view binds to the same one the stream writes?** Audit both sides.
4. **Is the code path behind a mode gate that the current route doesn't hit?** The Pro+cloud tool‑gap at `PipelineService.swift:302` is a textbook example — the tools existed, the UI existed, but the gate prevented the path.
5. **Are you running the just‑built binary or a cached one?** `ps aux | grep Epistemos.app` then kill, then re‑launch from the DerivedData build products, not from Finder.
6. **Did SwiftUI coalesce the update?** An `.animation(value:)` on a frequently‑changing binding can suppress visible updates; use `Text(verbatim:)` and remove animations while debugging.

This flow, not guesswork, is how your agents should respond to the next "I don't see it in the app" complaint.

## Recommended Agent Operating Contract

Paste this into every handoff document going forward. It converts the failure modes above into explicit rules:

- Never run `git add .`; always list files explicitly against a written batch plan.
- Never reuse a `-derivedDataPath` across sessions.
- Always `xcodegen -s project.yml` after creating or moving a Swift file, then grep `project.pbxproj` to confirm inclusion.
- Always `cargo check` the Rust workspaces before starting Swift edits, so Rust compile errors don't masquerade as Swift link errors.
- Always write one test that binds to the exact `@Published`/`@Observable` property the view reads, not the intermediate state.
- Never add a feature behind a mode gate without adding an integration test that routes a representative request through that gate.
- Never declare "tests pass" without reading the xcresult JSON — stdout tails lie.
- Split the three‑router consolidation into its own branch; do not attempt it alongside UI work.

## Known‑Good Order for the Remaining Backlog

Based on the already‑landed commits and the open items in your master plan, this is the lowest‑risk order to finish the app:

1. **Stabilize the commit hygiene first** — split out the bundled Codex edits in `0eb97f9e`, `KK`, and the `openai.rs` reasoning commit so reverts are surgical.
2. **Land the capability manifest** (Batch II) because every subsequent UI addition needs a single source of truth for what the app can do.
3. **Finish Batch FF tool‑narration slices** (sticky TodoWrite card, context meter, auto‑expand cards) — highest "app feels alive" payoff for the least surface area.
4. **Consolidate routers behind a feature flag** (P2 architecture) — ship under `router.v2.enabled=false` by default and migrate paths one at a time.
5. **Port Gemma 4 loader** (handoff §5.1) only after router consolidation, since the loader will route through the new authority.
6. **Rust memory work last** (graph engine buffer release, SearchIndex lazy unload) — it is the most invasive and benefits from a stable Swift‑side baseline.

Sequencing this way means every step builds on a green, testable baseline and none of the steps requires undoing an earlier one — which has been the dominant cost pattern in your session so far.