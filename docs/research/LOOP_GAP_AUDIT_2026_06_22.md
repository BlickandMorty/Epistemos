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
| P0 CLASSIFY shared-vs-chat-only not indexed | Extended **0.9** with →plan CLASSIFY shared-vs-chat-only |
| Graph-deep-integration pillar missing | Added **4.16** graph-deep-integration |
| FULL-CLONE PROCESS not in standing | Added STANDING entry with →plan 🔒 FULL-CLONE PROCESS |
| bd7717bc subagent commit | **Not found** — continued from iteration-3 partial + owner mandate |
| Tier 4 end in strict prompt | Updated 4.1→**4.16** in tier walk |

### Reverse addendum audit (iteration 4 grep)
| Addendum section | Queue index |
|------------------|-------------|
| ALL CHAT SURFACES | 0.2, 0.5, 1.6 |
| PER-CLONE SETTINGS | 0.21, 0.27, 4.1, 4.15 |
| BUILD-IT-HARDENED | 2.8 |
| DEFINITIVE ACT-UI | 0.17 |
| WORK ENGINE ARCH C | 1.3, 0.29, 1.7 |
| MAS / DUAL-BUILD | 5.1, 5.3, 4.8 |
| FULL-CLONE PROCESS | STANDING |
| CLASSIFY shared-vs-chat-only | 0.9 |
| deep graph integration | 4.16 |
| COMPANION backend | 0.30 OFF-LIMITS + STANDING |

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
| PASTE_READY PRIMARY certifies FULL PLAN | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures) |

### Still open (next 3m tick / build agent)
| Gap | Action |
|-----|--------|
| All queue items uncertified | Agent walks full plan 0.1→0.32 then TIER 1→5 with 5-gate bar |
| `osa_runtime_2026_06_22.png` | Agent captures on first run |
| Prior loops may have act-only `[x]` | All boxes UNCERTIFIED — re-prove from scratch |
| `OSAURUS_BUILD_PROGRESS` may claim done | 0.15 DEEP CHECK rewrites honestly |
| Build agent may still tunnel on act | Enforce 0.32 witness + owner paste block each iteration |
| Northstar PNGs | Optional visual refs |

## Iteration 5 — 2026-06-22 (reverse-audit + 0.32 hard gate + tier tables)

### Reverse addendum audit (iteration 5 grep)
| Addendum section | Queue index |
|------------------|-------------|
| ALL CHAT SURFACES | 0.2, 0.5, 1.6, 4.16 ✓ |
| PER-CLONE SETTINGS / BEYOND | 0.21, 0.27, 0.30, 4.1, 4.14, 4.15 ✓ |
| BUILD-IT-HARDENED | 2.8 ✓ |
| DEFINITIVE ACT-UI | 0.17 ✓ |
| WORK ENGINE ARCH C | 1.3, 0.28, 0.29, 1.7 ✓ |
| MAS / DUAL-BUILD | 5.1, 5.3, 4.8 ✓ |
| FULL-CLONE PROCESS | STANDING ✓ |
| CLASSIFY shared-vs-chat-only | 0.9 ✓ |
| deep graph integration | 4.16 ✓ |
| COMPANION backend | 0.30 OFF-LIMITS + STANDING ✓ |
| ⏫ PRIORITY finish ACT before WORK | STANDING (within TIER 0 only; does NOT cancel TIER 1+ walk) ✓ |
| **OPENCODE HEAVINESS MITIGATION** | **NEW 1.8** (was unindexed) |

