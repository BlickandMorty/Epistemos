# AGENT LOOP WRAPPERS — REAL-WORK-FIRST (owner 2026-06-30; refreshed 2026-07-01)

> These are the **loop wrappers** to paste to each running build agent so it stays "in the zone": do the REAL /
> user-visible work first and treat hardening as a capped, secondary fallback — never an infinite bound/redact sweep.
> The actual plans (build order + hard gates + canon) live in `PROMPT_PLAN_1/2/3` — these wrappers point at them and
> bind the WORK-ORDER directive. NOT a plan paste-prompt; the only plan paste-prompts remain `PROMPT_PLAN_1/2/3`.
>
> **2026-07-01 refresh — grounded in a full static-analysis pass of the current tree:**
> - **P0 for ALL THREE = GREEN THE BUILD.** `feat/goose-surface` does not currently compile, so the owner can't test
>   anything. Three one-line fixes green it: (a)+(b) are Plan 1's, (d) is Plan 3's — land them first and independently.
> - **Proof is softened (owner):** the owner tests the app directly. Call code done on your own honest self-check /
>   compiling build — do NOT block "done" on a formal in-app proof ceremony. But the build MUST compile so they CAN
>   test, and you must NEVER fake capability (honest gating stands).
> - **Corrections since the old wrappers:** Plan-1 white-screen is RESOLVED (renders) — do not re-fix it. Plan-2's 5
>   "deferred" caps are ALREADY code-complete + wired (the "empty didReceive" note was stale). Plan-1 **MAS is now
>   owner GREEN-LIT** (was deferred) — see its section.
> - Pace: **do NOT rush** — correctness + canon-fidelity over speed — but this is a **FINISH pass**: close the listed
>   reals, then ONE capped hardening pass on what you touched, then **STOP + REPORT**. No new app-wide hardening loops.

---

## → Plan 1 (Goose) — paste to the Plan-1 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ FINISH MODE — PLAN 1 (Goose). Don't rush (correctness + canon over speed), but CONVERGE: close the reals, ONE capped
hardening pass on what you touch, then STOP AND REPORT — do NOT infinite-loop hardening.
READ FIRST: docs/prompts/PROMPT_PLAN_1_GOOSE.md + docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md (Option 1) +
docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md + docs/research/GOOSE_FLAT_PIXEL_RESKIN_SPEC_2026_06_30.md
(owner-approved look = clean flat + slight pixel twist, theme-aware, NO blue focus ring — NOT the withdrawn flat-pixel-art
amendment). For MAS also read GOOSE_MAS_BUILD_CANON_2026_06_30 + GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.

P0 — GREEN THE BUILD (blocks the owner from testing anything; commit as a clean "green the build" checkpoint):
 1. Epistemos/Goose/GooseWebNativeAffordanceBridge.swift ~2420 — make `nonisolated enum GooseNativeJSONSizeBudget`
    (permits/consume are pure/Sendable; module default is @MainActor; called from nonisolated nativeSettingValueIsPersistable).
 2. Epistemos/Goose/GooseSurfaceAvailability.swift:3 — make `nonisolated struct GooseSurfaceAvailability` (or mark
    isReady/unavailableMessage/menuTitle nonisolated); GooseSurfaceHealthRow's nonisolated helpers read them.

THEN — remaining REAL work, in order:
 3. Reskin pixel-parity to GOOSE_FLAT_PIXEL_RESKIN_SPEC (primary visible work). In
    GooseWebSurfaceSupport.nativeFeelCSS(theme:): (a) flatten surfaces borderless — differentiate by tint + soft shadow,
    not a --color-border line; (b) KILL the focus ring — --color-ring-* must not be a visible accent; (c) inject radius
    (base 11 + per-component 8/9); (d) tune framer-motion to the 4 canonical springs (.bouncy{0.5,0.3} /
    .interactiveSpring{0.15,0.14} / .smooth{0.5,0} / .snappy{0.5,0.15}); (e) the pixel-font twist on headings/labels/companions.
 4. Custom-palette propagation (open OWNER-REVIEW BUILD bug, not a design decision): a LIVE theme change (incl. the CUSTOM
    palette) must re-inject the CSS into the running Goose WebView AND re-tint the native frame in lock-step — not boot-only.
 5. Then pull the next visible Goose phase (entry/nav/settings inside the web UI, epistemos.context.snapshot parity).
 DEFER: white-screen robustness hardening — it RENDERS; final hardening pass only, never a reason to pause features.

