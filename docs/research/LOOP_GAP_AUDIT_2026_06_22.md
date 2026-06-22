# LOOP GAP AUDIT (2026-06-22) — docs maintenance tracker

Each gap-fill iteration cross-checks: addendum headers ↔ WORK_QUEUE ↔ STRICT prompt ↔ PASTE_READY.

## Iteration 1 — 2026-06-22 (initial deep repair)

### Fixed
| Gap | Fix |
|-----|-----|
| Queue walk order broken (0.11 before 0.9; 2.5 before 2.4) | Renumbered 0.1→0.22, 2.1→2.6 in numeric order |
| Missing queue items | Added 0.17–0.22, 1.4; EML/Eidos in 2.5–2.6 |
| D4 vs TIER 4.1 conflict | Promoted settings to 0.21 TIER-0 blocking; D4/prompt updated |
| STRICT_RECERT_LOG missing | Created stub |
| Stale prompts confuse agent | Marked 2026_06_21 + QUEUE prompts SUPERSEDED |
| No single paste block | Created AGENT_LOOP_PASTE_READY_2026_06_22.md |
| Strict prompt thin vs queue | Added 0.11–0.22 mirror, per-surface screenshots, completeness critic |
| Discovery sweep not indexed | Added to STANDING in queue + prompt |

### Still open (next iterations)
| Gap | Action |
|-----|--------|
| `osa_runtime_2026_06_22.png` missing from repo | Build agent captures on first run; or gap-filler captures if app running |
| Addendum sections not individually indexed | Standing rule: completeness critic adds items; optional TIER items for PROSE EDITOR, AGENT-STACK CONVERGENCE, BUILD-IT-HARDENED, NEVER-IDLE, external ~/Downloads corpus |
| `OSAURUS_BUILD_PROGRESS` may claim done | 0.15 DEEP CHECK must rewrite with honest state |
| Option-(b) sections still in addendum | 0.17 + LOCKED RULES — agent must follow latest DEFINITIVE |

### Addendum sections — indexed vs standing-only

**Indexed in queue:** Epistemos Picks (0.11), all chat surfaces (0.2), surface wiring (0.12), landing/blur (0.3),
ACT=Osaurus (0.17–0.20), per-clone settings (0.21/4.1), EML (2.5), Eidos (2.2/2.6), TRINITY (3.1), Fugu (3.2),
vault/epdoc/motion/dual-build/optimization (T4–5), OpenCode (T1), substrate (2.1).

**Standing / completeness critic (not separate queue rows yet):**
- COMPLETENESS / DISCOVERY-SWEEP MANDATE
- AGENT-STACK CONVERGENCE (dual MLX clash)
- THREE STANDING DIRECTIVES §1 (owner messages → plan)
- BUILD-IT-HARDENED + GO-BACK-AND-UNIFY
- NEVER-IDLE
- PROSE EDITOR + MD-V2 COEXIST
- MORE LOVED ASSETS TO PRESERVE
- MAS sandbox substitute research
- External research corpus ~/Downloads

## Iteration 2 — 2026-06-22 (subagent audit follow-up)
- Added queue **0.23–0.26** (send-text harness standing, act UI bug bundle, gated chat delete, UI-hide)
- Added **4.10–4.11** (Epistemos Picks profiles, test-parity gate), **5.3** (MAS OsaurusCore split)
- Strict prompt: VOID stale plan sections (option-b, WORK ON HOLD); numeric order 0.1→0.26
- SUPERSEDED `SESSION_CONTINUATION_PROMPT_2026_06_21.md`
- `OSAURUS_BUILD_PROGRESS`: provisional banner — do not trust `[x]` until STRICT_RECERT_LOG certifies
- Still open: `osa_runtime_2026_06_22.png` binary (placeholder doc added), northstar PNGs

## Iteration 3 — 2026-06-22 (gap-fill hardening)

