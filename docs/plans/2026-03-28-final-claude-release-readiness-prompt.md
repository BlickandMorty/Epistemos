We are doing the final release-readiness audit for Epistemos.

This is the last all-hands-on-deck release pass. Treat this as the official v1 release gate, not a beta sweep.

You must audit the actual current shipping branch, re-verify all major work completed in the most recent stabilization session, compare it against older research-mode baselines, verify legal/compliance/distribution readiness, and only call the app release-ready if the evidence is genuinely there.

Use the `Recursive App Audit` skill for this session and follow its 3-pass zero-fail rule.

Do not trust prior claims, prior reports, or prior green results until you reproduce them.

Logs are mandatory evidence. While testing manually, always inspect app/runtime logs and correlate them with the observed UI behavior. A UI that "looks okay" but logs fallback, cancellation, permission denial, or hidden failures is not verified.

## Audit target

- Repo: `/Users/jojo/Downloads/Epistemos`
- Branch to audit: `codex/release-stabilization-and-runtime-hardening`
- Commit to audit: `d9cf9857c17094e81160ad736ee18d6ebc3b3444`
- Published PR: `https://github.com/BlickandMorty/Epistemos/pull/1`
- Compare current branch against:
  - `main`
  - older research-mode baselines:
    - `65aef46e22454c137c728370c697d998e92b41fc`
    - `91f6dc39b260e2df2c831b5e392b3a90cab3258b`

Your job is not to defend the branch. Your job is to decide whether it is truly ready to release and, if not, to close the remaining gaps.

## Primary mission

1. Audit all material work done on the current stabilization branch.
2. Verify release readiness for:
   - runtime stability
   - model support and model-mode wiring
   - research/Omega/agent functionality
   - note integrity and corruption safety
   - settings clarity and permission flows
   - release packaging and distribution
   - App Store readiness versus direct-distribution readiness
3. Make any minimal, release-oriented fixes still required.
4. Run recursive verification until you achieve 3 uninterrupted zero-fail passes without code changes between the final passes.
5. Produce an honest final verdict:
   - `READY FOR DIRECT RELEASE`
   - `READY FOR DIRECT RELEASE, MAS LITE ONLY`
   - `NOT READY`

If something is not ready, say so plainly with exact blockers. Do not overclaim.

## Non-negotiable product framing

- Qwen-first release
- Keep Knowledge Fusion as Qwen adapter training / personalization
- Keep Omega and research mode
- Do not drift into custom base-model shipping work
- Do not balloon into broad plugin/platform parity work
- Prefer finishing and verifying what already exists

## Read these first

### Local release and launch docs

- `/Users/jojo/Downloads/release/epistemos-final-release-plan.md`
- `/Users/jojo/Downloads/release/Mac App Store Launch Checklist.md`
- `/Users/jojo/Downloads/epistemos-final-release-plan.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-27-final-release-closure-report.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-27-release-closure-master-plan.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-27-qwen-plus-knowledge-fusion-release-plan.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-27-codex-release-audit-prompt.md`

### Key product / research / scope docs

- `/Users/jojo/Downloads/EPISTEMOS-FEATURE-SPEC.md`
- `/Users/jojo/Downloads/epistemos-upgrade-plan.md`
- `/Users/jojo/Downloads/Epistemos Complete Model Support & Feature Expansion Plan.md`
- `/Users/jojo/Downloads/soaar and research mode/Epistemos Training Readiness Audit.md`
- `/Users/jojo/Downloads/soaar and research mode/2026-03-27-master-gap-closure-plan.md`
- `/Users/jojo/Downloads/soaar and research mode/Epistemos Next-Generation Research Mode  Migration Blueprint.md`
- `/Users/jojo/Downloads/soaar and research mode/Omega Research & SOAR Redesign.md`
- `/Users/jojo/Downloads/soaar and research mode/new/EPISTEMOS-FEATURE-SPEC.md`
- `/Users/jojo/Downloads/soaar and research mode/new/EPISTEMOS-PLUGIN-PORTING-SPEC.md`

