# CURRENT Loop Prompt (2026-06-21, evening) — replaces the earlier continuation prompt for the loop

Paste this as the loop directive. It points at the FULL, current plan and makes re-reading it each iteration
the rule (the plan has grown a lot since this morning).

---

You are the Epistemos build loop (cwd /Users/jojo/Downloads/Epistemos). The on-disk plan is the AUTHORITY,
not your running context. Owner has flagged drift before — so:

## EVERY ITERATION, FIRST: re-read the FULL plan
- **docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md — READ IT IN FULL, top to bottom, every iteration.**
  It has grown all day; the NEWEST sections matter most: "‼️ CORRECTIONS", DUAL-BUILD distribution, OpenCode
  "HEAVINESS" mitigation, motion language, per-clone settings, UI/animation spec, north star. It SUPERSEDES
  the convergence/feasibility research docs wherever they conflict.
- Also: docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md + memory project_osaurus_full_clone_directive_2026_06_21.
- RULE: never act from stale context or a research recommendation the owner has already overridden. Owner
  directive ALWAYS beats a research rec.

## CURRENT STATE
- ACT = Osaurus: FULL clone vendored + dual-MLX consolidated + OsaurusCore LINKED + act runs end-to-end. ✅
- NEXT: WORK mode. Plus the act UI reskin + animations (build after engine), per directives.

## NON-NEGOTIABLE DIRECTIVES (full detail in the addendum — this is the summary)
1. **FULL CLONES, not leaf-by-leaf ports** — Goose AND every clone: vendor the real repo + crates as REAL
   deps (Goose: goose/goose-providers + `rmcp`), like Osaurus. STOP hand-porting wire types. Resolve dep
   clashes (accepted).
2. **WORK = keep OpenCode's REAL TERMINAL UI** (the minimal terminal look the owner loves), palette-matched
   live, named "work". Render the REAL TUI in a NATIVE terminal view (SwiftTerm/PTY) — do NOT ship the
   Electron/Tauri web GUI (that's the bloat; it's optional, OpenCode is headless-first). Bun engine =
   lazy-launch on work-open, loopback, kill-on-idle. Goose + Hermes + OpenClaw fuse as engines BENEATH the
   OpenCode shell. NO native rebuild (Option A, not C2/B). The terminal look IS preserved.
3. **MAS NON-RESTRICTIVE everywhere** — no "MAS-struct" corner-cutting for any clone/feature. DUAL BUILD:
   Pro/direct-distribution (full) + MAS (as robust as Pro, only the genuinely-ungrantable excluded — today
   just the Linux-VM sandbox, with a WASM/cloud substitute). Build full capability by default.
4. **ACT reskin = current-chat-UI discipline** (cream palette, monospace user bubble, Anthropic-Sans answers,
   flat-distinct composer, monospace section headers, provenance inspector, vault chips); PRESERVE model
   picker (real logos/tiers/install-state) + "Epistemos Picks" + command palette + 38-tool agent panel;
   Tamagotchi agent-creation kept + render-fixed (in scope); per-clone SETTINGS as tabs (Epistemos|act|work|
   beyond); landing BLUR + mode-entry animations (act=native blur-reveal; work=ASCII/pixel typewriter);
   MOTION LANGUAGE TRIAD (blur + ASCII typewriter + micro-motions on titles + display-only, noticeable-not-
   bloated, never in editors); live themes incl. custom drive all surfaces.
5. **PROTECT:** chat backend QUARANTINED, NEVER deleted (porting cycles before retire); Prose editor
   120fps/50k-word NO-REGRESS; landing-page ontology; EPDOC MD-V2 (md=source, projections; coexists with
   Prose, both shine).
6. **DISCIPLINE:** no fake-done (real-state tests only); no WIP/stash hiding places; reuse-not-rebuild owner
   IP (RustLSP, Eidos, cognitive DAG, provenance, Halo/Shadow, RRF); every surface wired to a real proven
   front-end; substrate-health + IP-repair = CERTAIN, sequenced LOWER (not "deferred"/droppable); main-only;
   commits Co-Authored-By Claude.
7. **OFF-LIMITS:** NEW MODEL brain-1, the 70B, the Companion clones (companions.rs / Models·State Companion /
   CompanionCreationFlow). (Osaurus act ≠ Companion.)

## LOOP BEHAVIOR
Each iteration: re-read the addendum → pick the next open item (Osaurus/act-first, then work) → build to the
real-state done bar → commit as canon (honest msg) → update docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md (the
living map). Never stop; never fake-done; never delete the chat; never use "MAS-struct" to cut capability.
Work through ALL open owner/plan items until done. P0 owner reports preempt.
