# PLAN 1 — Goose surface build prompt (paste to Codex)

> The agent (Codex) is mid-Plan-1. This continues it: **re-verify Phase 0 → close gaps → hand the owner a §7
> sign-off checklist → STOP for owner sign-off → only then the hybrid AppKit steps.** Hard-gated, thermonuclear-strict.
> Owner must personally sign §7; the agent may NOT self-declare Phase 0 done.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP/GOAL MODE — NEVER STOP until I (the owner) type "stop". This is a continuous goal spanning the WHOLE program (Phase 0 → Phases 1–5), not a one-shot. Keep working + hardening continuously; when a phase's work is complete, immediately continue to the next; when the whole program is built, keep looping (full thermonuclear pass → harden the weakest area → re-verify → repeat — never idle, never declare "done"). THE ONLY MANDATORY PAUSE is the §7 OWNER SIGN-OFF (the Phase 0 → Phase 1 gate): at that point hand me the sign-off checklist and WAIT for my sign-off message, then resume the loop into Phase 1. Commit at every clean point.

You are building the SINGLE Epistemos agent surface = Goose (reskinned). There is no Chat/Act/Work federation — Goose is the one surface (owner locked Goose-only 2026-06-28). AI is consolidated to Goose; do NOT revive Osaurus/Act, three-engine modes, or any separate local agent brain.

THE FULL PROGRAM (do NOT forget the later phases): Phase 0 = get Goose fully connected + PROVEN (WebView + ACP) — it's the prerequisite GATE, numbered 0 because it precedes the build, not a feature phase. After my §7 sign-off the program continues: Phase 1 = HYBRID APPKIT (native FRAME only — window/nav/launcher + permission pop-ups — wrapped around Goose's reskinned WebView; every Goose feature stays in the WebView) · Phase 2 = entry + navigation + settings · Phase 3 = feature parity + epistemos.context.snapshot bridge · Phase 4 = chat-primary default · Phase 5 = Paseo strategic fusion. The hybrid AppKit + WebView plan IS the goal; Phase 0 just unlocks it. Full program: GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md (Phases 0–5) + GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md (Steps 1–9).

