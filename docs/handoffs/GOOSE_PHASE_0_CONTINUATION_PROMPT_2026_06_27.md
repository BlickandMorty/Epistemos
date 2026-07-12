# Goose Phase 0 — Continuation + Verification Prompt (2026-06-27)

> 🔴 **SUPERSEDED 2026-07-02 (OpenChamber pivot) — DO NOT BUILD FROM THIS.** A continuation prompt for the DEAD reskin-Goose-surface program. current surfaces are Experimental/1Code + MAS/June; OpenChamber/ProAgent are deletion targets; goose = one engine. Historical reference only. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> 🛑 **SUPERSEDED 2026-06-29 — DO NOT PASTE THIS.** §7 is GREEN-LIT; Plan 1 is on Phase 1, Option 1 (no native
> chat). The only loop prompt to paste is `docs/prompts/PROMPT_PLAN_1_GOOSE.md`. "STILL ON PHASE 0 / wait for §7 /
> produce a sign-off checklist" below is HISTORICAL. Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md`.

**Purpose:** paste-ready prompt to resume the Codex agent after it stopped mid-Phase-0. It does NOT
hand over the hybrid/AppKit plan — Codex is still on Phase 0 and is forbidden from starting
`Epistemos/Agent/*` until the owner signs the §7 proof gate. Step 1 forces an independent
verification pass (re-prove every prior "done" claim from scratch) before any new code.

