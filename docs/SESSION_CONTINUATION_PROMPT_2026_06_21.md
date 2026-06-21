# Epistemos — Fresh-Session Continuation Prompt (2026-06-21)

Paste the block below to start the NEW main session. It re-anchors a fresh, hallucination-free session
to the on-disk authority and tells it how to (re)start the build loop where the last one left off.

---

You are taking over the Epistemos build (macOS PKM/agent app: Swift 6 + Rust/UniFFI + MLX), cwd
`/Users/jojo/Downloads/Epistemos`. The prior session was restarted because it hallucinated. TRUST ONLY
THE FILES — the plan/ledger/memory on disk are the authority, not any session memory.

## READ FIRST — CORE (in this order, before acting)
1. `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md` — full-clone strategy + the **2026-06-21 OWNER DIRECTIVE
   append** at the bottom (read that append first; it supersedes any reductive framing).
2. `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — Epistemos Picks + all-chats-get-act +
   surface-wiring + completeness-sweep + harden-after.
3. `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` — the hard no-delete + preserve/port guard.
4. `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md` — top banners (🛑 quarantine guard + 🔴 chat P0s, deferred).
5. Memory `project_osaurus_full_clone_directive_2026_06_21` (auto-loaded via MEMORY.md).

## READ NEXT — SUPPORTING (before building the relevant slice)
6. `docs/research/OSAURUS_ACT_CONNECTION_MAP_2026_06_19.md` — how act wires to Osaurus (act surfaces).
7. `docs/research/HERMES_OSAURUS_OPENCLAW_WIRING_R2_2026_06_19.md` + `..._OVERLAP_AND_DESTINATION_2026_06_19.md`
   — Osaurus/OpenClaw wiring + overlap/destination reasoning.
8. WORK-mode (Goose): `docs/GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md`, `docs/GOOSE_REPLACEMENT_STRATEGY.md`,
   `docs/GOOSE_AGENT_RESEARCH.md` (+ `_2`). OpenClaw: `docs/OPENCLAW_FEATURE_SPEC.md`,
   `docs/BEST_OF_CLAW_AND_OPENCLAW.md`.
9. Doctrine/quality bars: `docs/research/SS-PROVEN_DONE_DOCTRINE_2026_06_21.md` (real-state done bar),
   `docs/research/SS-CHATMODEL_P0_EXISTING_INSTALL_DEFAULT_2026_06_21.md` (default-resolution history +
   no-Qwen-fallback), `docs/research/SS-CHATPICKER_P0_INSTALLED_MODELS_NOT_CLICKABLE_2026_06_21.md`
   (picker/fallback root cause), `docs/research/SS-AUTONOMOUS_VERIFY_SYSTEM_2026_06_21.md` (verification),
   `docs/research/LOOP_HARDENED_ENGINEERING_CONTRACT_2026_06_20.md` (per-item discipline).
10. Substrate DETAIL (for the later-but-certain substrate-health/IP-repair phase, NOT walk-order):
   `docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`, `MASTER_BUILD_QUEUE_2026_06_20.md`,
   `RESEARCH_FINALIZATION_INDEX_2026_06_20.md`, `CONNECTION_MAP_2026_06_20.md`.
NOTE: if any doc names conflict, the CORE list + this prompt + the 2026-06-21 owner directives WIN.

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

---

## ⚠️ SUPERSEDES / DON'T-GET-CONFUSED (final check 2026-06-21)
Older docs still say "substrate/chat-first" and list "ActOsaurus/Vendor/Osaurus/LocalModelServer =
off-limits." Those are STALE as of 2026-06-21. The CURRENT truth (this prompt + the four docs above):
1. **Osaurus full clone is now AUTHORIZED + the priority.** The old "Osaurus off-limits" line is
   overridden — those files are exactly what you build now (carefully, per the import plan). Still
   off-limits: NEW MODEL brain-1, the 70B, and the *Companion* clones (companions.rs / Models·State/
   Companion / CompanionCreationFlow). Osaurus *act* ≠ Companion.
2. **Walk-order is Osaurus-first**, not the substrate-first order in MASTER_BUILD_QUEUE /
   SUBSTRATE_BUILD_SEQUENCE / RESEARCH_FINALIZATION_INDEX. Read those for substrate DETAIL only.
3. **SUBSTRATE HEALTH + IP-REPAIR COCKTAIL = LATER BUT CERTAIN.** The owner explicitly still wants the
   substrate-health work + the IP-repair cocktail done — scheduled AFTER the Osaurus clone + porting
   cycles, further down the walk, but NEVER dropped.
4. **Never delete the quarantined chat.** Porting cycles move its logic/IP into beneficial surfaces
   (Eidos/recall/graph/capture/act) BEFORE any retire; retire only after the 4-part bar + owner OK.
5. The loop's in-flight chat-picker increment is **committed as CANON at `9d7568920`** (NOT a stash/WIP
   — owner: WIP framing gets forgotten + regresses). Its real home is the Osaurus "Epistemos Picks"
   section — port that logic there. HONEST: that commit's compile-state is UNVERIFIED (loop was
   mid-edit); build-verify first; if it doesn't compile, fix or revert its 3 swift files (NOT on the
   Osaurus critical path). Nothing is left in an ephemeral stash; main has no untracked work-in-progress.

If any instruction anywhere conflicts with items 1–5, items 1–5 WIN (they are the latest owner directive).

## ⚠️ STASH TRIAGE (found 2026-06-21 — validates owner's "WIP gets forgotten" concern)
`git stash list` shows ~24 stashes — forgotten WIP from prior sessions, exactly the regress-risk the
owner flagged. EARLY TASK for the fresh session: triage every stash (`git stash list`; inspect each with
`git stash show -p stash@{N}`). For each, deliberately EITHER commit-as-canon (with an honest message) OR
drop it on purpose. Do NOT leave work in ephemeral stashes. No WIP/stash as a hiding place going forward —
unfinished work is either a canon commit or an explicit ledger item, never a floating stash.

## 🆕 ALL CHATS GET ACT POWERS
Every chat surface (main ChatView, MiniChat, Note chat/NoteChatSidebar, Graph chat/Hologram*) gets the SAME chat→act/Osaurus upgrade (tools, model picker + Epistemos Picks, no-fallback, streaming/thinking fidelity) via a SHARED act composer — not just main chat. Sweep for any missed chat entry point. See OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md.

## 🆕 COMPLETENESS / DISCOVERY-SWEEP
The named surface lists are STARTING POINTS, not exhaustive. Run a systematic discovery sweep (grep InferenceState / EpistemosRuntimePicker / setPreferredChatModelSelection / tool icons / capability pills / any prompt-sending view) to find EVERY consumer of the chat backend / inference / picker / tools. Each must be upgraded to act, or quarantined+ported, or deliberately marked out-of-scope with a reason — never silently missed. Reason about ripple effects (settings, landing, command palette, sidebars, widgets, tests). Run a "completeness critic" each cycle: "what did we miss?" -> ledger. See addendum.
