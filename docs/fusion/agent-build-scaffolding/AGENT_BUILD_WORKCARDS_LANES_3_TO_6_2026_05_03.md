# Agent Build Workcards — Lanes 3–6 — DRAFT — 2026-05-03

> **STATUS: DRAFT, NON-CANONICAL.** These cards are not approved for execution. They follow the template in `AGENT_BUILD_WORKCARDS_2026_05_01.md` and describe future-lane work the existing canonical workcards do not cover. Codex / user must approve each card before any agent picks it up. Until approved, do **not** copy these into the canonical workcards file or open a deliberation slice from them.
>
> Doctrine §7 lanes covered: Core killer-feature seed (Lane 3), Core/MAS symbol separation (Lane 2), Pro track (Lane 4), Research track (Lanes 5–6). Generated per `PARALLEL_WORK_MANIFEST.md` round-82 P4.

---

## How to read this draft

The current canonical `AGENT_BUILD_WORKCARDS_2026_05_01.md` covers cards 1–N for Lanes 1–2 (substrate spine + Core open queue). The cards below are the **next** executable slices once those lanes close, ordered roughly by build-graph dependency:

1. **L3-CARD-1** Resonance Gate τ + π + λ daemon seed (Rust)
2. **L3-CARD-2** Resonance Gate Swift consumer + UI shell
3. **L2-CARD-1** MAS / Core vs Pro capability symbol separation closure
4. **L4-CARD-1** Pro Developer ID + Notarization build configuration
5. **L4-CARD-2** Pro embedded JS runtime gate (QuickJS / Deno)
6. **L5-CARD-1** Research private framework loader gate (`AppleNeuralEngine.framework`)
7. **L5-CARD-2** Research direct ANE path via `_ANEClient`
8. **L6-CARD-1** Sherry 1.25-bit ternary weight format scaffolding

Each card is self-contained and can be opened independently **except** where "Dependencies" names a prerequisite. Do not chain cards — open one slice at a time per the doctrine §7 build-order graph.

---

## L3-CARD-1 — Resonance Gate τ + π + λ daemon seed (Rust)

### Goal

Land the first runnable τ (truth, Kleene K3 ternary) + π (prime/composite/gap) + λ (residency target) daemon module in `agent_core/src/resonance/`, CPU-only, callable from Swift via UniFFI. This is the first piece of the visible Resonance Gate philosophy.

### Tier

**Core** — the τ+π+λ subset is doctrine §4.1's Core entry. δ + ρ are Pro; κ + η are Research. Do **not** scaffold neural δ or κ in this card.

### Dependencies

- None (Lane 1 substrate + Lane 2 Core open are sufficient prerequisites).
- Does **not** depend on Pro entitlement bundle (CPU-only).

### Authority To Read First

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §3.1 (Resonance Gate)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.1 + Annex A.2 (T0–T2 ladder)
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/epistemos_resonance_gate.md` (donor research; not authority)
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/ternary_spectral_architecture.md` (donor research; Kleene K3 enum reference)
- `agent_core/src/lib.rs` for module registration pattern
- `agent_core/src/oplog.rs` for the existing single-binary-in-process pattern to mirror

### Allowed Write Set

- `agent_core/src/resonance/mod.rs` (NEW)
- `agent_core/src/resonance/tau.rs` (NEW — Kleene K3 truth value enum + computation per claim type)
- `agent_core/src/resonance/pi.rs` (NEW — prime / composite / gap classification over the 9 claim types)
- `agent_core/src/resonance/lambda.rs` (NEW — residency target L0–L3 mapping per Annex A.3)
- `agent_core/tests/resonance_seed.rs` (NEW)
- (FFI surface, narrow) `agent_core/src/bridge.rs` add `compute_resonance_signature(claim_json: String) -> String` only after the in-Rust seed passes its own tests

### Forbidden Write Set

