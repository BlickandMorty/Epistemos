# DEEP PLAN AUDIT — Research Hub (READ-FIRST) — 2026-06-19

> **MASTER-LOOP READ-FIRST MANDATE (owner 2026-06-19):** before ANY editing or
> building, the loop MUST read this hub AND every research doc indexed below. The owner:
> *"it must read all research before editing and building."* Research is deliberate and
> continuous; build on top of it, never ahead of it.

**Why this exists (owner 2026-06-19, verbatim intent):** run a continuous deep-research
loop over the ENTIRE plan to make sure there are NO issues — nuanced things like the
Hermes/Osaurus overlap, OpenClaw, the best proven reskin approach, how to handle the
SETTINGS of each cloned thing (e.g. OpenClaw) and give it a deep Epistemos revamp; go
through ALL current app parts that can be researched for what's to come, and ALL the
plan/prompt/ledgers/directives. Do as much Hermes + OpenClaw + Osaurus research as
possible. Find where the app should STOP reinventing and just USE the proven LOGIC from
the cloned ones. Things have been BROKEN — make sure it's all fixed, explicitly debugged,
and pruned of unnecessary things. Make the chats truly engage with the app's skills/tools
(all working). Target: an AI-native note-taking app that SUPERSEDES Obsidian-fused-with-
Codex / Claude-desktop / its-own-terminal, Tolaria, Notion CLI, etc. — deeply integrated.

## Index of ALL research docs (read every one before building)
- `docs/research/HERMES_ACT_FUSION_MAP_2026_06_19.md` — Hermes capabilities → seams.
- `docs/research/OSAURUS_ACT_CONNECTION_MAP_2026_06_19.md` — Osaurus as Act engine.
- `docs/research/OPENCLAW_UI_EMBED_MAP_2026_06_19.md` — OpenClaw WebKit-host plan.
- `docs/research/HERMES_OSAURUS_OVERLAP_AND_DESTINATION_2026_06_19.md` — the 4-item
  Hermes lift, no Osaurus overlap, in-process destination.
- `docs/RESEARCH_CUA_2026_06_18.md` — trycua/cua computer-use verdict.
- `docs/research/RESKIN_PLAYBOOK_2026_06_19.md` — (S2) pixel-art reskin across SwiftUI + WebKit; consolidation not new system.
- `docs/research/COMPETITOR_SUPERSESSION_2026_06_19.md` — (S5) gaps vs Obsidian/Claude/Codex/Tolaria/Notion + killer differentiators.
- (Appended as the loop produces them — keep this index complete.)

## Research-slice backlog (the loop works these; mark status each pass)
| # | Slice | Status |
|---|---|---|
| S1 | STOP-REINVENTING audit — where Epistemos hand-rolls what Osaurus/Hermes/OpenClaw/Goose already do better → switch to their proven logic | ☐ in progress |
| S2 | Best PROVEN reskin approach (pixel-art revamp) across native + WebKit-hosted surfaces | ✅ done → RESKIN_PLAYBOOK |
| S3 | SETTINGS revamp per cloned thing (OpenClaw, Osaurus, Goose) → deep Epistemos revamp; one coherent settings model | ☐ |
| S4 | CHAT ↔ skills/tools end-to-end integration audit + BROKEN-things debug + PRUNE unnecessary | ☐ in progress |
| S5 | COMPETITOR SUPERSESSION — Obsidian, Claude-desktop, Codex/terminal-integrated, Tolaria, Notion CLI → feature gaps to beat them | ✅ done → COMPETITOR_SUPERSESSION |
| S6 | WHOLE-APP forward audit — current parts researched for "what's to come" | ☐ |
| S7 | PLAN/LEDGER/DIRECTIVE consistency sweep — contradictions, gaps, dead items | ☐ |
| S8 | OpenClaw + Osaurus + Hermes deeper passes (continuing) — nuance, edge cases | ☐ |

## FINDINGS LOG (appended each research pass — newest at bottom)

**Pass 1 (2026-06-19):**
- **S2 RESKIN** → the reskin is a CONSOLIDATION, not a new system: `EpistemosTheme.resolved` is the one token source; `EpdocEditorThemeStyle.applyScript` is the proven WebKit CSS-injection precedent. Missing pieces: a `PixelSkinTokens` group (border/corner=0/shadow/image-rendering/pixel-font), hoisting `pixelPanel` out of Landing + making it theme-UNCONDITIONAL, generalizing the injector to `EpistemosWebTheme.applyScript(for:namespace:)`, a static `pixel-theme.css` per web surface. No `image-rendering:pixelated` exists yet; avoid the self-stamping DEMO fonts. Full: RESKIN_PLAYBOOK.
- **S5 COMPETITORS** → Epistemos LEADS on architecture (in-process MLX/no-sidecar, provenance/Eidos, native computer-use substrate, in-process PDF→md) but is BEHIND on shipped-working execution (the agent tool-loop is REOPENED-broken = the #1 blocker) and has true GAPS: web-clipper, voice, sync, working canvas, MCP-install UX. Anti-Tolaria move: expose the vault over MCP + an AGENTS.md convention while keeping the in-process brain as default. Moat = local-agent-over-YOUR-vault + honest provenance + three-engine fusion. Full: COMPETITOR_SUPERSESSION.
- (S1 stop-reinventing + S4 chat↔tools/debug/prune still running.)
