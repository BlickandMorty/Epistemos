# Epistemos Qwen + Knowledge Fusion Release Plan

**Date:** 2026-03-27  
**Status:** Final release-scope pivot  
**Decision authority:** User handoff, 2026-03-27

This plan consolidates the release-relevant conclusions from:
- `docs/plans/2026-03-27-training-readiness-final-gap-analysis.md`
- `/Users/jojo/Downloads/soaar and research mode/2026-03-27-master-gap-closure-plan.md`
- `/Users/jojo/Downloads/soaar and research mode/Epistemos Training Readiness Audit.md`
- `/Users/jojo/Downloads/soaar and research mode/Epistemos Next-Generation Research Mode  Migration Blueprint.md`
- `/Users/jojo/Downloads/soaar and research mode/new/Epistemos Next-Generation Research Mode  Migration Blueprint 2.md`
- `/Users/jojo/Downloads/soaar and research mode/Omega Research & SOAR Redesign.md`
- `/Users/jojo/Downloads/soaar and research mode/new/EPISTEMOS-FEATURE-SPEC.md`
- `/Users/jojo/Downloads/soaar and research mode/new/EPISTEMOS-FEATURE-SPEC copy.md`
- `/Users/jojo/Downloads/soaar and research mode/new/EPISTEMOS-PLUGIN-PORTING-SPEC.md`
- `/Users/jojo/Downloads/soaar and research mode/new/Epistemos-Essay.md`

## 1. Executive Decision

Epistemos ships as a **Qwen-first local product**.

- **Keep:** local Qwen runtime, Apple Intelligence lightweight routing, Knowledge Fusion adapters, QLoRA, KTO, replay, feedback, adapter registry/loader, ODIA traces, Omega, research mode, instant recall, ambient context systems.
- **Do not ship as a milestone:** custom base-model creation, MOHAWK distillation, Mamba-hybrid runtime, RunPod teacher-student training, custom 1B base model, distillation as a release gate.
- **Frame Knowledge Fusion honestly:** it is a **Qwen adapter and alignment layer**, not a promise that Epistemos is shipping its own new foundation model.
- **Frame Omega honestly:** it is a **deterministic local orchestration and research system**, not a magical autonomous hidden brain.
- **Treat feature/plugin specs as alignment only:** only tiny cherry-picks that directly improve Qwen usability, Omega research usability, note workflow quality, retrieval quality, shipping polish, or release stability are in scope.

Current runtime read after reviewing the referenced files:

- **Already aligned with the pivot:** `TriageService.swift`, `PipelineService.swift`, `MLXInferenceService.swift`, `LLMService.swift`, `LocalModelInfrastructure.swift`, `SetupAssistantView.swift`, `ResearchOrchestrator.swift`, `/research` routing in chat surfaces, and the new research tools in Omega.
- **Still needs release cleanup in wording or gating:** `TrainOnVaultView.swift`, `OmegaSettingsDetailView.swift`, and `TrainingScheduler.swift`.

## 2. What Qwen Owns

Qwen is the production runtime. These are the surfaces that define whether the release is real.

| Area | Files | Current read | Release rule |
|---|---|---|---|
| Local model catalog | `Epistemos/Engine/LocalModelInfrastructure.swift` | Six Qwen 3.5 local variants are defined and recommended by hardware tier | Verify install, selection, and load behavior for the supported tiers |
| Inference runtime | `Epistemos/Engine/MLXInferenceService.swift`, `Epistemos/Engine/LLMService.swift` | Mature local inference path exists | Treat this as the primary production engine |
| Routing | `Epistemos/Engine/TriageService.swift` | Already explicitly identifies the local assistant as Qwen and avoids fake hidden-capability claims | Keep product messaging aligned with this file |
| Note AI pipeline | `Epistemos/Engine/PipelineService.swift`, `Epistemos/State/NoteChatState.swift` | Core note chat and note operations already ride the Qwen path when needed | Must be stable before any training claims matter |
| Model selection UI | `Epistemos/App/RootView.swift`, `Epistemos/Views/Settings/SettingsView.swift` | Qwen install/select surfaces already exist | This is the main user-facing recovery path |
| Onboarding | `Epistemos/Views/Onboarding/SetupAssistantView.swift` | Already uses restrained, accurate local-model copy | Keep this tone; do not regress into custom-model language |
| Omega planning model | `Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift` | Research and tool-planning prompts already assume local model planning | Keep Omega on Qwen, not on deferred model work |

