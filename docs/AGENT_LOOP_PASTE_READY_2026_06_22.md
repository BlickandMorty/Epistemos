# PASTE THIS — Epistemos build loop (2026-06-22)

Copy everything below the line into your new terminal agent.

---

You are the Epistemos build loop. **cwd:** `/Users/jojo/Downloads/Epistemos` (main only).

**Certify the ENTIRE multi-feature plan** — all clones (Epistemos|act|work|beyond), all surfaces, substrate,
settings per clone, graph, notes, mini, inference, health rows, deletion sequence, MAS boundaries — **NOT act/D1–D5
only.** Act is P0 blocking for owner pain; **act certified ≠ loop done.**

## READ FIRST — every iteration, in full
1. `docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md` — **sole driver** (FULL PLAN CERTIFICATION section)
2. `docs/WORK_QUEUE_2026_06_22.md` — re-read IN FULL; walk **first unchecked item in numeric order**
   (**0.1→0.32**, then **TIER 1→5**) — no early exit at act/D1–D5

**IGNORE (SUPERSEDED):** `docs/AGENT_LOOP_PROMPT_2026_06_21.md`, `docs/AGENT_LOOP_PROMPT_QUEUE_2026_06_22.md`, `docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md`, `docs/AGENT_DIRECTIVE_CHECK_PROMPT_2026_06_21.md`

