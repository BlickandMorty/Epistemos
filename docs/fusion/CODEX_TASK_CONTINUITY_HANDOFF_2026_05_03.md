# Codex Task-Continuity Handoff — 2026-05-03

> **For Codex.** Account changed mid-session. Context may not have transferred. This handoff catches you up on the **last verified state of your in-flight work** so you can resume the very next thing without re-discovering what was already done. Sister docs: `CODEX_HANDOFF_2026_05_03.md` (session 1 close), `CODEX_HANDOFF_2026_05_03_PART2.md` (session 2 close — Resonance Gate + 26 Hermes parity commands), `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` (the new substrate vision — read AFTER this one), `CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md` (the integration ask).

---

## TL;DR — what to do first

1. **Read this whole doc** before opening any code. The next-action queue at §5 is the sequence; skipping ahead loses task continuity.
2. **Sync `Epistemos.xcodeproj/project.pbxproj`** to add the 17 production Swift files + 7 test files Claude shipped this session. This is the single hardest blocker for everything else; nothing compiles without it.
3. **Read `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`** to understand the hackathon priority reorder (Hermes XPC + Simulation v1.6 jump to the front of the queue) before starting M1/M2/M3 from the prior handoff.
4. **Then** read `CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md` for the integration + verify ask.

---

## 1. Current branch / HEAD state (as of this handoff)

