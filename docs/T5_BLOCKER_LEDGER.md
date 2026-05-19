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
| LAKE-BUILD | `lake build` runs with explicit `~/.elan/bin` PATH after the iter-581 Tropical schema repair and iter-592 zero-sorry E1 pass. | `PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build 2>&1` | every 10 iters once `LEAN-TOOLCHAIN` resolves | iter-733 | RESOLVED: cadence retry at iter-733 ran full `lake build`, printed `Build completed successfully.`, and exited 0 after the iter-724 through iter-732 schema-status and witness passes. | iter-582 |
| EML-LEAN-VENDOR | `tomdif/eml-lean` source is not vendored into the Lean project; gated on network/toolchain/vendor pass. | `test -d lean/Epistemos/eml-lean` | every 20 iters | iter-719 | FAILED: `test -d lean/Epistemos/eml-lean` returned `eml-lean=missing exit=1`; directory is still missing. |  |
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
- `LAKE-BUILD` attempt at iter-549 fixed the lakefile option syntax
  to Lean 4.16-compatible `⟨option, value⟩` entries and progressed
  into dependency/build work. The run then reported two blockers:
  mathlib cache fetch failed with a local dyld `__DATA_CONST` segment
  warning, and `Epistemos/E1.lean` has a bad import because
  `Mathlib.Topology.Algebra.StoneWeierstrass.lean` is absent from the
  pinned mathlib checkout. The source build was interrupted after this
  actionable import failure to avoid spending minutes compiling the
  rest of mathlib.
- `LAKE-BUILD` attempt at iter-550 changed E1 to import the pinned
  mathlib path `Mathlib.Topology.ContinuousMap.StoneWeierstrass` and
  added `Mathlib.Data.Complex.Basic` for the `ℂ` notation. Narrow
  `lake build Epistemos.E1` completed successfully and left only the
  existing E1 `sorry` warning. Full `lake build` was attempted next;
  because mathlib cache fetch still trips the local dyld
  `__DATA_CONST` warning, the command source-built dependencies and
  was interrupted after reaching about 1758/6040 modules with no new
  project error surfaced.
- `LAKE-BUILD` cadence retry at iter-560 ran the table command with
  explicit `~/.elan/bin` PATH. The source build advanced from the
  previous 1758-module boundary to about 2717/6040 modules before
  the bounded pass was interrupted; no new project error surfaced.
- `LAKE-BUILD` cadence retry at iter-570 ran the table command with
  explicit `~/.elan/bin` PATH. The source build advanced from the
  previous 2717-module boundary to about 3055/6040 modules before
  the bounded pass was interrupted; no new project error surfaced.
- `LAKE-BUILD` cadence retry at iter-580 ran the table command with
  explicit `~/.elan/bin` PATH. It source-built Mathlib through
  `[6032/6040]`, built `Epistemos.Scan`, `Epistemos.EML`,
  `Epistemos.Operator`, `Epistemos.Info`, and `Epistemos.Geometry`,
  then failed in `Epistemos.Tropical` with unsafe `Real.instRepr`,
  unknown `_root_.max`, missing executable `DecidableEq Expr`, and
  invalid nested `mutual` syntax.
- `LAKE-BUILD` retry at iter-582 ran after the iter-581
  `Epistemos.Tropical` repair. It replayed `Epistemos.E1` with the
  known tracked `sorry` warning, built `Epistemos`, printed
  `Build completed successfully.`, and exited 0.
- `LAKE-BUILD` retry at iter-593 ran after the iter-592 E1
  generator-completeness closure. `Tools/sorry-budget/sorry-budget.sh`
  reported `0 total sorries`, and full `lake build` built `Epistemos`,
  printed `Build completed successfully.`, and exited 0.
- `LAKE-BUILD` cadence retry at iter-603 ran with explicit
  `~/.elan/bin` PATH. `Tools/sorry-budget/sorry-budget.sh` reported
  `0 total sorries`, and full `lake build` printed
  `Build completed successfully.` and exited 0.
- `LAKE-BUILD` cadence retry at iter-613 ran with explicit
  `~/.elan/bin` PATH after the Scan and EML witness-schema additions.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-623 ran with explicit
  `~/.elan/bin` PATH after the iter-614 through iter-622
  certificate/schema alignment commits. `Tools/sorry-budget/sorry-budget.sh`
  reported `0 total sorries`, and full `lake build` printed
  `Build completed successfully.` and exited 0.
- `LAKE-BUILD` cadence retry at iter-633 ran with explicit
  `~/.elan/bin` PATH after the H1 top-level import and iter-624
  through iter-631 certificate alignment commits.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-643 ran with explicit
  `~/.elan/bin` PATH after the H4-H8 top-level imports.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-653 ran with explicit
  `~/.elan/bin` PATH after all H1-H17 stubs were imported into the
  aggregate library.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-663 ran with explicit
  `~/.elan/bin` PATH after the PCF-2 through PCF-9 aggregate imports.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-673 ran with explicit
  `~/.elan/bin` PATH after the PCF-10 import and H1-H7 proof-obligation
  sharpening passes.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-683 ran with explicit
  `~/.elan/bin` PATH after the E4/E5/E6 proof-obligation sharpening
  passes and the module-wide True-placeholder guard.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-693 ran with explicit
  `~/.elan/bin` PATH after the PCF-4 through PCF-10 implication/count
  passes plus the H13 and H17 sharpening passes.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-703 ran with explicit
  `~/.elan/bin` PATH after the Tropical, Info, Scan, Operator, and
  Geometry schema obligation-sharpening passes plus the Prop-True guard.
  `Tools/sorry-budget/sorry-budget.sh` reported `0 total sorries`,
  and full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-713 ran with explicit
  `~/.elan/bin` PATH after the Tropical, Info, Scan, Operator,
  Geometry, and EML certificate-header alignment passes.
  Full `lake build` printed `Build completed successfully.` and
  exited 0.
- `LAKE-BUILD` cadence retry at iter-723 ran with explicit
  `~/.elan/bin` PATH after the PCF-4, E7, E1, and H14 witness
  sharpening passes plus the Tropical, Scan, and Operator schema-status
  refreshes. Full `lake build` printed `Build completed successfully.`
  and exited 0.
- `LAKE-BUILD` cadence retry at iter-733 ran with explicit
  `~/.elan/bin` PATH after the Info, Geometry, and EML schema-status
  refreshes plus H13, H10, H15, and PCF-6 witness-sharpening passes.
  Full `lake build` printed `Build completed successfully.` and
  exited 0.
- `EML-LEAN-VENDOR` cadence retry at iter-517 returned
  `eml-lean=missing`; `test -d lean/Epistemos/eml-lean` exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-537 returned
  `eml-lean=missing`; `test -d lean/Epistemos/eml-lean` exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-557 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-577 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-597 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-617 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-637 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-657 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-679 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-699 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `EML-LEAN-VENDOR` cadence retry at iter-719 returned
  `eml-lean=missing exit=1`; `test -d lean/Epistemos/eml-lean`
  exited 1.
- `LAKE-BUILD` must not be described as passing until the command in
  the table runs successfully.
- `EML-IR-GAP` is resolved as a naming/canonicality clarification:
  EML-IR lives in `agent_core/src/research/eml/`; the branch name does
  not require a parallel `eml_ir/` directory.
