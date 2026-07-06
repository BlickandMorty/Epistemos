---
name: experimental-realistic-input-verification
description: >
  Verify substrate-matching code (retrieval, citation-checking, title/link resolution, parsing over
  the user's REAL data) with the INPUT SHAPES that actually occur — natural-language prompts, ordinal
  `04_` / slug / dated filenames, H1 titles that differ from the filename, wikilink display-text and
  anchors, unicode — NOT tidy keyword fixtures. Keyword fixtures give false green: they pass while the
  real path silently returns nothing. This methodology found FOUR silent correctness bugs in four
  cycles that every headless keyword test missed. Use it in TEMPER whenever code matches user text
  against a store. Class: enumerate real-world input shapes → test each against the real endpoint →
  fix → add BOTH the positive and the guard case to the witness.
---

# Experimental: realistic-input verification (test the shapes that actually occur)

## Why (the lesson, paid for in bugs)
A live Prompt Forge run came back UN-cited. Chasing that one real observation — instead of trusting the
green headless suite — unrolled four silent bugs, each invisible to keyword fixtures:
1. **NL grounding**: whole-vault search matched the FULL query as a substring, so a natural-language
   prompt ("help me make the X pitch compelling") retrieved ZERO notes. (Fixed: term-overlap search.)
2. **Ordinal filenames**: cite-check matched the filename, so `04_CLAIM_LEDGER.md` rejected `[[Claim
   Ledger]]`. (Fixed: strip a leading ordering prefix.)
3. **H1 ≠ filename**: a slug/dated file with an H1 title rejected a citation by that title. (Fixed:
   cached title index keyed by filename + prefix-stripped + H1.)
4. **Grounding + graph titles**: grounding cited the ugly filename, and H1-style `[[links]]` didn't
   resolve to slug files. (Fixed: `displayTitle` H1-preference + title-index link resolution.)
The through-line: fixtures used `Alpha Project.md` (filename == H1, single-keyword queries), which every
matcher passes. Real vaults use `04_CLAIM_LEDGER.md` with H1 "# Claim Ledger" and people type sentences.

## The checklist (before declaring a matcher "verified")
- **Queries:** a full natural-language sentence, not one keyword. (Substring vs term matching.)
- **Filenames:** `NN_UPPER_SNAKE.md`, `dated-2024-slug.md`, `kebab-case.md` — not just `Title Case.md`.
- **Titles:** an H1 that DIFFERS from the filename. Cite/resolve by BOTH.
- **Links:** `[[Title|display]]`, `[[Title#anchor]]`, H1-style vs filename-style wikilinks.
- **Guards:** a partial/superset must STILL be rejected (no substring false-verify); unicode/empty/degenerate must not crash.

## Verification (DoD)
Boot the real backend against a fixture that mirrors a REAL vault layout (ordinal/slug names, H1≠filename)
and POST the actual endpoint. For every fix add TWO witness assertions: the positive (it now matches) AND
the guard (the thing that must still be rejected) — the guard is what keeps a lenient fix honest. Every
fork edit → a `PATCH_LEDGER.md` row.

## Reuse targets
Any new substrate-matching code (a new retrieval mode, a new cite/verify axis, a parser over notes) —
run this checklist in TEMPER before shipping. Live verification with a real input is the tip that starts it.
