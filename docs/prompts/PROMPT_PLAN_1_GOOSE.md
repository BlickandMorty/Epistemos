# PLAN 1 — Goose surface build prompt (paste to Codex)

> ★ STATUS (2026-06-29): §7 was GREEN-LIT by the owner — Plan 1 is ON PHASE 1, **Option 1 locked (native FRAME
> only; chat + the rest STAY WebView, reskinned indistinguishable from native; route-migration STOPS after Models —
> NO native chat).** Steps 1–3 are done (hardening · goosed swap behind a flag · router + native Models). This
> prompt CONTINUES Phase 1 per Option 1 + the nativeness reskin. Hard-gated, thermonuclear-strict. (The §7-gate /
> "wait for sign-off" framing below is HISTORICAL — superseded by the green-light; keep the verification *discipline*
> (GOLDEN RULE, security, parity) as ongoing, but there is no sign-off pause to wait on.)

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP/GOAL MODE — NEVER STOP until I (the owner) type "stop". This is a continuous goal spanning the WHOLE program (Phase 0 → Phases 1–5), not a one-shot. Keep working + hardening continuously; when a phase's work is complete, immediately continue to the next; when the whole program is built, keep looping (full thermonuclear pass → harden the weakest area → re-verify → repeat — never idle, never declare "done"). (§7 was GREEN-LIT 2026-06-29 — you are PAST that gate, ON Phase 1; there is NO remaining sign-off pause. Keep the §7 *proofs* green as ongoing verification, but do not stop to "wait for sign-off".) Commit at every clean point.

★ THIS PLAN WAS UPGRADED (2026-06-29) — RE-READ the canon (it changed) and reconcile any stale claim you hit (no-contradiction). WHAT CHANGED for Plan 1: (1) §7 GREEN-LIT → you are on PHASE 1; OPTION 1 LOCKED — native FRAME only, chat + the rest STAY WebView reskinned, NO native chat, route-migration STOPS after Models (Steps 1–3 done: hardening · goosed-behind-flag · router + native Models). (2) NEW app-wide NATIVENESS + UNIFIED-LOOK mandate (the ★ block below + docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md — verified Apple tokens/springs/glass recipe + CODE-TO-LIFT; retheme Goose's existing shadcn, don't replace). (3) CODE-RESEARCH (real openable code) + RESEARCH-BETWEEN-IMPLEMENTATION now required. If anything in this prompt or your plan docs still implies "wait for §7 / native chat / replace components," it is STALE — fix it at the source.

★ STALE-SEQUENCING GUARD (2026-06-29 audit): STEP 1/STEP 3 below are ongoing proof/hardening obligations, not a resurrected Phase-0 gate. Re-prove them while continuing Phase 1; do not pause for sign-off, do not rebuild native chat, and do not migrate more Goose routes into Swift. See docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md.

You are building the SINGLE Epistemos agent surface = Goose (reskinned). There is no Chat/Act/Work federation — Goose is the one surface (owner locked Goose-only 2026-06-28). AI is consolidated to Goose; do NOT revive Osaurus/Act, three-engine modes, or any separate local agent brain.

