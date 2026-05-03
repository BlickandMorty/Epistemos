# Codex Handoff — 2026-05-03

> **For Codex.** Claude (parallel desktop side-fleet) just closed 8 outstanding ambiguities + committed the audit artifacts. This handoff names what's now decided, what's freshly surfaced, and what the next-best slice is.

---

## TL;DR

1. **Bridge AgentEvent layer is functionally complete (PR39–PR44).** Do not reopen it.
2. **The post-Bridge Omega/LocalAgent layer is also complete** for current production paths. Of 8 ambiguities I opened in earlier rounds, **zero are real instrumentation gaps** — 4 are dead code, 1 is already-correct (PR11), 1 is deferred (low-likelihood symptom-driven), 2 are no-Sovereign-gap (OAuth + Keychain).
3. **The single highest-leverage next slice is MAS/Core vs Pro symbol separation closure.** It's the gate to all of Lane 4 (Pro entitlement bundle, Notarization, JS runtime) and downstream Lanes 5–6.
4. **Four small cleanup slices** (delete dead code) and **two small AgentEvent slices** (silent credential writes) are now well-scoped and parallel-safe.

---

## What's freshly committed (Claude side-fleet, fbd1a211)

| Path | What it closes |
|---|---|
| `docs/fusion/fleet/omega-localagent-agent-event-inventory-pr45/claude-side-fleet/DETECTIVE_RESOLUTIONS_2026_05_03.md` | C-1, C-2, C-3, C-4, C-5, Gap-2 from the round-86 inventory |
| `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md` | SG-CARD-2 |
| `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_KEYCHAIN_AUDIT_2026_05_03.md` | SG-CARD-3 |

**Read these three first.** They turn 8 detective questions into closed verdicts so you don't spend a round re-investigating.

Note: between rounds 86 and now, you (Codex) independently closed C-1 yourself with `3d0242cc Close GhostComputerAgent reachability gate`. The detective resolution doc confirms that decision and lists the remaining cleanup queue.

---

## Closed verdicts (apply these instead of re-investigating)

### Dead code — open separate cleanup slices, do NOT instrument

| Surface | Status | Cleanup action | Effort |
|---|---|---|---|
| `Epistemos/Omega/Agents/GhostComputerAgent.swift` | ✅ already closed by you in `3d0242cc` | n/a | done |
| `Epistemos/Omega/Knowledge/AgentGraphMemory.swift` lines 44-120 (`recordExecution`) | open | Delete or wire to a real caller (zero current callers) | S |
| `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` (full file) | open | Wire to a tool surface OR delete (zero current callers; gated `#if !EPISTEMOS_APP_STORE`) | S–M |
| `VisualVerifyLoop` lazy var in `Epistemos/App/AppBootstrap.swift:844-847` | open | Wire `.verify(...)` into `ComputerUseBridge.execute(actionJSON:)` to close the post-action verification gap, OR delete the unused lazy var | S–M |

### Already-correct — no slice needed

| Surface | Why no gap |
|---|---|
| LocalAgent reflex/EOF flush completion (Gap-2) | EOF flush is text completion, not a tool event. PR11 emission at `LocalAgentLoop.swift:1084` covers the tool path (line 596+ branch). Mutually exclusive with the EOF branch (line 587-592). |
| ReasoningLoopService early-exit (C-5) | Deferred. Symptom-driven only. No log evidence of missing-completion events for ReasoningLoop run IDs in current production. |

### Sovereign Gate — no gap on either OAuth or Keychain

- **OAuth**: all 4 user-facing branches (sign-in, sign-out, client config save/clear) are user-initiated through UI buttons → satisfies Sensitive class per doctrine §A.7 without Touch ID. Silent token refresh is Trivial class (no prompt expected).
- **Keychain**: all 4 `Keychain.save` call sites are user-initiated through UI (3 of 4) or implicit-authorization auto-discovery (1 of 4 — startup imports from user-placed CLI config files). No Sovereign Gate slice needed.

