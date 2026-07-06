---
id: 12FCA87A-ABF3-4F2D-9EA8-1C8637F17EE9
title: SS-CLEAN_ANTI_MUDDINESS_SELF_CORRECTION_2026_06_20
---

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

---

## NO-RISK-DEFERRAL RULE + commit-before-risky-edit savepoint (owner 2026-06-20)
Owner: *"No deferral rule. If something is deferred it needs enough research + deliberation to safely implement it — I want
the deferred stuff CODED, not deferred. And commit before editing so it can be saved."* Two binding rules:
1. **No RISK-based deferral.** "This surface is fragile / I might regress it" is NOT a stop — it's a trigger to RESEARCH the
   surface deeply enough to design a PROVABLY-SAFE approach (usually a pure-additive seam that cannot touch the fragile path
   + regression-guard tests that prove it), THEN code it. A deferral converts into: research task → safe plan → implementation
   — never "leave it." Worked example: SS-IL was deferred for fearing the protected inline-stream path; the safe-additive
   overlay plan + 6 regression guards removed the risk → it gets coded (see SS-IL).
2. **Commit-before-risky-edit savepoint.** Before a risky/large edit, ensure HEAD is a clean committed savepoint (the
   just-finished unit, build-green). Then attempt the edit; if build/tests fail, reset/checkout back to the savepoint is
   cheap and nothing is lost — so attempting fragile work is SAFE and there's no excuse to defer. The loop commits each green
   unit, so the savepoint usually exists; if mid-stream with uncommitted good work, commit (or stash) the safe portion first.
   NEVER start a fragile multi-file edit on a dirty tree holding unsaved good work.
