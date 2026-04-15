# PLAN_V2 Canonicalization Redo Handoff

Date: 2026-04-14

Audience: Claude Code / continuation agents

Status: active redo brief

Purpose
This handoff replaces any prior "canonicalization complete" claim for the current session.

Use it when continuing the PLAN_V2 checkpoint and Phase 6 closure work.

The goal is not to write a new plan.

The goal is to make the current product actually canonical with the current local `docs/architecture/PLAN_V2.md`, up through Phase 6, without drifting, without hand-waving, and without claiming closure until the code and verification really support it.

## Non-Negotiable Corrections

These are already known and must be treated as facts for the redo pass:

1. The current local `docs/architecture/PLAN_V2.md` is the authority.
2. Do not use git history as the source of truth for the plan.
3. Do not edit `PLAN_V2.md` during this pass unless the human explicitly asks for a plan revision.
4. Code and sidecar docs must bend to the plan, not the other way around.
5. Do not call Phase 6 closed without the protocol-required manual verification matrix.

## Why The Prior "Done" Claim Was Wrong

The previous canonicalization attempt made real progress, but it overclaimed.

### Drift 3 was not actually fixed

`image_generate` now defaults to `provider: "mlx"` in Rust, but the new Swift MLX service is intentionally hardwired to "not ready" and returns an error envelope on every call.

Current code facts:

- `agent_core/src/tools/media.rs` defaults `image_generate` to `"mlx"`
- `Epistemos/Engine/MLXImageGenerationService.swift` has `isMLXFluxReady == false`
- the new Rust tests explicitly pin "defaults to mlx and fails" as expected behavior

That means the default product path is broken by design right now.

That is not a canonical closure of the plan's "image generation = MLX sidecar mode" requirement.

### Drift 1 is improved but not fully resolved

The new Rust `compile_command_center_request` bridge is real and good progress.

However, Rust still relies on a Swift-supplied tool catalog when compiling Command Center requests:

- `ChatCoordinator` gathers `accState.availableTools`
- `CommandCenterRequestCompiler` serializes that tool catalog into the FFI input envelope
- Rust resolves `resolvedToolPermissions` from that Swift-provided catalog

So Rust is not yet the sole source of truth for tool-permission resolution in the command compiler path.

This is better than the old all-Swift compiler, but it is still not the cleanest PLAN_V2 reading of "Rust owns routing, policy, permissions, and runtime truth."

### Drift 2 cannot be "closed" by rhetoric

`PLAN_V2.md` still does not contain a dedicated Phase 6 roadmap section or a dedicated channel subsystem section.

Because the plan is read-only in this pass, that docs gap cannot be erased by saying "the code is canonical now."

What you can close is code drift against the plan's invariants.

What you cannot close without a human plan edit is a missing plan section.

So be precise:

- code invariants may become canonical
- docs silence in the plan remains a human-owned plan gap unless explicitly revised

### Phase 6 closure still requires manual verification

The protocol still requires real manual/runtime verification for the Communication + Media surfaces.

No amount of unit tests or FFI cleanup replaces that requirement.

## Required Reading Order

Read these before making claims or edits.

### Tier 0 - repo rules

1. `AGENTS.md`
2. `docs/architecture/README.md`
3. `docs/architecture/PHASE_6_PROTOCOL.md`

### Tier 1 - architecture authority

4. `docs/architecture/PLAN_V2.md`
5. `docs/architecture/CODEX_CONTEXT_PACK.md`
6. `docs/architecture/RESEARCH_INDEX.md`
7. `docs/BACKEND_INTERFACE_SPEC_v1.md`
8. `docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
9. `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
10. `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`

### Tier 2 - phase transition context

11. `docs/architecture/PHASE_5_HANDOFF.md`
12. `docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
13. `docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md`

### Tier 3 - code surfaces you must audit before editing

#### Rust

- `agent_core/src/bridge.rs`
- `agent_core/src/command_center.rs`
- `agent_core/src/tools/media.rs`
- `agent_core/src/tools/registry.rs`
- `agent_core/src/agent_loop.rs`
- `agent_core/src/security.rs`
- `agent_core/src/tools/imessage.rs`
- `agent_core/src/tools/imessage_contacts.rs`
- `agent_core/src/tools/communication.rs`

#### Swift

- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/Bridge/ToolTierBridge.swift`
- `Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `Epistemos/Engine/MLXImageGenerationService.swift`
- `Epistemos/State/CommandCenterDiagnostics.swift`
- `Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `Epistemos/Omega/Channels/DriverChannelControlPlane.swift`
- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`
- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift`

#### Tests

