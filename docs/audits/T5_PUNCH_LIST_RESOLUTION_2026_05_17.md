# T5 Punch-List Resolution — 2026-05-17 (iter-49)

Cross-walks every open item flagged across all T5 audit + close-out
docs and reports its resolution status post-Phase-B. Companion to
`docs/audits/FINAL_AUDIT_OF_EVERYTHING_2026_05_17.md` (iter-48):
that doc verifies deliverables; this one closes the item-tracker.

---

## 1. iter-1 audit `EML_IR_AUDIT_2026_05_17.md` §6 punch-list

The iter-1 audit named 7 blocking holes for Phase B1.

| # | Item | Resolution |
|---|---|---|
| 1 | Constant-extension to `EmlExpr` | ✅ iter-10 (`4e0cbf253`): EmlClosure sibling type with Slot(idx) leaves |
| 2 | `normalize.rs` — Stachowiak canonical normal-form rewriter | ✅ iter-11 (`99f54d506`): closure-form constant-folding + idempotence |
| 3 | Branch-safe typing | ✅ iter-12 (`594502e20`): BranchedEmlExpr + PositiveEmlExpr typestate; compile_fail doctest |
| 4 | Lean certificate emission | ✅ iter-13 (`e5f45c316`): `lean_certificate(&PositiveEmlExpr)` emits sorry-stubbed theorem with `v > 0` goal |
| 5 | 100-fn elementary-function corpus | ✅ iter-14 + iter-15: 53 hand-derived + ~50 programmatic = 100+ entries with round-trip property test |
| 6 | Round-trip property test | ✅ iter-15 (`14a1e77d7`): §4.I:906 ≥80% acceptance test PASSES |
| 7 | Carney inexpressibility citation | ✅ iter-9 (`df41be778`): Carney "Inexpressibility in Exp-Minus-Log" arXiv:2605.01636 added to `eml/mod.rs` + claims.yaml |

**Iter-1 §6 punch-list: 7/7 closed.**

## 2. iter-1 audit §9 reconciliation issues

| # | Item | Resolution |
|---|---|---|
| §9.1 | Flat `tropical.rs` vs new `tropical_ir/` directory | ✅ iter-17 (`f51732cc2`): reverse-shim — `tropical_ir/mod.rs` re-exports from flat file. Iter-6 plan's forward-direction split deferred to a future iter (still optional; both paths work) |
| §9.2 | Co-author tag form | ✅ iter-9 onward: `Co-Authored-By: Codex (T5) <noreply@anthropic.com>` used consistently per `project_terminal_t5_override_2026_05_17` memory |
| §9.3 | OxiEML vendoring | ⏳ Phase C — needs `git submodule add` + network; explicitly deferred per `eml/mod.rs:20-22` |

**Iter-1 §9 reconciliation: 2/3 closed; 1 explicitly deferred to Phase C.**

## 3. iter-6 tropical reconciliation plan follow-ups

| # | Item | Resolution |
|---|---|---|
| §6.1 | Add Maclagan/Sturmfels to `research_custody/tropical/claims.yaml` | ✅ iter-20 (`5f8b5e2ce`): 3rd claim entry landed |
| §6.2 | `paper_registry/seed.rs` runtime integration | ⏳ Phase C |
| §6.3 | Post-move `research_custody/tropical/verification_status.md` paths | n/a (move not executed; reverse shim instead) |
| §7 | Iter-9 move acceptance bar | n/a (move deferred per iter-17 disk-pressure rationale) |

**Iter-6 follow-ups: 1 closed, 1 explicitly Phase C, 2 n/a (move
not executed).**

## 4. Phase A close-out `PHASE_A_CLOSEOUT_2026_05_17.md` §7 risks

| # | Risk | Resolution |
|---|---|---|
| 1 | Carney citation gap | ✅ iter-9 closure |
| 2 | Lean toolchain pin | ⏳ Phase C (Wave J B.0.5) |
| 3 | `paper_registry/` integration | ⏳ Phase C |
| 4 | OxiEML vendoring deferred | ⏳ Phase C |
| 5 | Tropical-IR file motion | n/a (reverse shim per iter-17) |

**Phase A §7 risks: 1 closed, 3 Phase C, 1 n/a.**

## 5. Phase B1 close-out `PHASE_B1_CLOSEOUT_2026_05_17.md` §8 risks

