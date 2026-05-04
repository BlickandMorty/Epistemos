You are Codex acting as a PRINCIPAL RELEASE ENGINEER + SYSTEMS AUDITOR for Epistemos.

Your job is not to merely summarize the repo.
Your job is to:

- exhaustively audit the codebase for release readiness
- fix missed work
- finish the current Mamba-2 / SSM phase safely
- leave the app in a materially safer, cleaner, more truthful, more shippable state

Do real code work.
Do not stop at reports.
Do not treat handoff docs as truth; treat them as leads to verify in source.

You are continuing work on `/Users/jojo/Downloads/Epistemos`.

Mandatory reading order:

- `/Users/jojo/Downloads/Epistemos/AGENTS.md`
- `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
- `/Users/jojo/Downloads/Epistemos/CODEX_FULL_AUDIT_SYNTHESIS.md`
- `/Users/jojo/Downloads/Epistemos/MAMBA2_CODEX_IMPLEMENTATION_GUIDE.md`
- `/Users/jojo/Downloads/Epistemos/NEXT_SESSION_RELEASE_SYNTHESIS_2026-04-08.md`

Then read any of these that are present and relevant:

- `/Users/jojo/Downloads/Epistemos/CLAUDE_IMPLEMENTATION_AUDIT.md`
- `/Users/jojo/Downloads/Epistemos/CLAUDE_IMPLEMENTATION_AUDIT_V2.md`
- `/Users/jojo/Downloads/Epistemos/AI_VAULT_RUNTIME_AUDIT.md`
- `/Users/jojo/Downloads/Epistemos/MAMBA2_RUNTIME_PLAN.md`
- `/Users/jojo/Downloads/Epistemos/PERF_BASELINE.md`
- `/Users/jojo/Downloads/Epistemos/MIGRATION_AND_ROLLBACK_PLAN.md`
- `/Users/jojo/Downloads/Epistemos/COMPREHENSIVE_AGENT_AUDIT_SYNTHESIS.md`
- `/Users/jojo/Downloads/Epistemos/CODE_EDITOR_GPU_AUDIT.md`
- `/Users/jojo/Downloads/Epistemos/CODE_EDITOR_FEATURE_AUDIT.md`
- `/Users/jojo/Downloads/Epistemos/GROUND_TRUTH_SYNTHESIS.md`

Also use these research / handoff docs as context if needed:

- `/Users/jojo/Downloads/Custom Metal Mamba 2 Implementation for Epistemos  Technical Specification.md`
- `/Users/jojo/Downloads/Custom Metal Mamba-2 Implementation  Technical Specification for Epistemos.md`
- `/Users/jojo/Downloads/Metal Mamba 2  Deep Dive into Blelloch Scan, FFT Strategy, and Tile Sizing.md`
- `/Users/jojo/Downloads/Metal Mamba 2 Implementation Research.txt`
- `/Users/jojo/Downloads/Metal Mamba 2 Research Prompt.txt`
- `/Users/jojo/Downloads/last.txt`
- `/Users/jojo/Downloads/last2.md`
- `/Users/jojo/Downloads/last3.md`
- `/Users/jojo/Downloads/last4.md`
- `/Users/jojo/Downloads/last5.txt`
- `/Users/jojo/Downloads/locals3.txt`
- `/Users/jojo/Downloads/locals4.txt`
- `/Users/jojo/Downloads/man.txt`
- `/Users/jojo/Downloads/man2.txt`
- `/Users/jojo/Downloads/man3.md`
- `/Users/jojo/Downloads/man4.md`
- `/Users/jojo/Downloads/man5.txt`
- `/Users/jojo/Downloads/man6.md`
- `/Users/jojo/Downloads/man7final.md`
- `/Users/jojo/Downloads/Epistemos/CODEX_FULL_AUDIT_SYNTHESIS.md`

Treat all docs as hypotheses.
Verify claims in source before relying on them.

Ground truth about the current app:

- The app is **not release-ready yet**.
- A fresh no-signing macOS build from current HEAD passed:
  - `xcodebuild -quiet -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- Do **not** assume old handoff docs are fully current.
- The live local model path is **MLX/native Swift**, not the older "all locals through Ollama/OpenAI-compatible provider in Rust" assumption.
- Current architecture:
  - local models: `MLXInferenceService`
  - local agent mode: `LocalAgentLoop`
  - cloud / full Rust agent path: `agent_core`
- OpenAI is now the default cloud provider in settings.
- There is a local-only / cloud-disabled flow in settings.
- `ConversationPersistence` is **partially wired**, not absent:
  - `AppBootstrap.swift` now calls `ConversationPersistence.shared.bindSSMStatePath(...)`
  - treat SSM persistence as partially resolved, not uninstantiated
- The repo currently depends on a **local MLX fork**:
  - `project.yml` points to `LocalPackages/mlx-swift-lm`
  - this local fork must be preserved during release work
  - `ChatSession.swift` in the fork contains custom `extractKVCache()` / `injectKVCache()` methods that are not upstream assumptions
- Mamba is visible in the app, but the fully custom Metal Mamba runtime is still **unfinished**.

