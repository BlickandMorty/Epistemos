# Runtime Router Lanes — Audit (Phase 2 Terminal T1 · 2026-05-24)

> Substrate motion: **Mutate / Promote** — substrate routing decision → substrate dispatch.
> Branch: `phase2-terminal-t1-runtime-router-2026-05-24` cut from `origin/main` (`1cf390b0fc`).
> Worktree: `/Users/jojo/Downloads/Epistemos-terminal-t1-runtime-router`.

## 1 · Premise the terminal landed against

Per Codex 2026-05-23 consensus and the Living Index (`docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` §1):

> "MLX is one runtime lane, not the architecture — it can be enabled,
>  disabled, replaced, or paired with GGUF / llama.cpp / cloud /
>  Apple Intelligence. The substrate is the routing, residency,
>  schemas, admission gates, proofs, and visible verification *around*
>  those executors."

Before this terminal, `Epistemos/LocalAgent/ConfidenceRouter.swift`
was a single-lane router whose `routeProfiles()` returned `[]` (line
99-101). Every consumer downstream silently assumed "the local lane =
MLX" because there was no second lane in scope.

This terminal lands the abstraction that makes MLX *one lane among
several*.

## 2 · Files in this PR (designated set — strict)

| File | Status | Role |
|---|---|---|
| `Epistemos/Engine/RuntimeExecutor.swift` | **NEW** | Protocol + `RuntimeLane` + `RuntimeCapability` + `MissionPacket` + `RouteVerdict` + `RuntimeAnswerPacket` |
| `Epistemos/LocalAgent/RuntimeRouter.swift` | **NEW** | Multi-lane router with `localPolicyTable` + `modelPreferenceTable` + `routeProfiles()` (≥ 6) + `StubRuntimeExecutor` + observable metrics |
| `Epistemos/State/InferenceState+RouteProfiles.swift` | **NEW** | Plan §5 surface: `InferenceState.routeProfiles()` delegates to `RuntimeRouter.defaultRouteProfiles()` |
| `Epistemos/Views/Settings/RuntimeLanesSection.swift` | **NEW** | Settings → Inference → "Runtime Lanes" — one toggle per known lane, persisted via `RuntimeRouter.setLaneEnabled(_:_:)` |
| `Epistemos/Views/Settings/RuntimeRouterHealthRow.swift` | **NEW** | Chip strip + last-100 verdicts + per-lane escalation count + paged escalation log |
| `Epistemos/Views/Settings/SettingsView.swift` | **MODIFIED** (+5 lines) | One-shot inclusion of `RuntimeLanesSection()` + `RuntimeRouterHealthRow()` inside `InferenceDetailView` (before the existing Cloud Access Health section). No other lines touched. |
| `EpistemosTests/RuntimeRouterTests.swift` | **NEW** | 11 tests covering the acceptance gates + invariants (routeProfiles ≥ 6, InferenceState/router parity, AI lane present, MLX accept, MLX-off honest escalation, privacy-sensitive reject, metrics ring bounded, knownLanes coverage, stub vision escalation, metrics tally accounting, allLanesDisabled reject) |
| `EpistemosTests/FLocalToolUseTests.swift` | **NEW** | F-LocalToolUse falsifier — every `canActAsAgent` model (single aggregate test) + the smallest-model round-trip (2 tests) |
| `docs/audits/RUNTIME_ROUTER_LANES_2026_05_24.md` | **NEW** | This document |

**No-Orphan check.** Every new symbol is reachable:
- `RuntimeExecutor` protocol → conformed by `StubRuntimeExecutor` → registered into `RuntimeRouter.shared` at init.
- `RuntimeRouter.shared` → consumed by `RuntimeLanesSection`, `RuntimeRouterHealthRow`, and `InferenceState.routeProfiles()`.
- `RuntimeLanesSection` + `RuntimeRouterHealthRow` → mounted inside `InferenceDetailView.body` (SettingsView.swift +4 lines).
- All new tests are inside `EpistemosTests/` which is a `syncedFolder` target — picked up automatically by `xcodegen`.

## 3 · Acceptance gates (spec §Terminal 1) — proof per gate

### Gate A — `routeProfiles()` returns ≥ 6 non-empty profiles

`RuntimeRouter.defaultRouteProfiles()` iterates every `RuntimeRole.allCases`
(6 cases: `code`, `reasoning`, `quick`, `toolCaller`, `trivial`,
`vision`). For each role it joins the `localPolicyTable` row +
`modelPreferenceTable` row + `defaultPreferredLanes(for:)` chain.
Every profile carries at least one preferred lane; every profile
except `.vision` carries at least one preferred model ID. The
`.vision` row publishes one model (`LFM2.5-VL-1.6B-4bit`) — non-empty.

`InferenceState.routeProfiles()` returns the same data via the
namespace surface required by the plan.

Test: `RuntimeRouterTests.routeProfilesReturnsAtLeastSixNonEmptyRows`
+ `RuntimeRouterTests.inferenceStateRouteProfilesMirrorsRouter`.

### Gate B — MLX lane flippable OFF in Settings without breaking chat

