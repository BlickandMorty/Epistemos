# Codex Verification Handoff — 2026-05-05

**Author:** Claude (Opus 4.7) session, 2026-05-05.
**Audience:** Codex, acting as the final overseer of work that has
not yet been independently verified.

---

## Reading orientation

You are the canonical verification overseer for this codebase.
**Per the user's explicit direction**, every commit since your last
session (commit `7a063f4a` *"Codex continuation residuals: test
alignments + AppBootstrap wiring + doc updates"*) is to be treated
as **UNVERIFIED** until you independently sign off.

The user's exact words for this handoff:

> "i truly want codex to like before act as if work has not been
> doe becasue it hasnt been verified by ut. it is the final
> overseer of all work particualr the work it has not checked or
> work it has not signed off on. so this should also have it
> disclose what is truly still blocked and being honest so i make
> sure its til canon and not losing nuacn e from the plan."

In plain terms:
1. Treat the last 32 commits as not-yet-shipped until you verify.
2. Read the commits cold; the prose in this doc is *my* framing,
   not yours.
3. Disclose what is *truly* still blocked — be honest about gates
   that I may have undersold or oversold.
4. Catch any nuance loss from the canonical plans
   (`docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`,
   `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`,
   `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`).

This doc is a **map**, not a verification. Your verification IS
the truth.

---

## The session boundary

- **Last Codex commit:** `7a063f4a` (2026-05-04)
- **First Claude commit this stretch:** `d9be24b5` (2026-05-05)
- **Commits in scope for your audit:** 32 (full list at the end)
- **Branch:** `feature/landing-liquid-wave`
- **Net diff vs the last Codex commit:** ~+5,000 / −1,500 LOC (rough)

Run this to see the exact set:

```bash
git log 7a064a3a..HEAD --oneline    # the last Codex commit's parent
# or equivalently:
git log d9be24b5^..HEAD --oneline    # the start of my session
```

---

## What I claim shipped (claims to verify)

**Hermes removal aftermath (commits 1-10 in the session ledger):**
1. R1 — Remove dead `.hermesSubprocess` gateway surface enum case
   + decision branch + XPC fallback + 6 test files updated
2. R2 — Delete dead `hermesFacultyHostView` / `hermesFacultyConstraints`
   state from `HologramOverlay.swift`
3. R3 — Update Rust doc comments after Hermes removal
4. R1 fixup — 2 test expectations missed in the first sweep

**V2.1 Phase 8 completion (commits 11-21):**
5. Phase A — Resonance FFI swap (`compute_resonance_signature_core`)
6. Lane 1 — Provenance ledger Rust→Swift bridge (3 FFI exports +
   `RustProvenanceLedgerClient` + Provenance Console panel)
7. Phase 8.E continuation — `ProceduralMirror` + `ProvenanceLedgerMirror`
   + `CompanionMirror` (all 4 DagMirrors landed)
8. Halo panel ClaimLedger ribbon
9. Cognitive DAG observability surface in Settings
10. Phase 8.E auto-invoke dispatch wired into `ClaimLedger::commit_*`,
    `ProceduralMemoryStore::record_outcome`, `SkillRouter::load`
11. Phase 8.F — `ReplayBundle` extended with optional `dag_snapshot`
    + `verify_replay()` method + `epistemos-trace verify-replay <path>`
    CLI subcommand + new exit code 5 (DAG merkle parity mismatch)
12. Phase 8.G — `epistemos-doctrine-lint` binary (4 §5 gates) +
    storage layer doctrine alignment (added explicit content-address
    + signature checks at `put_node` / `put_edge` boundary)

**V2.3 LSP migration (commits 22, 29-32):**
13. First slice — `LSPTransport` Swift protocol seam, 6 tests
14. Stage A — Hand-rolled in-process Rust `LspKernel` module, 14 tests,
    NO new Cargo deps (gated behind `lsp-runtime` feature, off by
    default)
15. Stage B — 3 UniFFI exports (`lsp_send_message_json`,
    `lsp_poll_response_json`, `lsp_lifecycle_state_debug`) +
    `build-agent-core.sh` enables `lsp-runtime` for both MAS + Pro
    builds
16. Stage C+D — Swift `RustLSPTransport` actor + 5 end-to-end tests
17. Stage E — Delete `LSPServerProcess` + `LSPServerProcessTests` +
    backward-compat shims in LSPClient + empty extension conformance
    in LSPTransport. The literal V2.3 sentence "closes last
    subprocess in editor surface" is now true at the source level.

**V2.4 first slice (commit 26):**
18. `ProviderServiceStreamingProtocol` Swift protocol +
    `ProviderXPCStreamingRequest` / `ProviderXPCStreamingSession` /
    `LLMTokenChunk` Codable types + `MockProviderServiceStreaming`
    in-process mock + 9 tests. Phase 1 wire format only — Phase 2
    IOSurface streaming ring deferred.

**V3.2 first slice (commit 27):**
19. `ANEBackend` Swift protocol + `ANEModelHandle` opaque handle +
    `ANEBackendError` enum + `ANEKVCacheBuffer` typed format +
    `MockANEBackend` actor with deterministic LCG generation + 11 tests.

**V3.3 paper draft (commits 23, 28):**
20. ~520-line systems paper draft for cognitive DAG / verifiable
    replay. Sections 1-7 + 9 + 10 substantively complete. §8 evaluation
    + §A reproducibility URLs deferred to V3.1 data + publication time.

**CLI gap fix (commit 24):**
21. Gemini + Kimi CLI passthrough handlers in
    `agent_core/src/tools/cli_passthrough.rs` (parity with the
    existing `claude_code` + `codex` handlers).

**Documentation (commits 12, 18, 23, 25, 33):**
22. V2 wire-up status + closeout docs, V2.4/V3.2 design assessment,
    V2.3 LSP migration plan, this Codex handoff.

---

## What is TRULY still blocked (be honest)

**Hard external gates** (not autonomous):

| Item | Gate | Where this sits in the plan |
|---|---|---|
| V2.4 production XPC service launch | Apple Developer Program ($99/yr) | XPC Mastery doctrine §X.1-X.5 |
| V3.2 production ANE direct path runtime | Apple Developer Program + private framework loading entitlements | Post-recovery V2 plan §V3.2 |
| V2.6 brand asset re-import | NousResearch licensing | Hermes brand doctrine (now superseded) |
| V2.1 Phase 8.H authority flip | Doctrine §10 two-week CI green | Cognitive DAG doctrine §10 |

**Strategic decision pending** (not gated externally, but
non-trivial):

| Item | Decision needed |
|---|---|
| V2.5 simulation worktree merge | `worktree-simulation` is a 6,678-file architectural divergence. Three options: (a) cherry-pick specific Sim Mode features onto current branch; (b) rebase the sim work atop current; (c) switch active branch to worktree-simulation and re-port V2/V3 work. Each is multi-day. |
| V2.3 Stage F | tower-lsp + tree-sitter Rust crates for hover/definition — adds tree-sitter native compile to every build. ~2-3 days, real dep weight. |

**Things I may have undersold** (please verify):

- The auto-invoke dispatch (commit `d327e87f`) wired three call
  sites: `commit_evidence`, `commit_claim`, `record_outcome`,
  `SkillRouter::load`. Verify there are NO other legacy write paths
  that should also fire mirror dispatches but don't (e.g. companion
  registration, evolution events, etc.).
