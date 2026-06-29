# AGENT 1 — Goose Surface (Plan 1) — Audit Trail & Research Log

**Date:** 2026-06-29 · **Agent:** Agent 1 = the Goose-surface build + audit agent (loop `5a0cef97`).
**Purpose:** a no-bullshit audit of *everything Agent 1 did and found* this session — edits made, research
done, findings, proposed-but-unapplied fixes, and open items — so other agents and the owner have a single
honest record.

> ⚠️ **ATTRIBUTION (read first).** A **separate concurrent agent** (loop `017add54`, commit prefix
> `research(goose-reskin)` / `research(nativeness)`) did the nativeness-reskin research (11 rounds), the
> prompt **upgrade notices**, and the doctrine/reskin/editor-plan edits. **That is NOT Agent 1.** This log
> records ONLY Agent 1's own work; where it references the other agent's output it is labelled. Agent 1's
> role this session: (a) Phase-1 native-frame hardening, (b) the white-screen investigation, (c) a deep
> adversarial audit of the doc-updating agent's "contradiction-free" claim.

---

## 1. EDITS AGENT 1 ACTUALLY MADE (committed; nothing left uncommitted)

| Commit | Files | What |
|---|---|---|
| `4d9309514` | `Epistemos/Goose/GooseWebSurfaceView.swift`, **new** `docs/handoffs/GOOSE_PHASE_1_HARDENING_2026_06_29.md` | Route-state fix: single `@State activeRoute` source-of-truth (fixes MED-1 post-sync reload snapping to hub + MED-2 startup rail clicks dropped). App-target build green on isolated DerivedData. |
| `e99d01c39` (earlier this session) | `Epistemos/Agent/AgentSurfaceRootView.swift`, `AgentNavigationRailView.swift`, `GooseWebSurfaceView.swift` (+`route` param), `EpistemosApp.swift` (⌘⇧A) | Native Phase-1 FRAME: nav rail drives the embedded reskinned WebView's route. |
| `4615eb5ab` (earlier) | removed 5 native-chat files | Reverted a wrong native-chat build back to frame-only (Option-1 compliance). |
| `f9bb4e057` (earlier, superseded) | `AgentSurfaceWindowController.swift` (kept) | Window controller; the native-chat parts of this were reverted in `4615eb5ab`. |

**Memory written by Agent 1** (outside the repo, `~/.claude/.../memory/`): updated
`goose-phase0-hardening-loop-state.md`; created `goose-white-screen-investigation.md`.

**Agent 1 made NO edits to** the prompt files, the Goose canon docs, the nativeness doctrine, or the reskin
doc. The audit below is **read-only findings + proposed fixes**, not applied — pending owner go-ahead (the
decision question was raised and the owner deferred it; Agent 1 will re-ask it in the future per instruction).

---

## 2. RESEARCH & FINDINGS

### 2a. Phase-1 native-frame hardening — DONE
Thermonuclear review of the frame (`AgentSurface*`, `AgentNavigationRailView`, `AgentSurfaceRootView`,
`AgentSurfaceWindowController` + the `route` delta): **0 HIGH / 3 MED / 2 LOW**. Independently re-verified
3 lifecycle properties PASS: window-close → no orphaned `goose serve`; rail nav → no goose-serve re-spawn
(same WebView identity); double-window (⌘3+⌘⇧A) → honest occupied-port fail (no 2nd spawn).
- **Fixed:** MED-1 (`reloadSurfaceAfterProviderSync` hardcoded `/?`), MED-2 (initial load read a stale
  captured `self` → dropped startup rail clicks). Both via `@State activeRoute`.
- **Deferred (documented in `GOOSE_PHASE_1_HARDENING_2026_06_29.md`):** MED-3 two-window shared-supervisor
  refactor (transitional; honest occupied-port today), LOW-1 controller-direct `stop()` (onDisappear +
  SIGTERM backstop already cover it), LOW-2 auto-recover `.failed` on port-free (manual Restart works).