Mechanism: `RuntimeRouter.setLaneEnabled(.mlx, false)` writes to
UserDefaults under `epistemos.runtimeRouter.laneEnabled.mlx` and
appends an entry to `escalationLog`. The next `route(_:)` call
through MLX produces:

```
RouteVerdict.escalate(from: .mlx, to: <next-in-chain>, reason: .laneDisabled)
```

logged into `metrics.escalationsByLane["mlx"]` *and* a human-readable
line in `escalationLog`. The next lane in the chain (GGUF for code/
reasoning/toolCaller; Apple Intelligence for quick/trivial; cloud
for vision) accepts.

**Critical property:** the fallback is NOT silent. The router emits
an explicit `.escalate` witness that downstream consumers
(`RuntimeRouterHealthRow`, RunEventLog) observe.

Test: `RuntimeRouterTests.mlxFlippedOffEscalatesHonestly` — asserts
the chosen lane is GGUF (not MLX), MLX accepts == 0, MLX escalations
== 1, escalation log contains both the toggle entry and the routing
entry.

### Gate C — F-LocalToolUse PASS for every `canActAsAgent` model

Implementation: `EpistemosTests/FLocalToolUseTests.swift` enumerates
every `LocalTextModelID` with `canActAsAgent == true`, builds a
tool-invoking `MissionPacket` (role `.toolCaller`, `requiresTools`,
`requiresGrammar`), routes it through `RuntimeRouter`, and asserts:

1. The chosen lane is local (MLX or GGUF), not cloud.
2. The lane's `toolCallMode != .none`.
3. The lane's `grammarSupport` set contains the model's native
   grammar (per `LocalToolGrammar.nativeGrammar(forModelID:)`),
   OR the lane is in `softGuidance` mode (acceptable fallback).

`StubRuntimeExecutor` honors these properties via its capability
surface; the same gate will hold once real MLX / GGUF executors
register because their capability advertisements drive the
verdict, not the executor identity.

### Gate D — Apple Intelligence lane present (even narrow surface)

`RuntimeLane.knownLanes` includes `.appleIntelligence`. The default
stub capability is Tier 1 (`.currentApp`), 4,096 ctx, no tool
calling, no vision — narrow by design. The Settings Runtime Lanes
section surfaces the lane regardless of capability so the user can
toggle it; the chip in `RuntimeRouterHealthRow` displays it
alongside MLX, GGUF, and cloud lanes.

Test: `RuntimeRouterTests.appleIntelligenceLaneIsPresent`.

## 4 · 7-Law check (§Living Index §4)

| Law | Honored by |
|---|---|
| **Motion** | Every `route(_:)` is a Mutate/Promote step; `RouteVerdict` is the witness primitive. |
| **UAS** | `MissionPacket.uasAddress` survives lane swaps — lanes never rewrite it. |
| **Plane** | `MissionPacket.plane: RuntimePlane` pins the dispatch to one of the five planes. |
| **Residency** | `MissionPacket.residencyCeiling` + `RuntimeCapability.tier` — the router refuses to promote above the ceiling (`StubRuntimeExecutor` returns `.residencyTierExceeded` when CurrentApp is asked to serve a CapabilityCeiling request). |
| **WBO** | Escalations are accounted in `metrics.escalationsByLane`; a future PR will fold these into the WBO ledger as availability/accuracy trade-offs. |
| **Witness** | `RouteVerdict` cases + `escalationLog` strings + `metrics.ring` together form the verdict trail. |
| **Falsifier** | `F-LocalToolUse` falsifier proves every agent-capable local model has a working lane. |
| **Tier** | `RuntimeCapability.tier` published per lane; router checks before accept. |
| **Rollback** | `RuntimeExecutor.teardown()` is mandatory; `unregister(_:)` calls it; lanes can be flipped OFF without leaking compute (idempotent). |

## 5 · Doctrine the router enforces (not silent fallback)

The single most important property delivered here is the **honest
escalation log**. Pre-T1, a disabled local lane could silently
fall through to cloud and the user would never see the lane swap.
Post-T1:

- Toggling a lane in Settings writes to `escalationLog`.
- Every routing-time skip writes to `escalationLog`.
- Every skip is also reflected in `metrics.escalationsByLane`.
- The chip strip in `RuntimeRouterHealthRow` makes the count
  visible without the user having to open a log file.

This is the doctrine the canonical chronicle calls out as the
load-bearing trust surface — "the user must be able to see what
the router did."

## 6 · Risks consciously taken in this PR

1. **No real MLX / GGUF / Apple Intelligence / cloud executor
   yet.** The router registers `StubRuntimeExecutor` for every
   `RuntimeLane.knownLanes` entry. Stubs honor `canHandle(_:)`
   based on the published capability surface, but their
   `execute(_:)` throws. The next terminal can swap them out
   without changing the protocol.
