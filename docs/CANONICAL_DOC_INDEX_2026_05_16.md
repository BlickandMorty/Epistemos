# Canonical Doc Index — 2026-05-16

**Purpose:** Master "table of contents" for every canonical doc that any of the 6 parallel terminals MUST consult. Each entry: path · purpose · owner terminal · cross-references · review cadence · drift risk.

**Status:** CANONICAL — living index. Updated when new doctrine emerges or canon shifts. Terminal C maintains.

**Cross-references:**
- `docs/ANTI_DRIFT_SYSTEM.md` (5-layer drift defense — this index IS Layer 4 part 1)
- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` (WRV state machine + promotion protocol)
- `docs/_INDEX.md` (legacy/comprehensive index — defer to that for non-2026-05-16 docs)

---

## §1. The 6 terminal prompts (loop drivers)

| Path | Owner | Cadence | Drift risk |
|---|---|---|---|
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md` | A reads each iter | every iter | HIGH (re-read every loop fire) |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` | B reads each iter | every iter | HIGH |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_C_2026_05_16.md` | C reads each iter | every iter | HIGH |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_D_2026_05_16.md` | D reads each iter | every iter | HIGH |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_E_2026_05_16.md` | E reads each iter | every iter | HIGH |
| `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md` | F reads each iter | every iter | HIGH |
| `docs/AUTONOMOUS_LOOP_UNIVERSAL_INVOCATION_GUIDE_2026_05_16.md` | All terminals; users | once at setup | LOW |

**§5.0 expectation:** every loop iter starts with §3 mandatory reading order. Any drift in these files mid-run breaks autonomy → Terminal C audit-of-audit catches.

---

## §2. Master canonical doctrine (read by all terminals on first touch of subsystem)

| Path | Purpose | Primary owner | Read cadence |
|---|---|---|---|
| `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` | Master plan · §0 immutable rules · §8 Implementation Log · §10 Compromises Recorded | All terminals; A primary, C audit | Every iter (§8 + §10 sections) |
| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` | Wave A-J roadmap · §3 doctrine pillars · §6 wave inventory | All terminals; B primary | First touch of subsystem |
| `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` | Hermes 2.0 architecture · §5 dispatch · §6 4-Tunnel · §7 tool registry · §13 stack | A · D · F primary | First touch of related section |
| `docs/NEW_SESSION_HANDOFF_2026_05_15.md` | Session-start protocol · §10 backlog landscape · §10.10 NOT-STARTED inventory | All terminals on resume | Session start + every 30 iters |

---

## §3. Audit registers (drift-detection source-of-truth)

| Path | Purpose | Primary owner | Update cadence |
|---|---|---|---|
| `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` (PASS-1) | HIGH/MED/LOW-tier rows + Status blocks; L-1..L-5 closed | C maintains; all terminals append Status | Every commit that closes a row |
| `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` (PASS-2) | B2-H/M/L-tier rows · §9 Audit-of-audit register (cycles #1-#10 as of 2026-05-16 iter 83; including the iter-74 [DRIFT-ALERT] cycle #8 + #8-continuation iter-75 + #8-follow-up iter-76 documenting Trust-but-verify lesson #6 + lesson-#6 sweep · cycle #9 J1 portfolio close + #10 J2 open / canonical-flow infrastructure) · §10 Phase Completion Ledger | C maintains | Every audit-of-audit cycle |
| `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` | ~242 RCA/UIX rows; ~30 CONFIRMED + 6 TODO at session start | A primary (closes bugs); C audits | Every bug-fix commit |
| `docs/APP_ISSUES_AUTO_FIX.md` | 30 Open opportunistic runtime fixes | A primary | Per-fix commit |
| `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` | Codex's recursive fix protocol (10 rules); P0 Wave 0 vault lifecycle blocker | A reference | Reference (don't modify) |

---

## §4. Anti-drift + hardening canonical docs (existing canon — DO NOT duplicate)

| Path | Purpose | Status |
|---|---|---|
| `docs/ANTI_DRIFT_SYSTEM.md` | 5-layer defense against LLM drift (compaction · attention decay · satisficing) | CANONICAL ✓ |
| `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` | WRV state machine + canon promotion protocol | CANONICAL ✓ |
| `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` | Codex's drift audit findings + recommended mitigations | CANONICAL ✓ |
| `docs/HARDENING_VERIFICATION.md` | Hardening verification commands + acceptance bars | CANONICAL ✓ |
| `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` | Master hardening + test harness plan | CANONICAL ✓ |
| `docs/V1_5_IMPLEMENTATION_TRACKER.md` | V1.5 R14-R16 + W9.6-W9.30 status board | CANONICAL-OPERATIONAL ✓ |

**Drift discipline:** Terminal C MUST cross-reference these on each audit-of-audit cycle. Never rewrite; only update Status when new evidence emerges.

---

## §5. New parallel-run tracking docs (2026-05-16)

These complement §4 with parallel-run-specific tracking:

| Path | Purpose | Status |
|---|---|---|
| `docs/HARDENING_TRACKER_2026_05_16.md` | Phase 2 hardening checklist per shipped feature | LIVING |
| `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` | Every feature shipped by any terminal + which canonical docs were updated | LIVING |
| `docs/PARALLEL_PROCESS_LIST_2026_05_16.md` | What's running where (terminals · CI · background tasks · browser tabs) | LIVING |
| `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md` | How the 6 terminals + CI + browser research flow into a coherent system | CANONICAL |
| `docs/CANONICAL_DOC_INDEX_2026_05_16.md` | THIS doc — master index | CANONICAL |

---

## §6. Research corpus (read before coding any new feature)

| Path | Purpose | Read cadence |
|---|---|---|
| `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | Concept-to-canonical-source map · every concept / subsystem has a primary canonical source listed | Every new feature slice |
| `~/Documents/Epistemos-QuickCapture/PLAN.md` (245 KB) | External master plan | First touch of related area |
| `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` (53 KB) | External synthesis | First touch |
| `~/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (68 KB) | Live Files V1.1+ research | When B works on Live Files |
| `~/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` (63 KB) | Obscura Pro-only research | When user-decision B-2 answered |
| `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB) | Brain export + Tamagotchi research | When B works on B.7 |

