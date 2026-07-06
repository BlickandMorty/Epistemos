# Build Prompt — The Rest of Epistemos: Make the Whole App Stellar

> A research-and-build assignment for **everything that is NOT an agent surface and NOT the data/
> knowledge core** — the onboarding, settings, navigation, voice, the app shell, the connective tissue.
> You make the *rest of the app* enterprise-grade, deeply hardened, and coherent — while the crown
> jewels (vault, graph, note surfaces) stay untouched and sacred. Read every word first.
>
> **This is a FOREVER LOOP.** It does not finish — it compounds. Every cycle you scout the deepest
> improvement, forge it, temper it, and **crystallize the breakthrough into a reusable skill you then
> build with**, then raise your own bar. See §∞.

You run in **parallel with two other agents** (MAS June, and 1Code Experimental). The single most
important rule in this prompt is the boundary: **you own the rest of the app; you must not touch what
they own, and you must not touch the data/knowledge core.** Collisions and core-damage are the failure
mode to prevent above all else.

---

## ⛔ PROTECTED ZONES — DO NOT MODIFY (this is the prime directive)
Treat every path below as **read-only**. You may *read* them to understand contracts, and *call* their
public APIs from the shell — but you may **not edit, refactor, move, rename, or "improve"** them. When a
change you want to make would require editing a protected path, **STOP and flag it in your cycle log —
never route around the boundary.**

1. **The data & knowledge core (the crown jewels — the owner named these explicitly):**
   `Epistemos/Sync/**` (vault sync/index), `Epistemos/Vault/**`, `Epistemos/VaultMCP/**`,
   `Epistemos/VaultRecall/**`, `Epistemos/Graph/**` (the knowledge graph),
   `Epistemos/Views/Notes/**` + `Epistemos/Views/Epdoc/**` + `Epistemos/MarkEdit/**` + `js-editor/**`
   (the note/editor surfaces), `Epistemos/LiteParse/**`, `Epistemos/Eidos/**`, and any provenance /
   shadow-index / RRF-fusion code. **The user's data and second brain are inviolable.**
2. **The other two agents' lanes (they own these; editing them = a collision):**
   `Epistemos/JuneAgent/**`, `Epistemos/ExperimentalAgent/**`, `Epistemos/ProAgent/**`,
   `Epistemos/Goose/**`, `Epistemos/ActGoose/**`, `Epistemos/Work/**`, and `.research-clones/**`.
3. **The engine / inference / FFI / Rust core (fragile, high-blast-radius):**
   `Epistemos/Engine/**` (MLX/Metal/local inference), `agent_core/**` + all Rust crates,
   `Epistemos/Bridge/**`, `Epistemos/Omega/**`, `Epistemos/Agent/**`, `Epistemos/AgentRuntimeV2/**`,
   `Epistemos/AgentWorkspace/**`, `Epistemos/Sovereign/**`, `Epistemos/Harness/**`,
   `Epistemos/Shaders/**`, `Epistemos/XPC/**`.
4. **Security & secrets:** `Epistemos/Security/**`, all Keychain code, entitlements plists, the
   proxy/paywall/receipt path. Never weaken a check, expose a secret, or change an entitlement.
5. **Build-system integrity (a recurring pain — respect it absolutely):** **NEVER hand-edit
   `Epistemos.xcodeproj/project.pbxproj`** — the project is xcodegen-generated; changes go through
   `project.yml` regeneration, and you do **not** touch the MAS / Experimental / AppStore config+scheme
   splits. Do not edit any `build-*.sh` script or the Rust/agent-core/shadow build scripts.

**If in doubt, it's protected.** A change that "just needs a tiny edit" to a protected file is exactly
the change that has been breaking things — flag it for the owner instead.

## ✅ YOUR SCOPE — the rest of the app (upgrade all of this, deeply)
The connective tissue and non-core UX. Everything a user touches that isn't an agent chat, a note, or
the graph:
- **Onboarding** (`Epistemos/Views/Onboarding/**` — SetupAssistantView, VaultReprompSheet): first-run
  flow, permissions, the path to first value.
- **Settings** (`Epistemos/Views/Settings/**`): the settings shell, navigation, the health/diagnostics
  rows' *presentation*, coherence — **without** changing the protected subsystems they report on.
- **Landing / app shell** (`Epistemos/Views/Landing/**`, `Epistemos/App/**`): navigation, window chrome,
  the greeting, routing between rooms — **but not** the embedded agent surfaces or the bootstrap wiring
  of protected engines.