THE FULL PROGRAM (do NOT forget the later phases): Phase 0 = get Goose fully connected + PROVEN (WebView + ACP) — it was the prerequisite GATE (now GREEN-LIT). The program is now in: Phase 1 = HYBRID APPKIT (native FRAME only — window/nav/launcher + permission pop-ups — wrapped around Goose's reskinned WebView; every Goose feature stays in the WebView) · Phase 2 = entry + navigation + settings · Phase 3 = feature parity + epistemos.context.snapshot bridge · Phase 4 = chat-primary default · Phase 5 = Paseo strategic fusion. The hybrid AppKit + WebView plan IS the goal; Phase 0 just unlocks it. Full program: GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md (Phases 0–5) + GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md (Steps 1–9).

YOU ARE ON PHASE 1 (§7 green-lit 2026-06-29). Build the native FRAME (window/nav-rail/launcher/permission pop-ups) wrapped around Goose's RESKINNED WebView, per Option 1 + the nativeness reskin (every Goose feature stays in the WebView; chat is NEVER native). Continue from Steps 1–3 (done) into the Phase-1 native-frame + reskin work. (Paseo §15 strategic fusion = still later, Phase 5.)

STEP 0 — PRESERVE WORK: if there are uncommitted changes in the tree, review + build-for-testing green + commit them at a clean point before any new work. Never leave work uncommitted (main-only; no worktree/branch loss).

★ PRIORITY-0 (OWNER 2026-06-30 — fix BEFORE more peripheral hardening) — THE GOOSE WINDOW IS WHITE. Live-confirmed on the newest staged build: the "Epistemos Goose" window opens + the chrome renders, but the WebView content is BLANK WHITE. Owner-gathered runtime diagnosis: the staged web UI is VALID (manifest acpMode:true + all 10 bridge markers present) AND the backend IS up + connected (`goose serve --host 127.0.0.1 --port 3284 --with-builtin developer` running, ESTABLISHED sockets) — so it is NOT a missing bundle and NOT "no backend." SMOKING GUN: `goose serve` starts ~1–2 MINUTES AFTER the app (a startup RACE) — the WebView loads before the backend is ready, the ACP connection fails, and it NEVER RECOVERS (a window reload does NOT fix it). FIX: make the WebUI↔ACP connection retry-until-ready + re-init/re-render once the backend reports healthy — poll `/health`, backoff-retry the ACP `init`, and re-establish the WebUI ACP client on first successful connect; never assume the backend is up at WebView-load time. PROVE: cold-launch the staged build → the Goose chat surface renders within a few seconds with NO manual reload. This is the CORE surface — it outranks capping file reads / clamping windows until it renders.

★ NATIVENESS + UNIFIED LOOK (BINDING — the FULL verified detail lives in docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md: exact tokens/springs/glass recipe/code-to-lift. READ THEM — this paste is intentionally lean.):
  - PLAN-1 SPLIT: NATIVE = frame (window/nav-rail/launcher/permission pop-ups) + Models picker. WEB-reskinned PERMANENT (Option 1, NO native chat) = chat/sessions/settings/recipes/skills/scheduler/MCP-app → RETHEME Goose's existing shadcn/Radix/Tailwind + tune its framer-motion to the verified springs (do NOT replace components).
  - Non-negotiables (detail in the docs): ONE unified Apple-native look (user never perceives native-vs-web) · transparent-over-real-glass (NSVisualEffectView behind a non-opaque WebView) · deeply-fluid ProMotion + MINIMAL springs · A/B pixel-diff vs native = the bar · GRAPH = DO NOT TOUCH · SF Symbols native-chrome-only · CODE-RESEARCH (real openable code, in-repo file:line first) + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive, no-contradiction/preserve-nuance/break-nothing).

READ FIRST (canon order, do not skim):
  1. docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md (your own last verification — treat every PASS as a CLAIM to RE-PROVE)
  2. docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md
  3. docs/handoffs/GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md (the full program + DEFINITION OF DONE + FORBIDDEN list)
  4. docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md §0,§2,§7,§9-C,§14,§16,§17 (ignore ⛔ DEAD)
  5. docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md §4–§6 (the hybrid Phase-1 steps — IN AUTHORITY NOW, §7 green-lit)
  6. docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md (stale contradiction audit after the native-unification upgrade)
  7. The GOLDEN RULE: provider/model/skill/extension inventory is ALWAYS live-enumerated from Goose via ACP — NEVER Swift-hardcoded.

