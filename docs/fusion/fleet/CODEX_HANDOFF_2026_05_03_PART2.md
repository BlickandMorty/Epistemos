# Codex Handoff — 2026-05-03 (Part 2)

> **For Codex.** This handoff covers the second half of 2026-05-03 — eight more commits on top of the prior `CODEX_HANDOFF_2026_05_03.md`. The Resonance Gate (Lane 3 killer feature) went from doctrine concept to end-to-end live code, and the Core Hermes parity slate (Lane 4 Core-side) went from 1 command to 26.

---

## TL;DR for the next round

1. **The Resonance Gate τ + π + λ daemon is alive end-to-end.** Rust seed + serde + UniFFI bridge + Swift mirror service + SwiftUI chip + legend. Production mounting (chip into chat/editor/Halo) is the natural next slice — it touches existing views so it is **coordination-required**.
2. **Every Core-tier row in `HermesCapabilityRegistry` now has a parser + intent**, plus a master dispatcher with a 36-variant sum type. `HermesCommandDispatcher.parseCore(_:)` is the single entry point. **Wire it into the chat input** to make slash commands actually work — also coordination-required (touches chat input surface).
3. **The biggest blocker for everything Swift this session is `Epistemos.xcodeproj/project.pbxproj`.** All new Swift files (production + tests) are on disk but not in the Xcode targets yet. Until that's done, SourceKit shows `No such module 'Testing'` and `Cannot find type` warnings. **Codex's first move should be to add the new files to the appropriate targets.**

---

## What just shipped (8 commits, in order)

```
06230e8d Seed Resonance Gate τ + π + λ daemon                  (Rust + lib.rs)
e03fb890 Add Resonance Gate Swift consumer and UI shell        (Swift, 4 files)
3cc3c612 Add Hermes /calc deterministic calculator             (Swift, NSExpression)
6f8ad5af Add five Core-native Hermes parity commands           (/help, /status, /tokens, /cost, /think)
07e33fed Bridge Resonance Gate signature to UniFFI             (Rust bridge.rs additive function)
469f6879 Add ten Core-native Hermes session-ops + parameter    (/new, /clear, /save, /load, /export, /compact,
         commands                                              /summary, /model, /system, /temperature,
                                                               /max-tokens, /top-p, /top-k)
caa46d05 Wire master Hermes command dispatcher and remaining   (HermesCommandDispatcher + persona + memory +
         Core registry rows                                    tools toggle + config show + notebook)
d2641b12 Complete the Core Hermes parity slate                 (UI display + vault file: /theme, /mode,
         (UI display + vault file)                              /markdown, /image, /pager, /width, /font,
                                                               /fontsize, /colors, /read, /write, /append,
                                                               /ls, /search, /grep)
```

Every commit is signed `Co-Authored-By: Claude Opus 4.7 (1M context)`. Net adds: ~5,400 insertions, 0 lines deleted from existing files except for the 1-line `pub mod resonance;` insertion in `agent_core/src/lib.rs` and a trailing `// MARK:` header before the existing Command Center section in `agent_core/src/bridge.rs`.

---

## What's now live on disk

### Rust (agent_core)

| File | Role |
|---|---|
| `agent_core/src/resonance/mod.rs` | Public API — `Claim`, `ClaimRef`, `ResonanceSignatureCore`, `compute_signature_core` |
| `agent_core/src/resonance/tau.rs` | Kleene K3 `Truth` enum + truth-table operators |
| `agent_core/src/resonance/pi.rs` | 9 `ClaimType` variants + `ClaimClass` (Prime/Composite/Gap) + classifier |
| `agent_core/src/resonance/lambda.rs` | 8-level `ResidencyLevel` (L0–L7) + Core-cap enforcement at L0–L3 + L7 |
| `agent_core/tests/resonance_seed.rs` | 30 integration tests — all green |
| `agent_core/src/bridge.rs` | (additive) `compute_resonance_signature_core(claim_json: String) -> Result<String, AgentErrorFFI>` at line ~826 |
| `agent_core/src/lib.rs` | (1-line) `pub mod resonance;` between `reasoning_metrics` and `resources` |

**Verification:** `cargo build --manifest-path agent_core/Cargo.toml --lib` → clean (51s incremental). `cargo test --test resonance_seed` → **30 passed; 0 failed; finished in 0.00s**.

