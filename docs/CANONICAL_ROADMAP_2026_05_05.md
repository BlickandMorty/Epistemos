---
state: canon
canon_promoted_on: 2026-05-05
supersedes: nothing (new canonical synthesis doc)
---

# Canonical Roadmap — 2026-05-05

> **Synthesis of three sources:** Codex's 2026-05-05 advice (10-point
> canon-hardening list), the canonical-upgrade-audit research agent's
> 17-item structured findings, and the work shipped this session.
>
> **Purpose:** name what's now canon, what's the next canonical move,
> and what's the long-tail. Apply the WRV + canon-promotion + no-date-
> gate protocols from `CANON_HARDENING_PROTOCOL_2026_05_05.md` to every
> entry.

## Section 1 — What is now canon (state: canon, verified: in flight)

| Item | Status (per WRV) | Commit | Notes |
|---|---|---|---|
| CD-005 capability-bound `put_edge` | wired + verified by tests; not Codex-verified yet | `9835b439` | The V2.1 8.H authority blocker per Codex's drift audit; closed at storage boundary |
| Canon hardening protocol (WRV + canon promotion + no-date-gates) | canon (this session) | `72b9fe0a` | Live doctrine; every future PR honors it |
| `epistemos-doctrine-lint` in CI | wired | `e523405e` | Doctrine §5.1-§5.4 gates enforced on every push/PR |
| Pro-build CI matrix | wired | `e523405e` | MAS-First §3.1 "CI must run BOTH" closed |
| `lsp-runtime` feature in CI | wired | `e523405e` | Codex's local verification now matched in CI |
| Dispatch tracing migration (eprintln → tracing) | wired + visible | `e523405e` | Structured observability for doctrine §10 verification window |
| AgentQueryEngine MainActor.run warning | fixed | `72b9fe0a` | Codex's flagged build warning eliminated |

## Section 2 — Highest-leverage NEXT canonical moves

These are the items where doing them gives the biggest canonical
return per unit effort. Ranked by `(canonical_priority / effort)`.

### #1 — B2: `epistemos-trace verify-replay` in CI

- **What.** The Phase 8.F `verify-replay` CLI subcommand exists with 5
  typed exit codes but no CI step calls it. Doctrine §10 verification
  gate; without a release-time gate the "verifiable replay" capability
  has no enforced contract.
- **Effort.** 2-3 hours. Build a sample `.epbundle` fixture in
  `agent_core/tests/fixtures/` and run `verify-replay` on it as a CI
  step.
- **Gate type.** Verification.

### #2 — Merge CANON_GAPS_AND_ADDENDA staged blocks

- **What.** Codex's #1 recommendation. 11 MERGE TARGET blocks across 5
  doctrine files (`EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` ×4 + others).
  Each block has been staged + reviewed; the merge is mechanical but
  needs its own canon brief because it touches every doctrine file.
- **Effort.** 1-2 days (careful merge + verify each section anchor
  survives + run doctrine linter).
- **Gate type.** Doctrine.

### #3 — A2: Real macaroon-bound capability binding for dispatch

- **What.** CD-005 closed the storage boundary; A2 is the next layer:
  wire macaroon issuance through SovereignGate session start, thread
  the live macaroon hash into each `on_*_committed` dispatch path,
  rewrite `cognitive_dag_store()` initializer to register caps as they
  arrive instead of pre-registering the sentinel.
- **Effort.** 2-3 weeks.
- **Gate type.** Capability.
- **Blocks.** V2.1 8.H authority flip (alongside A1 + A3).

### #4 — A3: Auto-invoke dispatch coverage gaps (CD-006)

- **What.** Wire missing dispatches: companion registration,
  self-evolution events, replay commit/import, skill mutation events.
