# Agent RE-SYNC PROMPT (2026-06-21) — realign to owner overrides, drop the "MAS-struct" corner-cutting

Paste to the build agent. It forces a re-read of the plan and realigns ALL newer overrides — not one feature.

---

STOP and RE-SYNC to the plan before continuing. You have been following older research RECOMMENDATIONS and
stale context instead of the owner's NEWER directives. The plan on disk is the authority — re-read it now and
realign everything below. GROUND IN FILES; owner directive ALWAYS beats a research rec on conflict.

## STEP 1 — RE-READ (fully, now)
- docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md — THE authority. Read ALL of it, ESPECIALLY the
  "‼️ CORRECTIONS" section and every 2026-06-21 section. This supersedes the convergence/feasibility research
  docs wherever they conflict.
- docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md
- memory: project_osaurus_full_clone_directive_2026_06_21
RULE: re-read the addendum at the START of EVERY iteration from now on. Do not act from stale context or from
a research recommendation the owner has already overridden.

## STEP 2 — REALIGN these overrides (all of them, not just one feature)
1. **MAS IS NON-RESTRICTIVE — stop the "MAS-struct" corner-cutting EVERYWHERE.** Do NOT use "MAS sandbox /
   MAS structure" as a reason to cut capability, gate features off, or do a reduced version — ANYWHERE, for
   ANY clone or feature. The app ships **DUAL BUILD**: a **PRO/direct-distribution** build (non-sandboxed,
   FULL capability) + a **MAS** build that is **as robust as Pro**, excluding ONLY the genuinely-ungrantable
   (today: just the Linux-VM sandbox) and swapping in a MAS-safe substitute (WASM/cloud — research best).
   Build FULL capability by default; never assume "MAS = smaller." Only one feature is actually MAS-blocked.
2. **FULL CLONE, not leaf-by-leaf port — for Goose AND every clone.** Vendor the real repo + needed crates as
   REAL dependencies (Goose: goose/goose-providers + `rmcp` as real deps), like Osaurus. STOP hand-porting
   individual wire types (Role/Message/etc.) — that's the cherry-pick → "never fully cloned → muddiness"
   failure the owner banned. Resolve dep clashes (accepted cost, like dual-MLX).
3. **WORK = KEEP OPENCODE'S REAL TERMINAL UI** (palette-matched, named "work"), with Goose + Hermes +
   OpenClaw fused in as the engine BENEATH it. Do NOT do a native SwiftUI rebuild (feasibility Option C2/B is
   OVERRIDDEN; owner chose Option A — keep the real UI). The bundled OpenCode runtime is FINE (Pro build).
4. **Tamagotchi render-fix = IN SCOPE** (keep the agent-creation Tamagotchi style + fix too-small/inner-square
   render bug). Not blocked by the off-limits-Companion guard.
5. **All other 2026-06-21 overrides hold:** ACT reskin = current-chat-UI discipline (fonts/palette/composer);
   preserve model picker + command palette + 38-tool agent panel + Epistemos Picks; per-clone SETTINGS tabs;
   landing BLUR + mode-entry animations (act=native blur-reveal, work=ASCII/pixel typewriter); motion-language
   TRIAD (blur + ASCII typewriter + micro-motions, titles + display-only, noticeable-not-bloated, never in
   editors); Prose editor 120fps/50k-word = no-regress; EPDOC MD-V2 (md=source, projections); chat NEVER
   deleted (quarantine + porting cycles); no fake-done (real-state tests); no WIP/stash; substrate+IP =
   certain/lower-not-deferred.

## STEP 3 — UPDATE THE MAP + CONTINUE
Update docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md so every row reflects these realignments (esp. Goose status
→ "full-clone, redo from leaf-port"; work → "OpenCode real UI + Goose engine"; MAS → "dual-build, full
capability, no MAS-struct cuts"). Then continue the build on the corrected path, Osaurus/act-first. Report:
what you realigned, what you're redoing, and confirm no MAS-struct corner-cuts remain anywhere.
