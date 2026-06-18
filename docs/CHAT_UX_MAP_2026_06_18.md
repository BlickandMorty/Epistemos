# CHAT UX MAP (2026-06-18) — P7.4a

The simplest coherent model of the whole chat UX, so nothing collides and there's
no black box. This **gates OpenCode (P7.4)** and makes the **cowork fusion (P7.6)**
coherent. Grounded in the real code paths (ChatCoordinator, PipelineService,
`InferenceState.effectiveChatSurfaceSelection`, `ChatToolTier`,
`OverseerComplexityRouter`, `AgentToolTogglePanel`).

## The three orthogonal axes (this is the whole UX)

Everything is one of THREE independent choices. Keep them separate and there are
no collisions.

### Axis 1 — MODE: *how hard does it work?* (Chat vs Act)
- **Chat** = conversational. Answers now; may call **read/search** tools a few
  steps if the question needs the vault (bounded). Today: operating modes
  Fast/Think/Code on the `localOnly` / `overseerLocalExecution` routes with the
  small per-turn tool budget (`cloudToolBudget`: Fast=5, Think=10, Code=15 turns).
- **Act** = the real multi-step **agent loop** — plans, uses the full tool surface
  (tools/memory/skills via `executionPlan`), shows progress, can create/modify
  files. Today: operating mode `.agent` / the `managedAgentSession` route.
- This is the **ACT vs CHAT toggle** the owner wants (P7.6). It maps to the
  existing `operatingMode` (`.agent` = Act; the tier modes = Chat). The toggle is
  a *presentation* of that, not a new engine.

### Axis 2 — MODEL TIER: *which brain?* (Fast / Think / Code, + cloud, + Apple)
- **Fast** = Gemma 4, sized per query (E2B→E4B→12B by complexity, P1.5).
- **Think** = VibeThinker-3B (reasoning).
- **Code** = Gemma 4 12B coder.
- **Cloud** = a toggle / per-send route to a configured cloud model (GPT/Claude/…).
- **Apple Intelligence** = the native on-device Apple route (P1.7), not cloud.
- The tier is the **brain**, chosen in the picker. It is independent of the mode:
  you can run **Chat on Code** or **Act on Fast**. (The capability ceiling, P7.1,
  still bounds what each *tier* can touch; the *mode* decides how many steps.)

### Axis 3 — SURFACE: *where am I typing?* (Main / Mini / Note / Graph / cowork)
- **Main chat** — the full composer (ChatInputBar): picker + tool/skill panel +
  memory blocker + Fast-effort + cloud route.
- **Mini chat** — floating window; now at parity (P7.5) via shared logic.
- **Note chat** — the per-note ask bar; lightweight, **escalates to Main** for tool
  work (honest per-surface).
- **Graph chat** — routes its request **into Main** (`routeGraphChatRequestIntoMainChat`).
- **cowork** (P7.6, new) — a Main-chat *layout* that adds the Act-mode panels
  (Progress / Working folder / Context / Queue / Connectors). Same engine, richer
  presentation.
- All surfaces share **one capability path** (`InferenceState` + `ChatCoordinator`/
  `PipelineService`). Parity is by sharing, not forking (locked by
  `ChatSurfaceParitySourceGuardTests`).

## How tools / skills / memory / connectors compose (per mode)

| Capability | Chat mode | Act mode | Where it lives |
|---|---|---|---|
| Vault/memory **search** (read) | ✅ (auto-inlined + read tools, bounded) | ✅ (full) | `resolveNotesContext` + chatLite tools |
| Vault **write** / file edit | ❌ (read-only ceiling) | ✅ gated by approval | chatPro/agent tools |
| **Skills** (run `/skill`) | ✅ | ✅ | slash menu + `AgentToolTogglePanel` |
| **Tool toggles** (user on/off) | ✅ gates the plan | ✅ gates the plan | `executionPlanGatedByUserToolToggles` (P2.1) |
| **MCP** servers/connectors | (read URL servers forwarded) | ✅ + connectors UI | `MCPUrlServerDirectory` (P2.3) → P7.6 connectors |
| **Shell / git / terminal** | ❌ (never on MAS) | ✅ **Pro only** | `mas_forbidden` + `pro-build` (P7.1, cargo-locked) |
| Progress / working-folder / context panels | (not shown) | ✅ from real agent-loop telemetry | P7.6 |

The **absolute MAS limit** (no shell/git/process) holds in **every** mode and tier
— it's build-gated (`not(feature="pro-build")`), not mode/tier-gated (P7.1). So
"Act" on the MAS build is powerful (read/search/write-with-approval/skills/MCP)
but still cannot shell; only the Pro build lifts that.

## Resolving the "Code is overloaded" collision (owner 2026-06-18)

- **"Code" is a MODEL TIER only** (Axis 2: Fast/Think/**Code**). It is NOT a mode.
- **OpenCode** is **not a mode and not a tier** — it is a **deep code/terminal
  CAPABILITY reachable from ACT mode** (Axis 1 = Act) on the Pro/dev build:
  terminal access to on-disk notes/research + the full app skills/tools, security.rs
  hardened. So: *Act mode + (Code or any tier) + Pro build → OpenCode-grade depth.*
- There is **no second "Code" button**. The user picks the **Code tier** for a
  coding brain, flips **Act** for multi-step, and on Pro that unlocks the deep
  terminal/code capability. One coherent path, zero collisions.

## What this unblocks (build order)

1. **P7.6 cowork** = Main surface + the Act-mode panels (Progress/Working-folder/
   Context/Queue/Connectors), driven by the **real** agent-loop telemetry +
   `AgentCommandCenterState` + MCP. The ACT/CHAT toggle is Axis 1 surfaced.
2. **P7.3 terminal/console** = the Pro-only shell surface (Axis: Act + Pro),
   honest-gated.
3. **P7.4 OpenCode** (LAST) = the deep code/terminal capability from Act mode, Pro/
   dev-gated — built on the same engine, NOT a fork, NOT a new mode.

## North-Star fit

Determinism + verifiability (the Founding Thesis) lives on Axis 2 (the small local
tiers) regardless of mode/surface: grammar/json-schema-constrained generation,
ClaimLedger/AnswerPacket provenance, the Cognitive DAG, the Knowledge Core, and an
explicit "why this route". The cowork panels (Progress/Context) are exactly the
*visible* form of that determinism — they show the real plan, the real tools, the
real files, not a black box.
