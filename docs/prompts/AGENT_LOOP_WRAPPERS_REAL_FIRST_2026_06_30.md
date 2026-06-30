# AGENT LOOP WRAPPERS — REAL-WORK-FIRST (owner 2026-06-30)

> These are the **loop wrappers** to paste to each running build agent so it stays "in the zone": do the REAL /
> user-visible work first, prove it in-app, and treat hardening as a capped, secondary fallback — never an infinite
> bound/redact sweep. The actual plans (build order + hard gates + canon) live in `PROMPT_PLAN_1/2/3` — these wrappers
> just point at them and bind the WORK-ORDER directive (now also baked into the top of each PROMPT_PLAN). NOT a plan
> paste-prompt; the only plan paste-prompts remain PROMPT_PLAN_1/2/3.

---

## → Plan 1 (Goose) — paste to the Plan-1 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — PLAN 1 (Goose) — NEVER STOP until I (the owner) type "stop".
READ FIRST: docs/prompts/PROMPT_PLAN_1_GOOSE.md (your plan — build order, hard gates, the WORK-ORDER directive at top)
+ the canon it cites (docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md = Option 1; docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md).
★ WORK ORDER (binding — REAL WORK FIRST, HARDENING CAPPED): each cycle do the next REAL / USER-VISIBLE item and PROVE it
in a cold-launched app before the next. Reals IN ORDER: (1) WHITE-SCREEN P0 — retry-until-ready ACP (poll /health,
backoff-retry init, re-init the WebUI ACP client on first healthy connect); PROVE cold-launch renders chat in seconds
with NO manual reload. (2) MAS in-process backend (keep reskinned WebUI; swap transport goosed-subprocess → in-process
ACP over agent_core behind EPISTEMOS_APP_STORE). (3) reskin pixel-parity polish.
HARDENING IS SECONDARY + CAPPED: after a real item, at most ONE focused pass on the code you just touched — NEVER an
open-ended app-wide bound/redact sweep, and NEVER let hardening preempt an unfinished visible item. When the reals are
done, pull the next REAL phase work; only when NO real/visible work remains, do ONE full hardening pass, then STOP AND
REPORT to me — do NOT infinite-loop hardening.
KEEP CANON: Option 1 (no native chat; chat/sessions/etc stay reskinned WebView), graph DO-NOT-TOUCH, two-token-sources,
retheme-not-replace. Commit at every clean point. Stop only when I say stop.
```

## → Plan 2 (Editor / HTML Workspace) — paste to the Plan-2 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — PLAN 2 (Editor) — NEVER STOP until I (the owner) type "stop".
READ FIRST: docs/prompts/PROMPT_PLAN_2_EDITOR.md + docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md + the nativeness
doctrine. Obey the WORK-ORDER directive baked at the top of the plan.
★ WORK ORDER (binding — REAL WORK FIRST, HARDENING CAPPED): each cycle ship the next REAL / USER-VISIBLE item and PROVE
it in-app before the next. Reals IN ORDER = the 5 deferred HTML-Workspace caps: (1) Full-surface REGENERATE (chat
rewrites the whole surface into a live site — atomic/versioned/reversible/AI-provenance replaceDocument + streaming),
(2) app message-bridge (implement the empty didReceive), (3) JS console/error capture, (4) DOM picker/style inspector,
(5) Python (Pyodide/WASM, build-vendored) — plus any owed lens/MarkEdit work. Flip each capability isLive→true ONLY
when it really works in-app.
HARDENING IS SECONDARY + CAPPED: after a real item, at most ONE focused pass on the code you just touched — NEVER an
open-ended app-wide bound/redact sweep, and NEVER let hardening preempt an unfinished visible item. When the reals are
done, pull the next owed/unspecced REAL item; only when none remain, ONE full hardening pass, then STOP AND REPORT.
KEEP CANON: lens model (Note=Epdoc / Source=MarkEdit / Prose=TK2; old code editor kept as v1 legacy), unified
tokens/springs, graph DO-NOT-TOUCH. Commit at every clean point. Stop only when I say stop.
```

## → Plan 3 (Capabilities) — paste to the Plan-3 agent
```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — PLAN 3 (Capabilities) — NEVER STOP until I (the owner) type "stop".
READ FIRST: docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md + docs/research/PLAN_3_CAPABILITIES_2026_06_28.md + the cited
codepacks. Obey the WORK-ORDER directive baked at the top of the plan.
★ WORK ORDER (binding — REAL WORK FIRST, HARDENING CAPPED): FIRST list your remaining DEFERRED/gated items from each
capability's gate-status (ArxivPullGateStatus, BrowserCapabilityStatus, etc.). THEN each cycle build the next REAL
capability to LIVE and PROVE it in-app: (1) browser-use signed-Pro packaging (vendored core 0.13.2 + Gradio web-ui in
WKWebView + MCP tools + honest Pro gate), (2) bring each capability's deferred bits to live (arXiv, voice/Kokoro,
meeting-STT, vault-MCP, provenance, obscura, extensibility, apple-native, edge-parse) — flip gate flags ONLY when real.
HARDENING IS SECONDARY + CAPPED: after a real item, at most ONE focused pass on the code you just touched — NEVER an
open-ended app-wide bound/redact sweep, and NEVER let hardening preempt an unfinished capability. When the reals are
live, pull the next owed REAL item; only when none remain, ONE full hardening pass, then STOP AND REPORT.
KEEP CANON: Goose = the ONE user-facing agent (browser-use is a subordinate MCP sub-agent), unified-native (native frame
+ reskinned WebView, NOT native chat), graph DO-NOT-TOUCH, honest capability gating. Commit at every clean point. Stop
only when I say stop.
```