### 2b. White / blank Goose surface (owner repro) — OPEN, needs one owner-side datum
Owner saw the Goose surface render **white/blank**. Their build = Xcode DerivedData app built **Jun 29
10:04** (latest Goose commit in it `edd426f76`) → this is the **core ⌘3 Goose WebView**, NOT Agent-frame /
route work. **Ruled out (headless):** backend (`goose serve` /health 200 in <1s, bundled arm64 v1.39.0),
SPA bundle staging (`goose-desktop/index.html` manifest `acpMode:true`, 77 assets, relative paths),
boot-shim injection (`window.electron`/`window.appConfig` injected at `.atDocumentStart`).
**Remaining candidates (need running app):** runtime SPA JS throw, or WorkSPA serving 404, or pre-load
blank. **Decisive next datum:** the in-app **details panel** (slider button, top-right) rows
(supervisor / ACP / UI-server / surface) — or the WebKit console. Full state in memory
`goose-white-screen-investigation.md`.

### 2c. Deep doc-consistency audit — verdict on the doc-agent's "contradiction-free": **REFUTED**
Method: 4 adversarial sub-audits (canon docs / Plan 2 / Plan 3 / cross-prompt+nativeness) + Agent-1 grep +
a deep read of `GOOSE_AGENT_APPKIT_FOLLOWON_PLAN`. **The claim is accurate ONLY inside the 3 prompt files'
current text; the canon those prompts elevate to authority is unreconciled.** Also methodologically: the
files were being edited concurrently during the check, so any "contradiction-free" snapshot was unverifiable.

**What genuinely holds (credit):** spring values byte-identical across all 3 prompts + doctrine + reskin
(`.smooth {0.5,0} · .snappy {0.5,0.15} · .bouncy {0.5,0.3} · .interactiveSpring {0.15,0.14}`); upgrade
banner present in all 3 prompts; `#0066cc`/SF Pro/radius consistent; Plan-2 prompt body clean; Plan-3
WORK-MODE + arXiv PRIORITY-0 present; Plan-2 capability count is genuinely 4 live / 5 deferred (no contradiction).

#### HIGH — Goose / Plan-1 canon (re-verified STILL PRESENT 2026-06-29)
1. **`FOLLOWON_PLAN §4–§6` is a live native-chat plan, and `PROMPT_PLAN_1:41` declares §4–§6 "IN AUTHORITY NOW."** The `:18` override only covers the route table/charter *above* §4. Still present: `:241` "Gate 7 | Native chat path default"; `:243` "native shell + **native chat loop**"; `:269` "Step 2 — Transcript reducer"; `:286/:335` `useNativeChatPath`; `:390` "AgentTranscript reducer"; §6 charter `:361/:392` "chat must go native by Gate 7"; §7 DoD `:405`.
2. **`MASTER_BUILD_PROMPT`** `:253` Phase-1 box header literally "**native chat** + WebView long-tail"; `:97` ARCHITECTURE "native chat path."
3. **Stale Phase-0 gating contradicting §7 green-lit:** `MASTER:29/68/159/248`; `STATUS_AUDIT:10-19/114` (paste-ready "DO NOT start Agent" block); `VERIFICATION:11` "still not signed off", `:287` **§7 Sign-Off Checklist**, `:312` "Do not start Phase 1."
4. **Models-picker over-correction** — the "no native chat" fix endangers the ONE locked native route: `MASTER:282` "No native picker" + `DOCTRINE:78` "pickers = WEB (not native)" vs `DOCTRINE:34/:81` + `PLAN_1:29` "native Models picker." Risk: an agent rips out the built `GooseNativeModelsView`.
5. **Systemic:** 0 of 5 Goose canon docs has a 2026-06-29 reconciliation banner; the new **retheme-don't-replace** nativeness mandate is absent from all canon (lives only in `PROMPT_PLAN_1` + the 2 research docs).

