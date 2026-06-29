# Goose Surface — Definitive Missing-Feature Audit (2026-06-28)

Branch: `feat/goose-surface`. Method: ultracode multi-agent audit (10 agents,
638K subagent tokens) over all 42 ungrafted non-test Goose Web UI components that
import the dead `@/api` REST surface, classifying each as a genuine
silently-missing feature vs. a false positive, cross-checked against the live
`@aaif/goose-sdk` ACP methods + `stage-goose-web-ui.sh` grafts + the ACP-wired
`ConfigContext`. **This is the definitive answer to "what is still silently
missing" — the owner's primary feature-completeness gate.**

## Result: 7 genuine gaps, 35 non-gaps

**35 NON-gaps** (NOT missing features): 16 types-only imports; 4 already flow
through the ACP-wired `ConfigContext`/`useConfig`; 7 sit in the dead
`USE_ACP_CHAT===false` branch or are unreachable while the live path is
ACP-routed; 8 are non-ACP native carve-outs (HuggingFace / local-inference
model download+tuning; Nostr/tunnel session sharing) that Epistemos owns natively
or that have no ACP method.

**7 genuine real-gaps** (a live non-type-only `@/api` call reachable under
`USE_ACP_CHAT=true`, not grafted, throws in ACP mode):

| # | Component | Feature | ACP method | Owner-visible | Complexity |
| --- | --- | --- | --- | --- | --- |
| 1 | `McpApps/toolsCache.ts` | Tool list backing MCP-UI apps + tool-call rendering | `toolsList_unstable` | high | **low** |
| 2 | `settings/extensions/modal/ExtensionModal.tsx` | Add/edit extension with secret env vars | `sessionExtensionsAdd_unstable` (secrets travel in ExtensionConfig) | high | medium |
| 3 | `settings/permission/PermissionModal.tsx` | Per-extension tool-permission editor | `toolsList_unstable` (load); **upsertPermissions has NO ACP save** | high | high |
| 4 | `settings/dictation/DictationSettings.tsx` | Dictation provider-status dropdown | `dictationConfig_unstable` | medium | high (audio/native overlap) |
| 5 | `McpApps/McpAppRenderer.tsx` | Interactive MCP-App iframe (read resources, call tools) | `resourcesRead_unstable` + `toolsCall_unstable` (+ goosed-only proxy dep) | medium | high |
| 6 | `settings/PromptsSettingsSection.tsx` | Named prompt-template editor (list/load/save/reset) | **none** (no ACP prompt-template CRUD) | medium | high |
| 7 | `alerts/AlertBox.tsx` | Save edited auto-compact threshold | `preferencesSave` via `ConfigContext.upsert` | low | **low** |

### Recommended action order
- **Clean wins (graftable now, low risk):** #1 toolsCache (high-visibility single-method swap) and #7 AlertBox (trivial reroute through the already-ACP-wired ConfigContext). Verify-then-fix + tsc-validate.
- **Medium:** #2 ExtensionModal (no-op `storeSecret()` in ACP so secrets ride in ExtensionConfig).
- **Owner-decision / high-complexity:** #3 PermissionModal save (no ACP persistence — Task #11), #4 Dictation (graft-vs-native — Task #12), #5 McpAppRenderer (needs the goosed-only `/mcp-app-proxy` + `window.electron` host resolved first), #6 Prompts (no ACP method — implement native or hide in ACP mode).

### Out-of-scope fail-open (documented, not bugs)
`SessionListView` (Nostr/tunnel Share/Import — no ACP equivalent; buttons toast on
click), `SettingsView` (`getTunnelStatus`, `.catch`'d to safe default),
`ToolApprovalButtons` (`confirmToolAction` only on a legacy non-ACP edit-rerun edge).

> Caveat: this is a multi-agent audit; each gap is verify-then-fixed before any
> graft (the same discipline that over-flagged then corrected the earlier 39-item
> list).

## Verify-then-fix corrections to the audit (2026-06-28 PM)

The audit's complexity ratings were optimistic on two gaps; verifying each against
the actual code before grafting corrected them:

- **#7 AlertBox — GRAFTED + tsc-validated (`80de32ab7`).** Genuinely clean: the
  component already used `useConfig()`; rerouted the threshold SAVE through
  `ConfigContext.upsert` (→ preference persistence) and dropped the unused import.
- **#1 toolsCache — GRAFTED (shipped, gate-locked).** Was rated "low / single
  method swap," but it passes `extension_name` for SERVER-side filtering, while ACP
  `toolsList_unstable({sessionId})` returns ALL session tools — so it needs
  client-side `extension__tool` prefix filtering (display-name-vs-registered-name
  casing). Shipped via the `listAcpSessionTools(sessionId, extensionName)` helper
  with a **full-list fallback** (`scoped.length > 0 ? scoped : all`) so a casing
  mismatch can never be WORSE than the silent-null REST path it replaces. Locked by
  7 gate assertions in `stagingGraftsWireLiveParityFeatures`. Live extension-casing
  re-verification still gated by the (blocked) Swift test bundle, but the fallback
  removes the regression risk in the meantime.
- **#3 PermissionModal — LOAD-only graft is a TRAP; both-halves-or-nothing (Path B).**
  The tool-LOAD (`getTools`) IS ACP-graftable via the same `listAcpSessionTools`
  helper. BUT the per-tool SAVE (`upsertPermissions`, PermissionModal.tsx:159) has
  **no ACP method**. Today the modal honestly shows a load-error state (no tools).
  Grafting LOAD alone would make it LOOK functional — show tools, accept permission
  edits — while SAVE silently `console.error`s and discards the change: a NEW silent
  failure, strictly worse for the owner's no-silent-failures gate than the current
  honest error. So PermissionModal is only honest once SAVE works → it is a Path-B
  feature (full REST serves `upsertPermissions`). Do NOT ship the LOAD-only half.
- **#2 ExtensionModal — audit's FIX IS WRONG (deferred).** The audit recommended
  "no-op `storeSecret()` so secrets travel inside ExtensionConfig." But
  `ExtensionConfig` carries `env_keys?: string[]` (KEY references) + `envs?: Envs`
  (NON-secret values); the secret VALUES are stored separately via `storeSecret`
  and referenced by `env_keys`. No-opping `storeSecret` would lose the secret
  values and break any extension with secret env vars. The CORRECT fix is to route
  `storeSecret` through an ACP secret-save path — but it is unverified whether one
  exists for arbitrary extension config secrets (Goose ACP has `providersConfigSave`
  for PROVIDER secrets; extension env secrets may have no ACP home). Needs that ACP
  capability confirmed + a behavioral test before grafting. Do NOT apply the audit's
  no-op approach.

#7 grafted this pass; #1/#2 deferred with corrected analysis; #3–#6 are
owner-decision / high-complexity per the table above.
