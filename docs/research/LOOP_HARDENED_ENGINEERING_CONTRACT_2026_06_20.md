# LOOP HARDENED ENGINEERING CONTRACT — failproof, super-robust, plan-anchored (2026-06-20)

Owner: *"always reference and read the plan for deeper analysis; make the agent deeply working, super-hardened,
super-robust, failproof."* This is the standing engineering discipline the master build loop follows for EVERY item.
It is the HOW that wraps the WHAT (`MASTER_BUILD_QUEUE_2026_06_20.md`) and the WHY (`OWNER_REQUESTS_LEDGER` verbatim
intent + the SS-* research). Read this + the plan at the start of every iteration.

## 0. ALWAYS READ THE PLAN FIRST (every iteration, before deciding or building)
Each iteration begins by reading, in order: (1) `MASTER_BUILD_QUEUE_2026_06_20.md` (what's next in the walk),
(2) the current item's `OWNER_REQUESTS_LEDGER_2026_06_18.md` block (the owner's VERBATIM intent),
(3) its SS-* slice + `CONNECTION_MAP_2026_06_20.md` (the research + reconnected intent), (4) `RESEARCH_FINALIZATION_INDEX`.
NEVER act from memory of the plan — re-read it; compaction and time erode memory, the docs are ground truth. Deeper
analysis ALWAYS cites the plan. If the item is THIN (no verbatim/research link), RECONNECT it first (find + attach its
original query + research) before building — the connection is a precondition.

## 1. DELIBERATE → DESIGN → SAFE-SEAM (before a single edit)
- Re-derive the item's true intent from the verbatim + research; state the acceptance bar (what "done + user-facing" means).
- Check current code/logs vs the plan's claim (most "NOT IMPLEMENTED" labels hide PASSes — audit before declaring).
- Choose the PROVABLY-SAFE additive seam: a new file / flag-gated branch / non-invasive hook over an in-place rewrite of
  a fragile surface (TK2/Prose, AppBootstrap, routing, Metal). Fragile → research the seam + regression guards, then code.

## 2. COMMIT A CLEAN SAVEPOINT before any risky edit (never lose work)
main-only; commit + push each green; if the next edit is risky (TK2 core, AppBootstrap launch path, routing), commit the
working state FIRST so a bad edit is one `git restore` away. Never leave the tree in a half-broken uncommitted state.

## 3. BUILD super-robustly (failproof engineering invariants)
- **Flag-gate** anything that could regress a live surface; flag-OFF must be **byte-identical** to today (prove it in a test).
- **Crash-safe**: separate windows/overlays drop `@Environment` — VERIFY the injection (`.withAppEnvironment`) exists before
  reading injected state (the SS-CRASH launch-crash class); guard every nil/zero/oversized/missing case so it can't crash.
- **No data loss**: never mutate persisted md/vault as a side effect (the SS-2S draw-only floor); never vault writes.
- **No hidden fallback**: every substitution/degradation visible at the point of use (honest, not a fake control).
- **No regression** to live chat / SS-CR / the 2,679-test suite. Re-run the relevant tests; routing changes need the full matrix.
- **Honest tier**: green = reachable + visible + verified + (witnessed-or-honestly-PENDING). No fake-T4, no green-without-witness.
- **Concurrency**: inference off-MainActor; UniFFI callbacks `DispatchQueue.main.async` never `.sync`; `// SAFETY:` on unsafe.

## 4. VERIFY exhaustively (self-verify, owner-verification is NOT a gate)
RENDER/behavior tests (not substring) + `cargo test --lib` (real Rust execution) + Swift compile-verify + xcodebuild
launch-smoke (proves it compiles + launches). "visual/live PENDING OWNER" is a non-blocking note, not a stop. Reason each
assertion to certainty where headless execution hangs.

## 5. NUCLEAR REVIEW + REPAIR PASSES (multi-checkpoint — see master queue)
Run the nuclear code-review (R-CODEREVIEW + aggressive checker) every ~5 items, at every tier boundary, and at the end of
the walk. Each cycle also: SS-CLEAN (dead-flag/orphan, duplicate, stale, surface-parity, launch-smoke) + Owner-Request
Coverage Sweep + NUANCE-COMPLETENESS + FOLLOW-ON-CAPTURE (harvest every "pending/next-increment" note into the ledger) +
DEEP-REPAIR (find→fix→verify + one perf + one usability win). DONE-RE-AUDIT: re-check "done" items are actually user-facing.

## 6. SHIP + RECORD (each green)
Commit (Co-Authored-By Claude) citing the slice + ledger line; push; the commit body states what's verified + what's an
honest non-blocking pending. A deferred safe-increment goes to SS-FOLLOWON — never dropped.

## 7. SELF-HEAL + NEVER STALL
"API error Retrying N/10" / "Rate limited (not your usage limit)" → wait, re-sample, don't intervene. On compaction →
re-anchor to this contract + the master queue + ledger (they're on disk, not in memory). P0 owner reports preempt
everything. Never park for owner-verification; keep building the next plan item.

## SCOPE (hard, never cross)
Loop builds the MODEL-AGNOSTIC substrate + chat/UI/editor/graph/recall surfaces. HARD OFF-LIMITS: NEW MODEL brain-1
(SSM/Mamba/M0/signal_bus/lattice/research-internals), the 70B, Companion→Osaurus clone backends. Never vault writes.
TK2/Prose non-invasive except the agreed SS-2S md-image + SS-IL overlays. Cross-ref MASTER_BUILD_QUEUE, RESEARCH_FINALIZATION_INDEX, SS-CLEAN, SCOPE BOUNDARY.

## ‼️ PROVEN-DONE OVERRIDE (owner 2026-06-21) — supersedes any weaker "done" in this contract
"Done" now requires PROVEN reach to the user's REAL state (see SS-PROVEN_DONE_DOCTRINE): real-state test (persisted/
existing-install, not fresh) + LIVE not flag-gated-off (bug fixes default-ON once the regression guard passes) + migrate
existing persisted state + end-to-end + witnessed-or-honestly-PENDING. Assume the user is always an EXISTING install with
persisted prefs. Every owner-reported bug gets a regression test that WOULD HAVE CAUGHT the original report. Never mark
[x] / say "done" on test-green or build-green alone. A default-OFF flag = "staged, not reaching the user yet," never "done."
