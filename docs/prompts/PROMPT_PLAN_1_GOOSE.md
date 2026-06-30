# PLAN 1 — Goose surface build prompt (paste to Codex)

> 🎨 **OWNER DESIGN DIRECTIVE — 2026-06-30 (CURRENT CANON, identical in EVERY plan):** the look = **HIGH-QUALITY FLAT · MINIMAL · THEME-AWARE · OPTIMIZED.** KEEP the Apple-native **FRAME** — rounded-corner window, vibrancy, traffic-lights, the calibrated springs (the curved-white native window the owner likes STAYS). **SURFACES (panels · buttons · lists · inputs) are FLAT + BORDERLESS:** NO thick outlines, NO hard box borders, NO 1px rules — differentiate by a subtle background tint + spacing + a very soft shadow only. NOT the old thick-outline pixel-art look, and NOT translucent-glass on every surface. **TOTAL THEME-AWARENESS:** every surface (native + editor-web + Goose-web) reads the Epistemos tokens for ALL palettes incl. the user CUSTOM palette; no hardcoded color; two-token-sources in lock-step. Full doctrine: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

> ★ **GOOSE = JUST THE GOOSE WEB UI IN A CLEAN NATIVE WINDOW — GET RID OF ALL THE NATIVE APP-SIDE CHROME (owner 2026-06-30):** the native app-side chrome (the `AgentNavigationRailView` nav rail + any native Models/Settings/Providers/per-route panels) DUPLICATED Goose's own web sidebar (Chat/Sessions/Models/Skills/Recipes/Extensions/Scheduler/Apps showed TWICE) AND it LAGGED on every click. **REMOVE ALL OF IT.** Native = the **bare window FRAME ONLY** (rounded window + vibrancy + traffic-lights + native permission/elicitation pop-ups) — nothing else. **Goose's OWN reskinned web UI is the ENTIRE surface AND the navigation**, and ALL controls/buttons/nav stay on the FAST goose-web side — add NO native SwiftUI controls (the native/AppKit side is what hangs). **Also KILL the big boxy window border, but KEEP the curved corners.** The Goose UI STAYS a WebView (Option 1). Get the curve WITHOUT a boxy frame: let the WebView fill the window edge-to-edge and take its rounded corners from the native window's own corner mask OR from the WebView layer's `cornerRadius` + `masksToBounds` — NOT from a bordered container drawn around it. Remove any surrounding frame/inset/border/background box; the WebView content meets the rounded window edge directly. = curved corners, ZERO boxy outer look. Do NOT build or keep `AgentNavigationRailView`, the hybrid content router, or per-route native migration — that whole workstream is CUT (removes a large chunk of the old Phase-1/2/3 native work). ⚠️ SCOPE: this is ONLY the Goose window. Epistemos's OWN non-Goose surfaces — notes/editor/graph/capabilities/landing/companions (Plan 2 + Plan 3) — are SEPARATE windows and are NOT touched/deleted by this.

