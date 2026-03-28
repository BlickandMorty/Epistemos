# Codex Release Audit Prompt for Epistemos

**Purpose:** Paste this entire document into a Codex session. After Codex completes all tasks, the app should be release-ready.

---

## Context

You are auditing and finishing the Epistemos macOS app for release. Epistemos is a 242K LOC Swift + Rust + Python personal knowledge management app with on-device AI inference via MLX (Qwen 3.5 models), a knowledge graph, note editor, and an Omega agent system with research capabilities.

**Release decision:** Ship with Qwen as the production local model. Knowledge Fusion (LoRA adapter training/personalization) ships as Experimental. Omega and research mode ship as stable. No custom base model, no MOHAWK distillation, no Mamba-2 hybrid. Qwen + adapters only.

Read these documents first for full context:
- `docs/plans/2026-03-27-qwen-plus-knowledge-fusion-release-plan.md` — The release pivot plan
- `docs/plans/2026-03-27-release-closure-master-plan.md` — The master execution plan
- `docs/plans/2026-03-27-final-release-closure-report.md` — Current status report
- `CLAUDE.md` — Engineering bible (architecture, patterns, anti-patterns)
- `docs/NANO-MASTER-TRAINING-GUIDE.md` — Training reference (for Knowledge Fusion context)

## CRITICAL BLOCKER 0: Missing file references in Xcode project

The following files exist on disk but are NOT in the Xcode project's build target (they were accidentally removed from `project.pbxproj` during a prior cleanup pass). They must be re-added to the Epistemos target:

- `Epistemos/Omega/ResearchOrchestrator.swift`
- `Epistemos/Omega/ResearchEvidenceScorer.swift`
- `Epistemos/Omega/ResearchComplexityGate.swift`
- `Epistemos/Omega/ResearchConfidenceState.swift`
- `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift`
- `EpistemosTests/ResearchModeTests.swift`

To fix: Either add them manually in Xcode, or run `xcodegen generate` and fix the resulting duplicate resource issues (add source excludes in project.yml for `**/*.jsonl`, `**/*.json`, `Omega/Knowledge/ODIATraceGenerator.swift`, `Omega/Knowledge/TraceDataMixer.swift`).

## CRITICAL BLOCKER 1: "Unsupported model type: qwen3_5"

The installed Qwen 3.5 models have `model_type: "qwen3_5"` in their config.json, but the pinned `mlx-swift-lm` SPM dependency (revision `7e19e09`) does not include Qwen 3.5 support. The support was added in later commits (commit `06bfeed` — "Add qwen3_5_text model type support #135"). The `project.yml` already pins to `bc3c20e` which includes this support, but the `project.pbxproj` and `Package.resolved` are stale at `7e19e09`.

