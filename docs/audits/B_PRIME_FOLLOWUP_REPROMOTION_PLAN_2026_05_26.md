# B-Prime Follow-up Repromotion Plan - 2026-05-26

Branch: `phase2-terminal-b-prime-chat-citations-2026-05-24`

PR: `#79`

This file is a durable pointer for unrelated follow-up work that was preserved during B-prime cleanup. Stashing is preservation only, not completion.

2026-05-26 update: the preserved B-prime follow-up is closed for current product
recovery in `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md`. Keep this
file as the historical repromotion plan, but do not dispatch new work from this
list unless a later diff against current `main` finds a genuinely novel hunk.

## Recovery Pointers

- Stash name: `b-prime-uncommitted-followup-2026-05-26`
- Recovery tag: `recovery/stash-b-prime-uncommitted-followup-2026-05-26`
- Patch: `/tmp/b-prime-uncommitted-final.patch`
- Next branch name: `phase2-followup-html-workspace-audio-settings-2026-05-26`

## Scope Groups

- HTML Workspace
- Audio/settings
- Local-agent repair
- Eidos/search follow-up
- Generated bundle review

Current disposition:

- HTML Workspace: recovered/superseded by the HTML Workspace source guard and
  legacy diagram compatibility slices.
- Audio/settings: superseded by current ambient playback state and settings.
- Local-agent repair: no remaining filtered delta against current `main`.
- Eidos/search follow-up: live via production VaultRecall traces and
  SearchIndexService-to-Eidos mirroring.
- Generated bundle review: recovered where needed for the legacy diagram bundle;
  remaining generated files are stale preservation noise.

## Repromotion Rule

The preserved work must be applied in small PRs, not one giant stash apply. Start from the named follow-up branch, inspect each group independently, and split generated bundle output from source changes unless a bundle refresh is required by that group's source patch.
