# Agent 3 — No-Bullshit Complete Audit (2026-06-29)

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** Audit findings on real code state are durable; the surface framing is re-scoped: Current surfaces = Experimental/1Code + MAS/June; OpenChamber/ProAgent are deletion targets; goose = one engine (not "Goose-only / the one surface / Option 1"). Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

This is the durable handoff for the Plan 3/capabilities agent and for any future session that receives the older
pasted Plan 3 loop prompt. It records what was actually verified in the repo, what docs/plans were changed, and what
must not be overclaimed.

## Audit Base
- Current audit base before this file: `585713236 Audit upgraded plan prompts`.
- Relevant preceding commits:
  - `5277144ef prompts: add 'THIS PLAN WAS UPGRADED' notice to all 3 + bring Plan 3 in line`
  - `13958ca9e research(goose-reskin): R9 — spec the A/B pixel-diff harness; ALL gaps closed`
  - `f623b4d3d research(nativeness): R10 — extend recipe to editor web bodies + the token-source unification`
  - `7f4afab43 research(goose-reskin): R11 — global macOS details (native scrollbars + accent focus ring)`
  - `585713236 Audit upgraded plan prompts`
- Verification commands used for this audit:
  - `git log --oneline -8`
  - `git show --stat --oneline 5277144ef 13958ca9e f623b4d3d 7f4afab43 585713236 --`
  - `rg` over `docs/prompts` and `docs/research` for upgrade notices, Plan 3 codepack names, pixel-diff, token sources,
    scrollbars, focus ring, and stale terms.

## Critical Truth
The pasted old Plan 3 prompt is stale. The current authority is the repo's current docs:
- `docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md`
- `docs/research/PLAN_3_CAPABILITIES_2026_06_28.md`
- `docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md`
- `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`
- `docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`

The most important correction is this: Plan 3 is now mostly shipped/staged, so "build order" usually means
verify/harden existing work, not rewrite codepacks or rebuild already-shipped slices.

## What The Other Agent Claimed, Checked Against Current Repo

### Claim: all three prompts now have upgrade notices
Verified. Current prompts contain `★ THIS PLAN WAS UPGRADED (2026-06-29)`:
- `PROMPT_PLAN_1_GOOSE.md`
- `PROMPT_PLAN_2_EDITOR.md`
- `PROMPT_PLAN_3_CAPABILITIES.md`

### Claim: Plan 3 got missing WORK MODE + arXiv PRIORITY-0
Verified. `PROMPT_PLAN_3_CAPABILITIES.md` now has:
- `WORK MODE — DEEP CODE, NOT TEST VOLUME`
- `PRIORITY-0 (verify/fix first): the arXiv "PDF not supported" bug`

No-bullshit note: this proves the prompt was fixed, not that the arXiv runtime path has been live-witnessed in the app.
The prompt still correctly says to verify/fix first.

### Claim: Plan 3 codepacks are complete enough to stop writing owed codepacks
Partly true, and now corrected in the docs. The earlier prompt still said "write the next OWED codepack
(browser-use vendor / Voice / meeting-STT / whole-app-logos)." That was stale because these files exist:
- `PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md`
- `PLAN_3_VOICE_CODEPACK_2026_06_28.md`
- `PLAN_3_MEETING_STT_CODEPACK_2026_06_28.md`
- `PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md`

Current `PROMPT_PLAN_3_CAPABILITIES.md` now says: if a codepack is missing, write it first; otherwise harden the next
shipped/staged follow-up.

### Claim: reskin research gaps are closed
Verified as a research claim, not as an implementation claim. `GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md` says all research
gaps are closed and identifies remaining work as implementation:
- R9: A/B pixel-diff harness spec
- R10: editor web-body token unification
- R11: native overlay scrollbars + accent focus ring

No-bullshit note: the A/B harness is specced, not built. The Goose retheme is not proven implemented merely because the
research doc is complete.

## Changes Made To Prompts And Plans

### `docs/prompts/PROMPT_PLAN_1_GOOSE.md`
Changed to prevent future agents from resurrecting Phase 0:
- Added `STALE-SEQUENCING GUARD`.
- Added `PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md` to READ FIRST.
- Reworded the Plan 2 shared seam as Goose note-context plumbing, not a native minichat.