> ★ STATUS (2026-06-30): §7 was GREEN-LIT by the owner — Plan 1 is ON PHASE 1, **Option 1 locked (native FRAME
> only; Goose WebView owns chat + sessions + settings + models + every other route; NO native chat; NO native
> route migration; NO native app-side rail).** Steps 1–3 are historical context only (hardening · goosed swap
> behind a flag · old router/native route slice); the owner later cut that native route work because it duplicated
> Goose and lagged. This prompt CONTINUES Phase 1 per Option 1 + the flat Claude-like pixel reskin. Hard-gated,
> thermonuclear-strict. (The §7-gate /
> "wait for sign-off" framing below is HISTORICAL — superseded by the green-light; keep the verification *discipline*
> (GOLDEN RULE, security, parity) as ongoing, but there is no sign-off pause to wait on.)

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP/GOAL MODE — NEVER STOP until I (the owner) type "stop". Continuous goal across the WHOLE program (Phase 0 → Phases 1–5), not a one-shot. ★ WORK ORDER (owner 2026-06-30 — REAL WORK FIRST, HARDENING CAPPED): each cycle do the next REAL / USER-VISIBLE item and PROVE it in a cold-launched app before the next. Phase-1 remaining reals, IN ORDER (VISIBLE work first): (1) reskin pixel-parity + unified native-blend polish (the shippable, user-visible Goose surface — you've been doing this well, KEEP GOING); (2) the rest of the visible Goose phases (2–5). ⛔ DO NOT DO MAS WORK — no EPISTEMOS_APP_STORE / in-process-backend / goosed-transport work, AT ALL. The owner has said this REPEATEDLY; it is OUT OF SCOPE. Build ONLY the visible Goose features + reskin/native-blend polish. (MAS is a separate, later, owner-INITIATED effort — never start it yourself.) FINISH THE VISIBLE PLAN first. ⛔ NO UNREQUESTED REFACTORING — do NOT restructure, split files, move code, rename, or "centralize/dedupe" WORKING code; touch a file ONLY to build/finish a feature or fix a real bug. Keep the tree COMPILING at every step (all agents share one tree). Hardening is SECONDARY + BOUNDED + LAST: after a real item, at most ONE focused pass on the code you just touched — do NOT launch open-ended app-wide bound/redact sweeps, and NEVER let hardening preempt an unfinished visible item. WHITE-SCREEN: it RENDERS now (owner-confirmed 2026-06-30) ✅ — do NOT re-fix it; its robustness hardening (atomic hash-gated UI staging + `GooseWebUIResolver` verifying every referenced `<script src>`/`<link href>` resolves + ACP-decouple, per `docs/handoffs/GOOSE_WHITE_SCREEN_DIAGNOSIS_2026_06_30.md`) belongs in the FINAL hardening pass so a future rebuild can't regress it — it currently renders only because a rebuild happened to stage consistent assets. When the reals are done, pull the next REAL phase work; there is ALWAYS more real feature/polish work — do NOT declare 'done' and do NOT stop to 'report done' (only the OWNER decides done, by typing stop). KEEP CODING real Goose features; fold the white-screen robustness into that final polish, never as a reason to stop. (§7 GREEN-LIT 2026-06-29 — past the gate, ON Phase 1; keep the §7 proofs green but do not wait for sign-off.) Commit at every clean point.

★ THIS PLAN WAS UPGRADED (2026-06-30) — RE-READ the canon (it changed) and reconcile any stale claim you hit (no-contradiction). WHAT CHANGED for Plan 1: (1) §7 GREEN-LIT → you are on PHASE 1; OPTION 1 LOCKED — bare native FRAME only, Goose WebView owns every visible Goose route, NO native chat, NO native nav rail, NO native Models picker, NO route migration. (2) NEW app-wide NATIVENESS + UNIFIED-LOOK mandate (the ★ block below + docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md + docs/research/GOOSE_FLAT_PIXEL_RESKIN_SPEC_2026_06_30.md — verified tokens/springs + owner-approved clean flat Claude-like pixel twist; retheme Goose's existing shadcn, don't replace). (3) CODE-RESEARCH (real openable code) + RESEARCH-BETWEEN-IMPLEMENTATION now required. If anything in this prompt or your plan docs still implies "wait for §7 / native chat / native nav rail / native Models / replace components," it is STALE — fix it at the source.

★ STALE-SEQUENCING GUARD (2026-06-29 audit): STEP 1/STEP 3 below are ongoing proof/hardening obligations, not a resurrected Phase-0 gate. Re-prove them while continuing Phase 1; do not pause for sign-off, do not rebuild native chat, and do not migrate more Goose routes into Swift. See docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md.

You are building the SINGLE Epistemos agent surface = Goose (reskinned). There is no Chat/Act/Work federation — Goose is the one surface (owner locked Goose-only 2026-06-28). AI is consolidated to Goose; do NOT revive Osaurus/Act, three-engine modes, or any separate local agent brain.

THE FULL PROGRAM (do NOT forget the later phases): Phase 0 = get Goose fully connected + PROVEN (WebView + ACP) — it was the prerequisite GATE (now GREEN-LIT). The program is now in: Phase 1 = clean native macOS window frame only (rounded window + traffic lights + native permission pop-ups) around Goose's reskinned WebView; Goose's own web UI provides all navigation and every visible Goose route · Phase 2 = entry + navigation + settings inside Goose web UI · Phase 3 = feature parity + epistemos.context.snapshot bridge · Phase 4 = chat-primary default · Phase 5 = Paseo strategic fusion. The hybrid AppKit + WebView plan IS the goal; Phase 0 just unlocks it. Full program: GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md (Phases 0–5) + GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md (Steps 1–9), with the 2026-06-30 no-native-rail/no-native-route override above.

YOU ARE ON PHASE 1 (§7 green-lit 2026-06-29, owner-refined 2026-06-30). Build the bare native FRAME (window + traffic lights + native permission/elicitation pop-ups only) wrapped around Goose's RESKINNED WebView, per Option 1 + the owner-approved flat Claude-like pixel reskin (every Goose feature stays in the WebView; chat is NEVER native). Continue visible Phase-1 reskin/native-blend polish. (Paseo §15 strategic fusion = still later, Phase 5.)

STEP 0 — PRESERVE WORK: if there are uncommitted changes in the tree, review + build-for-testing green + commit them at a clean point before any new work. Never leave work uncommitted (main-only; no worktree/branch loss).

★ WHITE-SCREEN — RESOLVED (owner-confirmed 2026-06-30): the Goose window RENDERS. Do NOT chase it, do NOT prioritize it, do NOT re-fix it. The ONLY remaining white-screen work is robustness hardening (atomic hash-gated UI staging + `GooseWebUIResolver` verifying referenced assets resolve + ACP-decouple, per `docs/handoffs/GOOSE_WHITE_SCREEN_DIAGNOSIS_2026_06_30.md`) and it belongs in the FINAL hardening pass ONLY — never as a reason to pause feature work. Focus = FINISH THE VISIBLE PLAN.

★ NATIVENESS + UNIFIED LOOK (BINDING — the FULL verified detail lives in docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md: exact tokens/springs/glass recipe/code-to-lift. READ THEM — this paste is intentionally lean.):
  - PLAN-1 SPLIT: NATIVE = bare macOS window frame + native permission/elicitation pop-ups only. WEB-reskinned PERMANENT (Option 1, NO native chat, NO native Models, NO native nav rail) = Goose's own sidebar/nav + chat/sessions/settings/models/providers/recipes/skills/scheduler/MCP-app → RETHEME Goose's existing shadcn/Radix/Tailwind + tune its framer-motion to the verified springs (do NOT replace components).
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
E. SECURITY/HONESTY — no hidden fallback/secret spawn on the live path; keys in Keychain NEVER UserDefaults (grep); goosed subprocess hardened per agent_core security.rs; ADD-DON'T-EDIT the Goose Rust core. MAS/App-Store checks are out of scope until the owner explicitly starts MAS.
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
2. Gate 5 non-owner items: deeper provider/settings parity; finish or honestly-block the long-tail boot shims. MAS honest-gate/manual WRV/distribution checks are explicitly deferred until the owner starts MAS.
3. Re-prove the GOLDEN RULE live; CI/grep gate: NO provider/model roster literals in Epistemos/Goose/**/*.swift.
4. (§7 is GREEN-LIT — no sign-off checklist to produce. Keep the GOLDEN RULE + 5 proofs green as ongoing verification while you build Phase 1.)

=========================================================
★ MAS / APP-STORE WORKSTREAM — DEFERRED, OWNER-INITIATED ONLY
=========================================================
Do NOT build MAS Goose, in-process ACP, app-store transport, app-store distribution gates, or `EPISTEMOS_APP_STORE`
Goose backend changes in this plan run. MAS is a separate later effort and starts only when the owner explicitly says
to start MAS. Until then, Plan 1 work is visible Goose Pro/non-MAS: clean native window, Goose WebView UI, ACP parity,
provider/model live enumeration, reskin polish, and non-MAS runtime hardening.

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

THIS RUN = continue PHASE 1 per Option 1 + the owner-approved flat Claude-like pixel reskin: build the bare native FRAME (rounded window + traffic lights + native permission/elicitation pop-ups only) around Goose's RESKINNED WebView, applying the verified tokens/springs recipe (`GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`) and the approved spec (`GOOSE_FLAT_PIXEL_RESKIN_SPEC_2026_06_30.md`). Goose's own Web UI owns every route and navigation surface. Keep the GOLDEN RULE + the 5 §7 proofs + security green as ongoing verification (no checklist, no stop). Never idle, never declare "done" — loop and harden until I type "stop".

Canon: GOOSE_MASTER_BUILD_PROMPT (DEFINITION OF DONE + FORBIDDEN), SURFACE §7, GOOSE_AGENT_APPKIT_FOLLOWON_PLAN §4–§6, GOOSE_PHASE_0_STATUS_AUDIT, the GOLDEN RULE.

★ FINAL PHASE — MAS IN-PROCESS BACKEND (DEFERRED · OWNER-GATED · LAST). Do NOT start this until (a) the owner EXPLICITLY green-lights "start MAS" AND (b) all the visible Goose work above (reskin + features) is finished and good — the ⛔ DO NOT DO MAS WORK rule in the WORK ORDER stays in force until then. This is the App-Store path: KEEP the reskinned WebUI, SWAP the `goose serve` subprocess → an IN-PROCESS ACP backend over `agent_core` (Rust/FFI) behind `EPISTEMOS_APP_STORE`. Foundation already exists (MAS entitlements incl. `network.server` + `cs.allow-jit` + vault bookmarks; `agent_core` UniFFI bridge; the `WorkSPAServer` loopback pattern; the `EPISTEMOS_APP_STORE` gate to re-wire). FULL SPEC = build order · transport · tool-boundary split (Pro-gate cli_passthrough/terminal/stdio_mcp/bash/imessage/apple/code_execution; keep vault/HTTP-MCP/cloud/in-app) · the 4 "truly good" loop rules · the sandboxed-build PROOF BAR → `docs/research/GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md` (§6 = deep-research on transport + App-Review risk, landing). When MAS is green-lit, build to that spec and prove it in a real sandboxed/notarized build (not Debug). ★ ALREADY-BUILT — KEEP IT INERT: an agent already committed a MAS in-process backend (commit `0d9ce0045`, `runInProcessAgentCore` + `GooseMASAgentCoreCatalog`). It is now **OWNER-GATED OFF by default** via `EPISTEMOS_MAS_GOOSE_V0` (default off) in `GooseRuntimeSupervisor` — on a MAS build it stays honestly `.unavailable` unless the owner sets the flag. ⛔ Do NOT enable that flag, do NOT remove/weaken the gate, and do NOT do any further MAS work — MAS stays INERT until the owner explicitly green-lights it. (Debug/Pro builds are unaffected; this only keeps MAS builds off.)
```