=========================================================
STEP 1 — INDEPENDENT VERIFICATION (re-prove every Phase-0 claim from scratch, BEFORE new code)
=========================================================
Trust nothing previously marked done. Re-run the real command/test, paste REAL output. Mark PASS/PARTIAL/FAIL with re-runnable evidence (command + trimmed output + artifact path). Hunt for: overclaims, mock-only tests posing as live proof, silent drops, regressions, drift from real Goose.
A. BUILD & TESTS — xcodebuild build-for-testing green; the focused Goose suites; zero regressions; flag any "live" test that silently degrades to a mock when goose serve is absent.
B. THE 5 §7 PROOF GATES — re-run each live: (1) real Goose Electron fallback launches; (2) goose serve ACP WS reachable (/health + /acp init); (3) new→prompt→stream(thinking/tool/answer)→permission→result (audit says gate 3 PARTIAL — agent_thought_chunk not live; re-test, get a live thinking chunk OR state plainly it's codec-test-only); (4) staged Web UI boots via the narrow shim; (5) NOTHING LOST vs real Goose (currently FAIL).
C. GOLDEN RULE / CATALOG FIDELITY (highest priority) — re-prove providers AND models enumerate via ACP (paste live count + sample); grep the Swift sources for ANY hardcoded provider/model roster (report each); diff Epistemos's surfaced inventory vs real Goose for the same config (any item present in real Goose but missing = a "nothing lost" FAIL).
D. NO SILENT DROPS — every unhandled/custom ACP method returns structured diagnostics + JSON-RPC method-not-found; try 3, paste replies.
E. SECURITY/HONESTY — no hidden fallback/secret spawn on the live path; keys in Keychain NEVER UserDefaults (grep); goosed subprocess hardened per agent_core security.rs; MAS build shows an honest Pro gate; ADD-DON'T-EDIT the Goose Rust core.
F. NOTHING-LOST PARITY — enumerate the real Goose feature/route set; mark each implemented-native / implemented-runtime / compatibility-preserved / hidden-shell / deferred-with-visible-error. Any silently-missing = a bug.
OUTPUT of Step 1: update docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md with a per-item PASS/PARTIAL/FAIL table + real evidence + a ranked ISSUES FOUND list. Do not soften.

=========================================================
STEP 2 — THERMONUCLEAR PASS + FIX
=========================================================
Run the thermo-nuclear-code-quality-review skill over the Goose surface code (correctness, dead/stale code, honesty-constraint violations, drift). DELETION GUARDRAIL: harden/dedupe/refactor, but DELETION IS A LAST RESORT — never delete new/in-progress/owner-requested code; commit any deletion separately. Fix every Step-1 issue; re-run its proof.

=========================================================
STEP 3 — CLOSE PHASE 0 (non-owner items only)
=========================================================
1. Gate 3: real live agent_thought_chunk OR honest codec-test-only statement.
2. Gate 5 non-owner items: deeper provider/settings parity; finish or honestly-block the long-tail boot shims; MAS honest-gate + manual WRV + distribution checks.
3. Re-prove the GOLDEN RULE live; CI/grep gate: NO provider/model roster literals in Epistemos/Goose/**/*.swift.
4. (§7 is GREEN-LIT — no sign-off checklist to produce. Keep the GOLDEN RULE + 5 proofs green as ongoing verification while you build Phase 1.)

=========================================================
★ MAS IN-PROCESS BACKEND — NEW WORKSTREAM (owner 2026-06-30; queue AFTER the white-screen P0 + the current Phase-1 reskin, but it is now IN SCOPE)
=========================================================
WHY: today's Goose backend is a SPAWNED SUBPROCESS (`goose serve --with-builtin developer` via `GooseRuntimeSupervisor` `Process()`/`run()`). That is the PRO path — FORBIDDEN on MAS (the sandbox + hardened runtime block subprocess spawn AND arbitrary command exec; the `developer` builtin = run-commands/install-deps; your own NO-HIDDEN-SIDECAR rule bans it). Today MAS just honest-gates Goose to "unavailable" — there is NO MAS Goose yet.
BUILD the MAS-legal backend: KEEP the reskinned Goose WebUI frontend, but SWAP its backend from the goose-serve subprocess to an IN-PROCESS ACP bridge backed by Epistemos's `agent_core` (Rust, via FFI — where orchestration already lives). The WebUI speaks ACP to an in-process server; NO subprocess, NO port race (this also kills the white-screen bug class on the MAS path).
  - BOUNDED MAS TOOLSET (sandbox-safe, the App-Store product): vault read/write (security-scoped bookmarks) · NETWORK/HTTP MCP · cloud APIs · in-app capabilities (PDF/search/etc.).
  - PRO-GATE (honest "Pro only" message on MAS, never silent-drop): the `developer`/shell builtin · install-deps · local stdio MCP (process-spawning) · the goose-serve subprocess.
  - RESULT: ONE WebUI, TWO backends behind `EPISTEMOS_APP_STORE` — Pro = goose-serve subprocess (full shell/autonomy); MAS = in-process agent_core (bounded). HONEST CAPABILITY GATING throughout; the GOLDEN RULE (live-enumerate inventory) still holds — agent_core must expose the same ACP catalog surface the WebUI expects.
  - This is the only way Goose ships on the App Store; it is real but bounded work (the agentic loop exists in agent_core — this is the ACP-over-FFI adapter + the tool-boundary split), not a native-Swift reimplementation (that stays FORBIDDEN below).

=========================================================
HARD GATES / FORBIDDEN
=========================================================
× Reviving native chat / per-route native-migration beyond Models — Option 1 LOCKED (chat + the rest stay WebView, reskinned; NO native chat).
× Starting Paseo §15 strategic fusion early — that's Phase 5, later. (Phase 1 native-frame + reskin is active now; §7 is green-lit.)
× Reviving Chat/Act/Work/Osaurus/three-engine; any separate local agent brain.
× Any hardcoded/app-maintained provider/model/skill roster (GOLDEN RULE).
× Reimplementing ANY Goose feature in native Swift (chat/providers/models/settings/sessions/skills/recipes/extensions/scheduler) — native is the FIXED frame ONLY.
× Silent ACP drops, hidden fallback, hidden inference/orchestration spawn.
× "Works on my machine" — must work on a clean staged build or honestly gate.

PROVEN-DONE bar (5 criteria for any [x]): real-state · live · migrates-existing-installs · end-to-end through the PRODUCTION (web UI) path · witnessed with a re-runnable artifact.

PARALLELISM: other agents are concurrently building Plan 2 (editor) + Plan 3 (capabilities) in the SAME repo. You own Epistemos/Goose/* + Epistemos/Agent/* + agent_core Goose lanes. Do NOT touch the editor surfaces (Epdoc/Prose/code-editor/HTML-workspace) or the Plan-3 capability files. The only shared seam is Goose note-context plumbing: Plan 2 supplies editor context/affordance routing; the LIVE Goose agent surface is yours.

THIS RUN = continue PHASE 1 per Option 1 + the nativeness reskin: build the native FRAME (window/nav-rail/launcher/permission pop-ups) around Goose's RESKINNED WebView, applying the verified tokens/springs/glass recipe (GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md) + GOOSE_AGENT_APPKIT_FOLLOWON_PLAN Steps 1–9 (native frame only; every Goose feature stays in the WebView; NO native chat). Keep the GOLDEN RULE + the 5 §7 proofs + security green as ongoing verification (no checklist, no stop). Never idle, never declare "done" — loop and harden until I type "stop".

Canon: GOOSE_MASTER_BUILD_PROMPT (DEFINITION OF DONE + FORBIDDEN), SURFACE §7, GOOSE_AGENT_APPKIT_FOLLOWON_PLAN §4–§6, GOOSE_PHASE_0_STATUS_AUDIT, the GOLDEN RULE.
```
