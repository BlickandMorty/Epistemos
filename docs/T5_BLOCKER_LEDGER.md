# T5 Blocker Ledger

State owner: T5 Primitive IR Stack.

Purpose: every blocker that gates Lean schema authority, certificate
alignment, proof obligations, or EML source custody gets a retry command,
cadence, last result, and resolution marker. Unresolved rows are retried
by cadence before selecting new work.

Current iteration baseline: iter-497.

| blocker_id | description | retry_command | retry_cadence | last_attempt_iter | last_result | resolved_at_iter |
|---|---|---|---|---|---|---|
| LEAN-TOOLCHAIN | `elan`, `lean`, and `lake` were missing before the iter-548 auto-install; explicit PATH to `~/.elan/bin` now locates Lean 4.16.0 and Lake 5.0.0. | `PATH="$HOME/.elan/bin:$PATH"; command -v elan && command -v lean && command -v lake` | every 10 iters | iter-548 | RESOLVED WITH EXPLICIT PATH: `elan=/Users/jojo/.elan/bin/elan`; `lean=/Users/jojo/.elan/bin/lean`; `lake=/Users/jojo/.elan/bin/lake`; `lean --version` returned Lean 4.16.0; `lake --version` returned Lake 5.0.0. Default shell PATH still omits `~/.elan/bin`. | iter-548 |
| LAKE-BUILD | `lake build` now runs with explicit `~/.elan/bin` PATH but fails on Lean project syntax. | `PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build 2>&1` | every 10 iters once `LEAN-TOOLCHAIN` resolves | iter-548 | FAILED: `lake update && lake build` exited 1 with `lakefile.lean:31:19: unexpected token '↦'; expected ']'`. |  |
| EML-LEAN-VENDOR | `tomdif/eml-lean` source is not vendored into the Lean project; gated on network/toolchain/vendor pass. | `test -d lean/Epistemos/eml-lean` | every 20 iters | iter-537 | FAILED: `test -d lean/Epistemos/eml-lean` exited 1; directory is still missing. |  |
| EML-IR-GAP | Initial prompt named `agent_core/src/research/eml_ir/` as empty, but doctrine maps EML-IR canonically to `agent_core/src/research/eml/`. | `ls agent_core/src/research/eml_ir/*.rs 2>/dev/null` | every 5 iters until investigation | iter-497 | NOT A GAP: `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §2.1 declares `agent_core/src/research/eml/` as the EML-IR crate/module, and §4.1 says the existing flat `eml/{grammar,operator,evaluator,ulp_oracle,gate}.rs` layout maps directly to the IR shape. Current code includes `agent_core/src/research/eml/certificate.rs` and `agent_core/src/research/mod.rs` exports `pub mod eml;`. Do not create a duplicate `eml_ir/` module unless doctrine changes. | iter-497 |

## Retry Notes

- `LEAN-TOOLCHAIN` retry command was also expanded at iter-497 with:
  `for tool in elan lean lake; do ...; done`
  and returned all three as `NOT_IN_PATH`.
- `LEAN-TOOLCHAIN` cadence retry at iter-507 again returned
  `elan=NOT_IN_PATH`, `lean=NOT_IN_PATH`, `lake=NOT_IN_PATH`, with
  combined retry exit code 1.
- `LEAN-TOOLCHAIN` cadence retry at iter-517 again returned
  `elan=NOT_IN_PATH`, `lean=NOT_IN_PATH`, `lake=NOT_IN_PATH`, with
  combined retry exit code 1.
- `LEAN-TOOLCHAIN` cadence retry at iter-527 again returned
  `elan=NOT_IN_PATH`, `lean=NOT_IN_PATH`, `lake=NOT_IN_PATH`, with
  combined retry exit code 1.
- `LEAN-TOOLCHAIN` cadence retry at iter-537 again returned
  `elan=NOT_IN_PATH`, `lean=NOT_IN_PATH`, `lake=NOT_IN_PATH`, with
  combined retry exit code 1.
- `LEAN-TOOLCHAIN` cadence retry at iter-547 again returned
  `elan=NOT_IN_PATH`, `lean=NOT_IN_PATH`, `lake=NOT_IN_PATH`, with
  combined retry exit code 1.
- `LEAN-TOOLCHAIN` auto-install attempt at iter-548 succeeded:
  `elan 4.2.1` installed under `/Users/jojo/.elan/bin`; with
  `PATH="$HOME/.elan/bin:$PATH"`, `lean --version` returned Lean
  4.16.0 and `lake --version` returned Lake 5.0.0. Default shell
  PATH still omits `/Users/jojo/.elan/bin`.
- `LAKE-BUILD` attempt at iter-548 used explicit `~/.elan/bin` PATH
  and failed before elaboration: `lakefile.lean:31:19: unexpected
  token '↦'; expected ']'`.
- `EML-LEAN-VENDOR` cadence retry at iter-517 returned
  `eml-lean=missing`; `test -d lean/Epistemos/eml-lean` exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-537 returned
  `eml-lean=missing`; `test -d lean/Epistemos/eml-lean` exited 1.
- `LAKE-BUILD` must not be described as passing until the command in
  the table runs successfully.
- `EML-IR-GAP` is resolved as a naming/canonicality clarification:
  EML-IR lives in `agent_core/src/research/eml/`; the branch name does
  not require a parallel `eml_ir/` directory.
