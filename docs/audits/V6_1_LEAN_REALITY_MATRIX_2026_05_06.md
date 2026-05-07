---
state: audit
created_on: 2026-05-06
scope: Epistemos V6.1 lean-canon implementation reality matrix
verdict: GREEN_FOR_THIS_SLICE_NOT_RELEASE_READY
---

# V6.1 Lean Reality Matrix - 2026-05-06

This ledger records what is actually proven in the current Epistemos
worktree after the V6.1 attention-as-interrupt audit pass. It exists to
prevent a subtle but dangerous drift: treating canonical target language
as if it were already hardware-proven implementation.

The north star is now pinned in code and doctrine:

> Epistemos is not an AI app. It is a cognitive substrate that
> occasionally summons AI as a precision instrument.
>
> The model is a guest in the user's brain - not a tenant of the user's
> machine.

The current slice is green for the surfaces below. It is not a final
release sign-off because runtime/manual app checks, distribution review,
sanitizer passes, and three no-change zero-fail release passes have not
been completed.

## Verified In Code And Tests

| Surface | Evidence | Result | Nuance |
|---|---|---:|---|
| AnswerPacket attention mode | `agent_core/src/scope_rex/answer_packet.rs`; `Epistemos/Models/AnswerPacket.swift`; W1 falsifier | PASS | `attention_mode` is present in Rust and Swift as `dynamic`, `static_fallback`, or `unavailable`. Default is `unavailable`. |
| Static 9:1 fallback honesty | `ClaimKind::StaticFallbackAcknowledged`; AnswerPacket helpers; doctrine linter gate 6.1 | PASS | Static fallback must be acknowledged. A fallback emission without the acknowledgement claim is invalid by helper and source-lint contract. |
| Goodfire VPD precision | `epistemos-research/src/goodfire_vpd_specs.rs`; canonical consistency tests | PASS | Internal math is `205 / 9972`, while user-facing/canonical presentation is `2.1%`. Comments and labels must not fight the rounded canon. |
| V6.1 five-plane discipline | `epistemos-research/src/v6_1_stream_surface.rs`; `v6_1_execution_policy.rs`; canonical consistency tests | PASS | Streams are product lanes. Planes are runtime structure. The tests preserve all 15 stream-plane cells. |
| ACS plane placement | `epistemos-research/src/acs.rs` | PASS | ACS lives in the Episodic plane and is audited in the Verification plane. |
| MAS / Pro / Vault execution policy | `epistemos-research/src/v6_1_execution_policy.rs` | PASS | MAS uses interrupt-first policy with static 9:1 fallback only when dynamic signals are unavailable. Pro enables full interrupt scoring plus LocalRecallIsland policy. Vault adds PacketRouter1bit and experimental ConnectomeAlarm policy. |
| Kernel canon posture | `epistemos-research/src/m2_max_kernels.rs` | PASS | The V6.1 five kernels are recorded as doctrine targets, not implementation claims. |
| LocalAgent membrane | `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift`; `agent_core/src/agent_runtime/prompt_format.rs` | PASS | External/provider/tool orchestration is a membrane. Local deterministic substrate answers must not add a gateway hop when no external context is needed. |
| Source mirror coverage | `Epistemos.xcodeproj/project.pbxproj`; HELIOS source guards | PASS | The app test bundle now mirrors doctrine, research, vault, shadow, and Lean source files, including `.lean` and `lean-toolchain`. |
| Lean theorem budget | `Tools/sorry-budget/sorry-budget.sh --report` | PASS | Current budget is 37 total sorries. This is not "100% theorem proven"; it is an explicit, bounded Lean proof debt ledger. |
| SSD/RAM mmap substrate | `agent_core/src/arena/mod.rs`; `agent_core/tests/arena_budget.rs` | PASS | A real temp-file-backed `MAP_SHARED` arena is opened twice. Producer writes and flushes, consumer reads and consumes, producer observes tail update, and a reopened mapping preserves header state. |
| Current real Metal shaders | `Tools/metal-shader-compile/metal-shader-compile.sh` | PASS | 19 existing `.metal` files compile with `xcrun -sdk macosx metal -std=metal3.1`. |
| W25 theorem/falsifier runner | `Tools/falsifier/falsifier.sh` | PASS | All registered W25 protocols pass. This is a stage-0 protocol pass, not a substitute for every V6.1 hardware falsifier. |
| Swift warning cleanup | `EpistemosSpeechAnalyzer.swift`; `AppBootstrap.swift`; Epdoc, MLX thermal, and agent harness tests | PASS | The prior warning inventory was retired. The full post-cleanup macOS suite passed after stabilizing a notification timing assertion. |

## Verification Commands Run