**Status when written:** Phase 0 ~90% code / ~96% proof gate, NOT signed off. Gate 5 ("nothing lost
vs real Goose") still FAIL. `Epistemos/Agent/` does not exist; no `GOOSE_PHASE_0_SIGNOFF.md`.
Source of truth for the gate: `GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md` + `SURFACE...2026_06_25.md` §7.

---

## PASTE THIS TO CODEX

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

Do not stop until I say stop. You are the agent building the SINGLE Epistemos agent surface = Goose (reskinned). There is no Chat/Act/Work federation — Goose is the one surface.

[🛑 HISTORICAL 2026-06-29 — §7 is GREEN-LIT; Plan 1 is on Phase 1, Option 1 (no native chat). The line below is SUPERSEDED — do not act on it. This whole doc is DO-NOT-PASTE.] YOU ARE STILL ON PHASE 0. It is NOT signed off. DO NOT start Epistemos/Agent/*, hybrid AppKit Phase 1, or Paseo §15 until I (owner) personally sign the §7 proof gate.

READ FIRST (do not skim):
  - docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md §0, §2, §7, §9-C, §14, §16, §17 (ignore any ⛔ DEAD/SUPERSEDED section)
  - docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md (your own last audit — treat every "PASS" in it as a CLAIM to be re-proven, not a fact)
  - docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md §4–§6
  - The GOLDEN RULE: Epistemos must enumerate Goose's provider/model inventory through the same ACP/catalog paths Goose uses — NEVER Swift-hardcoded or manually-added lists. Behave exactly like real Goose; any deviation is a bug.

=========================================================
STEP 1 — INDEPENDENT VERIFICATION PASS (DO THIS FIRST, BEFORE ANY NEW CODE)
=========================================================
Trust nothing previously marked done. Re-prove every Phase 0 claim from scratch by re-running the actual command/test and pasting the REAL output. For each item below, mark PASS / PARTIAL / FAIL with re-runnable evidence (command + trimmed output + artifact path). Actively hunt for: overclaims, mock-only tests masquerading as live proof, silent drops, regressions, and drift from real Goose.

A. BUILD & TESTS — re-run, paste real results:
   - xcodebuild ... build-for-testing (must be green)
   - The focused Goose suites the audit claims pass: GooseACPClient (10/10), GooseLiveIntegrationTests (6/6), GooseProviderMutationLiveIntegrationTests (2/2), GooseSettingsMutationLiveIntegrationTests (1/1), GooseSourceMutationLiveIntegrationTests (1/1), GooseWebRouteLiveIntegrationTests (1/1), golden fixture suite (4/4), codec/client/event-bridge/shim/native-affordance/runtime suites (44/44).
   - Confirm zero regressions against the broader suite. If a "live" test silently degrades to a mock when goose serve is absent, FLAG IT.

B. THE 5 PROOF GATES (SURFACE §7) — re-run each live and report status honestly:
   1. Real Goose Electron fallback launches (CDP reachable, process tree cleaned).
   2. goose serve ACP WebSocket reachable (/health + /acp init).
   3. new → prompt → stream(thinking/tool/answer) → permission → result. (Audit says gate 3 is PARTIAL — agent_thought_chunk not seen live. Re-test; either get a live thinking-chunk or state plainly it's codec-test-only.)
   4. Staged Web UI boots in WebView via the narrow shim.
   5. NOTHING LOST vs real Goose (currently FAIL — see C/F).

C. GOLDEN RULE / CATALOG FIDELITY (highest priority):
   - Re-prove providers AND models enumerate via ACP (the audit claims 65 provider entries live). Paste the live count + a sample.
   - grep the Swift sources for ANY hardcoded provider names, model ids, or manually-curated inventory lists. If found, that violates the GOLDEN RULE — report each site.
   - Diff Epistemos's surfaced inventory against what real Goose shows for the same config. Any item present in real Goose but missing in Epistemos = a "nothing lost" FAIL; list them.

D. NO SILENT DROPS: confirm every unhandled/custom ACP method returns structured diagnostics + JSON-RPC method-not-found, never a silent drop. Try at least 3 unhandled methods and paste replies.

E. SECURITY / HONESTY INVARIANTS:
   - No hidden fallback, no secret subprocess/inference spawn on the live path.
   - Provider API keys go to macOS Keychain, NEVER UserDefaults (grep to prove).
   - goosed subprocess hardened per agent_core security.rs harden_cli_subprocess.
   - MAS build shows an honest "Pro only" gate, never a hidden spawn.
   - ADD-DON'T-EDIT: confirm no surgery on Goose's vendored Rust core / agent path / protected env-config-protocol names.

F. NOTHING-LOST PARITY: enumerate the real Goose feature/route set (providers, models, settings, extensions, skills, recipes, scheduler, subagents, sessions, etc.) and mark each as: implemented-native / implemented-runtime / compatibility-preserved / hidden-shell / deferred-with-visible-error. Any feature that is silently missing = a bug, not a deferral.

G. CLEANUP: after the run, confirm no listener on :3284 and no leftover goose / xcodebuild / xctest / swift-frontend processes.

H. HONESTY AUDIT: for every "PASS" in GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md, confirm a re-runnable artifact exists and actually re-runs today. Flag anything stale, mock-only, environment-dependent, or overclaimed.

OUTPUT of Step 1: write docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md with a per-item PASS/PARTIAL/FAIL table, real evidence, and an explicit ISSUES FOUND list (ranked by severity). Do not soften. If something the prior audit called PASS is actually weaker, say so.

=========================================================
STEP 2 — FIX THE ISSUES
=========================================================
Fix every issue found in Step 1 before adding new functionality. Re-run its proof. Commit at clean points (the clone has its own git).

=========================================================
STEP 3 — CONTINUE PHASE 0 (NEXT ORDER), only after Step 1+2:
=========================================================
1. OAuth / browser-mediated provider authenticate SUCCESS path + deeper provider/settings parity — or an HONEST blocked UI where not yet wired (note: the owner may need to perform the actual OAuth login; build the path and tell me exactly where to do my part).
2. Finish or honestly block remaining long-tail shims: showMessageBox, file read/write, app launch/refresh/close, notification settings, binary path, directory ensure.
3. Add a fresh-machine staging/health note so GooseWebUI availability isn't tribal knowledge.
4. Re-run MAS honest gate, manual WRV, and distribution checks.
5. Produce a §7 owner sign-off checklist (the exact things I must click/verify to sign).

NON-NEGOTIABLES:
 • Goose stays independently GREEN at all times (§17). Two gates in order: (1) Goose green standalone, (2) Epistemos integration. The app never compiles Goose into itself.
 • ADD, DON'T EDIT (§14.3). Wiring lives in Epistemos across the ACP/MCP seam + reskin overlay.
 • All Goose paths Pro/Developer-ID (subprocess); MAS hides or shows honest "Pro only".
 • Preserve thinking blocks on tool_use; stream every token, no buffering; agent decides termination.

FORBIDDEN:
 • Starting Epistemos/Agent/*, hybrid AppKit Phase 1, or Paseo §15.
 • Marking Phase 0 complete from build-green or live-proof alone — only the owner signs §7.
 • ANY hardcoded/manually-curated provider or model list.
 • Silent ACP drops, hidden fallback, or hidden inference/orchestration spawn.

DONE (for this run) = GOOSE_PHASE_0_VERIFICATION_2026_06_27.md with honest evidence + all Step-1 issues fixed + NEXT ORDER 1–4 closed or honestly blocked + a ready §7 owner-sign-off checklist. Then stop and hand me the sign-off checklist.

Canon: SURFACE §7, GOOSE_AGENT_APPKIT_FOLLOWON_PLAN §4–§6, GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md, the GOLDEN RULE.
```

---

## Owner's part (don't lose this)

Two things only the owner can do, so Phase 0 cannot fully close without you:
1. **OAuth provider authenticate success** likely needs you to perform the actual browser login.
2. **The manual §7 sign-off.** Codex must hand you a checklist; you verify + sign. Do not let it mark
   Phase 0 done from build-green or live-proof alone.

After sign-off — and only then — Codex gets the hybrid/AppKit plan
(`GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md`) and may create `Epistemos/Agent/*`.