Current meaning:
- Plan 1 is past §7 and on Phase 1.
- Option 1 is locked: native frame only; chat and non-Models Goose routes stay WebView/reskinned.
- Step 1/3 proof language is ongoing verification, not a sign-off pause.

### `docs/prompts/PROMPT_PLAN_2_EDITOR.md`
Changed to prevent Plan 2 from building the wrong chat surface:
- Added `STALE-CANON AUDIT`.
- Added `PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md` to READ FIRST.
- Reworded old minichat language to "Goose note-context seam."
- Kept old code editor as v1 legacy.
- Kept MarkEdit Source route language as verify/current-code-first, not fixed stale line-number authority.

Current meaning:
- Plan 2 builds editor surfaces plus note-context plumbing only.
- Live chat/agent UI is Plan 1's Goose WebView/reskin.
- No separate native chat UI.

### `docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md`
Changed to align with current Plan 3 reality:
- Added stale-canon audit pointer.
- Added missing codepacks to READ FIRST:
  - `PLAN_3_BROWSER_USE_CODEPACK`
  - `PLAN_3_VOICE_CODEPACK`
  - `PLAN_3_MEETING_STT_CODEPACK`
  - `PLAN_3_WHOLE_APP_LOGOS_CODEPACK`
- Changed `BUILD ORDER` to `BUILD/HARDENING ORDER`.
- Replaced "Needs a vendor codepack" with "vendor codepack already exists."
- Clarified browser-use remaining work is signed Pro packaging/UI/MCP hardening.
- Clarified Plan 3 owns PDF parse + `source_pdf` handoff, while Plan 2 owns the PDFKit viewer.

Current meaning:
- Do not rewrite existing codepacks.
- Do not build Obscura native automation, ColBERT, local model-management, three-engine/Osaurus, or DeerFlow.
- Continue Plan 3 hardening around shipped/staged slices.

## Changes Made To Research/Canon Docs

### `docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md`
New file. It is the contradiction guard. It records:
- Plan 1 §7 is green-lit, no native chat.
- Plan 2 note-context only, no native minichat.
- Plan 2 MarkEdit settings must become reachable before final acceptance.
- Plan 2 keeps v1 code editor as legacy.
- Plan 3 mostly shipped/staged.
- Quick grep checklist for stale terms.

### `docs/research/PLAN_3_CAPABILITIES_2026_06_28.md`
Changed the top codepack status list to include the missing shipped/staged codepacks:
- `PLAN_3_LANDING_BUTTONS_CODEPACK`
- `PLAN_3_ARXIV_CODEPACK`
- `PLAN_3_BROWSER_USE_CODEPACK`
- `PLAN_3_VOICE_CODEPACK`
- `PLAN_3_WHOLE_APP_LOGOS_CODEPACK`
- `PLAN_3_MEETING_STT_CODEPACK`

Also clarified Plan 3 PDF ownership:
- Plan 3 owns parse engine + `source_pdf` storage/handoff/affordance.
- Plan 2 owns the PDFKit PDF viewer.

### `docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md`
Changed to remove stale Plan 2 traps:
- Added 2026-06-29 upgrade patch notice.
- Replaced native minichat recommendation with Goose note-context plumbing only.
- Replaced Phase-0/§7 sign-off gating with Plan 1 coordination.
- Replaced stale fixed `CodeEditorView.swift:706` claims with verify-current-code-first routing guidance.
- Changed "embedded-but-inert settings" framing: MarkEdit settings must be user-reachable before final acceptance.
- Changed old-code-editor cleanup: old editor stays as v1 legacy fallback.

### `docs/research/GOOSE_MINICHAT_CODEPACK_2026_06_27.md`
Retitled and tombstoned in scope:
- Now `Goose Note-Context Plumbing`.
- Older native chat/minichat UI recommendation is historical.
- Plan 2 may build active-note tracking, bounded context snapshots, `_meta`, MCP descriptors, wikilink/selection context,
  and editor affordance routes.
- Plan 1 owns live chat/agent UI.

### `docs/research/AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK_2026_06_27.md`
Changed old minichat sender reference:
- Now refers to any note-aware Goose sender owned by Plan 1 plus Plan 2-provided context plumbing.