Release truth:

- Qwen owns main chat, note AI, local reasoning, local planning, and model installation.
- Apple Intelligence remains the light local companion tier for lightweight work.
- Cloud paths, if still present in code, are not the core product promise for this release.

## 3. What Knowledge Fusion Owns

Knowledge Fusion stays in scope, but only as the personalization layer on top of Qwen.

| Area | Files | Current read | Release rule |
|---|---|---|---|
| Adapter registry | `Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift` | Solid, atomic, separate-adapter design | Keep |
| Adapter hot-swap | `Epistemos/KnowledgeFusion/Adapters/AdapterLoader.swift` | Correctly keeps adapters separate from base weights | Keep |
| Manual training | `Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift`, `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift` | Real training path exists, but output quality and run completion are still unproven | Ship as Experimental |
| Preference alignment | `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift` | Wired and worth keeping | Ship as Experimental |
| Nightly scheduler | `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift` | Scheduler exists, but deploy-gate behavior is still placeholder-level | Keep only with fail-closed rules and opt-in boot behavior |
| Feedback and replay | `KnowledgeFusionViewModel.swift` plus logger/replay paths | Worth keeping; compatible with Qwen adapters | Keep |

Important boot-time truth:

- `Epistemos/App/AppBootstrap.swift` configures `KnowledgeFusionViewModel.shared` at launch and calls `loadState()`.
- `loadState()` in `KnowledgeFusionViewModel.swift` starts scheduler registration.
- That is acceptable for release **only because actual training remains opt-in** and `omega.overnightTraining` stays off by default.

Model-agnostic systems that remain in scope with the Qwen pivot:

- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `Epistemos/State/AmbientCaptureService.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/State/NightBrainService.swift`
- `Epistemos/State/NoteChatState.swift`

These are not to be cut simply because the custom base-model program is deferred.

## 4. What Ships As Experimental

These features stay visible, but only with honest expectations.

| Feature | Files | Why it stays Experimental |
|---|---|---|
| Train on Vault | `Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift` | Real path exists, but end-to-end success and quality are not yet dependable |
| Personal adapters | `AdapterSelectorView.swift`, `TrainingHistoryView.swift` | Adapter mechanics are real; adapter quality is still maturing |
| KTO feedback alignment | `KTOTrainer.swift`, feedback logging path | Signal collection is valuable, but results are still unproven |
| Overnight adapter training | `TrainingScheduler.swift`, `OmegaSettingsDetailView.swift` | Scheduler exists, but the deploy gate is not yet a trustworthy evaluator |
| Embodied capture | `Omega/Orchestrator/OrchestratorState.swift`, capture services | Useful for future data quality, but not yet a polished shipping promise |
| Omega research mode | `ResearchOrchestrator.swift`, `ResearchComplexityGate.swift`, research tools | Real and useful, but still new enough to label honestly where surfaced |

Experimental means:

- The feature is available.
- The feature is never required for core product value.
- Failure must leave base Qwen workflows intact.
- The UI does not promise self-improving intelligence, autonomous overnight model upgrades, or a custom base model.

## 5. What Is Hidden Because It Belongs To The New Base-Model Program

These ideas may remain on disk as future work, but they are not part of the shipping promise and should not be foregrounded in release messaging or UI.

| Program item | Action |
|---|---|
| MOHAWK distillation | Hidden from release messaging and user-facing milestone language |
| Custom 1B base model | Hidden from release scope and ship criteria |
| Mamba-hybrid architecture | Hidden from release messaging |
| RunPod teacher-student pipeline | Hidden from release scope |
| Distillation as a shipping gate | Hidden and deferred |
| CoreML export for a new custom model | Hidden and deferred |
| Any claim that Epistemos is shipping its own new foundation model | Remove from user-facing copy |
| Any UI reference to "Nano" that implies a shipping custom model | Rename to "local model" or "Qwen adapter" |

Hidden does **not** mean remove from the repository. It means:

- do not market it,
- do not make it a checklist item for this release,
- do not block Qwen shipping on it,
- do not let adjacent UI text imply it already exists.

## 6. Qwen Recovery Plan

The shortest path to a real release is proving the Qwen path is solid.