- `EpistemosTests/CommandCenterRequestCompilerTests.swift`
- `EpistemosTests/CommandCenterDiagnosticsTests.swift`
- `EpistemosTests/ControlPlaneSurfaceTests.swift`
- `EpistemosTests/DeviceAgentServiceTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

## Current Repo Truth You Should Preserve

These changes are real and should not be thrown away without a concrete reason:

1. The Rust FFI entry point `compile_command_center_request` exists.
2. The Rust module `agent_core/src/command_center.rs` exists and already owns real runtime-resolution logic.
3. The Swift Command Center compiler is now a thin wrapper around Rust plus local mention resolution.
4. The explicit per-tool allowlist is already wired through `ToolTierBridge`, `ChatCoordinator`, and Rust `ToolRegistry`.
5. Relay-to-native fallback telemetry for the channel layer is already present.
6. The iMessage driver rate limit and model-option hardening are already present.
7. The iMessage reply delegate now explicitly denies image generation, which is good and should remain unless the plan changes.

Redo means:

- salvage good work
- remove fake closure claims
- close the real remaining gaps

It does not mean:

- revert everything
- restart from scratch
- widen into Phase 7

## The Real Remaining Gaps

### Gap A - MLX-first image generation is not actually landed

This is the highest-priority code gap.

Current failure shape:

- default provider is `mlx`
- delegate path exists
- service always says "not configured"
- default product behavior therefore fails

Required closure:

1. The default `image_generate` path must actually work in the MLX lane, or the feature must be removed/hidden until it works.
2. Do not silently route that default call to FAL.
3. `provider: "fal"` may remain as the explicit remote opt-in, but only by name.
4. The MLX path must return a truthful success envelope on success and a truthful error on real failure.
5. Tests must stop pinning permanent failure as the canonical expected behavior.

If the MLX image stack truly cannot be made real in this session, do not lie and do not call Drift 3 fixed.

But the mission from the human is to finish canonicalization, so your default assumption should be:

- wire a real MLX sidecar path
- keep FAL explicit-only
- verify at least one live MLX generation if the environment permits

Likely implementation direction:

- make `MLXImageGenerationService` real instead of placeholder-only
- route through the actual local MLX/flux-sidecar machinery already available in this repo or its local packages
- keep the Rust delegate contract unchanged if possible
- return inspectable output paths or URLs in a stable JSON envelope

Do not ship a permanent stub hidden behind a "canonical" comment.

### Gap B - Command Center tool-permission truth still depends on Swift catalog input

The Rust compiler should not need Swift to tell it what the catalog is in order to decide permissions.

Current shape:

- Swift supplies `availableTools`
- Rust uses that to compute `resolvedToolPermissions`

Required closure:

1. Rust should derive tool-permission truth from a Rust-owned catalog or Rust-owned FFI source, not from a Swift-maintained UI snapshot.
2. Swift may still own parsing and vault-backed mention lookup if that cannot be moved cleanly yet.
3. The inspector contract should stay stable if possible.
4. Do not regress the working JSON contract and parity tests.

Preferred target:

- Swift sends user intent only:
  - query
  - mode
  - slash token
  - explicit tool toggles
  - requested brain
  - resolved mention bodies
- Rust derives:
  - tool catalog truth
  - permission decisions
  - runtime truth
  - execution policy
  - notes context

You may need to expose a Rust-side catalog surface or reuse the registry metadata already present in `agent_core`.

### Gap C - Code/path canonicality must be separated from plan-doc silence

Do not claim "all drifts closed" unless you explicitly distinguish:

- code canonicality against plan invariants
- plan-document incompleteness that only the human can resolve

For this pass:

- keep `PLAN_V2.md` untouched
- bring code into alignment with the plan's stated rules
- record any remaining plan-doc silence precisely, not rhetorically

### Gap D - Phase 6 closure still needs real verification

Even after code fixes, do not call Phase 6 closed until:

- required automated verification passes
- required manual/runtime verification is completed or blocked with precise evidence

## Specific Things To Re-Audit In Code

### Command Center

Audit whether any of these still live on the Swift side in a plan-violating way:

- runtime fallback truth
- tool permission truth
- route selection truth
- policy/budget synthesis
- expert allowlist synthesis

The target state is:

- Swift parses and binds UI
- Rust owns control-plane truth
- Swift inspector renders Rust-origin truth

### image_generate

Audit:

- default provider behavior
- delegate registration path
- no-silent-fallback guarantee
- success envelope shape
- error envelope shape
- iMessage reply isolation
- explicit FAL opt-in path

If the default path still errors in a healthy local environment, Drift 3 is not fixed.

### Channel layer

Reconfirm:

- no silent local-to-cloud escalation
- fallback telemetry remains visible
- per-contact rate limiting still works
- settings persistence still works
- no fake success on permissions failures

These were in decent shape already. Do not break them while fixing other drifts.

## Work Sequence

Follow this order.

### Step 1 - Audit current Claude work before rewriting

Do not blindly trust or discard the current partial implementation.

For each of these surfaces, mark:

- real and keep
- real but incomplete
- misleading and replace
- test-only rhetoric with no shipped value

Required surfaces:

- `agent_core/src/command_center.rs`
- `agent_core/src/bridge.rs`
- `Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `agent_core/src/tools/media.rs`
- `Epistemos/Engine/MLXImageGenerationService.swift`
- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`

### Step 2 - Fix image generation for real

Do this before declaring canonicality.

Success means:

- default MLX path is functional
- no fake success
- no forced failure stub
- no silent FAL fallback
- explicit `provider: "fal"` still works as the named remote path

### Step 3 - Finish the Rust authority boundary for Command Center

Move the remaining catalog/permission truth out of Swift-owned state.

Keep the existing Swift-facing compiled-request contract if possible so downstream UI does not churn unnecessarily.

### Step 4 - Re-run focused tests while you work

Minimum:

- Rust command_center tests
- Rust image_generate tests
- Swift CommandCenterRequestCompiler tests
- Swift CommandCenterDiagnostics tests
- Phase 6 Swift control-plane tests

### Step 5 - Run the wider verification sweep

At minimum:

- `cargo test --manifest-path agent_core/Cargo.toml`
- `cargo test --manifest-path epistemos-core/Cargo.toml`
- `cd graph-engine && cargo test`
- `cd omega-mcp && cargo test`
- `cd omega-ax && cargo test`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- focused Phase 6 Swift tests
- a fresh `xcodebuild ... test` sweep if the current tree allows it

If the full Swift suite still has failures, verify whether they are:

- caused by your work
- genuinely pre-existing and still present
- stale tests that must be updated to current project reality

Do not just label them "pre-existing" without proving it.

### Step 6 - Manual runtime verification

Perform what is safe and possible.

Required Phase 6 matrix remains:

- `send_message` real outbound path + missing-credential path
- `vision_analyze` local file path + URL path + provider-backed response
- `image_generate` real generation on the default MLX path
- `text_to_speech` live playback or output file
- `imessage` read path or explicit Full Disk Access denial
- iMessage driver local-model no-cloud-escalation verification

If blocked, classify every blocker precisely:

- credential
- OS permission
- environment
- missing local model/runtime

## Verification Standards

You are not done if the only new MLX test says "defaults to mlx and fails."

You are not done if Rust only compiles permissions from a Swift-provided catalog.

You are not done if the default product path is a stub with a nice error string.

You are not done if you say "canonical" while the plan-doc gap remains unqualified.

## Required Final Deliverables

Your final report must include all of this:

1. Docs read
2. A phase-by-phase canonicality checkpoint through Phase 6
3. Exact remaining drift list, with a clear distinction between:
   - code drift fixed
   - code drift still open
   - plan-doc silence that is human-owned
4. Exact files changed
5. Exact commands run
6. Exact pass/fail counts
7. Manual verification evidence or precise blockers
8. A direct answer:
   - `Phase 6 ready to close`
   - or `Phase 6 not ready to close`

If not ready to close, list exactly why.

## Copy-Paste Startup Prompt For Claude Code

Use this block verbatim:

Read `/Users/jojo/Downloads/Epistemos/AGENTS.md` first, then read the canonicalization bundle in this order:

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/README.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
5. `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`
6. `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
7. `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
8. `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
9. `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
10. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
11. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
12. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md`
13. `/Users/jojo/Downloads/Epistemos/docs/architecture/CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md`

Then audit the current partial canonicalization work already present in the tree. Do not restart from scratch and do not edit `PLAN_V2.md`. Salvage what is real, replace what is misleading, and make the code actually canonical with the current local plan through Phase 6.

Critical known facts you must preserve:

- the current local `PLAN_V2.md` is the authority
- the prior attempt made real progress on Rust Command Center compilation and Phase 6 hardening
- `image_generate` is not actually fixed because the default MLX path is currently a permanent not-ready stub
- the Command Center compiler still depends on a Swift-provided tool catalog for permission truth
- plan-doc silence is not the same thing as code canonicality
- Phase 6 cannot close without the protocol-required manual verification matrix

Your mission:

1. audit the current partial implementation
2. make `image_generate` actually canonical with the MLX-first plan
3. finish the Rust authority boundary for Command Center so Swift is not the source of tool-permission truth
4. rerun focused and broad verification
5. perform manual verification where possible
6. report honestly whether Phase 6 is ready to close

Do not claim Drift 3 fixed unless the default MLX path actually works.
Do not claim Drift 1 fully fixed unless Rust no longer relies on a Swift-owned tool catalog for permission truth.
Do not claim all drifts closed without distinguishing code fixes from human-owned plan-doc silence.
