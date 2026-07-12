# Goose Phase 0 — Status Audit (Codex handoff vs proof gate)

> 🔴 **SUPERSEDED 2026-07-02 (OpenChamber pivot) — DO NOT BUILD FROM THIS.** This is a phase artifact of the DEAD "reskin Goose's WebView as the agent surface" program. current surfaces are Experimental/1Code + MAS/June; OpenChamber/ProAgent are deletion targets; goose = one engine. Historical reference only. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> 🛑 **SUPERSEDED 2026-06-29:** §7 is GREEN-LIT; Plan 1 is ON Phase 1. **IGNORE** the "DO NOT start Agent until §7
> sign-off / Phase 0 NOT signed" instructions below — historical. Option 1: native = frame + Models picker only;
> chat + all features stay WebView, reskinned. Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md`.

**Date:** 2026-06-27
**Branch:** `feat/goose-surface`
**Auditor:** Phase 0 completion audit + 2026-06-27 live proof checkpoint
**Build authority for Phase 1+:** `GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md` (hybrid-by-route) — **blocked until this gate passes**

---

## Verdict

Codex delivered a **real Phase 0 scaffold** (~12 Swift modules, unit tests on mock ACP, build-for-testing green). The 2026-06-27 hardening slices closed the original live transport/WebView/Electron fallback proof holes, the top native file/dialog/external-URL affordances, the read-only custom ACP minimum, typed/unit-proven provider-settings read ACP, live provider config save/read/delete ACP, live settings mutation ACP, live provider authenticate fail-closed rejection for non-OAuth providers, live Skills source-list/export ACP for project and built-in skills, live isolated project Skill source create/update/delete/import ACP, live read-only WebView route smoke for providers/settings/extensions/skills, structured unhandled-ACP diagnostics, and golden F1-F5 ACP fixtures, but **Phase 0 is still NOT signed off** because full parity/"nothing lost vs real Goose", owner/browser-mediated OAuth provider authenticate success, remaining provider/settings parity, remaining long-tail shims, MAS/manual/distribution WRV, and owner sign-off remain open.

| Layer | ~Complete |
|-------|-----------|
| Architecture / code shape | ~90% |
| Owner §7 proof gate | ~96% |

**Not ready** for hybrid AppKit Phase 1, Paseo §15, or `Epistemos/Agent/*`.

The previous "Done" conflated **scaffold + compile + session PNGs** with the **live proof gate** in `SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` §7. The current checkpoint replaces that gap with real runtime evidence, but it does not close the full Phase 0 parity gate.

---

## Proof gate (owner prompt) — current status

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Real Goose Electron as in-app comparison fallback | **PASS** — Pro menu wires a Swift launcher for real Goose Electron; launcher keeps Electron Forge stdin open, live test launches via Hermit pnpm/CDP, sees a renderer page, and cleans the process tree |
| 2 | `goose serve` ACP WebSocket reachable | **PASS** — Swift live test reaches `/health`, connects `/acp?token=...`, and initializes ACP |
| 3 | new → prompt → stream → permission → result | **PARTIAL** — live Swift ACP creates a session, prompts, receives streamed answer/tool events where emitted, routes permission, and receives tool result; live provider did not emit `agent_thought_chunk`, covered by deterministic codec/client tests only |
| 4 | Staged Web UI boots via narrow shim | **PASS** — staged ACP-mode Web UI boots in macOS WebPage through `epistemos-goose://`, with shim/ACP config/permission bridge/native affordance bridge evidence |
| 5 | Nothing lost vs real Goose | **FAIL** — read-only `_goose/unstable/*` providers/extensions/preferences/defaults/session-info/diagnostics plus Skills source-list/export for project/built-in skills are live-proven, project Skill source create/update/delete/import is live-proven in an isolated project, provider supported-model/config-read/config-status ACP is typed/unit-proven, provider config save/read/delete is live-proven, settings preference save/read/remove plus defaults-save are live-proven, provider authenticate non-OAuth rejection is live-proven without config mutation, read-only WebView routes for providers/settings/extensions/skills are live-smoke proven, unsupported custom requests now return structured diagnostics, and F1-F5 ACP fixtures are pinned, but remaining long-tail shims, owner/browser-mediated OAuth authenticate success, remaining provider/settings parity, MAS/manual/distribution WRV, and manual owner sign-off remain open |

---

## 2026-06-27 live proof artifacts

- `/tmp/epistemos-goose-electron-fallback.log` — original standalone baseline: real Goose Electron launched from `.research-clones/work/goose/ui` with Hermit `pnpm --filter goose-app run start-gui`; CDP `json/version` and page list reachable; process group cleaned up.
- `/tmp/epistemos-goose-phase0-electron-launcher.log` — current in-app path: Swift `GooseElectronFallbackLauncher` uses the Pro menu launcher contract, holds stdin open for Electron Forge, reaches CDP `json/version`, sees one renderer page, and stops/cleans the process tree.
- `/tmp/epistemos-goose-phase0-electron-launcher-progress.log` — launcher progress: CDP version ready on debug port `9330`, page list reached, fallback process cleaned.
- `/tmp/epistemos-goose-phase0-acp-initialize.log` — `phase0_live_acp_initialize=pass`, base `http://127.0.0.1:3284`, redacted ACP WS URL, protocol version 1, agent identity.
- `/tmp/epistemos-goose-phase0-acp-prompt.log` — `phase0_live_acp_prompt=pass`, live session, `stop_reason=end_turn`, non-empty agent message stream.
- `/tmp/epistemos-goose-phase0-acp-permission.log` — `phase0_live_acp_permission=pass`, `GOOSE_MODE=approve`, permission request, `allow_once`, tool call, and terminal tool result.
- `/tmp/epistemos-goose-phase0-acp-custom-readonly.log` — `phase0_live_acp_custom_readonly=pass`, live session, 65 provider entries, 15 config extensions, preferences/defaults present, session info echo, diagnostics object report, 7 project skill sources, 1 built-in skill source, type checks true for both source lists, and live project Skill export returned `Epistemos Release Audit.skill.json` with 6,630 chars of valid JSON.
- `/tmp/epistemos-goose-phase0-provider-config-mutation.log` — `phase0_live_provider_config_mutation=pass`; isolated `HOME`, file-backed secrets (`GOOSE_DISABLE_KEYRING=true`), live `azure_openai` config save/read/delete over ACP; status moved `false -> true -> false`.
- `/tmp/epistemos-goose-phase0-settings-mutation.log` — `phase0_live_settings_mutation=pass`; isolated `HOME`, file-backed secrets, live preference save/read/remove for `gooseThinkingEffort` + `autoCompactThreshold`, live defaults-save against a disposable configured provider, and provider config cleanup completed.
- `/tmp/epistemos-goose-phase0-provider-authenticate-rejection.log` — `phase0_live_provider_authenticate_rejection=pass`; isolated `HOME`, file-backed secrets, live `azure_openai` `_goose/unstable/providers/config/authenticate` rejection preserved JSON-RPC `-32602` error data (`Provider does not support native authentication`) and kept config status `false -> false`.
- `/tmp/epistemos-goose-phase0-source-mutation.log` — `phase0_live_source_mutation=pass`; isolated temp project, live project Skill source create/update/export/delete/import/cleanup over ACP, writable Skill source returned, exported JSON valid, one imported source cleaned up.
- `/tmp/epistemos-goose-phase0-webview-boot.log` — `phase0_live_webview_boot=pass`, staged Web UI URL, `ready_state=complete`, React root mounted, `window.electron`, `window.epistemos.goose`, ACP config, permission bridge, native affordance bridge, `directoryChooser`, `openExternal`, secret bridge, and runtime ACP URL match.
- `/tmp/epistemos-goose-phase0-webview-route-smoke.log` — `phase0_live_webview_route_smoke=pass`; real staged Goose Web UI navigated in WebView against live `goose serve` to `/configure-providers`, `/settings?section=models`, `/extensions`, `/apps`, `/schedules`, `/recipes`, `/sessions`, and `/skills`; provider catalog picker used `_goose/unstable/providers/catalog/list`, Apps rendered `Apps` plus `Import App`/`No apps available`, Session History rendered `Session History` plus `CHATS` and observed `session/list`, and the staged script was `./assets/index-DDJFnyeu.js`.
- `EpistemosTests/Fixtures/GooseACP/F1_initialize.json` through `F5_custom_readonly.json` — sanitized live-captured golden ACP fixtures for initialize, session/new, prompt answer stream, permission/tool result, and read-only custom ACP.
- `scripts/generate-goose-acp-fixtures.mjs` — pinned generator that launches local `goose serve`, records ACP over WebSocket, normalizes volatile session/tool/request ids and repo paths, and stores the current Goose revision in fixture metadata.
- Cleanup verified after live tests: no listener on TCP `3284`; no `xcodebuild`, `xctest`, `goose`, `swiftc`, or `swift-frontend` process left from the run.
- Build/test checkpoint: `xcodebuild ... build-for-testing` passed after adding Skills source create/update/delete/import ACP proof; focused Goose ACP codec/client/event-bridge/golden-fixture/shim/native-affordance/runtime suites passed 44/44; `GooseACPClientTests` passed 10/10; live `GooseSourceMutationLiveIntegrationTests` passed 1/1 and live `GooseLiveIntegrationTests` passed 6/6 against real `goose serve`; retained same-day proof remains: `GooseProviderMutationLiveIntegrationTests` 2/2, `GooseSettingsMutationLiveIntegrationTests` 1/1, `GooseWebRouteLiveIntegrationTests` 1/1, golden fixture suite 4/4, and runtime/resolver/staging/Electron-launcher suites green.

### 2026-06-28 owner-visible route repair

- Pre-repair manual testing showed exactly the owner-reported breakage: Apps,
  Session History, and model/provider surfaces could fail even while the
  details panel showed a live runtime. A stale staged artifact under app
  support and provider inventory-first behavior were the relevant Phase 0
  failure modes.
- Current staged artifacts must contain `shared-getAcpClient-provider-inventory`
  and `local-acp-config-GOOSE_TELEMETRY_ENABLED`. `createEpistemosGooseACPClient`
  is no longer the accepted bridge marker.
- Provider UI is now catalog-first and avoids the heavy provider inventory call
  unless catalog loading fails, so settings/default/config reads are not starved
  on the shared ACP client.
- Manual debug-app verification showed the corrected details labels:
  `native ACP Goose ready (1.39.0)` and `custom ACP Goose ready`.
- Fresh route proof:
  `build/xcode-results/2026-06-28-goose-web-route-live-no-background-inventory.xcresult`.
  The owner should retest Apps, Session History, Settings -> Models,
  Providers/Add Provider, Recipes, Scheduler, Extensions, and Skills. Provider-
  specific model errors can still occur when a provider such as LM Studio is not
  configured or running; that is not an ACP WebSocket failure.

---

## What Codex did ship (keep)

- `GooseRuntimeSupervisor` — spawn, env hardening, health, token encoding
- `GooseACPClient` / `GooseACPProtocol` — standard ACP
- `GooseWebSurfaceView` + `GooseWebBootShim` (69-key ledger)
- Native permission + elicitation panels + bridge
- Native file/dialog/external URL affordance bridge for `directoryChooser`, `showOpenDialog`, `showSaveDialog`, `selectFileOrDirectory`, `selectImportSessionFile`, `openExternal`, `openInChrome`, and `openDirectoryInExplorer`
- Read-only custom ACP subset for providers, config extensions, preferences, defaults, session info, diagnostics, Skills source-list discovery for project/built-in skills, and project Skill source export
- Provider-settings read ACP for supported models, config field reads, and configured-status reads; provider config save/delete ACP live-proven in an isolated home; settings preference/defaults mutation live-proven; provider authenticate non-OAuth rejection live-proven with preserved error data; Skills source-list/export and project Skill source create/update/delete/import ACP live-proven; owner/browser-mediated OAuth success and remaining provider/settings parity still open
- Staged Goose Web UI ACP provider overlay plus live route smoke for provider inventory, models settings, extensions, and skills routes
- Structured unhandled custom ACP diagnostics plus JSON-RPC method-not-found replies instead of silent drops
- Golden ACP F1-F5 fixture pack plus generator and decoder/shape tests
- Real Goose Electron fallback launcher with sanitized environment, held-open stdin for Electron Forge, CDP proof, and process-tree cleanup
- Menu entry ⌘3, MAS honest Pro gate
- Unit tests (mock transport)

---

## Hardening backlog (before any new features)

1. Finish extended ACP beyond the live-proven read-only subset, typed provider-settings reads, provider config save/delete, settings mutation, provider-authenticate rejection, Skills source-list/export, project Skill source create/update/delete/import, and read-only route smoke: owner/browser-mediated OAuth authenticate success, deeper provider/settings parity, or honest blocked UI where not yet wired.
2. Use the surfaced unhandled-ACP diagnostics to close any remaining dropped custom-method paths; do not return to silent drops.
3. Finish or honestly block remaining long-tail shims (`showMessageBox`, file read/write, app launch/refresh/close, notification settings, binary path, directory ensure).
4. Add a fresh-machine staging/health note so `GooseWebUI` availability is not tribal knowledge.
5. Re-run MAS honest gate, manual WRV, distribution checks, and owner sign-off on follow-on plan §6 checklist.

---

## Building agent paste block

```
GOOSE PHASE 0 — LIVE TRANSPORT/WEBVIEW/ELECTRON FALLBACK + TOP NATIVE AFFORDANCES + READ-ONLY CUSTOM ACP + SKILLS SOURCE LIST/EXPORT/MUTATION + PROVIDER ROUTE SMOKE + PROVIDER CONFIG/SETTINGS MUTATION + PROVIDER AUTH REJECTION + GOLDEN F1-F5 PROVEN, NOT SIGNED OFF

DO NOT start Epistemos/Agent/* or hybrid AppKit Phase 1 until owner signs §7 proof gate.

NEXT ORDER: (1) OAuth provider auth success and deeper provider/settings parity or honest blocked UI,
(2) remaining long-tail shim audit, (3) fresh-machine staging/health note,
(4) MAS/manual/distribution WRV, (5) owner sign-off.

FORBIDDEN: Phase 1 Agent module, Paseo §15, marking complete from build-green
or live ACP/WebView/Electron fallback proof alone.

Canon: SURFACE §7, GOOSE_AGENT_APPKIT_FOLLOWON_PLAN §4–§6.
Full audit: docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md
```

---

*Audit detail: agent transcript Phase 0 completion audit 2026-06-27.*