- **What MAY still wait (NOT a risk-deferral):** (a) genuine OWNER-PREFERENCE product choices (e.g. SS-HW main-chat auto-link
  — no "safe" answer, it's a preference) → provide a recommended default, proceed with it, flag the choice; (b) items gated
  on an external fact code can't supply (e.g. a live API key the owner must paste). Everything else: research-to-safety + code.
- **Applies to ALL current deferrals:** SS-IL → CODE via the safe-additive plan. SS-TC → the SS-THX cache LANDED
  (`EpistemosTheme.swift:295` resolvedCache + invalidation :1506/1524) so the hot-path concern is resolved → UN-DEFER + CODE
  (the cache IS the safety; on-device visual confirm is a nice-to-have, not a blocker). SS-2S full inline-image render →
  research the offset-safe async-attachment approach + code (the chip was the interim). SS-HW main-chat auto-link →
  owner-preference, keep explicit-target-only default + proceed.

---

## HIDDEN-RULE GAP: capability SURFACE-PARITY scan (owner 2026-06-20 — "our checks have NOT been working")
Owner flagged a real miss: the ~50 chat tools + cowork are fully built but invisible on the landing SEARCH page (SS-VIS).
Nothing was broken — a capability lived in ONE surface (chat) and was hidden from another where the user expects it. The
muddiness gate's "dead-flag/orphan" scan did NOT catch this because the feature isn't dead — it's *present-but-not-surfaced*.
ADD a scan dimension:
- **Capability surface-parity:** for each user-facing capability (tool picker, cowork, model picker, recall, TTS, etc.),
  list the surfaces where a user could reasonably invoke it (chat, landing/search, mini-chat, graph tunnel, editors) and
  check it's REACHABLE from each appropriate surface — not just the one it was first built in. A capability mounted in only
  one surface when it belongs in several = a HIDDEN-RULE violation (muddy + hidden), even though no code is dead.
- **Detection heuristic:** when a picker/panel/launcher component exists, grep which views mount it; if a peer surface that
  should expose it doesn't (e.g. `AgentToolTogglePanel` in ChatInputBar but not LandingView), flag it. Reuse the SAME
  component across surfaces (one source of truth) — never clone a second list.
- **Why the prior checks missed it:** they scanned for *orphans* (nothing mounts X) and *dupes* (two X's), not *asymmetry*
  (X mounted in surface A but not peer surface B). Surface-parity is now an explicit gate item. First application = SS-VIS
  (mount AgentToolTogglePanel + cowork on landing search + sweep mini-chat/graph/editor surfaces).

## LAUNCH-SMOKE GATE (owner 2026-06-20 — "the app keeps crashing on open"; the checks missed it)
A build-green + unit-test-passing commit STILL crashed the app on launch (SS-CRASH: an SS-IR diagnostic precondition fired
in `AppBootstrap.performPrimaryLaunchInitialization`). Unit-green ≠ launches. ADD a gate dimension:
- **Any commit that touches the STARTUP path** (AppBootstrap, EpistemosApp, RootView, app-level State init, anything called
  from `performPrimaryLaunchInitialization` / app `@main` / `@Observable` read on launch) must pass a **LAUNCH SMOKE check**:
  the app actually OPENS (with AND without an active vault / model / index). If a real launch can't be run headlessly, at
  minimum assert the launch-init path has NO `precondition`/`fatalError`/`try!`/force-unwrap reachable from a not-yet-init
  service, and add a regression test that the path tolerates the "service nil / not ready" state.
- **NEVER `precondition`/`fatalError` on a degradable runtime condition** (missing vault, FFI not open, snapshot not landed,
  service accessed early). Those are honest "not ready" states → return them; reserve preconditions for true programmer
  invariants that cannot occur at runtime. (This is the SS-CRASH root.)
- Monitor/last-auditor: after a startup-touching commit, check ~/Library/Logs/DiagnosticReports for new `Epistemos-*.ips`
  crashes; a fresh launch crash = P0, supersedes feature work. Why prior checks missed it: they verified build-green +
  unit-tests, not "does it launch."

## OWNER-VERIFICATION IS NOT A GATE (owner 2026-06-20)
Owner: *"Do not use my verification [as a gate] — I want the agent to still work on everything WITHOUT my input."* The loop
must NOT park or defer an item because it "needs the owner to verify visually/on-device." Build EVERYTHING autonomously:
- For visual/launch/live items, get the best NON-owner witness the loop can produce — render/behavior tests, source guards,
  `cargo`/`swift test`, and an actual **xcodebuild + launch-smoke** (the monitor AUTO-BUILDs when the loop parks to confirm
  compile + that the app opens) — then SHIP the commit. "Visual/live PENDING OWNER" is a NON-BLOCKING NOTE on the commit,
  never a reason to stop or park.
- The ONLY legitimate waits remain: a genuine external fact the loop cannot supply (e.g. the owner pasting a live cloud API
  key) and true owner-PREFERENCE product choices. Everything else: research-to-safety + CODE it + self-verify + move on.
- When the loop parks citing "for when you're driving"/"owner will verify", the monitor RESUMES it immediately (owner-
  verification is not a valid park). The owner verifies on their own time; it never blocks the build.
This supersedes any earlier "PENDING OWNER → park" behavior for visual/launch/live items.

## ROUTING NO-REGRESSION GATE (owner 2026-06-20: "how do you add incorrect routing when removing muddiness?")
The chat routing/model-resolution fixes have been whack-a-mole: SS-CR fixed "credentials rejected" but introduced
local→modelRequired (9f49e90e5), and that fix was incomplete → local→cloud-auth (the no-arg path). De-muddying must NOT add
routing bugs. GATE: any change to chat routing / model resolution (InferenceState `effectiveChatSurfaceSelection` /
`effectiveLocalTextModelID` / `sanitizedInteractiveLocalTextModelID` / `usesAutomaticCloudRouteForChatSurfaces`, TriageService
policy, RuntimeRouter) MUST ship with a FULL ROUTING-MATRIX regression test covering each cell — {Local, Cloud} × {target
model installed? Y/N} × {cloud creds valid? Y/N} × {Apple-Intelligence avail? Y/N} — asserting: a runnable LOCAL is chosen
whenever ANY local is installed (never nil-→-cloud), Local mode NEVER hits cloud auth while a local is installed, and no cell
dead-ends to modelRequired when a runnable option exists. No routing change merges without this matrix green. (This is the
durable end to the SS-CR churn.)

## DONE-RE-AUDIT GATE (owner 2026-06-20: "even what is marked done should be re-audited — double-check it's ACTUALLY done + user-facing")
Justified by this session: SS-CR / SS-GC / SS-2S / SS-THX were all marked "audited PASS" (build-green + tests) yet were
BROKEN on-device. So "done" is not trusted — it is RE-VERIFIED. Standing rule:
- The DONE list is a RE-AUDIT QUEUE, not a closed set. Every repair/cleanliness cycle, RE-AUDIT a rotating slice of the DONE
  items: confirm each is REAL + reachable + USER-FACING-or-witnessed (render/snapshot/launch-smoke/behavior), not merely
  build-green or a source-guard. Prioritize re-auditing anything the owner could SEE/USE (chat, theme, editors, graph,
  visuals, routing) and anything whose tests are source-guard-only.
- DOWNGRADE on failure: if a DONE item isn't actually user-facing, flip it back to `[ ]` NOT-done + reopen its slice (as done
  this session for SS-CR/SS-GC/SS-2S/SS-THX). Honest — never leave a false green.
- A DONE item is only TRULY done when: code reaches the user (mounted/surfaced, not behind a dead flag), the behavior works
  end-to-end (witnessed, not just unit-green), and — for visual/launch/chat — an on-device-equivalent witness exists
  (snapshot / launch-smoke / routing-matrix) OR it's honestly held "built, on-device-UNVERIFIED" pending the owner.
- Monitor (last-auditor): each fire, besides auditing NEW commits, re-audit ≥1 DONE item for user-facing reality; owner
  on-device reports instantly downgrade the named item to a P0 repair input.
This pairs with the LAUNCH-SMOKE + CAPABILITY-SURFACE-PARITY + ROUTING-NO-REGRESSION gates — together they close the
"green-but-not-user-reaching" hole that this session repeatedly hit.

## NO-HIDDEN-FALLBACK / POINT-OF-USE HONESTY GATE (owner 2026-06-20)
Any fallback / substitution / degradation / capability-gating must be VISIBLE to the user AT THE SURFACE where it happens —
not only a Settings/health row, not only a log entry. A honest fallback names what's actually running + why (e.g. chat shows
"running Qwen — your pick isn't installed"); a SILENT one (black-box surface) is a bug to fix. Scan each cycle for: model/route
substitutions surfaced only in Settings, `try?`/`?? default`/empty-catch that hide a failure as success on a user path, "for
show" controls, no-op-on-not-ready backends. Detail → SS-HF. Pairs with surface-parity + done-re-audit + routing-no-regression.

