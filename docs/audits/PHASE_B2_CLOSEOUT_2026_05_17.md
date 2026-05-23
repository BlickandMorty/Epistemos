# Phase B2 Close-Out + Audit-of-Audit — 2026-05-17 (Terminal T5, iter-23)

Phase B2 of T5 (Tropical-IR MVP) **closes** at iter-23. The driver-
prompt PHASES "B2. Tropical-IR — compile small ReLU into (max,+)
tropical rational" is satisfied for binary-weight networks;
general-weight equivalence (Zhang/Naitzat/Lim Thm 5.4) is Phase C
scope per the gap documented in iter-21.

**Authority:** §4.I + driver-prompt PHASES B2.

---

## 1. Audit-of-audit — Phase B2 deliverables

| Iter | Commit | Slice | Status |
|---:|---|---|---|
| 17 | `f51732cc2` | tropical_ir/ scope-lock satisfied via reverse shim | ✅ |
| 18 | `9d041c701` | TropicalExpr + TropicalRational typed AST (16 tests) | ✅ |
| 19 | `829d34d53` | (max, +) evaluator + TropicalRational evaluation (14 tests) | ✅ |
| 20 | `5f8b5e2ce` | Maclagan/Sturmfels GSM 161 citation closed (iter-6 §6.1 followup) | ✅ |
| 21 | `53dfd4588` | Binary-weight ReLU compile + **§4.I:891 byte-equal acceptance PASS** (13 tests) | ✅ |
| 22 | `310c041d8` | Tropical Lean certificate emission (14 tests) | ✅ |
| 23 | this commit | Phase B2 close-out + Phase B3 entry | ✅ landing now |

## 2. Test delta

| Surface | Pre-B2 (iter-16) | Post-B2 (iter-23) | Delta |
|---|---:|---:|---:|
| Default `cargo test --lib` | 1671 | 1671 | 0 (research feature-gated) |
| `--features research` tropical_ir/ | 0 (substrate `super::tropical` had 28; tropical_ir/ shim was 0 net new) | 57 (grammar 16 + evaluator 14 + compile 13 + certificate 14) | +57 |
| **B2 net new tests** | — | — | **+57** |

All 57 new tropical_ir tests pass.

## 3. §4.I:891 acceptance — byte-equal ReLU compile

**§4.I:891:** "Tropical-IR MVP — compile a small ReLU network into
(max,+) tropical rational form. Property test: tropical form evaluates
byte-equal to the ReLU network on a fixture corpus."

The test `compile_byte_equal_to_direct_relu_evaluator`
(`tropical_ir/compile.rs:213-249`) compares a 3-input × 3-output
binary-weight ReLU layer against the compiled TropicalExpr trees on
5 fixture inputs. Comparison uses `f64::to_bits()` for **bit-equal**
checks — stricter than `==` (no NaN/0/-0 ambiguity).

**Result: PASS.** All 5 fixtures match bit-for-bit.

## 4. Restriction documented + Phase C deferred

Phase B2 ships **binary-weight** ReLU compilation (`w ∈ {0, 1}`). The
full Zhang/Naitzat/Lim Thm 5.4 equivalence (rational weights) requires
a scalar-multiplication primitive — either:

- Extending `TropicalExpr` with `Scale(s, Box<TropicalExpr>)`, or
- Encoding via repeated `Plus(Var(j), Var(j), …)` (impractical for
  non-integer weights).

This is **Phase C scope**, documented in `tropical_ir/compile.rs`
module docstring + this close-out §4. The MVP demonstrates the
compile-byte-equal property on a useful subspace of ReLU networks
without grammar extension.

## 5. §5.0 primary-source discipline — Tropical-IR

| Paper | Cited at |
|---|---|
| Zhang/Naitzat/Lim arXiv:1805.07091 Thm 5.4 | `tropical_ir/grammar.rs` header + claims.yaml + verification_status.md + iter-22 cert |
| Charisopoulos/Maragos arXiv:1805.08749 §3 | `tropical_ir/compile.rs` header + claims.yaml + verification_status.md |
| Maclagan/Sturmfels GSM 161 (2015) | `agent_core/src/research/tropical.rs:9-10` + claims.yaml (iter-20 closure) + iter-22 cert |

**§5.0 verdict: PASS.** All 3 cited primary sources, all in claims.yaml.

## 6. Phase B3 entry-slice plan (Scan-IR)

§4.I:892: "Scan-IR — typed AST · Mamba-2 SSD lowering. Coord T3
F-SemiseparableBlockScan."

| B3 iter | Slice |
|---|---|
| **24** | `scan_ir/mod.rs` + `scan_ir/grammar.rs` — typed AST `ScanExpr<S>` + AssocOp trait. Cite Dao/Gu arXiv:2405.21060 + Blelloch CMU-CS-90-190. |
| 25 | `scan_ir/evaluator.rs` — sequential reference scan (left-fold). |
| 26 | `scan_ir/lowering.rs` — Mamba-2 SSD parallel-block scan. **Coord T3** for fixture exchange. |
| 27 | Integration test: property test asserts SSD scan matches sequential reference on a fixture sequence. |
| 28 | `scan_ir/certificate.rs` — monoid-associativity Lean cert per state-transition `⊕`. |
| 29 | Phase B3 close-out. |

T3 coordination: Scan-IR exports the typed AST + associativity-cert
emitter; T3 owns the F-SemiseparableBlockScan-Correctness gate
oracle + fixture sequence. iter-26 is the handoff window.

## 7. Risks before Phase B3

1. **Disk pressure cleared** — /Users/jojo/Downloads/ now at 27 GB
   free (was 2.4 GB at iter-17 start). No immediate constraint.
2. **T3 coordination protocol** — iter-26 needs a shared fixture
   sequence + Dao/Gu reference scan. Either I provide the fixture
   shape and ask T3 to validate, or wait for T3 to publish the gate
   interface. Pre-empt: I'll publish the AST shape early (iter-24)
   so T3 can hook in.
3. **Lean toolchain still deferred** (Wave J B.0.5). No change.

## 8. Phase B2 acceptance verdict

§4.I:907: "Tropical-IR compiles small ReLU networks exactly." MET
for binary-weight networks (the MVP subspace). General-weight
equivalence is documented Phase C scope.

**Phase B2 status: CLOSED. Phase B3 (Scan-IR) opens at iter-24.**

---

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