YOU ARE STILL ON PHASE 0. It is NOT signed off. DO NOT start Epistemos/Agent/*, hybrid AppKit Phase 1, or Paseo §15 until I (owner) personally sign the §7 proof gate.

STEP 0 — PRESERVE WORK: if there are uncommitted changes in the tree, review + build-for-testing green + commit them at a clean point before any new work. Never leave work uncommitted (main-only; no worktree/branch loss).

★ NATIVENESS + UNIFIED LOOK (BINDING — read docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md, which carry the VERIFIED tokens/springs/glass recipe/code-to-lift):
  - ONE unified Apple-native look across AppKit + WebView + the Goose surface, from SHARED sources: SF Pro (-apple-system) + shadcn Apple tokens (Action Blue #0066cc + palette) + macOS HIG geometry + macOS-26 Liquid Glass + the EXACT SwiftUI spring values. The user must NEVER perceive native-vs-web — the seams vanish.
  - PLAN-1 SPLIT: NATIVE = the frame (window / nav-rail / launcher / permission+elicitation pop-ups) + Models picker. WEB-reskinned, PERMANENT (Option 1, no native chat) = chat, sessions, settings, recipes, skills, scheduler, MCP-app. Treatment = RETHEME Goose's EXISTING shadcn/Radix/Tailwind (verified: React 19 + shadcn + Radix + Tailwind v4 + framer-motion v12 + lucide) via Tailwind/CSS vars + tune its EXISTING framer-motion to the verified springs; do NOT replace components.
  - REAL Liquid Glass on native chrome (NSVisualEffectView / macOS-26 glassEffect — already in-repo: Theme/GlassModifiers.swift, Views/Shared/UnifiedFrostedGlass.swift; the Goose window is ALREADY isOpaque=false at Agent/AgentSurfaceWindowController.swift:37). Web body TRANSPARENT (drawsBackground=false — proven Views/Epdoc/EpdocKaTeXPreview.swift:79) over real glass + SF Pro + theme tokens + frost/specular fallback (refraction is Chromium-only, absent in WebKit).
  - MOTION: deeply fluid, ProMotion 120fps, MINIMAL. Verified SwiftUI springs → framer-motion {duration,bounce}: .smooth {0.5,0} (controls/sheets) · .snappy {0.5,0.15} (tabs/toggles/buttons) · .bouncy {0.5,0.3} (toasts/transitions) · .interactiveSpring {0.15,0.14} (drag). transform/opacity only; interruptible; honor reduce-motion. HARDENING: no lag/jank/bug, virtualize transcript/sessions, bounded webview live-set + teardown. A/B PIXEL-DIFF (rethemed web control vs native) — if distinguishable, FAIL.
  - GRAPH = already full AppKit/Metal → DO NOT TOUCH (the native-feel reference). SF Symbols: real ONLY in native chrome; web keeps lucide (ISC) restyled to match — never bundle SF Symbols into the webview.
  - CODE-RESEARCH: back every change with REAL openable code — in-repo file:line FIRST (reskin doc "CODE TO LIFT"), then vetted OSS + license + ProvenanceGate (clone/lift/adapter/clean-room/reject).
  - RESEARCH-BETWEEN-IMPLEMENTATION: between every slice, research local docs + the repo + online primary sources, and READ before editing as much as possible. Exhaustive — tokens are NOT a constraint; lost nuance + bugs are the expensive thing. NO-CONTRADICTION + PRESERVE-NUANCE + BREAK-NOTHING on every edit.

READ FIRST (canon order, do not skim):
  1. docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md (your own last verification — treat every PASS as a CLAIM to RE-PROVE)
  2. docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md
  3. docs/handoffs/GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md (the full program + DEFINITION OF DONE + FORBIDDEN list)
  4. docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md §0,§2,§7,§9-C,§14,§16,§17 (ignore ⛔ DEAD)
  5. docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md §4–§6 (the hybrid steps — AUTHORITY ONLY AFTER §7 sign-off)
  6. The GOLDEN RULE: provider/model/skill/extension inventory is ALWAYS live-enumerated from Goose via ACP — NEVER Swift-hardcoded.

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
4. Produce a §7 OWNER SIGN-OFF CHECKLIST = the exact things I must click/verify + the OAuth login you need me to perform.

=========================================================
HARD GATES / FORBIDDEN
=========================================================
× Marking Phase 0 done from build-green or live-proof alone — ONLY I sign §7.
× Starting Epistemos/Agent/*, hybrid AppKit, or Paseo §15 before my §7 sign-off.
× Reviving Chat/Act/Work/Osaurus/three-engine; any separate local agent brain.
× Any hardcoded/app-maintained provider/model/skill roster (GOLDEN RULE).
× Reimplementing ANY Goose feature in native Swift (chat/providers/models/settings/sessions/skills/recipes/extensions/scheduler) — native is the FIXED frame ONLY.
× Silent ACP drops, hidden fallback, hidden inference/orchestration spawn.
× "Works on my machine" — must work on a clean staged build or honestly gate.

PROVEN-DONE bar (5 criteria for any [x]): real-state · live · migrates-existing-installs · end-to-end through the PRODUCTION (web UI) path · witnessed with a re-runnable artifact.

PARALLELISM: other agents are concurrently building Plan 2 (editor) + Plan 3 (capabilities) in the SAME repo. You own Epistemos/Goose/* + Epistemos/Agent/* (after sign-off) + agent_core Goose lanes. Do NOT touch the editor surfaces (Epdoc/Prose/code-editor/HTML-workspace) or the Plan-3 capability files. The only shared seam is the Goose minichat: Plan 2 builds its note-context PLUMBING now, but the LIVE Goose agent surface is yours and stays Phase-0-gated.

DONE (this run) = updated VERIFICATION doc with honest evidence + all Step-1 issues fixed + the non-owner Gate-3/Gate-5 items closed-or-honestly-blocked + a ready §7 OWNER SIGN-OFF CHECKLIST. Then STOP and hand me the checklist. AFTER I sign §7 (separate message), continue with GOOSE_AGENT_APPKIT_FOLLOWON_PLAN Steps 1–9 (native frame only; every Goose feature stays in the WebView).

Canon: GOOSE_MASTER_BUILD_PROMPT (DEFINITION OF DONE + FORBIDDEN), SURFACE §7, GOOSE_AGENT_APPKIT_FOLLOWON_PLAN §4–§6, GOOSE_PHASE_0_STATUS_AUDIT, the GOLDEN RULE.
```
