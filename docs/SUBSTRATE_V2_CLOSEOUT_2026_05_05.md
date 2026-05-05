# Substrate V2 close-out — 2026-05-05

End-of-stretch status for the V2 sequence (V2.1-V2.7) before opening
V3 (research tier). Honest accounting of what shipped, what's gated,
and what V3.3 (paper drafts) starts on next.

## V2 status matrix

| Lane | Scope | Status | Gating |
|---|---|---|---|
| V2.1 | Cognitive DAG Phase 8 | 8.A-8.G ✓ | 8.H gated on doctrine §10 two-week CI green (release decision) |
| V2.2 | Halo V1 | ✓ (with ledger ribbon, this stretch) | none |
| V2.3 | LSP migration | First slice ✓ (protocol seam shipped today) | Slice 2 (tower-lsp + tree-sitter Rust) needs ~1-2 days; slice 3 (delete subprocess) follows |
| V2.4 | XPC Mastery (5 services) | NOT STARTED | **Paid Apple Developer Program required.** User confirmed no team yet. |
| V2.5 | Simulation v1.7+ | Sim Mode S0-S11 sits in `worktree-simulation` (17 commits) | Merge needs S9 conflict resolution (S9 references Hermes graph faculty deleted in slice 1 of Hermes removal) |
| V2.6 | UX advanced + brand identity | NOT STARTED | NousResearch licensing gate; brand tokens already removed in Hermes teardown |
| V2.7 | Multi-Agent ACS tooling | Ongoing/substantial | none, but multi-day each |

**Strict acceptance bar from the post-recovery plan:** "V2.1-V2.7
complete; tests green; two-week CI stable." That bar is not met
because V2.4 is hard-gated on paid team and V2.5/V2.6 have outside
dependencies. The user's direction is to continue with what's
autonomous; V3 work begins from here while V2.4-V2.7 remain
in-flight.

## What shipped during the V2 stretch (2026-05-05 session)

15 commits total this session (from `b34164e5` onward):

**V2.1 follow-on (Phase 8 completion):**
- `b34164e5` Phase A — Resonance FFI swap
- `d606afc0` Lane 1 — Provenance ledger Rust→Swift bridge
- `fb3d4fe3` Lane 2a+2b — Procedural + Provenance DagMirrors
- `b439db25` Lane 2c — Companion DagMirror (4/4)
- `49d4efaf` Cognitive DAG observability surface
- `d327e87f` Phase 8.E auto-invoke dispatch
- `28af9b71` Phase 8.F — ReplayBundle DAG snapshot + verify-replay CLI
- `261e7cca` Phase 8.G — epistemos-doctrine-lint binary

**V2.2 follow-on:**
- `6f609d8c` Halo panel ClaimLedger ribbon

**V2.3 first slice:**
- `d06fefca` LSPTransport protocol seam

**Documentation:**
- `e50ee926` V2 wire-up status doc
- `939d7947` V2 wire-up complete doc
- `546ee564` Hermes-removal handoff R1-R4 record
- (this commit) Substrate V2 close-out doc

## Verification (final state)

- **Rust:** 1041/1041 agent_core tests pass
- **Swift focused:** 42/42 LSP-area + 68/68 V2-wire + 121/121 Hermes-area + 105/105 cloud-routing tests pass
- **Build:** xcodebuild SUCCEEDED
- **Both binaries ship:** `epistemos_trace` (verify + verify-replay), `epistemos_doctrine_lint` (4 doctrine §5 gates)

## V3 entry — autonomous starting point

Per the post-recovery plan, V3 has three lanes:

| Lane | Scope | Autonomous? |
|---|---|---|
| V3.1 | Ternary substrate (Sherry 1.25-bit, KV-Direct, WBO-6) — Track T14 | **NO.** Week-0 KV-Direct experiment requires Metal/MLX hands-on benchmarking on the user's hardware (D_KL=0 + token_match=100% + RAM≥8× lower). Needs the user. |
| V3.2 | ANE Direct Path / KV Implantation — Track T15 | **NO.** Research only; Developer ID + private framework loading; explicitly NOT in the MAS path. Paid-team-gated like V2.4. |
| V3.3 | V2/V3 paper drafts → MLSys / NeurIPS systems track | **YES.** Writing task. The cognitive DAG doctrine §6 explicitly says "Verifiable replay is publishable systems work." V3.3 captures what's been built in a publishable form. |

**Therefore V3 starts with V3.3 — paper draft.** First slice ships
the paper outline + abstract + one full systems-contribution section
covering V2.1's Cognitive DAG Phase 8 (the most novel + complete
shipped substrate). Subsequent slices add the methodology + evaluation
sections as the V3.1 experiments produce data.

The paper-draft starting point is `docs/V3_3_PAPER_DRAFT_2026_05_05.md`.