---

## §7. CI + drift workflows

| Path | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Master CI on main + PRs (existing — 17 KB, comprehensive) |
| `.github/workflows/ci-parallel-branches.yml` | Per-run-* branch CI |
| `.github/workflows/drift-detection.yml` | Every-6h §5.0 claim verification + cross-link integrity |
| `.github/workflows/lint.yml` | Existing lint pipeline |
| `.github/workflows/release.yml` | Existing release pipeline (MAS submission) |

---

## §8. Where to find the architecture-of-the-architecture

Top-level authority chain (highest to lowest):
1. **`CLAUDE.md`** (project-rules; always loaded) → 60-80% reliable adherence (per ANTI_DRIFT_SYSTEM Layer 1)
2. **`docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §0** (immutable rules 1-8 + lockstep rules)
3. **`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`** (architectural roadmap)
4. **`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`** (Hermes 2.0 architecture)
5. **Specific subsystem doctrine** (e.g., `XPC_MASTERY_DOCTRINE` · `COGNITIVE_DAG_DOCTRINE` · etc.)
6. **Salvage corpus** (`docs/fusion/salvage/` — last-resort source-of-truth when 2-5 are silent)

---

## §9. Update protocol for this index

When new canonical doctrine emerges:
1. Determine if it's NEW canon or extending existing canon
2. If NEW: add row in appropriate section (§2, §3, §4, §5, §6, §7)
3. If extending existing: update existing row's Status / cadence / cross-references
4. Update §9 audit-of-audit cycle in PASS-2 to note the index change
5. Push commit; Terminal C verifies on next cycle

---

*Living index. Owner: Terminal C (cross-terminal audit). Read cadence: every audit-of-audit cycle (every 3-5 commits across all terminals).*
