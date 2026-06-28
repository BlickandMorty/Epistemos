# Goose Phase 0 - Claude Deep Hardening Handoff

Date: 2026-06-28 09:59 CDT
Branch: `feat/goose-surface`
Author: Codex continuation pass
Status: Phase 0 only. Not signed off.

## Owner Report

The owner is still seeing Goose surface failures in the app:

- Providers no longer auto-load reliably like they used to.
- ACP WebSocket / provider model picker errors still appear in some paths.
- Apps, Session History, and chat history have shown loading failures.
- Settings -> Auth showed `Failed to load provider credentials`.
- The details/status language must be exact: the owner expects
  `native ACP Goose ready (...)` and `custom ACP Goose ready`, not vague
  `Goose ACP ready` / `Goose`.
- The owner wants deep hardening, edge-case coding, and recursive proof, not a
  cosmetic patch.

Treat this as a live Phase 0 stabilization task, not Phase 1.

## Absolute Boundaries

- Do not start `Epistemos/Agent/*`.
- Do not start hybrid AppKit Phase 1.
- Do not start Paseo Section 15.
- Do not mark Phase 0 signed off.
- Do not hardcode provider/model catalogs in Swift. Provider/model/skill data
  must come from live Goose ACP/catalog paths.
- Do not delete or rewrite unrelated work. The tree has unrelated untracked
  docs; ignore them unless the owner explicitly asks.
- Preserve the working WebView/ACP path and improve it in place.

## Required Reads Before Continuing

Read these first, in this order:

1. `AGENTS.md` at repo root / prompt context.
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` only enough to satisfy
   local-canon research-first discipline for this Goose task.
3. `docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md`
4. `docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md`
5. This file.
6. Current diffs in:
   - `stage-goose-web-ui.sh`
   - `EpistemosTests/GooseSessionLifecycleLiveIntegrationTests.swift`
   - `EpistemosTests/GooseCustomCapabilityLiveIntegrationTests.swift`
   - `EpistemosTests/GooseProviderMutationLiveIntegrationTests.swift`
   - `EpistemosTests/GooseSettingsMutationLiveIntegrationTests.swift`
   - `EpistemosTests/GooseWebPromptLiveIntegrationTests.swift`

Use the Recursive App Audit skill methodology for the hardening pass: run
tests, perform manual/logical audit, fix issues, reset pass counter, and require
three clean verification passes before claiming stable. Do not claim that loop
is complete until it actually is.

## Current Uncommitted Work

The repo currently has uncommitted Phase 0 repairs in six files:

- `stage-goose-web-ui.sh`
  - Adds recipe ID reconciliation in the generated Goose Web UI so saved recipe
    IDs returned by ACP can be resolved back to the canonical recipe list entry.
  - Handles normalized `/var` vs `/private/var` paths and filename/title
    fallback.
  - Keeps provider/model catalog fallback in the Web UI: model picker first uses
    live provider model list, then falls back to Goose ACP catalog `known_models`
    if a local/provider endpoint cannot be contacted.
  - Keeps Settings -> Auth on ACP `providers/config/status` instead of stale raw
    HTTP provider-secret paths.

- `EpistemosTests/GooseSessionLifecycleLiveIntegrationTests.swift`
  - Fixed the direct session-history proof to match upstream Goose desktop:
    `session/new` now sends desktop compatibility metadata:
    `client=goose-desktop`, `compatibilityClient=goose-desktop`,
    `appName=Epistemos`, `brand=epistemos`.
  - `session/list` no longer passes `cwd`; upstream Goose UI lists globally with
    `_meta.types = ["user", "scheduled"]`.
  - The proof now prompts the new session, waits for the prompted session to
    appear in `session/list`, reads `_goose/unstable/session/info`, then
    performs `session/load` and `session/fork` using the session-info `cwd`.

- `EpistemosTests/GooseCustomCapabilityLiveIntegrationTests.swift`
  - Recipe custom-capability proof now resolves saved recipe ID to canonical
    recipe ID before launch.
  - Sets an isolated provider/default before launching a recipe session.
  - Logs provider/model/recipe IDs for follow-up debugging.

- `EpistemosTests/GooseProviderMutationLiveIntegrationTests.swift`
  - Provider mutation proof now writes URL-shaped placeholders for endpoint/base
    URL/host keys and asserts against per-key expected values.

- `EpistemosTests/GooseSettingsMutationLiveIntegrationTests.swift`
  - Same provider config value helper as provider mutation proof, so settings
    defaults proof does not fail on endpoint-shaped fields.

- `EpistemosTests/GooseWebPromptLiveIntegrationTests.swift`
  - Adds a wait loop for the WebView prompt input so the prompt proof does not
    race the initial `LOADING...` screen.

## Proofs Already Passed In This Pass

Focused settings mutation proof passed:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-settings-mutation-helper.xcresult \
  -only-testing:EpistemosTests/GooseSettingsMutationLiveIntegrationTests test
```

