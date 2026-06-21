# Directive-Compliance CHECK PROMPT (2026-06-21)

Paste the block below to a checker (or the build agent itself) to verify it has the updated directives,
produce an implementation map, and go back + fix anything diverged.

---

You are auditing the Epistemos build (cwd /Users/jojo/Downloads/Epistemos) for compliance with the
2026-06-21 owner directives. GROUND EVERYTHING IN FILES — read before you claim; cite file:line; no
"done" without a real-state test. Do NOT trust prior session memory; the docs on disk are authority.

## STEP 1 — Load the directives (read fully)
- docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md  (THE master directive doc — read all of it)
- docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md (+ its 2026-06-21 append)
- docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md
- docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md
- docs/research/OPENCODE_FULL_CLONE_FEASIBILITY_2026_06_21.md
- docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md
- docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md
- memory: project_osaurus_full_clone_directive_2026_06_21

## STEP 2 — For EACH directive below, check the CURRENT implementation (grounded, cite files)
Mark each: ✅ done+verified (real-state test) / 🟡 in-progress / 🔴 not-started / ⚠️ DIVERGED-from-directive.
1. **Two modes:** ACT = Osaurus (full clone, in-process); WORK = OpenCode shell fusing Goose + Hermes +
   OpenClaw, with RustLSP wired in. One brain (owner IP) on top, per-mode engines beneath; engine choice
   at one site (ChatCoordinator), not RuntimeRouter.
2. **Osaurus landed + linked:** vendored at LocalPackages/osaurus; dual-MLX consolidated onto vmlx-swift
   (mlx-swift-lm dropped); OsaurusCore linked; act turn via generation-closure swap.
3. **OpenCode WORK UI:** keep OpenCode's REAL terminal UI, palette-matched LIVE incl. custom themes,
   renamed "work" (never shows "OpenCode"); present in main chat + minichat + graph chat, NOT note chat;
   search+type → transitions to work; TWO landing pages (Osaurus/act reskinned + OpenCode/work) with BLUR
   transitions (press-anywhere→act landing→toggle→work landing); act/work toggles.
4. **ACT reskin = current chat UI discipline:** warm cream palette; user message bubble = MONOSPACE in
   coral/salmon bubble; assistant text = Anthropic Sans; flat-but-distinct composer; monospace pixel-art
   section headers; right-side provenance inspector; vault chips; rounded window + soft shadow; palette-aware
   text; live themes drive Osaurus too.
5. **Preserve UI chrome:** model picker (real logos, Fast/Think tiers, install states, memory needs, 128K/32K
   badges, checkmark, "Install local AI") — with the owner's hardened models as the "Epistemos Picks" section;
   command palette (Fast/Tools/Agent tabs + bottom command grid); 38-tool agent panel (toggles, "asks first").
6. **Tamagotchi agents:** Osaurus agent-creation keeps Tamagotchi-style avatars; FIX render bug (too small +
   artifact squares inside bodies → larger, dynamic, flat, no inner squares).
7. **Chat backend:** QUARANTINED, NEVER deleted; porting cycles move its logic/IP into beneficial surfaces
   before retire; retire only after 4-part bar + owner OK.
8. **No silent Qwen fallback:** too-large = honest message / owner's pick; never a silent substitute (the
   live "running Qwen 3 4B instead" behavior must be gone from the act path).
9. **MAS non-restrictive + Swift/Rust leniency = GLOBAL** (all repos incl. Talaria + Epdoc fuse); notarized
   direct-distribution; supersedes CLAUDE.md MAS section; honesty still holds (real APIs, no hidden fallbacks).
10. **Reuse-not-rebuild owner IP:** RustLSP (agent_core::lsp_runtime) wired into work as tools; Eidos/recall,
    cognitive DAG, provenance, Halo/Shadow, RRF wired into both modes — not re-cloned.
11. **Every surface wired to a real proven front-end** (no dead surfaces); completeness/discovery sweep run
    (grep all consumers of chat/inference/picker/tools); all chats get act (+work where applicable).
12. **EPDOC MD-V2:** md = source of truth, html/json = projections; pixel-art native, more dynamic.
13. **Substrate-health + IP-repair = CERTAIN, sequenced LOWER (not labeled "deferred"/droppable);** code as
    much as possible first.
14. **Hygiene:** no WIP/stash hiding places (24 old stashes triaged); no pre-2026-06-19 old-doc drift; real-
    state tests; commits Co-Authored-By Claude; main-only; never vault writes.

## STEP 3 — Produce the IMPLEMENTATION MAP
A table: Directive # | status | file:line evidence | gap/divergence | action. Then a short prose summary of
what's on-track vs what diverged or is missing.

## STEP 4 — GO BACK AND FIX
For every ⚠️ DIVERGED or 🔴 mismatch that contradicts a directive, FIX IT now (edit code/plan) to match the
directive — Osaurus-first ordering. Commit each fix as canon (honest message, real-state test). If a fix is
risky or large, write it as an explicit ledger item (NOT a stash, NOT "deferred"). Never delete the chat.

## STEP 5 — Report
Return: the implementation map, what you fixed (commits), what remains (as ordered ledger items), and any
directive that is ambiguous / needs an owner decision. Update docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md with
the current map so it stays the living source of truth for "Osaurus and beyond."

15. **ACT/WORK UI + ANIMATIONS** (per addendum): act reskin matches current-chat discipline (cream palette, monospace user bubble, Anthropic-Sans answers, flat-distinct composer, section headers, provenance inspector, vault chips); model picker + command palette + 38-tool agent panel PRESERVED; Tamagotchi agent-creation style kept + render bug fixed; per-clone settings as executive tabs (Epistemos|act|work|beyond); landing BLUR transitions; mode-entry animations (act=native blur-reveal greeting->title typewriter; work=ASCII/pixel typewriter + dynamic full-page reveal, OpenCode font); live theme incl custom drives both.