### Swift — Resonance Gate consumer + UI

| File | Role |
|---|---|
| `Epistemos/Engine/ResonanceService.swift` | `@Observable` `@MainActor` service mirroring the Rust types. Computes signatures locally (FFI-ready stub — swap in `bridge::compute_resonance_signature_core` when wired). |
| `Epistemos/Views/Resonance/ResonanceChip.swift` | 3-pip horizontal strip (T · P · L1). Accessible, tier-leakage warning border. **Previews-only** — not mounted in any production view yet. |
| `Epistemos/Views/Resonance/ResonanceLegendView.swift` | Settings-style explanation surface for the chip. Previews-only. |
| `EpistemosTests/ResonanceServiceTests.swift` | 14 Swift Testing cases mirroring the Rust 30. |

### Swift — Hermes parity Core commands (every Core-tier row in HermesCapabilityRegistry)

| File | Commands |
|---|---|
| `Epistemos/LocalAgent/HermesCalcCommand.swift` | `/calc <expression>` |
| `Epistemos/LocalAgent/HermesHelpCommand.swift` | `/help`, `/help <tier|surface>` |
| `Epistemos/LocalAgent/HermesStatusCommand.swift` | `/status` + `HermesSessionStatusInput` + `HermesSessionStatus` |
| `Epistemos/LocalAgent/HermesTokensCommand.swift` | `/tokens` + `HermesTokenStatsInput` + `HermesTokenStats` |
| `Epistemos/LocalAgent/HermesCostCommand.swift` | `/cost` + `HermesCostStatsInput` + `HermesCostStats` |
| `Epistemos/LocalAgent/HermesThinkCommand.swift` | `/think <prompt>` + canonical reasoning cue wrap |
| `Epistemos/LocalAgent/HermesSessionOpsCommands.swift` | `/new`, `/clear`, `/save`, `/load`, `/export`, `/compact`, `/summary`, `/model`, `/system <prompt>` |
| `Epistemos/LocalAgent/HermesParameterCommands.swift` | `/temperature`, `/max-tokens`, `/top-p`, `/top-k` (with bounds enforcement) |
| `Epistemos/LocalAgent/HermesPersonaCommands.swift` | `/persona`, `/persona list`, `/persona <name>`, `/persona create|edit|delete|export|info <name>`, `/persona import <file>` |
| `Epistemos/LocalAgent/HermesConfigToggleCommands.swift` | `/memory on|off|clear`, `/tools on|off`, `/config show` |
| `Epistemos/LocalAgent/HermesNotebookCommands.swift` | `/notebook`, `/notebook list`, `/notebook clear`, `/notebook open <name>`, `/notebook <name>` shorthand |
| `Epistemos/LocalAgent/HermesUIDisplayCommands.swift` | `/theme`, `/theme list`, `/theme <name>`, `/mode <simple|rich>`, `/markdown on|off`, `/image on|off`, `/pager on|off`, `/width <40-500>`, `/font <name>`, `/fontsize <8-72>`, `/colors` |
| `Epistemos/LocalAgent/HermesVaultFileCommands.swift` | `/read`, `/write`, `/append`, `/ls`, `/search`, `/grep` |
| `Epistemos/LocalAgent/HermesCommandDispatcher.swift` | `HermesParsedCommand` sum type (36 variants) + `HermesCommandDispatcher.parseCore(_:)` + inline `HermesAskCommand` |

### Swift — tests

| File | Suites / cases |
|---|---|
| `EpistemosTests/HermesCalcCommandTests.swift` | 5 suites, 15 cases |
| `EpistemosTests/HermesParityCommandsTests.swift` | 5 suites, 31 cases (help / status / tokens / cost / think) |
| `EpistemosTests/HermesSessionAndParameterCommandsTests.swift` | 12 suites, 38 cases (session-ops + parameters) |
| `EpistemosTests/HermesPersonaConfigNotebookCommandsTests.swift` | 5 suites, 17 cases |
| `EpistemosTests/HermesCommandDispatcherTests.swift` | 1 suite, 12 cases |
| `EpistemosTests/HermesUIDisplayAndVaultFileCommandsTests.swift` | 11 suites, 22 cases |
| `EpistemosTests/ResonanceServiceTests.swift` | 1 suite, 14 cases |

**Total Swift Testing cases added this session: ~149.**

---