- `agent_core/src/sovereign/` (separate killer feature)
- `agent_core/src/agent_loop.rs` (do not wire signature emission yet — that's a follow-up card)
- Any δ, ρ, κ, η neural scaffolding (Pro / Research only; not in this card)
- Swift side files (separate L3-CARD-2)
- `Cargo.toml` (coordination-required — adding a new module does not require Cargo.toml change unless a new crate boundary is needed)
- Phase 5 / Phase 7 / Phase 4 bridge files (Codex provenance work)
- All canon-in-flight docs

### Implementation Contract

- `tau` returns `Truth::True | Truth::Unknown | Truth::False` per Kleene K3 — not a `bool`. The `Unknown` case is load-bearing per doctrine §4.1.
- `pi` operates over the 9 claim types from doctrine §4.1: `Equation, Inequality, Causal, Definition, Empirical, CodeInvariant, Prime, Composite, Gap`. Returns one of those three classes.
- `lambda` maps a (claim, signature subset) tuple to one of L0–L3 only (doctrine §A.3 — Core caps at L3).
- Hot path target per doctrine §4.1 is < 100 µs/token. **Do not** call Z3 / Kani / Lean inline (T2 ceiling per Annex A.2).
- The seed daemon is pure CPU — no Metal, no MLX, no ANE.

### Tests And Logs

- Red test: `agent_core/tests/resonance_seed.rs::tau_emits_kleene_three_value_truth_for_each_claim_type` should fail before τ is implemented.
- Focused test: `cargo test --manifest-path agent_core/Cargo.toml resonance` after each module lands.
- Property test: τ is monotonic with respect to evidence count for Empirical claims (more confirming evidence → never less True).
- Hot-path benchmark: `cargo bench --manifest-path agent_core/Cargo.toml resonance_seed_throughput` should report < 100 µs / signature on a 16 GiB host.
- Expected `/tmp/...log` names: `/tmp/epistemos-resonance-seed-<timestamp>.log`.

### Acceptance

- Three new Rust files exist with public API per the contract.
- `cargo test resonance` passes 100%.
- Hot-path benchmark meets the < 100 µs / signature target on the user's 16 GiB host.
- No Z3 / Kani / Lean / kissat calls in the resonance module's release path.
- No Metal / MLX / ANE imports in the resonance module.

### Stop Triggers

- The < 100 µs / signature target cannot be met without GPU dispatch — escalate; this is a doctrine §4.1 hard requirement, redesign before code.
- The τ enum requires a fourth value (e.g., paraconsistent "both") for an existing claim type — escalate to update doctrine before implementing.
- The π classification requires a tenth claim type — escalate to update doctrine before implementing.

### Completion Report

- Files changed
- `cargo test` output
- Benchmark log path
- WRV proof (Resonance signature Wired in Rust, Reachable from FFI when L3-CARD-1's bridge.rs row lands, Visible in the test output)
- Remaining risks
- Rollback (`git revert <hash>`; the slice is purely additive)

---

## L3-CARD-2 — Resonance Gate Swift consumer + UI shell

### Goal

Land the Swift consumer (`ResonanceService.swift`) + SwiftUI Previews-only UI chip (`Epistemos/Views/Resonance/ResonanceChip.swift`) that visualizes the τ + π + λ signature. No production wiring yet.

### Tier

**Core** — same tier as L3-CARD-1.

### Dependencies

- L3-CARD-1 must ship first OR the Swift side stubs the FFI behind `#if canImport(agent_coreFFI)` so the chip preview works without Rust available.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.1 (visual grammar)
- `Epistemos/Engine/MutationEnvelope.swift` for the @Observable pattern and Sendable guidance
- `Epistemos/Bridge/ToolTierBridge.swift` for the `canImport(agent_coreFFI)` pattern
- L3-CARD-1's completion report if shipped

### Allowed Write Set

- `Epistemos/Engine/ResonanceService.swift` (NEW — @Observable service, calls FFI when available, returns stub signatures otherwise)
- `Epistemos/Views/Resonance/ResonanceChip.swift` (NEW — SwiftUI Previews only; the 9 claim badges + 5 directional pills + 7-field Σ pip strip)
- `Epistemos/Views/Resonance/ResonanceLegendView.swift` (NEW — explanation surface for the user)
- `EpistemosTests/ResonanceServiceTests.swift` (NEW)

### Forbidden Write Set

- Any production view that would render `ResonanceChip` to actual users (next card)
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`
- Closed PR43 ClarifyPromptBridge files unless an approved future slice reopens them
- Canon-in-flight docs
- `Epistemos.xcodeproj/project.pbxproj` (coordination-required)

### Implementation Contract

- `ResonanceService` is `@Observable`, `nonisolated`, `Sendable`.
- The chip uses the existing `+1 / 0 / -1` ternary visual language already established for fleet artifacts.
- All chip rendering happens inside `#Preview` blocks; no parent view mounts it yet.

### Tests And Logs

- Focused test: `xcodebuild ... -only-testing:EpistemosTests/ResonanceServiceTests`.
- Preview snapshot: manual screenshot of each `#Preview`.

### Acceptance

- Service + chip + legend + tests exist.
- Tests pass when L3-CARD-1 is shipped; pass with stub data when L3-CARD-1 is not yet shipped.
- No parent view mounts the chip in production.

### Stop Triggers

- Visual grammar dispute (chip vs strip vs radial) — escalate to user for design taste before implementation.
- Service requires a non-`Sendable` type — escalate; the doctrine §2.2 invariants require Sendable for cross-actor surfaces.

### Completion Report

- Files changed
- Tests run
- Preview screenshots (saved under `/tmp/`)
- Remaining risks
- Rollback

---

## L2-CARD-1 — MAS / Core vs Pro capability symbol separation closure

### Goal

Close the doctrine §7 "MAS/Core vs Pro capability symbol separation" lane so a single Swift compile can produce two genuinely-different binaries: one that links zero Pro/Research symbols (App Store), and one that links the full Pro surface (Developer ID).

### Tier

**Both** — the work straddles Core and Pro by definition; it builds the wall between them.

### Dependencies

- None — this is a foundation card for L4-CARD-1.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3 (three-tier ship model) + §6 (hard forbidden list)
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §3.1 (tier classification rules) + §4 (tier-leakage symbol check)
- `Epistemos/Bridge/ToolTierBridge.swift` for the `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` precedent
- `EpistemosTests/CoreMASBoundarySourceGuardTests.swift` (already-uncommitted source guards)
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme` for the existing scheme

### Allowed Write Set

- `Epistemos/<file>.swift` for any file that needs `#if !EPISTEMOS_APP_STORE` gating that doesn't yet have it (audit-driven)
- `EpistemosTests/MASCoreSymbolSeparationLinkerGuardTests.swift` (NEW — tests that the App Store target's symbol table contains zero Pro-only symbol names)
- (coordination-required) `Epistemos.xcodeproj/project.pbxproj` for new `EPISTEMOS_APP_STORE` define rows

### Forbidden Write Set

- Any Pro-only feature file (do not add new Pro features; this card is a fence, not a build-out)
- Codex reservation set
- Canon-in-flight docs

### Implementation Contract

- After this card ships, a Release build of the App Store scheme **fails** to compile any Pro/Research symbol if a `#if !EPISTEMOS_APP_STORE` gate is missing.
- The linker test reads the actual `.app` symbol table (e.g., via `nm` or `otool -lv`) and asserts none of the doctrine §6 forbidden symbols appear.
- The pre-existing `coreAppStoreAllowedToolNames` set in `ToolTierBridge.swift` remains the runtime fallback; this card adds a compile-time guard above it.

### Tests And Logs

- Linker test as above.
- Existing source-guard tests (`CoreMASBoundarySourceGuardTests`) remain passing.
- Build the App Store scheme: `xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build` must succeed.

### Acceptance

- New linker test passes.
- App Store scheme builds clean with zero Pro/Research symbols in the binary.
- Default scheme (Pro-equivalent) still includes Pro symbols.

### Stop Triggers

- The linker test reveals > 5 Pro symbols leaking into the App Store binary today — escalate; this is a P0 surface that needs its own dedicated audit slice before symbol separation can be claimed closed.
- A Pro feature genuinely needs to ship in Core (rare, doctrine §6 violation by definition) — escalate to update doctrine before implementing.

### Completion Report

- Files changed
- Linker output (sanitized)
- Tests run
- Remaining risks
- Rollback

---

## L4-CARD-1 — Pro Developer ID + Notarization build configuration

### Goal

Add a `Epistemos-Pro` Xcode scheme that produces a Developer ID Application-signed, notarized `.app` ready for distribution outside the Mac App Store.

### Tier

**Pro**.

### Dependencies

- L2-CARD-1 must ship first (compile-time symbol separation must exist before there's a meaningful "Pro build").
- Apple Developer enrollment ($99/yr) must be active. **The user is the gating resource here**; this card cannot start until enrollment + Developer ID Application cert exist.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3 (Pro tier) + Annex A on entitlements
- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme` for the App Store scheme to mirror
- `Epistemos-AppStore-Info.plist` for the entitlement comparison
- Apple's notarytool docs (web validation; primary source: `developer.apple.com/documentation/security/notarizing_macos_software_before_distribution`)

### Allowed Write Set

- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-Pro.xcscheme` (NEW)
- `Epistemos-Pro-Info.plist` (NEW — drop the App Sandbox entitlement; add `cs.allow-jit`, `cs.allow-unsigned-executable-memory`, `cs.disable-library-validation`, `automation.apple-events` per doctrine §3)
- `scripts/notarize.sh` (NEW — wrapper around `xcodebuild archive` + `xcodebuild -exportArchive` + `xcrun notarytool submit --wait` + `xcrun stapler staple`; reads team ID + Apple ID + app-specific password from env vars only)
- (coordination-required) `Epistemos.xcodeproj/project.pbxproj` for the new target / scheme rows

### Forbidden Write Set

- Hard-coded credentials (Apple ID, password, team ID) anywhere
- Any new Pro feature code (this card is build config only)
- Codex reservation set
- Canon-in-flight docs

### Implementation Contract

- `scripts/notarize.sh` exits non-zero with a clear message if any of `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_NOTARY_PASSWORD` env vars are unset.
- The Pro scheme defines `EPISTEMOS_PRO=1` and removes `EPISTEMOS_APP_STORE`.
- The Pro `.app` includes the doctrine §3 Pro entitlement bundle.
- Notarization end-to-end on a clean build produces a stapled `.app` with `xcrun stapler validate` exit code 0.

### Tests And Logs

- `scripts/notarize.sh` dry-run test (with `NOTARIZE_DRY_RUN=1` env var) prints the planned commands without executing them.
- Manual: full notarize loop on a throwaway build; record the Apple notarization ticket ID.
- Expected `/tmp/...log` names: `/tmp/epistemos-pro-notarize-<timestamp>.log`.

### Acceptance

- Pro scheme exists and builds.
- `notarize.sh` produces a stapled `.app` end-to-end on the user's machine.
- L2-CARD-1's linker test against the Pro target shows Pro symbols ARE present (validates the symbol-separation worked the other direction too).

### Stop Triggers

- Apple Developer enrollment not yet purchased — stop; this card is gated on user purchase.
- Notarization rejects the build — capture the rejection reason; that's a separate fix slice.

### Completion Report

- Files changed
- Notarization ticket ID
- Stapler validation output
- Remaining risks
- Rollback

---

## L4-CARD-2 — Pro embedded JS runtime gate

### Goal

Add a Pro-only embedded JavaScript runtime (QuickJS or Deno bindings via Rust) for use by Pro tools (CLI passthrough, browser-use scripting, MCP server hosting), gated behind the `EPISTEMOS_PRO` compile flag.

### Tier

**Pro**.

### Dependencies

- L2-CARD-1 (symbol separation) must ship first.
- L4-CARD-1 (Pro entitlement bundle) must ship first — `cs.allow-jit` + `cs.allow-unsigned-executable-memory` are required for QuickJS / Deno JIT.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §5 Pro tier (mentions QuickJS / Deno explicitly)
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §3 (killer features) for any cross-reference
- Web validation: latest QuickJS-NG bindings for Rust on `crates.io` (primary source); Deno's `deno_runtime` crate on `crates.io`
- `agent_core/Cargo.toml` for crate version conventions

### Allowed Write Set

- `agent_core/src/jsruntime/mod.rs` (NEW)
- `agent_core/src/jsruntime/quickjs.rs` (NEW — chosen embedding)
- `agent_core/tests/jsruntime_smoke.rs` (NEW)
- (coordination-required) `agent_core/Cargo.toml` for the new crate dependency
- `Epistemos/Engine/JSBridge.swift` (NEW — Swift wrapper, `#if EPISTEMOS_PRO`)
- `EpistemosTests/JSBridgeTests.swift` (NEW, gated by `#if EPISTEMOS_PRO`)

### Forbidden Write Set

- Any non-`#if EPISTEMOS_PRO`-gated invocation of the JS runtime
- `Epistemos/Bridge/ChunkedMCPFraming.swift` and other transport files (separate cards)
- Codex reservation set
- Canon-in-flight docs

### Implementation Contract

- The JS runtime never loads in a Core build (linker test from L2-CARD-1 must continue to pass for the Core target).
- Sandboxed by default — JS code cannot read the user's vault or network without an explicit Rust-side host function exposure.
- `eval` does not block; long-running scripts run on a background tokio task.

### Tests And Logs

- `cargo test jsruntime_smoke` exercises load-eval-result-return on a hello-world script.
- Pro Swift test exercises the FFI round-trip.

### Acceptance

- Pro build includes JS runtime; Core build does not.
- Smoke tests pass.
- L2-CARD-1 linker test continues passing for both targets.

### Stop Triggers

- QuickJS-NG vs Deno benchmark difference > 10× on the smoke workload — escalate to choose.
- JIT entitlement not present in Pro build — escalate to fix L4-CARD-1 entitlement set first.

### Completion Report

- Crate chosen + version
- Files changed
- Tests run
- Linker check both targets
- Remaining risks
- Rollback

---

## L5-CARD-1 — Research private framework loader gate

### Goal

Add a Research-only loader for `AppleNeuralEngine.framework` via `disable-library-validation`, gated behind `EPISTEMOS_RESEARCH` compile flag. The loader is the foundation for L5-CARD-2's direct ANE path.

### Tier

**Research**.

### Dependencies

- L2-CARD-1 (symbol separation) and L4-CARD-1 (Pro entitlement bundle) must ship first.
- `cs.disable-library-validation` entitlement must be in the Pro entitlement bundle (per L4-CARD-1) — this card extends it for Research.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3 Research tier + Annex A.11 (ANE direct path)
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` (donor research — IOKit/SMC channels, MLCustomLayer interception)
- Apple's docs on `dlopen` semantics with private frameworks (web validation)

### Allowed Write Set

- `Epistemos/Engine/PrivateFrameworkLoader.swift` (NEW, `#if EPISTEMOS_RESEARCH`)
- `EpistemosTests/PrivateFrameworkLoaderTests.swift` (NEW, `#if EPISTEMOS_RESEARCH`)
- `Epistemos-Research-Info.plist` (NEW — Pro entitlement bundle + `cs.disable-library-validation`)
- (coordination-required) `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-Research.xcscheme` (NEW)

### Forbidden Write Set

- Any private **entitlement** (`com.apple.private.*`) per doctrine §6 hard forbidden list
- Any non-Research build configuration that loads private frameworks
- Codex reservation set
- Canon-in-flight docs

### Implementation Contract

- Loader uses `dlopen` with the explicit framework path; no entitlement key.
- Loader never executes in Pro or Core builds (compile flag gate + runtime guard).
- Loader returns `nil` on failure rather than crashing — Research-only does not mean Research-only-and-fragile.

### Tests And Logs

- Smoke test: load + symbol-resolve + close on a private framework that's known to exist on macOS 26.x.
- Test that Pro and Core builds either don't compile this file or fail-soft.

### Acceptance

- Research scheme builds and runs the loader successfully on the user's host.
- Pro and Core builds remain unaffected.
- Doctrine §6 hard forbidden list is not violated (no private entitlements anywhere).

### Stop Triggers

- macOS 26.x changes private framework discovery semantics — re-research before implementing.
- App Store / Pro target accidentally compiles this file — STOP, fix the compile gate before merging.

### Completion Report

- Files changed
- Research scheme build log
- Tests run
- Remaining risks
- Rollback

---

## L5-CARD-2 — Research direct ANE path via `_ANEClient`

### Goal

Land a Research-only direct path to the Apple Neural Engine via `_ANEClient` loaded through L5-CARD-1's private framework loader.

### Tier

**Research**.

### Dependencies

- L5-CARD-1 must ship first.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3 Research tier + Annex A.11
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`
- L5-CARD-1's completion report

### Allowed Write Set

- `Epistemos/Engine/ANEDirectPath.swift` (NEW, `#if EPISTEMOS_RESEARCH`)
- `EpistemosTests/ANEDirectPathTests.swift` (NEW, `#if EPISTEMOS_RESEARCH`)

### Forbidden Write Set

- Any `MTLBuffer.contents()` raw KV implantation (separate Research card)
- Any private entitlement
- Codex reservation set

### Implementation Contract

- `_ANEClient` is loaded once at process start in Research builds.
- Failure path returns `nil` and logs a structured warning; never crashes.
- IOSurface is used for zero-copy I/O per doctrine §A.11.

### Tests And Logs

- Smoke test: load `_ANEClient`, list devices, close.
- Bench: simple inference round-trip latency vs MLX-Swift baseline.

### Acceptance

- Smoke test passes on Research build.
- Latency comparison recorded.
- Pro / Core builds unaffected.

### Stop Triggers

- `_ANEClient` API surface changed in macOS 26.x — re-research.
- Direct path is slower than MLX-Swift on the smoke workload — record finding, do not productionize without a clear win path.

### Completion Report

- Files changed
- Tests run + benchmark output
- Remaining risks
- Rollback

---

## L6-CARD-1 — Sherry 1.25-bit ternary weight format scaffolding

### Goal

Land a pure-Rust Sherry 1.25-bit packing / unpacking module with Arenas annealing skeleton, in `agent_core/src/ternary/`, with verified CPU baseline numbers.

### Tier

**Research** at ship time, but **the code can exist in dev mode for years before Pro/Research ships** — pure Rust, no Apple entitlements, no FFI exposure required for dev iteration.

### Dependencies

- None for the dev scaffold. For shipping, depends on L5-CARD-1 + L5-CARD-2 (direct ANE / KV implantation are the surfaces where 1.25-bit pays off).

### Authority To Read First

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H-honest claims (the "3059× speedup" figure is **unsupported**; actual Sherry numbers are 10–18% over other ternary baselines on CPU)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §A.5 (continual learning honest stance)
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/ternary_spectral_architecture.md` (donor research)
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/ternary_code_scaffolds.md` (donor research)
- Web validation: Huang et al. 2026 Sherry paper (primary source); BitNet b1.58 paper (Microsoft, 2B params production)

### Allowed Write Set

- `agent_core/src/ternary/mod.rs` (NEW)
- `agent_core/src/ternary/pack.rs` (NEW — 1.25-bit packing per Huang et al. 2026)
- `agent_core/src/ternary/unpack.rs` (NEW)
- `agent_core/src/ternary/arenas.rs` (NEW — annealing skeleton)
- `agent_core/tests/ternary_seed.rs` (NEW)
- `agent_core/benches/ternary_baseline.rs` (NEW)

### Forbidden Write Set

- Any FFI exposure (Swift side stays untouched until Lane 5/6 ship)
- Any combination with QLoRA / 4-bit quantization (not 4-bit compatible per doctrine §A.5)
- Codex reservation set
- Canon-in-flight docs
- `Cargo.toml` (coordination-required if a new crate is needed)

### Implementation Contract

- Pack / unpack are bit-exact round-trip identity for tensor input.
- Annealing is a skeleton (correct types, simulated-annealing loop body), not a full optimizer.
- Benchmark records actual CPU numbers — **do not import the unsupported "3059×" figure**; report what the code measures.

### Tests And Logs

- Property test: pack → unpack → equality for random tensors.
- Bench: pack throughput (MB/s) on a 16 GiB host.
- Verified-claim test: bench output matches the 10–18% CPU baseline range from Master Research Index §0; if not, record divergence honestly.

### Acceptance

- Three new Rust files + tests + bench exist.
- Round-trip property test passes.
- Bench numbers recorded honestly (do not paper over divergence).

### Stop Triggers

- Pack / unpack round-trip fails for edge tensor shapes — escalate.
- Bench shows < 5% CPU advantage over `i8` baseline — record finding; the slice may be deferrable until L5-CARD-2 brings ANE into the picture.

### Completion Report

- Files changed
- Bench output
- Honest claim status (matches MASTER_RESEARCH_INDEX §0 honest discoveries: yes / partially / no)
- Remaining risks
- Rollback

---

## Note on canonicality

Until Codex / user reviews this draft, none of these cards may be:

- Copied into `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- Used to open a `docs/fusion/deliberation/<slice>_deliberation_2026_05_03.md` slice
- Picked up by any parallel coding agent

When the user approves, the natural promotion path is: (a) move the approved card body into the canonical workcards file under a new "Card N — <title>" heading per the doctrine §7 dependency order, (b) open a deliberation file per the standard process, (c) update the doctrine §7 build-order graph row from `not started` to `assigned`.

---

## Reservation respect

This draft was generated without editing any of:

- `Epistemos/Bridge/ClarifyPromptBridge.swift` (closed by Codex PR43)
- `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift` (closed by Codex PR43)
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.
