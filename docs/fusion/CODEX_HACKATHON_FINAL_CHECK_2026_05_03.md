# Codex Hackathon Final Check — Hermes + Simulation Demo-Ready — 2026-05-03

> **Your job:** verify Hermes Expert Mode (T5) + Simulation Mode v1.6 /
> Companion Farm (T6) are demo-usable end-to-end for the hackathon.
> Fix any gaps you find. Polish without scope-creep. **No compromises**
> on canon-compliance, BUT no work on Pro-tier surfaces (per
> `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`). Stay strictly inside the
> MAS-shippable surface.
>
> **Time budget:** ≤ 4 focused hours. If you hit ceiling on a fix,
> stop, log to `CANON_GAPS_AND_ADDENDA_2026_05_02.md`, move on.

---

## 0. Read first (in this order, ≤ 30 min)

1. **`docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`** — Pro is
   PART OF THE PLAN, NOT ON THE CRITICAL PATH. The phrase. §4.5
   TEMP-FREE-TIER (App Groups stripped — DON'T try to re-add).
2. **`docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`** — every PR
   that adds a per-command renderer needs `GENUI-DEFER:` marker +
   §9 deferral list row OR a dispatcher migration. No third option.
3. **`docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`** — Track
   numbering vocabulary: T5 = Hermes, T6 = Simulation. "Lane A/B" =
   git branches; never reuse "Lane" for features.
4. **`Epistemos/Views/Landing/Hermes/`** — every file (8 files) — what
   shipped this session
5. **`Epistemos/Views/Landing/Farm/`** — every file (5 files) — what
   shipped this session
6. **`Epistemos/Models/Companion/CompanionModel.swift`** +
   **`Epistemos/State/Companion/CompanionState.swift`** —
   Simulation foundation
7. The most recent ~15 commits via `git log --oneline -15` to absorb
   slice-by-slice progress

**DO NOT** read the Kimi/GPT mockup folders for this pass — those are
research-grade per `EPISTEMOS_FUSION_HANDOFF_2026_05_03.md`. Stay in
the canonical Epistemos tree.

---

## 1. Verification gates (run in order; STOP at first failure)

### 1.1 Build matrix (5 min)

```bash
# MAS scheme — the active surface
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# AppStore scheme — verify it still signs/builds with TEMP-FREE-TIER
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust kernel — MAS feature default
cargo build --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build

# Tests — agent_core only (Swift tests are slower; defer)
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build
```

**Pass criteria:** all four green. If any fail, that's your first fix.

### 1.2 Doctrinal greps (3 min)

```bash
# 1.2.1 Sovereign Gate single-owner — must return zero
grep -rn 'LAContext\|canEvaluatePolicy\|evaluatePolicy' \
  Epistemos/ --include='*.swift' \
  | grep -v 'Epistemos/Sovereign/'

# 1.2.2 No subprocess in new Hermes/Farm code — must return zero
grep -rn 'Process()\|NSTask\|Command::new' \
  Epistemos/Views/Landing/Hermes/ \
  Epistemos/Views/Landing/Farm/ \
  Epistemos/State/Companion/ \
  Epistemos/Models/Companion/ \
  --include='*.swift'

# 1.2.3 No PRO_BUILD-only code reachable from MAS — must return zero
grep -rn '#if PRO_BUILD' \
  Epistemos/Views/Landing/Hermes/ \
  Epistemos/Views/Landing/Farm/ \
  --include='*.swift'

# 1.2.4 Pro-only Hermes commands NOT exposed via parseCore — must return zero
grep -rn '\.execute\b\|\.run\b\|\.shell\b\|\.kill\b' \
  Epistemos/LocalAgent/HermesCommandDispatcher.swift

# 1.2.5 No App Group entitlement re-added accidentally
grep 'application-groups' Epistemos/Epistemos-AppStore.entitlements

# 1.2.6 GENUI-DEFER markers intact on Hermes runner
grep -c 'GENUI-DEFER' Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift
# expected: at least 1
```

### 1.3 Hermes Expert Mode demo loop (15 min)

Launch the app, click the "Hermes Mode" chip on the landing page (or
press ⌥⌘H). Verify in order:

| # | Action | Expected | If broken |
|---|---|---|---|
| H1 | Click toggle | Greeting backspaces character-by-character | Check `LiquidGreeting.enterHermesHeroMode` |
| H2 | After backspace | Shimmering girl SF Symbol (`figure.stand.dress`) appears with halo + sweep | Check `HermesShimmeringSigil` |
| H3 | After sigil | "Hermes Agent" types out in hero font | Check `LiquidGreeting.hermesHeroPhrase` |
| H4 | After typewrite | Liquid-glass terminal box appears below | Check `HermesExpertModeView.body` |
| H5 | Type `/help` | Markdown card with sections (Agent / Session / Config / Files / Persona / UI / Tools / Advanced / Toolset / Messaging) | Check `renderHelpInline` |
| H6 | Type `/calc 2*3.14159` | Inline `= 6.28318` | Check `renderCalcInline` |
| H7 | Type `/status` | Yaml card with 6 fields | Check `renderStatusInline` |
| H8 | Type `/config show` | Yaml card with 8 fields | Check `renderConfigShowInline` |
| H9 | Type `/search test` (something in vault) | Markdown card with hits + snippets | Check `renderSearchInline` + vaultSync wiring |
| H10 | Type `/model list` | Markdown card local + cloud | Check `renderModelInline .list` |
| H11 | Type `/` only | Live palette appears below input with up to 6 matches | Check `commandPalette` |
| H12 | Press ↓ (palette open) | Selection moves; ▸ marker on highlighted row | Check `movePaletteSelection` |
| H13 | Press Tab on highlighted row | Token autofills into input | Check `autofillFromMatch` |
| H14 | Press ↑ (palette closed) | Previous submitted command recalls into input | Check `recallPrev` |
| H15 | Type `/write foo bar` | Touch ID prompt with reason "Write to a vault file" | Check Sovereign Gate route + `sovereignReason` |
| H16 | Press ⏎ on bare prompt "what is 2+2" | "→ opening main chat for streaming response…" appears, then exits to main chat | Check `handleHermesExpertSubmit` + `handoffAsAsk` |
| H17 | Press Esc | Mode exits cleanly back to greeting playlist | Check `onKeyPress(.escape)` |
| H18 | Press ⌥⌘H | Toggles back to expert mode | Check hidden Button shortcut in `.background` |

### 1.4 Simulation Mode v1.6 — Companion Farm demo loop (15 min)

| # | Action | Expected | If broken |
|---|---|---|---|
| S1 | Land on home (no Hermes Mode) | Companion Farm panel visible with "Sage" companion idle-breathing | Check `LandingFarmView` mount + `seedDefaultIfEmpty` |
| S2 | Click Sage | Active marker appears (capsule under name); name turns accent color | Check `companionState.activate(_:)` |
| S3 | Click "+ New Companion" | 4-step wizard sheet opens | Check `farmShowingCreate` sheet binding |
| S4 | Step 1: pick "Orb" | Card highlights with accent border | Check `bodyKind` selection |
| S5 | Step 2: type a name | "Next" button enables when name non-empty | Check `canAdvance` |
| S6 | Step 3: pick a preset color | Selected swatch gets primary stroke | Check `accentHex` binding |
| S7 | Step 4: see preview | CompanionView renders with chosen body + accent | Check confirm step |
| S8 | Click "Create" | Wizard dismisses; new companion appears in Farm | Check `companionState.createCompanion` + `reloadRoster` |
| S9 | Right-click any companion → Delete | Delete sheet opens; companion preview shown | Check context menu + `farmDeleteTarget` |
| S10 | Click "Move to trash" | Touch ID prompt with reason "Move companion 'X' to trash" | Check `confirmAndArchive` + Sovereign Gate |
| S11 | After Touch ID approved | Companion fades out; sheet dismisses; companion gone from Farm | Check `archive` + animation |
| S12 | Click trash chip "N in trash" | Restore sheet opens with archived companion(s) | Check `farmShowingRestore` |
| S13 | Click Restore on a row | Companion moves back to Farm | Check `companionState.restore` |
| S14 | Click Purge Forever | Touch ID prompt with reason "Permanently delete…" (every-time, no grace) | Check `purge` + `.deviceOwnerAuthentication` |
| S15 | Right-click companion → Apply Adapter | Adapter sheet opens with gift-box visual | Check `farmAdapterTarget` + `CompanionAdapterView` |
| S16 | Type adapter path + click "Unwrap" | Gift box scales out; companion shimmers; phase reaches `.settled` after ≥ 1.6s | Check Invariant I-11 floor |
| S17 | Quit and re-launch | All companions persist (SwiftData); Sage still seeded if first launch | Check `EpistemosSchema.models` includes CompanionModel |
| S18 | System Settings → Accessibility → Reduce Motion ON, restart | Sigil + companions render static with "idle" badge; no animations | Check `accessibilityReduceMotion` env var |

---

## 2. Fix list (if you find issues; in priority order)

These are the specific issues likely to surface during §1.3 / §1.4. Fix
the ones that block demo; defer rest with a row in
`CANON_GAPS_AND_ADDENDA_2026_05_02.md`.

### Priority 1 (demo-blocking)

- **Sigil missing or fallback box visible** — verify `figure.stand.dress`
  resolves on this macOS version. If missing, swap to
  `person.crop.circle.fill` in `HermesShimmeringSigil.systemImageName`.
- **Hero font not rendering** — verify `AppDisplayTypography.font(size: 44)`
  works for "Hermes Agent". If broken, fall back to `.system(size: 44, weight: .semibold, design: .rounded)`.
- **Touch ID prompt fires twice / wrong reason text** — verify
  `sovereignReason(for:)` returns the correct string per command.
- **Companion not persisting across launches** — verify
  `CompanionModel.self` is in `EpistemosSchema.models` and the
  ModelContainer doesn't fall back to in-memory.
- **Sovereign Gate denied flow shows no error** — verify error
  surface in `CompanionDeleteSheet.confirmAndArchive` switch
  `.denied` branch renders the error message.

### Priority 2 (polish)

- **Palette never appears** when you type `/` — verify
  `state.showingCommandPalette` flips on `updateDraft`.
- **Arrow keys don't navigate palette** — verify `.onKeyPress(.downArrow)`
  / `.upArrow` reach the TextField (some macOS versions consume them
  for cursor movement; if so, gate behind a non-default modifier).
- **Tab doesn't autofill** — same root cause; may need
  `Button(action:){...}.keyboardShortcut(.tab, modifiers: [])`
  pattern instead of `.onKeyPress(.tab)`.
- **`/search` returns empty for vault content that should match** —
  verify `vaultSync.searchFull(query:limit:)` is wired and
  `RRFFusionFlags.isEnabled` matches what you expect.
- **Adapter unwrap floor too short** — bump
  `CompanionAdapterView.applyAdapter` `unwrapMin` from 1.6 to 2.0
  if the gift-box animation feels rushed.

### Priority 3 (visual refinement)

- **Hermes terminal feels cramped** — bump
  `HermesExpertModeView.maxWidth` if landing layout permits
- **CompanionView hover lift too subtle / too dramatic** — tune the
  `.scaleEffect(isHovered ? 1.06 : 1.0)` factor + spring
- **Trash chip hard to find** — make it more prominent in
  `LandingFarmView.trashHint` (icon + count badge style)
- **Sage's default tagline could be warmer** — update
  `companionState.seedDefaultIfEmpty` copy

---

## 3. Anti-patterns (DO NOT do these)

Per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`:

- **DO NOT** add or restore the `application-groups` entitlement — it
  was stripped intentionally for free-tier signing (TEMP-FREE-TIER §4.5)
- **DO NOT** write any `Process()`, `NSTask`, `posix_spawn`,
  `Command::new` in the active surface — Pro-only and gated
- **DO NOT** create a new XPC service target in `project.pbxproj` —
  needs paid Developer Team for cross-target signing; deferred until
  paid team
- **DO NOT** add Pro-tier commands (`/run`, `/shell`, `/kill`,
  `/execute`) to `HermesCommandDispatcher.parseCore` — they stay
  registry-only with `tier: .pro`
- **DO NOT** create a parallel Sovereign Gate, AgentEvent enum,
  agent loop, skill registry, or LocalAuthentication caller — single
  canonical owners per `COGNITIVE_KERNEL_DOCTRINE` §1
- **DO NOT** add per-command UI code without either a GenUIDispatcher
  migration OR a `GENUI-DEFER:` comment + row in
  `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §9 deferral list
- **DO NOT** silently delete Pro-only stubs you find — those preserve
  optionality per §6 of MAS_FIRST_FOCUS_DOCTRINE; PRs to remove Pro
  require explicit user sign-off
- **DO NOT** start the GenUI dispatcher (Phases G.1-G.6) — that's
  T0 sub-track 4 substrate-foundational work, NOT hackathon scope
- **DO NOT** start the Cognitive Kernel sprint (Phases 1-7) or
  Cognitive DAG (Phase 8) — both deferred until after hackathon
- **DO NOT** modify the doctrine docs in `docs/fusion/*_2026_05_03.md`
  — they're canonical; if you find drift, log to
  `CANON_GAPS_AND_ADDENDA_2026_05_02.md` instead

---

## 4. Polish slate (do if time after §1 + §2)

Pure visual / copy refinements. Each ≤ 15 min. Pick the ones that
land cleanest.

- **Hermes terminal opening transition** — currently jumps in; could
  scale-in from 0.96 with a damped spring matching the sigil entrance
- **Companion creation success toast** — brief "Created Sage" inline
  flash on Farm header after wizard closes
- **Sigil colors per active companion** — when a companion is active,
  the Hermes sigil could borrow that companion's accent
- **Persona prompt preview** — show the first ~80 chars of
  `personaPrompt` on hover-tooltip over the companion in the Farm
- **`/calc` answer formatted in green** — special-case
  `.systemResponse` for calc results to use a "success green"
- **Empty Farm state copy** — currently says "No companions yet" +
  "Create your first one"; could read more invitingly ("Your first
  companion is one click away")
- **Reduce-motion micro-copy** — when reduce-motion is ON, the "idle"
  badge could read "(static)" so users on reduce-motion know it's
  intentional, not a bug

---

## 5. Acceptance bar (when you're done)

The hackathon demo is shippable when:

```
[ ] xcodebuild -scheme Epistemos green
[ ] xcodebuild -scheme Epistemos-AppStore green
[ ] cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build green
[ ] All §1.2 doctrinal greps return zero (or only-ALLOWED hits)
[ ] All H1-H18 Hermes loop steps pass (§1.3)
[ ] All S1-S18 Simulation loop steps pass (§1.4)
[ ] One row appended to CANON_GAPS_AND_ADDENDA_2026_05_02.md per
    deferred fix from §2 (so user knows what didn't make it)
[ ] grep -rn 'TEMP-FREE-TIER' returns the expected ~3-4 hits, no more
[ ] No new files created outside Epistemos/Views/Landing/{Hermes,Farm}/,
    Epistemos/State/Companion/, Epistemos/Models/Companion/, OR
    Epistemos/Engine/ unless absolutely necessary (and if so, the
    reason is in the commit message)
```

When all checked, append one line to
`CANON_GAPS_AND_ADDENDA_2026_05_02.md`:

```
2026-05-XX — Codex hackathon final check complete. Hermes T5 + Simulation T6
demo-shippable. Pro work + GenUI dispatcher + Cognitive Kernel/DAG remain
deferred per MAS-First Focus Doctrine. <N> issues fixed, <M> deferred to
post-hackathon.
```

Then reply: **"HACKATHON FINAL CHECK COMPLETE — DEMO READY"**

---

## 6. Out of scope for this pass (do NOT touch)

- Cognitive Kernel doctrine sprint (Phases 1-7) — paused
- Cognitive DAG doctrine (Phase 8) — paused
- XPC Mastery doctrine (Phases X.1-X.5) — paused
- Schema-First GenUI dispatcher (Phases G.1-G.6) — paused
- Hermes-in-Rust kernel module — paused
- WASM exec via wasmtime — paused
- In-process bundled MCP refactor — paused
- LSP migration to in-process Rust — paused
- Pro-tier feature work of any kind — deferred
- Hermes XPC service target — needs paid Developer Team
- Notes view integration of NotesSidebarSkin — separate slice
- Graph Live Theater (third Simulation placement) — separate slice
- AgentEvent → ambient label translation — separate slice

If user asks about any of the above DURING this pass, redirect: "Part
of the plan, not on the critical path right now — final check is
hackathon-only." Then continue.

---

## 7. Cross-references

```
docs/fusion/CODEX_HACKATHON_FINAL_CHECK_2026_05_03.md   ← this doc
docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md       (active surface + Pro deferral)
docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md       (GENUI-DEFER discipline)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md       (T5 + T6)
docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md         (where deferrals + drift get logged)
CLAUDE.md                                                 (NON-NEGOTIABLE constraints)

Epistemos/Views/Landing/Hermes/   ← Hermes Expert Mode (8 files)
Epistemos/Views/Landing/Farm/     ← Companion Farm (5 files)
Epistemos/State/Companion/        ← CompanionState
Epistemos/Models/Companion/       ← CompanionModel
Epistemos/Engine/DeterministicPRNG.swift  ← Invariant I-13
Epistemos/Sovereign/SovereignGate.swift   ← canonical (DO NOT duplicate)
Epistemos/Models/Artifact.swift           ← partial schema-first GenUI seed
Epistemos/Views/Chat/ArtifactBlockView.swift  ← canonical artifact renderer
```

Build it. Verify it. Don't chase Pro. Don't chase substrate. Just make
the hackathon demo land cleanly inside the canonical lines.
