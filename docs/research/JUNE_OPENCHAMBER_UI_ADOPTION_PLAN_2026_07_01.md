# June + OpenChamber → Epistemos UI adoption plan (2026-07-01)

> Built on the token study: `JUNE_OPENCHAMBER_DESIGN_STUDY_2026_07_01.md` (raw palettes/fonts/scales). This is the
> **actionable plan** after a 5-round component study of both cloned repos (both MIT).
> **Owner directive (REVISED 2026-07-01):** **June is THE absolute base UI ontology, app-wide.** Vendor June's whole UI as
> the SINGLE stack for every surface; reskin ONLY **fonts + theme-aware Epistemos palette**. **OpenChamber = a REFERENCE
> for small, subtle gap-fillers ONLY** (the few dev-power components June lacks), each **rebuilt in June's stack + June's
> look** — never vendored as OpenChamber's own stack. One stack, one design language, no Frankenstein.

## THE DECISION — June is the single stack; OpenChamber is a pattern reference
June and OpenChamber are **different UI stacks** (June = framework-free custom CSS + Tiptap + framer-motion; OpenChamber =
React19 + Tailwind v4 + CVA + Base UI + cmdk + Sonner). To avoid the two-stack friction entirely, **Epistemos adopts ONE
stack: June's.** June's whole UI becomes the base for **every** surface (Chat/Act/home AND Work/OpenGUI), rewired to our
backends and rethemed to Epistemos tokens + pixel greeting font. **OpenChamber is NOT vendored as a stack** — it is only a
**design reference** for the handful of dev-power components June genuinely lacks, which we **rebuild inside June's stack,
styled to June's look.** Result: one consistent design language, no cross-stack Frankenstein.

## THE PLAN
### ▸ BASE (all surfaces) ← JUNE's whole UI = THE ABSOLUTE
Vendor June's frontend verbatim as the single Epistemos web-UI stack. Rewire it from June's Tauri/cloud layer →
`agent_core` + your vault/STT (the MAS WebKit bridge is identical; the engine/MAS work is unchanged — you're swapping
which web UI sits on top). This **replaces the Goose web frontend** (see Plan-1 note) and provides the base for the Work
surface too. You get, as the app-wide language:
- Segmented mode switch (Chat/Voice/Meetings/Agent), frosted-glass Tiptap composer, notes/meetings **tabbed card chrome**,
  timestamped **transcript timeline** (source badges, per-row copy), spring dialogs, smart align-selected popovers,
  hover-intent tooltips, the **recording/meeting HUD** motion, dot-spinner, `@property` sidebar animation, reusable
  EmptyState, warm framer-motion springs, warm-oklch palette driven by a single `--brand` var (→ trivial Epistemos remap).

### ▸ GAP-FILLERS ONLY (subtle tangents) ← OPENCHAMBER as a PATTERN, rebuilt in June's stack
Where June has no equivalent — chiefly the **Work/OpenGUI (code) surface** — take the *idea/structure* from OpenChamber
and **re-implement it in June's stack + June's look** (June tokens, June spacing/radius, June motion, June/pixel fonts).
Do NOT vendor OpenChamber's Tailwind/Base-UI components. The gap-fillers worth borrowing as patterns:
- **Inline diff view** (gutter + syntax + unified/split toggle) — the one clear must-borrow for code review.
- **Command palette** (fuzzy + platform-aware ⌘/⇧ shortcut icons).
- **Code-file iconography** (Codicon-style file-type icons) — or just extend your Plan-4 mono set to cover file types.
- **Mermaid / worker markdown render**, and the **fork/undo/redo timeline** — nice-to-haves if the Work surface wants them.
Everything else June already does better or equally — do NOT borrow it.