### Fixed
| Gap | Fix |
|-----|-----|
| OPENCODE heaviness mitigation unindexed | Added **1.8** (lazy-launch, loopback-only, kill-on-idle, no Electron, SwiftTerm TUI) |
| 0.32 witness too weak for act-tunnel | HARD GATE: mandatory log block + forbidden end-claims in queue, strict prompt (H), paste #13 |
| 0.31 grep missing WORK/BEYOND | Extended grep list in queue 0.31 + strict prompt reverse audit |
| PASTE_READY tier walks implicit only | Added explicit NON-OPTIONAL tables: TIER 1 (1.1→1.8), TIER 2 (2.1→2.8), TIER 4 (4.1→4.16) |
| ACT-before-WORK priority ambiguous vs full-plan | STANDING clarifies: preempts WITHIN TIER 0 only, not TIER 1+ skip |
| TIER 1 end was 1.7 | Updated to **1.8** in strict prompt + paste clone matrix + tier walk |

### Pre-launch checklist (iteration 5)
| Check | Status |
|-------|--------|
| Queue 0.1→0.32 numeric order | PASS |
| Queue 1.1→1.8 numeric order | PASS |
| Queue 2.1→2.8 numeric order | PASS |
| Queue 4.1→4.16 numeric order | PASS |
| FULL-PLAN-NO-ACT-TUNNEL in STANDING | PASS |
| 0.32 HARD GATE (forbidden end-claims) | PASS |
| Reverse audit grep includes WORK/BEYOND | PASS |
| OPENCODE heaviness indexed (1.8) | PASS |
| PASTE_READY tier walks 1.1→1.8, 2.1→2.8, 4.1→4.16 NON-OPTIONAL | PASS |
| Clone matrix + 18 non-negotiables synced | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures) |
| Any queue item `[x]` certified | FAIL (expected — all UNCERTIFIED) |

### Still open (next 3m tick / build agent)
| Gap | Action |
|-----|-----|
| All queue items uncertified | Agent walks full plan 0.1→0.32 then TIER 1→5 with 5-gate bar |
| `osa_runtime_2026_06_22.png` | Agent captures on first run |
| Build agent act-tunnel risk | Enforce 0.32 mandatory witness block each iteration; forbidden end-claims |
| `OSAURUS_BUILD_PROGRESS` may claim done | 0.15 DEEP CHECK rewrites honestly |
| MAS VM sandbox substitute research | Standing-only (research, not separate queue row) |
| MULTI-LoRA routing repos | Standing pattern ref for 3.1 (addendum says STANDING classify) |
| Northstar PNGs | Optional visual refs |

## Iteration 6 — 2026-06-22 (reverse-audit ESCALATION + tier-3/5 tables + act-tunnel hardening)

### Reverse addendum audit (iteration 6 grep)
| Addendum section | Queue index |
|------------------|-------------|
| ALL CHAT SURFACES | 0.2, 0.5, 1.6, 4.16 ✓ |
| PER-CLONE SETTINGS / BEYOND | 0.21, 0.27, 0.30, 4.1, 4.14, 4.15 ✓ |
| BUILD-IT-HARDENED | 2.8 ✓ |
| DEFINITIVE ACT-UI | 0.17 ✓ |
| WORK ENGINE ARCH C | 1.3, 0.28, 0.29, 1.7 ✓ |
| MAS / DUAL-BUILD | 5.1, 5.3, 4.8 ✓ |
| FULL-CLONE PROCESS | STANDING ✓ |
| CLASSIFY shared-vs-chat-only | 0.9 ✓ |
| deep graph integration | 4.16 ✓ |
| COMPANION backend | 0.30 OFF-LIMITS + STANDING ✓ |
| OPENCODE HEAVINESS | 1.8 ✓ |
| ⏫ PRIORITY finish ACT before WORK | STANDING (TIER 0 only) ✓ |
| **🔴🔴 ESCALATION P0-A/P0-B** | **Strengthened 0.6** (engine indicator, visible errors, duplicate toggle, click-to-search) |
| **P0-B FULLER SURFACING** | 0.17 + 0.6 + 0.3/0.24 ✓ |
| **META-ESCALATION build-green ≠ works** | 0.32 + STANDING ✓ |
| ENGINES DONE → VISIBLE SURFACES | 0.1, 0.28, 1.2, 4.6 (priority bundle, no new row) ✓ |
| MULTI-LoRA routing repos | STANDING pattern ref for 3.1 ✓ |
| EXTERNAL RESEARCH CORPUS | STANDING ✓ |