| # | Risk | Resolution |
|---|---|---|
| 1 | Disk pressure | ✅ resolved (27 GB free as of iter-18 onward) |
| 2 | Lean toolchain pin | ⏳ Phase C |
| 3 | Default lib baseline must hold | ✅ HELD across all 47 Phase B iters (1671 unchanged) |

**Phase B1 §8 risks: 2 closed, 1 Phase C.**

## 6. Phase B2 close-out §7 risks

| # | Risk | Resolution |
|---|---|---|
| 1 | Disk pressure cleared | ✅ confirmed across remaining iters |
| 2 | T3 coordination protocol | ✅ resolved via iter-26/27/28 handoff (Scan-IR exports `ssd_block_scan` + `scan_ssd_equivalence_<hash>` theorem + 100-element fixture) |
| 3 | Lean toolchain still deferred | ⏳ Phase C |

**Phase B2 §7 risks: 2 closed, 1 Phase C.**

## 7. Phase B3 close-out §7 risks

| # | Risk | Resolution |
|---|---|---|
| 1 | Disk: 27 GB free | ✅ held |
| 2 | B4 iter-33 logistic fixture | ✅ delivered in `tests/info_ir_logistic_mirror.rs` (hand-rolled 6-sample 2D fixture) |
| 3 | Amari book vendoring | ⏳ Phase C (book PDF — no arXiv ID) |

**Phase B3 §7 risks: 2 closed, 1 Phase C.**

## 8. Phase B4-B6 close-outs (no §7 explicit risks)

All B4-B6 close-outs reference Phase C deferrals without adding
new risks. All B4-B6 §4.I acceptance bars MET.

## 9. Sibling-terminal cross-references

Per the memory state at session entry, sibling terminals exist:
T1 (trifusion), T2 (agent), T3 (uasacs), T4 (vault), T6 (uiux),
T7 (eml runtime), T8 (biometric). T5's deliverables interlock with
T1, T2, T3:

| Terminal | Cross-link | Handoff state |
|---|---|---|
| T1 | hyperdynamic_schemas/ carries IR-typed expressions | ⏳ Phase C — surface available via the 6 IR module exports |
| T2 | AnswerPacket.confidence consumes Info-IR `KlProjection` | ✅ infra ready (`info_ir::evaluate_scalar` + `logistic_regression_step` exported) |
| T3 | F-SemiseparableBlockScan-Correctness consumes Scan-IR `ssd_block_scan` | ✅ infra ready (`scan_ir::ssd_block_scan` + Lean theorem + 100-element fixture in `tests/scan_ir_ssd_match.rs`) |

T2 + T3 wiring is THEIR call to make; T5's contract is fulfilled
on the export side.

## 10. Open items explicitly deferred to Phase C

Consolidated list:

1. **OxiEML vendoring** (Wave J B.0.1) — needs `git submodule add
   cool-japan/oxieml` + network.
2. **`tomdif/eml-lean` vendoring** (Wave J B.0.2) — needs Lean
   toolchain + network.
3. **Lean 4.29.1 toolchain pin verification** (Wave J B.0.5) —
   needs the actual Lean toolchain installed for typecheck.
4. **Lean typecheck the per-tree certificates** (all 6 IRs) —
   iters 13/22/28/34/40/46 emit sorry-stubbed terms; Phase C
   discharges the sorries.
5. **OxiEML 412k+2048 ULP fixture** — needs the vendored crate
   from item 1.
6. **Tropical-IR general-weight equivalence** (Zhang/Naitzat/Lim
   Thm 5.4 for rational weights) — needs AST extension (Scale
   primitive or equivalent).
7. **Tri-Fusion integration** with T1's hyperdynamic_schemas/.
8. **paper_registry/ runtime integration** — wire research_custody/
   claims.yaml entries into the runtime claim ledger.
9. **PDF vendoring** for the 13 cited primary papers — populate
   `research_custody/<ir>/sources/` + `hashes/SHA256SUMS`.
10. **Tropical reconciliation plan execution** (iter-6 forward
    direction) — optional given the reverse-shim works.

All 10 items are explicitly Phase C scope. None are blockers for
the §4.I:904 items 1-5 (which are MET).

## 11. Verdict

**Every open item across every audit document has a clear
resolution status.** Closed or explicitly deferred to Phase C; no
items in a fuzzy state.

T5 Phase A + Phase B closure is **fully accounted for** — both
deliverable-side (per iter-48 final audit) and item-tracker-side
(this doc).

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
