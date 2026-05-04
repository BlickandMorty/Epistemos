# Round 88 Checkpoint — Canonical Recovery, Hermes Brand, and T6 Specificity

## Status

Partial recovery checkpoint, clean to hand off.

This round did **not** complete the full
`CODEX_RECOVERY_HANDOFF_2026_05_04.md` acceptance bar, so do not claim
`RECOVERY PUSH COMPLETE — CANON RESTORED` yet. Stage B.1 Hermes-in-Rust remains
the next recovery-stage implementation.

## Completed

- Canon specificity drift was corrected for T6 Companion Farm / Simulation Mode.
- A durable specificity-recovery rule was added so every future phase/wave
  searches local docs and research roots before coding.
- Hermes Expert Mode Stage A.4 priority-2 renderer migration was completed:
  rich command output now routes through typed `GenUIPayload` instead of
  legacy `Artifact` markdown/YAML blocks.
- Hermes brand Stage E.0.1-E.0.4 was completed enough for build:
  `HermesBrand`, bundled Inter/JetBrains Mono fonts, and a native SwiftUI
  Canvas caduceus replaced the placeholder SF Symbol sigil.

## Verification

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Result: `BUILD SUCCEEDED`.

```bash
rg -n '\.artifact\(Artifact\(' Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift
```

Result: no matches.

```bash
rg -n 'figure\.stand\.dress|systemImageName' Epistemos/Views/Landing/Hermes
```

Result: no matches.

```bash
rg -n 'HERMES-BRAND-STUB' Epistemos/Views/Landing/Hermes
```

Result: no matches.

```bash
rg -n 'Specificity recovery|Tamagotchi-style companion creatures|deterministic Landing Farm roaming|Graph companion presence|animated walking sprites|24 emotes|50 Tamagotchi sprites' docs/fusion
```

Result: expected hits in the master index, track register, recovery plan, fleet
prompt, all-docs index, and canon-completeness audit.

## Files Changed In This Round

Code:

- `Epistemos/Theme/EpistemosFont.swift`
- `Epistemos/Views/Landing/Hermes/HermesBrand.swift`
- `Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift`
- `Epistemos/Views/Landing/Hermes/HermesExpertModeToggleChip.swift`
- `Epistemos/Views/Landing/Hermes/HermesExpertModeView.swift`
- `Epistemos/Views/Landing/Hermes/HermesShimmeringSigil.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/Views/Landing/LiquidGreeting.swift`
- `Epistemos/Resources/Fonts/Inter-Regular.ttf`
- `Epistemos/Resources/Fonts/Inter-SemiBold.ttf`
- `Epistemos/Resources/Fonts/JetBrainsMono-Regular.ttf`

Canon / fleet:

- `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md`
- `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`
- `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`
- `docs/fusion/CANON_COMPLETENESS_AUDIT_2026_05_04.md`
- `docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`

## Next Safe Pickup

1. Start Stage B.1 from `CODEX_RECOVERY_HANDOFF_2026_05_04.md`: Hermes-in-Rust,
   using the user's canonical Hermes parity plan and current in-tree surfaces.
2. Before any T6 implementation, read
   `docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`.
3. First T6 implementation slice should create the native
   `CompanionAvatarGlyph` / `CompanionAvatarGrammar` Canvas body renderer and
   migrate `CompanionView` away from SF Symbols. Do not touch protected graph
   internals for graph companion presence without a dedicated deliberation.
