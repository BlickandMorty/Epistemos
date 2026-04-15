# Phase 6 Protocol

Status: ready to start

Date: 2026-04-14

Audience: Clark / Claude Code / Codex continuation agents

## Purpose

This is the canonical startup and execution protocol for Phase 6 work.

Phase 6 in this repo is the Communication + Media slice:

- `send_message`
- `vision_analyze`
- `image_generate`
- `text_to_speech`
- `imessage`
- `imessage_contacts`

Plus the Swift surfaces that make those capabilities real inside Epistemos:

- `ChannelRegistryState`
- `IMessageDriverService`
- `IMessageReplyDelegate`
- `IMessageDriverSettingsView`
- related bootstrap and routing wiring

This document exists so Clark can load the right context, avoid drifting into old research or stale handoffs, and close Phase 6 against the actual repo state.

## Critical Status Note

Phase 5 is closed enough for Phase 6 to begin.

`docs/architecture/PHASE_5_HANDOFF.md` is still useful, but its old "Phase 6 is blocked" verdict is now historical. Use this file as the active Phase 6 kickoff authority.

## What Phase 6 Is

Phase 6 is not a greenfield build.

The Phase 6 code already exists in the repo:

- `agent_core/src/tools/communication.rs`
- `agent_core/src/tools/media.rs`
- `agent_core/src/tools/imessage.rs`
- `agent_core/src/tools/imessage_contacts.rs`
- `Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`
- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift`

That means Clark must treat Phase 6 as:

- audit
- verify
- harden
- close

Do not restart Phase 6 from scratch unless the code proves a subsystem is fake or nonfunctional.

## Required Reading Order

Clark must read these in order before making architectural claims or code changes.

### Tier 0 — Repo rules

1. `AGENTS.md`
2. `docs/architecture/README.md`
3. `docs/architecture/PHASE_6_PROTOCOL.md`

### Tier 1 — Architecture authority

4. `docs/architecture/CODEX_CONTEXT_PACK.md`
5. `docs/architecture/RESEARCH_INDEX.md`
6. `docs/architecture/PLAN_V2.md`
7. `docs/BACKEND_INTERFACE_SPEC_v1.md`
8. `docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
9. `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
10. `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`

### Tier 2 — Phase 5 to Phase 6 transition context

11. `docs/architecture/PHASE_5_HANDOFF.md`
12. `AGENT_COMMAND_CENTER_UX_HANDOFF.md`

### Tier 3 — Phase 6 implementation context

13. `docs/SKILL_IMPLEMENTATION_PLAN.md`
Read the Phase 6 section and the callback / file-structure sections that touch communication and media.

14. `docs/CODEX_HANDOFF_2026_04_10.md`
Read the sections covering:
- Phase 6 tool list
- iMessage local-model routing
- known build gotchas
- pointer map
- audit checklist items relevant to communication/media

15. `docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`

### Tier 4 — Optional advisory research

If local historical research docs still exist on disk, Clark may read them after the documents above, but they are advisory only and may not override the architecture bundle.

Examples:

- local Claude or Gemini agent research packs
- older Hermes / OpenClaw parity notes
- exploratory agent UX syntheses

Rule:

- architecture docs override historical research
- current code overrides stale implementation-status claims

## What Clark Must Say Before Editing

Clark's first substantial reply must include all of the following:

- a list of the docs read
- a short summary of the Phase 6 scope
- an explicit statement that Phase 6 is already partially implemented in code
- a short list of the most likely closure risks
- a statement of what will be audited before anything is rewritten

If Clark cannot do that, Clark has not loaded enough context yet.

## Non-Negotiable Architecture Rules

Clark must preserve these rules throughout the phase:

- Rust remains the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` remain sibling runtimes.
- No silent backend reroute.
- No silent cloud self-escalation.
- No mid-generation backend switching.
- No second control plane in Swift.
- No hidden permission expansion.
- No fake success on unsupported or permission-denied behavior.
- Destructive communication actions must remain explicit and auditable.
- Phase 6 must not silently widen into Phase 7, marketplace work, persistent memory, or runtime-contract rewrites.

Phase 6-specific rules:

- no test should send real user data to real recipients
- use test accounts, test rooms, test webhooks, or test inboxes only
- missing credentials must fail clearly
- missing Full Disk Access or Automation permissions must fail clearly
- local-model iMessage routes must not silently fall back to cloud
- channel routing and tool tiering must remain explicit and inspectable

## Current Repo Reality Clark Must Respect

Before changing code, Clark must internalize these repo facts:

### Communication

`send_message` already has adapters for:

- slack
- telegram
- discord
- webhook
- matrix
- whatsapp
- signal
- email

So the default assumption is not "implement adapters."
The default assumption is "audit adapter correctness, safety, and live-path behavior."

### Media

`media.rs` already contains:

- `vision_analyze`
- `image_generate`
- `text_to_speech`

Current reality from code:

- `vision_analyze` supports Claude and OpenAI-style vision paths
- `image_generate` uses FAL Flux
- `text_to_speech` uses macOS `say`

So the default assumption is not "design media tools."
The default assumption is "verify the current implementations and close the real gaps."

### iMessage

The repo already has:

- Rust iMessage read/write tooling
- Rust `imessage_contacts` routing storage
- Swift channel registry state
- Swift iMessage driver service
- Swift iMessage settings UI

So the default assumption is not "invent an iMessage architecture."
The default assumption is "verify the architecture already wired and make sure it honors the no-silent-fallback rule."

## Code Audit Map

Clark must read these files before editing any Phase 6 surface.

### Rust

- `agent_core/src/tools/communication.rs`
- `agent_core/src/tools/media.rs`
- `agent_core/src/tools/imessage.rs`
- `agent_core/src/tools/imessage_contacts.rs`
- `agent_core/src/tools/registry.rs`
- `agent_core/src/bridge.rs`
- `agent_core/src/agent_loop.rs`
- `agent_core/src/security.rs`

### Swift

- `Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`
- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/App/ChatCoordinator.swift`

### Tests and validation surfaces

- `EpistemosTests/DeviceAgentServiceTests.swift`
- `EpistemosTests/ControlPlaneSurfaceTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

Rust inline tests in:

- `agent_core/src/tools/communication.rs`
- `agent_core/src/tools/media.rs`
- `agent_core/src/tools/imessage.rs`
- `agent_core/src/tools/imessage_contacts.rs`

## Phase 6 Work Sequence

Clark must follow this order.

### Step 1 — Build the baseline matrix

Before editing, build a Phase 6 matrix with one row per deliverable:

- `send_message`
- `vision_analyze`
- `image_generate`
- `text_to_speech`
- `imessage`
- `imessage_contacts`
- Swift channel registry / driver / settings integration

For each row, record:

- source-of-truth expectation
- files that implement it
- tests that cover it
- whether the path is unit-tested only or live-verified
- open risks
- whether the gap is architectural, implementation, test, or docs-only

Do not implement before this matrix exists.

### Step 2 — Reconcile docs against code

If docs conflict with code:

- architecture docs win on constraints
- code wins on implementation status
- historical handoffs are evidence, not authority

Examples of acceptable reconciliation:

- older docs say a tool is partial, but code now contains the handler and tests
- older plan says implement 3 adapters, but code now has 8

Examples of unacceptable reconciliation:

- using an old research memo to override Rust-sovereign architecture
- claiming a live path is complete when only unit tests exist

### Step 3 — Identify only the real closure gaps

Clark must separate:

- missing implementation
- missing verification
- missing safety hardening
- stale documentation

Do not treat "not manually verified yet" as the same thing as "not implemented."

### Step 4 — Fix one surface at a time

Use this order unless a discovered blocker forces a change:

1. Rust tool correctness
2. registry / permission / tier behavior
3. Swift driver or UI wiring
4. tests
5. docs

### Step 5 — Keep edits phase-scoped

Allowed:

- Phase 6 tool fixes
- Phase 6 verification additions
- iMessage driver hardening
- channel configuration correctness
- docs needed to reflect the true Phase 6 state

Not allowed unless a direct blocker appears:

- Phase 7 intelligence work
- memory system expansion
- marketplace / skill-install work
- runtime contract rewrite
- adaptation experiments
- generalized cloud escalation behavior

## Required Verification Protocol

Clark may not call Phase 6 complete without both automated and manual verification.

### Automated verification

Run these, at minimum:

```bash
cargo test --manifest-path agent_core/Cargo.toml
cargo test --manifest-path epistemos-core/Cargo.toml
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Run focused Swift verification for the communication/iMessage surfaces:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test-without-building \
  -only-testing:EpistemosTests/DeviceAgentServiceTests \
  -only-testing:EpistemosTests/ControlPlaneSurfaceTests \
  -only-testing:EpistemosTests/RuntimeValidationTests
```

If more focused tests are added during the work, rerun them too.

### Manual runtime verification

Clark must perform or explicitly document each of these:

1. `send_message`
- verify at least one real outbound path using a dedicated test destination
- preferred examples: Mailtrap/test SMTP, Slack test webhook, Discord test webhook, Matrix test room
- confirm success path and missing-credential failure path

2. `vision_analyze`
- verify one local file path
- verify one URL path
- verify at least one real provider-backed response with a test image

3. `image_generate`
- verify one real generation with a test API key
- confirm the returned URL is non-empty and fetchable

4. `text_to_speech`
- verify one live playback or one generated output file
- verify failure path for invalid input if touched

5. `imessage`
- verify read-path behavior with a real or test-local Messages database if permissions are available
- otherwise verify the failure message is explicit and truthful about Full Disk Access

6. `iMessage driver`
- verify a local-model contact does not silently escalate to cloud
- verify allow/deny routing behavior
- verify settings persistence through the Swift settings surface

No manual verification, no Phase 6 sign-off.

## Required Safety Checks

Clark must explicitly audit these before calling the phase done:

- communication tools do not leak secrets through logs or outputs
- destructive sends remain permission-gated where intended
- private/local URLs are not accidentally allowed on generic outbound tools
- local-only exceptions are narrowly justified
- iMessage permission failures are explicit, not disguised as empty success
- output redaction still applies where the agent loop expects it
- no new `todo!()`, `unimplemented!()`, `panic!()`, or casual `.unwrap()` appear in touched handler code

## Phase 6 Exit Criteria

Phase 6 is complete only if all are true:

- the Phase 6 scope is documented correctly
- the existing implementations are reconciled against the plans and handoffs
- all real implementation gaps are closed
- all destructive or permission-sensitive paths fail clearly
- no silent local-to-cloud fallback remains on the iMessage local route
- automated verification passes
- manual runtime verification is completed or any blocked checks are precisely documented
- docs are updated so the next session does not need to reverse-engineer Phase 6 status

If any of those are false, Phase 6 is not closed.

## Required Final Deliverables From Clark

Clark must finish with:

- a Phase 6 audit summary
- a gap matrix
- the exact files changed
- the exact commands run
- exact pass/fail results
- manual verification evidence or precise blockers
- a direct answer: "Phase 6 ready to close" or "Phase 6 not ready to close"

If blocked, Clark must list:

- what is blocked
- whether it is code, environment, credential, or OS-permission related
- what remains to be done

## Explicit Do-Not-Drift List

Do not drift into:

- speech-to-text
- audio analysis
- GitHub / Home Assistant / Notion / Linear expansions
- Phase 7 intelligence layer
- memory system redesign
- Agent Command Center redesign
- runtime identity rewrites
- speculative research implementation not anchored in the codebase

## Copy-Paste Startup Prompt For Clark

Use this exact instruction block to start Clark cleanly:

```text
Read /Users/jojo/Downloads/Epistemos/AGENTS.md first, then read the Phase 6 startup bundle in this exact order:

1. /Users/jojo/Downloads/Epistemos/docs/architecture/README.md
2. /Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md
3. /Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md
4. /Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md
5. /Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md
6. /Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md
7. /Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md
8. /Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md
9. /Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md
10. /Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md
11. /Users/jojo/Downloads/Epistemos/AGENT_COMMAND_CENTER_UX_HANDOFF.md
12. /Users/jojo/Downloads/Epistemos/docs/SKILL_IMPLEMENTATION_PLAN.md
13. /Users/jojo/Downloads/Epistemos/docs/CODEX_HANDOFF_2026_04_10.md
14. /Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md

Then audit the current Phase 6 Communication + Media implementation already present in code. Do not restart Phase 6 from scratch. Build a gap matrix first, reconcile docs against current code, make only the changes needed to close real gaps, run the required automated verification, perform manual runtime verification where possible, and do not call Phase 6 complete without explicit evidence.
```