### Secondary research references if needed

- `/Users/jojo/Downloads/Cognitive Computing Capabilities for a Native macOS Personal Knowledge System.md`
- `/Users/jojo/Downloads/Epistemos  Zero-Copy, Zero-Latency Implementation Masterclass.md`
- `/Users/jojo/Downloads/Epistemos Complete Model Support & Feature Expansion Plan.md`
- `/Users/jojo/Downloads/cap1_contextual_shadows.md`
- `/Users/jojo/Downloads/cap2_cross_app_capture.md`
- `/Users/jojo/Downloads/cap3_cognitive_friction.md`
- `/Users/jojo/Downloads/cap4_temporal_graph.md`
- `/Users/jojo/Downloads/cap5_night_brain.md`
- `/Users/jojo/Downloads/cap6_spatial_graph.md`

## Official sources you must use for compliance and release policy

For compliance/distribution/app-review questions, browse official sources only unless you explicitly label something as an inference:

- Apple App Review Guidelines:
  - `https://developer.apple.com/app-store/review/guidelines/`
- App privacy details in App Store Connect:
  - `https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy`
- Export compliance overview:
  - `https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance`
- D-U-N-S and organization enrollment:
  - `https://developer.apple.com/help/account/membership/D-U-N-S/`
  - `https://developer.apple.com/programs/`
- Developer ID and notarization:
  - `https://developer.apple.com/developer-id/`
- Third-party SDK privacy manifest/signature requirements:
  - `https://developer.apple.com/support/third-party-SDK-requirements`
- App Store Small Business Program:
  - `https://developer.apple.com/app-store/small-business-program/`
- App Review / submission help:
  - `https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app`
  - `https://developer.apple.com/help/app-store-connect/reference/app-review-information`

Use BIS / official government sources for encryption/export issues when needed, and official Texas/state/local sources for business-formation or tax questions when needed.

Do not give fake legal certainty. If something needs counsel/CPA confirmation, mark it as `Needs legal review` or `Needs CPA review`, but still produce the operational checklist.

## Files and subsystems you must audit directly

### Distribution / compliance

- `/Users/jojo/Downloads/Epistemos/Epistemos/Epistemos.entitlements`
- `/Users/jojo/Downloads/Epistemos/Epistemos/PrivacyInfo.xcprivacy`
- `/Users/jojo/Downloads/Epistemos/Epistemos-Info.plist`
- `/Users/jojo/Downloads/Epistemos/project.yml`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Distribution/AppStoreHelper.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/OmegaPermissions.swift`

### Inference / model support / routing

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/TriageService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/PipelineService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/ChatState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ChatView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Landing/LandingView.swift`

### Omega / research / agent / tools

- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/MCPBridge.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Agents/SafariAgent.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Agents/NotesAgent.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Agents/AutomationAgent.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Agents/TerminalAgent.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Orchestrator/OrchestratorState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/ResearchComplexityGate.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/ResearchConfidenceState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/ResearchEvidenceScorer.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/ResearchOrchestrator.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Omega/OmegaPanel.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/UtilityWindowManager.swift`

### Notes / integrity / corruption-risk paths

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/NoteChatState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/NoteFileStorage.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/MappedNoteBody.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultIndexActor.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/Extensions.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/MarkdownContentStorage.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`

### Knowledge Fusion / training / messaging

- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/UI/FeedbackIndicatorView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/SettingsView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/CognitiveSettingsSection.swift`

### Tests you must audit and extend if needed

- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ResearchModeTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/OmegaAgentTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/TriageServiceTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/UserFacingModelOutputTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/NoteChatStateTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/NoteFileStorageTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/MappedNoteBodyTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/VaultIndexActorTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/FileAttachmentBuilderTests.swift`

## What changed recently and must be re-audited

Do not trust any of these claims until you verify them yourself:

