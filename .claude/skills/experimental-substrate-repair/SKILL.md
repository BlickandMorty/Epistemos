---
name: experimental-substrate-repair
description: >
  Turn a verification MISS into a REPAIR: when a claim/citation/link fails to resolve against the
  substrate, find the nearest VALID substrate entity and suggest the correction — but only at high
  confidence, withholding when nothing genuinely matches (a wrong suggestion is worse than none).
  The step past detection: verify tells you [[X]] is wrong; this tells you "did you mean [[Y]]?".
  Composes experimental-substrate-verification (the miss) + experimental-vault-context-assembly
  (the nearest-entity lookup). Use for cite-check repair, broken-wikilink fixup, misremembered-fact
  correction, wrong-tool suggestion — any detect-then-suggest-correction loop over the substrate.
---

# Experimental: substrate repair (detect → suggest the fix)

## Why
Detection alone ("that citation doesn't exist") leaves the user to hunt for what the agent meant.
Because Epistemos holds the real substrate (the vault's actual note titles / graph entities), it can
close the loop: find the nearest real thing and offer it. No standalone agent can — it has no
authoritative index of the user's knowledge to repair against.

## The pattern
1. **Only repair a confirmed miss.** Run the verification first (exact match). Repair is for the
   items that FAILED — never "correct" something already valid.
2. **Rank candidates by a cheap, explainable similarity** over the substrate's own index — e.g.
   title-TOKEN overlap (shared words ≥4 chars), not fuzzy edit-distance guesswork. Server-side, where
   the entity list already lives (don't ship the whole index to the client). Bounded to the cached list.
3. **HIGH-CONFIDENCE OR NOTHING.** Return a suggestion only when a real signal exists (≥1 shared
   significant token). If nothing overlaps, return null — showing a bad "did you mean" is worse than
   silence, and erodes the trust the verification just earned. This is the crux; get it wrong and the
   feature becomes noise.
4. **Present as a tentative suggestion, not a claim** ("did you mean [[Y]]?") — the user decides. Never
   auto-rewrite.

## Verification (DoD)
Pure + deterministic → verify HEADLESS with a fixture: a hallucinated title that shares a token with a
real note returns that note; an unrelated title returns null. (Proven: "Project Roadmap 2027"→[[Roadmap]],
"Auth Design Spec"→[[Authentication Design]], "Quantum Teleportation"→null.) Add both the positive AND the
withhold case to the witness — the withhold is the one that keeps it honest. Every fork edit → a
`PATCH_LEDGER.md` row.

## Reuse targets
- Broken `[[wikilink]]` in a note the user is editing → suggest the real neighbor.
- Agent names a tool/command that doesn't exist → nearest real tool by token overlap.
- Extend the ranking key (add graph-distance or recency) — but keep the withhold gate absolute.
