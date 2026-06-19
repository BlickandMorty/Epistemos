# SETTINGS REVAMP for cloned engines (OpenClaw · Osaurus · Goose) — S3, 2026-06-19

Read-only research (subagent). Feeds DEEP_PLAN_AUDIT_HUB. How to absorb each clone's
settings into ONE coherent, pixel-art, honest Epistemos model — never a foreign panel.

## Core finding
Epistemos already has the whole pattern to absorb a clone's settings honestly:
`<Engine>GateStatus` (pure, always-compiled, MAS "Pro only") + `<Engine>HealthRow`
(read-only visible surface) + flag gate + `SettingsSurfaceComponents` pixel chrome. The
job is NOT to host any clone's settings panel; it's to map each clone's real knobs into
Epistemos's native controls and HIDE/HARDCODE the rest. **Biggest nuance: OpenClaw ships
a schema-driven config form (`ui/src/ui/views/config-form.*` + `SECTION_META`, ~20
sections auto-generated from a Zod schema) — that foreign settings UI must be HIDDEN
(CSS + don't wire `config.*` bridge methods), never embedded.**

## Disposition inventory (SURFACE = native control · HIDE = real knob, not user-facing · HARDCODE = pinned by doctrine)
**OpenClaw** (`~/Downloads/openclaw-main/src/config/schema.ts`): gateway port/mode → HARDCODE (no Node gateway on MAS); channels (Telegram/Discord/Slack/…) → HIDE/DEFER (Epistemos `ChannelsSettingsView` is the native equiv; don't duplicate); auth/device-auth → HARDCODE (Keychain); models/aliases/fallbacks → SURFACE via existing `ModelStackSettingsView`+`InferenceDetailView`; mcp/mcpServers → SURFACE (consolidated MCP); cron → HIDE; tts/stt/browser/canvas/hooks/logging/env → HIDE/HARDCODE; theme → HARDCODE (overridden by pixel CSS injection). Net: ZERO new panels; only an `OpenClawGatewayHealthRow`.

**Osaurus** (docs.osaurus.ai/configuration): :1337 port → HARDCODE (`LocalModelServer` pins it, shown read-only in `ActOsaurusHealthRow`); models dir → HARDCODE (Epistemos owns storage); MCP → HIDE (consolidated); Containerization VM → SURFACE-as-status-only (Pro/dev-gated executor, honest "Pro · not live"); plugins → HIDE/DEFER (via Epistemos Skills); SQLCipher/Keychain → HARDCODE. Net: existing `ActOsaurusHealthRow` only.

**Goose** (`~/.config/goose/*.yaml`): provider/model → HARDCODE (rides the Epistemos stack); extensions → SURFACE (consolidated MCP); permission_mode/permission.yaml → SURFACE via `AuthoritySettingsView`+`AgentAuthorityStore` (allow/ask/deny is already native); recipes → SURFACE via `SkillsSettingsView` (discovery source); telemetry/auto_update → HARDCODE; secrets → Keychain. Net: existing `WorkBackendHealthRow` only.

## The proven revamp triad (mirror what already ships)
1. **`<Engine>GateStatus.swift`** — nonisolated enum, pure, always-compiled; `#if EPISTEMOS_APP_STORE` → honest "Pro only"; Pro branch reads `EPISTEMOS_<ENGINE>_V0` flag. Templates: `ActOsaurusGateStatus.swift`, `WorkBackendGateStatus.swift`.
2. **`<Engine>HealthRow.swift`** — read-only View; shows live endpoint/path ONLY `if isActive` AND under `#if !EPISTEMOS_APP_STORE`; never a value that isn't real. Templates: `ActOsaurusHealthRow.swift`, `WorkBackendHealthRow.swift`.
3. **Mount in `SubstrateHealthPanel` "Agent Runtime"** (`SubstrateHealthPanel.swift:86-96`), wrapped in `VerifiedFloorChipStrip`/`surface(falsifier:)` so green is witness-earned.
Pixel guarantee: rows render through `SettingsSurfaceComponents` → identical to every Epistemos row. OpenClaw's foreign config-form is hidden by CSS; only the chat surface is reskinned via `EpistemosWebTheme.applyScript(for:namespace:)` + `data-epistemos-skin="pixel"`.

## One coherent IA (clones get NO sidebar section)
Clones are engines-behind-modes (Chat=Epistemos, Act=Osaurus, Work=Goose), already encoded: Act→Osaurus via `ActEngine{openClaw,osaurusLocal}` in `ChatCoordinator`; Work→Goose flag-gated; OpenClaw = UI host + cloud/CLI `AgentBackend` lane, NOT a 3rd Act route. So:
- per-engine STATUS/honesty → consolidates in `SubstrateHealthPanel`→"Agent Runtime".
- model selection/advertising → ONE `ModelStackSettingsView`+`InferenceDetailView` (all engines draw from it — kills each clone's duplicate model config).
- permissions → `AuthoritySettingsView`/`AgentAuthorityStore` (absorbs Goose permission_mode).
- skills/recipes/plugins → `SkillsSettingsView` (absorbs Goose recipes + Osaurus plugins).
- **MCP install → ONE surface** (today scattered across `AgentBlueprintSettingsView`/`AgentControlSettingsView`/`AgentToolTogglePanel`) — **highest-leverage anti-duplication move**; OpenClaw mcpServers, Osaurus /mcp/*, Goose extensions all register through it.
Anti-muddy rule: a clone setting appears in exactly ONE Epistemos home; shared knobs (model, MCP) resolve to the one native control, engine-picker decides the consumer.

## MAS/Pro gating + honesty
Always-compiled both profiles: every GateStatus+HealthRow (MAS sees it exists + "Pro only"). Pro-gated `#if !EPISTEMOS_APP_STORE`: anything touching a port/subprocess/Node gateway/VM/vendored link (sidebar already hides channels/skills/etc. on MAS, reroutes deep-links via `safeDetailSelection`). Honesty invariants: show a toggle/endpoint only when truly armed; `isLive=false` until linked+live; seam THROWS rather than silently routing to cloud (constraint #1); `VerifiedFloorChipStrip` stays orange until a primary witness passes; gate copy states the reason it's off.

## Ordered plan
1. **Consolidate the MCP-install surface** (highest leverage) — one native panel; mirror `SkillsSettingsView` quarantine→promote.
2. Add `OpenClawGateStatus` + `OpenClawGatewayHealthRow` (flag `EPISTEMOS_OPENCLAW_UI_V0`, "Pro · Developer build only", bundle path/size/last-build) in "Agent Runtime".
3. Fold clone model knobs into the one stack (no second picker).
4. Fold Goose permissions → `AuthoritySettingsView`; Goose recipes + Osaurus plugins → `SkillsSettingsView`.
5. Suppress OpenClaw's config-form (scoped pixel CSS + don't wire `config.*` bridge); reskin chat surface only.
6. Pixel-skin native engine rows for free (once `pixelPanel` is hoisted unconditional, RESKIN_PLAYBOOK).
7. Honesty/witness sweep — each engine setting gets a witness wrapper; no green without a passing witness; no shown value unless live.

Key files: `Views/Settings/SettingsView.swift` · `ActOsaurus/ActOsaurusGateStatus.swift` · `Work/WorkBackendGateStatus.swift` · `Views/Settings/{ActOsaurusHealthRow,WorkBackendHealthRow,SubstrateHealthPanel,SettingsSurfaceComponents,ModelStackSettingsView,SkillsSettingsView,ChannelsSettingsView,AuthoritySettingsView}.swift` · `Work/WorkBackend.swift` · `App/ChatCoordinator.swift` · upstream `~/Downloads/openclaw-main/src/config/schema.ts` + `ui/src/ui/views/config-form.render.ts`. Pairs with RESKIN_PLAYBOOK + OPENCLAW_UI_EMBED_MAP + OSAURUS_ACT_CONNECTION_MAP.
