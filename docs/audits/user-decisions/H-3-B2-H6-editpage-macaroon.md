# H-3 / B2-H6 EditPage Macaroon - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide the shape and timing of the Local Engineering Agent / EditPage capability: whether Epistemos should ship a capability-gated `edit_note_block(page_id, block_id, new_markdown, capability_token)` tool, keep MAS V1 limited to existing attachment/read/write surfaces, or route the full agent-editing feature to Pro/post-V1.

The reconciliation gate changes the framing. The app already has live note attachments, session-scoped write-grant plumbing, inlined attached-note context, and whole-note edit/write tools. That current surface is useful, but it is not the H-3/B2-H6 feature. The missing feature is narrower and safer: a block-scoped edit tool gated by a single-use macaroon, tied to provenance, Undo, stale-block checks, and the existing note storage/editor save path.

The decision is therefore not "attach notes or not." It is the capability contract for agent edits:

- Should a full `edit_note_block` mutation surface ship before MAS V1, in V1.1, or Pro-only?
- Should the token expire by wall-clock TTL, event-count/one-shot semantics, or both?
- Should scope be path-based, page-based, block-based, or page+block-based?
- Should the existing path/whole-note `vault.write` and `note.edit` tools count as enough, or should H-3 require a dedicated block tool?

## Options

### Option A - V1.1 block-scoped EditPage macaroon with one-shot semantics

Ship MAS V1 with the existing attachment and write-grant substrate, but do not expose `edit_note_block` until V1.1. For V1.1, implement the tool as a dedicated block edit with a single-use capability token.

Recommended capability shape:

- Tool caveat: `ToolNameEq { name: "edit_note_block" }`
- Page scope: durable `page_id`, not mutable path.
- Block scope: `block_id` plus expected previous block hash.
- Expiry: short wall-clock `ExpiryAfter` as a backstop.
- Consumption: event-bound one-shot semantics, aligned with Hermes §5.2 / B2-H20 `Caveat::OneShot { run_event_id }`.
- Provenance: successful edit emits effect/inverse, execution receipt, note-edit claim, and UndoLog row.

**Pros**
- Matches the design doc's intent without pulling unfinished mutation UX into MAS V1.
- Uses the shipped macaroon substrate instead of inventing a separate permission object.
- Treats existing write tools as lower-level substrate, not the user-facing safe agent-edit contract.
- Gives Undo/provenance a clear consumer.
- Page+block+hash scope sharply reduces accidental whole-note rewrites.

**Cons**
- Requires a real V1.1 implementation slice across Rust tools, macaroons, Swift editor bridge, provenance, and Undo.
- Needs the B2-H20 one-shot/consume primitive or an equivalent one-shot ledger before it is complete.
- Requires user signoff because the design doc is explicitly design-only.

### Option B - Full V1 `edit_note_block` now

Implement the full capability-gated block edit feature before MAS V1.

**Pros**
- Delivers the hero local-engineering-agent capability immediately.
- Removes the ambiguity between existing path-based write tools and the future block-scoped tool.
- Creates an early end-to-end test of macaroons, Undo, note storage, and live editor forwarding.

**Cons**
- The source design doc says no code should land until explicit user signoff.
- The one-shot capability semantic is not implemented in `macaroons.rs` yet.
- The Undo and provenance consumer wiring for this feature is not done.
- App Review/product risk is higher because partially implemented agent mutation can confuse users and reviewers.

### Option C - Keep MAS to existing attachments/write grants; no dedicated EditPage tool

Declare the current live/snapshot attachment system plus `vault.write`/`note.edit` good enough for MAS, and do not build `edit_note_block`.

**Pros**
- Minimal implementation work.
- Keeps the current tool inventory simpler.
- Avoids adding another capability type.

**Cons**
- Does not satisfy the H-3/B2-H6 design goal of a single-use, block-scoped, provenance-backed edit.
- Whole-note/path writes are broader than necessary for agent editing.
- Does not solve stale-block or concurrent-human-edit safety.
- Leaves "local engineering agent edits attached notes" as an unsafe convention rather than a typed contract.

### Option D - Pro-only full mutation; MAS keeps attach/read context

Keep MAS V1 and MAS V1.1 away from agent note mutation. Build `edit_note_block` only in the Pro stream.

