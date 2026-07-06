# Build Prompt — Pro (OpenChamber) + the Rest of Epistemos: Make the Whole App Stellar

## ⚡ READ-FIRST PRIORITY LEDGER (if you skim nothing else, obey these)
1. **THE BOUNDARY IS ABSOLUTE: your diff touches ZERO protected paths (data core, the two sibling agent lanes, engine/FFI, security, build system). If in doubt, it's protected — flag it.**
2. **Two domains only: OpenChamber (Pro agent) + the shared rest-of-app. NEVER hand-edit the pbxproj.**
3. **"Build green" ≠ done — verify in the RUNNING app; never stop while a DoD is unmet.**
4. **Minimalism is law: add polish / hardening / connectedness, never bloat.**
5. **Every cycle (from Cycle 2): USE ≥1 prior skill, SHIP a profound build, FORGE a new reusable skill.**
6. **Build Prompt Forge (§ Feature Mandate) — the CANONICAL shared submission-time prompt upgrader, vault-grounded.**

## ❌ FAILURE MODES — worked anti-examples of "done wrong" (never do these)
- **Skim-and-declare** (the #1 failure this project keeps hitting): read the ledger, skip the body, ship a shallow change, say "nothing left." → A DoD is unmet; re-read.
- **Boundary breach** (the cardinal sin here): "one tiny edit" to a protected path — the data core, a sibling agent lane, engine/FFI, security, or the pbxproj. → Never; flag it.
- **Bloat / plumbing-as-done:** add surface area or chrome the app doesn't need instead of connecting + hardening what exists. Minimalism is law.
- **Fake capability:** ship a dead button or a faked state. → Gate it honestly.
- **Trophy skill:** forge a SKILL.md nothing reuses, or run a cycle that ignores the library. → Under-compounded.

> A research-and-build assignment for **two domains at once**: (1) the **Pro agent surface —
> OpenChamber** (harden and deeply upgrade its agent, exactly as the other two agents upgrade theirs),
> and (2) **the rest of Epistemos** — the onboarding, settings, navigation, voice, the app shell, the
> connective tissue that **every build (MAS, Pro, Experimental) shares.** You make both enterprise-grade,
> deeply hardened, and coherent — while the crown jewels (vault, graph, note surfaces) and the *other
> two agents' lanes* stay untouched and sacred. Read every word first.
>
> **This is a FOREVER LOOP.** It does not finish — it compounds. Every cycle you scout the deepest
> improvement (from EITHER domain), forge it, temper it, and **crystallize the breakthrough into a
> reusable skill you then build with**, then raise your own bar. See §∞.

You run in **parallel with two other agents** (MAS June, and 1Code Experimental). The single most
important rule is the boundary: **you own OpenChamber and the shared rest-of-app; you must not touch what
the other two own, and you must not touch the data/knowledge core.** Collisions and core-damage are the
failure mode to prevent above all else.

---

## ⛔ PROTECTED ZONES — DO NOT MODIFY (this is the prime directive)
Treat every path below as **read-only**. You may *read* them to understand contracts, and *call* their
public APIs — but you may **not edit, refactor, move, rename, or "improve"** them. When a change would
require editing a protected path, **STOP and flag it in your cycle log — never route around the
boundary.**

1. **The data & knowledge core (the crown jewels — the owner named these explicitly):**
   `Epistemos/Sync/**` (vault sync/index), `Epistemos/Vault/**`, `Epistemos/VaultMCP/**`,
   `Epistemos/VaultRecall/**`, `Epistemos/Graph/**` (the knowledge graph),
   `Epistemos/Views/Notes/**` + `Epistemos/Views/Epdoc/**` + `Epistemos/MarkEdit/**` + `js-editor/**`
   (the note/editor surfaces), `Epistemos/LiteParse/**`, `Epistemos/Eidos/**`, and any provenance /
   shadow-index / RRF-fusion code. **The user's data and second brain are inviolable.**
2. **The OTHER two agents' lanes (they own these; editing them = a collision):**
   `Epistemos/JuneAgent/**` (MAS June's), `Epistemos/ExperimentalAgent/**` + `.research-clones/1code/**`
   (1Code Experimental's). *(OpenChamber's `ProAgent/Goose/Work` are NO LONGER protected — they are your
   scope now; see below.)*
3. **The shared engine / inference / FFI / Rust core (fragile, high-blast-radius, shared by all builds):**
   `Epistemos/Engine/**` (MLX/Metal/local inference), `agent_core/**` + all Rust crates,
   `Epistemos/Bridge/**`, `Epistemos/Omega/**` (the omega-mcp crate — you *use* the bundled binary via
   Work, you do not refactor the crate), `Epistemos/Agent/**`, `Epistemos/AgentRuntimeV2/**`,
   `Epistemos/AgentWorkspace/**`, `Epistemos/Sovereign/**`, `Epistemos/Harness/**`,
   `Epistemos/Shaders/**`, `Epistemos/XPC/**`.
4. **Security & secrets:** `Epistemos/Security/**`, all Keychain code, entitlements plists, the
   proxy/paywall/receipt path. Never weaken a check, expose a secret, or change an entitlement.
5. **Build-system integrity (a recurring pain — respect it absolutely):** **NEVER hand-edit
   `Epistemos.xcodeproj/project.pbxproj`** (xcodegen-generated; changes go through `project.yml`
   regeneration, and you do **not** touch the MAS/Pro/Experimental/AppStore config+scheme splits). Do not
   edit any `build-*.sh` script (including `build-openchamber-web.sh`) or the Rust/agent-core/shadow
   build scripts. The vendored OpenChamber **web donor** (external / `.research-clones`) follows the
   existing vendoring discipline — flag web-donor needs for the owner; you harden the **Swift host +
   integration**, not the donor build.

**If in doubt, it's protected.** A change that "just needs a tiny edit" to a protected file is exactly
the change that has been breaking things — flag it for the owner instead.

## ✅ YOUR SCOPE — two domains

### Domain 1 — OpenChamber (the Pro agent surface): harden + deeply upgrade its agent
The Swift host + engine supervision + integration for the Pro agent, exactly the deep-audit/connect/
harden treatment the other two agents give theirs: `Epistemos/ProAgent/**` (supervisor, surface view,
theme bridge, nav bar, all-chats, child ledger, perf), `Epistemos/Goose/**` (the goose engine
supervision + provider-key bridge + web-surface support), `Epistemos/Work/**` (the OpenCode runtime + the
MCP vault-fusion writer), `Epistemos/ActGoose/**`. Make the Pro agent as robust, connected, and hardened
as June and Experimental are becoming — supervision, crash/zombie reaping, the script-message bridge,
theme fidelity, the MCP fusion, the instant-open recipe, provider-key flow. Connect its disconnected
parts; harden it to the deepest tier. (You call the shared engine/FFI core's public APIs; you do not edit
the core itself.)

### Domain 2 — The rest of the app (shared by ALL builds; upgrade all of it, deeply)
The connective tissue every build touches:
- **Onboarding** (`Epistemos/Views/Onboarding/**`): first-run flow, permissions, path to first value.
- **Settings** (`Epistemos/Views/Settings/**`): the settings shell, navigation, the health/diagnostics
  rows' *presentation* — without changing the protected subsystems they report on.
- **Landing / app shell** (`Epistemos/Views/Landing/**`, `Epistemos/App/**`): navigation, window chrome,
  the greeting, routing between rooms — but not the embedded MAS/Experimental agent surfaces or the
  bootstrap wiring of protected engines.
- **Voice & read-aloud** (`Epistemos/VoicePro/**`, the speech synthesizer, ReadAloudButton, voice prefs).
- **Shared UI** (`Epistemos/Views/Shared/**`), dialogs, sheets, empty/error/loading states,
  accessibility, keyboard nav, localization (`Epistemos/Resources/Localizable.xcstrings`), theme *polish*
  (`Epistemos/Theme/**` — presentation only, within the canon; never to alter a protected subsystem's
  behavior).
- **Non-core rooms** that aren't agent/notes/graph (e.g. `Epistemos/Arxiv/**`, mini-chat chrome).

When a workable file reaches into a protected subsystem's *internals or contract*, treat that line as a
boundary: call the public API, do not change the subsystem.

---

## THE ONE RULE (why past passes fell short)
**"Build green" is not done. "It compiles" is not "it works."** Done is the DoD below, each proven in
the **running app** with a real screenshot/transcript, plus a thermonuclear review with zero open HIGHs,
plus a clean diff that **touches zero protected paths**. Do not stop on plumbing; do not declare done
while any DoD is unmet; do not fake capability.

## §0 NON-NEGOTIABLES
1. **Minimalism is law** (`docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`): Apple-native
   unified blend is *the* look; pixel-minimalism only in fonts/accents/palette; **total theme-awareness**
   (every surface correct in light AND dark). You **add polish, hardening, coherence, and connectedness —
   never clutter, never feature-bloat, never visual noise.** Fewer, better, more native.
2. **Honest capability** — never ship a dead button or a fake state; absent = absent, gracefully.
3. **No regressions** — `swift test` stays green; never break a protected subsystem's caller contract.
4. **Standards** (project canon): `@Observable` not `ObservableObject`; no `try!`/force-unwraps/`print()`
   in production; heavy work off `@MainActor`; every `unsafe` gets a `// SAFETY:` comment;
   `DispatchQueue.main.async` in any FFI/UniFFI callback, never `.sync`.
5. **The recurring-issue guardrails:** xcodegen only (never edit the pbxproj); never two `xcodebuild`s at
   once (16 GB); never `git add -A`; commit narrowly; stay in your two domains.

## §1 THE THESIS — where "enterprise" is actually won
The Pro agent (OpenChamber) deserves the same depth of hardening its siblings are getting — a supervised,
crash-safe, deeply-connected, theme-perfect agent, not a half-wired web view. And **an app is judged at
its seams** — the first-run flow, the settings that don't confuse, the navigation that never janks, the
empty state that guides, the voice that just works, the error that recovers. World-class apps are the
ones whose Pro surface is bulletproof AND whose connective tissue is invisible because it's flawless.
Because the shared shell serves **every build**, one stellar upgrade here lifts MAS, Pro, and Experimental
at once. Judged on: **(1) OpenChamber robustness & connectedness**, **(2) coherence & flow of the shared
app**, **(3) minimal-native excellence + hardening across both.**

## FEATURE MANDATE — Prompt Forge (the CANONICAL shared prompt upgrader; you build the core)
You own shared shell services, so **you build the canonical `PromptForge` service the whole app reuses**
+ its OpenChamber composer integration. When a user submits a prompt in ANY surface, Prompt Forge deeply
upgrades it before it reaches the model — more robust/useful/effective — preserving intent and voice.
Full spec: `docs/research/PROMPT_UPGRADING_FIELD_STUDY.md` Part 3. Pipeline: intent+gaps → clarity+
structure (keep the user's nouns/constraints/voice) → task-matched technique injection (never
over-applied) → **vault-grounding** (retrieve relevant notes/graph via the vault's PUBLIC read API — you
READ, never edit the protected core; inject the highest-priority context that fits the model's window,
cite) → budget-aware assembly → clarify-don't-guess (≤3 questions on real ambiguity). UX: original→
upgraded diff, one-click Accept/Edit/Retry/Revert, never silent, fast (small model, streamed), show what
changed. Build the shared service (Swift, in your scope) + wire the OpenChamber composer, and expose a
clean API the other two surfaces adopt in their own lanes. Minimal + native + theme-correct (§0). Ships
DoD-gated (a live "underspecified prompt → upgraded, vault-cited prompt" transcript), not a stub.

## FEATURE MANDATE — System Prompt Forge + Pattern Library (companion to Prompt Forge; you build the core)
Prompt Forge upgrades the USER prompt; this upgrades the SYSTEM-prompt / behavior layer. You own shared
services → **build the canonical shared Pattern Library + System Prompt Forge service** the whole app
reuses + the OpenChamber integration. Two parts: (1) a curated, composable **Pattern Library**
(Fabric-model, markdown, task/persona-scoped) applied + composed per agent; (2) a system-prompt
**upgrader** that meta-improves a custom system prompt into the layered frontier architecture — **identity
→ capability-honesty → tool contract → refusal framing → output contract → priority budgeting → worked
failure examples** — preserving intent/voice, with the diff UX. Vault-grounded via the vault's PUBLIC read
API (read, never edit the core). Full spec + architecture lessons:
`docs/research/SYSTEM_PROMPT_FIELD_STUDY.md`. **⚠️ IP: learn the PATTERNS, NEVER copy proprietary
system-prompt TEXT.** Expose a clean API the other two surfaces adopt. Minimal + native (§0). Ships
DoD-gated (a custom system prompt measurably upgraded + a Pattern applied), not a stub.

## PHASE A — DEEP AUDIT (research your own code, both domains)
Two 7-layer audits. **A1 — OpenChamber:** map every seam of the Pro agent (supervision lifecycle,
child/zombie reaping, the bridge, theme fidelity, MCP fusion, provider-key flow, instant-open, the
dual-engine) — verdict CONNECTED/HALF-WIRED/DISCONNECTED/DEAD per seam, plus reliability/security/leak
risk. Deliverable: `docs/research/OPENCHAMBER_DEEP_AUDIT.md`. **A2 — the shared shell:** onboarding,
settings, landing/shell, voice, shared UI, states, a11y, localization, theming — hunt first-run friction,
dead-end states, inconsistent nav, un-themed (light/dark) surfaces, missing a11y, un-localized strings,
silent failures, view leaks, jank, disconnected shell parts. Deliverable: `docs/research/APP_SHELL_DEEP_AUDIT.md`.
Web-verify current Apple HIG/API facts where relevant.

## PHASE B — THERMONUCLEAR CODE REVIEW
Run the deepest `/code-review` you can invoke over your diff (both domains). Triage by the four lenses
(correctness, security, memory/data-leak, robustness). Fix every CONFIRMED HIGH before shipping. Re-review.

## PHASE C — BUILD (harden OpenChamber + make the seams stellar)
From the audits, upgrade in priority order across both domains: harden OpenChamber's supervision/reaping/
bridge/theme/MCP-fusion and connect its disconnected parts; and give the shared app a first-run that
reaches value fast, coherent settings, jank-free navigation, reliable voice, guiding empty/error states,
full accessibility + keyboard nav, total theme-awareness, localization coverage. Every change: minimal,
native, theme-correct, and *connecting* what was disconnected — never new surface area for its own sake.

## PHASE D — DEEPEST HARDENING (the four lenses over both domains)
Security (no secret leaked; no weakened check — you harden usage, you don't touch the security core),
memory/data-leak (view + web-surface teardown, no retain cycles, bounded state), robustness (no crash on
bad input/permission-denied/offline; graceful degradation), reliability (every error path recovers or
guides; OpenChamber's children never orphan). Reported thermonuclear (`N HIGH/MED/LOW`, file:line,
FIXED/DEFERRED); a HIGH blocks the commit. Perf budgets hold; zero test regressions.

---

## §∞ THE FOREVER LOOP — the self-evolving engine (the heart; it never ends)
Not a project with an end state, and NOT a skill-collecting exercise. A **loop of profound BUILDS** —
real upgrades (OpenChamber hardening OR shared-shell excellence) shipped every cycle — where **skills are
compounding leverage you USE to build, never trophies you collect.** Each cycle stands on the skills
before it and leaves one more. Phases A–D are **Cycle 1**. Then loop, forever. Five movements:
1. **SCOUT** — re-scan both domains, the field (how the best Apple-native apps + the best agent hosts do
   this), and the substrate. Name the one frontier — in OpenChamber OR the shared shell — whose upgrade
   this cycle would most raise the whole app's quality. One frontier per cycle — the deepest, staying
   minimal.
2. **FORGE — by COMPOSING your skills.** Build it to enterprise depth, **actively invoking your
   accumulated skills** (reuse prior breakthroughs, don't re-derive). Minimal, native, theme-correct,
   in-scope only. **The deliverable is the shipped, working build — not the skill.**
3. **TEMPER** — four lenses + thermonuclear review; zero HIGH; zero test regressions; verified running.
4. **CRYSTALLIZE** — distill the breakthrough into a NEW reusable `SKILL.md` under
   `.claude/skills/proshell-<slug>/` (a named, invocable capability + the methodology for that CLASS of
   upgrade). Update `.claude/skills/PROSHELL_SKILLS_INDEX.md`. The skill must capture a genuinely reusable
   class you'll invoke again — a "skill" no later cycle uses is dead weight to prune, not a trophy.
5. **ASCEND** — record what this cycle made possible and what it makes possible next; set the next bar
   higher. Commit. Loop.

**Invariants:** **from Cycle 2 on, every cycle USES ≥1 prior skill to build — a cycle that ignores the
library has failed to compound; no trophy skills.** Strictly additive; honest capability; minimalism
holds every cycle; **the protected zones (the two other agents' lanes, the data core, the shared engine/
FFI, security, the build system) are never touched, ever**; verify in the running app every cycle. By
cycle N, OpenChamber is bulletproof and the rest of Epistemos is as stellar as its core — because each
build stood on the last.

## DEFINITION OF DONE — per cycle (proven in the running app, not a compile)
- **DoD-Boundary (the one that matters most)** — `git diff` for the cycle touches **ZERO protected
  paths** (§ protected zones). Prove it: the diff's file list is entirely within your two domains. A
  single protected-path edit fails the cycle outright.
- **DoD-∞** — The cycle SHIPS a profound build (OpenChamber hardening OR a shared-shell upgrade, live in
  the running app), USES ≥1 prior skill (from Cycle 2 on), forges a new reusable skill + updates the
  index + raises the bar.
- **DoD-A** — The relevant deep-audit doc committed; every finding cited file:line.
- **DoD-B** — Thermonuclear review run; every CONFIRMED HIGH fixed; re-review clean.
- **DoD-C** — The upgrade is minimal + native + theme-correct in light AND dark; screenshot both (for
  OpenChamber, in the Pro build; for the shell, wherever it renders).
- **DoD-D** — Hardening report, zero open HIGHs; zero test regressions; perf budgets green.

## EXECUTION RULES (do not violate)
1. **Research-first, always.** Read the surface + its callers before editing; web-verify current
   Apple/HIG facts. Never pattern-match from memory.
2. Phases A → B → C → D per cycle, then loop. **Commit after every coherent change** (build green,
   `CODE_SIGNING_ALLOWED=NO` for headless checks; never two `xcodebuild`s at once). Verify in the RUNNING
   app — a compile is not evidence.
3. **Do not stop while any DoD is unmet.** Do not fake capability. Do not add bloat. If a scheduled/loop
   wrapper drives you with an older prompt, this file supersedes it.
4. **THE BOUNDARY IS ABSOLUTE:** never edit a protected path; never touch the MAS-June or 1Code-
   Experimental lanes, the data core, the shared engine/FFI, security, or the build system; never
   hand-edit the pbxproj; never `git add -A`; commit narrowly within your two domains; report honestly.

**The bar, restated:** the owner opens the Pro build and OpenChamber is bulletproof — supervised,
connected, theme-perfect; and across every build, onboarding, settings, navigation, voice, and every seam
of Epistemos is flawless — minimal, native, coherent, accessible, unbreakable — enterprise-grade to the
same standard as the vault, graph, and notes it surrounds, which you never touched.