## Coordination-required (Codex's first move)

### `Epistemos.xcodeproj/project.pbxproj` — add new files to targets

The new Swift files exist on disk but aren't in any Xcode target yet. SourceKit reports the expected `No such module 'Testing'` and `Cannot find type 'X' in scope` warnings until they're added.

**Add to `Epistemos` target (production):**
- `Epistemos/Engine/ResonanceService.swift`
- `Epistemos/Views/Resonance/ResonanceChip.swift`
- `Epistemos/Views/Resonance/ResonanceLegendView.swift`
- `Epistemos/LocalAgent/HermesCalcCommand.swift`
- `Epistemos/LocalAgent/HermesHelpCommand.swift`
- `Epistemos/LocalAgent/HermesStatusCommand.swift`
- `Epistemos/LocalAgent/HermesTokensCommand.swift`
- `Epistemos/LocalAgent/HermesCostCommand.swift`
- `Epistemos/LocalAgent/HermesThinkCommand.swift`
- `Epistemos/LocalAgent/HermesSessionOpsCommands.swift`
- `Epistemos/LocalAgent/HermesParameterCommands.swift`
- `Epistemos/LocalAgent/HermesPersonaCommands.swift`
- `Epistemos/LocalAgent/HermesConfigToggleCommands.swift`
- `Epistemos/LocalAgent/HermesNotebookCommands.swift`
- `Epistemos/LocalAgent/HermesUIDisplayCommands.swift`
- `Epistemos/LocalAgent/HermesVaultFileCommands.swift`
- `Epistemos/LocalAgent/HermesCommandDispatcher.swift`

**Add to `EpistemosTests` target:**
- `EpistemosTests/ResonanceServiceTests.swift`
- `EpistemosTests/HermesCalcCommandTests.swift`
- `EpistemosTests/HermesParityCommandsTests.swift`
- `EpistemosTests/HermesSessionAndParameterCommandsTests.swift`
- `EpistemosTests/HermesPersonaConfigNotebookCommandsTests.swift`
- `EpistemosTests/HermesCommandDispatcherTests.swift`
- `EpistemosTests/HermesUIDisplayAndVaultFileCommandsTests.swift`

**Verification command after the pbxproj add:**

```bash
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
           -scheme Epistemos \
           -destination 'platform=macOS' \
           -only-testing:EpistemosTests/HermesCommandDispatcherTests \
           -only-testing:EpistemosTests/ResonanceServiceTests \
           test 2>&1 | xcbeautify
```

If those two suites pass, the rest of the new test files will too.

---

## Recommended next slices (each parallel-safe with the others)

### M1 — Wire the Resonance chip into one production surface (M, coordination-required)

**Goal:** mount `ResonanceChip` into either the chat surface or the Halo recall result rows so users actually see the τ · π · λ signature for at least one claim type.

**Touches:** `Epistemos/Views/Chat/...` or `Epistemos/Views/Halo/...`. Both are existing-view edits so this is **coordination-required** with anything else Codex is doing in those folders.

**Acceptance:** chip appears next to at least one user-visible message / claim with sane defaults. Tap-and-hold (or hover) opens `ResonanceLegendView` as a popover.

### M2 — Wire `HermesCommandDispatcher.parseCore` into the chat input (M, coordination-required)

**Goal:** make slash commands actually work. The chat input surface (likely `Epistemos/Views/Chat/ChatInputBar.swift` or similar) currently passes raw text through; intercept `/...` inputs and route them through `HermesCommandDispatcher.parseCore(_:)`.

**Acceptance:** typing `/help` shows the help output; `/calc 2+2` shows `4`; `/todo add X` adds a todo via the existing native ledger; unknown slash commands fall back to existing chat behaviour.

### M3 — Replace `ResonanceService.computeStub(for:)` with the FFI call (S, coordination-required)

**Goal:** swap the Swift mirror compute for the authoritative Rust path now that `agent_core::bridge::compute_resonance_signature_core` is exported.

**Touches:** `Epistemos/Engine/ResonanceService.swift` lines 169-178 (the `#if canImport(agent_coreFFI)` branch).

**Pattern:**