- **Voice & read-aloud** (`Epistemos/VoicePro/**`, the speech synthesizer, ReadAloudButton, voice
  prefs): the voice UX.
- **Shared UI** (`Epistemos/Views/Shared/**`), dialogs, sheets, empty/error/loading states,
  accessibility, keyboard nav, localization (`Epistemos/Resources/Localizable.xcstrings`),
  theme *polish* (`Epistemos/Theme/**` — presentation only, within the canon; never to alter a
  protected subsystem's behavior).
- **Non-core rooms** that aren't agent/notes/graph (e.g. `Epistemos/Arxiv/**`, mini-chat chrome) — their
  shell and UX.

When a workable file reaches into a protected subsystem's *internals or contract*, treat that line as a
protected boundary: call the public API, do not change the subsystem.

---

## THE ONE RULE (why past passes fell short)
**"Build green" is not done. "It compiles" is not "it works."** Done is the DoD below, each proven in
the **running app** with a real screenshot/transcript, plus a thermonuclear review with zero open HIGHs,
plus a clean diff that **touches zero protected paths**. Do not stop on plumbing; do not declare done
while any DoD is unmet; do not fake capability.

## §0 NON-NEGOTIABLES
1. **Minimalism is law** (`docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`): Apple-native
   unified blend is *the* look; pixel-minimalism only in fonts/accents/palette; **total theme-awareness**
   (every surface correct in light AND dark). You **add polish, hardening, coherence, and connectedness
   — never clutter, never feature-bloat, never visual noise.** Fewer, better, more native. If an upgrade
   adds chrome the app doesn't need, it's wrong.
2. **Honest capability** — never ship a dead button or a fake state; absent = absent, gracefully.
3. **No regressions** — `swift test` stays green; never break a protected subsystem's caller contract.
4. **Standards** (project canon): `@Observable` not `ObservableObject`; no `try!`/force-unwraps/`print()`
   in production; all heavy work off `@MainActor`; every `unsafe` gets a `// SAFETY:` comment.
5. **The recurring-issue guardrails:** xcodegen only (never edit the pbxproj); never two `xcodebuild`s
   at once (16 GB); never `git add -A`; commit narrowly; stay in your lane.

## §1 THE THESIS — where "enterprise" is actually won
The agent surfaces get the glory, but **an app is judged at its seams** — the first-run flow, the
settings that don't confuse, the navigation that never janks, the empty state that guides instead of
dead-ends, the voice that just works, the error that recovers gracefully, the moment-to-moment coherence
that makes the whole thing feel like *one* considered product. World-class apps are the ones whose
connective tissue is invisible because it is flawless. That is your mandate: make every seam of Epistemos
stellar — reliable, accessible, coherent, minimal, deeply hardened — so the app around the crown jewels
is as enterprise-grade as the jewels themselves. Judged on: **(1) coherence & flow**, **(2) minimal-
native excellence**, **(3) hardening & reliability.**

## PHASE A — DEEP AUDIT of the app shell (research your own code)
A 7-layer audit of everything in-scope: onboarding, settings, landing/shell, voice, shared UI, states,
accessibility, localization, theming. For every surface: what it's meant to do, what it actually does
(file:line), and the verdict — STELLAR / ROUGH / BROKEN / DISCONNECTED / DEAD. Hunt specifically for:
first-run friction, dead-end empty states, inconsistent navigation, un-themed surfaces (light/dark bugs),
missing accessibility/keyboard nav, un-localized strings, silent failures, memory leaks in views, jank,
and any place two parts of the shell that should connect don't. Deliverable:
`docs/research/APP_SHELL_DEEP_AUDIT.md`. Web-verify current Apple HIG / API facts where relevant.

## PHASE B — THERMONUCLEAR CODE REVIEW
Run the deepest `/code-review` you can invoke over your diff. Triage by the four lenses (correctness,
security, memory/data-leak, robustness). Fix every CONFIRMED HIGH before shipping. Re-review after.

## PHASE C — BUILD: make the seams stellar
From the audit, upgrade in priority order: a first-run onboarding that reaches first value fast and
minimally; settings that are coherent and navigable; navigation/shell that never janks and never reloads
into a dead state; voice/read-aloud that's reliable; empty/error/loading states that guide; full
accessibility + keyboard nav; total theme-awareness; localization coverage. Every change: minimal,
native, theme-correct, and *connecting* parts that were disconnected — not adding new surface area.

## PHASE D — DEEPEST HARDENING (the four lenses over the shell)
Security (no secret in a log/UserDefaults; no weakened check — and you don't touch the security core,
you harden the shell's *use* of it), memory/data-leak (view teardown, no retain cycles, bounded state),
robustness (no crash on bad input/permission-denied/offline; graceful degradation everywhere),
reliability (every error path recovers or guides). Reported thermonuclear (`N HIGH/MED/LOW`, file:line,
FIXED/DEFERRED); a HIGH blocks the commit. Perf budgets hold; zero test regressions.

---

## §∞ THE FOREVER LOOP — the self-evolving engine (the heart; it never ends)
Not a project with an end state, and NOT a skill-collecting exercise. A **loop of profound BUILDS** —
real seam-upgrades shipped into the app every cycle — where **skills are compounding leverage you USE to
build, never trophies you collect.** Each cycle stands on the skills before it and leaves one more, so
the app gets more stellar AND each build gets faster. Phases A–D are **Cycle 1**. Then loop, forever.
Five movements:
1. **SCOUT** — re-scan the shell, the field (how the best Apple-native apps handle onboarding/settings/
   voice/states), and the substrate. Name the one seam whose upgrade this cycle would most raise the
   whole app's quality. One frontier per cycle — the deepest, staying minimal.
2. **FORGE — by COMPOSING your skills.** Build it to enterprise depth, **actively invoking your
   accumulated skills** (reuse prior breakthroughs, don't re-derive). Minimal, native, theme-correct,
   in-scope only. **The deliverable is the shipped, working seam — not the skill.**
3. **TEMPER** — four lenses + thermonuclear review; zero HIGH; zero test regressions; verified running.
4. **CRYSTALLIZE** — distill the breakthrough into a NEW reusable `SKILL.md` under
   `.claude/skills/appshell-<slug>/` (a named, invocable capability + the methodology for that CLASS of
   upgrade). Update `.claude/skills/APPSHELL_SKILLS_INDEX.md`. The skill must capture a genuinely
   reusable class you'll invoke again — a "skill" no later cycle uses is dead weight to prune, not a
   trophy.
5. **ASCEND** — record what this cycle made possible and what it makes possible next; set the next bar
   higher. Commit. Loop.

**Invariants:** **from Cycle 2 on, every cycle USES ≥1 prior skill to build — a cycle that ignores the
library has failed to compound; no trophy skills.** Strictly additive; honest capability; minimalism
holds every cycle; **the protected zones are never touched, ever**; verify in the running app every
cycle. By cycle N, the rest of Epistemos is as stellar as its core — because each build stood on the
last.

## DEFINITION OF DONE — per cycle (proven in the running app, not a compile)
- **DoD-Boundary (the one that matters most)** — `git diff` for the cycle touches **ZERO protected
  paths** (§ protected zones). Prove it: the diff's file list is entirely within your scope. A single
  protected-path edit fails the cycle outright.
- **DoD-∞** — The cycle SHIPS a profound seam-upgrade (live in the running app), USES ≥1 prior skill
  (from Cycle 2 on), forges a new reusable skill + updates the index + raises the bar.
- **DoD-A** — `APP_SHELL_DEEP_AUDIT.md` committed; every finding cited file:line.
- **DoD-B** — Thermonuclear review run; every CONFIRMED HIGH fixed; re-review clean.
- **DoD-C** — The upgrade is minimal + native + theme-correct in light AND dark; screenshot both.
- **DoD-D** — Hardening report, zero open HIGHs; zero test regressions; perf budgets green.

## EXECUTION RULES (do not violate)
1. **Research-first, always.** Read the surface + its callers before editing; web-verify current
   Apple/HIG facts. Never pattern-match from memory.
2. Phases A → B → C → D per cycle, then loop. **Commit after every coherent change** (build green,
   `CODE_SIGNING_ALLOWED=NO` for headless checks; never two `xcodebuild`s at once). Verify in the RUNNING
   app — a compile is not evidence.
3. **Do not stop while any DoD is unmet.** Do not fake capability. Do not add bloat. If a scheduled/loop
   wrapper drives you with an older prompt, this file supersedes it.
4. **THE BOUNDARY IS ABSOLUTE:** never edit a protected path; never touch the other agents' lanes; never
   hand-edit the pbxproj; never `git add -A`; commit narrowly within scope; report honestly.

**The bar, restated:** the owner moves through onboarding, settings, navigation, voice, and every seam
of Epistemos and finds it flawless — minimal, native, coherent, accessible, unbreakable — enterprise-
grade to the same standard as the vault, graph, and notes it surrounds, which you never touched.