### Fixed
| Gap | Fix |
|-----|-----|
| ESCALATION P0-A/P0-B not explicitly indexed | **0.6** expanded: VISIBLE engine indicator, VISIBLE send errors, duplicate toggle, click-to-search →plan ESCALATION + RUNTIME STILL BROKEN |
| PASTE_READY missing TIER 3/5 item tables | Added **TIER 3 WALK (3.1→3.2)** + **TIER 5 WALK (5.1→5.3)** NON-OPTIONAL tables |
| 0.32 witness allowed vague "highest attempted" | Requires **highest attempted item ID** (e.g. `2.3`); INCOMPLETE if stopped before 1.1 |
| Act-tunnel deferral language still possible | Added forbidden end-claims: "defer TIER 1+ to next iteration", "act blocking so skipping work/substrate", "full-plan walk complete after TIER 0" |
| 0.31 grep missed ESCALATION keyword | Extended grep list in queue 0.31 + strict prompt + paste #12 |

### Pre-launch checklist (iteration 6)
| Check | Status |
|-------|--------|
| Queue 0.1→0.32 numeric order | PASS |
| Queue 1.1→1.8 numeric order | PASS |
| Queue 2.1→2.8 numeric order | PASS |
| Queue 3.1→3.2 numeric order | PASS |
| Queue 4.1→4.16 numeric order | PASS |
| Queue 5.1→5.3 numeric order | PASS |
| PASTE_READY tier walks 0.1→0.32, 1.1→1.8, 2.1→2.8, 3.1→3.2, 4.1→4.16, 5.1→5.3 | PASS |
| ESCALATION P0-A/P0-B indexed (0.6) | PASS |
| 0.32 requires highest item ID + INCOMPLETE-before-1.1 rule | PASS |
| FULL-PLAN-NO-ACT-TUNNEL forbidden deferral phrases | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures) |
| Any queue item `[x]` certified | FAIL (expected — all UNCERTIFIED) |

### Still open (next 3m tick / build agent)
| Gap | Action |
|-----|--------|
| All queue items uncertified | Agent walks full plan 0.1→0.32 then TIER 1→5 with 5-gate bar |
| `osa_runtime_2026_06_22.png` | Agent captures on first run |
| Build agent act-tunnel risk | Enforce 0.32 witness with item ID; iteration INCOMPLETE if stopped before 1.1 |
| `OSAURUS_BUILD_PROGRESS` may claim done | 0.15 DEEP CHECK rewrites honestly |
| MAS VM sandbox substitute research | Standing-only (research, not separate queue row) |
| Northstar PNGs | Optional visual refs |

## Iteration 7 — 2026-06-22 (pass49 audit + reverse-audit addendum)

### Pass49 doc fixes applied
| Finding | Fix |
|---------|-----|
| P0-1 RESET not enforced | **STEP-0 RESET** in queue RULES + STANDING; step 0 in strict prompt; paste non-negotiable #2 |
| P0-2 Infinite TIER-0 dwell | **TIER ADVANCE FLOOR** every 3 iters highest attempted ≥1.1 or stall report; act IN PARALLEL with T1+ |
| P0-3 Uncapped `[~]` escape | **`[~]` CAP ≤2/phase**; 3rd halts owner; exact cmd+output required in log |
| P1 →plan anchor drift | Fixed FUGU → `"🌟 FUGU = FOUNDATIONAL FEATURE"`; Epistemos Picks → quoted heading |
| P2 MAS sandbox substitute unindexed | Added queue **5.4** |
| P2 APP-WIDE ANIMATION evaded narrow grep | Expanded **4.6** + indexed §315/§292 explicitly |
| P2 0.31 grep too narrow | Extended to **🆕/🌟/RESEARCH** + paste hit count to log |