MAS — OWNER HAS GREEN-LIT IT. Run it as a SEPARATE focused pass AFTER steps 1-4 land (don't collide with the reskin in the
shared tree). Foundation exists: GooseInProcessACPServer.swift + GooseMASAgentCoreCatalog.swift compile behind
#if EPISTEMOS_APP_STORE + runtime flag EPISTEMOS_MAS_GOOSE_V0. The v0 is a STUB and must NOT ship as-is:
  - Wire runInProcessAgentCore session/prompt to the REAL agent_core agentic loop over the UniFFI bridge (preserve thinking
    blocks, stream every token, honor stop_reason, DispatchQueue.main.async NEVER .sync in FFI callbacks) — replace the
    CloudLLMClient passthrough. Replace empty extensions/recipes/skills/schedules + static catalog with live enumeration.
  - Implement the real tool-boundary split in agent_core (Pro-gate cli_passthrough/terminal/registry-bash/stdio_mcp/imessage/
    apple/code_execution; keep vault/HTTP-MCP/cloud/in-app) with honest structured "Pro only" errors — replace the Swift
    keyword heuristic. Keep the owner gate + one-flag rollback intact; do NOT weaken it; no faked agent capability.

PROOF (softened): the owner tests directly — call code done on a compiling build + your own honest self-check, don't wait on
a proof ceremony. Never fake capability.
KEEP CANON: Option 1 (no native chat; chat/sessions/settings stay reskinned WebView), NO native Models picker / NO native
route router (owner override), graph DO-NOT-TOUCH, two-token-sources, retheme-not-replace, the 4 springs. Commit at every
clean point.
DONE WHEN: build green; reskin matches the spec (flat, no focus ring, radius, springs, pixel twist); custom palette re-tints
live everywhere; MAS in-process path runs the REAL agent_core loop behind the gate. Then one capped hardening pass, STOP + REPORT.
```

## → Plan 2 (Editor / HTML Workspace) — paste to the Plan-2 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ FINISH MODE — PLAN 2 (Editor / HTML Workspace). Don't rush, but CONVERGE: close the reals, ONE capped hardening pass, then
STOP AND REPORT.
READ FIRST: docs/prompts/PROMPT_PLAN_2_EDITOR.md + docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md + the nativeness doctrine.
NOTE: your 5 "deferred" HTMLWorkspaceCapabilityStatus caps (Full-surface regenerate, App message-bridge, JS console/error
capture, DOM picker/style inspector, Python/Pyodide) are ALREADY code-complete + fully wired — the plan's "empty didReceive"
note is STALE (HTMLWorkspaceSafeAPI + didReceive + dispatchAppBridgeResponse are implemented). isLive:false only because the
app target couldn't launch (out-of-lane Goose compile breaks).

WHAT'S LEFT, in priority order:
 1. PRIORITY-0.0 — dark/light toggle crash fix + in-app crash recorder. Guard theme re-injection against mid-load /
    deallocating WKWebViews across HTMLWorkspaceEditorView / EpdocEditorChromeView / CodeEditorView / HTMLWorkspacePreviewView.
    Add NSSetUncaughtExceptionHandler + SIGABRT/SIGSEGV handler writing to <vault>/.epcache/diagnostics/.
 2. PRIORITY-0.1 — root-cause the BLANK code editor (MarkEdit chrome renders, body empty): chunk-loader WKURLSchemeHandler /
    index.html load / message-handler runtime bug. (This fix IS in-lane; the "regenerate must not touch the code editor"
    rule below is about the regenerate FEATURE, not this bug.)
 3. Once the app launches (after the tree-wide P0 greens land): verify each of the 5 caps works in-app and FLIP its isLive
    flag to true — honest self-check, no proof ceremony.
 4. Full-surface regenerate "REAL VISION" polish: pixel-minimal styling per the nativeness canon + the drag-drop /
    context-picker direct-manipulation FEEL (plumbing + one-click stream→preview→apply→revert is already done; this is the feel layer).

PROOF (softened): owner tests directly — flip isLive on your own honest self-check once it works in-app; don't wait on a
formal ceremony; never fake.
DO NOT TOUCH: the code editor / Source lens / CoreEditor as the REGENERATE target (regenerate must not modify code-editor
files); the graph (DO-NOT-TOUCH); Goose/* (Plan 1) — depend on Goose only via the regenerate ACP seam; Plan-3 capability files.
KEEP CANON: lens model (Note=Epdoc / Source=MarkEdit / Prose=TK2; old code editor kept as v1 legacy), unified tokens/springs,
graph DO-NOT-TOUCH. Commit at every clean point.
DONE WHEN: no theme-toggle crash + crash recorder writing diagnostics; code-editor body renders; the 5 caps flipped to live
after working in-app; regenerate feels direct/pixel-minimal. Then one capped hardening pass, STOP + REPORT.
```

