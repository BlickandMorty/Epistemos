---
name: experimental-run-provenance
description: >
  Make the embedded agent's run AUDITABLE — capture its tool-call/action sequence from the
  transcript into a tamper-evident, hash-chained record and persist it to the Epistemos
  substrate (vault provenance note, or the agent_core RunEventLog/ReplayBundle when the FFI
  lands). Use for run.export-bundle, a provenance/observability console, or any "prove what the
  agent DID" feature. The trust axis, from the OTHER side: substrate-verification (Cycle 5)
  checks the agent's CLAIMS; this records the agent's ACTIONS. Class: transcript parts →
  ordered events → SHA-256 hash chain → persist to substrate. Composes experimental-provenance-writeback.
---

# Experimental: run provenance capture (web-side RunEventLog)

## Why (the moat)
Every standalone agent runs opaque — you can't prove what it did. Epistemos can: capture the
tool-call sequence, hash-chain it (tamper/reorder-evident), and write it back to the user's KB.
No standalone app persists an auditable run to a personal knowledge base.

## The pattern
1. **Extract events (pure fn over `message.parts`).** Tool parts have `type: "tool-<Kind>"`,
   `toolCallId`, `input`. ACP dynamic tools carry the real name in `input.toolName` (resolve it).
   Skip non-actions (`tool-Thinking`). Summarize the target from `input.file_path/command/query/…`.
   Keep it deterministic + unit-testable.
2. **Hash-chain for integrity.** `prev = SHA-256(prev + "|" + ordinal + "|" + kind + "|" + target)`
   via `crypto.subtle` (available in renderer AND Node ≥20 for headless tests). Root = last hash.
   Property to test: reorder → different root; same input → same root.
3. **Persist to substrate.** Format a markdown provenance note (steps + root hash) and write it
   via the Cycle-1 `epistemos` `vault:create-note` channel. When the agent_core RunEventLog /
   ReplayBundle FFI lands (`provenance/replay.rs`, `bin/epistemos_trace`), swap the SHA chain for
   BLAKE3 + export a verifiable `.epbundle` — same shape, stronger guarantee.

## Reuse targets (later cycles compose THIS)
- `run.export-bundle`: the same events → a ReplayBundle `.epbundle` checkable by `epistemos-trace`.
- Whole-run (not per-turn): the extractor takes a message ARRAY, so read the sub-chat's full
  message list IMPERATIVELY from the global jotai store in the click handler (not hooks):
  `appStore.get(messageIdsPerChatAtom(subChatId))` → map each id via
  `appStore.get(messageAtomFamily(getPerChatMessageKey(subChatId, id)))`. Fall back to the single
  message if the store isn't reachable. This is how a per-message button audits the entire session.
- Provenance/observability console: render the events + running hash + costs in a web panel
  (whole-run: pass all messages, not just one — the extractor already takes an array).
- Combine with `experimental-substrate-verification`: a run record whose citations are cite-checked.

## Verification (DoD)
Pure logic → verify HEADLESS (Node has crypto.subtle): assert event count/order, ACP-name
resolution, Thinking-skip, and the two hash-chain properties (tamper-evident + deterministic) —
no app build needed. Then live: on a turn with tool calls, click Provenance → a note lands in
`<vault>/notes/` with the ordered steps + root hash. Button shows only on turns WITH tool calls
+ native host. Every fork edit → a `PATCH_LEDGER.md` row.

## Proven (Cycle 8)
`ProvenanceButton` on assistant turns: extract tool-calls → SHA-256 chain → vault note. Headless
test: 3 events (Thinking skipped, ACP `vault.search_notes` resolved), reorder→different root,
deterministic root.
