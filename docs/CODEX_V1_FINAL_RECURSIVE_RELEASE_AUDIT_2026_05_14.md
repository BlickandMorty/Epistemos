# Codex V1 Final Recursive Release Audit - 2026-05-14

Scope: current Epistemos v1 only, for both Mac App Store (`Epistemos-AppStore`) and Pro/direct (`Epistemos`) builds. Helios/V6.2 migration, Lean verification stack, research-tier kernels, speculative architecture rewrites, and post-v1 research work are excluded unless they affect the current shipping app.

Protected surfaces observed: no graph rendering, Metal/SDF renderer, layout, camera, physics, selection visuals, or hologram overlay visuals were changed. No vault/database reset, deletion, casual migration, or user-data mutation was performed. `~/Epistemos-RETRO`, `src-tauri`, and `~/meta-analytical-pfc` were not touched.

## Phase 0 Snapshot

Recorded at start of audit:

| Field | Value |
|---|---|
| Working directory | `/Users/jojo/Downloads/Epistemos` |
| Branch | `codex/research-snapshot-2026-05-08` |
| Starting HEAD | `f2ec53514` |
| Current HEAD after local fixes | `fbcc0aabb` |
| Starting dirty files | `M docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`; `?? docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md` |
| Current dirty files | this audit file, MAS artifact-gating patch files, plus the pre-existing dirty docs above, unless noted in later entries |
| Recent starting commits | `f2ec53514`, `1feb73423`, `9b74c615d`, `f5f50d0ac`, `3a43066df`, `951a74c38` |
| Build schemes found | `Benchmarks`, `CodeEditLanguages`, `Epistemos`, `Epistemos-AppStore`, `EpistemosWidgets`, `GGUFRuntimeBridge`, `MLXEmbedders`, `MLXLLM`, `MLXLMCommon`, `MLXLMIntegrationTests`, `MLXLMTests`, `MLXVLM`, `NightBrainHelper`, `SwiftTreeSitter`, `TextStory`, `TextStory-Package`, `TextStoryTesting` |
| Bundle paths observed | `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ekieujweaiaygrcmyrukcjfesyuj/Build/Products/Debug/Epistemos.app`; `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-bjwdvdauuwlqafghniedksyklqzf/Build/Products/Debug/Epistemos.app`; `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`; `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Index.noindex/Build/Products/Debug/Epistemos.app` |

Recursive register strict `Status:` count snapshot from `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`:

| Status | Count |
|---|---:|
| PATCHED | 176 |
| PATCHED PARTIAL | 27 |
| PATCHED BUT NOT CLOSED | 1 |
| PATCHED BUT WATCH | 1 |
| REOPENED | 4 |
| SOURCE REOPENED | 1 |
| OPEN | 1 |
| DEFERRED | 2 |
| TODO | 0 |
| CONFIRMED | 30 |
| PARTIAL | 9 |
| PATCH PROPOSAL | 6 |
| OBSOLETE | 2 |
| OTHER | 13 |

Known reopened gates at start:

- Swift/Xcode test compile failure in `EpistemosTests/SDPageQueryDescriptorTests.swift`.
- App Store artifact scan failures for `bash_execute`, `docker`, and exported `posix_spawn`.
- Swift 6 sending/data-race warning in `Epistemos/Engine/EpdocEditorBridge.swift`.
- `RCA8-P0-003` SwiftData/vault lifecycle crash through `SDPage.tags` during instant-recall rebuild.
- Local runtime store schema error: `ZWIKILINKREFERENCESCANSIGNATURE`.
- Incomplete live Computer Use smoke for chat, note ask-bar, graph inspector, and settings diagnostics.
- Chat intent classifier misses for softer vault queries.
- PATCHED PARTIAL manual-smoke items remain unclosed until runtime evidence exists.
- Pro-only subprocess/tool surfaces must remain absent from MAS and present/working in Pro.

## V1 Remaining-Work Ledger