- The doctrine linter (commit `261e7cca`) covers §5.1-§5.4 only. §5.5
  (Merkle reproducibility) and §5.6 (Replay verification round-trip)
  are existing test invocations the doctrine assumes are run in CI;
  verify those tests actually run + pass in your environment.
- Storage doctrine alignment (commit `261e7cca`) added
  `Node::compute_id(&node.kind) == node.id` check in `put_node`. This
  rejects manually-constructed Nodes with bad ids. Verify NO test
  fixture outside `cognitive_dag/` constructs a Node directly with
  a manual id field — they should all use `Node::new` / `Node::new_at`.
- The InProcessLSPTransport stub returns MethodNotFound for every
  request. The LSPClient `notInitializedGuards` test was migrated
  to use this stub instead of the deleted LSPServerProcess. Verify
  the test still asserts the right semantic (server doesn't speak
  LSP → all RPC methods surface .notInitialized).

**Things I may have oversold**:

- The V3.3 paper draft is a *draft*, not publication-ready. Several
  sections (§4, §5, §6) lean heavily on close-to-the-code
  description that would need rewriting for academic register.
  Don't sign off on "publishable" — sign off on "complete first
  draft suitable for an internal review pass."
- The V2.4 ProviderServiceStreaming "wire format is stable" claim
  rests on the fact that I designed it; it has not been validated
  against an actual Anthropic / OpenAI / Google streaming response
  shape end-to-end. Phase 2 needs to confirm the LLMTokenChunk
  fields + metadataJson schema are sufficient.
- The "Halo ribbon shows Rust ledger counts" claim assumes the
  poll cadence + the Rust ledger actually accumulating data in
  production. Verify that under real agent traffic the counts
  visibly update.

---

## Acceptance bar for your verification

For each commit (or coherent group of commits), confirm or reject:

1. **Build green** — `xcodebuild -scheme Epistemos build` SUCCEEDED?
2. **Tests green** — the focused test suite the commit message
   claims passes, actually passes? Run them, don't trust the claim.
3. **Doctrine alignment** — does the commit honor the canonical
   doctrines (cognitive DAG §5 verification gates, MAS-first focus
   §3.1, post-recovery V2 plan sequencing)?
