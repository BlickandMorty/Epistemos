# Epistemos V6.2 Laptop Manual Audit Checklist

VERDICT: GREEN_FOR_CURRENT_SLICE_NOT_RELEASE_READY

This ledger records the current laptop evidence for the non-compromise Helios route. It is not a final release sign-off. It proves that the current Epistemos build expresses the canon honestly, compiles on Jojo's laptop, and keeps unimplemented V6.1/V6.2 kernels classified as targets until real kernel files and M2 Pro falsifiers pass.

## Canon Posture

- Product naming: Epistemos product, Helios architecture.
- Hardware lock: Jojo's M2 Pro 16 GB is the shippability rig; M2 Max and workstation results are scale-validation only.
- Verified floor: `ac8c6d28` remains pinned.
- Runtime doctrine: attention is an interrupt, not a substrate.
- Tier doctrine: MAS is lean and bounded; Pro widens controlled runtime surfaces; Vault contains experimental runtime mutation and candidate research.

## Automated Evidence From This Pass

- PASS: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- PASS: `cargo test --manifest-path epistemos-research/Cargo.toml --features research`
- PASS: `cargo test --manifest-path agent_core/Cargo.toml`
- PASS: focused Swift shard covering `HELIOSInvariantSourceGuardTests`, `OverseerProtocolTests`, `HaloControllerTests`, `HaloEditorBridgeTests`, `ResonanceServiceTests`, `SovereignGateRequirementMatrixTests`, and `SovereignGateTests`.
- PASS: test-first Swift AnswerPacket attention-mode shard. The first run failed because Swift lacked the Rust-side static-fallback acknowledgement guard; the follow-up run passed after adding `requiresStaticFallbackAcknowledgement` and `acknowledgesStaticFallback`.
- PASS: agent-core mmap arena coverage includes page-aligned layout, mapped arena init, producer/consumer shared request state, two mappings sharing SSD-backed request state, full-ring detection, corrupt-header reset, and reopen-style persistence paths.

## Manual Computer Use Evidence From This Pass

- PASS: launched the freshly built `Epistemos.app` from DerivedData on this laptop.
- PASS: main window opened and rendered the landing surface.
- PASS: Settings opened from the live app.
- PASS: General diagnostics were visible, including Editor bundle, Halo backend, OpLog projection, agent events, graph events, projection snapshot, audit projection, and Cognitive DAG rows.
- PASS: Agent settings exposed consolidated Overview, Authority, Overseer, Spend, and Structures tabs.
- PASS: Overseer tab was visible as read-only routing audit: active on every main-chat turn, logic home `Epistemos/Engine/OverseerProtocol.swift`, no user controls, capped at 10 recent turns.
- PASS: HELIOS V5 settings were visible with Verified Research Mode, Connectome Browser, and Experimental Metal Kernels all default OFF.
- PASS: HELIOS compliance copy surfaced `ac8c6d28` and the App Review 2.5.2 default-off posture.

## Follow-on Evidence - 2026-05-07 00:52 CDT

- PASS: `Tools/metal-shader-compile/metal-shader-compile.sh` now contains `HELIOS-V6-TARGET-ONLY-KERNEL-GUARD` for `SemiseparableBlockScan.metal`, `LocalRecallIsland.metal`, `PageGather.metal`, `ControllerKernelPack.metal`, `PacketRouter1bit.metal`, and `InterruptScore.metal`.
- PASS: direct filesystem probe found none of those target-only filenames under the compiled shader roots `Epistemos/Shaders` or `agent_core/metal`.
- PASS: `Tools/metal-shader-compile/metal-shader-compile.sh` compiled the 19 real `.metal` shaders currently present in those roots.
- BLOCKED: a focused Xcode source-guard run could not reach the new target-only kernel guard because the current dirty Epdoc graph tests fail at compile time: they reference `EpdocDocument.graphModelContainer`, `EpdocDocument.projectAndPersistGraph(...)`, and `EpistemosDocumentController(modelContainer:)`, which production does not currently expose. This is a separate active-worktree blocker and prevents any honest "Xcode green" claim until reconciled.