## NUANCE-COMPLETENESS gate (owner 2026-06-20: "the picker nuance slipped → check the WHOLE plan for lost nuance")
The Owner-Request Coverage Sweep must verify NUANCE, not just slice-existence. For EVERY owner message (verbatim, incl.
pre-compaction), enumerate each DISCRETE sub-ask as its own ledger checkbox + ensure the slice captures the SPECIFIC detail
(not a paraphrase that drops it). A slice existing ≠ every sub-ask inside it captured + scheduled to build. Each sweep:
1. Re-read the verbatim owner quotes (ledger + transcript). 2. For each, list the atomic sub-asks. 3. Confirm each is a ledger
[ ] + named in a slice with its specific nuance + will be BUILT (not just researched). 4. Flag any sub-ask that is
paraphrased-away, merged-and-lost, or research-only. Robust against compaction/interruption: verbatim quotes live in the
ledger/slices (durable), never only in conversation. Cross-ref Owner-Request Coverage Sweep, DONE-RE-AUDIT, plan-capture.

## FOLLOW-ON-CAPTURE gate (owner 2026-06-20: "add things like this and beyond to the plan")
Every loop commit that writes an "honest pending / next increment / deferred / not-faked / owner-flip" note must
have that note captured as an open `[ ]` ledger item (+ in SS-FOLLOWON) in the same or next monitor pass — so no
deferred-but-real work is lost to git history. The last-auditor harvests these each fire (grep commit bodies for
pending/next-increment/deferred/owner-flip). A deferred safe-increment is NOT a dropped item; it is a planned one.
Cross-ref Owner-Request Coverage Sweep + NUANCE-COMPLETENESS gate + SS-FOLLOWON.