- **Effort.** 1 week per site (4 weeks total).
- **Gate type.** Doctrine §10 ("mirrors writing on EVERY legacy
  write").
- **Blocks.** V2.1 8.H authority flip.

### #5 — A1: Persistent DAG storage backend (`redb`)

- **What.** Today's DAG is in-memory only; doctrine §1.3 names `redb`
  as the recommended backend. Without persistence the §10 acceptance
  bar resets every restart.
- **Effort.** 4-6 days.
- **Gate type.** Doctrine + verification.
- **Blocks.** V2.1 8.H authority flip.

### #6 — B5/source-guard: MAS/Pro source-guard sweep (Codex #6)

- **What.** Codex's #6: full source guard over every `Command::new`,
  `Process`, `Pipe` site to confirm no Pro-only surface bleeds into
  the MAS build path. Largely aligned per existing
  `MAS_RUNTIME_FORBIDDEN_TOOLS` discipline; needs a doctrine-linter
  gate addition that codifies the check.
- **Effort.** 1-2 days.
- **Gate type.** Distribution + entitlement.

### #7 — XPC trust spine (Codex #5/#9)

- **What.** Wire `NSXPCConnection.setCodeSigningRequirement(_:)` per
  Apple docs into every XPC service connection (AgentXPC,
  ProviderXPC, future VaultXPC, future WASMExecXPC). App validates
  service, service validates app, no PID trust. Reciprocal
  code-signing requirements + per-service entitlements + no temp
  exceptions unless justified.
- **Effort.** 1-2 weeks (design + Swift implementation + tests; gated
  on $99/yr Apple Developer Program for production deployment).
- **Gate type.** Distribution + entitlement.

## Section 3 — V2.1 8.H authority flip — the canonical blockers

Per Codex's CD-004 + my agent's audit: V2.1 Phase 8.H (DAG becomes
authoritative; legacy stores become read-only fallback) cannot ship
until ALL of these clear:

- [ ] **A1** persistent backend (`redb`) — without this, "two weeks
      of CI green" resets every restart
- [x] **A2 storage layer** capability-bound `put_edge` (CD-005, this
      session) — the structural gate is done; macaroon binding is the
      remaining layer (#3 above)
- [ ] **A2 dispatch layer** macaroon-derived caps (vs sentinel) — see
      #3 above
- [ ] **A3** auto-invoke dispatch coverage — see #4 above
- [ ] **CD-004** Phase 1-7 kernel doctrine prerequisites verified by
      Codex
- [ ] **§10 two-week CI green window** with all of the above
      operating in production

After all clear: §10 authority flip becomes a single release decision.

## Section 4 — Long-tail (canon-candidate, not blocking)

These are upgrades the audit identified but that aren't on any
critical path. Promote from `candidate → canon` as bandwidth allows.

| ID | Item | Effort | Notes |
|---|---|---|---|
| A4 | WASM exec runtime (kernel doctrine §5) | 3-4 weeks | The big MAS unlock for code execution |
| A5 | In-process bundled MCP (kernel doctrine §6) | 2-3 weeks | MAS distribution dispatcher refactor |
| A6 | Hermes-in-Rust kernel doc reconciliation | 1 day | Doctrine names `agent_core::hermes`; reality is `agent_core::agent_runtime`. Document the mapping or rename. |
| A7 | Five-XPC-service decomposition skeletons | 3-5 weeks | Vault + WASMExec services beyond current Agent + Provider |
| C2 | `provenance_ledger()` Mutex → RwLock | 1-2 hours | Read-heavy paths benefit |
| C3-C5 | Misc hardening polish (clippy denials, error-type tightening, TODO cleanup) | 1-3 days | Background work |
| D1-D2 | Test coverage gaps in canonical surfaces | varies | Identified by audit; not on critical path |
| E1 | Cross-language consistency check | 1 day | Already healthy per audit |
| F1 | `ci.yml` matrix expansion (multi-arch, multi-OS) | 1 day | Belt-and-suspenders |
| F3-F4 | Build-script canonical surface verification | 1 day | Polish |
| G1 | `docs/AGENT_PROGRESS.md` refresh | 30 min | 7-day stale per audit |
| G2 | CLAUDE.md FILE MAP additions | 30 min | Missing entries for `cognitive_dag/`, `provenance/`, `lsp_runtime/`, `agent_runtime/`, two new bin tools |

## Section 5 — Externally-gated work (not autonomous)

Per the no-date-gates protocol: these are gated by capability,
distribution, entitlement, or licensing — not by calendar.

| Item | Gate type | Specific gate |
|---|---|---|
| V2.4 production XPC service launch | Distribution | Apple Developer Program enrollment |
| V3.2 production ANE direct path | Distribution + entitlement | Developer Program + private framework loading entitlement |
| V2.6 brand asset re-import | Licensing | NousResearch licensing decision |
| V2.5 sim worktree merge | Doctrine | Strategic call: cherry-pick (donor-mine pattern per Codex #8) |
| Codex full-app sign-off | Verification | Codex independently runs the full xcodebuild test suite |

## Section 6 — Canon-hardening invariants (live)

Per `CANON_HARDENING_PROTOCOL_2026_05_05.md`:

1. Every claim uses one of the six WRV states; "shipped" requires
   `verified` at minimum.
2. Every doc declares its `state:` in frontmatter (`canon`,
   `candidate`, `research`, `superseded`, `historical`, `rejected`).
3. Every blocker is one of six gate types (capability, verification,
   distribution, entitlement, licensing, doctrine).
4. CI enforces the doctrine §5 gates via `epistemos-doctrine-lint`
   (live as of `e523405e`).
5. CI enforces both MAS + Pro feature surfaces (live as of
   `e523405e`).
6. CI enforces the LSP runtime feature surface (live as of
   `e523405e`).

## Section 7 — Session ledger (this session, on top of V2 close-out)

| # | Commit | What |
|---|---|---|
| (V2 close-out commits already in `SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` ledger) | | |
| 35 | `9835b439` | CD-005: capability-bound `put_edge` |
| 36 | `72b9fe0a` | Canon hardening protocol + audit + AgentQueryEngine warning fix |
| 37 | `e523405e` | Canon B1+B3+B4+C1: CI gate enforcement + dispatch tracing |
| 38 | (this commit) | Canonical roadmap synthesis |

Total session = 38+ commits since the last Codex commit (`7a063f4a`).

## Section 8 — Acceptance for this roadmap

This roadmap is `state: canon` as of its merge. Future audits compare
shipped work against Section 1 (current canon) + Section 2 (next
moves) + Section 5 (gated). Anything outside those buckets either
needs a roadmap update or doesn't exist.

The canon-hardening protocols (Section 6) apply prospectively to
every commit. The doctrine linter is the mechanical enforcer; the
roadmap is the strategic enforcer.