1. Verify first-run install flow.
   - `SetupAssistantView.swift` should lead users cleanly into local model setup.
   - `SettingsView.swift` and `RootView.swift` must recover cleanly when no model is installed.
2. Verify recommended-model behavior.
   - The recommended tier for the current machine must match `LocalModelInfrastructure.swift`.
   - The default 4B-class recommendation must be validated on the target 18 GB hardware tier.
3. Verify install, select, unload, and reload.
   - Switching between supported Qwen tiers must not wedge inference.
4. Verify routing.
   - Lightweight operations stay on Apple Intelligence when appropriate.
   - Deeper work routes to local Qwen.
   - User-facing errors clearly tell the user to install/select a supported local Qwen model.
5. Verify note workflows.
   - Main chat, note chat, rewrite, summarize, expand, continue writing, and analysis all work against the current local runtime.
6. Verify Omega planning on Qwen.
   - Regular tasks produce usable tool plans.
   - Research tasks produce research-shaped plans without invoking any old standalone research subsystem.

## 7. Knowledge Fusion Stabilization Plan

Knowledge Fusion does not need to be perfect for release. It needs to be safe, honest, and clearly subordinate to the Qwen runtime.

1. Fix deploy-gate behavior.
   - `TrainingScheduler.runDeployGate()` still accepts too much placeholder logic.
   - Release rule: fail closed unless real evaluation is available.
   - Manual adapter activation through the settings UI remains acceptable.
2. Keep boot-time state loading, but not autonomous promises.
   - Registry, active adapter state, and feedback loading at startup are good.
   - Overnight work remains opt-in and off by default.
3. Unify the framing.
   - All training language should say "Qwen adapters," "local model personalization," or "adapter training."
   - Do not imply a new base model is being created.
4. Verify adapter lifecycle.
   - Train -> register -> activate -> deactivate -> delete must be mechanically sound.
5. Keep KTO, replay, feedback, registry, loader, and scheduler in scope.
   - These are core to the Qwen-plus-adapters story.
6. Keep retrieval and context systems active.
   - Instant recall, ambient capture, event storage, night processing, and note-context injection remain valuable regardless of base-model deferral.

Release mismatches corrected in the closure pass:

- `TrainOnVaultView.swift` no longer uses "Autoresearch" or "model improves while you sleep" language.
- `OmegaSettingsDetailView.swift` now uses experimental adapter-training language and no longer references training data "for Nano."
- `TrainingScheduler.swift` now fails closed for automatic deployment.
- `/research` routing in `MiniChatView.swift` and `ChatView.swift` now visibly acknowledges the Omega handoff and opens the Omega panel instead of silently disappearing from chat.

## 8. Omega / Research Simplification Plan

Omega and research remain in the product, but with a simpler and more honest promise.

- Research is an **Omega task type**, not a revived standalone subsystem.
- `ResearchOrchestrator.swift`, `ResearchComplexityGate.swift`, `ResearchEvidenceScorer.swift`, and `ResearchConfidenceState.swift` are the correct shape for release.
- `/research` routing in `MiniChatView.swift` and `ChatView.swift` is aligned with the migration blueprint.
- `OmegaPanel.swift` already exposes research as a quick action and keeps execution visible.
- Research tool surfaces are already represented in `SafariAgent.swift`, `NotesAgent.swift`, and `MCPBridge.swift`.

Release framing:

- Omega is for task orchestration, local planning, research, and tool execution.
- Research mode is for structured source gathering, evidence scoring, contradiction checks, and research-note creation.
- Do not describe Omega as a hidden persona, an autonomous brain, or a self-improving super-agent.
- Keep the old standalone research architecture dead.

## 9. UI and Messaging Plan

This is where the pivot must become visible.

### Keep as-is or very close

- `Epistemos/Views/Onboarding/SetupAssistantView.swift`
  - Current copy is restrained and already aligned with the Qwen-first release.
- `Epistemos/Engine/TriageService.swift`
  - The baseline local system prompt is already honest and Qwen-specific.
- `Epistemos/App/RootView.swift`
  - The local model picker already points users toward local Qwen.

### Reword for release honesty

- `Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift`
  - Replace broad "Knowledge Fusion fine-tunes your local AI model" marketing with "Create a personal Qwen adapter from your vault notes."
  - Remove or soften "Autoresearch" and "improves while you sleep" claims.
  - Keep privacy and on-device framing.
