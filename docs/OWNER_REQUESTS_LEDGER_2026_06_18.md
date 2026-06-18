# OWNER REQUESTS LEDGER (2026-06-18) — the authoritative checklist

The owner's words: *"everything I have been asking is not being done. it's being
lazy… go back and look at my queries and requests and actually do them."* This is
the complete list of EVERY owner request this session. **A line is DONE only when
the owner can SEE and USE it in the rebuilt app** — visible, reachable, and
functional for the owner's ACTUAL setup (local-first, frequently NO cloud
configured). "Compiles + committed + tests pass" is NOT done. "Gated into
invisibility" is NOT done. Re-audit each against the running app; fix until real.

## REALITY-AUDIT RULE (applies to every line)
1. Build the app; actually trace the UX path the owner would take.
2. If a feature is hidden unless cloud/Pro/some-state — that's a FAIL for a
   local-first owner. Make it reachable + functional on LOCAL by default; gate
   only the genuinely-cloud/Pro-only pieces, and when gated, show WHY (honest,
   visible), never just vanish.
3. No feature is "done" until the owner can demonstrably use it.

## REOPENED — owner reports these DON'T WORK (fix first, verify in-app)
- [ ] **#1 LOCAL FOR ALL MODES — STOP THE HIDDEN GPT ROUTE.** Owner (verbatim):
      *"not even having cloud selected it goes to gpt, you should be able to use
      my local for all modes."* This is the #1 honesty-constraint violation: with
      NO cloud selected, Act/agentic still routes to GPT (cloud). FIX: the LOCAL
      agent loop (`LocalAgentLoop`, `canRunLocalAgentLoop`) must back Act / agentic
      / cowork on the owner's LOCAL models by default — Chat AND Act AND every
      cowork affordance work on local. NEVER auto-route to GPT/any cloud unless
      the owner EXPLICITLY enabled cloud or pressed "route to cloud" for that turn.
      If a local model can't do a step, show the honest P1.4-style blocker (free
      memory / smaller tier / optionally route to cloud) — never silently use GPT.
      Audit EVERY route seam: TriageService, ConfidenceRouter, RuntimeRouter,
      ChatCoordinator agent path, `availableOperatingModes`, `CoworkChatMode`,
      `usesAutomaticCloudRouteForChatSurfaces`, `preferredAutoRouteCloudProvider`,
      `effectiveChatSurfaceSelection`. Regression: no-cloud + Act → local, not GPT.
- [ ] **ACT mode** — reported not working. Root: gated behind cloud/Pro
      (`CoworkChatMode.actAvailable` / `availableOperatingModes`) AND the auto-cloud
      route above. FIX: Act runs the LOCAL multi-step agent loop by default (see
      #1); cloud only augments when explicitly chosen. Visible + togglable + works
      with zero cloud configured.
- [ ] **QUEUE** — reported not working. Only appears while `isProcessing` + draft
      non-empty. Make it discoverable and prove the staged message actually sends
      on completion in the running app.
- [ ] **CONTEXT** — reported not working. Only shows when tools were used + as a
      tiny composer strip. Assemble it as a real, visible panel; populate from
      actual run telemetry; show an honest empty state, not nothing.
- [ ] **COWORK SURFACE** — the Act/Progress/Working-folder/Context/Queue/Connectors
      pieces are scattered into the composer, NOT the cohesive cowork LAYOUT from
      the owner's Claude-Desktop screenshot. Assemble the real surface (panels),
      reachable from chat. (P7.6)
- [ ] **Local models "not working" → showing GPT instead of local** in Settings.
      Investigate WHY other local models don't load/resolve; fix the label so
      local rows show the real local model, never a cloud/GPT fallback unless
      cloud is the genuine active route. (SettingsView activeChatModelDisplayName /
      activeLocalTextModelDisplayName / `?? .openAI` ~1542; AgentBlueprint /
      Constellation / ModelProfile rows.)
- [ ] **Palette preview for ALL themes** — currently gated `if pair == .custom`
      (SettingsView ~4081). Generalize `CustomThemePaletteSwatch` to every
      `ThemePairCard` so every theme shows the palette preview.
- [ ] **Custom-theme font** — claimed fixed (4b0a5e59e); VERIFY in-app that picking
      a font on the custom theme actually changes rendered text, every level.

## Picker / routing / honesty
- [x] Think → VibeThinker, never Gemma 12B (P1.6) — verify still true on all paths.
- [x] No hidden Qwen on tool/attachment seam (P1.10) — verify in-app with attach.
- [x] Apple Intelligence selectable native route (P1.7) — verify visible.
- [x] Download/install progress visible (P1.8) — verify a real install shows it.
- [x] Fast low/med/high effort visible (P1.9) — verify the composer hint shows.
- [ ] Vault "best essay in my vault" returns ranked answer w/ title/path/reason,
      not a generic reply or empty "no vault retrieval" (P2.2 — still partial).

## Chat capability + parity
- [ ] Capability ceiling Fast→tools, real on LOCAL (P7.1) — verify tools actually
      run from chat on a local model, not just documented.
- [ ] MiniChat / Note / Graph chat parity — verify each surface really has the
      Main-chat capabilities in-app (P7.5).
- [ ] Tool toggles actually gate the runtime AND are visible/usable (P2.1).
- [ ] In-chat skills run; MCP/connectors (Slack/Gmail/Drive/Notion) actually
      connect + are usable (P2.3/P2.4/P7.6 connectors).

## Surfaces the owner asked for
- [ ] HTML workspace is BROKEN (can't see code) → fix + HTML canvas live-viewer the
      chat can drive (P7.2). NOT STARTED — owner flagged broken.
- [ ] Terminal + console actually work (Pro/dev) (P7.3).
- [ ] "WORK" mode (the OpenCode surface) = THREE clean modes Chat / Act / Work
      (NOT buried in Act). Work = deep terminal access to on-disk notes/research +
      ALL app skills/tools from chat, local=cloud parity. Toggle lives UPWARD at
      the TOP of the search page (not on the search bar) and turns the search page
      INTO Work/OpenCode. After the revised UX map (P7.4/P7.4a).
- [ ] Provider logos (B&W, prefer pixel-art), context-specific, in Settings +
      picker + chat (P6.1). NOT DONE — assets staged in docs/brand-assets/lobehub.
- [ ] Voice: Kokoro + MOSS (special reading voice) + auto-read-screen / read-replies
      / STT granular toggles + pixel-art retro filter (P7.7). NOT BUILT (research only).

## Architecture / process
- [ ] Founding thesis everywhere: determinism + verifiability on small local models;
      substrate health + Knowledge Core (P5/R-ARCH) — more important than 70B.
- [x] Auto-commit + push every slice to GitHub — verify still pushing.
- [ ] Osaurus deep-read + full-replace eval (P3); Unsloth port + training UI (P4.1).
- [ ] Settings decluttered + coherent (P6.4c) — verify it reads clean in-app.

## Verdict docs already produced (decisions, not yet built)
R-VOICE (Kokoro+MOSS+filter), R-EVE (pattern only), R-OKF (export+privacy+dedup),
R-PROMPT (cache-stable prefix + lean schemas), CHAT_UX_MAP (3 axes). These are
DECISIONS — the BUILD + in-app verification still has to happen.
