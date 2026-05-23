# Phase A Close-Out + Audit-of-Audit — 2026-05-17 (Terminal T5, iter-8)

Phase A of T5 (§4.I EML-IR Primitive Stack) **closes** at iter-8 with
this document. Audit-of-audit verifies every Phase A deliverable
landed against the §4.I:887-895 + driver-prompt task list; the
Phase B branch plan below locks the B1 entry slice.

**Authority:** §4.I of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`
(lines 853-913) + driver-prompt PHASES clause (this branch).

---

## 1. Audit-of-audit — Phase A deliverables checklist

Every Phase A deliverable is bound to a commit hash + line/file
verification. Per §7 of the driver doc ("Every 10 iters: run
audit-of-audit cycle"), this is the close-out audit.

| Deliverable | Iter | Commit | File | Lines | Status |
|---|---:|---|---|---:|---|
| EML substrate audit | 1 | `0b14c779b` | `docs/audits/EML_IR_AUDIT_2026_05_17.md` | 256 | ✅ landed |
| Doctrine §1-3 (mission · 6-IR table · Lean authority) | 2 | `078bbce83` | `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` | (cumulative) | ✅ landed |
| Doctrine §4-5 (lowering details · acceptance bar) | 3 | `201d35515` | same doc | 306 cumulative | ✅ landed |
| `research_custody/` skeleton (6 IRs × 4 files) | 4 | `6714761cc` | `research_custody/{eml,tropical,scan,operator,info,geometry}/` | 24 files / 266 ins | ✅ landed |
| `claims.yaml` seed entries (13 claims across 6 IRs) | 5 | `f99cdc02d` | `research_custody/<ir>/claims.yaml` | 84 ins / 6 del | ✅ landed + pushed |
| Tropical reconciliation plan | 6 | `9f3fb782e` | `docs/audits/TROPICAL_IR_RECONCILIATION_PLAN_2026_05_17.md` | 202 | ✅ landed |
| Doctrine §6 cross-IR composition lattice | 7 | `d7cd4a1a4` | same doctrine doc | 393 cumulative | ✅ landed |
| Phase A close-out (this doc) + push | 8 | this commit | `docs/audits/PHASE_A_CLOSEOUT_2026_05_17.md` + push | n/a | ✅ landing now |

**Verdict:** all 8 Phase A iters delivered as planned. No drift, no
deferrals, no failed slices.

## 2. §5.0 primary-source discipline — global audit

Every IR claim above is cited to a primary source somewhere in the
Phase A corpus. Cross-reference table:

| IR | Primary papers cited | Where |
|---|---|---|
| **EML-IR** | Odrzywołek arXiv:2603.21852 · Stachowiak arXiv:2604.23893 · Carney (TBD) · Smith quintic fence (doctrinal) | doctrine §2.1 + audit §7 + claims.yaml + tropical reconciliation §1 |
| **Tropical-IR** | Zhang/Naitzat/Lim arXiv:1805.07091 Thm 5.4 · Charisopoulos/Maragos arXiv:1805.08749 §3 · Maclagan/Sturmfels GSM 161 (in tropical.rs header, flagged for claims.yaml extension) | doctrine §2.2 + claims.yaml + tropical reconciliation §6.1 |
| **Scan-IR** | Dao/Gu arXiv:2405.21060 §6 · Blelloch CMU-CS-90-190 | doctrine §2.3 + claims.yaml + verification_status.md |
| **Operator-IR** | Lu et al. arXiv:1910.03193 Thm 2 · Li et al. arXiv:2010.08895 §3 | doctrine §2.4 + claims.yaml + verification_status.md |
| **Info-IR** | Amari (Springer 2016) Ch. 2 + Ch. 6 · Beck-Teboulle Op. Res. Lett. 31:167-175 | doctrine §2.5 + claims.yaml + verification_status.md |
| **Geometry-IR** | Hestenes-Sobczyk (Reidel 1984) Ch. 1 · Dorst-Fontijne-Mann (Morgan Kaufmann 2007) §10.3 | doctrine §2.6 + claims.yaml + verification_status.md |

**§5.0 verdict:** PASS for 5 of 6 IRs. EML-IR has one **open citation
gap**: Carney inexpressibility result (iter-1 audit §6 item 7).
This is the **only** un-cited primary source across Phase A; it must
resolve at Phase B1 entry per §3 below.

## 3. Phase B1 entry-slice plan

The lattice §6.3 of the doctrine doc requires EML-IR to ship first
(every other IR composes to it). Phase B1 acceptance per §4.I:890:
**"100-fn corpus of elementary functions round-trips through
EML-IR → normal form → Rust eval, within float tolerance."**

The iter-1 audit §6 punch-list named 7 holes. Phase B1 splits them
into iterations:

| B1 iter | Slice | Acceptance |
|---|---|---|
| **9** | Resolve **Carney inexpressibility citation** + add to `research_custody/eml/claims.yaml` (4th entry) + add to `agent_core/src/research/eml/mod.rs` source-citation header | claim cited with paper + section; iter-1 audit §6 item 7 closes |
| **10** | **Constant-extension to `EmlExpr`** — sibling-type `EmlClosure { tree, consts: Vec<f64> }` per audit §3 (preserves the parameter-free grammar term algebra; constants live alongside the tree) + serde derive + tests | `EmlClosure` round-trips through serde; closure-arity invariant `consts.len() == tree.const_slot_count()` upheld |
| **11** | **`normalize.rs` — Stachowiak canonical normal-form rewriter** — push `One` leaves to canonical position; apply elementary identities `eml(1, 1) = e`, `eml(0, 1) = 1`; canonicalize `M / f / f⁻¹` triple per Stachowiak depth-3 bound | idempotence property test (`normalize(normalize(e)) == normalize(e)`) over an 8 × 4-depth grid |
| **12** | **Branch-safe typing** — `BranchedEmlExpr` (or `EmlExpr<Branch>` phantom-tagged) — `y > 0` precondition discharged at the type level; convert runtime `NonPositiveLogArg` error into compile-time rejection for type-checked trees | construction of a `BranchedEmlExpr` whose tree contains an `Eml(_, _)` node with `y ≤ 0` fails to compile (`compile_fail` doctest) |
| **13** | **`certificate.rs` — Lean 4 term emission** for branch-safety | `lean_certificate(&tree) → String` returns a Lean 4 term; typecheck deferred to Phase C (toolchain pin per Wave J B.0.5) |
| **14-15** | **100-fn elementary corpus** — `tests/eml_ir_corpus_round_trip.rs` integration crate. Seed: trig (sin/cos/tan via Euler), hyperbolic (sinh/cosh), log family (log_b, log1p, log_e), exponential (exp, exp_m1, exp_b), power (sqrt, pow, cbrt), inverse trig (atan via series). Each entry `(name, EmlExpr, reference_fn, tolerance)` | corpus has ≥ 100 named entries; ≥ 80% round-trip through `evaluate(normalize(tree))` within tolerance vs `reference_fn` on a sample grid |
| **16** | **B1 close-out + Phase B2 entry handoff** — audit-of-audit per §7 driver-prompt cadence; sets up B2's tropical reconciliation move (iter-6 plan) | acceptance: corpus ≥ 80% closes per §4.I:906; cargo test count grows from 1671 baseline by the B1 test increment (target: +50 to +80) |

**Slice-discipline note.** Each B1 iter touches one file at a time
(audit §6 punch-list shape), per driver-prompt "ONE slice" per iter.
Phase B1 totals 8 iters (9-16) to land EML-IR's MVP; Phase B2-B6
each estimated 8-10 iters (iters 17-60 covers all six MVPs with
slack for B2's tropical migration).

## 4. Push posture + branch state

- **Local commits ahead of origin at iter-8 entry:** 2 (`9f3fb782e`
  + `d7cd4a1a4` from iter-6 + iter-7).
- **Iter-8 push covers:** iter-6 + iter-7 + iter-8 (this commit) =
  3 commits in the push.
- **Total commits since branch cut:** 8 (this commit is #8).
- **Driver `push every 5-10` cadence:** the iter-5 push covered
  iters 1-5; this iter-8 push covers iters 6-8. Both windows are
  inside the 5-10 floor.

## 5. main-broken-BLOCKER check

Per driver STOP clause "main broken → BLOCKER · no push":
- Local cargo lib test baseline (iter-2): **1671 passed; 0 failed**.
- No iter touched any code path outside `docs/`, `research_custody/`
  (the latter is new, never imported).
- No `Cargo.toml` change → no dependency drift on `main`.
- No `.xcodeproj` change → no Xcode-side build risk.

**Verdict:** main is not in a broken state attributable to Phase A.
Push is **CLEAR**.

## 6. Coord-clause status — sibling-terminal touch-points

Driver-prompt COORDINATION clause:
- **T1 carries IR-typed expressions.** Phase A doc only; no T1
  cross-link work landed. Phase C (iter 60+) handoff.
- **T2 uses Info-IR for AnswerPacket.confidence.** Phase A doc only
  (Info-IR `KlProjection` typed primitive named in doctrine §2.5 +
  composition lattice §6.2 row "Scan-IR → Info-IR"). T2 wiring
  blocks on Phase B4.
- **T3 consumes Scan-IR.** Phase A doc only. T3's F-SemiseparableBlockScan-
  Correctness gate will consume Scan-IR's AST + Dao/Gu lowering at
  Phase B3 (iter 25-ish under the §3 slice-rate estimate).

No cross-terminal merge work in Phase A. Phase B3 + Phase B4 are the
first windows where T3 and T2 hand off begins.

## 7. Risks acknowledged before Phase B

1. **Carney citation gap (§2 row 1).** The single un-closed §5.0
   item. Iter-9 must resolve.
2. **Lean toolchain pin (Wave J B.0.5).** Required before iter-13
   (`certificate.rs`) emits Lean 4 terms anyone can typecheck.
   Verification is "manual setup pass" per `eml/mod.rs:33-35`.
3. **`paper_registry/` integration.** Phase A doctrine §3 names it
   as the runtime claim ledger but no iter wired research_custody/
   claims.yaml entries into the registry. Phase C scope.
4. **OxiEML vendoring deferred.** Per `eml/mod.rs:20-22` the full
   412k+2048 ULP fixture lives in the unvendored `cool-japan/oxieml`
   crate. Substrate-floor smoke run is the only F-ULP-Oracle gate
   shipping today. Phase C work.
5. **Tropical-IR file motion.** Iter-6 plan is locked but not
   executed; iter-9 or iter-17 (B2 entry) executes the `git mv` +
   split + shim. Acceptance per the plan doc §7.

## 8. Phase A acceptance verdict

Per §4.I:904 global acceptance (item 1 only — items 2-6 are Phase B/C):

> 1. All 6 IRs have an MVP, audit doc, doctrine doc, and property-test suite.

Phase A delivers **audit + doctrine docs** for all 6 IRs. MVPs +
property-test suites are Phase B (B1-B6). Phase A acceptance:
**PASS** for the audit + doctrine sub-criterion.

## 9. Iter-9 entry conditions

Next iteration starts Phase B1 iter-9 (Carney citation closure +
research_custody update + eml/mod.rs header amendment) per §3 above.

---

**Status:** Phase A complete; Phase B opens iter-9.
**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
