# Epistemos — Fresh-Session Continuation Prompt (2026-06-21)

Paste the block below to start the NEW main session. It re-anchors a fresh, hallucination-free session
to the on-disk authority and tells it how to (re)start the build loop where the last one left off.

---

You are taking over the Epistemos build (macOS PKM/agent app: Swift 6 + Rust/UniFFI + MLX), cwd
`/Users/jojo/Downloads/Epistemos`. The prior session was restarted because it hallucinated. TRUST ONLY
THE FILES — the plan/ledger/memory on disk are the authority, not any session memory.

## READ FIRST (in this order — do not act before reading all five)
1. `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md` — full-clone strategy + the **2026-06-21 OWNER DIRECTIVE
   append** at the bottom (read that append first; it supersedes any reductive framing).
2. `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — "Epistemos Picks" model section + harden-after.
3. `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` — the hard no-delete guard.
4. `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md` — top banners (🛑 quarantine guard + 🔴 chat P0s, now deferred).
5. Memory `project_osaurus_full_clone_directive_2026_06_21` (auto-loaded via MEMORY.md).

## THE DIRECTIVE (owner 2026-06-21, do NOT re-reduce)
- **FULL Osaurus clone — the ENTIRE app (settings, everything), zero cherry-pick, in-process Swift**
  (OsaurusCore is in-process, NOT a subprocess — an earlier "subprocess blocks MAS" claim was a
  hallucination). Vendor the complete repo, link OsaurusCore, reskin views to app chrome.
- **Act replaces chat.** The owner LOVES the chat front-end and wants act to look exactly like it —
  REUSE the proven chat front-end as act's UI. Likely two modes: **act + work** (work = Goose/OpenCode).
- **🆕 EVERY OSAURUS SURFACE MUST WIRE TO A REAL, ALREADY-PROVEN FRONT-END PART OF THE APP.** No dead
  or disconnected surfaces. If Osaurus exposes a capability (settings, model stack, server, tools,
  transcript), it must be linked to an existing, working app front-end that's already proven — the owner
  does NOT want things that don't work. Map each Osaurus surface → the real app view it drives BEFORE
  wiring it.
- **"Epistemos Picks" model section:** surface the owner's custom hardened models (QAT GGUF ladder, MLX,
  all — already standalone in `Epistemos/Engine/LocalModelInfrastructure.swift`/LocalModelCatalog) as a
  curated section in the Osaurus model stack. Honest selection: NO silent Qwen substitute; too-large =
  honest message.
- **RETAIN owner IP** (system prompts + hidden pieces): preserve + PORT into Osaurus (act) / Goose
  (work). Nothing of the owner's deleted before the clone proves out + IP is ported.
- **SEQUENCING:** Osaurus full clone FIRST → wire surfaces to real front-ends + port IP + "Epistemos
  Picks" → THEN harden everything that exists. Do NOT keep patching the dying chat (its picker/Qwen
  fixes are deferred into the act build, NOT applied to the quarantined chat).

## 🛑 HARD RULES (never violate)
- **NEVER DELETE chat / chat-backend code** (resolution layer, picker, views, InferenceState chat paths,
  model wiring). QUARANTINE only (flag-OFF / off-live-path, stays in-tree). Only the OWNER authorizes
  deletion, after IP is ported + act proves out.
- **Ground every claim in a file READ before stating it.** No claim about a file/capability from memory.
- **No fake-done:** mark [x] / "done" only with a REAL-STATE test (existing-install/persisted state),
  never on build-green/test-green alone. A flag-OFF bug fix is "staged," not done.
- main-only; never vault writes; commits Co-Authored-By Claude; when committing docs `git add` ONLY your
  own files (never `-A`).
- HARD OFF-LIMITS for autonomous building (need owner go): NEW MODEL brain-1 (SSM/Mamba/M0/signal_bus/
  lattice/research-internals), the 70B, Companion→Osaurus *Companion* clones (cognitive_dag/companions.rs,
  Models/Companion/*, CompanionCreationFlow). NOTE: the Osaurus *act* clone is now AUTHORIZED + the
  priority (this supersedes the old "ActOsaurus/Vendor/Osaurus/LocalModelServer off-limits" line — those
  are exactly what you now build, carefully, per the plan).

## WHERE IT LEFT OFF (2026-06-21)
- Last loop commits: `d25eaead8` chat-picker enumeration (additive, reusable for Epistemos Picks),
  `9b66d0777`/`c88f8daa2`/`7c7d31469`/`5d78c5eb7` local-tools robustness, `79ee699dd` idle-memory,
  `e61eaf4b7` OpenAI-tools disclosure. All honest-floor; no chat deletions.
- Chat default-RESOLUTION was fixed earlier (ddbadf434) BUT the **too-large→Qwen runtime fallback is
  still live** (`InferenceState.swift:3072` hardcoded `.qwen3_4B4Bit` + the constrained chain). That
  requirement now moves into the act/Osaurus model selection (no silent Qwen) — NOT a chat patch.
- Substrate remainder (deferred behind Osaurus): STAGE-2 RuntimeRouter live flip, P5 EML rerank/W-51
  recall, P2 load-on-launch. See `docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`.

## FIRST ACTIONS
1. Read the five docs above. Confirm understanding back to the owner in 5 bullets (don't start coding
   until confirmed).
2. Start the Osaurus clone at **Seam A / S1** per the import plan: `ActOsaurusBridge` protocol + flag
   (OFF) + inert stub + gate HealthRow + MAS/Pro boundary guard test — compile-verified, no repo import
   yet. Then S2 (vendor the full repo) per the plan.
3. For EACH surface, first map Osaurus-surface → the real proven app front-end it will drive; wire it;
   prove it works (real-state test / launch-smoke). No dead surfaces.

## RESTART THE LOOP + WATCHDOG (session-local)
- The detached loop screen is `epistemos-master-loop` (pid 77384). To stop it for a clean restart:
  `screen -S epistemos-master-loop -X quit`. Watchdog: `pkill -f epi_loop_watchdog.sh`.
- To start a fresh loop: open `screen -S epistemos-master-loop`, launch `claude`, paste this prompt's
  directive, and run a self-paced `/loop` (or restart the 5-min monitor cron separately).
- Re-arm the watchdog: `nohup zsh scripts/epi_loop_watchdog.sh >/dev/null 2>&1 & disown`.

REMINDER: when unsure, read the file. Never delete the chat. Wire every Osaurus surface to a real,
proven front-end. Osaurus first, harden after.
