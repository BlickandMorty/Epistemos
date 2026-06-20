# NEW MODEL + 70B — THEORETICAL RESEARCH, PRESERVED & AVAILABLE TO BUILD (NOT in the app) (2026-06-20)

Owner: *"Make sure the 70B and new model are SAVED — just not in the app. It should be theoretical research for now and
definitely available to build. Add it to the lattice explainer / living index and all the other places."* This doc
PRESERVES that research as theoretical + build-ready, so nothing is lost. NONE of this ships in the app now; it all stays
behind the `LocalModelHandoff` seam with `AnswerPacket.attention_mode = static_fallback/unavailable`, never advertised.
Authority for the math/falsifiers stays the lattice-coordinate-explainer + Living Index (write-plans only — not edited here).

## C1 — M0 interrupt experiment ("the gate that unblocks the new model")
- **What:** falsifier `F-Interrupt-Moves-Loss` — proves a per-token "interrupt" gate (cheap SSM → brief full-attention when
  confused) actually moves loss at toy scale. Backbone = a vanilla state-tracking-WEAK linear SSM (~2 layers, d_model 64-128,
  pure-Rust f64, deterministic seed) — explicitly NOT Mamba-3. 3 arms (always-SSM / always-attention / interrupt-gated +
  random-gate ablation); 4 axes (moves-loss / beats-random / AUROC≥0.85 / efficient: recovery≥0.5 at fire-rate≤0.25);
  output `artifacts/falsifiers/interrupt_moves_loss/result.json`. (CHECKPOINT §6, READOUT §8.3.)
- **Status:** harness SCAFFOLD built + tested — `agent_core/src/research/m0_interrupt_harness.rs` (typed schema + pinned
  thresholds + pure `evaluate_axes`/`overall_pass`/`from_measurements`, 6 tests pass under `--features research`; commits
  `da8475dff` + `67b20dcaf` + `3033d5674`). NO experiment driver yet (no toy-SSM, no gate, no token gen).
- **Build gate (when owner green-lights):** lift the `docs_first` hold (Q10b) → implement
  `agent_core/src/bin/falsify_interrupt_moves_loss.rs` reusing the scaffold's `evaluate_axes` +
  `research::interrupt_calibration::auc_roc`. CPU-only Rust binary, feature `research`, Pro/research scope (not MAS).

## C2 — Spine decision (DEFERRED, not an M0 blocker)
- M0 uses the vanilla SSM; Mamba-3 lands later at "B3" (`SelectiveScan.metal` bit-exact vs a Mamba-2 PyTorch ref). The open
  owner choice is **Mamba-3 vs a B'MOJO-style SSM+sliding-window-attention hybrid** for the production spine. Needed only
  before B3; NOT before M0. (READOUT §8.2/§8.4, CHECKPOINT §8.)

## C3 — Gemini "Local 70B Cocktail" blueprint + evaluation (T0 external, deduped)
- **What:** external Gemini blueprint to run a 70B-class model on a 16GB Mac via the app-as-Residency-Governor — three
  sparsities (activation / MoE-weight / decoupled-Engram), State+Episodic+Lookup planes, ReLU²/SpQt sparse decode,
  DeepSeek-Engram/MoLKV O(1) lookup, metriplectic interrupt gating, UAS zero-copy, a 6-week kernel-first plan. (BLUEPRINT.)
- **Status:** T0 UNVERIFIED external input, non-authority. The EVALUATION deduped every claim vs the live repo: most cores
  already exist (InterruptScore, attention-sinks, active_assembly, Helios/ColdStream residency, UAS + `F-UAS-CopyCount`
  falsified, packet-router + Metal kernel, Engram type-surface). Genuinely-new + beneficial: pre-attention prefetch,
  sliding-window cache, row-col bundling (all T1 → already pulled into the model-agnostic substrate, see BUILD_SEQUENCE);
  MoLKV/Engram-real, ReLU² spine, SpQt zigzag (T0, stay deferred). Honesty corrections: no "GPT 6.md"/SpQt warning doc
  exists; the "SpQt" name is unverified (SpQR-adjacent) — verify before any build. (EVAL §1-2.)
- **Build gate:** the blueprint's Week-1-kernels-first order is RE-ORDERED behind M0/M1 (kernels → B3); nothing dropped.
  Pending owner: verify DeepSeek Engram/MoLKV sources, confirm the real "SpQt" name.

## The 4 owner decisions before a full M0/new-model build (all still pending)
1. Lift the `docs_first` hold (green-light the M0 experiment driver). 2. B3 spine: Mamba-3 vs B'MOJO (after M0). 3. Confirm
build env (`cargo --manifest-path agent_core/Cargo.toml` from `/Users/jojo/Downloads/Epistemos/`). 4. M0 scope = Pro/research
CPU-only Rust falsifier binary, feature `research`, not MAS. (READOUT §8.4/§8.7, CHECKPOINT §8.)

## Availability + provenance (so it's "available to build" later)
All of C1-C3 is preserved in: this doc; Cursor's `docs/fusion/*` (SESSION_CHECKPOINT, ARCHITECTURE_READOUT §8, RESEARCH_LOOP_LEDGER
PASS-1..22, RESEARCH_INTENT_AND_QUERY_LOG Q1-Q38, GEMINI_70B_COCKTAIL_BLUEPRINT/EVALUATION); the built scaffold
`m0_interrupt_harness.rs`; the ~50-falsifier index. The math/theorem authority stays the lattice-coordinate-explainer
(`docs/june 1/artifacts/lattice-coordinate-explainer/index.html`) + the Living Index — both authority, write-plans only, not
edited. When the owner green-lights, the build path is: lift docs_first → M0 driver → (M1) → spine commit (B3) → kernels.
This research is NOT a loop build item — it is theoretical/available; the loop builds only the model-agnostic substrate.
Cross-ref SUBSTRATE_BUILD_SEQUENCE (EXCLUDED list), SUBSTRATE_RESEARCH_BUNDLE, SS-SUB.