### `docs/research/MARKEDIT_EMBED_CODEPACK_2026_06_27.md`
Changed stale Plan 2 editor assumptions:
- v1 WebKit code editor is retained as legacy, not removed.
- Dormant code-editor scaffolds are keep/flag unless owner separately approves cleanup.
- MarkEdit Settings must be vendored and user-reachable before final acceptance.
- Markdown Source route must be verified against current code before editing; do not trust stale line numbers.

### `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`
Changed/verified:
- Two token sources must hold identical values:
  - `Epistemos/Theme/EpistemosTheme.swift`
  - Goose `ui/desktop/src/theme/theme-tokens.ts`
- Plan 3 does not implement a second PDF viewer; it hands a resolved `source_pdf` URL to Plan 2's PDFKit viewer.

### `docs/research/TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md`
Changed stale historical pass notes:
- Added 2026-06-29 supersession banner.
- Replaced native minichat / Phase-0 gate with Plan 2 context plumbing only.
- Replaced old-editor deletion with v1 legacy retention.
- Replaced inert MarkEdit settings with settings must be reachable.
- Replaced stale `update_note` wording with current `edit_note`.

### `docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`
Verified existing research commits:
- R9 added A/B pixel-diff harness spec:
  - Native capture via SwiftUI `ImageRenderer` / AppKit bitmap APIs.
  - Web capture via `WKWebView.takeSnapshot`.
  - Diff via `pixelmatch` by default, possible `odiff`.
  - Gate about 2 percent mismatch across light/dark/states.
- R10 added editor web-body retheme entry points:
  - `EpistemosTheme.swift`
  - `EpdocEditorThemeStyle`
  - `MarkEditCoreEditorView` theme param
  - `HTMLWorkspacePreviewView.themeGuardCSSOverride`
  - invariant: `EpistemosTheme` and Goose `theme-tokens.ts` must hold identical Apple values.
- R11 added global macOS details:
  - Neutralize Goose custom scrollbar CSS so native macOS overlay scrollbars return.
  - Use accent-colored focus ring, not 1px neutral outline.

No-bullshit note: R9/R10/R11 are research/spec/canon updates. They do not prove the actual UI retheme has been
implemented or pixel-diff verified.

## Current Open Implementation Truth

Do not tell the owner "done" for implementation based on these docs alone.

Still implementation work or verification work:
- Plan 1 still must apply the Goose retheme to `theme-tokens.ts`, `main.css`, and component CSS, then build and run the
  A/B pixel-diff harness.
- The A/B pixel-diff harness is specified but not proven as a built dev-only tool.
- Native overlay scrollbar/focus-ring fixes are specified; code implementation must still be verified in Goose/editor web CSS.
- Plan 2 still must feed Apple token values through `EpistemosTheme` and editor web-body injectors and prove visual parity.
- Plan 3 browser-use Pro lane still needs signed Pro packaging/UI/MCP hardening per the current Plan 3 prompt.
- The arXiv `.pdf` temp-file P0 must be verified live end-to-end unless current code/test evidence proves it.
- Existing dirty worktree contains unrelated app/source/test changes; do not accidentally stage or revert them.

## Current Dirty Worktree Warning
At audit time, the repo had many unstaged changes outside this file, including app Swift files, Rust `agent_core` files,
tests, generated editor resources, Xcode project files, and an in-progress browser-use hardening diff. This audit file
must be committed separately from those changes. Do not use a broad `git add .`.

Known unstaged Plan 3 browser-use hardening files at audit time:
- `agent_core/src/tools/browser_input.rs`
- `EpistemosTests/BrowserUseAdapterPlan3Tests.swift`
- `EpistemosTests/BrowserUseCodepackPlan3Tests.swift`
- `docs/research/PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md`

## Future Agent Rules
1. Read this file before following the pasted old Plan 3 loop prompt.
2. Treat `PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md` as the contradiction guard.
3. If a doc says "owed browser-use/Voice/meeting-STT/logo codepack," it is stale unless it explicitly means a new gap.
4. If a doc says Plan 2 should build native minichat or wait for Phase 0/§7 sign-off, it is stale.
5. If a doc says delete the old code editor, it is stale.
6. If a doc says MarkEdit settings may remain inert for final acceptance, it is stale.
7. If a doc says Plan 3 owns the PDF viewer, it is stale; Plan 3 owns parse + handoff, Plan 2 owns PDFKit viewer.
8. "Research complete" means research/spec complete, not implementation complete.
9. Commit at clean points and stage explicit paths only.