- `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
  - Rename "Overnight autoresearch" to "Overnight adapter training (Experimental)" or equivalent.
  - Replace "Generates embodied training data for Nano" with language about local adapters or local model improvement data.
- `Epistemos/Views/Settings/SettingsView.swift`
  - Knowledge Fusion section remains visible.
  - Experimental labeling should be explicit on the training-facing surfaces, not hidden in prose.

### Release copy rules

- Prefer "Qwen," "local model," "adapter," and "personalization."
- Avoid "new model," "custom base model," "Nano" in a shipping-model sense, "self-improving," and "autonomous brain."
- Research copy should emphasize visibility, determinism, evidence, and user control.

## 10. Spec-Derived Cherry Picks For This Release

The feature spec, plugin porting spec, essay, and research blueprints are guidance, not automatic scope.

### Allowed now

| Item | Why it is allowed |
|---|---|
| Existing Omega research tools and their registration | Directly improves research usability and is already largely expressed in code |
| `/research` routing in chat surfaces | Tiny, release-safe usability improvement and already present |
| OmegaPanel research quick action | Small discoverability win and already present |
| Honest Experimental labeling for training and research surfaces | Direct shipping polish |
| Qwen install/select/runtime polish | Direct release value |
| Adapter lifecycle safety fixes | Direct release stability |
| Deploy-gate fail-closed behavior | Direct release safety |

### Deferred after release

| Item | Why it is deferred |
|---|---|
| Broad plugin parity work | Not release-critical and explicitly out of scope |
| Dataview-style query waves | Too large |
| Plugin SDK architecture | Too large |
| Terminal ecosystem expansion beyond direct ship blockers | Too large |
| VLM desktop-control program | Too large |
| Agent profiles / multi-instance architecture | Too large |
| CI/CD feature-spec waves unless directly blocking release operations | Useful, but not the product pivot itself |
| Large porting or parity initiatives across Notion/Obsidian/Logseq | Explicitly out of scope |

### Explicitly out of scope

- custom base-model shipping,
- distillation as a release milestone,
- Mamba-hybrid shipping,
- RunPod teacher-student work,
- broad ecosystem parity initiatives.

## 11. Verification Plan

No ship-ready claim is valid until this section passes.

### Manual release verification

1. Qwen install and selection
   - Fresh install with no local model
   - Install recommended model
   - Select a different installed model
   - Confirm inference still works after switching
2. Core workflows
   - Main chat
   - Note chat
   - Rewrite / summarize / expand / continue writing
   - Omega task execution
   - Omega research task execution
3. Knowledge Fusion safety
   - Training UI appears and is labeled Experimental
   - Failed training does not break the app
   - Adapter activation and deactivation do not break base Qwen
   - Overnight training is off by default
   - Deploy gate does not silently auto-promote an unevaluated adapter
4. Research correctness
   - `/research` routes into Omega
   - research quick action works
   - research tools produce visible, logged steps
   - contradiction/pause flow stays user-visible

### Automated verification

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd omega-mcp && cargo test
```

Recommended release-specific assertions:

- Qwen install/select path works from a clean local state
- `TriageService` keeps the Qwen-first local framing intact
- `ResearchOrchestrator` and research tool registration tests still pass
- `TrainingScheduler` fails closed when evaluation is unavailable

## 12. Ship Checklist

### Must be true before release

- [ ] Qwen install/select/runtime path is verified from a clean start
- [ ] Apple Intelligence and local Qwen routing work as intended
- [ ] Main chat, note AI, and Omega planning are stable
- [ ] Research mode is present, useful, and honestly framed
- [ ] Knowledge Fusion remains visible as a Qwen adapter layer
- [ ] Training-facing features are labeled Experimental where needed
- [ ] Overnight training is off by default
- [ ] Deploy gate fails closed unless real evaluation exists
- [ ] No user-facing copy promises a custom base model
- [ ] No user-facing copy uses "Nano" in a shipping-model sense
- [ ] Broad plugin/spec work is deferred, not silently pulled into release scope
- [ ] Automated verification passes
- [ ] Manual smoke verification passes

### Execution order for the release pass

1. Qwen recovery
2. Knowledge Fusion stabilization on Qwen
3. Hide only new-base-model work
4. Apply experimental labeling where needed
5. Run full verification
