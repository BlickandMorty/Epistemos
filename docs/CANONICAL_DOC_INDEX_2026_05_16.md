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
| `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` (PASS-2) | B2-H/M/L-tier rows · §9 Audit-of-audit register · §10 Phase Completion Ledger | C maintains | Every audit-of-audit cycle |
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
| `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` | V6.1 research synthesis (implementation doc + Foundation Doc) integrated into 6-terminal cocktail | **CANONICAL — read at session start** |
| `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` | Phases 1-7 unified Rust kernel doctrine | CANONICAL ✓ |
| `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` | Phase 8 typed content-addressed Merkle-rooted Cognitive DAG | CANONICAL ✓ |
| `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` | Foundational doctrine (referenced) | CANONICAL ✓ |
| `docs/fusion/helios v5 first.md` + `helios v5 updated.md` | V5 substrate (LANDED 2026-05-06) | CANONICAL ✓ |
| `docs/fusion/helios v6.2.md` | V6.2 strict V6.1 superset | CANONICAL ✓ |

---

## §5.5 V6.1 / 70B-Local-Cocktail research corpus (the user's end-game vision substrate)

These docs are referenced by V6.1 integration §1.13 (Phase B.0-LARGE F-70B-Local-Cocktail):

| Path | Purpose | Status |
|---|---|---|
| `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md` | Autopoietic Cognitive Stack — Maturana-Varela organizational closure + Stafford Beer VSM + Kauffman attractors + Kuramoto-coupled cellular resonance + SiliconSwarm 6.31× speedup; the recursive "transistor to ecosystem" pattern | CANONICAL research-tier |
| `docs/_consolidated/50_research_corpus/mass_research/Architectural Hardening_ Total Victory Plan.md` | **Unified Address Space (UAS)** doctrine — zero-copy FFI + HNSW + usearch + Swift/Rust/Metal/MLX in ONE address space | CANONICAL (UAS is the load-bearing primitive for B.0-LARGE) |
| `~/Downloads/EPISTEMOS_V6_1_FINAL_SYNTHESIS_LOCK.md` | V6.1 Final Synthesis — 5-plane formalism · interrupt-score equation · attention-as-interrupt thesis · donor-distillation ramp · Goodfire VPD CONFIRMED-PUBLIC · 5 load-bearing kernels · 32 new nuance items (166-197) | CANONICAL lock |
| `~/Downloads/EPISTEMOS_HELIOS_v4_1_AMENDMENTS.md` | V4.1 amendments — `eml_star` preservation ledger + M3 Ultra Mac Studio 256GB correction + tools-rejected appendix (nanowhale + ml-intern HARD NO with 4-gate discipline) | CANONICAL amendment |
| `~/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md` | Hermes Agent Creative Hackathon manifesto — substrate-core slotmap entity graph + 6-verb MCP surface + skills-as-nodes + loop profiles + schema-driven UI + WKWebView built-in browser | CANONICAL (Hackathon vision, pre-purge — naming-reconciliation context per CLAUDE.md "Hermes parity not Hermes agent") |
| `docs/fusion/helios v5 first.md` + `docs/fusion/helios v5 updated.md` | V5 substrate doctrine (LANDED 2026-05-06) — W1-W26 + E1-E7 + H1-H17 + PCF-1..10 | CANONICAL substrate |
| `docs/fusion/helios v6.2.md` | V6.2 strict V6.1 superset — 8-stage V6_2_FALSIFIER_ORDER · M2Pro16Gb hardware lock | CANONICAL delta |
| `docs/fusion/jordan's research/ternary kernel.md` | Three ternary backends (Dense MLX baseline / BitNet reference truth / Ternary Metal breakthrough) | CANONICAL ternary research |
| `docs/fusion/jordan's research/SCOPE_REX_GATE_REGISTER_2026_05_01.md` | SCOPE-Rex gate register | CANONICAL governance |
| `docs/fusion/jordan's research/scope rex.md` + `scope rex omega.md` | SCOPE-Rex MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog doctrine | CANONICAL governance |
| `docs/fusion/jordan's research/deterministicapp.md` | Deterministic app doctrine — confidence floors + escalate_on_empty + LadderLog → Provenance Console | CANONICAL deterministic-output doctrine |
| `docs/fusion/jordan's research/CODEX_SCOPE_REX_SUBSTRATE_PROMPT_2026_05_01.md` + `CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30 (1).md` | Codex execution prompts for SCOPE-Rex substrate + unified execution | CANONICAL build prompts |
| `epistemos-research/src/acs.rs` (190 LOC, in tree) | AcsAnchor + CmsXField constitutive field — Episodic plane substrate (V5 W6-W8 lift) | EV (verified in main + runE worktrees) |
| `agent_core/src/scope_rex/kv/direct_gate.rs` (290 LOC, in tree) + `Epistemos/Shaders/kv_direct_gate.metal` (65 LOC) | KV-Direct Tier-1 BIT-IDENTICAL contract substrate | EV (commits 99cab68c1 + b970f98fe) |
| `~/Downloads/master resarch here/EPISTEMOS_HELIOS_MASTER_ARCHIVE_2026_05_05_PRESERVATION_BUNDLE/` | Full preservation bundle — raw prompts appendix + original uploads + supporting research | CANONICAL archive |
| `~/Downloads/final/last round of thinking/Epistemos Architecture Consensus & Disruption.txt` + `compass_artifact_*.md` (multiple) | External consensus + disruption analyses across 6 independent reasoners (the convergence-as-signal evidence in V6.1 lock §1) | CANONICAL convergence evidence |
| `~/Downloads/final/executive sumaries/epistemos-rival-doctrine.md` + `gpt deep.md` + `deeper research from gpt.md` | Executive summaries (rival doctrine + GPT deep research) | CANONICAL competitive analysis |

**Drift discipline:** these are the user's end-game vision substrate. Phase B.0-LARGE (F-70B-Local-Cocktail) unifies them into one falsifiable gate. Terminal C MUST cross-reference these on each audit-of-audit cycle when B.0-LARGE work appears.

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