| Command | Result |
|---|---:|
| `cargo test --manifest-path agent_core/Cargo.toml` | PASS: 985 lib tests plus binary, integration, and doc-test suites. |
| `cargo test --manifest-path epistemos-research/Cargo.toml --features research` | PASS: 464 lib tests, 97 canonical consistency tests, doc tests. |
| `Tools/metal-shader-compile/metal-shader-compile.sh` | PASS: 19 Metal shaders compile. |
| `Tools/sorry-budget/sorry-budget.sh --report` | PASS: 37 total sorries. |
| `Tools/falsifier/falsifier.sh` | PASS: W25 all protocols. |
| `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` | PASS. |
| `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SearchFusionHealthRowTests` | PASS: focused regression check after notification-counter stabilization. |
| `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test` | PASS: 254.086 second post-cleanup full test run. |
| `cd graph-engine && cargo test` | PASS: 2522 passed, 8 ignored, doc tests. |
| `cd omega-mcp && cargo test` | PASS: 143 passed, doc test ignored. |
| `cd omega-ax && cargo test` | PASS: 12 passed. |
| `cd epistemos-vault && cargo test --features vault` | PASS: 15 passed, doc tests. |
| `git diff --check` | PASS. |

## Current Warning Inventory

The prior Swift warning inventory has been retired in this slice:

- `EpistemosSpeechAnalyzer.swift`: converter state is isolated behind a small locked `@unchecked Sendable` helper.
- `AppBootstrap.swift`: the redundant `await` was removed.
- `EpdocEndToEndSmokeTests.swift`: unnecessary `try` expressions were removed.
- `MLXThermalBenchTests.swift`: intentionally discarded benchmark results are now explicit.
- `AgentHarnessTests.swift`: deprecated string loading was replaced with the encoding-aware initializer.

The only observed Xcode chatter in the latest quiet build/test output is
the standard "multiple matching destinations" destination selection
warning and run-script phase notes. Keep watching non-quiet logs during
the release audit; this is not a substitute for manual/runtime log review.

## Proxy Passes Versus Hardware Proof

| Claim area | Current status | Why it is not enough yet |
|---|---|---|
| V6.1 `SemiseparableBlockScan.metal` | Target only | Existing Mamba2 shaders compile, but no canonical `SemiseparableBlockScan.metal` file is implemented and bit-exact checked against `cartesia-metal`. |
| `LocalRecallIsland.metal` | Target only | Policy is encoded. The actual passkey recall >= 0.99 at 128K is not yet hardware-run. |
| `PageGather.metal` | Target only | No M2 Max gather benchmark proves >= 70% memory bandwidth utilization yet. |
| `ControllerKernelPack.metal` | Target only | No fused controller pack exists with 1 ULP equivalence proof yet. |
| `PacketRouter1bit.metal` | Target only | Vault policy is encoded. No implemented canonical kernel has proven routing-quality loss <= 2% versus FP16 reference. |
| `InterruptScore.metal` | Target only | The interrupt equation exists in research code. The always-on Metal kernel is not implemented yet. |
| T35 at 128K | Not hardware-proven | `rho_max = 0.20` is encoded. Real RULER/passkey long-context runs are still required. |
| T42 ConnectomeAlarm | Research/Vault target | Goodfire atlas status is public-confirmed for observability, but runtime prediction of interrupt traces remains unproven. |
| Donor-distilled student | Not trained | The Qwen3-8B to Granite-4-H-shape route is canonical. No student checkpoint exists in this repo yet. |

## Next Gates Before New-Repo V1

1. Add real hardware falsifier harnesses for the V6.1 target kernels before claiming kernel completion.
2. Implement `InterruptScore.metal` only after the CPU/reference interrupt-score contract is wired into AnswerPacket emission.
3. Add a runtime/manual app audit with logs for model routing, fallback behavior, note AI, Omega/research, and settings copy.
4. Run sanitizer passes when feasible.
5. Run the release-audit recursive zero-fail rule only after code changes pause.

## Bottom Line

The current Epistemos build is materially more canonical and lean after
this pass: the audit substrate now records whether attention was dynamic,
static fallback, or unavailable; static fallback is no longer silent;
Goodfire precision no longer fights the 2.1% canon; ACS and the tier/plane
rules are executable tests; mmap has a real SSD-backed producer/consumer
proof; and the existing Metal shaders compile.

The V6.1 five-kernel substrate is still a target, not a finished hardware
claim. That honesty is part of the architecture. The floor never moves,
and the proof ledger should never pretend it did.

## V6.2 Intake Link - 2026-05-07

The follow-on V6.2 research has been saved and indexed at
`docs/fusion/EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md`.

The important update is not a product rename. It is a verification
envelope correction: Jojo's M2 Pro 16GB is now the shippability rig, and
M2 Max / workstation-class targets are scale-validation or Pro/Vault
only. V6.2 preserves the V6.1 architecture while budget-revising the
hardware falsifiers:

- PageGather must pass against 70% of measured `BW_baseline_M2Pro`, not
  against theoretical M2 Max bandwidth.
- LocalRecallIsland Core is 32K, 50 trials x 5 depths; 128K is Stretch.
- SemiseparableBlockScan Core is L=32768; L=131072 is Stretch.
- InterruptScore is Swift CPU canonical for the single-token path; Metal
  remains a batch shadow only.
- Goodfire VPD activity subnumbers were revalidated by Codex on the live
  public page during intake, while runtime acceleration remains candidate.