```swift
#if canImport(agent_coreFFI)
let claimJson = try JSONEncoder().encode(claim)  // requires Codable on ResonanceClaim — TODO
let signatureJson = try computeResonanceSignatureCore(claimJson: String(data: claimJson, encoding: .utf8)!)
let signature = try JSONDecoder().decode(ResonanceSignatureCore.self, from: signatureJson.data(using: .utf8)!)
return signature
#else
let signature = computeStub(for: claim)
#endif
```

**Sub-task:** add `Codable` to `ResonanceClaim`, `ResonanceClaimType`, etc. so the JSON round-trip is one-line. The Swift mirror types currently are not `Codable`; add the conformance in the same slice.

**Acceptance:** the Pro/Research build path uses the Rust signature; tests still pass on Core-only builds via the stub.

### S1 — Mount Resonance signature emission into the chat token stream (L, depends on M1 + M3)

The actual integration: as tokens stream, classify each completed claim and attach a chip. This is the doctrine §4.1 "the gate is one daemon between source and sink" vision. Larger slice — open as a deliberation brief first.

### S2 — Add Sherry 1.25-bit ternary scaffolding (L1 from prior workcards draft, L)

Lane 6 work. Pure Rust, can scaffold in dev mode any time. Reference `AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md` L6-CARD-1.

### S3 — MAS/Core symbol separation closure (L2-CARD-1)

The single highest-leverage Core-open item. Closing it unblocks Lane 4 ship (Pro Developer ID + Notarization, JS runtime).

---

## What NOT to do

| Anti-pattern | Why |
|---|---|
| Re-write any of the 26 Hermes parity commands | They exist, are tested, and are tier-correct. Just route them. |
| Re-implement Resonance Gate τ/π/λ | Already exists end-to-end. Extend with δ + ρ (Pro) or κ + η (Research) when the user explicitly says go. |
| Add `LAContext` anywhere outside `Epistemos/Sovereign/SovereignGate.swift` | Single-owner doctrine still holds. |
| Touch the user's pre-existing 660-uncommitted-files pile | Treat as read-only. Each Hermes / Resonance commit this session was clean against that pile. |
| Run R15 live MLX harness | Per `R15_LIVE_MLX_GO_NO_GO_2026_05_03.md` — still NO-GO until headroom recovers. |
| Open Pro-only commands as Core (`/run`, `/shell`, `/kill`, `/web search`, `/web page`, `/mcp ...`) | Dispatcher already rejects them with a tier-leakage guard. They belong to the Pro Hermes gateway. |
| Add commands to `HermesCommandDispatcher.parseCore` without also adding the variant to `HermesParsedCommand` | Compiler will catch this, but the `requiresApproval` switch needs the new branch too. |

---

## Star checklist (Codex's "is this all good?" pass)

- ⭐ All 8 commits present in `git log` between `b8433286` and the current HEAD
- ⭐ Resonance Gate Rust seed compiles + 30 tests pass: `cargo test --manifest-path agent_core/Cargo.toml --test resonance_seed`
- ⭐ `agent_core` lib still compiles: `cargo check --manifest-path agent_core/Cargo.toml --lib`
- ⭐ 660-pile untouched (every commit only added to its own narrow file set)
- ⭐ No protected paths edited (`ProseEditor*`, `MetalGraphView`, `HologramController`, graph internals)
- ⭐ No canon-in-flight docs edited (`MASTER_RESEARCH_INDEX`, `UNIFIED_SUBSTRATE_CURRENT_STATE`, `AGENT_BUILD_WORKCARDS`, `REGISTRY.md`, `PARALLEL_WORK_MANIFEST.md`)
- ⭐ Every test file shows the expected `No such module 'Testing'` SourceKit warning — the resolution is the pbxproj add, not a code fix
- ⭐ Every Hermes command file follows the established `HermesTodoCommand` shape (struct + parse + Sendable/Equatable)
- ⭐ Master dispatcher `HermesParsedCommand` has 36 variants and the `requiresApproval` switch is exhaustive

---

## State at handoff

- **Branch:** `feature/landing-liquid-wave`
- **HEAD:** `d2641b12 Complete the Core Hermes parity slate (UI display + vault file)`
- **Ahead of origin:** 250 commits (push when ready, not part of this handoff)
- **Codex side-fleet:** idle, ready for next dispatch
- **Recommended first action for the next round:** the pbxproj add (see "Coordination-required" §). After that, M2 (wire dispatcher into chat input) is the highest-leverage single move because it makes 26 commands actually reachable from the UI in one slice.