**Authority:** `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — read ONLY the current item's `→plan:` section. **Plan wins over code.** Latest 🔒/DEFINITIVE section wins over older addendum text (VOID sections at §607/§1485/§1507 — build §1651 only).

## PER-CLONE CERTIFICATION MATRIX

| Clone | Settings | Inference | Screenshot surfaces | Queue |
|-------|----------|-----------|---------------------|-------|
| **Epistemos (main)** | Epistemos-native tab | TriageService / vault / graph | Main settings, graph or notes | 0.27, 0.21 |
| **act** | Osaurus/act full settings | Osaurus in-process | Main act, mini, graph, note | 0.1–0.26, D1–D5 |
| **work** | OpenCode/work settings | OpenCode/Goose engine | Work landing, TUI, toggle | 0.28, 1.1–1.7 |
| **beyond** | Tab per future clone (stub OK) | Per-clone when wired | Beyond tab + wired clones | 0.30, 4.14 |

**OFF-LIMITS:** Companion-backend (companions.rs, CompanionCreationFlow, new-model interrupt). **IN SCOPE:** work +
beyond future clones (Talaria, Epdoc-fuse, Tamagotchi render-fix).

## LOCKED ACT DIRECTION (no drift)
- Mount **Osaurus's OWN UI** (`LocalPackages/osaurus` ChatView), reskinned cream/monospace + **3 grafts** (message bar, side panel, scroll-blur).
- **SUPERSEDES option-(b)** old Epistemos `ChatView`. Do NOT mount `Epistemos/Views/Chat/ChatView.swift` for act.
- **Landing = Epistemos `LandingView` FIRST** (D2/0.3) → blur → act. NOT Osaurus default "Good morning" landing.

## NON-NEGOTIABLES — every iteration (18)
1. **FULL-PLAN-NO-ACT-TUNNEL** — attempt 0.1→0.32 then TIER 1→5; do NOT stop after act/D1–D5 or build-green
2. **Compile** — no red on main (`cargo test --lib` fast; `xcodebuild` at checkpoints)
3. **Send REAL text (0.23)** — live act inference; assert non-empty reply; owner's model; no HTTP requestFailed; no silent Codex/Qwen. **Build harness if missing.** Log prompt + ~80 chars.
4. **Screencapture** — build → open → `screencapture -x /tmp/epi_<surface>.png` → **Read PNG**. **One PNG per surface** (main act, mini, graph, note, work landing, each settings tab). Owner is NOT checking.
5. **5-gate bar** per item: (a) exists file:line · (b) on-plan · (c) wired · (d) real-state tested · (e) runtime proven. Append to `docs/research/STRICT_RECERT_LOG_2026_06_22.md`.
6. **D1–D5 gate (0.8):** do NOT mark 0.1–0.7 `[x]` until matching D screencapture passes. **4.7 gated on D5.**
7. **D4/settings is TIER-0** — per-clone matrix 0.21 (Epistemos|act|work|beyond); do not defer to 4.1.
8. **Provider wiring (0.11):** owner's models selectable AND used on send; Configuration opens real settings; no silent Codex/Qwen.
9. **Health-row honesty (0.14):** `wiredToday`/`stillStub` match REAL code after every change.
10. **Title-gen (0.16 extends 0.9):** parse `<think>`; CLASSIFY shared-vs-chat-only; CLEAN short titles.
11. **Discovery sweep** — grep chat/inference consumers; add missed surfaces to queue.
12. **Reverse addendum audit (0.31)** — grep addendum 🔒/DEFINITIVE/P0/MUST/BUILD-IT-HARDENED/PER-CLONE/ALL CHAT SURFACES; index or add queue row same iteration.
13. **Full-plan witness (0.32)** — before iteration ends: highest item attempted, per-tier `[x]`/`[~]`/`[ ]` counts; confirm not act-only.
14. **Certify AND fix** in same walk — broken → fix to full plan spec → re-prove → `[x]`.
15. **Narrow `[~]` bar** — ONLY if screencapture AND send-text BOTH fail (state why). Never `[x]` on build-green.
16. **P0 owner reports** → addendum + queue + prompt same iteration, then fix first.
17. **Act certified ≠ loop done** — continue into TIER 1+ same iteration when TIER 0 certified or honestly blocked.
18. **FAVOR OSAURUS on clash** · **owner messages → plan+queue** · **NEVER-IDLE** · **FULL-CLONE PROCESS** for every adopted engine · **main-only** · Co-Authored-By Claude.

## TIER WALK — strict numeric order, NO EARLY EXIT
1. **TIER 0:** 0.1 → 0.32 (act + clone baseline + reverse audit + iteration witness)
2. **TIER 1:** 1.1 → 1.7 (OpenCode/work — do NOT skip because act is broken)
3. **TIER 2:** 2.1 → 2.8 (substrate, salvage, BUILD-IT-HARDENED)
4. **TIER 3:** 3.1 → 3.2 (TRINITY, Fugu)
5. **TIER 4:** 4.1 → 4.16 (settings, pillars, beyond, graph integration)
6. **TIER 5:** 5.1 → 5.3 (distribution, MAS split)

## TIER 0 WALK (0.1 → 0.32)
| Item | Summary |
|------|---------|
| 0.1 | Reskin at vendored `Theme.swift` SOURCE |
| 0.2 | ALL chat surfaces → Osaurus act host; screenshot EACH |
| 0.3 | Epistemos landing FIRST → blur → act (D2) |
| 0.4 | Send works — in-process, owner's model |
| 0.5 | Mini + grab-chat; screenshot EACH |
| 0.6 | Re-certify claimed-done bugs |
| 0.7 | Message-bar graft |
| 0.8 | D1–D5 runtime acceptance gate |
| 0.9 | Act fidelity + CLASSIFY shared-vs-chat-only |
| 0.10 | Data carry-over |
| 0.11 | Provider wiring + Epistemos Picks |
| 0.12–0.13 | Surface-wiring + shared act component |
| 0.14–0.15 | Health rows + DEEP CHECK |
| 0.16 | Reasoning + title-gen |
| 0.17–0.20 | LOCKED direction / registration / deletion / duality |
| 0.21 | Per-clone settings matrix (D4) — 4 tabs |
| 0.22 | ONE inference chokepoint |
| 0.23–0.26 | Send harness / UI bugs / gated chat delete / UI-hide |
| 0.27 | Epistemos (main) clone baseline |
| 0.28 | WORK clone surface reachable |
| 0.29 | Per-clone inference routing |
| 0.30 | BEYOND tab + OFF-LIMITS honesty |
| 0.31 | Reverse addendum audit (standing) |
| 0.32 | Full-plan iteration witness (standing) |

## D1–D5 (must all pass YOUR screencapture before act is done)
- **D1** Curved window + soft shadow · **D2** Owner landing FIRST · **D3** Pill back · **D4** Settings work (all clone tabs) · **D5** Full reskin + picker/palette/38-tool panel

Ground truth: `docs/research/osa_runtime_2026_06_22.png` (see `osa_runtime_PLACEHOLDER.md` if missing).

## FIRST ACTION (every iteration)
1. Read driver + queue in full
2. Baseline screencapture → Read PNG; save `osa_runtime_2026_06_22.png` if missing
3. Build/run send-text harness (0.23)
4. Walk **0.1 → 0.32**, then **continue TIER 1→5** same iteration — no queue-jumping
5. Reverse addendum audit (0.31) + full-plan witness (0.32)
6. Update queue + STRICT_RECERT_LOG; `git add` only your files; Co-Authored-By Claude

**Act certified ≠ iteration done. Certify FULL PLAN, not act-only. Do not say "computer use unavailable" — use screencapture + Read + osascript.**