**Task:** Update the `mlx-swift-lm` SPM dependency to revision `bc3c20ef4644c86f2b347debcfe1efe4308712a6` (or later) which includes `qwen3_5`, `qwen3_5_moe`, and `qwen3_5_text` model type support. This requires:
1. Updating the revision in `Epistemos.xcodeproj/project.pbxproj` (search for the `XCRemoteSwiftPackageReference "mlx-swift-lm"` section)
2. Updating the revision in `Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
3. Resolving SPM dependencies
4. Verifying the build succeeds — if `mlx-swift` (the base framework) also needs updating for compatibility, update it too
5. Verifying the app can load a Qwen 3.5 model without "Unsupported model type" errors

The installed models are at: `~/Library/Application Support/Epistemos/Models/text/active/`

**WARNING:** The `project.yml` source exclude patterns may need updating. The xcodegen-generated project currently has duplicate resource issues with JSONL/JSON training data files and duplicate Swift files (ODIATraceGenerator.swift and TraceDataMixer.swift exist in both `KnowledgeFusion/SyntheticData/` and `Omega/Knowledge/`). Exclude the `Omega/Knowledge/` duplicates and all `*.jsonl`, `*.json`, `composed_training_data/**`, `epistemos_training_data_validated/**`, `embodied_data/**` from sources.

## Already Completed Fixes (verify these are still correct)

These were applied in the current working tree. Verify they are present and correct:

1. **Deploy gate fully fail-closed** — `TrainingScheduler.swift` `runDeployGate()`: All 3 paths return `passed: false`. No `passed: true` anywhere in the function. Zero matches for `passed: true` in the file.

2. **LoRA rank unified to 16/32** — `QLoRATrainer.swift` `defaultKnowledge`: `loraRank: 16, loraAlpha: 32`. Python script `train_knowledge.py`: `DEFAULT_RANK = 16, DEFAULT_ALPHA = 32`.

3. **Cross-app PID capture** — `OrchestratorState.swift`: `resolveTargetPID(for:)` method maps agent names to bundle IDs via NSWorkspace.

4. **TrainOnVaultView messaging** — No "Autoresearch", no "improves while you sleep", no "Voice Cloning", no "Knowledge Absorption". Uses "Style Adaptation", "Knowledge Exposure", "Tool Familiarity", "Background Training".

5. **Experimental labels** — "Knowledge Fusion (Experimental)" in SettingsView sidebar and TrainOnVaultView header. "Start Training (Experimental)" on button. "Overnight adapter training (Experimental)" and "Embodied data capture (Experimental)" in OmegaSettingsDetailView.

6. **FeedbackIndicatorView** — `FeedbackIndicatorView.swift:67` says "Preference training can run overnight when enabled in Omega settings." (not the old "runs overnight when idle").

7. **Test fixes** — `CognitiveSubstrateTests.swift`: friction test explicitly sets `frictionEnabled = true`, disabled test restores it after. Blocklist test resets `allowlistJSON = "[]"`. `QLoRATrainingTests.swift`: assertions match rank 16/alpha 32.

## Remaining Tasks for Codex

### TASK 1: Fix the MLX dependency and build (BLOCKING)

Update mlx-swift-lm to support Qwen 3.5 (see Critical Blocker above). Get `xcodebuild build` to succeed.

### TASK 2: Run full test suite

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd omega-mcp && cargo test
cd omega-ax && cargo test
```

All tests must pass. If any fail, fix them. The current verified baseline is 2,597 Swift tests passing and 2,540 Rust tests passing.

### TASK 3: Keep release documentation numbers synced

- `docs/plans/2026-03-27-release-closure-master-plan.md` and `docs/plans/2026-03-27-final-release-closure-report.md` should reflect the live count of 26 Omega tools.
- Keep Swift verification totals aligned with the current 2,597-test baseline if more regression tests are added.

### TASK 4: Fix remaining force unwraps in production code

Check these specific locations:
- `EmbodiedCaptureService.swift:27` — `FileManager.default.urls(for:in:).first!` — replace with safe unwrap
- `EpistemosTheme.swift:200` — `Self.resolvedCache[self]!` — replace with safe unwrap or precondition

Search for any other `!` force unwraps in production code (not tests, not `init(coder:)` stubs).

### TASK 5: Fix stale rank-32 comment in train_knowledge.py

`train_knowledge.py` line 9 header comment still says "rank=32, alpha=64" but actual code uses 16/32. Update the comment.

### TASK 6: Verify Omega tool count consistency

Count the actual `OmegaToolDefinition` entries in `MCPBridge.swift` `OmegaToolRegistry.all`. Verify the test in `ResearchModeTests.swift` matches. Update any mismatched documentation.

### TASK 7: Audit all user-facing strings one final time

Grep for these patterns in all `.swift` files under `Epistemos/`:
- "Nano" (excluding OpenAI model names like "GPT-5.4 Nano" and code comments)
- "autoresearch" (case insensitive) in user-facing strings
- "improves while you sleep" or "gets smarter" or "self-improving"
- "custom model" or "new model" or "own model" in user-facing strings
- "autonomous brain"

If any user-facing matches remain, fix them.

### TASK 8: Verify overnight training is off by default

Confirm `@AppStorage("omega.overnightTraining")` defaults to `false` in `OmegaSettingsDetailView.swift`. Confirm `TrainingScheduler.startScheduling()` returns early when this flag is false.

### TASK 9: Verify research mode is complete

Verify all these exist and are wired:
- `ResearchComplexityGate.swift` — `requiresResearch()` method
- `ResearchEvidenceScorer.swift` — 6-tier URL scoring
- `ResearchConfidenceState.swift` — confidence tracking, `requiresPause`
- `ResearchOrchestrator.swift` — task detection, result processing, escalation
- `OmegaInferenceBridge.swift` — research planning rules injected for research tasks
- `ChatView.swift` — `/research` prefix routes to Omega
- `MiniChatView.swift` — `/research` prefix routes to Omega
- `OmegaPanel.swift` — research quick action button
- `SafariAgent.swift` — handles `readpagecontent`, `searchpapers`
- `NotesAgent.swift` — handles `collectsnippet`, `savecitation`, `createresearchnote`, `analyzecontradiction`, `scoreevidence`
- `osascript.rs` — `tool_get_page_text()` exists

### TASK 10: Write final verification report

After all tasks complete, write `docs/plans/2026-03-27-final-release-closure-report.md` with:
1. Every fix applied (with file:line references)
2. Build result (`xcodebuild build` output)
3. Test results (Swift test count + Rust test count)
4. Grep verification results (all clean)
5. Known remaining issues (if any)
6. Honest verdict: is this release-ready or not, and what manual verification remains

## Hard Constraints

- Do NOT work on custom base-model creation, distillation, MOHAWK, Mamba-2, or RunPod
- Do NOT start plugin porting, SDK architecture, or Notion/Obsidian/Logseq parity
- Do NOT add features — only fix bugs, update dependencies, and clean messaging
- Do NOT claim release-ready unless `xcodebuild test` passes and the model actually loads
- Prefer minimal, targeted fixes over broad refactors
- Read before writing — understand existing code before modifying

## Files to Read First

Core runtime:
- `Epistemos/Engine/TriageService.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/App/AppBootstrap.swift`

Knowledge Fusion:
- `Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift`
- `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift`
- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`

Omega + Research:
- `Epistemos/Omega/MCPBridge.swift`
- `Epistemos/Omega/Orchestrator/OrchestratorState.swift`
- `Epistemos/Omega/ResearchOrchestrator.swift`
- `Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift`

Tests:
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `EpistemosTests/ResearchModeTests.swift`
- `EpistemosTests/OmegaAgentTests.swift`
- `EpistemosTests/QLoRATrainingTests.swift`

Settings:
- `Epistemos/Views/Settings/SettingsView.swift`
- `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
- `Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift`
- `Epistemos/KnowledgeFusion/UI/FeedbackIndicatorView.swift`