## COMPONENT REFERENCE (from the 5 rounds) — what June owns vs the few OpenChamber gap-fillers
| Domain | JUNE = the base (use as-is, reskinned) | Borrow as PATTERN from OpenChamber? |
|---|---|---|
| Mode switch | ⭐ SegmentedControl (spring indicator) | — |
| Composer | ⭐ frosted Tiptap + category chips | (Work surface may want @mention//cmd affordances — rebuild in June) |
| Buttons / switch / checkbox | June (extend its minimal set) | pattern only if June lacks a variant |
| Modals / popover / tooltip | ⭐ spring + align-selected + hover-intent | — |
| HUD / recording / transcript / notes-meetings chrome | ⭐ June (best-in-class) | — |
| Sidebar / empty states / scrollbar / spinner / motion | ⭐ June | — |
| Icons | ⭐ June bespoke + `--brand` wordmark → your Plan-4 mono | file-type coverage idea (Codicons) |
| **Diff view** | June has NONE | ✅ **borrow pattern → build in June's look** |
| **Command palette** | June has NONE | ✅ borrow pattern |
| **Mermaid / worker markdown** | June = Tiptap editable only | ◐ optional pattern for Work |
| **Fork/undo timeline** | June has NONE | ◐ optional pattern for Work |
| Fonts | serif+sans+mono — **COMMERCIAL, drop** | (OpenChamber's IBM Plex mono = a free mono option) |

## RESKIN RECIPE (the ONLY things that change — fonts + palette, on the June stack)
1. **Fonts:** drop June's 3 commercial `.woff2` faces; set `--font-serif`/`--font-sans`/`--font-mono` (`src/styles/tokens.css`)
   → your **pixel greeting font** (greeting/section-labels only) + a free sans (body) + a free mono (JetBrains/IBM Plex).
2. **Palette:** repoint `--brand` (master hook) + the per-theme token blocks in `tokens.css` → **Epistemos tokens**
   (two-token-source w/ `EpistemosTheme.swift`). June's `color-mix(--brand …)` math recolors the whole UI for free;
   classic-B&W + custom palettes propagate automatically.
3. **Nothing structural** — no component rewrites, no layout changes. Gap-fillers get built new, in this same token+font system.

## UNIVERSAL polish to fold in (keeps it cohesive)
- **Theme-switch flicker-kill:** `:root.<switching> * { transition:none !important }` during any palette/light-dark swap
  (OpenChamber does this; port the one-liner into the June stack).
- **Token-driven SVG icons:** June's `currentColor + --brand` wordmark = the model for wiring your **Plan-4 mono icons**.
- **Native window frame** (rounded, vibrancy, traffic-lights) around the WKWebView.

## HONEST CAVEATS
- **The reskin is the easy 20%.** The real work = **rewiring the vendored June frontend to your backend** (`agent_core` +
  vault/STT), plus **building the 1–2 gap-fillers** (diff view especially) in June's stack. The look is nearly free.
- **Plan-1 implication:** June-as-base = **replacing the Goose web frontend** (engine/MAS unchanged). This *simplifies*
  Plan 1 (stop reskinning Goose's "bad" UI). Real redirect — confirm before the reskin agent pivots.
- **Fonts:** June's ABC Diatype / Martina Plantijn / Berkeley Mono are **commercial — never ship them.**
- **Vendor cost:** June = plain CSS (easy to lift). Rebuilding OpenChamber's diff view in June's stack is real work, but it
  keeps ONE design language — which is the point.
- Both repos MIT → vendor June with attribution; treat OpenChamber as reference (patterns/ideas, not vendored code).

## FEASIBILITY VERDICT — "go absolutely June" (2026-07-01, two-sided study)
**GO — feasible + bounded, because the expensive half is already built.** Two feasibility agents mapped both sides:

**Epistemos backend readiness = 8.5/10.** The seam that hosts Goose is directly reusable for June: `WorkSPAServer`
(loopback SPA) + a bootstrap script + `WKScriptMessageHandlerWithReply` bridges + `callAsyncJavaScript` streaming +
trusted-origin gating. The engine (`agent_core` `run_agent_session()` + the `AgentEventDelegate` streaming callbacks) is
mature. **Every local service June needs already ships in-process + MAS-ready:** STT (`EpistemosSpeechAnalyzer`, macOS 26),
TTS (Kokoro CoreML), vault CRUD, system-audio/meeting capture (ScreenCaptureKit).

**June frontend rewire = a NARROW, clean seam.** All backend calls funnel through ONE file — ~90 typed Tauri `invoke()`
commands in `src/lib/tauri.ts` + one Hermes-gateway **WebSocket** for agent streaming (`src/lib/hermes-gateway.ts`). **No
scattered HTTP/fetch.** State is already **local-first** (SQLite/Rust) — no remote-sync to unwind. Crucially, June's
streaming event schema (`message.delta` / `tool.*` / `approval.request` / `thinking.delta`) maps **almost 1:1** onto
`agent_core`'s `AgentEventDelegate` (`on_text_delta` / `on_tool_*` / `on_permission_required` / `on_thinking_delta`).

**Reconciling the two effort reads:** the June-side agent estimated "2–3 months" — but that assumed you'd have to BUILD
the backend (local agent runtime + STT/TTS). **You don't — Epistemos already has all of it (8.5/10).** So the real work is
an **adapter/shim layer**, not a rebuild:
1. **Vendor June's SPA** into the repo; host via the existing WorkSPA + WKWebView pattern (reuse Goose's).
2. **Command adapter:** implement June's ~90 `invoke()` commands as native handlers → route to `vault` / `agent_core` /
   `EpistemosSpeechAnalyzer` / Kokoro (via `WKScriptMessageHandlerWithReply`). Many map cleanly.
3. **Streaming shim:** replace June's Hermes **WebSocket** with the MAS **Path A** transport — `agent_core`
   `AgentEventDelegate` callbacks → `callAsyncJavaScript` push in June's event shape (~1:1 mapping).
4. **Reskin:** swap fonts (drop the 3 commercial faces → pixel greeting + free sans/mono) + remap `--brand` + the
   `tokens.css` per-theme blocks → Epistemos tokens.
5. **MAS-gate (same playbook as Goose):** DROP June's cloud-locked + forbidden bits — `os_accounts_*` (auth/billing/
   referral), June API gateway/Venice catalog/image-gen/issue-report, the **Hermes subprocess + CLI access + skill-taps +
   MCP add-server** (all 2.5.2-forbidden). You wire June's UI to YOUR in-process `agent_core`, not June's Hermes runtime.
6. **Gap-fillers:** rebuild the OpenChamber diff view (± command palette) in June's look for the Work surface.

**Honest cost:** a focused **multi-week integration** (the adapter is the bulk), NOT a months-long rebuild — because the
backend exists. Plus: you inherit a large fork to maintain (June's `App.tsx` is ~139KB — track upstream like Goose), and
June's "dictation-into-any-app" (global hotkey + insert via Accessibility) stays **Pro-only, not MAS** (as before).

**Plan-1 impact:** this **replaces the Goose reskin workstream**. Recommend PAUSING the Goose reskin (it's polishing a UI
you'll replace) and repointing Plan 1 to the June-frontend swap. The MAS bridge work Plan 1 is doing is **reused** (June
rides the same transport). Engine/MAS/services all unchanged.

## RECOMMENDATION (my best combo, per the revised directive)
**June is the absolute — its whole UI is the single Epistemos stack for every surface, reskinned to your tokens + pixel
font.** OpenChamber is demoted to a **pattern reference for subtle gap-fillers only** — realistically just the **diff view**
(and maybe a command palette / file-type icons) for the Work/OpenGUI code surface, each rebuilt in June's look. This gives
you one cohesive, best-in-class design language (June nails notes/meetings/chat/consumer polish), zero cross-stack friction,
and OpenChamber filling only the couple of developer-power holes June doesn't have.