- release stabilization branch published as commit `d9cf9857`
- research-mode entry points restored and research routing improved
- capability-tailored `Fast / Thinking / Agent` controls added
- unsupported modes are hidden rather than shown disabled
- thinking-mode output fix landed in the shared visible-output scrubber
- Omega / Agent / Research window activation hardened
- top additional MLX models added on the current architecture
- App automation permission path wired for System Events / Apple Events
- web / browser / terminal / desktop-control tools wired through Omega
- Knowledge Fusion deploy gate made fail-closed and experimental labeling improved
- note-AI cleanup bug fixed
- Unicode / UTF-16 note decode hardening added to prevent false gibberish/corruption
- settings descriptions expanded for advanced features

## Mandatory release audit tasks

### 1. Diff-based audit

- Audit the branch diff versus `main`.
- Audit the branch diff versus the older research-mode commits.
- Identify every user-facing regression risk introduced by the stabilization branch.
- Compare current research mode and Omega experience against the older research-mode baselines.
- Prove the current app is equal or better in every major area, or name the regressions exactly.

### 2. Release architecture decision

Produce an explicit shipping recommendation for one of these:

- `Direct-distributed full app first, Mac App Store later`
- `Hybrid: direct-distributed full app + sandboxed MAS-lite companion build`
- `Single Mac App Store build only`

You must base this on real audit evidence, not wishful thinking.

Specifically examine whether these are compatible with a true Mac App Store build:

- `com.apple.security.app-sandbox`
- MLX/JIT/unsigned executable memory/library validation needs
- Apple Events automation against other apps, especially Finder/System Events
- browser control, terminal, accessibility-driven desktop control
- current Gateway helper/App Store helper scaffold state

If full Omega automation is not realistically compatible with App Store review right now, say so explicitly and recommend the hybrid/direct route.

### 3. Release-blocker audit

Treat these as must-audit release blockers:

- empty release entitlements file
- missing `PrivacyInfo.xcprivacy` if still missing
- missing or inaccurate App Store privacy answers / privacy policy URL requirements
- missing export compliance setup
- App Store helper / gateway scaffold that still throws or overclaims
- any unsupported mode exposed in UI
- any model-specific crash or blank-response path
- any note decode / file read path that can present healthy files as corrupt
- any feature whose UI copy overclaims capability

### 4. Manual runtime verification

You must perform real manual tests in the app, not just read code.

Use a disposable test vault for destructive note or training checks.

Keep logs open while running the app and correlate every manual check with runtime evidence.

Manual matrix to run:

#### A. Model install/select/runtime

- Verify current supported local model list in the real UI.
- On this machine, manually test each actually supported/visible model.
- For each visible model, verify which modes appear:
  - `Fast`
  - `Thinking`
  - `Agent`
  - research button / research handoff
- Confirm unsupported modes disappear for models that do not support them.
- Confirm supported modes remain visible and stable.
- Send real prompts in each supported mode.
- Watch logs for actual routing path, actual model load, stream tokens, and stop reason.
- No silent fallback unless clearly intentional and logged.

At minimum, verify:
- Apple Intelligence path if available
- Qwen `0.8B`
- Qwen `2B`
- Qwen `4B`
- any newly added small/medium MLX models that are runnable on this hardware

If a model is too large for the machine, verify that the UI handles that honestly rather than pretending support.

#### B. Research mode

- Verify there is a visible research entry point in main chat and mini chat.
- Trigger research via the button and via `/research ...`.
- Verify Omega opens visibly.
- Verify planning state appears.
- Verify execution steps appear.
- Verify result output is structured and useful.
- Confirm logs prove that the research path actually ran, not plain chat.

#### C. Agent / Omega

- Verify Agent mode opens and surfaces Omega reliably.
- Verify browser, search, notes, terminal, and desktop-control tools exist and are callable.
- Test:
  - open URL
  - search web
  - get page title / URL
  - safe terminal command
  - AX tree read
  - click / type / press key
- Verify permission prompts and failure states are honest.

#### D. Note AI and file integrity

