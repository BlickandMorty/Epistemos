# Parallel Flow Doctrine — 2026-05-16

**Purpose:** Define how 6 autonomous terminals + CI + browser research + user-decisions + cron pacing all flow into a coherent feature-then-harden development process. Cross-reference: `docs/ANTI_DRIFT_SYSTEM.md` (5-layer drift defense — this doc operationalizes Layer 4 for the parallel run).

**Status:** CANONICAL — read by every terminal as part of §3 mandatory reading (added via §5.7 of each prompt).

---

## §1. The phase boundary — Feature-first, Harden-later

### Phase 1: Feature Build (CURRENT — 2026-05-16 onward)

Every terminal operates with **shallow-but-shipped** discipline:

- ✅ Research-first per `CLAUDE.md` RESEARCH-FIRST FOR EVERY TASK
- ✅ Test-first per `CODEX_RECURSIVE_FIX_PROMPT §7` (write failing test before product code)
- ✅ Minimal-fix per §8 (no broad refactors during Phase 1)
- ✅ §5.0 verification per each terminal's §4
- ✅ Acceptance: happy path works · ONE test green · §8 row appended
- ⚠️ Tolerated: known TODOs · partial test coverage · suboptimal perf · weak edge-case handling
- ❌ NOT tolerated: silently broken features · undocumented decisions · drift between doctrine + code

**Goal:** ship every V1 feature + post-V1 substrate as fast as parallelism allows.

### Phase 2: Hardening Sweep (POST-V1 ship)

Once Terminal A reaches §0 victory (V1 MAS + Pro Developer ID ready), trigger Phase 2:

- 🔒 Security audits per `HARDENING_VERIFICATION.md`
- ⚡ Performance — Instruments runs (H-1 / H-2 already queued in user-decision queue)
- 🧪 Edge cases · fuzzing · property-based tests
- ♿ Accessibility (VoiceOver · Dynamic Type · reduce-motion · color contrast)
- 🌍 i18n framework wired (English-only ships first)
- 📚 Doc polish · user-help · onboarding · error message quality
- 📈 Bench coverage `cargo bench` for hot paths
- 🚀 CI hardening — matrix builds · cross-version

Per-feature hardening checklist lives in `docs/HARDENING_TRACKER_2026_05_16.md`.

### Phase 3: Sustaining

Ongoing security · provider API drift · macOS compat · etc.

---

## §2. The 6 parallel agents

```
┌─────────────────────────────────────────────────────────────────────┐
│                       PARALLEL AGENT FLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Terminal A ──┐                                                     │
│   (V1 ship)    │                                                     │
│                ├──→ codex/research-snapshot-2026-05-08 → main        │
│   Terminal B ──┘                                                     │
│   (post-V1)         run-b-post-v1-research                           │
│                                                                      │
│   Terminal C ←──────── audits all sibling commits ────── flags drift │
│   (audit)             run-c-audit                                    │
│                                                                      │
│   Terminal D ──→ run-d-providers (providers · MCP · tools)           │
│   Terminal E ──→ run-e-decisions (user-decision research)            │
│   Terminal F ──→ run-f-integrations (channels · iMessage · OpenClaw) │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

Each terminal:
- Lives in its own `git worktree`
- Has strict file ownership per its §2
- §1.5 scope boundary forbids bleed into sibling work
- §1 invariant check at every iter (fails loud if wrong path or branch)
- Reads canonical doctrine via §3 mandatory reading order

---

## §3. Information flow channels

### 3a. Direct branch push (canonical write path)
Each terminal writes ONLY to its own branch via `git push origin <branch>`. Other terminals read via `git fetch --all`.

### 3b. Periodic merge (every 20 iters or phase boundary)
Each non-A terminal pulls `origin/codex/research-snapshot-2026-05-08` (A's V1 ship surface) periodically per §13 of its prompt. Downmerge happens via user-direct merge (not auto).

### 3c. Append-only shared files
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log` — every terminal appends rows; never deletes
- `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` — every terminal logs feature changes
- `docs/HARDENING_TRACKER_2026_05_16.md` — every terminal logs Phase 2 hardening items
- `docs/legal/licenses.md` — lockstep when deps change

### 3d. Audit findings (Terminal C → others)
Terminal C never modifies sibling code. Instead it writes audit rows in PASS-2 §9 register. Other terminals read on `git fetch` + their next iter's §3 ritual surfaces findings.

