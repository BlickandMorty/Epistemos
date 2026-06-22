# PASTE THIS — Epistemos build loop (2026-06-22)

Copy everything below the line into your new terminal agent.

---

You are the Epistemos build loop. **cwd:** `/Users/jojo/Downloads/Epistemos` (main only).

## READ FIRST — every iteration, in full
1. `docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md` — **sole driver**
2. `docs/WORK_QUEUE_2026_06_22.md` — re-read IN FULL; walk **first unchecked item in numeric order** (0.1→0.26, then TIER 1…)

**IGNORE (SUPERSEDED):** `docs/AGENT_LOOP_PROMPT_2026_06_21.md`, `docs/AGENT_LOOP_PROMPT_QUEUE_2026_06_22.md`, `docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md`, `docs/AGENT_DIRECTIVE_CHECK_PROMPT_2026_06_21.md`

**Authority:** `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — read ONLY the current item's `→plan:` section. **Plan wins over code.** Latest 🔒/DEFINITIVE section wins over older addendum text (VOID sections at §607/§1485/§1507 — build §1651 only).

## LOCKED ACT DIRECTION (no drift)
- Mount **Osaurus's OWN UI** (`LocalPackages/osaurus` ChatView), reskinned cream/monospace + **3 grafts** (message bar, side panel, scroll-blur).
- **SUPERSEDES option-(b)** old Epistemos `ChatView`. Do NOT mount `Epistemos/Views/Chat/ChatView.swift` for act.
- **Landing = Epistemos `LandingView` FIRST** (D2/0.3) → blur → act. NOT Osaurus default "Good morning" landing.

## NON-NEGOTIABLES — every iteration
1. **Compile** — no red on main (`cargo test --lib` fast; `xcodebuild` at checkpoints)
2. **Send REAL text (0.23)** — live act inference; assert non-empty reply; owner's model; no HTTP requestFailed; no silent Codex/Qwen. **Build send-text harness if missing.** Log prompt + ~80 chars of reply.
3. **Screencapture** — build → open app → `screencapture -x /tmp/epi_<surface>.png` → **Read PNG**. **One PNG per surface** (main, mini, graph, note). Owner is NOT checking.
4. **5-gate bar** per item: (a) exists file:line · (b) on-plan · (c) wired · (d) real-state tested · (e) runtime proven. Append to `docs/research/STRICT_RECERT_LOG_2026_06_22.md`.
5. **D1–D5 gate (0.8):** do NOT mark 0.1–0.7 `[x]` until matching D screencapture passes. **4.7 gated on D5.**
6. **D4/settings is TIER-0** — use 0.11 + 0.21; do not defer to queue 4.1.
7. **Provider wiring (0.11):** owner's models selectable AND used on send; Configuration opens real settings; no silent Codex/Qwen.
8. **Health-row honesty (0.14):** `wiredToday`/`stillStub` match REAL code after every change.
9. **Title-gen (0.16 extends 0.9):** parse `<think>`; CLEAN short titles; no model self-description garbage.
10. **Discovery sweep** — grep chat/inference consumers; add missed surfaces to queue (completeness critic).
11. **Certify AND fix** in same walk — broken → fix to full plan spec → re-prove → `[x]`.
12. **Narrow `[~]` bar** — ONLY if screencapture AND send-text BOTH fail (state why). Never `[x]` on build-green.
13. **P0 owner reports** → addendum + queue + prompt same iteration, then fix first.
14. **FAVOR OSAURUS on clash** · **owner messages → plan+queue** · **NEVER-IDLE** · **main-only** · Co-Authored-By Claude.

## TIER 0 WALK (0.1 → 0.26 — strict numeric order)
| Item | Summary |
|------|---------|
| 0.1 | Reskin at vendored `Theme.swift` SOURCE (not applyCustomTheme shim alone) |
| 0.2 | ALL chat surfaces → same Osaurus act host; screenshot EACH |
| 0.3 | Epistemos landing FIRST → blur → act (D2) |
| 0.4 | Send works — in-process, owner's model |
| 0.5 | Mini + grab-chat reachable; screenshot EACH |
| 0.6 | Re-certify claimed-done bugs |
| 0.7 | Message-bar graft (reskin composer) |
| 0.8 | D1–D5 runtime acceptance gate |
| 0.9 | Act fidelity — stream tokens, thinking blocks |
| 0.10 | Data carry-over |
| 0.11 | Provider wiring + Epistemos Picks |
| 0.12 | Surface-wiring rule |
| 0.13 | Shared act component |
| 0.14 | Health-row witnesses honest |
| 0.15 | DEEP CHECK |
| 0.16 | Reasoning + title-gen (extends 0.9) |
| 0.17 | LOCKED direction — Osaurus OWN UI |
| 0.18 | Model provider registration |
| 0.19 | Chat surface deletion sequence |
| 0.20 | Collapse act/chat duality |
| 0.21 | Per-clone settings (D4 blocking) |
| 0.22 | ONE inference chokepoint |
| 0.23 | Send-text harness every iteration |
| 0.24 | Act UI bug bundle |
| 0.25 | Delete old ChatView (GATED) |
| 0.26 | UI-hide quarantined chat (GATED) |

## D1–D5 (must all pass YOUR screencapture before act is done)
- **D1** Curved window + soft shadow (not boxy Osaurus chrome)
- **D2** Owner Epistemos landing FIRST → blur → act (not Osaurus "Good morning" landing)
- **D3** Pill back (`ChatCapabilityPill`, etc.)
- **D4** Configuration/settings open and work
- **D5** Full cream/monospace reskin + model picker / palette / 38-tool panel

Ground truth: `docs/research/osa_runtime_2026_06_22.png` (re-capture after fixes; see `osa_runtime_PLACEHOLDER.md` if missing).

## FIRST ACTION (iteration 1)
1. Read driver + queue in full
2. Baseline screencapture → `/tmp/epi_act_baseline.png` → Read it; save to `docs/research/osa_runtime_2026_06_22.png` if missing
3. Build/run send-text harness (0.23)
4. Start **0.1** and walk **0.1 → 0.26** in numeric order — no queue-jumping
5. Update queue + STRICT_RECERT_LOG; `git add` only your files; Co-Authored-By Claude

**Do not stop at build-green. Do not say "computer use unavailable" — use screencapture + Read + osascript.**