### Fixed
| Gap | Fix |
|-----|-----|
| Missing queue: agent-stack / dual MLX | Added **2.7** with →plan AGENT-STACK CONVERGENCE |
| Missing queue: BUILD-IT-HARDENED | Added **2.8** with →plan BUILD-IT-HARDENED + GO-BACK-AND-UNIFY |
| Missing queue: Prose editor coexist | Added **4.12** PROSE EDITOR + MD-V2 COEXIST |
| Missing queue: loved assets | Added **4.13** MORE LOVED ASSETS TO PRESERVE |
| THREE STANDING DIRECTIVES §1 not indexed | Added to STANDING: owner messages → plan+queue |
| FAVOR OSAURUS not in queue | Added to STANDING with →plan ref |
| External ~/Downloads corpus not indexed | Added to STANDING (read-only research) |
| NEVER-IDLE not explicit in standing | Added to STANDING + strict prompt |
| 0.5 per-surface screenshot weak | Strengthened 0.5 text — one PNG per surface |
| Strict prompt 0.11–0.22 only (missing 0.23–0.26) | Extended mirror to 0.26 |
| Audit paragraphs A–G missing from strict prompt | Added MANDATORY BEHAVIOR A–G section |
| FIRST ITERATION jumped queue order | Aligned to walk 0.1→0.26 numeric |
| PASTE_READY stopped at 0.22 | Full 0.1→0.26 table + 14 non-negotiables |
| Addendum §607/§1485/§1507 confuse agent | VOID banners pointing to §1651 + queue 0.17 |
| Landing authority ambiguous | Explicit: Epistemos LandingView FIRST (D2/0.3) in VOID + paste + strict |
| AGENT_DIRECTIVE_CHECK stale | SUPERSEDED redirect to strict recert stack |
| osa_runtime PNG missing | Added osa_runtime_PLACEHOLDER.md with capture instructions |
| STRICT_RECERT_LOG thin header | Added queue/driver/PNG authority refs + iteration 3 log |

### Pre-launch checklist (iteration 3)
| Check | Status |
|-------|--------|
| Queue 0.1→0.26 numeric order | PASS |
| Queue 2.1→2.8 numeric order | PASS |
| All OPEN addendum directives indexed or STANDING | PASS |
| Strict prompt mirrors 0.11–0.26 | PASS |
| Paragraphs A–G in strict prompt | PASS |
| PASTE_READY synced | PASS |
| VOID banners on superseded addendum sections | PASS |
| Stale prompts SUPERSEDED | PASS |
| STRICT_RECERT_LOG header | PASS |
| osa_runtime capture instructions | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures iteration 1) |
| Any queue item `[x]` certified | FAIL (expected — all UNCERTIFIED until agent walks) |

## Iteration 4 — 2026-06-22 (owner feedback: act-only tunnel vision)

### Owner complaint
Build loop was certifying ONLY the act surface (D1–D5 / TIER 0) instead of the ENTIRE multi-feature plan:
all clones (Epistemos|act|work|beyond), companion OFF-LIMITS vs work/beyond in-scope, substrate, inference
routing per clone, settings per clone, work/beyond surfaces, health rows, BUILD-IT-HARDENED, full addendum scope.

### Fixed
| Gap | Fix |
|-----|-----|
| TIER 0 framed as whole plan | Renamed section + banner: act P0 blocking, NOT sole scope; act certified ≠ loop done |
| FIRST ACTION narrowed to act/D1–D5 | Strict prompt + paste: walk 0.1→0.32 then TIER 1→5; no early exit |
| Missing clone queue items | Added **0.27–0.32** (main baseline, work reachable, per-clone routing, beyond/OFF-LIMITS, reverse audit, iteration witness) |
| Missing work certification | Added **1.5–1.7** (work surface cert, per-surface routing, work inference) |
| Missing beyond scope | Added **4.14–4.15** (beyond clones, multi-clone settings polish) |
| 0.21 too thin for per-clone matrix | Expanded to Epistemos\|act\|work\|beyond with per-tab screenshot |
| No FULL-PLAN-NO-ACT-TUNNEL rule | Added to STANDING in queue + strict prompt + paste non-negotiable #1 |
| No reverse addendum audit | Added **0.31** + strict prompt FULL PLAN section + paste #13 |
| Strict prompt lacked clone matrix | Added FULL PLAN CERTIFICATION section with matrix + tier walk |
| PASTE_READY act-only | Synced: 18 non-negotiables, 0.1→0.32 table, SHORT RESUME block, clone matrix |
| MANDATORY BEHAVIOR ended at G | Added **(H) FULL-PLAN-NO-ACT-TUNNEL** |

### Pre-launch checklist (iteration 4)
| Check | Status |
|-------|--------|
| Queue 0.1→0.32 numeric order | PASS |
| Queue 1.1→1.7 numeric order | PASS |
| FULL-PLAN-NO-ACT-TUNNEL in STANDING | PASS |
| Clone matrix in strict prompt + paste | PASS |
| Reverse addendum audit indexed (0.31) | PASS |
| Work/beyond surfaces indexed | PASS |
| Companion OFF-LIMITS vs work/beyond clarified | PASS |
| PASTE_READY PRIMARY + SHORT RESUME | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures) |

### Still open (runtime — build agent)
| Gap | Action |
|-----|--------|
| All queue items uncertified | Agent walks full plan 0.1→5.3 with 5-gate bar |
| `osa_runtime_2026_06_22.png` | Agent captures on first run |
| Prior loops may have act-only `[x]` | All boxes UNCERTIFIED — re-prove from scratch |
