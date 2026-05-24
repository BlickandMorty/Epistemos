# Decision Resolved — ACS Anchor Addressing Scope

**Decision:** **Option 2 — Re-scope Terminal E** (chosen 2026-05-24)
**Resolver:** user via Claude session
**Reason:** Terminal G already produced the typed anchor substrate at `agent_core/src/uas/{acs_anchor.rs, anchor_registry.rs}` and measured `F-ACS-AnchorLookup` on M2 Pro. Forcing Terminal E to also build the `agent_core/src/research/acs/anchor.rs` + harness would either (a) duplicate substrate or (b) break the canonical lane separation (research/acs/ = Lane 3 research, never MAS · acs_admission/ = product lane).

## What Terminal E claims (locked)

- W-46: **Rust-wired** — `ACSRunEventLogSink::admit_and_record` fans verdicts into OpLog
- W-47: **partial-wired** — `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` carried on v2 tool handoffs; forged-signature rejection covered
- W-25: **partial** — Provenance Console renders inline ACS verdict field; full clickable AcsAnchor sorting blocked on row-level ACS anchor IDs (future work)
- W-52: **wired-source-guarded** — `CSISafeguard` is called before distillation persistence; low-CSI short-circuit test added

## What Terminal E does NOT claim (locked)

- **F-ACS-Anchor-Addressing canonical PASS** — that falsifier requires `agent_core/src/research/acs/{anchor,anchor_registry}.rs` + `agent_core/tests/acs_anchor_addressing.rs` (1,000-anchor four-stage round-trip), all of which belong to T3/research-tier and remain out of scope for Terminal E's product-lane work.

## What gets deferred (Future research-tier follow-up)

A new deferred item is created:

- **D-27 · F-ACS-Anchor-Addressing canonical harness** — the typed-anchor four-stage round-trip in `agent_core/src/research/acs/` + tests. Re-promotion codeword: **`RESUME ACS ANCHOR HARNESS`**. Builds on Terminal G's `agent_core/src/uas/anchor_registry.rs` foundation. Currently research-tier; promotes to Tier-1 product-lane after the typed-anchor round-trip PASSes on M2 Pro.

## Adjacent victory already in main

- Terminal G's PR (pending open) lands `F-ACS-AnchorLookup` measured PASS (anchor lookup `< 1 μs avg over 10k claims`). This is the product-relevant anchor-performance measurement and lives in the product lane (`agent_core/src/uas/`). The canonical F-ACS-Anchor-Addressing four-stage harness remains deferred per D-27 above.