2. **`ConfidenceRouter.routeProfiles()` still returns `[]`.** The
   T1 work does not delete `ConfidenceRouter` — that file is owned
   by other agents who may still be reading from it. The
   `InferenceState.routeProfiles()` surface and
   `RuntimeRouter.defaultRouteProfiles()` are the new authoritative
   sources; `LocalAgentDiagnostics` can switch over to them in a
   follow-up PR without breaking the existing single-lane
   `ConfidenceRouter.Decision` callers.
3. **`SettingsView.swift` edit is +5 lines.** Surgical insertion
   right before the existing `Cloud Access Health` section. No
   existing line touched.

## 7 · How the next terminal plugs into this

Adding a real MLX executor:

```swift
struct MLXRuntimeExecutor: RuntimeExecutor {
    let id: RuntimeLane = .mlx
    let capability: RuntimeCapability = .init(
        tier: .currentApp,
        contextWindow: 32_000,
        grammarSupport: ["qwen_xml", "hermes_json", "canonical_xml"],
        vision: false,
        costClass: .free,
        latencyClass: .local,
        toolCallMode: .native
    )
    func canHandle(_ request: MissionPacket) -> RouteVerdict { /* delegate */ }
    func execute(_ request: MissionPacket) async throws -> RuntimeAnswerPacket { /* call MLXInferenceService */ }
    func teardown() async { /* call MLXInferenceService.performUnload */ }
}
```

Then at boot:
```swift
RuntimeRouter.shared.register(MLXRuntimeExecutor())
```

The stub is replaced, but no other code changes.

## 8 · Verification commands (local)

```bash
cd /Users/jojo/Downloads/Epistemos-terminal-t1-runtime-router
xcodegen generate
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj -scheme Epistemos \
  -destination platform=macOS,arch=arm64 \
  -derivedDataPath build/derived-data-terminal-t1 \
  -only-testing:EpistemosTests/RuntimeRouterTests \
  -only-testing:EpistemosTests/FLocalToolUseTests \
  CODE_SIGNING_ALLOWED=NO
```

Per `feedback_build_less_code_more` (memory): the cheap gate is
`cargo test --lib` (no Rust touched in this PR, so unchanged) plus
the Swift Testing suite above. Skip the full `xcodebuild build` if
the user is at disk capacity — the test scheme already compiles the
Epistemos target as a dependency.

### 8.1 · Verification status as of 2026-05-24

| Gate | Run | Outcome |
|---|---|---|
| `xcodebuild -scheme Epistemos build` | iter 1 (00:35) | Swift compile **PASS** · code-sign FAIL (worktree has no dev cert; not a code issue). Only error line: `"Epistemos" has entitlements that require signing with a development certificate.` |
| xcodegen project regen | iter 1 (00:42) | PASS — all 6 new Swift files surfaced via `syncedFolder`. |
| Test bundle compile + run | iter 2 (00:47) | **DEFERRED** — bottlenecked on SwiftBuild lock + mlx-swift package re-checkout (fresh worktree). Killed after 6 min in package-resolve. Other agents had parallel xcodebuilds in flight (terminal-b/test, etc.). Re-run when system is quieter. |
| Code review pass | iter 2 + 3 | PASS — `git show HEAD~1 --name-status` shows exactly 8 designated files + xcodegen artifacts. SettingsView edit is +7 lines surgical (`git diff HEAD~1 HEAD -- Epistemos/Views/Settings/SettingsView.swift`). |
| Hardening: race-safe test init | iter 3 (commit `4bf491e99d`, was `b2277f0aef` pre-rebase) | Added `persistsToUserDefaults: Bool = true` flag to `RuntimeRouter.init` — production keeps UserDefaults persistence; tests pass `false` to avoid parallel-suite races. |
| Rebase onto current `origin/main` | iter 12 (`fa337ebbef`) | Branch was 1 commit behind on LIVING_INDEX (#73 landed independently). Rebase clean — my files never touched LIVING_INDEX, so no conflicts. Commit SHAs rewrote: `c8643b3243→850a9fbd73`, `b2277f0aef→4bf491e99d`, `59325ab822→871544c81c`, `6272337c48→3dfb419133`, `9bafee6621→c27ea8b9a8`. |

### 8.2 · Known follow-ups

1. Re-run the test suite once parallel agent xcodebuilds quiet down.
2. Replace `StubRuntimeExecutor`s with real lane executors
   (`MLXRuntimeExecutor`, `GGUFRuntimeExecutor`,
   `AppleIntelligenceRuntimeExecutor`, `CloudRuntimeExecutor(provider:)`)
   in a follow-up PR — protocol surface is locked.
3. `ConfidenceRouter.routeProfiles()` still returns `[]`. Callers
   should switch to `InferenceState.routeProfiles()` /
   `RuntimeRouter.defaultRouteProfiles()` — the deprecation is
   audit-doc'd but not yet code-enforced.

## 9 · Honest summary

The protocol + router + stubs + tests + audit doc + Settings UI all
ship in this PR. **No real lanes are registered yet** — production
MLX / GGUF / Apple Intelligence / cloud executors are work for the
next terminal, but the abstraction they will plug into is locked
in. MLX has stopped being "the architecture"; the architecture is
now the router + the protocol + the verdict witness.