## Feature Expression Matrix

| Research surface | Current expression | Current proof | Honest gap |
| --- | --- | --- | --- |
| Helios V5/V6.1/V6.2 canon | Research docs indexed; North Star addendum; Rust research constants; Swift source guards | `epistemos-research` tests and `HELIOSInvariantSourceGuardTests` | V6.1/V6.2 runtime kernels are not live yet |
| SCOPE-Rex | `agent_core/src/scope_rex` AnswerPacket, witnessed state, BTM semantic substrate, residency, KV direct, kernels | agent-core tests pass; Swift AnswerPacket now mirrors the static-fallback acknowledgement invariant | Full runtime UX is still partly routed through existing app surfaces |
| Halo | `HaloController`, `HaloEditorBridge`, Shadow panel/backend diagnostics | Swift Halo tests and General diagnostics row | Full manual editor-selection smoke remains a later runtime pass |
| ACS | Research module encodes ACS as Episodic plane plus Verification audit | `acs` tests and canonical consistency tests | Runtime page-coordinate teleport/gather falsifier still target-only |
| KV-Direct | Metal shader and Rust policy/fixtures express the auto-pointing-at-data route | agent-core tier1 W8 tests and `kv_direct_gate` research tests | Needs hardware benchmark and app-visible dispatch telemetry |
| Lattice / transform data | Babai, E8, Leech metadata, quantization budget, morph-field theorem surfaces | `lattice_budget` and theorem tests pass | Nested lattice remains fallback/secondary, not a shipped semantic spine |
| mmap SSD+RAM arena | File-backed mapped arena with shared two-mapping state | `arena_budget` tests pass | Needs Instruments/thermal trace under real app load |
| Resonance | Rust resonance seed and Swift `ResonanceService` | Rust resonance tests and Swift focused shard pass | Needs live contradiction/resonance UI smoke |
| Sovereign Gate | Destructive settings actions route through Sovereign Gate requirements | Swift Sovereign Gate tests and manual Settings inspection | App-wide destructive-surface sweep is not complete |
| Overseer | Overseer is retained as Controller/Verification-plane audit and route envelope | Swift tests and manual Settings inspection | Naming may be reframed later; deletion is not justified now |

## Kernel Truth Table

Five V6.1/V6.2 kernels remain target-only until real kernel files and M2 Pro falsifiers pass:

- `SemiseparableBlockScan.metal`
- `LocalRecallIsland.metal`
- `PageGather.metal`
- `ControllerKernelPack.metal`
- `PacketRouter1bit.metal`

`InterruptScore` remains Swift CPU canonical for V6.2; Metal is a shadow/batch optimization only after parity is proven.

## Next Required Passes

- M2 Pro PageGather baseline bandwidth harness.
- PageGather scatter/gather correctness and bandwidth ratio.
- ~~Swift CPU `InterruptScore` implementation~~ → **LANDED 2026-05-12**
  via `Epistemos/Engine/InterruptScoreCpu.swift` (V6.2 §1.4 Falsifier 6
  canonical Swift CPU path, weights α=0.30 β=0.25 γ=0.20 δ=0.15 ε=0.10,
  P99 latency test gating < 500 µs CI-budget against the 100 µs V6.2
  target). Three-bucket classifier matches V6.2 §1.5 thresholds
  (LOW < 0.25, MED < 0.65, HIGH ≥ 0.65). Pending: runtime population
  into emitted AnswerPackets at the StreamingDelegate seam.
- Runtime population of `attention_mode` (and `InterruptScore` bucket)
  into emitted AnswerPackets.
- PacketRouter1bit dispatch budget and quality-loss falsifier.
- ControllerKernelPack baseline equivalence.
- SemiseparableBlockScan reference match.
- LocalRecallIsland 32K 50-by-5 passkey harness.
- Manual live note/editor/Halo selection smoke with logs.
- Manual model-routing prompt with logs showing `attention_mode` / static fallback truthfulness.
