# Canon Completeness Audit — 2026-05-04

## Purpose

The user reported that high-specificity feature intent can get compressed away
as the fusion packet evolves. The concrete example was T6: the plan said
"body grammar", but the remembered intent was actual Tamagotchi-style companion
creatures on Landing and Graph, with styleable avatar/SVG shapes and idle
walking/roaming.

This audit makes that class of drift explicit and adds a required recovery pass
for every future phase/wave.

## Scope Scanned

- `docs/fusion/` first, including `MASTER_RESEARCH_INDEX_2026_05_02.md`,
  `SUBSTRATE_TRACK_REGISTER_2026_05_03.md`,
  `CANONICAL_RECOVERY_PLAN_2026_05_03.md`, fleet artifacts, and deliberations.
- Primary research roots discovered under `/Users/jojo/Downloads/`, including
  Kimi, GPT, and Jordan research folders.
- Current code anchors for T6:
  `Epistemos/Views/Landing/Farm/CompanionView.swift`,
  `Epistemos/Views/Landing/Farm/LandingFarmView.swift`, and
  `Epistemos/Views/Graph/`.

## Search Terms Used

`tamagotchi`, `companion`, `farm`, `avatar`, `creature`, `pet`,
`body grammar`, `walk`, `roam`, `wander`, `simulation mode`, `landing farm`,
`graph live theater`, `notes sidebar skin`, `CompanionView`, `Character DNA`,
`Hermes Snake`.

## Findings

- Fusion canon already contained the core T6 concepts: three placements,
  body grammar, pixel-art/Tamagotchi mode, Character DNA, and the fact that
  current code still renders SF Symbols.
- The final plan did not make the user's concrete product sentence prominent
  enough: "small Tamagotchi-like companion creatures visibly roaming Landing
  and later appearing in Graph." That sentence is now patched into the recovery
  plan, track register, and master research index.
- Quick Capture Wave 10 is more specific than the compressed T6 register:
  Pixel mode means animated walking sprites, emotes, color-per-agent, and an
  exit bar of 50 Tamagotchi sprites, 24 emotes, and smooth 60 FPS walking on
  M-series. Tactical mode must be information-equivalent for enterprise.
- The Kimi "where you are" summary preserves the three-placement map as
  Landing Farm, Graph Live Theater, Notes Sidebar, plus a pixel-art mascot
  system at agent leaves. GPT research keeps the shell-level flows but is less
  specific about creature embodiment.
- The Kimi donor implementation is not enough by itself: it mentions/shows
  orb/shard/pulse-style scaffolding, while the canon target is styleable
  native avatar grammar with deterministic roaming and later graph projection.
- The correct implementation order is: native `CompanionView` Canvas/SVG body
  grammar, then Landing Farm roaming, then Graph companion presence via a
  protected graph-specific deliberation.

## Canon Updates Made

- `CANONICAL_RECOVERY_PLAN_2026_05_03.md`: Stage E now includes the
  2026-05-04 Tamagotchi correction plus E.3 Landing roaming and E.4 Graph
  presence planning.
- `SUBSTRATE_TRACK_REGISTER_2026_05_03.md`: T6 now has a specificity lock row.
- `MASTER_RESEARCH_INDEX_2026_05_02.md`: §11 now has a dedicated
  T6 Tamagotchi specificity correction and §22.1 now requires specificity
  recovery before every phase/wave.
- `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`: anti-drift invariant 12 now
  requires concrete-term semantic searches before briefs.

## Durable Rule

Before any future slice, agents must search the user's concrete words and
semantic siblings locally before coding. A compressed doctrine label is not
allowed to erase concrete product intent. If the final plan says "body grammar"
but research/user memory says "Tamagotchi creatures walking on Landing and
Graph", the brief must carry the latter.

## Verification Commands

```bash
rg -n -i "Tamagotchi|specificity recovery|body grammar|roam|wander|CompanionView" docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md
```

## Usefulness

+1 — this prevents future Codex/Claude/Kimi sessions from collapsing the user's
specific T6 artifact intent into a generic "asset renderer" task.