**Pros**
- Lowest MAS review risk.
- Lets Pro carry experimental agent-edit UX first.
- Can use broader Pro-only policy surfaces if needed.

**Cons**
- The original design is explicitly MAS-compatible and in-process, so Pro-only is more conservative than technically required.
- Delays a signature local-first feature for MAS users.
- Still requires the same macaroons, one-shot, Undo, and provenance work.

## Canonical Sources

### `docs/audits/LOCAL_ENGINEERING_AGENT_DESIGN_2026_05_10.md`

- Lines 1-8: design-only status; local agent can read vault and live-edit attached notes, with no inbound listener, daemonized port, or MAS-incompatible surface.
- Lines 12-22: goals require attach-note-to-chat, in-place edits, provenance guarantees, in-process `agent_core::agent_runtime`, and MAS shippability.
- Lines 24-35: non-goals forbid open ports, subprocesses, AnswerPacket/EpiKernel architecture work, theme work, graph visuals, and camera work.
- Lines 37-46: proposed surface table names single-use `EditPage(page_id, expires_at)` macaroons, `edit_note_block(page_id, block_id, new_markdown, capability_token)`, the existing Tiptap bridge, and provenance ledger claims.
- Lines 47-68: required failure modes include window close, page move/delete, multiple edits requiring fresh capability, and concurrent human edit draining the autosave pipeline.
- Lines 70-81: MAS compatibility rationale.
- Lines 83-91: design does not promise live collaboration, per-turn edit limits, or rollback UI yet.
- Lines 93-105: implementation slices list capability type/ledger, tool/tests, attach affordance, Tiptap bridge, provenance GenUI, and MAS E2E.
- Lines 107-116: open questions include edit-only vs create-new, wall-clock vs ledger-event expiry, and ACS interaction.
- Lines 120-121: no code lands until the user explicitly says to build P9 slice 1.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- PASS 1 H-3 identifies Local Engineering Agent / Attach-Note-To-Chat as an RCA13 P9 user-decision item.
- The audit describes the target as attached-note in-place edit with provenance and a MAS-shippable hero capability.
- Destination guidance says to add `edit_note_block` / `EditPage` macaroon coverage to Hermes §7.1 or MAS §B.10.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md`

- PASS 2 B2-H6 repeats the same feature through the capability-gating lens.
- The required tool signature is `edit_note_block(page_id, block_id, new_markdown, capability_token)`.
- The required policy properties are single-use macaroons, ledger-tracked edits, no subprocesses/ports, and MAS compatibility.

### `agent_core/src/cognitive_dag/macaroons.rs`

- Lines 1-28: shipped Phase 8.C macaroon substrate with issue/restrict/delegate/revoke, HMAC-chain signature, capability hash, and revocation cascade integration.
- Lines 37-57: current `Caveat` variants are `ScopePrefix`, `ExpiryAfter`, `ToolNameEq`, and `AdditionalContext`.
- Lines 75-100: `Macaroon` carries location, base kind/scope, optional expiry, ordered caveats, delegation marker, and signature.
- Lines 155-184: `issue` creates root capabilities.
- Lines 186-214: `restrict` appends caveats without widening the token.
- Lines 229-248: `verify_macaroon` verifies the signature chain.
- Lines 250-340: `evaluate_caveats` composes expiry, scope prefix, tool name, and additional context at runtime.
- Current gap: no `EditPage` caveat, no `OneShot` caveat, and no consume-on-use API.

### `agent_core/src/cognitive_dag/dispatch.rs`

- Lines 46-73: process-local cognitive DAG store registers system and per-mirror capability hashes.
- Lines 76-104: `system_mirror_macaroon()` creates a process-local system mirror macaroon.
- Lines 118-139: `derive_mirror_macaroon(scope_prefix)` narrows the system macaroon by scope prefix.
- Current gap: these are mirror/system helper wrappers, not an EditPage issuance/consume surface.

### `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`

- Lines 414-460: Hermes §5.2 forward-stages `Caveat::OneShot { run_event_id }`, `issue_ephemeral`, and `verify_and_consume_ephemeral`.
- Lines 584 and 631: Hermes §5.4 names H-3 `edit_note_block` as a V1.1 consumer of the Effect/Inverse Undo backbone.
- Lines 720-721: Hermes §7.1 lists `note.attach_readonly` as a V1 stub and `edit_note_block` as a V1.1 deferred hero tool.

### `Epistemos/Models/ChatTypes.swift`

- Lines 127-140: `ContextAttachmentResourceMode` distinguishes `Snapshot` read-only attachments from `Live` resource handles.
- Lines 142-177: `ContextAttachment` carries `resourceURI`, `resourceMode`, and `resourceCapabilities`.
- Lines 180-218: attachments can convert into Rust-side `AttachedResource` values.

### `Epistemos/Views/Chat/NotesMentionDropdown.swift`

- Lines 81-117: note references with a vault-relative path become `.live` attachments with default read/write capabilities.
- Lines 159-192: live file attachments also receive read/write capabilities.
- Lines 195-222: pasted text becomes a `.snapshot` attachment with read-only capability.

### `Epistemos/App/ChatCoordinator.swift`

- Lines 2220-2242: live resource attachment is treated as an explicit session-scoped write grant candidate.
- Lines 2244-2261: `r4LiveAttachmentWriteGrantCandidates` filters live writable attachments into grant candidates.
- Lines 4082-4162: attached note/chat context is resolved into the turn context.
- Lines 4459-4533: attached note bodies are inlined as required context.
- Lines 4536-4548: live writable attached notes include a path hint for `vault.write.path` only when the user asks for an edit.

### `Epistemos/Sync/NoteFileStorage.swift`

- Lines 1102-1116: `writeBody` stages and persists a note body with integrity hashing.
- Lines 1118-1126: `writeBodyAsync` preserves global file mutation order.
- Lines 1144-1155: `scheduleWriteBody` stages content for immediate reads and persists in the background.
- Lines 1158-1168: `flushPendingBodyToDisk` drains staged in-memory content.

### `agent_core/src/tools/note_tools.rs`

- Lines 202-232: `NoteEditTool` replaces the markdown body of a vault note by path/id.
- Lines 235-250: `edit_note` schema is whole-note replacement, not block-scoped, and has no capability-token parameter.

## Code Impact Estimate

### Option A - V1.1 block-scoped EditPage macaroon

Estimated implementation: 1,500-3,500 LOC across Rust runtime, Swift editor bridge, and tests.

Likely Rust work:

- Add a typed EditPage capability shape or strict `AdditionalContext` keys for `page_id`, `block_id`, and previous block hash.
- Add B2-H20-style one-shot consume support or a feature-local consume ledger.
- Add `edit_note_block` tool under `agent_core/src/tools/`.
- Verify `ToolNameEq`, page scope, block scope, expiry, one-shot consumption, and expected previous block hash before mutation.
- Emit Effect/Inverse, ExecutionReceipt, Claim/ledger row, and UndoLog entry on success.
- Return typed errors for expired token, already consumed token, page deleted, block mismatch, stale previous hash, and concurrent edit conflict.

Likely Swift work:

- Mint/request capability from the attached-note chat surface after user signoff.
- Drain `EpdocEditorSavePipeline` before applying an agent edit to an open page.
- Forward block replacement through the existing Tiptap bridge when the page is open; otherwise persist through canonical storage.
- Render provenance/Undo affordance in chat transcript or GenUI surface.

Tests:

- Macaroon unit tests for page/block/tool/expiry/one-shot composition.
- Tool tests against an in-memory note store with stale-block and consumed-token failures.
- Swift tests for live/snapshot attachment behavior and writable-path prompt behavior.
- Editor bridge test for open-page forwarding and closed-page storage fallback.
- MAS E2E test for one edit under sandbox constraints.

### Option B - Full V1 `edit_note_block` now

Estimated implementation: same 1,500-3,500 LOC, but with higher release risk because it must land before V1 closure.

Additional risk work:

- Product copy, approval UX, and reviewer-safe explanation.
- Manual QA for accidental whole-note rewrites.
- Fallback behavior if Undo UI is not ready.

### Option C - Existing attachments/write grants only

Estimated implementation: 0-300 LOC, mostly documentation/status updates.

Potential cleanup:

- Clarify that current live writable attachments are a path/whole-note write affordance, not the H-3 block-scoped tool.
- Decide whether `note.attach_readonly` remains a Hermes doctrine label or becomes a real tool alias.

### Option D - Pro-only full mutation

Estimated implementation: same feature work as Option A, plus tier gates and MAS symbol/feature tests.

Likely extra work:

- Pro-only feature gate.
- MAS build proof that `edit_note_block` is absent or inert.
- Separate Pro UX copy and documentation.

## Recommendation

Recommend **Option A: V1.1 block-scoped EditPage macaroon with one-shot semantics**.

Recommended decision record:

> MAS V1 keeps the current attached-note context and live/snapshot resource substrate, but does not claim the H-3/B2-H6 `edit_note_block` feature. V1.1 ships a dedicated `edit_note_block(page_id, block_id, new_markdown, capability_token)` tool gated by a page+block-scoped, short-lived, single-use macaroon. Successful edits must emit Effect/Inverse, ExecutionReceipt, provenance/Claim ledger, and UndoLog rows. The token expires by short wall-clock TTL and is consumed by event-bound one-shot semantics. Existing path/whole-note `vault.write` and `note.edit` remain lower-level tools, not the EditPage contract.

Reasoning:

- The design doc is explicit that no code should land until user signoff.
- Current code already supports useful attachment/write-grant flows, so V1 does not need a rushed new mutation feature to preserve the attach-note user story.
- Whole-note path writes are too broad to stand in for a block-scoped agent edit feature.
- Hermes already forward-stages the missing `OneShot` primitive, and B-3 already has the Undo substrate H-3 needs.
- Page+block+previous-hash scoping is a better safety contract than path-only scope because pages can move and blocks can change under concurrent human edits.

## Acceptance Criteria

If the user chooses **Option A**:

- `edit_note_block` remains out of the MAS V1 tool surface.
- Existing live/snapshot attachments continue to work as current code describes.
- The V1.1 tool requires `page_id`, `block_id`, `new_markdown`, `capability_token`, and an expected previous block hash or equivalent stale-edit guard.
- Capability verification requires tool name, page scope, block scope, expiry, and one-shot consumption.
- Every successful edit writes through the canonical note storage/editor pipeline.
- Every successful edit emits Effect/Inverse, ExecutionReceipt, provenance/Claim ledger, and UndoLog rows.
- UI exposes Undo only for reversible edits and records attempted-but-abandoned edits when a page is deleted or token check fails after planning.
- Concurrent human edits are handled by draining the save pipeline and rejecting stale block hashes.
- Tests cover token reuse, expired token, wrong page, wrong block, stale hash, page deleted, closed-page fallback, and MAS sandbox E2E.

If the user chooses **Option B**:

- All Option A acceptance criteria land before MAS V1 closure.
- User signoff on the design doc is recorded before implementation begins.
- Product/reviewer copy clearly explains why the agent can edit attached notes and how the user stops or undoes it.

If the user chooses **Option C**:

- MAS docs stop implying that `edit_note_block` exists or is "mostly done."
- The existing path/whole-note write behavior is documented as a separate, broader tool path.
- H-3/B2-H6 is marked closed only if the user explicitly accepts no block-scoped edit capability.

If the user chooses **Option D**:

- MAS build tests prove the full mutation surface is absent from MAS.
- Pro build gates the feature behind explicit user approval and one-shot capability verification.
- The Pro implementation still uses the same one-shot, provenance, and Undo criteria as Option A.

## Decision-Ready Prompt

**H-3 / B2-H6 EditPage macaroon decision:** What should Epistemos do with capability-gated attached-note editing?

1. **V1.1 block-scoped EditPage macaroon** - MAS V1 keeps current attachments; V1.1 ships `edit_note_block` with page+block scope, short TTL, one-shot consumption, provenance, and Undo. **Recommended.**
2. **Full V1 implementation now** - build and ship `edit_note_block` before MAS V1 closure after explicit user signoff.
3. **Existing attachments/write grants only** - treat current live attachments plus path/whole-note write tools as enough; do not build `edit_note_block`.
4. **Pro-only mutation** - MAS keeps attach/read context; Pro gets the full block-scoped mutation feature later.

Answer with one option label and any constraints, for example: "Option 1, but require previous block hash and Undo button in the first V1.1 PR."