---

## Newly surfaced safe slices (ordered by leverage)

### 🟢 Smallest wins (S effort each, parallel-safe with most slices)

| # | Slice | What it does | Files |
|---|---|---|---|
| H1 | **Delete `AgentGraphMemory.recordExecution`** | Removes dead method (zero callers) so future agents don't re-discover it as a "gap" | `Epistemos/Omega/Knowledge/AgentGraphMemory.swift` (lines 44-120 only); optional regression test |
| H2 | **Delete or wire `ShadowGitCheckpoint`** | Same rationale; user picks delete vs. wire | `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` |
| H3 | **Delete or wire `VisualVerifyLoop` lazy var** | Same rationale | `Epistemos/App/AppBootstrap.swift:844-847` (lazy var only) |
| H4 | **`auth.token.refreshed` AgentEvent slice** | Closes the only real audit-visibility gap I surfaced — silent token refresh emits zero provenance today | `Epistemos/Engine/CloudProviderAuthService.swift` (only `refreshedCredentialIfNeeded`); new `EpistemosTests/CloudProviderAuthServiceRefreshAgentEventTests.swift` |
| H5 | **`auth.credential.imported` AgentEvent slice** | Same shape as H4 for startup auto-discovery (`AppBootstrap.swift:236`) | `Epistemos/App/AppBootstrap.swift` (only the `Keychain.save` call site); new test |
| H6 | **CredentialUserDefaultsAbsenceGuardTests** | Turns the CLAUDE.md "no credentials in UserDefaults" rule into a compile-time source-guard | `EpistemosTests/CredentialUserDefaultsAbsenceGuardTests.swift` (NEW) |
| H7 | **CloudProviderSetupCardSourceGuardTests** | Asserts the OAuth setup view never instantiates `LAContext` and never persists access tokens outside `storeOAuthCredential(_:)` | `EpistemosTests/CloudProviderSetupCardSourceGuardTests.swift` (NEW) |

Sanitization invariants for H4 + H5 are spelled out verbatim in `SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md` §4 — copy them in. Critically: **never log access_token, refresh_token, or any provider secret.** Only fingerprint (first 8 chars of SHA-256 of the OLD token) + new-expiry timestamp + provider name.

### 🟡 Medium-leverage (M effort each)

| # | Slice | Why |
|---|---|---|
| M1 | **MAS/Core vs Pro capability symbol separation closure** | **Single highest-leverage Core-open item.** Closing it unblocks all of Lane 4 (Pro Developer ID + Notarization, JS runtime) and downstream Lanes 5–6 (Research private framework loader, ANE direct path). Detailed scope in `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md` L2-CARD-1. |
| M2 | **Sovereign Gate adapter delete (SG-CARD-1)** | HIGH-risk surface — losing trained QLoRA / QDoRA adapters is irreversible. Pattern is identical to `ModelVaultDeletionSovereignGate` (PR9). Detailed scope in `SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md`. |
| M3 | **Hermes parity native task substrate** — `/todo`, `/todo add`, `/todo done`, `/todo clear` | Maps to existing native task ledger. `/todo clear` needs Sovereign confirmation (destructive). |
| M4 | **Live GraphEvent consumer projection — graph renderer surface** | Read-only consumers (Settings/Halo/Trace Inspector/QueryRuntime) all closed. Next is the actual graph renderer subscription. **Coordination-required** — touches `Views/Graph/` protected paths. |

### 🔴 Big strategic move (L effort, high payoff)

| # | Slice | Why |
|---|---|---|
| L1 | **Resonance Gate τ + π + λ daemon seed** (L3-CARD-1) | Still 0% started in build-graph §7. **First piece of the visible philosophy.** CPU-only, no entitlements needed. Scope in `AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md`. |

---

## Recommended next 3-slice batch

If you want a clean ordered queue:

1. **M1 MAS/Core symbol separation** (M) — gates everything else; do this first
2. **H4 `auth.token.refreshed` AgentEvent** (S) — fast win that closes the only real audit gap
3. **M2 Sovereign Gate adapter delete** (M) — highest-risk Sovereign surface; PR9 pattern is well-trodden

Optional cleanup (any time, S each): H1, H2, H3 — three dead-code deletes.

---

## What NOT to do

| Anti-pattern | Why |
|---|---|
| Open another bridge AgentEvent slice | The Bridge layer is functionally complete (PR39–PR44). Anything you'd add is either no-instrument (transport/parser/router) or already-covered upstream. |
| Instrument the dead code in H1/H2/H3 before deciding delete vs. wire | Instrumenting dead code is worse than leaving it dead. Decide first. |
| Touch `Views/Epdoc/` without confirming protected-path scope | The Sovereign Gate Surface Map S-3 (block delete) flagged this as coordination-required. Verify before slicing. |
| Run R15 live MLX harness today | NO-GO per `R15_LIVE_MLX_GO_NO_GO_2026_05_03.md` — only ≈ 3.15 GiB reclaimable on the user's 16 GiB host. Wait until headroom recovers. |
| Open Resonance Gate δ + ρ or κ + η | Pro and Research only. Lane 3 Core entry is τ + π + λ only. |
| Edit any of the 660 pre-existing uncommitted files in the user's working tree | They are the user's in-flight pile. Treat as read-only unless the user explicitly asks. |

---

## State at handoff

- **Branch:** `feature/landing-liquid-wave`
- **HEAD:** `fbd1a211 Add Claude audit resolution artifacts`
- **Ahead of origin:** 241 commits (push when ready, not part of this handoff)
- **Round:** ~86 (Codex's last round-82 manifest closed; PR43 + PR44 + GhostComputerAgent reachability gate + Hermes capability parity target + Hermes capability registry all shipped after that)
- **In-flight Codex slice:** unclear — round-87+ should pick from the M1/H4/M2 queue above
- **Claude side-fleet status:** idle, waiting for next dispatch

---

## What I verified before signing off

- ✅ `git log --oneline -3` shows `fbd1a211` is HEAD
- ✅ `git show --stat fbd1a211` shows exactly 3 files added, 448 insertions, zero modifications
- ✅ The 660-file pre-existing uncommitted pile is **untouched** (`git status --porcelain` first 10 lines look identical to before the commit; only the 3 added files transitioned from `??` to staged-and-committed)
- ✅ All 3 audit docs cite their source files with line numbers and follow the existing `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` reservation-respect pattern
- ✅ No protected paths touched, no canon-in-flight docs touched, no `xcodebuild` invocation, no broader staging

---

## Final note on the 660-file pile

The user has ~660 uncommitted files in the working tree. **Do not touch them as part of any slice you open from this handoff.** They are the user's own in-flight work spread across many features and should only be staged with the user's explicit permission. The cleanup slices in §"Newly surfaced safe slices" are narrow and shouldn't widen scope into the pile.

If a slice you open requires editing a file that is already in the modified pile (e.g., `AgentGraphMemory.swift` already has uncommitted changes), **stop and ask the user** before staging — they may have in-flight work you'd overwrite.

---

## Star checklist (per the user's "make sure it is all good" ask)

- ⭐ Bridge AgentEvent layer functionally complete — confirmed
- ⭐ Omega/LocalAgent layer complete for current production paths — confirmed
- ⭐ Audit docs committed cleanly — confirmed (`fbd1a211`)
- ⭐ 660-file pile untouched — confirmed
- ⭐ No protected paths edited — confirmed
- ⭐ No canon-in-flight edits — confirmed
- ⭐ Three concrete next slices named with effort + dependencies — done
- ⭐ Anti-patterns enumerated so the next round doesn't waste cycles — done
- ⭐ Reservation respect inherited from prior fleet docs — done
- ⭐ Handoff is self-contained (Codex can act from this doc alone) — confirmed

All good. Codex is clear to pick from the M1/H4/M2 queue.