#### MED — Plan 3
- `PLAN_3_CAPABILITIES_2026_06_28.md:56` (the "wins-on-conflict" doc) **drops `.interactiveSpring`** (lists only 3 springs).
- Prompt calls 4 **already-shipped, on-disk** codepacks (browser-use / Voice / meeting-STT / whole-app-logos) "OWED / write-first" (`:11/:40`) + omits them from READ-FIRST (`:23`) → duplicate-work risk.
- Build order (`:36`) reads as fresh work despite SHIPPED canon.
- **Cross-cutting:** shared `Theme/EpistemosTheme.swift` + `Theme/GlassModifiers.swift` are **unassigned across all 3 plans** while the binding doctrine tells everyone to edit them → collision risk.

#### MED — Plan 2 (supporting docs only; prompt body is clean)
- `GOOSE_MINICHAT_CODEPACK_2026_06_27.md §1:12` + `:137-138` still headline "**native SwiftUI chat**" (has a top supersede banner, but the §1 body/Net recommendation are unedited → contradicts its own banner; prompt lists it READ-FIRST).
- `EDITOR_CANONICAL_PLAN_2026_06_27.md:177` still says minichat is "**Phase-0 gated**" (the same doc lists that wait as STALE at `:19`).

#### LOW
- `DOCTRINE` carries a 5th informational spring `.spring {0.55,0.18}` (additive, not a conflict).
- `PLAN_1` upgrade notice isn't the literal first line (consistent convention across all 3).
- `PLAN_2:15` lens order (Prose-first) vs `:41`/canon (Prose wired LAST); HTML-workspace double-homed (P0 + step 8).
- `MASTER:293` residual "Gate 7" label on Phase 4 (Phase 4 = chat-primary *landing* is itself correct).
- Stale arXiv code citations in `PLAN_3:15` (`ArxivIngestService.swift:77` now points elsewhere; fix already shipped at `:40-65`).

---

## 3. PROPOSED FIXES — NOT YET APPLIED (awaiting owner go-ahead)
Agent 1 deliberately did **not** edit any of these (the apply-fixes decision was deferred by the owner).

- **A.** Add a 2026-06-29 reconciliation banner atop the 5 Goose canon docs (§7 green-lit · Option 1: native = frame + Models picker only, chat/all features WebView-permanent, NO native chat · retheme-don't-replace · pointer to `PROMPT_PLAN_1` + `DOCTRINE`).
- **B.** Widen `FOLLOWON:18` override to cover §4–§7 (mark Steps 2/3/9 + §6 charter + §7 DoD DELETED inline).
- **C.** Carve the Models-picker exception into `MASTER:282` + `DOCTRINE:78`.
- **D.** Fix `MASTER:253/97` native-chat header + architecture lines.
- **E.** Banner-strike the `VERIFICATION` §7 checklist + `STATUS_AUDIT` paste-block.
- **F.** (Plan-3 lane) add `.interactiveSpring {0.15,0.14}` to `PLAN_3_CAPABILITIES_2026_06_28.md:56`.
- **G.** (Plan-2 lane — coordinate w/ concurrent agent) fix `GOOSE_MINICHAT_CODEPACK §1` + `EDITOR_CANONICAL_PLAN:177`.
- **H.** Assign shared `Theme/*` ownership across the 3 plans.

A–E are Agent 1's lane (Goose canon) and the concurrent agent is NOT touching them; F/G/H belong to other lanes.

---

## 4. OPEN ITEMS / DEFERRED DECISIONS
- **DEFERRED QUESTION (re-ask in the future, per owner):** scope + depth of applying the §3 fixes — Goose-canon only vs all lanes; banners vs full section rewrites; Agent 1 vs the doc-updating agent.
- **White-screen bug:** needs the owner's details-panel datum (§2b) to root-cause.
- **Phase-1 deferred:** MED-3 shared-supervisor singleton (two-window), LOW-1/LOW-2.
- **Pre-existing blocker (not Agent 1's):** `EpistemosTests/ArxivPlan3Tests.swift` (Plan-3) breaks the shared test target → focused Goose unit suites blocked; Agent 1 validates via app-target build + live ACP probes.
