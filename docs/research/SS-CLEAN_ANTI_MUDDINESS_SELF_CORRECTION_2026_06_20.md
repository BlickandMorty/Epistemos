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