- Open and edit test notes in a disposable vault.
- Exercise note AI query, streaming, accept, discard, clear, and note window close/reopen behavior.
- Verify no divider orphaning or stale AI zone corruption.
- Create and open a UTF-16 sample note and verify it reads correctly in Epistemos.
- Verify attachment preview and vault indexing do not show gibberish for valid Unicode files.
- Confirm logs show decode path behaving normally.

#### E. Settings and descriptions

- Verify the app actually explains advanced features clearly in settings and relevant UI.
- Confirm "auto research" is not misleadingly implied where it should really mean training or orchestration.
- Verify experimental labels are present where required and absent on stable surfaces.

### 5. Automated verification

Run and fix until clean:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd omega-mcp && cargo test
cd omega-ax && cargo test
```

Then run sanitizer / higher-scrutiny passes if feasible:

```bash
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableAddressSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableThreadSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableUndefinedBehaviorSanitizer YES
```

If any sanitizer pass is infeasible, say exactly why.

### 6. Store readiness audit

Audit these App Store / distribution items directly:

- Apple Developer Program membership readiness
- D-U-N-S / organization enrollment readiness if shipping as an organization
- App Store Connect metadata completeness
- privacy policy URL
- support URL
- App Review notes
- demo account / demo mode if needed
- screenshots / app preview / icon readiness
- age rating / content disclosures
- export compliance answers
- App Store privacy answers
- privacy manifest accuracy
- third-party SDK privacy manifest/signature requirements
- entitlements correctness
- hardened runtime / notarization readiness for direct distribution
- tax / banking / Small Business Program readiness
- EULA / Terms / Privacy Policy presence

Do not just enumerate them. Check what is actually present in the repo or current launch materials and classify each as:

- `Ready`
- `Needs setup outside repo`
- `Blocked`
- `Not compatible with MAS full build`

## Deliverables you must write before stopping

Create these files:

- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-final-claude-release-audit-report.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-distribution-decision-and-compliance-report.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-manual-runtime-verification-evidence.md`

### Report 1: final audit report

Must contain:

1. Executive verdict
2. What changed on the audited branch
3. Comparison vs older research-mode baselines
4. Remaining regressions, if any
5. Release blockers, if any
6. Exact tests run
7. Exact manual tests run
8. Log-derived findings
9. Fixes made during the audit
10. 3-pass recursive audit result
11. Honest final release-readiness verdict

### Report 2: distribution / compliance decision

Must contain:

1. Recommended shipping model:
   - direct only
   - hybrid
   - MAS-only
2. Why
3. MAS blockers for the full Omega build, if any
4. Direct-distribution checklist
5. MAS-lite checklist
6. Privacy manifest status
7. Entitlements status
8. Export compliance status
9. Tax / banking / enrollment checklist
10. Items needing legal or CPA review
11. Official Apple / government sources used

### Report 3: manual runtime evidence

Must contain:

1. Machine / hardware context
2. Supported visible models on this machine
3. For each tested model:
   - visible modes
   - hidden modes
   - prompts sent
   - results observed
   - logs observed
4. Research-mode evidence
5. Agent/Omega evidence
6. Note AI evidence
7. File-integrity / UTF-16 evidence
8. Permission-flow evidence
9. Screenshots or artifact paths if created

## Rules for this audit

- Do not trust earlier docs that said "ship it" or "green" without rerunning.
- Do not overclaim App Store compatibility for unrestricted desktop automation.
- Do not assume full Omega automation is MAS-safe.
- Do not delete future-facing infrastructure unless it directly harms the release.
- Do not broaden scope into speculative GGUF/llama.cpp/backend work.
- Do not call the app ready if a core manual path is still unverified.
- Do not ignore logs.

## Final success condition

You may only call Epistemos officially release-ready if all of the following are true:

- automated tests are green
- the critical manual runtime matrix is green
- log evidence matches the observed behavior
- model/mode controls are correctly tailored
- research and agent flows are truly working
- note/file integrity looks safe
- distribution strategy is explicitly decided
- legal/compliance/store requirements are either ready or honestly classified
- the reports are written

If you cannot clear all of that, do not soften it. Name the blockers exactly.