### 3e. User-decision pipeline
- Terminal E surfaces decision-ready docs in `docs/audits/user-decisions/`
- User reads + answers (via chat to coordinator terminal or direct edit)
- Coordinator writes answer to E's worktree
- E handoffs to owning terminal (A/B/D/F) on next iter
- Owning terminal picks up as implementation slice

### 3f. CI feedback (GitHub Actions → all terminals)
- Push to any run-* branch triggers `ci-parallel-branches.yml`
- Drift workflow runs every 6h on main
- CI failures show in GitHub UI; terminals don't auto-react (manual user direction)

### 3g. User override channel
Per each prompt's §3 step 0 (after §5.6 update):
```
0. Check /Users/jojo/Downloads/Epistemos-runX/CONTROL.md — if present, follow exactly. User/coordinator override.
```

---

## §4. Anti-drift discipline (per ANTI_DRIFT_SYSTEM.md mapping)

| Layer (ANTI_DRIFT_SYSTEM) | Implementation in parallel run |
|---|---|
| **Layer 1: CLAUDE.md (always in context)** | Project-level rules; every terminal reads via Claude Code's auto-load |
| **Layer 2: Inline reminders in long specs** | §1.5 SCOPE BOUNDARY in every prompt + §0 immutable rules in MAS_COMPLETE_FUSION |
| **Layer 3: Per-iter §5.0 reconciliation gate** | Every terminal's §4 mandates §5.0 before any slice |
| **Layer 4: Audit-of-audit cycles** | Terminal C every 3-5 commits + ci-parallel-branches workflow |
| **Layer 5: Periodic external verification** | `drift-detection.yml` every 6h + user audits via this doc |

---

## §5. Canonical lockstep rules (CI-enforced)

From `MAS_COMPLETE_FUSION §0` + extensions:

1. **ResidencyLevel (B2-M12)**: doctrine + code together
2. **ACS (B2-M13)**: doctrine + code together
3. **New Cargo workspace crates (B2-M15)**: doctrine + code + `docs/legal/licenses.md` together
4. **XPC entitlement changes**: `.entitlements` + Info.plist + provisioning profile + MAS_APP_REVIEW_NOTES + codesign verify test, all same commit
5. **New feature (any terminal)**: code + test + §8 row + FEATURE_CHANGE_TRACKER row, all same commit (Phase 1)
6. **Hardening pass on feature (Phase 2)**: hardening commit + HARDENING_TRACKER checklist update, same commit

CI workflows verify (1)-(4); (5)-(6) verified by Terminal C audit.

---

## §6. Drift patterns observed in run 2026-05-16 (to actively detect)

Per audit-of-audit cycles #1-#7:

1. **HELIOS V5/Wave 9 substrate drift** — doctrine claims missing when full substrate landed
2. **Forward cross-link gaps** — substrate in main but doctrine destination missing cross-link
3. **Code-completion races already shipped** — earlier iter committed substrate but didn't update audit row
4. **Naming-drift code↔doctrine** — code uses `L4Engram` but doctrine uses `L4 Network Cascade`
5. **Partial-substrate framed as NOT-STARTED** — 949 LOC in main but doctrine claims absent (iter-63 NightBrain catch)

**Mitigation:** every §5.0 verification step in every terminal MUST do a live disk read before doctrine claim. Pattern: §3 state-check + §4 §5.0 reconciliation gate.

---

## §7. When all 6 terminals converge

Convergence points (manual checkpoints user triggers):
- **Weekly status sync** — user reads §8 Implementation Log + PASS-2 §10 Phase Completion Ledger + this doc's status
- **Phase boundaries** — A reaches §0 victory → trigger Phase 2 hardening across all terminals
- **User-decision unblocks** — E surfaces decision → user answers → owning terminal picks up
- **CI failures** — user investigates + directs corrective action

---

## §8. Cross-references

- `docs/ANTI_DRIFT_SYSTEM.md` — 5-layer drift defense (canonical)
- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — WRV state machine + canon promotion
- `docs/CANONICAL_DOC_INDEX_2026_05_16.md` — master doc index
- `docs/HARDENING_TRACKER_2026_05_16.md` — Phase 2 per-feature checklist
- `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` — every feature shipped + docs updated
- `docs/PARALLEL_PROCESS_LIST_2026_05_16.md` — process inventory
- `docs/AUTONOMOUS_LOOP_UNIVERSAL_INVOCATION_GUIDE_2026_05_16.md` — invocation guide
- Each of the 6 V3 TERMINAL prompts

---

*Living doctrine. Owner: Terminal C primary; all terminals read via §3 mandatory reading. Updates require audit-of-audit cycle to surface drift.*
