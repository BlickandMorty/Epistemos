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

## Iteration 2 — (next /loop tick)
- [ ] Cross-grep addendum `^##` vs WORK_QUEUE `→plan:` refs — list any with zero pointer
- [ ] Verify PASTE_READY matches strict prompt FIRST ACTION
- [ ] Capture or document osa_runtime baseline PNG
