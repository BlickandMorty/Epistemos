---
state: namespace-decision
created_on: 2026-05-23
authored_by: Terminal 2 (Rust substrate hardening) — R6
purpose: Pin the relationship + non-rename decision for `agent_core::research::eml_ir` vs `agent_core::research::fulp_oracle`. The two modules share several type names (`FulpEvaluator`, `FulpOracleError`, `FulpRunConfig`, `OperationStats`, `WorstCase`, `ULP_TOLERANCE_FP16`, `reference_value`, `run_fulp_oracle`, `Fp16Bits`, `Fp16Class`, `FulpWitness`, `acceptance_witness_json`, `replay_witness_json`) but serve different production roles.
authority: this doc is the canonical reference for any future "should we merge / rename these?" question.
---

# T12 EML-IR vs F-ULP-Oracle namespace — non-rename decision

## §1. The question

`agent_core/src/research/` contains two modules whose public surfaces overlap by name:

- `agent_core::research::fulp_oracle::*`
- `agent_core::research::eml_ir::*`

Both expose `Fp16Bits`, `Fp16Class`, `FulpEvaluator`, `FulpOperation`, `FulpOracleError`, `FulpRunConfig`, `OperationStats`, `WorstCase`, `ULP_TOLERANCE_FP16`, `reference_value`, `run_fulp_oracle`, `FulpWitness`, `acceptance_witness_json`, and `replay_witness_json`. The names are NOT type-identical (Rust module paths disambiguate), but the surface duplication asks for a verdict: rename, merge, or keep both?

## §2. Downstream blast radius (audit, 2026-05-23)

`grep -rln '::fulp_oracle\|research::fulp_oracle'` — **1 external caller**:

- `agent_core/src/bridge.rs:3636` — `fulp_oracle_acceptance_witness_json` FFI body calls `crate::research::fulp_oracle::acceptance_witness_json()`. This is the production FFI Swift's `FUlpHealthRow` decodes.

`grep -rln '::eml_ir\|research::eml_ir'` — **0 external callers**. Only self-references inside `eml_ir/oracle.rs` and `eml_ir/witness.rs`. Heavy doc cross-references from:

- `docs/falsifiers/F_ULP_ORACLE_2026_05_18.md` — explicitly names `agent_core/src/research/eml_ir/` + `Epistemos/Shaders/morph_eval_reduced.metal`. Pinned by an in-source test (`fn falsifier_doc_points_at_eml_ir_lane_and_shader` in `agent_core/src/research/eml_ir/mod.rs`).
- Sibling IR cert modules: `info_ir/certificate.rs`, `scan_ir/certificate.rs`, `tropical_ir/certificate.rs` — each references the EML-IR sibling for cross-IR consistency comments.
- `agent_core/src/research/eml_integration/mod.rs` and `agent_core/src/research/eml/ulp_oracle.rs` — T5/T7 lanes that reference the shared morph shader.

## §3. Why both exist (distinct roles)

### `fulp_oracle` — production F-ULP gate

- Substrate floor for the F-ULP-Oracle falsifier (`acceptance_witness_json` returns a JSON `FulpWitness` for the Settings → Diagnostics `FUlpHealthRow`).
- Targets `Epistemos/Shaders/fulp_oracle.metal` (the OLDER fp16 oracle kernel; one operation per kernel).
- Sources: `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T12 + `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.1.
- Grid shape: stratified (412 000 pts) + adversarial (2 048 pts) over `[0.5, 2]`.

### `eml_ir` — T12 EML-IR research substrate

- Research-only layer for the EML-IR arithmetic floor used by the T12 substrate work + cross-IR sibling tests (Scan-IR, Tropical-IR, Info-IR).
- Targets `Epistemos/Shaders/morph_eval_reduced.metal` (the NEWER combined oracle kernel — `morphOracleFp16` emits exp / ln / eml outputs from one launch).
- Sources: `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T12 + `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5 + `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` rows B2-B3.
- Fixture shape: log-sampled (matches `LOG_SAMPLED_POINT_COUNT`) + adversarial + stress axes — additional fixture machinery on top of the base oracle.

Both modules are real and serve different consumers. `eml_ir` is the **research lane's** F-ULP machinery layered atop the same fp16 acceptance semantics; `fulp_oracle` is the **production lane's** F-ULP gate that the user-visible Diagnostics row reads.

## §4. Decision: KEEP BOTH, DO NOT RENAME

### Decision

1. **Do not rename `fulp_oracle`.** Renaming breaks `bridge.rs:3636` (the FFI Swift consumes), the Swift `FUlpHealthRow` mirror, and any doc that names `fulp_oracle::acceptance_witness_json`.
2. **Do not rename `eml_ir`.** Renaming breaks the in-source falsifier-doc cross-link test (`eml_ir/mod.rs:81`) and every sibling IR doc comment (`scan_ir`, `tropical_ir`, `info_ir`, `eml`, `eml_integration`).
3. **Do not merge.** Their grid shapes (stratified-vs-log-sampled fixtures), shader targets (`fulp_oracle.metal` vs `morph_eval_reduced.metal`), and downstream consumers (production FFI vs research substrate) are independent. A merge would either pessimize one consumer or require versioned surfaces, which is more cost than the readability gain.

### Naming-clarity action (this PR)

Add a one-line cross-reference to each module's header doc-comment naming the sibling and pointing at this decision doc. Future readers see the relationship without having to grep.

### Re-litigation trigger

Re-open this decision **only** when one of:

- The bridge FFI changes consumer (Swift switches from `fulp_oracle` to `eml_ir`).
- The morph shader fully subsumes the `fulp_oracle.metal` kernel and the older shader is deleted.
- Both modules are confirmed redundant by external research direction (would need a separate audit + doctrine update).

## §5. What this PR changes

- Adds `docs/audits/T12_EML_IR_VS_FULP_ORACLE_DECISION_2026_05_23.md` (this file).
- Adds a 2-line cross-reference to `agent_core/src/research/fulp_oracle/mod.rs` and `agent_core/src/research/eml_ir/mod.rs` pointing at this doc.

No `pub` surface changes. No FFI changes. No Swift impact. Cross-IR sibling tests + falsifier doc references unaffected.

## §6. Cross-references

- `agent_core/src/bridge.rs` — production FFI (`fulp_oracle_acceptance_witness_json`)
- `agent_core/src/research/fulp_oracle/mod.rs` — production F-ULP gate
- `agent_core/src/research/eml_ir/mod.rs` — T12 EML-IR research substrate
- `agent_core/src/research/eml/mod.rs` — T5 EML primitive lane (separate)
- `agent_core/src/research/eml_integration/mod.rs` — T7 EML observatory lane (separate)
- `docs/falsifiers/F_ULP_ORACLE_2026_05_18.md` — falsifier doctrine
- `Epistemos/Shaders/fulp_oracle.metal` — older single-op fp16 oracle kernel
- `Epistemos/Shaders/morph_eval_reduced.metal` — newer combined exp/ln/eml fp16 oracle kernel
