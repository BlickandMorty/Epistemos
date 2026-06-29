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
> list). #1 and #7 verified + grafted in this pass; the rest tracked.
