# Local Engineering Agent — Design Sketch (P9)

**Status:** Design-only. No code, no open ports, no infrastructure churn.
**Date:** 2026-05-10
**Context:** RCA13 P9 — the user wants a structured plan for a future
"local engineering agent" that can read the vault and live-edit
attached notes, paired with a clear non-goal: no inbound network
listener, no daemonized port-holder, no MAS-incompatible surface.

## Goals

1. Let the user attach a note (or set of notes) to a chat turn and
   have the local agent edit it in place, with the same provenance
   guarantees the rest of agent_core enforces (DAG capability tokens,
   ledger Claim records, GenUI dispatcher rendering).
2. Stay entirely in-process. The agent loop is the existing
   `agent_core::agent_runtime` already running on the Rust side —
   nothing new to spawn, nothing new to listen on.
3. MAS-shippable from day one: works inside the App Sandbox without
   any of the entitlements that would bounce review (no
   `com.apple.security.network.server`, no `com.apple.security.cs.allow-jit`,
   no temporary-exception entitlements).

## Non-Goals (explicit, per handoff preservation rules)

- **No open ports.** The agent does not listen on `127.0.0.1:any` or
  any other socket. Inbound requests are not a feature.
- **No subprocess.** Existing legacy-subprocess removal (Hermes purge
  2026-05-05) stays in force. The agent is in-process Rust, called
  through UniFFI.
- **No AnswerPacket or EpiKernel architecture work.** Those are
  future-tier items per the V6.1 lock; do not let this design pull
  them forward.
- **No new themes, no graph-visual changes, no camera changes.**
  Pure agent + editing surface.

## Surface

| Layer | Lives in | Responsibility |
|---|---|---|
| Attach affordance | `Epistemos/Views/Notes/*` (existing chat composer) | User clicks a paperclip on a chat turn → picks one or more pages → page IDs land in `AttachmentPayload` on the turn |
| Capability minting | `agent_core/src/cognitive_dag/macaroons.rs` | When the agent starts on an attached page, mint a single-use `EditPage(page_id, expires_at)` macaroon. Cap is consumed on first successful write, then the agent must request a fresh one for any subsequent edit in the same turn |
| Tool surface | `agent_core/src/tools/` | New tool `edit_note_block(page_id, block_id, new_markdown, capability_token)`. Uses the existing canonical NoteFileStorage write path, NOT a new I/O path |
| Live-edit dispatch | `Epistemos/Engine/EpdocEditorChromeView.swift` (existing JS bridge) | Forward the new block contents into the running Tiptap editor if the page is open in a window — same path Halo uses today for inline-edit |
| Provenance | `agent_core/src/provenance/ledger.rs` | Every successful edit emits a `Claim::NoteEdited` with the page_id + previous block hash + new block hash. Retraction propagates per existing rules |

## Failure modes the design has to handle

1. **User closes the note while the agent is editing.** The
   capability token survives the window close; the edit lands in the
   NoteFileStorage path, the WKWebView bridge just no-ops (no live
   page to forward to).
2. **Page is moved or deleted between attach and edit.** The
   capability is keyed on the durable `page_id`, not the path —
   stays valid across moves. Delete: tool returns
   `ToolError::PageDeleted`, ledger records the abandoned edit
   attempt.
3. **Multiple edits per turn.** Each `edit_note_block` call demands
   a fresh capability. The agent's loop has to call a sibling tool
   `mint_edit_capability(page_id)` between blocks. This is verbose
   on purpose: the user sees every edit in the ledger and can stop
   the loop after one if they want.
4. **Concurrent human edit.** The Tiptap autosave pipeline runs at
   300 ms cadence; agent edits collide if the user is typing. First
   slice: agent edits queue behind any unflushed user keystrokes
   (the P3 `flushAllForShutdown` hook gives us the drain primitive
   already). A more sophisticated CRDT path is explicitly future
   work.

## Why this stays MAS-compatible

- All inference + orchestration happens in `agent_core::agent_runtime`,
  the in-process Rust loop that already ships in the MAS build.
- File writes go through the existing NoteFileStorage path, which
  the sandbox already grants via the user-selected vault scope.
- The capability token machinery is pure in-process data — no
  process-to-process IPC, no XPC service, no LaunchAgent. The
  Quick Capture / W8.7 indexer pattern is the model.
- The GenUI dispatcher renders the agent's edit results inline in
  the chat surface, so there's no new view-controller registration
  that would need an entitlement.

## What this design does NOT promise

- Live multi-user collaboration. Single-user, single-machine only.
- Edit-distance limits on a per-turn basis. The agent can in
  principle rewrite an entire page; UX safeguards are a separate
  slice.
- Rollback UI. The provenance ledger has the data; a future slice
  surfaces it. For now, "undo" is the existing Cmd-Z stack in the
  editor.

## Sequenced slices (when work picks up)

1. Capability token type + ledger integration (Rust-only, no UI)
2. `edit_note_block` tool + tests against an in-memory NoteFileStorage stub
3. Chat composer attach affordance (Swift-only, attaches page_ids to turn)
4. Wire the agent's tool call through to the Tiptap bridge for live forward
5. Provenance ledger surface in the GenUI dispatcher
6. MAS-build E2E test that exercises one end-to-end edit and checks
   the sandbox didn't trip

Each slice ships independently; the user can stop after slice 2 if
they want the agent-side work without the UI affordance, and the
existing chat path keeps working unchanged.

## Open questions (for the next session, not for now)

- Does the user want the agent to be able to create new pages, or
  only edit existing ones? (Defaulting to "edit only" until asked.)
- Should the capability token expire on a wall-clock or on a
  ledger-event count? Likely event count to avoid time-drift bugs.
- How does this interact with the planned ACS / multi-agent work?
  Probably as the canonical "single-machine editor agent" the ACS
  Companion can delegate to — but ACS is not on the critical path
  per the post-recovery V2 plan.

---

Filed for the user as design context. No code lands until they
explicitly say "now build P9 slice 1."