Focused provider mutation proof passed after endpoint placeholder fix:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-provider-mutation-helper-fixed.xcresult \
  -only-testing:EpistemosTests/GooseProviderMutationLiveIntegrationTests test
```

Web UI validate/typecheck passed:

```sh
EPISTEMOS_GOOSE_UI_VALIDATE_ONLY=1 \
EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK=1 \
./stage-goose-web-ui.sh /tmp/epistemos-goose-ui-validate-recipe-id
```

WebView prompt proof passed:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-webview-prompt-input-wait.xcresult \
  -only-testing:EpistemosTests/GooseWebPromptLiveIntegrationTests test
```

Custom capability proof passed:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-custom-capabilities-isolated-provider.xcresult \
  -only-testing:EpistemosTests/GooseCustomCapabilityLiveIntegrationTests test
```

Session lifecycle proof passed after aligning with Goose desktop session
metadata/global list:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-session-lifecycle-desktop-compatible.xcresult \
  -only-testing:EpistemosTests/GooseSessionLifecycleLiveIntegrationTests test
```

Proof log:

```text
/tmp/epistemos-goose-phase0-acp-session-lifecycle.log
phase0_live_acp_session_lifecycle=pass
initial_listed_count=9
initial_listed_empty_session=false
prompt_stop_reason=end_turn
persisted_listed_count=10
persisted_listed_session=true
session_info_cwd_matches_repo=true
load_has_modes=true
load_has_models=true
load_has_config_options=true
fork_differs_from_original=true
```

## Current Blocker / Interrupted State

The combined provider/session/custom/WebView sweep was attempted:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-nested-provider-session-sweep-desktop-compatible.xcresult \
  -only-testing:EpistemosTests/GooseProviderCatalogLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseSessionLifecycleLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseCustomCapabilityLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseWebPromptLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseWebRouteLiveIntegrationTests test
```

It failed before tests ran because Xcode package artifacts in DerivedData were
stale/missing:

```text
There is no XCFramework found at .../SourcePackages/artifacts/ggufruntimebridge/llama/llama.xcframework
Missing package product 'AXorcist'
Missing package product 'GRDB'
Missing package product 'Grape'
Missing package product 'Numerics'
Missing package product 'AsyncHTTPClient'
Missing package product 'NIOCore'
Missing package product 'NIOHTTP1'
Missing package product 'Crypto'
Missing package product 'OrderedCollections'
Missing package product 'yyjson'
Missing package product 'CodeEditSourceEditor'
Missing package product 'SwiftTreeSitter'
Missing package product 'CodeEditLanguages'
```

Codex then ran:

```sh
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -resolvePackageDependencies
```

That also failed before product tests:

```text
Error Domain=NSCocoaErrorDomain Code=513 "“yyjson” couldn’t be removed because you don’t have permission to access it."
NSFilePath=.../DerivedData/Epistemos-.../SourcePackages/checkouts/yyjson
binary target 'llama' could not be mapped to an artifact with expected name 'llama'
```

So the next agent must first repair DerivedData/package artifact health. This
is likely a local Xcode package-cache state issue plus a local binary target
artifact naming issue, not an observed Goose product assertion. Do not treat the
combined sweep as failed product behavior until it actually reaches XCTest
assertions.

## Deep Hardening Orders For Claude

1. First restore package/artifact health.
   - Run package resolution.
   - Verify `llama.xcframework` exists under DerivedData SourcePackages artifacts
     or that Xcode no longer errors on it.
   - Resolve the local DerivedData permission failure on
     `SourcePackages/checkouts/yyjson` without destructive repo resets.
   - Resolve the local `GGUFRuntimeBridge`/`llama` binary artifact mapping
     failure. Prefer the repo's existing scripts/package instructions; do not
     bypass by deleting product code.
   - Rerun the exact combined sweep.

2. Re-stage the repaired Goose Web UI into the app support location after tests
   pass:

   ```sh
   ./stage-goose-web-ui.sh "$HOME/Library/Application Support/Epistemos/GooseWebUI"
   ```

3. Launch the current Debug app:

   ```sh
   /usr/bin/open "/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app"
   ```

4. Manual test the exact owner-reported paths:
   - Open Goose with `Cmd-3`.
   - Open the details/slider panel.
   - Confirm exact language:
     - `native ACP Goose ready (...)`
     - `custom ACP Goose ready`
   - Settings -> Auth: must not show `Failed to load provider credentials`.
   - Settings -> Models -> Switch models:
     - provider picker must auto-populate from Goose ACP catalog.
     - local providers such as LM Studio/Ollama may show provider-specific
       errors if their local server is off, but should not break the whole
       picker or show generic ACP WebSocket failure.
   - New Chat:
     - prompt input must appear after loading.
     - default provider/model should display.
     - a tiny prompt should stream and return.
   - Apps:
     - route must load.
     - `No apps available` is acceptable.
     - generic `Error loading apps` is not acceptable.
   - Recipes:
     - route must load.
     - save-and-run must not throw `recipe not found`.
   - Session History:
     - route must load.
     - recent prompted session should appear.
     - no generic `Error Loading Sessions`.
   - Skills, Scheduler, Extensions:
     - routes must load without generic error boundaries.

5. Edge-case hardening to add if not already covered:
   - ACP WebSocket reconnect/reload: kill and restart `goose serve`; the UI must
     recover or show honest blocked UI, not stale provider errors.
   - Empty provider credentials: Auth must show empty state, not toast error.
   - Configured provider with unreachable endpoint: model picker must fall back
     to catalog `known_models` where possible and show provider-specific warning.
   - Provider with no `known_models`: picker must keep custom model entry usable.
   - Rapid route switching: `/apps`, `/sessions`, `/settings?section=models`,
     `/settings?section=auth`, `/recipes`, `/skills` should not leave stale
     toasts/dialogs or close ACP socket prematurely.
   - Multiple ACP clients: marker/probe clients in tests must close cleanly and
     not starve the Web UI shared client.
   - Session creation classification: sessions created through Epistemos must
     include Goose desktop compatibility metadata so they appear under
     `session/list` types `user/scheduled`.
   - Recipe save ID drift: test `/var` vs `/private/var`, filename-only match,
     title collision, and no-match failure path.
   - App import/export: no raw HTTP path, native file bridge works or shows
     honest blocked UI.

6. Run recursive proof:
   - One focused pass for each repaired area.
   - One combined sweep.
   - One manual app pass.
   - Then two more repeat passes without code changes.
   - Only after three consecutive clean passes should you call the surface
     hardened. Even then, Phase 0 remains unsigned until owner OAuth/sign-off.

## Suggested Verification Commands

After package resolution:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-goose-nested-provider-session-sweep-rerun.xcresult \
  -only-testing:EpistemosTests/GooseProviderCatalogLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseSessionLifecycleLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseCustomCapabilityLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseWebPromptLiveIntegrationTests \
  -only-testing:EpistemosTests/GooseWebRouteLiveIntegrationTests test
```

Then:

```sh
EPISTEMOS_GOOSE_UI_VALIDATE_ONLY=1 \
EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK=1 \
./stage-goose-web-ui.sh /tmp/epistemos-goose-ui-validate-final
```

Then:

```sh
./scripts/xcodebuild_epistemos.sh -scheme Epistemos -destination 'platform=macOS' \
  -resultBundlePath build/xcode-results/2026-06-28-phase0-final-build-for-testing.xcresult \
  build-for-testing
```

## Documentation / Commit Rules

Before committing:

- Update `docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md` with a
  2026-06-28 addendum for:
  - provider auto-load/catalog fallback,
  - Auth provider credentials ACP bridge,
  - recipe ID reconciliation,
  - desktop-compatible session lifecycle proof,
  - WebView prompt-input wait,
  - remaining unsigned Phase 0 gates.
- Stage only relevant Phase 0 files.
- Ignore unrelated untracked docs unless owner requests otherwise.
- Commit after tests/manual proof are honest.

## Paste Block For Claude

Continue Goose Phase 0 only. Do not start `Epistemos/Agent/*`, hybrid AppKit
Phase 1, or Paseo Section 15. The owner still sees provider auto-load, ACP
WebSocket/model picker, Apps, Auth, Session History, and chat-history issues.
Read
`docs/handoffs/GOOSE_PHASE_0_CLAUDE_DEEP_HARDENING_HANDOFF_2026_06_28.md`,
then restore package/artifact health, rerun the combined Goose sweep, re-stage
the repaired Web UI, manually test the owner-reported routes, and use recursive
app-audit methodology for deep edge-case hardening. Current uncommitted repairs
are in `stage-goose-web-ui.sh` and five `EpistemosTests/Goose*.swift` files.
Focused settings/provider/custom capability/WebView prompt/session lifecycle
proofs passed; the combined sweep was blocked before tests by missing Xcode
package artifacts. Phase 0 remains NOT signed off.
