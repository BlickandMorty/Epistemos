# SS-CLEAN — Anti-messiness / anti-muddiness self-correction discipline (2026-06-20)

Owner: *"I don't want this [wikilink work] to be messy and muddy. I want those two things [the in-use feature + the
overnight feature] implemented in different parts of the plan, and there are times where the agents will PAUSE and check
for messiness, check for muddiness, fix it, correct itself, and continue."* This is a **META directive** — it governs HOW
the build loop works (a recurring self-correction checkpoint), not just one feature. It also maps onto Karpathy's wiki
**lint** step (cross-ref SS-WL), so it doubles as a product feature.

## What "messy / muddy" means in Epistemos (the things to detect + self-correct)
1. **Dead-flag / orphan features** — code shipped behind a flag that's never turned on, or a view/function nothing mounts
   (the exact failure mode the last-auditor flags: "green but not user-facing"). Also half-wired features (a fix that
   compiles + has a test but doesn't reach the user — e.g. the SS-SH render-guard test without the production fix).
2. **Duplicate / divergent implementations** — two code paths doing the same job that drift (e.g. MiniChat vs main chat;
   two wikilink parsers; cloud vs local prompt assembly diverging — see SS-MV where local never got the vault). One source
   of truth per concern.
3. **Stale artifacts** — vault profiles never refreshed (SS-MV), docs/ledger out of sync with code, "(legacy)"/"Experimental"
   sections shipped to users (SS-BWB #1), TODO/FIXME left in user paths.
4. **Contradictions** — a doc/claim superseded by newer work but not retracted; a ledger line that contradicts current code.
5. **Layering mud** — a synchronous/offline concern leaking network or model calls onto a hot path; a background concern
   mutating UI state directly. (For SS-WL specifically: the in-use parser must stay pure/offline; only the overnight runner
   calls models — that separation is the anti-muddiness contract.)

## The "Cleanliness Gate" — a recurring checkpoint woven into the plan
A lightweight gate the loop runs on a CADENCE (e.g. every ~5 build iterations, and at the end of each multi-commit feature
cycle), NOT every iteration (don't stall forward progress). Steps: **pause → scan → fix/self-correct → re-verify → continue.**
Concrete scans (cheap, scriptable, mostly already in the auditor's toolkit):
- **Orphan/dead-flag scan:** grep for feature flags with no enable path; views/functions with zero references; new symbols
  not reachable from a mounted surface. Fix = wire it through or remove it.
- **Duplicate-impl scan:** flag two functions/files covering the same concern (e.g. `grep` for parallel prompt-assembly or
  link-parsing). Fix = converge on one seam.
- **Stale/consistency scan:** docs/ledger ↔ code drift; `last updated` artifacts past max-age; `(legacy)`/`TODO`/`FIXME`
  in user paths. Fix = refresh or gate.
- **Green-with-witness:** every "done" has a RENDER/behavior test + is user-facing end-to-end (no substring-only passes).
- **Build/test green + no regressions** against the suite before declaring the cycle clean.
- **(Wiki-feature instance, SS-WL):** Karpathy lint — stale claims, orphan pages, missing cross-refs, contradiction edges.

## Where it lives in the plan (owner: "different parts of the plan")
- **As loop discipline (NOW):** add a periodic self-clean checkpoint to the build-loop cadence (the monitor cron carries it):
  every ~5 iterations / end-of-cycle, the loop runs the Cleanliness Gate, self-corrects, then continues. The LAST-AUDITOR
  (me) independently verifies the same on each fire — flagging dead flags, orphans, duplicate impls, stale docs, and
  green-without-witness, exactly as today.
- **As a product feature (SS-WL cycle):** the overnight runner's lint pass keeps the wiki/Model-Vault un-muddy
  (orphan pages, stale profiles, contradiction edges, missing backlinks), surfaced honestly in the System tab.
- **Specifically for SS-WL:** the in-use feature and the overnight feature are implemented as SEPARATE modules sharing one
  parser-AST + backlink-index seam — never two divergent link engines. That is the concrete "don't let it get messy" rule.

## Non-negotiables
Self-correction NEVER deletes owner work or scope-boundary domains (dual-brain, Companion→Osaurus); it operates only on the
loop's own surfaces. Corrections are committed with a clear message + cite this slice. Honest: if a scan finds nothing,
say so; if it finds something it can't safely fix inline, log it as a ledger item rather than forcing a risky edit.
Cross-ref SS-WL, SS-MV, SS-BWB (the decomposition backlog is the structural side of the same anti-mud goal).

---

## OWNER-REQUEST COVERAGE SWEEP (owner 2026-06-20: "make a cycle in the plan so nothing I asked for is left out")
A SEPARATE recurring cycle from the muddiness gate — its job is **completeness of owner intent**, not code cleanliness.
The owner's concern: things get "missed or interrupted" mid-request (a long voice message, a compaction, a park). This
sweep guarantees every owner ask becomes a tracked, slice-backed, built deliverable.

### The cycle (run end-of-batch, and on every monitor fire as the last-auditor)
1. **Every owner directive → a ledger `[ ]` line, verbatim.** Each new owner message is captured verbatim (not paraphrased)
   the moment it arrives, BEFORE any work, so an interruption can't drop it.
2. **Every ledger `[ ]` → a research slice + a place in the build order.** Sweep: does each open item name an SS-*/EPDOC
   slice AND appear in the loop's NEXT-order (cron)? If an item has no slice → research it; if it has a slice but isn't in
   the order → insert it; if it's done → check it off honestly (only when user-facing end-to-end).
3. **Every slice → referenced by the ledger OR the finalization index (no orphans).** Sweep: `for each SS-*_<date>.md, is
   it referenced?` An unreferenced slice = a deliverable that could rot unbuilt. Add it to the index.
4. **Multi-part asks: each sub-bullet tracked.** Long owner messages often pack 3-6 asks; decompose into separate `[ ]`
   lines so a sub-ask isn't swallowed by the headline one (e.g. the theme-hang message also carried quick-capture + TTS +
   /loop-cadence + pill — each its own line).
5. **Report gaps, don't paper over.** If the sweep finds an uncaptured/un-sliced/un-ordered ask, surface it as a fresh
   ledger item + (if needed) a slice; never silently assume it's covered.
- Scriptable sweep helpers: `grep -c '^- \[ \]' <ledger>` (open count); per-item slice-ref check; orphan scan
  (`for s in SS-*_<date>.md; grep -l "$s" <ledger> <index>`). Run cheaply each batch; deeper pass at end-of-cycle.

### First sweep result (2026-06-20)
167 open ledger items. Slice-coverage of the recent owner asks: OK (each names its slice). Orphan scan flagged 5 slices
not referenced in ledger/index: **SS-AL** (agent-loop robustness — DONE), **SS-Y** (masked-logit — DONE), **SS-FM**
(frontmatter/tags — folded into EPDOC_MD_V2), **SS-UMA** (instant-recall zero-copy — folded into SS-IR), **SS-SH**
(substrate-health — its own active item, blank-sidebar still open). Action: recorded them in the finalization index's active
set so none rots. No owner ask found dropped — the catch was index-completeness, exactly what the sweep is for.
