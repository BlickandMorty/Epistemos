# Stash 6 Non-Chat Donor Closeout - 2026-05-26

Status: remaining non-chat donor material recovered or explicitly superseded.

Source: `stash@{6}` (`preserve-wip-before-merge-wave-2026-05-24`).

Recovery rule: No stash was popped, dropped, checked out, or bulk-applied.

## What Was Already Closed

The chat, VaultRecall, and Eidos product slice of `stash@{6}` is closed by
`docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md`.

## What This Slice Recovered

The durable non-chat material was documentation/canon alignment:

- `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` now names the 13-terminal deck
  correctly, restores the Addressable Neural Substrate mandatory read, and adds
  the Neural Substrate check for local inference/model-routing PRs.
- `docs/LEGENDARY_CODEWORD_2026_05_23.md` now points builders at the Living
  Index before dispatching/merging terminals and preserves the Neural Substrate
  check requirement.
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` now indexes the
  Shadow Projection / Research Construction addendum and the Addressable Neural
  Substrate canon-target.

## What Was Superseded

`artifacts/lattice-coordinate-explainer/index.html` from `stash@{6}` was not restored.
Current `main` already has a newer and larger explainer with the
`§3K Addressable Neural Substrate` section, `NeuralSubstrateAddressSet`, and
the no-compromise local-model framing. Replacing it with the stash version
would be a downgrade.

## Remaining Queue Impact

The active value of `stash@{6}` is now closed for current product recovery.
Keep the stash only as a preservation reference until the user approves
retiring old recovery refs.