## → Plan 3 (Capabilities) — paste to the Plan-3 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ FINISH MODE — PLAN 3 (Capabilities: browser-use Pro, arXiv, voice/Kokoro, work backends). Don't rush, but CONVERGE: close
the reals, ONE capped hardening pass, then STOP AND REPORT.
READ FIRST: docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md + docs/research/PLAN_3_CAPABILITIES_2026_06_28.md + the cited codepacks.

P0 — GREEN THE BUILD (blocks the owner from testing; commit as a clean "green the build" checkpoint):
 1. Epistemos/Bridge/ToolTierBridge.swift — safeDomain(_:) declares `let bounded` TWICE in the SAME scope (~line 391 and
    ~line 403). Rename one (e.g. the line-403 local → `clamped`).

THEN — remaining REAL work:
 2. Kokoro TTS — bring the voice LIVE. Native engine is real + wired (LocalPackages/KokoroPipeline: KokoroPipeline /
    KokoroSynthesisExecutor / HarmonicSource; KokoroCoreMLSynthesizer.render). Finish the model-bundle install path and flip
    KokoroVoiceGateStatus isReady false→true once synthesis actually produces audio (owner will listen).
 3. AVSpeech unwiring — EpistemosSpeechSynthesizer still wraps AVSpeechSynthesizer; per owner AVSpeech must NOT be the shipped
    read-aloud/TTS voice. Route the shipped path to Kokoro; AVSpeech may remain in code but unwired from the shipped surface.
 4. browser-use Pro signed packaging — the ad-hoc-signed BrowserUsePro.bundle + SIGNATURE_MANIFEST + smoke suite are DONE.
    Only gap = Developer-ID identity + notarization (distribution ops): do it only if the owner has the Dev-ID cert ready;
    otherwise leave PACKAGE_RESULT.notarization honestly deferred and REPORT it as the one blocker.
 5. Small cleanup — the Goose→browser-use MCP delegation tool descriptions (omega-mcp catalog / browser_schema) read like
    internal notes; make them honest user-facing strings.

DO NOT BUILD (owner-cut — leave honestly NotConfigured): Obscura native stealth, anti-fingerprint (UA/canvas/WebGL) spoof,
ColBERT, model-management. DO NOT TOUCH: Goose/* (Plan 1), the editor surfaces + PDFView (Plan 2), the graph.
PROOF (softened): owner tests directly — flip honest gates on your own self-check once real; never fake capability.
KEEP CANON: Goose = the ONE user-facing agent (browser-use is a subordinate MCP sub-agent), unified-native (native frame +
reskinned WebView, NOT native chat), graph DO-NOT-TOUCH, honest capability gating. Commit at every clean point.
DONE WHEN: build green; Kokoro voice live (or honestly blocked on model install, reported); AVSpeech off the shipped path;
signed packaging done or Dev-ID/notarization reported as the sole remaining gate. Then one capped hardening pass, STOP + REPORT.
```
