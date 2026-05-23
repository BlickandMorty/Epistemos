# T18B — ACS namespace proposal (2026-05-22)

**Status**: PROPOSAL ONLY — awaiting user arbitration before either branch
acts. No code changes land from this doc.

**Branches in scope**
- `codex/t17b-lattice-wbo-register-2026-05-18` — owns
  `agent_core/src/research/acs/` (decomposed in commit `674bc9ae40`)
- `codex/t18b-acs-admission-field-2026-05-18` — owns
  `agent_core/src/acs_admission/` (decomposed across commits `68e60ef435`,
  `e0ad3c62ae`, `b9302fcc81`)

## Headline finding

**There are zero hard name collisions between the two trees today.**
Every public symbol in `research::acs::*` and every public symbol in
`acs_admission::*` differs by at least the case-style of the `ACS`
prefix (T17B `Acs*` / T18B `ACS*`) and by the surrounding noun. The two
modules can compile alongside each other on a single merged tree without
touching either side.

The collision the user prompt asks us to resolve is therefore
*conceptual* — not syntactic. It splits into three sub-questions:

1. Are these two trees the same "ACS"? (Yes by doctrine, but at
   different layers.)
2. Where should "ACS anchors" live? (Neither branch has it yet; T17B's
   doc-string hints at it, T18B's hardening commits hint at it.)
3. Should we converge the prefix convention now or grandfather the
   split?

This doc lays out the surface, calls out the three sub-questions
explicitly, and proposes one resolution per question that the user can
accept, redirect, or split.

---

## Surface inventory (type-by-type)

### T17B — `crate::research::acs::*` (substrate floor)

Source: `research/acs/{mod,autopoiesis,governance,kuramoto,notch_delta,vsm}.rs`

| Public item                              | Kind  | Owner sub-file          |
| ---------------------------------------- | ----- | ----------------------- |
| `AcsScale`                               | enum  | `governance.rs`         |
| `AcsPrimitive`                           | enum  | `governance.rs`         |
| `AcsDispatchError`                       | enum  | `governance.rs`         |
| `validate_dispatch`                      | fn    | `governance.rs`         |
| `KuramotoNetwork`                        | struct| `kuramoto.rs`           |
| `KuramotoOscillator`                     | struct| `kuramoto.rs`           |
| `KuramotoError`                          | enum  | `kuramoto.rs`           |
| `OrderParameter`                         | struct| `kuramoto.rs`           |
| `SyncOutcome`                            | struct| `kuramoto.rs`           |
| `kuramoto_step`                          | fn    | `kuramoto.rs`           |
| `order_parameter`                        | fn    | `kuramoto.rs`           |
| `critical_coupling_kc`                   | fn    | `kuramoto.rs`           |
| `run_until_sync`                         | fn    | `kuramoto.rs`           |
| `NotchDeltaCell`                         | struct| `notch_delta.rs`        |
| `NotchDeltaNetwork`                      | struct| `notch_delta.rs`        |
| `NotchDeltaParams`                       | struct| `notch_delta.rs`        |
| `NotchDeltaError`                        | enum  | `notch_delta.rs`        |
| `CellFate`                               | enum  | `notch_delta.rs`        |
| `BimodalOutcome`                         | struct| `notch_delta.rs`        |
| `notch_delta_step`                       | fn    | `notch_delta.rs`        |
| `bimodality_score`                       | fn    | `notch_delta.rs`        |
| `classify_cells`                         | fn    | `notch_delta.rs`        |
| `run_until_bimodal`                      | fn    | `notch_delta.rs`        |
| `ComponentId`                            | struct| `autopoiesis.rs`        |
| `ProductionEdge`                         | struct| `autopoiesis.rs`        |
| `ProductionNetwork`                      | struct| `autopoiesis.rs`        |
| `ComponentProductionVerdict`             | struct| `autopoiesis.rs`        |
| `OperationalClosureVerdict`              | struct| `autopoiesis.rs`        |
| `AutopoiesisError`                       | enum  | `autopoiesis.rs`        |
| `check_operational_closure`              | fn    | `autopoiesis.rs`        |
| `verify_component_production`            | fn    | `autopoiesis.rs`        |
| `count_sccs`                             | fn    | `autopoiesis.rs`        |
| `is_strongly_connected`                  | fn    | `autopoiesis.rs`        |
| `VsmUnit`                                | struct| `vsm.rs`                |
| `VsmLevel`                               | enum  | `vsm.rs`                |
| `VsmLevelCounts`                         | struct| `vsm.rs`                |
| `VsmError`                               | enum  | `vsm.rs`                |
| `check_vsm_consistency`                  | fn    | `vsm.rs`                |

### T18B — `crate::acs_admission::*` (admission policy)

Source: 13 submodules under `acs_admission/`.

| Public item                                    | Kind  | Owner sub-file   |
| ---------------------------------------------- | ----- | ---------------- |
| `ACS_AUDIT_RUN_EVENT_KEY`                      | const | `common.rs`      |
| `ACSRiskVector` / `ACSRiskVectorError`         | …     | `risk.rs`        |
| `ACSOperationKind` / `ACSLane`                 | enum  | `risk.rs`        |
| `ACSAdmissionPayload`                          | enum  | `wire.rs`        |
| `ActiveAssemblyPacket`                         | struct| `requests.rs`    |
| `ACSMemoryWriteRequest`                        | struct| `requests.rs`    |
| `ACSToolActionRequest`                         | struct| `requests.rs`    |
| `ACSKernelPromotionRequest`                    | struct| `requests.rs`    |
| `ACSModelAdaptationRequest`                    | struct| `requests.rs`    |
| `ACSAdmissionInput` / `ACSAdmissionInputError` | …     | `input.rs`       |
| `ACSAdmissionVerdict`                          | enum  | `verdict.rs`     |
| `ACSAuditRecord` / `ACSAuditRecordError`       | …     | `verdict.rs`     |
| `AuditRecordId`                                | struct| `verdict.rs`     |
| `CapabilitySignature`                          | struct| `proof.rs`       |
| `SCOPERexAdmissionProof`                       | struct| `proof.rs`       |
| `ACSAdmissionProofError`                       | enum  | `proof.rs`       |
| `SCOPERexAdmissionProofVerificationError`      | enum  | `proof.rs`       |
| `ACSAdmissionDecision`                         | struct| `decision.rs`    |
| `ACSAuditSink` / `ACSAuditError`               | …     | `audit_sink.rs`  |
| `ACSRunEventLogSink` / `InMemoryACSAuditSink`  | struct| `audit_sink.rs`  |
| `ACSAuditLookupError`                          | enum  | `audit_sink.rs`  |
| `resolve_acs_audit_record`                     | fn    | `audit_sink.rs`  |
| `admit` / `admit_and_log` / `admit_and_record` | fn    | `admit.rs`       |
| `guard_durable_commit` / `ACSDurableCommitError`| …    | `admit.rs`       |
| `ACSRiskThresholds`                            | struct| `policy.rs`      |
| `ACSCapabilityRule`                            | struct| `policy.rs`      |
| `ACSOperationThresholdRule`                    | struct| `policy.rs`      |
| `ACSPolicy` / `ACSPolicyError`                 | …     | `policy.rs`      |

### Cross-tree intersection

Run with `comm`-style diff on the two surfaces: **0 shared identifiers**.

The closest near-collisions are:

| T17B name                       | T18B name                              | Distance                    |
| ------------------------------- | -------------------------------------- | --------------------------- |
| `AcsDispatchError`              | `ACSAdmissionInputError`               | both `Acs*Error`, different layer |
| `AcsScale`                      | `ACSLane`                              | both organize by scale/lane |
| `OperationalClosureVerdict`     | `ACSAdmissionVerdict`                  | both "verdict" but unrelated semantics |
| `validate_dispatch`             | `validate_*` (24 internal helpers)     | T18B's `validate_*` are `pub(crate)`, not `pub` |

None of these would refuse to link. They could read confusingly to a
caller who already imported one and then sees the other.

---

## Sub-question 1 — Is this the "same ACS"?

Both branches' doc-strings ground "ACS" in the same canonical sources:

- T17B `research/acs/mod.rs`:
  > Autopoietic Cognitive Stack (ACS) doctrine. Recursive self-governance
  > where each cell is a complete SCOPE-Rex instance and cells synchronize
  > via Kuramoto-coupled phase dynamics on Apple Silicon UMA.

- T18B `acs_admission/mod.rs`:
  > ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
  > admission is a policy boundary above SCOPE-Rex. It is intentionally
  > pure-data: it does not call cloud providers, run inference, or apply
  > durable state changes directly.

T17B describes the *substrate floor* (the synchronization primitives
that let cells form tissues — Kuramoto, Notch-Delta, Autopoiesis, VSM,
multi-scale dispatch).

T18B describes the *admission boundary above SCOPE-Rex* (verdict, audit,
policy, capability gating for cognitive writes/promotions).

**Proposal**: Yes, same ACS doctrine; different stack layers. Adopt the
following layered phrasing in both module-level doc-comments so a reader
landing in either one knows where the other half lives:

> ACS in this codebase is split by layer:
> - `crate::research::acs::*` — substrate floor (Kuramoto sync, Notch-Delta
>   differentiation, autopoietic closure, VSM levels, multi-scale dispatch)
> - `crate::acs_admission::*` — admission boundary above SCOPE-Rex
>   (verdict, audit, policy, capability gating)

This is a 4-line addition to each `mod.rs`. Costs nothing, eliminates
the "wait, which ACS?" friction in code review.

---

## Sub-question 2 — Where do "ACS anchors" live?

Neither tree currently has an `acs::anchors` submodule. Existing
anchor-related code is scattered:

- T17B `research/acs/mod.rs` doc-string mentions
  `F-ACS-AnchorLookup` as a falsifier hook for "substrate anchor lookups
  that must remain grounded in typed ACS/code evidence", but no module
  implements it yet.
- T17B `lattice_wbo/accounting.rs` and `lattice_wbo/verifier.rs` contain
  the word "anchor" in unrelated lattice-WBO accounting logic — not ACS
  anchors.
- T18B has no anchor code at all (the prompt's reference to "ACS anchors"
  appears speculative for the T18B side).

**Proposal**: Reserve `crate::research::acs::anchors` as the canonical
path for any future substrate-anchor primitive (it pairs naturally with
the substrate-floor Kuramoto/Notch-Delta/Autopoiesis/VSM neighbors that
already live in `research::acs::`). No code lands today; this just
documents the reservation in `research/acs/mod.rs` so the next ACS
author doesn't accidentally place it under `acs_admission`.

If T18B later grows admission-side anchor support (e.g.,
"this admission references a grounding anchor in the substrate"), it
would go at `acs_admission::anchor_ref` (a *reference* type pointing at
`research::acs::anchors::*`, not a duplicate implementation).

---

## Sub-question 3 — Prefix convention (`Acs*` vs `ACS*`)

T17B types follow Rust-idiomatic CamelCase: `AcsPrimitive`, `AcsScale`,
`AcsDispatchError`.

T18B types follow legacy all-caps acronym style: `ACSRiskVector`,
`ACSPolicy`, `ACSAdmissionVerdict`. This style is inherited from earlier
hardening commits (`af78e4bfb5`, `1e388b8b8d`, etc.); the names predate
T17B's choice.

A reader who imports both will see two case styles side-by-side. Rust's
clippy `upper_case_acronyms` lint fires on the T18B side (currently
silenced by the codebase's lint config).

**Three options, escalating in churn**:

| Option | Action                                                                  | Churn        |
| ------ | ----------------------------------------------------------------------- | ------------ |
| **3a** | Document the convention split as intentional and move on. Add a note to | ~10 LOC docs |
|        | both `mod.rs`'s explaining why the prefixes differ.                     |              |
| **3b** | Rename T18B's types from `ACS*` to `Acs*`. Updates 30+ pub idents +     | ~400 callers |
|        | every test + every caller. Big diff, no behaviour change.               | + churn      |
| **3c** | Rename T17B's types from `Acs*` to `ACS*`. Same scale of edit on T17B.  | ~150 callers |

**Recommendation: 3a (document the split)**.

Rationale:
- T18B's `ACS*` style has been on `main` precedent through five hardening
  commits and 379 unit tests. A rename now would risk breaking external
  callers (Swift FFI surfaces, Bridge code, etc.) that the user may not
  want to touch in a refactor branch.
- T17B's `Acs*` style is the Rust-idiomatic choice and matches the rest
  of the codebase (look at `cognitive_dag`, `provenance`, `agent_runtime`,
  etc.).
- Co-existence works. The two prefix styles are unambiguous at the
  identifier level (`ACSPolicy` vs `AcsPrimitive` never alias-conflict
  in a `use` statement).
- A future "convergence" PR can revisit if the dual style becomes a
  reader-friction problem at scale. Today it's not.

---

## Who owns what

| Concern                                       | Canonical path                                  | Branch  |
| --------------------------------------------- | ----------------------------------------------- | ------- |
| Substrate-floor sync (Kuramoto)               | `crate::research::acs::kuramoto`               | T17B    |
| Cell-fate differentiation (Notch-Delta)       | `crate::research::acs::notch_delta`            | T17B    |
| Autopoietic closure verifier                  | `crate::research::acs::autopoiesis`            | T17B    |
| Viable Systems Model levels                   | `crate::research::acs::vsm`                    | T17B    |
| Multi-scale governance dispatch               | `crate::research::acs::governance`             | T17B    |
| **Substrate anchors** (future)                | `crate::research::acs::anchors` *(reserved)*   | T17B    |
| Admission policy (the boundary above SCOPE-Rex)| `crate::acs_admission::*`                      | T18B    |
| Admission audit-trail / sink                  | `crate::acs_admission::audit_sink`             | T18B    |
| Admission proof (SCOPE-Rex compat)            | `crate::acs_admission::proof`                  | T18B    |
| **Admission anchor reference** (future)       | `crate::acs_admission::anchor_ref` *(reserved)* | T18B   |

No path moves. The "reserved" rows just mark the spots so future PRs
land in the right tree.

---

## Collision-by-collision resolution map

The user prompt asked for "every collision mapped to a resolution". Here
is the exhaustive list against the inventory above:

| #  | Collision                                                                 | Resolution                                                                                              |
| -- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 1  | Both trees use the "ACS" prefix in identifiers and module paths.          | **Keep both paths**: `crate::research::acs::*` and `crate::acs_admission::*`. Add cross-reference docs (Sub-Q 1). |
| 2  | `Acs*` vs `ACS*` case style in identifiers.                               | **Grandfather both** (Option 3a). Document the why in each `mod.rs`.                                    |
| 3  | "AcsDispatchError" vs "ACSAdmissionInputError" — both `*DispatchError`-like. | No syntactic collision. Doc clarifies layers (Sub-Q 1).                                              |
| 4  | "OperationalClosureVerdict" vs "ACSAdmissionVerdict" — both "verdict".    | No syntactic collision. Different semantic domains; doc clarifies.                                      |
| 5  | "validate_dispatch" (T17B pub fn) vs "validate_*" helpers (T18B pub(crate)). | No collision: T18B's `validate_*` are crate-private and not re-exported.                              |
| 6  | "ACS anchors" — referenced by both doc-strings, implemented by neither.   | **Reserve `research::acs::anchors`** for substrate anchors. **Reserve `acs_admission::anchor_ref`** for admission-side references (Sub-Q 2). |
| 7  | Module-level doc-comment phrasing diverges on what "ACS" means.           | **Unify the layered phrasing** (4-line addition to both `mod.rs`'s, Sub-Q 1).                          |

---

## Net code change required by this proposal

| File                                                  | Change                            | LOC |
| ----------------------------------------------------- | --------------------------------- | --- |
| `agent_core/src/research/acs/mod.rs`                  | Add layered-phrasing doc comment  | ~5  |
|                                                       | Reserve `pub mod anchors;` *(commented placeholder)* | ~1 |
| `agent_core/src/acs_admission/mod.rs`                 | Add layered-phrasing doc comment  | ~5  |
|                                                       | Reserve `pub mod anchor_ref;` *(commented placeholder)* | ~1 |
| `docs/T18B-NAMESPACE-PROPOSAL-2026-05-22.md`         | This document                     | this file |

**Total**: ~12 LOC of doc-comment additions across two modules + this
proposal doc. No identifier rename. No code move. No test churn.

---

## Decision the user needs to make

Three independent yes/no choices:

- [ ] **Q1** (Layer doc-comments): accept the 4-line layered-phrasing
  addition to both `mod.rs`'s?
- [ ] **Q2** (Anchor reservation): accept the `research::acs::anchors` +
  `acs_admission::anchor_ref` *path* reservation, with no code today?
- [ ] **Q3** (Prefix style): grandfather `ACS*` vs `Acs*` (Option 3a),
  rename T18B (3b), or rename T17B (3c)?

Once arbitrated, the resolution lands as a small follow-up PR on
whichever branch the user picks — most likely T17B (T18B's mod.rs is
already touched and its decompose just landed).
