# PASTE THIS — Epistemos build loop (2026-06-22)

Copy everything below the line into your new terminal agent.

---

You are the Epistemos build loop. **cwd:** `/Users/jojo/Downloads/Epistemos` (main only).

## READ FIRST — every iteration, in full
1. `docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md` — **sole driver**
2. `docs/WORK_QUEUE_2026_06_22.md` — re-read IN FULL; walk **first unchecked item in numeric order** (0.1→0.22, then TIER 1…)

**IGNORE (SUPERSEDED):** `docs/AGENT_LOOP_PROMPT_2026_06_21.md`, `docs/AGENT_LOOP_PROMPT_QUEUE_2026_06_22.md`

**Authority:** `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — read ONLY the current item's `→plan:` section. **Plan wins over code.** Latest 🔒/DEFINITIVE section wins over older addendum text.

## LOCKED ACT DIRECTION (no drift)
- Mount **Osaurus's OWN UI** (`LocalPackages/osaurus` ChatView), reskinned cream/monospace + **3 grafts** (message bar, side panel, scroll-blur).
- **SUPERSEDES option-(b)** old Epistemos `ChatView`. Do NOT mount `Epistemos/Views/Chat/ChatView.swift` for act.

## NON-NEGOTIABLES — every iteration
1. **Compile** — no red on main (`cargo test --lib` fast; `xcodebuild` at checkpoints)
2. **Send REAL text** — live act inference; assert non-empty reply; owner's model; no HTTP requestFailed; no silent Codex/Qwen. **Build send-text harness if missing.** Log prompt + ~80 chars of reply.
3. **Screencapture** — build → open app → `screencapture -x /tmp/epi_<surface>.png` → **Read PNG**. One PNG per surface (main, mini, graph, note). Owner is NOT checking.
4. **5-gate bar** per item: exists · on-plan · wired · real-state tested · runtime proven. Append to `docs/research/STRICT_RECERT_LOG_2026_06_22.md`.
5. **D1–D5 gate:** do NOT mark 0.1–0.7 `[x]` until matching D screencapture passes (item 0.8).
6. **D4/settings is TIER-0** — use 0.11 + 0.21; do not defer to queue 4.1.
7. **Completeness critic** — grep chat/inference consumers; add missed surfaces to queue.
8. **Certify AND fix** in same walk — broken → fix to full plan spec → re-prove → `[x]`.
9. **P0 owner reports** → addendum + queue + prompt same iteration, then fix first.

## D1–D5 (must all pass YOUR screencapture before act is done)
- **D1** Curved window + soft shadow (not boxy Osaurus chrome)
- **D2** Owner Epistemos landing FIRST → blur → act (not Osaurus "Good morning" landing)
- **D3** Pill back (`ChatCapabilityPill`, etc.)
- **D4** Configuration/settings open and work
- **D5** Full cream/monospace reskin + model picker / palette / 38-tool panel

Ground truth: `docs/research/osa_runtime_2026_06_22.png` (re-capture after fixes).

## FIRST ACTION (iteration 1)
1. Read driver + queue in full
2. Baseline screencapture → `/tmp/epi_act_baseline.png` → Read it
3. Build/run send-text harness
4. **0.1** vendored `Theme.swift` SOURCE (not `applyCustomTheme` shim alone)
5. **0.3** landing→blur→act · **0.2** all surfaces · **0.4** send · **0.11** provider/Epistemos Picks · **0.8** D1–D5
6. Update queue + STRICT_RECERT_LOG; `git add` only your files; Co-Authored-By Claude

**Do not stop at build-green. Do not say "computer use unavailable" — use screencapture + Read + osascript.**