| ID | Status | Subsystem | MAS impact | Pro impact | Evidence | Verification | Decision | Code changes allowed |
|---|---|---|---|---|---|---|---|---|
| V1-GATE-SWIFT-001 SDPage query test compile | PASS after fix | Swift tests / extraction models | MAS blocker until test target compiles | Pro blocker until test target compiles | Pre-fix failure at `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:27`; fixed optional access in `EpistemosTests/SDPageQueryDescriptorTests.swift:453` | `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SDPageQueryDescriptorTests/ExtractionAndMessageRegressionTests/extractionResultDecodesWithoutSources test CODE_SIGNING_ALLOWED=NO -quiet` | Fixed and committed | Yes; done in `fbcc0aabb` |
| V1-GATE-SWIFT-002 ThemePair stale enum compile | PASS after fix | Swift tests / theme | MAS blocker until test target compiles | Pro blocker until test target compiles | `ThemePair.warmth` no longer exists; current enum cases are in `Epistemos/Theme/EpistemosTheme.swift:1208` | Same focused SDPage test now compiles; targeted ThemePair suite compiles but fails assertions below | Fixed stale compile reference only | Yes; done in `fbcc0aabb` |
| V1-GATE-SWIFT-003 ThemePair source-guard drift | FAIL / REOPENED | Swift tests / theme + landing source guards | MAS release-gate risk because tests fail | Pro release-gate risk because tests fail | `.xcresult` failures at `EpistemosTests/ThemePairTests.swift:386`, `:387`, `:388`, `:450-452`, `:456-458`, `:521`, `:1311`, `:1320`, `:1367` | `xcodebuild ... -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO` | Reopen as stale-test or real-regression triage; do not change graph rendering | Test-only changes allowed after confirming production intent |
| V1-GATE-MAS-001 App Store artifact scanner | PASS after patch | Packaging / MAS compliance | MAS gate cleared for official scanner | Pro non-blocker; Pro build still passes | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:31-39`; clean scan report `build/codex-appstore-audit-gate` | `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateDD/Build/Products/Debug/Epistemos.app` | Fixed MAS string leaks and scanner false-positive tokenization without removing Pro functionality | Yes; pending commit |
| V1-GATE-MAS-002 Undefined fork/exec imports | OPEN / MAS compliance risk | Packaging / third-party/static Rust linkage | MAS risk pending Release/narrow-policy decision | Pro non-blocker | Exploratory `nm -u` on isolated Debug bundle still shows `_fork`, `_execvp`, `_posix_spawnp` in `Epistemos.debug.dylib` and `_fork`, `_execlp` in `llama.framework`; the official scanner does not inspect undefined imports | Repeat on Release bundle; compare against manifest's `nm -gU` gate and decide whether this is an App Store blocker or accepted static-link baseline | Track separately; do not hide in official scanner | Maybe, only after linkage evidence |
| V1-GATE-EPDOC-001 EpdocEditorBridge Swift 6 warning | FAIL / REOPENED | Epdoc WKURLSchemeHandler | MAS blocker risk under Swift 6 strict concurrency | Pro blocker risk under Swift 6 strict concurrency | `Epistemos/Engine/EpdocEditorBridge.swift:260-263`; assessment `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:25`, `:73` | Build both schemes and confirm warning absent | Minimal actor-safe URL scheme response delivery | Yes |
| V1-GATE-VAULT-001 RCA8-P0-003 SwiftData tags crash | FAIL / REOPENED | Vault / SwiftData lifecycle / instant recall | MAS blocker | Pro blocker if same lifecycle applies | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:53-61`; `Epistemos/Sync/VaultIndexActor.swift:2072-2082`; `Epistemos/Sync/VaultSyncService.swift:2758-2762`, `:2814-2824` | Zero-crash rerun/soak on App Store and Pro bundles with existing user data untouched | Minimal vault-safe snapshot/access fix only after evidence; no data reset | Yes, with rollback-safe plan |
| V1-GATE-VAULT-002 local store schema error | FAIL / REOPENED | SwiftData/CoreData store compatibility | MAS blocker for live smoke | Pro blocker if same local store path is used | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-50` | Launch against current local store; verify no `ZWIKILINKREFERENCESCANSIGNATURE` errors without mutating user vault casually | Diagnose schema/migration/recovery path; no destructive reset | Yes, only safe migration/recovery |
| V1-GATE-LIVE-MAS-001 MAS live smoke incomplete | BLOCKED | Runtime UI / MAS | MAS blocker | Pro not covered | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-51` | Computer Use: settings diagnostics, HELIOS V5 off, Cognitive DAG row, chat `hi`, chat vault query, note ask-bar rewrite/escalation, graph inspector summarize/escalation, graph unchanged screenshots | Blocked by runtime store errors until fixed | No broad UI changes without reproduced bug |
| V1-GATE-LIVE-PRO-001 Pro live smoke incomplete | BLOCKED | Runtime UI / Pro routing | MAS non-blocker | Pro blocker | Required by user mission; manifest Pro identity at `docs/MAS_RELEASE_MANIFEST_2026_05_13.md:10-18` | Computer Use: Pro surfaces, local/cloud routing, provider/tool tiers, no MAS restriction bleed | Pending after builds and store stability | Yes, only evidence-backed |
| V1-GATE-CHAT-001 softer vault query classifier misses | FAIL / v1 polish risk | Chat intent routing | MAS manual-smoke risk; can block if vault query silently no-tools | Pro manual-smoke risk | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:90-96` | Unit tests around `ChatCapability` plus live chat smoke with softer queries | Fix only if current v1 smoke reproduces broken behavior | Yes, small heuristic/test patch |
| V1-GATE-PRO-001 Pro-only surfaces gated from MAS and alive in Pro | OPEN | Build gating / tools / settings | MAS blocker if leaked | Pro blocker if missing | Manifest denied/pro features at `docs/MAS_RELEASE_MANIFEST_2026_05_13.md:102-141`, feature matrix at `:10-18` | MAS scan, Pro runtime smoke, `cargo test --features pro-build` | Verify, fix only leaks or missing Pro path | Yes |
| V1-PARTIAL-001 PATCHED PARTIAL manual smoke set | OPEN | Mixed | MAS risk until sampled/closed | Pro risk until sampled/closed | Register count snapshot above; sampled items in assessment `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:79-83` | Recursive passes plus live UI smoke | Close, defer post-v1, or reopen item-by-item | Maybe, evidence-backed only |
| V1-DEAD-001 stale/dead/scaffold surfaces visible in v1 | OPEN | Mixed | MAS polish/compliance risk | Pro polish risk | Manifest and register require prune/hide pass; known stale source guards now visible in `ThemePairTests` | `rg` audit and UI smoke | Prune only if visible in shipping app; docs/test-only stale entries may be marked stale | Maybe |
| POSTV1-EXCL-001 Helios/V6.2/research migration work | DEFERRED-POST-V1 | Future architecture | Excluded unless current app blocker | Excluded unless current app blocker | `docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md`; `docs/future-work-audit.md` | N/A for v1 release | Do not start | No |

## Recursive Pass Log

### Pass 1 - 2026-05-14

Result: new blockers found; zero-streak reset to 0.

- `V1-GATE-SWIFT-001`: FAIL reproduced, then fixed. Pre-fix `decoded.tags.map(\.name)` compiled against an optional array incorrectly. Fixed to `decoded.tags?.map(\.name)`. Focused SDPage test now exits 0.
- `V1-GATE-SWIFT-002`: FAIL surfaced after the first compile fix. `ThemePair.warmth` was stale; current `ThemePair` cases are `platinumViolet`, `classic`, and `ember`. Fixed test expectation to `platinumViolet`. Focused SDPage test still exits 0 after this patch.
- `V1-GATE-SWIFT-003`: REOPENED. `ThemePairTests` now compiles but fails 13 source-guard/runtime assertions against existing production behavior. No production theme/graph rendering files changed.
- `V1-GATE-EPDOC-001`: FAIL still present. Xcode emits the documented Swift 6 sending/data-race warning for `Task.detached` capturing `urlSchemeTask`.
- `V1-GATE-MAS-001`, `V1-GATE-VAULT-001`, `V1-GATE-VAULT-002`, `V1-GATE-LIVE-MAS-001`, `V1-GATE-LIVE-PRO-001`: carry forward as open/reopened from evidence docs and required smoke list.

### Pass 2 - 2026-05-14

Result: MAS official artifact scanner cleared; new import-level MAS risk added; zero-streak remains 0 because an unresolved MAS compliance risk was found.

- `V1-GATE-MAS-001`: PASS on a clean isolated `Epistemos-AppStore` Debug build at `/tmp/EpistemosAppStoreGateDD/Build/Products/Debug/Epistemos.app`. The scanner reported no prohibited runtime strings, no prohibited exported symbols/link names, and no prohibited research/tool resources.
- MAS leak fixes were limited to current v1 release packaging: Pro-only legacy aliases for `bash_execute`, terminal/process, and cron are compiled out of MAS; `dockerDevcontainer` gateway names are compiled out of MAS; Swift subprocess continuation/cleanup helpers now compile as inert MAS stubs.
- The scanner regex now matches fork/exec/posix-spawn as exported symbol tokens instead of substrings inside Rust-mangled type names such as `std..sys..process..posix_spawn..PosixSpawnattr`.
- `V1-GATE-MAS-002`: OPEN. An exploratory import scan outside the official gate still shows undefined `_fork`, `_execvp`, and `_posix_spawnp` in the app debug dylib and `_fork`, `_execlp` in `llama.framework`. Static Rust archives all show the same Rust std process imports, so this needs Release-bundle triage rather than a broad refactor.
- `V1-GATE-EPDOC-001`: FAIL still present in both MAS and Pro builds.

## Fix Log

### Commit `fbcc0aabb` - `fix(tests): restore Swift test compilation`

Changed:

- `EpistemosTests/SDPageQueryDescriptorTests.swift`: optional-map fix for decoded optional tags.
- `EpistemosTests/ThemePairTests.swift`: replaced stale `ThemePair.warmth` test reference with current `ThemePair.platinumViolet`.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SDPageQueryDescriptorTests/ExtractionAndMessageRegressionTests/extractionResultDecodesWithoutSources test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL after compile; stale ThemePair source-guard assertions listed in `V1-GATE-SWIFT-003`.

### Pending MAS Artifact Fix Commit

Changed:

- `Epistemos/Bridge/ToolTierBridge.swift`: compiles Pro-only legacy subprocess aliases out of MAS.
- `Epistemos/LocalAgent/LocalAgentGatewayPolicy.swift`, `Epistemos/Security/CapabilityBridge.swift`, `Epistemos/XPC/AgentServiceProtocol.swift`: compiles `dockerDevcontainer` names and parsing out of MAS.
- `Epistemos/State/TimeoutUtility.swift`, `Epistemos/State/OrphanSubprocessCleanup.swift`: removes Swift `Process` helper types from MAS compilation and provides inert cleanup stubs.
- `scripts/scan_appstore_bundle.sh`: avoids false-positive exported-symbol matches inside Rust-mangled type names.
- `EpistemosTests/AppStoreHardeningTests.swift`: source guard for the symbol-token scanner behavior.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosAppStoreGateDD build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; still emits `V1-GATE-EPDOC-001` warning.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateDD/Build/Products/Debug/Epistemos.app` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; still emits `V1-GATE-EPDOC-001` warning.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/AppStoreHardeningTests/appStoreArtifactScanInspectsFinalBundleStringsSymbolsExecutablesAndResources -only-testing:EpistemosTests/HermesGatewayEvidenceContractTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.

## Current Verdict

Not release-ready. MAS and Pro remain blocked by the unresolved gates above. No five-pass zero-new-blocker streak has started.