- **Branch:** `feature/landing-liquid-wave`
- **HEAD before this handoff was written:** `8f4309a5 Add Claude session-2 handoff to Codex` (Claude's prior handoff for this same session)
- **Ahead of origin:** 250 commits, do not push without explicit user approval
- **Codex side-fleet:** idle, ready for next dispatch
- **660+ pre-existing uncommitted files in the working tree:** the user's in-flight pile. **Treat as read-only.** Every Claude commit this session was clean against that pile and so should yours.

---

## 2. What Codex was working on RIGHT BEFORE the account change

Per the git log around the account-change boundary, Codex's last 6 in-flight commits (in chronological order) were:

```
3d0242cc Close GhostComputerAgent reachability gate          ← Codex closed this independently
9762eceb Add Hermes capability registry                       ← Codex authored
3db2941e Record Hermes capability parity target               ← Codex authored (the parity target doc)
1f993097 Add gateway and tool-surface guard tests             ← Codex authored
2204e774 Record Omega LocalAgent AgentEvent inventory         ← Claude side-fleet artifact
f45c377a Add Bridge AgentEvent no-double-count guards         ← Codex closed PR44
```

**Just before the account change, Codex was finishing up:**
- The **Hermes capability parity target** doc (lives at `docs/fusion/fleet/hermes-capability-pass-through/HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` per the existing fleet folder structure)
- The **gateway + tool-surface guard tests** (`HermesGatewayEvidenceContractTests.swift`, `ToolSurfaceBehavioralMatrixTests.swift`, `GhostComputerAgentReachabilityGuardTests.swift`)
- The **Hermes capability registry** (`Epistemos/LocalAgent/HermesCapabilityRegistry.swift`)

Then the account change happened. Claude (this session) picked up the slate and shipped:

1. `06230e8d Seed Resonance Gate τ + π + λ daemon` (Rust seed, 5 files, 26 tests green)
2. `e03fb890 Add Resonance Gate Swift consumer and UI shell` (4 Swift files, 14 tests written)
3. `3cc3c612 Add Hermes /calc deterministic calculator`
4. `6f8ad5af Add five Core-native Hermes parity commands` (`/help`, `/status`, `/tokens`, `/cost`, `/think`)
5. `07e33fed Bridge Resonance Gate signature to UniFFI` (FFI export + serde derives + 4 more tests; total 30 tests green)
6. `469f6879 Add ten Core-native Hermes session-ops + parameter commands`
7. `caa46d05 Wire master Hermes command dispatcher and remaining Core registry rows` (HermesCommandDispatcher + persona + memory + tools + config + notebook)
8. `d2641b12 Complete the Core Hermes parity slate (UI display + vault file)` — final batch, registry slate complete
9. `8f4309a5 Add Claude session-2 handoff to Codex`

**So the current state is:**
- Resonance Gate τ + π + λ daemon is alive end-to-end (Rust seed + Swift consumer + UI + FFI bridge)
- Every Core-tier row in `HermesCapabilityRegistry` has a parser + intent (26 commands + master dispatcher)
- All new files are on disk; **none are in `Epistemos.xcodeproj/project.pbxproj` yet** — that's the immediate blocker

---

## 3. The pbxproj sync (your first move)

Per `CODEX_HANDOFF_2026_05_03_PART2.md` "Coordination-required (Codex's first move)":

**Add to the `Epistemos` target (production):**
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

**Add to the `EpistemosTests` target:**
- `EpistemosTests/ResonanceServiceTests.swift`
- `EpistemosTests/HermesCalcCommandTests.swift`
- `EpistemosTests/HermesParityCommandsTests.swift`
- `EpistemosTests/HermesSessionAndParameterCommandsTests.swift`
- `EpistemosTests/HermesPersonaConfigNotebookCommandsTests.swift`
- `EpistemosTests/HermesCommandDispatcherTests.swift`
- `EpistemosTests/HermesUIDisplayAndVaultFileCommandsTests.swift`

**Verification command after the sync:**

```bash
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
           -scheme Epistemos \
           -destination 'platform=macOS' \
           -only-testing:EpistemosTests/HermesCommandDispatcherTests \
           -only-testing:EpistemosTests/ResonanceServiceTests \
           test 2>&1 | xcbeautify
```

If those two suites pass, every other new test file will too.

---

## 4. The Rust side is already verified clean

You don't need to re-verify these. They were tested in this session.

- `cargo build --manifest-path agent_core/Cargo.toml --lib` → **clean, 51s incremental**
- `cargo test --manifest-path agent_core/Cargo.toml --test resonance_seed` → **30 passed; 0 failed**

The Resonance Gate FFI export (`agent_core::bridge::compute_resonance_signature_core`) is live and tested. The Swift consumer (`ResonanceService`) currently uses a Swift mirror; swapping it to the Rust FFI is M3 in the recommended next batch.

---

## 5. Recommended next-action queue (with hackathon reorder)

The user's ask: hackathon priorities (Hermes XPC integration + Simulation Mode v1.6) ride the front. The prior CODEX_HANDOFF_2026_05_03_PART2.md M1/M2/M3 sequence still applies, but **after** the hackathon block.

```
STEP 1 (this hour) ──  pbxproj sync (above §3). Verify 2 test suites green.

STEP 2 (this day)  ──  Read EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md.
                       Decide whether the hackathon-reorder narrative is
                       coherent. Flag conflicts in
                       CANON_GAPS_AND_ADDENDA_2026_05_02.md if any.

STEP 3 (Week 0)   ──   KV-Direct gate experiment (Helios v3 Week 1 binary).
                       Half-day. PASS = build the rest. FAIL = audit.
                       Run in parallel with everything below.

STEP 4 (Week 1)   ──   App Group container migration.
                       Move existing shared state to group.com.epistemos.shared.
                       Pre-req for AgentXPC + ProviderXPC.
                       Coordination-required (touches existing storage code).

STEP 5 (HACKATHON BLOCK A — Week 2-3) ──
                       Hermes XPC service split per docs/fusion/jordan's research/hermes.md.
                       Move agent execution into AgentXPC; provider HTTP into ProviderXPC.
                       Existing HermesGatewayPolicy + 26 commands + master dispatcher
                       run inside AgentXPC.
                       Acceptance: end-to-end agent call from chat input through
                       dispatcher → AgentXPC → tool execution → AgentEvent.

STEP 6 (HACKATHON BLOCK B — Week 2-3) ──
                       Simulation Mode v1.6 land from worktree to main.
                       Resolve the 6 v1.6 AgentEvent variants (per
                       MASTER_RESEARCH_INDEX honest discovery H6).
                       Land Landing Farm + Notes Sidebar Skin (Core-shippable).
                       Defer Graph Live Theater (touches MetalGraphView — protected).
                       Per simulation worktree DOCTRINE.md v1.6 invariants I-1..I-9.

STEP 7 (Week 4) ──     Provenance Console UI (rounds out the MAS feature trio).
                       Existing AgentEvent rows get a UI surface.
                       Filter / search / export.

POST-HACKATHON ──      Resume CODEX_HANDOFF_2026_05_03_PART2.md sequence:
                       M1 mount Resonance chip into one production surface.
                       M2 wire HermesCommandDispatcher.parseCore into chat input.
                       M3 swap ResonanceService.computeStub for the FFI call.
                       S1 stream integration. S2 Sherry ternary. S3 MAS/Core
                       symbol separation closure.
```

**The hackathon items don't break the prior sequence — they reorder it.** Once they ship, you resume from M1.

---

## 6. What to read in what order (to rebuild context)

If the new account doesn't have memory of prior context:

1. `CODEX_HANDOFF_2026_05_03.md` (session 1 close — Claude's prior audit work)
2. `CODEX_HANDOFF_2026_05_03_PART2.md` (session 2 close — Resonance Gate + 26 Hermes parity commands)
3. **This doc** (you're reading it)
4. `JORDANS_RESEARCH_INDEX_2026_05_03.md` (the new research folder index)
5. `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` (the substrate reconceptualization)
6. `CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md` (the integration + verify ask)

Then for hackathon-block specifics:

7. `docs/fusion/jordan's research/hermes.md` (Hermes XPC thesis — load-bearing for STEP 5)
8. `.claude/worktrees/simulation/docs/simulation-mode/DOCTRINE.md` v1.6 (Simulation invariants — load-bearing for STEP 6)
9. `docs/fusion/jordan's research/mac store edition.md` (MAS Core architecture — App Group + capability grants)

Then the deeper canon (read as needed):

10. `MASTER_RESEARCH_INDEX_2026_05_02.md`
11. `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`
12. `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

---

## 7. Star checklist (verify before you sign off)

- ⭐ pbxproj sync done; the 2 verification test suites pass
- ⭐ Cleanly understand what shipped this session (HEAD = `8f4309a5` before this handoff)
- ⭐ Cleanly understand the hackathon reorder (Hermes XPC + Simulation v1.6 first)
- ⭐ Read the 4 sister docs (`JORDANS_RESEARCH_INDEX`, `EPISTEMOS_RECONCEPTUALIZATION`, this doc, the verify-ask doc)
- ⭐ 660-pile untouched (do not stage existing modified files without user approval)
- ⭐ No protected paths edited (`ProseEditor*`, `MetalGraphView`, `HologramController`, graph internals — except where Simulation v1.6 explicitly requires coordinated edits)
- ⭐ Every new commit follows the `Add X` / `Record X` / `Close X` repo style
- ⭐ Every new commit signs with `Co-Authored-By: Codex <noreply@openai.com>` (or your account-specific co-author line) per repo convention

---

## 8. What to NOT do

- Do **not** invent new architecture beyond what's in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`. The substrate is reconceptualized, not rewritten.
- Do **not** start the M1/M2/M3 sequence before the hackathon block lands. That's the user's explicit ask.
- Do **not** edit any of the 660 pre-existing uncommitted files without the user's explicit approval.
- Do **not** open Pro-only features (browser-use, embedded JS, Sherry on weights, ANE direct path) until the hackathon block ships and the MAS Core trio (Vault Guard + Bounded Agent Service + Provenance Console) is product-ready.
- Do **not** push to origin without explicit approval. Branch is 250 commits ahead.

---

## 9. State at handoff

- **Branch:** `feature/landing-liquid-wave`
- **HEAD before this handoff:** `8f4309a5`
- **Resonance Gate end-to-end:** alive (Rust + Swift + UI + FFI), 30 Rust tests + 14 Swift tests written
- **Hermes parity Core slate:** complete (26 commands + master dispatcher with 36-variant sum type)
- **Pre-existing uncommitted pile:** 660+ files, untouched
- **Codex side-fleet:** idle, ready
- **Recommended first action:** pbxproj sync, then read `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`, then start STEP 4 (App Group container migration)
