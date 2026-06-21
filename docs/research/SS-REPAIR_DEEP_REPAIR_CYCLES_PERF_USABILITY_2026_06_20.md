# SS-REPAIR — Deep Repair Cycles + deep perf/usability wins (recurring discipline) (2026-06-20)

Owner: *"These are things that should be part of the deep repair parts — idk if the repair already happened, but all of these
should be added parts to the repair cycles. Also deep deep wins for performance and actual usability."* So: stop treating the
on-device failures (chat, theme, images, white bar, composer, routing, local tools, graph) as scattered one-offs — fold them
into a RECURRING REPAIR CYCLE, and run a standing pursuit of deep perf + real-usability wins. Cross-ref SS-CLEAN (muddiness/
coverage/launch-smoke/routing-no-regression), SS-PERF2 (perf), SS-BWB (big wins), SS-CC/SS-CR/SS-THX/SS-2S/SS-GC/SS-SH/SS-LT/SS-GE.

## The DEEP REPAIR CYCLE (recurring — run it as a standing loop discipline, ~every cycle/5 iters alongside SS-CLEAN)
A repair cycle is **find → fix → verify (on-device-equivalent) → repeat**, not a one-shot:
1. **FIND (proactive + reactive):** sweep for things that are BROKEN / REGRESSED / MUDDY for the USER — not just build-green.
   Sources: (a) every owner on-device report (the authoritative witness); (b) a proactive self-sweep — does each core flow
   actually WORK end-to-end (chat returns an answer, theme applies in one change, images render, panels aren't blank, controls
   are pressable, tools fire)? (c) the SS-CLEAN gates (dead-flag/orphan, duplicate, surface-parity, layering-mud, routing-matrix).
2. **FIX:** NO-RISK-DEFERRAL (research a provably-safe seam + regression guard → code), commit-before-edit savepoint, honest tier.
3. **VERIFY on-device-equivalent, NOT just unit-green** (the recurring miss): render/snapshot tests + xcodebuild launch-smoke +
   for routing the FULL matrix; "tests pass" ≠ "works for the owner." Mark done only when user-facing-or-witnessed.
4. **REPEAT** until the cycle finds nothing broken, then move to the next surface.

## Active repair batch (the current broken/regressed/muddy set — all owner-reported, all reopened where needed)
- 🔴 CHAT P0 (SS-CR): Local→"provider rejected credentials" — uninstalled-Gemma-default strands installed Qwen → cloud
  auto-route. Fix at `sanitizedInteractiveLocalTextModelID:6113` + FULL routing-matrix regression. THE top repair.
- CHAT COMPOSER (SS-CC): minimal Apple-native runtime control; context glyph + thicker hit-target; cowork/book works-or-removed;
  FUSE tools+skills+commands into one working button; sweep main+mini+all chats.
- THEME (SS-THX regression): custom theme needs ~3 changes to match — themeRevision re-apply + full cache flush.
- IMAGES (SS-2S full render): owner wants to SEE the image, not the chip → offset-safe inline-attachment render.
- WHITE BAR (SS-GC): re-verify the Live-Preview-header fix actually killed it on-device.
- BLANK SIDEBAR (SS-SH): Settings sidebar blank — build + render-test.
- LOCAL TOOLS (SS-LT): intent→tool worked once, now regressed (ConfidenceRouter/local prompt).
- GRAPH (SS-GE): inline-edit all surfaces in both graphs; raw-thoughts visibility; appearance toggles wired.
- LAUNCH (SS-CRASH): keep the launch-smoke gate green every cycle.

## DEEP PERF + USABILITY WINS (standing pursuit, run as part of each repair cycle)
Beyond fixing broken things, every cycle also hunts a BIG win for PERFORMANCE and ACTUAL USABILITY (owner: "deep deep wins"):
- **Perf:** profile the hot paths (chat token stream, graph render/120Hz, theme resolve, editor open, recall) for jank/alloc/
  blocking-main; land a measured win (cross-ref SS-PERF2 remaining #7/#9-12, the 2026-04-29 perf wave patterns). Witness = a
  measured before/after, not a guess.
- **Usability:** the obvious "any sane person would want this" upgrades (cross-ref SS-BWB: ⌘K palette, unified search, error/
  empty/retry states, first-run time-to-value, model-status clarity, a11y/Dynamic-Type). Pick the highest-ROI, ship it
  user-facing, verify it's reachable.
- Pick ONE perf + ONE usability win per cycle so it compounds without churn; record the measured/observed result honestly.

## How it runs (no new machinery — it's the loop's standing cadence)
The loop already self-runs SS-CLEAN every ~5 iters; the REPAIR CYCLE is that gate PLUS the find→fix→verify repair pass + one
perf + one usability win. The monitor (last-auditor) treats owner on-device reports as P0 repair inputs and verifies fixes
on-device-equivalent. Everything here is in the PLAN (ledger + slices), per the owner's plan-capture rule — never prompt-only.
