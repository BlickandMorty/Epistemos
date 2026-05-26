# B-Prime Follow-up Repromotion Plan - 2026-05-26

Branch: `phase2-terminal-b-prime-chat-citations-2026-05-24`

PR: `#79`

This file is a durable pointer for unrelated follow-up work that was preserved during B-prime cleanup. Stashing is preservation only, not completion.

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

## Repromotion Rule

The preserved work must be applied in small PRs, not one giant stash apply. Start from the named follow-up branch, inspect each group independently, and split generated bundle output from source changes unless a bundle refresh is required by that group's source patch.
