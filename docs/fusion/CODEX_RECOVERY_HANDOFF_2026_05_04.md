# Codex Recovery Handoff — Continue Stages A.4 → B.1, Use Claude As Sub-Agent — 2026-05-04

> **Hackathon abandoned 2026-05-03.** Active path is now the Canonical
> Recovery Plan (`docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`).
> Stages A.1, A.2, A.3 + first A.4 migration shipped today; this
> handoff continues from there.
>
> **No compromises. Stay canonical. Use Claude as a collaborating
> sub-agent.**

---

## 0. Context (≤ 15 min read)

The user explicitly abandoned the hackathon push and asked for the
Substrate to be completed fully canonically per the build docs. The
canon-debt audit + recovery sequence is in
`CANONICAL_RECOVERY_PLAN_2026_05_03.md`. Today's work landed the
first four stages (audit + GenUI dispatcher + first migration). You
continue from Stage A.4 priority 2 onward.

**Read in this order, exactly:**

1. **`CANONICAL_RECOVERY_PLAN_2026_05_03.md`** — the master recovery
   sequence (A.1 → F.4); the five-question PR discipline (Stage /
   GenUI route / Sovereign / Pro impact / TEMP-FREE-TIER); what
   stays as-is.
2. **`MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`** — Pro is part of
   the plan, not on the critical path. §4.5 TEMP-FREE-TIER (App
   Groups stripped — DON'T re-add). The phrase to use when tempted
   to scope-creep into Pro.
3. **`COGNITIVE_KERNEL_AUDIT_2026_05_04.md`** ← TODAY'S DELIVERABLE.
   The fragmentation map. §11 Recommended implementation order is
   your Stage B.1 sub-stage sequence.
4. **`COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`** §2 + §4 + §11 +
   Appendix B — the Hermes-in-Rust Phase 2 spec (Stage B.1 of the
   recovery).
5. **`COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`** §4 G.1-G.6 — the
   GenUI dispatcher you'll continue migrating renderers into.
6. **`HERMES_BRAND_DOCTRINE_2026_05_04.md`** ← TODAY'S DELIVERABLE.
   The brand identity gap doctrine. §6 HERMES-BRAND-STUB deferral
   list. Stage E.0 sub-stage.
7. **`/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md`** ←
   USER'S CANONICAL HERMES REFERENCE. 595 lines, 5 phases, exact
   file paths + line numbers + verification commands. **THIS IS
   AUTHORITATIVE for Stage B.1 — read every Hermes file it names
   before porting; do not re-derive.**
8. **`docs/HERMES_INTEGRATION_RESEARCH.md`** — Hermes Fast Pack 10
   + Deep Pack 30 + 40-file Hermes list; canonical operational doc.
9. **`docs/HERMES_PARITY_REPORT.md`** — what's FULL / PARTIAL /
   MISSING parity today (2026-03-30 snapshot).
10. **`Epistemos/Models/GenUI/GenUIPayload.swift`** + **`Epistemos/Engine/GenUIDispatcher.swift`** ← TODAY'S CODE — the GenUI surface to migrate Hermes renderers into.

---

## 1. The user's two corrections (canonical, must address)

### Correction 1 (2026-05-03): Hermes UI is placeholder, not canon

> "the ui for the hermes agent all that is basically like not at all
> what i wanted it should be the actual assets and hermes agent font
> and color with the real nous research logo, etc."

**Where it lives in canon:** `HERMES_BRAND_DOCTRINE_2026_05_04.md`.
Every Hermes-branded surface (sigil, accent colors, hero font,
terminal mono) currently ships with placeholder values under
explicit `HERMES-BRAND-STUB` markers. Your work routes through
Stage E.0 sub-stages:

- E.0.1: author `Epistemos/Views/Landing/Hermes/HermesBrand.swift`
  with placeholder design tokens
- E.0.2: migrate every Hermes view to consume from `HermesBrand.*`
  (no per-view literals)
- E.0.3: build the **caduceus** sigil in SwiftUI Canvas (public
  domain, ships immediately)
- E.0.4: bundle Inter + JetBrains Mono fonts in `Resources/Fonts/`
  (free OFL licenses, ship immediately)
- E.0.5: USER DECISION — pursue NousResearch licensing? (deferred
  to user)
- E.0.6 + E.0.7: gated on E.0.5

**Asset note:** `/Users/jojo/Downloads/hermesagent-color.svg` is a
broken 14-byte 404 placeholder, NOT a real SVG. The user thinks
they have it; they don't. Re-acquisition is part of E.0.5.

### Correction 2 (2026-05-04): Hermes Agent doesn't actually work

> "the hermes agent does not actually work at all i tt just has the
> same stuff as main chat. also i was thinking of having the nous
> research logo in the model picker and stuff as well and the chat
> changes to the hermes agent one, etc. gen ui everywhere but the
> genui should of course be like high-quality NS and SwiftUI like
> all the things i can get that look super native"

**Where it lives in canon:** the Hermes-runtime gap is
`COGNITIVE_KERNEL_AUDIT_2026_05_04.md` §9 — the six Rust modules
under `agent_core/src/hermes/` that don't exist yet are the cause.
Closing this gap is Stage B.1 (Hermes-in-Rust); the canonical
implementation reference is the user's
**`/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md`**.

Until B.1 ships, the Hermes UI is honestly "just main chat with a
sigil" — that's the audit's core finding.

The user's "GenUI everywhere with NousResearch identity" intent
spans:
- Model picker showing Hermes/NousResearch logo for Hermes models
- Chat surface visual identity changes when the active companion
  is on a Hermes model
- Settings screens use the brand tokens
- GenUI dispatcher renders cards in NousResearch design language

This is Stage E.0 + a follow-on integration sub-stage that touches
every Hermes-aware view. Doctrine handles it via the design-token
swap pattern; once `HermesBrand.swift` lands and views consume
from it, every NousResearch identity update is a one-file change.

---

## 2. Your recovery work (in order, no scope-creep)

### Stage A.4 priority 2: complete the Hermes Expert Mode renderer migration

Today's commit migrated `/status` end-to-end. Six more renderers in
`Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift` need
the same swap pattern:

| Renderer                | Current code          | Target swap                                                          |
|---|---|---|
| `renderHelpInline`      | `state.append(.artifact(Artifact(kind: .markdown, ...)))` | `state.append(.payload(.markdownCard(title: "Hermes Parity", lines.joined(...))))` |
| `renderConfigShowInline`| `state.append(.artifact(Artifact(kind: .yaml, ...)))`     | `state.append(.payload(.keyValueTable(title: "Config", [...])))` |
| `renderTokensInline`    | `state.append(.artifact(Artifact(kind: .yaml, ...)))`     | `state.append(.payload(.keyValueTable(title: "Tokens", [...])))` |
| `renderCostInline`      | `state.append(.artifact(Artifact(kind: .yaml, ...)))`     | `state.append(.payload(.keyValueTable(title: "Cost", [...])))` |
| `renderModelInline`     | `state.append(.artifact(Artifact(kind: .markdown, ...)))` (the .list case) | `state.append(.payload(.capabilityList(title: "Available Models", headers: [...], rows: [...])))` |
| `renderSearchInline`    | `state.append(.artifact(Artifact(kind: .markdown, ...)))` | `state.append(.payload(.searchResults(query: cmd.query, rows: [...])))` |

After this, every command in HermesExpertModeRunner that produced
structured output uses the canonical dispatcher. The legacy
`.artifact(...)` path stays in the codebase for backward
compatibility during the migration window.

**Acceptance:** `grep -c '.artifact(Artifact(' Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift`
returns 0; xcodebuild green; visible behavior unchanged but renders
flow through `GenUIDispatcher.shared.render(payload)` instead of
`ArtifactBlockView(artifact:)` directly.

### Stage E.0.1-E.0.4: the brand identity surface

Per `HERMES_BRAND_DOCTRINE_2026_05_04.md` §3:

1. Create `Epistemos/Views/Landing/Hermes/HermesBrand.swift` per the
   doctrine §3 exact spec (placeholder values + design-token shape)
2. Migrate every Hermes view file to consume from `HermesBrand.*`:
   - `HermesShimmeringSigil.swift` accent → `HermesBrand.primary`
   - `HermesExpertModeView.swift` `theme.resolved.accent.color` →
     `HermesBrand.primary`
   - `HermesExpertModeView.swift` `monoFont` → `HermesBrand.mono(13.5)`
   - `LiquidGreeting.hermesHeroPhrase` font →
     `HermesBrand.display(44)`
   - `HermesExpertModeToggleChip.swift` accent → `HermesBrand.primary`
3. Build the caduceus sigil in `HermesShimmeringSigil.swift` using
   SwiftUI `Canvas` Bezier paths (public domain mythological symbol;
   no licensing risk). Replace `Image(systemName: "figure.stand.dress")`.
4. Bundle Inter Variable + JetBrains Mono in `Resources/Fonts/`,
   register via `Info.plist` `ATSApplicationFontsPath` key. Switch
   `HermesBrand.display(...)` and `HermesBrand.mono(...)` to use
   `Font.custom(...)`.

**Acceptance:** `grep -rn 'HERMES-BRAND-STUB' Epistemos/Views/Landing/Hermes/`
shows only items in the doctrine §6 deferral list; no surfaces
outside the list. `Font.custom("Inter-Semibold", ...)` actually
loads (fallback to system if not bundled).

### Stage B.1: Hermes-in-Rust (the big one)

**This is the actual fix for "the hermes agent does not actually
work."** Per the recommended implementation order from
`COGNITIVE_KERNEL_AUDIT_2026_05_04.md` §11:

1. `agent_core/src/hermes/mod.rs` — public API stubs only
2. `agent_core/src/hermes/prompt_format.rs` — port from
   `Epistemos/LocalAgent/HermesPromptBuilder.swift` + verify against
   the user's `/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md`
   File Map "run_agent.py → agent_loop.rs" mapping
3. `agent_core/src/hermes/function_call.rs` — port from
   `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`
4. `agent_core/src/hermes/skills.rs` — **consolidate the three
   parallel surfaces** (`skill_router.rs` + `storage/skills_registry.rs`
   + `tools/skills.rs`). DO NOT re-derive — read each, decide
   `keep | collapse | reject`, then merge per the audit §2.
5. `agent_core/src/hermes/procedural_memory.rs` — lift from
   `agent_core/src/tools/skills.rs` (current seed)
6. `agent_core/src/hermes/self_evolution.rs` — new; references
   `AgentEvent` ring buffer
7. FFI bridge in `agent_core/src/bridge.rs` — expose the seven new
   entry points from `COGNITIVE_KERNEL_DOCTRINE` §3
8. Swift mirror — collapse `HermesPromptBuilder.swift` +
   `IncrementalToolCallDetector.swift` to ≤ 50-line FFI consumers

**Use the parity plan's PHASE 1 (5 unregistered tools) as the
shortest path to "Hermes actually works":** the parity plan §PHASE 1
identifies five tools (delegate_task, file_ops, memory, skills,
web_fetch) that are ALREADY IMPLEMENTED in Rust but NOT REGISTERED
in `tools::registry`. Registering them takes ~30 minutes per the
plan and gives Hermes immediate functional parity.

**Acceptance:** `cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build`
all pass; `grep 'fn agent_loop\|class.*AgentLoop\|impl.*AgentLoop' Epistemos/ agent_core/src/`
returns only canonical loop in `agent_core/src/agent_loop.rs` plus
≤ 50-line Swift FFI mirror in `LocalAgentLoop.swift`. The Hermes
Expert Mode UI's `/ask` calls into the Rust runtime instead of
fanning through MainChatSubmissionRouter.

---

## 3. Use Claude as a sub-agent (the collaboration model)

The user's instruction: "you both should be speaking together."

### When to ask Claude (via the user, in this same conversation)

- **Doctrinal interpretation questions:** "Does §X of the doctrine
  permit Y?" — Claude wrote the doctrines, can clarify intent
- **GenUI payload shape decisions:** "Should `/persona list` use
  `capabilityList` or `keyValueTable`?" — Claude knows the seven
  new schemas
- **Design-token decisions:** "What value should `HermesBrand.primary`
  be in the placeholder?" — Claude has the brand doctrine
- **Reading the parity plan slabs:** "Summarize PARITY PLAN PHASE 3
  Skills shipping" — Claude reads + condenses faster than re-grepping
- **Building scaffolds:** "Scaffold `agent_core/src/hermes/mod.rs`
  with the public API surface" — Claude writes the skeletons quickly
- **Cross-cutting verifications:** "Audit my migration of
  `renderHelpInline` against the canonical pattern" — Claude reviews

### When NOT to ask Claude

- **Build verification:** Codex runs xcodebuild + cargo test
  directly; no need to delegate
- **Canonical docs:** the doctrines are written; don't re-author
  unless explicitly extending
- **Pro-tier work:** out of scope per MAS-First Focus Doctrine; if
  user asks Claude about Pro, Claude redirects to "part of the
  plan, not on the critical path"
- **Decisions the user must make:** licensing (NousResearch logo),
  paid Apple Developer Program, scope changes — these go to the
  user, not Claude

### Pattern for handoff messages

When you want Claude to do something, write a short message that
the user will see + paste. Format:

```
@Claude: [short task description]

Context: [the file you're touching + the doctrine section you're
following + what you've done so far]

Decision needed: [the specific question or scaffold ask]
```

Keep it ≤ 8 lines. The user is the message bus; don't make them
copy long blocks.

---

## 4. The five-question PR discipline (every PR you ship)

Per `CANONICAL_RECOVERY_PLAN_2026_05_03.md` §2:

```
Stage:        which recovery stage (A.4 priority 2 / E.0.1 / B.1 step 4 / etc.)
GenUI route:  via dispatcher  |  GENUI-DEFER (with §9 row)  |  N/A
Sovereign:    canonical SovereignGate only  |  N/A
Pro impact:   no change  |  feature-gate (with restoration steps)  |  user-approved removal
TEMP-FREE-TIER: no change  |  added (with restoration row)
```

Five honest answers in the commit message body or it doesn't ship.

---

## 5. Anti-patterns (do NOT)

- **DO NOT** restore the App Group entitlement (TEMP-FREE-TIER)
- **DO NOT** add `Process()`, `NSTask`, `posix_spawn`, `Command::new`
  to active surface — Pro-only, gated
- **DO NOT** silently delete Pro-only stubs — preserves optionality
- **DO NOT** create a new XPC service target — needs paid Developer
  Team for cross-target signing; deferred until paid team
- **DO NOT** add new per-command UI renderers without GenUIDispatcher
  migration OR explicit `GENUI-DEFER:` marker + §9 row
- **DO NOT** create a parallel SovereignGate, AgentEvent enum, agent
  loop, skill registry, or LocalAuthentication caller — single
  canonical owners per kernel doctrine §1
- **DO NOT** modify the doctrine docs in `docs/fusion/*_2026_05_03.md`
  or `*_2026_05_04.md` — they're canonical; if you find drift, log
  to `CANON_GAPS_AND_ADDENDA_2026_05_02.md`
- **DO NOT** treat the `hermesagent-color.svg` 14-byte placeholder
  as a real SVG — it's a 404 download
- **DO NOT** scope-creep into the Cognitive DAG (Phase 8) or XPC
  Mastery (X.1-X.5) — those are deferred until B.1 stabilizes

---

## 6. Acceptance bar for the recovery push

Recovery push is "done" when:

```
[ ] Stage A.4 priority 2 — all 6 remaining Hermes renderers migrated
    to GenUIDispatcher; grep shows zero .artifact(Artifact( in
    HermesExpertModeRunner.swift
[ ] Stage E.0.1-E.0.4 — HermesBrand.swift authored, every Hermes
    view consumes from it, caduceus sigil rendered, fonts bundled
[ ] Stage B.1 — agent_core::hermes module live with 6 sub-modules
    + FFI bridge; Swift LocalAgentLoop ≤ 200 lines all FFI delegation;
    Hermes Expert Mode /ask calls into Rust runtime
[ ] Stage A.4 priority 2 (Approval Modal) + Daily Brief + Welcome
    Back GenUI migrations
[ ] xcodebuild -scheme Epistemos green
[ ] xcodebuild -scheme Epistemos-AppStore green (free-tier signing)
[ ] cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build green
[ ] All §2.5 doctrinal greps return zero (no parallel agent loops,
    no parallel skill registries, single biometric context owner)
[ ] grep -rn 'TEMP-FREE-TIER' returns exactly the doctrine §3
    items, no more
[ ] grep -rn 'GENUI-DEFER' returns exactly the doctrine §4 items,
    no more
[ ] grep -rn 'HERMES-BRAND-STUB' empty (or only doctrine §6 items)
[ ] HERMES_PARITY_REPORT.md updated to reflect new FULL parity items
    after B.1 + Phase 1 of the parity plan ship
```

When all checked, append one line to
`CANON_GAPS_AND_ADDENDA_2026_05_02.md`:

```
2026-05-XX — Codex recovery push complete. Stages A.1-A.4, E.0.1-E.0.4,
B.1 shipped. Hermes Agent fully functional via Rust runtime. GenUI
dispatcher canonical. Brand tokens centralized. <N> issues fixed,
<M> deferred to next push (DAG / XPC Mastery / etc.).
```

Then reply: **"RECOVERY PUSH COMPLETE — CANON RESTORED"**

**STOP after the reply.** Do NOT auto-continue into V2 work. The
post-recovery sequence is canonicalized at
`docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` but
**Codex must wait for the explicit user signal**:

> ***"RESUME SUBSTRATE V2"***

When the user types that exact phrase, read the V2 plan and begin
from V2.1 (Cognitive DAG Phase 8.A). Until then, recovery's done is
the natural pause point — gives the user a green-light decision
about timing, paid Apple Developer Program, collaborators, etc.

Same wait-for-signal pattern that `CODEX_DAG_RADAR_HANDOFF` uses for
its Phase 8 trigger, applied to the recovery → V2 transition.

---

## 7. Out of scope for this push (do NOT touch)

- Cognitive DAG doctrine (Phase 8) — paused until B.1 stabilizes
- XPC Mastery doctrine (Phases X.1-X.5) — paused; needs paid team
- Schema-First GenUI Phases G.4-G.6 (cross-runtime serialization,
  DAG integration, doctrine linter) — paused after G.3 priority 1
- Hermes-in-Rust Phase 3 (WASM exec via wasmtime) — paused
- Phase 4 (in-process bundled MCP) — paused
- LSP migration to in-process Rust — paused
- Pro-tier feature work of any kind — deferred per MAS-First Focus
- Hermes XPC service target creation — needs paid Developer Team
- Notes view integration of NotesSidebarSkin — separate slice
- Graph Live Theater (third Simulation placement) — separate slice
- Simulation custom-drawn body grammars (Stage E.1-E.2) — separate
  slice (after E.0 ships and stabilizes)

---

## 8. Cross-references

```
docs/fusion/CODEX_RECOVERY_HANDOFF_2026_05_04.md          ← this doc
docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md         (master sequence)
docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_04.md          (Stage A.1; informs B.1)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md       (Phase 2 Hermes-in-Rust spec)
docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md        (Phases G.1-G.6)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md          (Phase 8 — paused)
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md            (Phases X.1-X.5 — paused)
docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md        (Pro deferral discipline)
docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md           (Stage E.0; brand identity)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md        (T0-T15 + status)
docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md          (drift log; append on every gap)

/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md     ← USER'S CANONICAL HERMES REF
docs/HERMES_INTEGRATION_RESEARCH.md                       (Hermes Fast Pack 10 + Deep Pack 30)
docs/HERMES_PARITY_REPORT.md                              (FULL / PARTIAL / MISSING parity 2026-03-30)

Epistemos/Models/GenUI/GenUIPayload.swift                 ← TODAY'S CODE (Stage A.2)
Epistemos/Engine/GenUIDispatcher.swift                    ← TODAY'S CODE (Stage A.3)
Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift  (Stage A.4 first migration; 6 more to do)
Epistemos/Sovereign/SovereignGate.swift                   (canonical biometric context owner)
Epistemos/Models/Artifact.swift                           (legacy chat-block; Adapter routes here)
Epistemos/Views/Chat/ArtifactBlockView.swift              (canonical chat-block renderer)

CLAUDE.md                                                  (NON-NEGOTIABLE constraints)
```

---

## 9. The single sentence

> **Stages A.1-A.4 + Hermes Brand Doctrine shipped today; you
> continue with A.4 priority 2 (six renderer migrations) → E.0.1-E.0.4
> (brand tokens + caduceus + bundled fonts) → B.1 (Hermes-in-Rust,
> the actual fix), guided by the user's
> `EPISTEMOS-HERMES-PARITY-PLAN.md` for B.1 implementation, and use
> Claude as a sub-agent for doctrinal questions and quick scaffolds.**

No compromises. Stay canonical. Build it.
