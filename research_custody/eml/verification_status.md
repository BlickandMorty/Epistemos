# EML-IR — Source Custody Verification Status

**Created:** 2026-05-17 (T5 Phase A iter-4 skeleton).
**Authority:** §4.I:898-900 of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`.
**Doctrine cross-link:** `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.1.
**Audit cross-link:** `docs/audits/EML_IR_AUDIT_2026_05_17.md` §7.

## Primary sources

| Source | Vendoring status | Hash status | Lean-cert status |
|---|---|---|---|
| Odrzywołek arXiv:2603.21852 — Liouvillian-elementary universality of `eml(x, y) = exp(x) − ln(y)` | not vendored (iter-5+) | pending | pending (Phase C) |
| Stachowiak arXiv:2604.23893 — abelian-group + functional-inverse decomposition | not vendored (iter-5+) | pending | pending (Phase C) |
| Carney, "Inexpressibility in Exp-Minus-Log", arXiv:2605.01636 | **cited** at `agent_core/src/research/eml/mod.rs` header (iter-9 closure) | pending vendor pass | pending (Phase C) |
| Smith quintic counter-construction (universality fence) | doctrinal note `agent_core/src/research/eml/mod.rs:42-46` | n/a | n/a |
| `tomdif/eml-lean` (vendored Lean proofs, claims 0-sorry) | **deferred** per `eml/mod.rs:23-25` — needs Lean toolchain + network | n/a | Phase C |

## Verification gates

- **F-ULP-Oracle** — implemented in `agent_core/src/research/eml/ulp_oracle.rs` (substrate-floor smoke run); production 412k+2048-point fixture deferred to OxiEML vendoring per `eml/mod.rs:20-22`. Status: **smoke passing**, full fixture **pending**.
- **AnswerPacket schema-freeze gate** — `eml/gate.rs::check_answer_packet_freeze_allowed`. Status: **smoke passing** (substrate-floor proxy for full fixture).

## Open items

- Resolve Carney citation (Phase B1 entry slice).
- Vendor `cool-japan/oxieml` per Wave J B.0.1 (manual setup pass).
- Vendor `tomdif/eml-lean` per Wave J B.0.2 (manual setup pass).
- Verify Lean 4.29.1 toolchain pin against mathlib4 per Wave J B.0.5.