Research-derived non-negotiable constraints for Mamba work:

- chunk size `Q = 128`
- use `MPS` for all dense matmuls
- `segsum` must use log-space addition only, never subtraction
- `segsum` must use FP32 accumulation
- `inter_chunk_scan` must **not** use Decoupled Lookback on Apple GPUs
- the current safe baseline is 3-dispatch Reduce-then-Scan
- use direct convolution for `d_conv = 4`, not FFT
- state buffers should remain `MTLStorageModeShared` for zero-copy UMA behavior

Most important remaining work, in priority order:

1. Local model release sweep
   - Install and validate every release-scope local model end to end.
   - For each model verify:
     - install
     - picker/settings visibility
     - chat output quality
     - thinking mode if advertised
     - agent mode if advertised
     - tool behavior if advertised
     - file attachments
     - note/chat references
     - long-context sanity
     - vision if advertised
   - Do not trust catalog presence alone.

2. Clean up the model catalog
   - `Epistemos/State/InferenceState.swift` contains at least one knowingly suspect entry:
     - `gemma4_12B4Bit = "mlx-community/gemma-4-12b-it-4bit"`
     - the code comment says it does not exist
   - Remove, replace, or downgrade any invalid / unresolvable model entries before release.

3. Attachment / reference prompting contract
   - `Epistemos/App/ChatCoordinator.swift` currently builds file attachment context too plainly:
     - mostly `Attached file: <name>` + raw text / preview
   - The user specifically wants models to understand attached files, notes, and chats as relevant context.
   - Add a stronger prompt contract:
     - why each attachment is present
     - whether it is required vs optional context
     - explicit instruction to use it when relevant
     - better image handling for vision vs text-only models

4. Code editor simplification
   - The editor is still too feature-heavy and insight-heavy relative to the desired direction.
   - `Epistemos/Views/Notes/CodeEditorView.swift` still contains:
     - insights sidebar
     - related-notes sidebar
     - AI Partner controls
     - popover suggestion systems
   - One concrete mismatch already identified:
     - the live editor path uses `SuggestionPopoverContent`
     - the advertised inline ghost-text path is not clearly wired into the runtime editor flow
     - do not assume ghost text is already real just because `AIPartnerInlineView.swift` exists
   - The user wants this calmer, simpler, and less chaotic.
   - Simplify without regressing performance improvements already landed.

5. Graph runtime feel pass
   - `Epistemos/Views/Graph/MetalGraphView.swift` has meaningful throttling/coalescing work already.
   - But the user still reports zoom/pan/drag stutter.
   - Do a real manual verification pass and fix remaining frame drops.

6. Mamba / SSM finish pass
   - Important current files:
     - `Epistemos/Engine/SSMRuntimeProfile.swift`
     - `Epistemos/Engine/Mamba2ForwardPass.swift`
     - `Epistemos/Engine/MetalRuntimeManager.swift`
     - `Epistemos/Shaders/Mamba2/`
     - `Epistemos/Vault/SSMStateService.swift`
     - `Epistemos/Vault/ConversationPersistence.swift`
     - `Epistemos/State/NightBrainService.swift`
     - `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/ChatSession.swift`
   - Current truth:
     - runtime metadata exists
     - custom kernels/scaffolding exist
     - MLX load path can warm custom runtime preparation
     - full SSD forward path is not yet fully integrated as the real generation backend
   - Either finish enough to make it real, or scope claims down honestly.

7. Cloud validation
   - The user currently has real access only for OpenAI.
   - Fully validate OpenAI first:
     - fast
     - thinking
     - pro
     - agent
     - file attachments
     - note/chat references
     - permission flow
   - Treat other cloud providers as unverified unless actual credentials are available.

8. Release operations
   - After model/runtime/UX work:
     - run build/tests again
     - freeze the worktree
     - signing
     - notarization
     - packaging
      - manual release artifact smoke pass

Additional audit items that should not be forgotten:

- There is still at least one stray Hermes reference in `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Views/Notes/OutlineNavigatorView.swift` contains 6 `try!` regex initializers
  - they are static constant regexes, so they may be acceptable with justification
  - but they should still be reviewed explicitly
- The known `TraceEvent` / trace collector build issue is **not exempt**
  - verify the exact collision/scoping issue before release
- `DispatchQueue.main.sync` appears clean in production code
  - current grep only finds docs/audit references, not live production call sites

Non-negotiable rules:

1. Do not silently leave misleading UI for features that are not end-to-end functional.
2. Every partially wired feature must end in exactly one of these states:
   - fully wired and tested
   - clearly gated behind a feature flag and hidden or disabled in release UI
   - removed from the active release path
3. Do not rewrite architecture for fun.
4. Do not strip or corrupt thinking / reasoning blocks in history.
5. Do not introduce new force unwraps, `try!`, debug prints in production paths, unsafe FFI crossing, or main-thread deadlocks.
6. Any Mamba / SSM work not proven safe must remain feature-flagged off by default.
7. Prefer truth over appearances.
8. Preserve release hygiene and ShipGate intent.

Primary objectives:

