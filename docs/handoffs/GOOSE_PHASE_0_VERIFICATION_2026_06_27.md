# Goose Phase 0 - Independent Verification

Date: 2026-06-27
Branch: `feat/goose-surface`
Verifier: Codex independent Phase 0 continuation pass
Scope: Phase 0 only. `Epistemos/Agent/*`, hybrid AppKit Phase 1, and Paseo
Section 15 remain forbidden until owner Section 7 sign-off.

## Verdict

Phase 0 is still not signed off.

The fresh verification pass substantially improves the proof state: the app
builds for testing, the generated app-hosted test bundle runs after ad-hoc
signing, real Goose Electron launches as the comparison fallback, `goose serve`
ACP works over loopback, the staged Goose Web UI boots in WebPage/WKWebView,
provider/settings/source mutations pass live, and the broad Phase 0 live slice
passes 13/13 tests.

The release gate still fails because Gate 3 remains partial (`agent_thought_chunk`
was not emitted by the live provider path) and Gate 5 is not complete. Owner/
browser-mediated OAuth success, deeper provider/settings parity, true AppKit
window/modal affordance proof, MAS/manual/distribution WRV, and owner sign-off
remain open.

## Required Sources Read

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md`
  Section 0, Section 2, Section 7, Section 9-C, Section 14, Section 16, and
  Section 17
- `docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md`
  Section 4, Section 5, and Section 6
- `docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md`
- `docs/handoffs/GOOSE_PHASE_0_CONTINUATION_PROMPT_2026_06_27.md`
- `docs/handoffs/GOOSE_PHASE_0_FRESH_MACHINE_STAGING_HEALTH_2026_06_27.md`

## Fresh Verification Matrix

| Gate | Requirement | Fresh result | Evidence |
| --- | --- | --- | --- |
| Build | App build-for-testing | PASS | `build/goose-phase0-verification-2026-06-27/build-for-testing.after-window-affordance-honesty.log`; result `build/xcode-results/2026-06-27-200200-window-affordance-honesty-build.xcresult` |
| Host | App-hosted XCTest runner | PASS | Generated app re-signed with `codesign --force --deep --sign -`; `codesign --verify --deep --strict` passed |
| 1 | Real Goose Electron comparison fallback | PASS | Direct proof `/tmp/epistemos-goose-phase0-direct-electron-fallback.log`; hosted proof `/tmp/epistemos-goose-phase0-electron-launcher.log` |
| 2 | `goose serve` `/health` plus ACP initialization | PASS | `/tmp/epistemos-goose-phase0-direct-acp-catalog.log`; hosted `GooseLiveIntegrationTests` |
| 3 | New session -> prompt -> stream -> permission -> result | PARTIAL | Prompt and permission pass, but both fresh live logs show `saw_agent_thought=false` |
| 4 | Staged Web UI boots through narrow shim | PASS | `/tmp/epistemos-goose-phase0-webview-boot.log`; broad live result 13/13 |
| 5 | Nothing lost vs real Goose | FAIL | Dynamic catalog/settings/source/route evidence exists; OAuth success, deeper parity, true window affordances, MAS/manual/distribution WRV, and owner sign-off remain open |

## Test Evidence

- Build-for-testing PASS:
  `build/goose-phase0-verification-2026-06-27/build-for-testing.after-window-affordance-honesty.log`
- App signature repair PASS:
  `codesign --force --deep --sign - build/goose-phase0-verification-2026-06-27/DerivedData/Build/Products/Debug/Epistemos.app`
  then `codesign --verify --deep --strict --verbose=2 .../Epistemos.app`
- Focused hosted Goose suite PASS, 61 tests / 11 suites:
  `build/goose-phase0-verification-2026-06-27/goose-focused.after-webui-fixture-fix.log`
- Settings live suite PASS, 2/2:
  `build/goose-phase0-verification-2026-06-27/goose-settings-live.after-inventory-fix.log`
- `GooseLiveIntegrationTests` PASS, 7/7:
  `build/goose-phase0-verification-2026-06-27/goose-live-suite.after-window-affordance-honesty.log`;
  result `build/xcode-results/2026-06-27-goose-live-suite-after-window-affordance-honesty.xcresult`
- Broad live verification PASS, 13/13 across `GooseLiveIntegrationTests`,
  `GooseWebRouteLiveIntegrationTests`, `GooseProviderMutationLiveIntegrationTests`,
  `GooseSettingsMutationLiveIntegrationTests`, and
  `GooseSourceMutationLiveIntegrationTests`:
  `build/goose-phase0-verification-2026-06-27/goose-live-verification.after-window-affordance-honesty.log`;
  result `build/xcode-results/2026-06-27-goose-live-verification-after-window-affordance-honesty.xcresult`

The first hosted test attempts appeared to stall because the generated
`CODE_SIGNING_ALLOWED=NO` app bundle failed strict signature verification
(`code has no resources but signature indicates they must be present`). Re-
signing the generated app fixed the hosted runner.

## Notable Fixes From This Pass

- `GooseSurfaceAvailability.current` now lets tests disable bundled Web UI
  candidates, so availability tests prove the staged artifact they intend to
  prove instead of accidentally passing through a bundled candidate.
- The ready Web UI fixture now writes the same ACP marker shape the resolver
  requires, closing a false-positive test gap.
- Provider/settings defaults proof now uses the live provider inventory's
  default or first model, and endpoint-shaped placeholder values for endpoint
  keys. This fixed the live model-defaults persistence proof.
- The WebView native-affordance test no longer opens real AppKit modal/app
  windows under XCTest. It live-proves scoped file edits, recents, recipe trust,
  and the WebView bridge route; `showMessageBox`, `launchApp`, `refreshApp`,
  and `closeApp` are handler-routed and explicitly marked in the proof log.

## 2026-06-28 Route Loading Repair Addendum

The owner-reported failures on Apps, Session History, and model/provider
surfaces were reproducible as stale/fragile staged Goose Web UI behavior, not
as permission to start Phase 1. The repair stayed inside Phase 0 WebView/ACP
staging:

- Preserved the prior checkpoint first: `a4ff19320` (`Stabilize Goose Phase 0
  checkpoint`) after `build-for-testing` passed at
  `build/xcode-results/2026-06-28-phase0-preserve-build-for-testing.xcresult`.
- Re-staged the Goose Web UI instead of trusting the old
  `~/Library/Application Support/Epistemos/GooseWebUI` artifact.
- Replaced the stale provider client marker `createEpistemosGooseACPClient`
  with `shared-getAcpClient-provider-inventory`, proving the provider catalog
  and inventory paths use the shared `getAcpClient()` lane.
- Added the `local-acp-config-GOOSE_TELEMETRY_ENABLED` marker and local ACP
  config handling for app-local settings keys such as telemetry, voice
  dictation, security prompt/classifier settings, and max turns.
- Made provider UI catalog-first. The heavier provider inventory call now runs
  only as a fallback after catalog failure; this avoids starving later
  settings/default/config reads on the shared ACP client.
- Updated the live route smoke helper to dismiss the first-run telemetry prompt
  and to close the marker ACP client deterministically.

Fresh live route smoke passed at
`build/xcode-results/2026-06-28-goose-web-route-live-no-background-inventory.xcresult`
and wrote `/tmp/epistemos-goose-phase0-webview-route-smoke.log`:

```text
phase0_live_webview_route_smoke=pass
goose_web_ui_index_script=./assets/index-DDJFnyeu.js
provider_catalog_picker_acp_methods=_goose/unstable/providers/catalog/list
route=/configure-providers required_hits=Provider Configuration Settings,Add Provider
route=/settings?section=models required_hits=Settings any_hits=Models,Provider,Model
route=/extensions required_acp_methods=_goose/unstable/config/extensions/list
route=/apps required_hits=Apps any_hits=Import App,No apps available
route=/schedules required_acp_methods=_goose/unstable/schedules/list
route=/recipes required_acp_methods=_goose/unstable/recipes/list
route=/sessions required_hits=Session History any_hits=CHATS required_acp_methods=session/list
route=/skills required_acp_methods=_goose/unstable/sources/list
```

Manual debug-app verification on 2026-06-28 also showed the corrected details
language:

```text
native ACP Goose ready (1.39.0)
custom ACP Goose ready
```

The owner should no longer expect Apps or Session History to show generic
"Error Loading" surfaces in this build. A provider-specific model-list error is
still expected when the selected provider itself is not configured or not
running, for example LM Studio without a reachable local server. That is not
the same failure as `ACP WebSocket connection failed`.

## 2026-06-28 Auth/Provider Credentials Repair Addendum

The follow-up owner screenshots showed `Failed to load provider credentials`
on Settings -> Auth and model-picker/provider errors after the first route
repair. That exposed one remaining stale HTTP path in the staged Goose Web UI:
the Auth provider credentials surface was still calling the raw Goose HTTP
client instead of the native/custom ACP bridge.

This pass keeps the repair inside Phase 0:

- `AuthSettingsSection` now lists credentials through ACP
  `providers/config/status`, then reads fields only for configured providers.
  It no longer calls the old raw HTTP provider-secret path in ACP mode.
- Provider model fetches still prefer live Goose ACP
  `providers/model/list`; if the provider endpoint itself rejects or is not
  running, the picker falls back to `known_models` from the Goose ACP provider
  catalog. No Swift/manual provider list was introduced.
- The live route smoke now covers `/settings?section=auth` and explicitly
  forbids `Failed to load provider credentials`.

Fresh focused proof passed at
`build/xcode-results/2026-06-28-goose-web-route-auth-provider-fallback-2.xcresult`
and wrote `/tmp/epistemos-goose-phase0-webview-route-smoke.log`:

```text
phase0_live_webview_route_smoke=pass
provider_markers_source=goose_acp
provider_catalog_picker_acp_methods=_goose/unstable/providers/catalog/list
route=/settings?section=auth required_hits=Settings,Provider Credentials forbidden_hits= required_acp_methods=_goose/unstable/providers/config/status seen_acp_methods=_goose/unstable/providers/config/status
route=/apps required_hits=Apps any_hits=Import App,No apps available forbidden_hits=
route=/sessions required_hits=Session History any_hits=CHATS forbidden_hits= required_acp_methods=session/list seen_acp_methods=session/list
route=/skills required_acp_methods=_goose/unstable/sources/list seen_acp_methods=_goose/unstable/sources/list
```

The patched Web UI was also rebuilt and staged into
`~/Library/Application Support/Epistemos/GooseWebUI` on 2026-06-28 so the
Debug app can load this exact bundle. This still does not sign off Phase 0:
owner/browser-mediated OAuth success, Gate 3 stream-contract resolution, deeper
provider/settings parity, window-affordance proof, MAS/manual/distribution WRV,
and owner sign-off remain open.

One extra Xcode command targeting
`ReleasePackagingHardeningTests/runtimeAssetBundlerStagesGooseOnlyForDirectDistribution`
returned `TEST SUCCEEDED` but selected zero tests, so it is not counted as proof.
The broader release-packaging suite still has unrelated pre-existing red
assertions around SourceMirror/model-manifest expectations and is not closed by
this addendum.

## Fresh Proof Highlights

Direct provider/catalog proof:

```text
phase0_direct_acp_catalog=pass
protocol_version=1
agent_name=Epistemos
agent_version=1.39.0
provider_count=65
provider_model_count=413
setup_provider_count=32
custom_provider_count=106
catalog_digest_sha256=67073642c458d3815c9f8d1837e716f056165283e1c6caed6ac226166e0766f3
```

Fresh hosted prompt proof:

```text
phase0_live_acp_prompt=pass
stop_reason=end_turn
event_count=14
saw_agent_message=true
saw_agent_thought=false
saw_tool_call=false
saw_permission_request=false
```

Fresh hosted permission proof:

```text
phase0_live_acp_permission=pass
goose_mode=approve
event_count=8
saw_agent_message=false
saw_agent_thought=false
saw_tool_call=true
saw_tool_result=true
saw_permission_request=true
selected_permission_option=allow_once
```

Fresh WebView native-affordance proof:

```text
phase0_live_webview_native_affordances=pass
confirm_handler_override=true
mcp_app_handler_override=true
goosehints_write=true
goosehints_read_matches=true
recent_added=true
recent_listed=true
recipe_trust_recorded=true
recipe_trust_after=true
request_native_affordance_bridge=true
errors=
```

Fresh route smoke proof includes provider, settings, extensions, apps,
schedules, recipes, sessions, and skills routes, with required ACP method
observations where those routes require custom Goose ACP.

## Issues Found

| Severity | Issue | Required next action |
| --- | --- | --- |
| P1 | Gate 5 remains failed: owner/browser-mediated OAuth success and deeper provider/settings parity are not complete. | Run the OAuth success path with owner browser interaction, then close remaining deltas or expose honest blocked UI. |
| P1 | Gate 3 remains partial because live Goose did not emit `agent_thought_chunk`. | Produce a live Goose/provider mode that emits the event, or amend the Section 7 requirement with owner approval if Goose no longer emits it on the supported path. |
| P1 | True AppKit `showMessageBox` and MCP app window lifecycle crashed under hosted XCTest in `_NSWindowTransformAnimation dealloc`. | Keep handler-routed WebView proof as limited evidence; add a separate stable manual/UI proof or refactor the window lifecycle before claiming confirm dialogs or MCP apps WORKS. |
| P1 | MAS/manual/distribution WRV remains open. | Re-run MAS honest gate, manual WRV, and release/distribution checks after owner OAuth/parity proof is done. |

Crash reference for the window-affordance issue:
`/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-06-27-195020.ips`.

## Backlog Closure State

1. OAuth provider auth success and deeper provider/settings parity:
   still open. Owner browser interaction is likely required for a true OAuth
   success path.
2. Remaining long-tail shim audit:
   partially closed. Scoped file read/write/list, recents, recipe trust, route
   smoke, and bridge dispatch are live-proven. True modal/window affordances are
   not live-proven in hosted XCTest.
3. Fresh-machine staging/health note:
   closed by `docs/handoffs/GOOSE_PHASE_0_FRESH_MACHINE_STAGING_HEALTH_2026_06_27.md`.
4. MAS/manual/distribution WRV:
   still open. This pass did not run a release/distribution preflight.
5. Owner sign-off:
   not ready. Owner should not sign until Gate 3, Gate 5, OAuth/parity, true
   window affordances or explicit blocked UI, and release WRV are green or
   explicitly amended.

## Owner Section 7 Sign-Off Checklist

Owner sign-off remains blocked until every item below is true:

- [x] Fresh hosted Xcode tests run and report XCTest output.
- [x] Gate 1: real Goose Electron fallback launches and cleans up.
- [x] Gate 2: `goose serve` `/health` and `/acp?token=...` initialization pass.
- [ ] Gate 3: live prompt/permission/result proof satisfies the final agreed
      stream-event contract, including `agent_thought_chunk` unless the owner
      explicitly amends that requirement.
- [x] Gate 4: staged Goose Web UI boots in WKWebView/WebPage through the narrow
      shim.
- [ ] Gate 5: provider/settings/source/skills/session/diagnostics parity is
      complete or honestly blocked in UI, with no silent custom-ACP drops.
- [ ] Owner/browser-mediated OAuth provider authentication success is proven.
- [ ] True confirm-dialog and MCP-app window affordances are runtime-proven or
      explicitly demoted to honest blocked/handler-routed UI.
- [ ] MAS/App Store build shows the honest Pro gate and no hidden subprocess
      path.
- [ ] Direct-distribution/manual WRV and release preflight pass.
- [x] No `Epistemos/Agent/*`, hybrid AppKit Phase 1, or Paseo Section 15 work
      has started before this checklist is signed.

## Continuation Order

Do not start Phase 1. Continue Phase 0 in this order:

1. Complete owner/browser-mediated OAuth provider authentication success.
2. Close deeper provider/settings parity, or wire honest blocked UI for the
   remaining real-Goose deltas.
3. Resolve the Gate 3 `agent_thought_chunk` contract with live evidence or an
   owner-approved Section 7 amendment.
4. Stabilize or manually prove true confirm-dialog and MCP app window
   affordances; do not count handler-routed proof as real window proof.
5. Re-run MAS/manual/distribution WRV and ask for owner Section 7 sign-off only
   after the checklist is green or explicitly amended.