### Reverse addendum audit (iteration 7 — sample hits)
| Addendum section | Queue index |
|------------------|-------------|
| APP-WIDE ANIMATION INITIATIVE (§315) | **4.6** (expanded this iter) ✓ |
| MODE-ENTRY TRANSITION ANIMATIONS (§292) | **4.6** ✓ |
| MAS VM sandbox substitute research (§402) | **5.4** (new this iter) ✓ |
| MOTION LANGUAGE = TRIAD (§333) | **4.6** ✓ |
| NORTH STAR / PRODUCT VISION (§343) | **4.3/4.13/4.12** pillar bundle ✓ |
| GRAND UNIFICATION SWEEP (§1187) | **2.3** GUS salvage ✓ |
| HOLISTIC UNIFICATION MAP (§1109) | **2.4** unification ✓ |
| CRYSTALLIZED TWO-MODE ARCHITECTURE (§117) | **0.17/0.20/1.2** ✓ |
| GOOSE FULL-VENDOR COST (§574) | **1.3** ✓ |
| ENGINES DONE → VISIBLE SURFACES (§809) | **0.1, 0.28, 1.2, 4.6** ✓ |
| trinity_coordinator reference (§1011) | **3.1** + STANDING pattern ref ✓ |
| MULTI-LoRA routing repos (§1002) | STANDING pattern ref for **3.1** ✓ |
| SUBSTRATE + IP CERTAIN (§213) | **2.1** ✓ |
| OPENCODE = FULL CLONE WORK SHELL (§101) | **1.1–1.8** ✓ |

### PASTE_READY vs queue cross-check (iteration 7)
| Check | Status |
|-------|--------|
| Non-negotiables include STEP-0, `[~]` cap, TIER advance floor, parallel act | PASS |
| 21 non-negotiables (was 18) | PASS |
| TIER 5 walk 5.1→5.4 matches queue | PASS |
| 0.31 grep tokens match queue/strict | PASS |
| Clone matrix + tier tables complete | PASS |

### Pre-launch checklist (iteration 7)
| Check | Status |
|-------|--------|
| Queue 0.1→0.32 numeric order | PASS |
| Queue 5.1→5.4 numeric order | PASS |
| STEP-0 RESET in queue + strict + paste | PASS |
| `[~]` CAP ≤2 in queue + strict + paste | PASS |
| TIER ADVANCE FLOOR in queue + strict + paste | PASS |
| MAS sandbox substitute indexed (5.4) | PASS |
| APP-WIDE ANIMATION indexed (4.6) | PASS |
| 0.31 grep 🆕/🌟/RESEARCH | PASS |
| PASTE_READY synced with queue | PASS |
| Runtime PNG in repo | FAIL (expected — agent captures) |
| Any queue item `[x]` certified | FAIL (expected — all UNCERTIFIED) |

### Still open (not doc-fixable this iteration — pass49 P0-4/P0-5/P0-6)
| Gap | Action |
|-----|--------|
| P0-4 Substrate/orchestrator runtime rubric weak | Needs W1–W5, B1–B3, S-gate acceptance specs (future iter) |
| P0-5 Phase COMPLETE without app launch | Add completion preconditions when recert phase ends |
| P0-6 Work/beyond/substrate cheap to `[x]` | W/B/S acceptance gates — product spec work |
| All queue items uncertified | Build agent walks full plan with 5-gate bar |
| `osa_runtime_2026_06_22.png` | Agent re-captures each iteration (paste #21) |
| `OSAURUS_BUILD_PROGRESS` may claim done | 0.15 DEEP CHECK rewrites honestly |
| Northstar PNGs | Optional visual refs |
| STRICT_RECERT_LOG gap-fill vs cert line separation | P1 — separate headers when first real cert lands |
| Post-recert forward scope undefined | P1 — define when STRICT RE-CERT COMPLETE triggers forward-only mode |