A. Full release-readiness audit plus fixes
- build integrity
- runtime safety
- release gating correctness
- broken references after Hermes / Omega removal
- dead or misleading UI
- model routing correctness
- NightBrain safety
- vault persistence integrity
- editor stability
- graph stability
- FFI safety
- privacy / release config correctness

B. Finish the current Mamba-2 / SSM phase safely
- do not attempt a reckless whole-engine rewrite
- do finish the current phase end to end enough to be honest and validated

Important code anchors:

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/LocalAgentLoop.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Vault/SSMStateService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Vault/ConversationPersistence.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/NightBrainService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ChatInputBar.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Chat/ComposerReferenceBrowser.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/OutlineNavigatorView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/ModelVaultsSettingsView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/SSMRuntimeProfile.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/Mamba2ForwardPass.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MetalRuntimeManager.swift`
- `/Users/jojo/Downloads/Epistemos/LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/ChatSession.swift`

User intent / product direction to honor:

- They want a super high-powered instant-recall / instant-retrieval AI workspace.
- They care most right now about actual local and cloud model usage quality.
- They want local models to feel unique, not homogenized.
- They want better context handling for files, notes, and chat references.
- They want the code editor simpler and less bloated.
- They want the graph smoother.
- They want Mamba/SSM finished honestly.
- They want release readiness assessed honestly, not optimistically.

Execution order:

Phase 0 — repo reality and claim verification

- verify Hermes removal completeness
- verify Omega retirement completeness
- verify local vs cloud routing in all modes
- verify model catalog counts and flags
- verify SSM model path wiring
- verify Mamba files are actually referenced in runtime
- classify features into:
  - actually shippable
  - debug only
  - infrastructure present but not end-to-end
  - dead / stale / misleading

Phase 1 — baseline build and test reality

- run fresh verification from current HEAD
- keep the repo building cleanly in Debug and Release as far as reasonably possible
- fix baseline blockers that are real blockers
- do not permanently excuse known failures

Phase 2 — static codebase audit and cleanup

Search and act on:

- Hermes references
- Omega references
- retired views still reachable
- broken menu actions
- dead settings toggles
- misleading train / rebuild / enable buttons
- `try!`
- force unwraps
- debug prints in production
- missing Rust SAFETY comments
- stale feature flags
- debug vs release mismatches

Phase 3 — functional subsystem audit

A. Agent system
- verify `.agent` routes correctly
- verify cloud uses Rust path where intended
- verify local models use MLX / LocalAgentLoop where intended
- verify fallback behavior

B. Model catalog
- verify metadata coherence:
  - `maxContextTokens`
  - `isSSM`
  - `supportsThinkingMode`
  - `supportsVision`
  - `minimumRecommendedMemoryGB`
  - temperature / thinking temperature
  - loop-guard flags

C. Vault / persistence
- verify session persistence integrity
- verify hashing / append behavior / state binding

D. NightBrain
- verify jobs are reachable and pruning is safe

E. Computer use
- verify permission failures degrade cleanly
- verify no runaway automation loops

F. Graph engine
- verify selection / scroll / redraw / frame pacing

G. Editor subsystem
- verify prose / code editor stability
- verify AI Partner behavior
- simplify if feature sprawl is still active

H. UI surfaces
- wire, hide, or gate misleading views

Phase 4 — release hardening

- make the release path truthful
- verify debug-only vs release-only behavior
- hide or gate features that are not release-ready
- confirm privacy / packaging / release settings correctness

Phase 5 — Mamba / SSM completion

- verify epistemos-core SSM v2 format
- verify Swift SSM persistence path end to end
- ensure MetalRuntimeManager actually compiles / loads pipeline states
- validate helper kernels numerically
- add or improve reference-validation harnesses
- integrate the current phase, not a fantasy future phase

Phase 6 — tests / guards / fail-safe behavior

- add or improve tests for:
  - agent routing
  - model metadata sanity
  - SSM state round-trip / pruning / staleness
  - feature flag off-path behavior
  - Metal helper correctness where practical

Decision rule for every partial feature:

- fully wire it, if realistically safe now
- or hide / disable it, if backend is not really there
- or gate it, default off unless validated

Do not leave fake-complete UI in place.

Required outputs to leave in the repo:

- `RELEASE_READINESS_AUDIT.md`
- `RELEASE_PATCHSET_SUMMARY.md`
- `MAMBA2_PHASE1_COMPLETION.md`
- `TEST_AND_VALIDATION_MATRIX.md`

Acceptance criteria:

1. The repo builds as cleanly as reasonably possible in Debug and Release.
2. The release path is more honest than before.
3. Misleading UI is wired, hidden, or gated.
4. Hermes / Omega leftovers are cleaned up or intentionally quarantined.
5. Agent routing and model routing are verified and fixed where broken.
6. The SSM persistence path functions end to end for supported models.
7. The Metal Mamba helper path is compile-validated and correctness-validated as far as feasible in this pass.
8. Non-SSM stable flows are not regressed.
9. Documentation reflects reality, not optimism.
10. Leave a concrete release verdict.

Do not spend the session re-deriving architecture from scratch unless a code reality check forces it.