4. **No silent regressions** — does the commit accidentally remove
   functionality the user relies on?
5. **Comment quality** — are the doctrine references in the commit
   message + code comments accurate? Cite-checks.
6. **No bloat** — does the commit add dependencies, build time,
   binary size that's disproportionate to the value delivered?

---

## Specific verifications I recommend prioritizing

In rough order of "if this is wrong it matters most":

1. **`813c15dd` (LSPServerProcess deletion)** — the deletion is
   irreversible without `git revert`. Verify no production code
   path I missed depends on `LSPServerProcess`. The grep I ran
   showed zero non-test consumers; confirm.
2. **`d327e87f` (auto-invoke dispatch)** — the dispatch helpers
   `eprintln!` failures + don't propagate. Confirm this is the
   correct doctrine §10 invariant (a mirror miss must NOT break
   the legacy write). If the failure mode should be louder
   (telemetry, panic in debug builds), flag it.
3. **`261e7cca` (storage doctrine alignment)** — the new
   `ContentAddressMismatch` error path added a new error variant
   to `DagError`. Verify all existing `match err { ... }` sites
   handle the new variant or deliberately fall through.
4. **`28af9b71` (Phase 8.F replay verification)** — the
   `ReplayBundle` schema bumped from v1 to v2 (added optional
   `dag_snapshot`). Verify v1 bundles still deserialize cleanly
   under v2 readers + `verify_replay` short-circuits the DAG
   check when `dag_snapshot` is None.
5. **`d0eed651` (Gemini + Kimi CLI handlers)** — verify the CLI
   binary candidate paths actually match where the user has them
   installed. If their setup has `gemini` at a non-standard
   location, the install-hint payload will fire spuriously.

---

## What I did NOT touch (preserve unchanged)

- The 18 `Epistemos/LocalAgent/Hermes*.swift` files (canonical
  local-agent path; "Hermes" prefix refers to the Hermes-3 model's
  prompt format, not the removed Python subprocess).
- The two `#if false` Hermes subprocess test files
  (`HermesSubprocessTests.swift`, `HermesBridgeIntegrationTests.swift`)
  — kept per their explicit "do not delete" comments.
- Anything in `worktree-simulation` (untouched per the V2.5
  decision deferral).
- Macaroon capabilities in `agent_core/src/cognitive_dag/macaroons.rs`
  — orphan by doctrine until Phase 8.H.

---

## Where the canonical plans are

Read these BEFORE the commits to ground your verification:

- `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` —
  V2.1-V2.7 sequencing + V3 entry signal contract
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — §1-§10
  (especially §4 anti-patterns + §5 verification gates + §10
  authority flip)
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` — what
  goes in MAS vs Pro
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — kernel
  doctrine §13 (the predecessor doctrine to the DAG doctrine)
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — my view of
  V2 status (this doc's sibling)

---

## Format for your sign-off

When verifying, please produce:

```
COMMIT <sha> — <one-line summary>
  build:    PASS | FAIL | NOT-CHECKED
  tests:    PASS (N/M) | FAIL (failed: ...) | NOT-CHECKED
  doctrine: ALIGNED | DRIFT (where: ...) | NOT-CHECKED
  bloat:    ACCEPTABLE | EXCESSIVE (what: ...) | NOT-CHECKED
  notes:    <free text — concerns, surprises, recommended fixes>
```

For the overall V2 closure: a one-paragraph honest assessment of
whether the plan's nuance has been preserved or if I've drifted.
The user wants brutal honesty; preserve it.

---

## Five-question PR discipline (standing rule)

Per `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`
the standing five-question PR discipline applies to every commit
in scope:

1. **Stage** — which V2/V3 stage does this advance?
2. **GenUI route** — does this surface need GenUI dispatch (per
   schema-first GenUI doctrine)? Is it wired correctly?
3. **Sovereign Gate** — does this affect capability boundaries?
   Are the macaroon scopes preserved?
4. **Pro impact** — does this commit change the Pro vs MAS
   surface? If so, is the cfg-feature gating correct?
5. **TEMP-FREE-TIER** — has any temporary free-tier-only test
   path been left in production?

I have NOT systematically checked these for every commit. Please
catch any I missed.

---

## Final note from me to you

This is a long stretch (32 commits, ~5,000 LOC net add). I've
documented intent extensively in commit messages + doc files. Your
job is to find where my intent diverged from execution, where the
doctrine got bent without a deliberation brief, where the user's
nuance got lost. The user's standing rule is *"if Codex hasn't
seen it, it isn't shipped."* I respect that and have left the
door open for you to reject anything.

Sign off when ready, or list the specific commits + concerns
that need work before they ship.

— Claude session, 2026-05-05
