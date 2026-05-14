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
| Current HEAD before Epdoc fix | `3cc7b2fc9` |
| Starting dirty files | `M docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`; `?? docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md` |
| Current dirty files | pre-existing `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` and untracked `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md`, unless noted in later entries |
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
| V1-GATE-SWIFT-003 ThemePair source-guard drift | PASS after test-only fix | Swift tests / theme + landing source guards | MAS test gate cleared | Pro test gate cleared | Pre-fix `.xcresult` failures at `EpistemosTests/ThemePairTests.swift:386`, `:387`, `:388`, `:450-452`, `:456-458`, `:521`, `:1311`, `:1320`, `:1367`; fixed to match current production theme intent | `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO -quiet` | Test-only source guards updated; no graph rendering touched | Yes; test-only done |
| V1-GATE-SWIFT-004 RuntimeValidation stale source guards | PASS after test-only fix | Swift tests / source guards | MAS test gate cleared | Pro test gate cleared | Pre-fix `.xcresult` failures at `EpistemosTests/RuntimeValidationTests.swift:2420`, `:4492`; source guards expected stale RootView and cloud-agent-routing shapes | `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO -quiet` | Test-only source guards updated | Yes; test-only done |
| V1-GATE-MAS-001 App Store artifact scanner | PASS after patch | Packaging / MAS compliance | MAS gate cleared for official scanner | Pro non-blocker; Pro build still passes | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:31-39`; clean scan report `build/codex-appstore-audit-gate` | `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateDD/Build/Products/Debug/Epistemos.app` | Fixed MAS string leaks and scanner false-positive tokenization without removing Pro functionality | Yes; done in `60c3067cb` |
| V1-GATE-MAS-002 Undefined fork/exec imports | PATCHED PARTIAL / MAS compliance risk | Packaging / third-party binary framework linkage | MAS review risk remains for binary `llama.framework` `_fork` / `_execlp`; MLX `_popen` removed from wrapper-built Release app | Pro non-blocker | Clean wrapper Release build at `/tmp/EpistemosAppStoreReleaseWrapperNoPopen/Build/Products/Release/Epistemos.app` no longer imports `_popen`; broad scan still reports `Contents/Frameworks/llama.framework/Versions/A/llama:_execlp` and `:_fork`; MLX source evidence was `Source/Cmlx/mlx/mlx/backend/cpu/jit_compiler.cpp` | `./scripts/xcodebuild_epistemos.sh ... -scheme Epistemos-AppStore -configuration Release ... build`; official scanner PASS; manifest narrow scans PASS; broad undefined import scan still reports llama only | Keep MLX patch in release wrapper; resolve binary `llama.framework` via vendor rebuild/replacement, App Review risk acceptance, or remove from MAS bundle if product can ship without it | Yes for MLX patch done; no local patch possible for binary llama framework without replacing the artifact |
| V1-GATE-EPDOC-001 EpdocEditorBridge Swift 6 warning | PASS after fix | Epdoc WKURLSchemeHandler | MAS gate cleared for this warning | Pro gate cleared for this warning | `Epistemos/Engine/EpdocEditorBridge.swift:260-266`; assessment `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:25`, `:73` | Both schemes build without the warning; Epdoc targeted tests pass | Fixed with actor-safe URL scheme response delivery | Yes; done in Epdoc fix |
| V1-GATE-VAULT-001 RCA8-P0-003 SwiftData tags crash | PATCHED / RUNTIME RERUN REQUIRED | Vault / SwiftData lifecycle / instant recall | MAS blocker until zero-crash rerun | Pro blocker until zero-crash rerun if same lifecycle applies | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:53-61`; pre-fix `Epistemos/Sync/VaultIndexActor.swift:2099-2119` now snapshots primitives before awaits | Zero-crash rerun/soak on App Store and Pro bundles with existing user data untouched | Patched by primitive snapshot before async body reads; runtime soak still required | Yes; code patched |
| V1-GATE-VAULT-002 local store schema error | PATCHED / MAS NOTES RERUN PASS / PRO RERUN REQUIRED | SwiftData/CoreData store compatibility | MAS runtime blocker cleared for the reproduced Notes-click crash; broader MAS smoke still incomplete | Pro blocker until direct build is launched against same local store path | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-50`; read-only schema inspection showed `ZSDPAGE` missing `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`; repair now runs for both legacy root and app-scoped stores in `Epistemos/App/AppBootstrap.swift:1247`, `:1255`, and verifies required columns at `:1256`; Notes crash stack was `NotesSidebarFolderCacheSignature.init` -> `SDPage.isArchived` at `Epistemos/Views/Notes/NotesSidebar.swift:127` before the cache patch | Launch MAS/Pro against current local store; verify both stores contain required columns and Notes opens without new `.ips` | Additive, idempotent SQLite column repair before `ModelContainer`, with one-time pre-alter SQLite backup; Notes sidebar avoids inverse `folder.pages` faults and uses active-page query snapshots; no vault reset/delete | Yes; code patched |
| V1-GATE-LIVE-MAS-001 MAS live smoke incomplete | PATCHED/PARTIAL; note simple rewrite remains blocked by data-safety choice | Runtime UI / MAS | MAS blocker until full smoke completes | Pro not covered | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-51`; Pass 10 note ask-bar crash evidence in `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-014126.ips`; Pass 11 graph/settings smoke | Computer Use: settings diagnostics, HELIOS V5 off, Cognitive DAG row, chat `hi`, chat vault query, note ask-bar rewrite/escalation, graph inspector summarize/escalation, graph unchanged screenshots | Main chat, note ask-bar vault escalation, settings diagnostics, graph summarize, graph related-notes escalation, and graph return smoke passed; note ask-bar simple rewrite still not run because it would intentionally mutate a user note without a disposable scratch note | No broad UI changes without reproduced bug |
| V1-GATE-LIVE-PRO-001 Pro live smoke incomplete | PATCHED/PARTIAL; cloud-agent smoke BLOCKED by missing provider keys | Runtime UI / Pro routing | MAS non-blocker | Pro blocker until cloud-key-dependent smoke is resolved or waived | Required by user mission; manifest Pro identity at `docs/MAS_RELEASE_MANIFEST_2026_05_13.md:10-18`; Pass 11 Pro settings/runtime evidence | Computer Use: Pro surfaces, local/cloud routing, provider/tool tiers, no MAS restriction bleed | Pro profile surfaces and local model/tool routing passed; cloud provider/tool-agent smoke blocked because Pro settings report `No provider keys stored` | Yes, only evidence-backed |
| V1-GATE-CHAT-001 softer vault query classifier misses | PASS for reproduced note/main-chat vault lookup prompts; broader smoke pending | Chat intent routing | MAS risk reduced; still blocked by full smoke completion | Pro manual-smoke risk until live Pro rerun | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:90-96`; `Epistemos/Engine/AgentHarness/ChatCapability.swift:167`, `:322`; `EpistemosTests/ChatCapabilityIntentTests.swift:44` | Targeted `ChatCapabilityIntentTests`; MAS note ask-bar live rerun; Pro live smoke still needed | Fixed current reproduced soft/plural vault lookup miss with local/tool-capable routing | Yes; code patched |
| V1-GATE-NOTES-001 note ask-bar TextKit line-range crash | PASS for reproduced MAS crash; Pro live smoke pending | Notes / TextKit2 / ask bar | MAS crash gate cleared for reproduced path | Pro risk until direct app smoke covers the same editor path | Crash stack in `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-014126.ips`; fix at `Epistemos/Views/Notes/ProseTextView2.swift:698`, `:705`; guard at `EpistemosTests/TextKit2FoundationTests.swift:167` | Targeted TextKit2 foundation test, MAS note ask-bar live rerun, Pro direct live smoke | Clamp inverted TextKit fragment order before assigning `visibleLineRange`; no graph/vault code changed | Yes; code patched |
| V1-GATE-PRO-001 Pro-only surfaces gated from MAS and alive in Pro | PASS for MAS/Pro profile visibility and local tools; cloud-key smoke blocked | Build gating / tools / settings | MAS scanner/settings gate passed | Pro profile surface gate passed | Manifest denied/pro features at `docs/MAS_RELEASE_MANIFEST_2026_05_13.md:102-141`, feature matrix at `:10-18`; Pro settings Pass 11 showed enabled CLI passthrough, Channels, Knowledge Fusion, iMessage Driver, Skills, AX/computer-use, Bash/MultiEdit/WebFetch, and installed Claude/Codex/Kimi CLIs | MAS scan, Pro runtime smoke, `cargo test --features pro-build` | Fix only if remaining cloud-key smoke reveals a Pro path regression | Yes |
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

### Pass 3 - 2026-05-14

Result: Epdoc Swift 6 warning cleared; zero-streak remains 0 because vault/runtime, ThemePair source-guard drift, Pro/MAS live smoke, and undefined import triage remain unresolved.

- `V1-GATE-EPDOC-001`: PASS. The Brotli response path now performs decompression in a detached child task but resumes the inherited `@MainActor` task before touching `WKURLSchemeTask`, eliminating the Swift 6 sending/data-race warning without moving response delivery off the actor.
- Verification covered MAS build, Pro build, and targeted Epdoc bridge/source-guard tests. No graph rendering or vault/database code was touched.

### Pass 4 - 2026-05-14

Result: vault/schema blockers patched structurally; runtime proof still pending; zero-streak remains 0 because live smoke, zero-crash soak, import-level MAS triage, and stale test/source guards remain unresolved.

- `V1-GATE-VAULT-002`: PATCHED structurally. Read-only SQLite inspection of `/Users/jojo/Library/Application Support/Epistemos/default.store` confirmed `ZSDPAGE` lacked `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`. `AppBootstrap.preparePersistentModelStoreIfNeeded` now applies an idempotent additive repair for those columns before opening SwiftData, matching the existing legacy `SDMessage` column repair pattern. A one-time `default.store.pre-column-repair.backup` SQLite backup is created before the first ALTER so the change has an on-disk rollback point.
- `V1-GATE-VAULT-001`: PATCHED structurally. `VaultIndexActor.fullPageData(for:)` and `allPagesForRebuild()` now snapshot page id, title, file path, inline body, joined tags, and updated date before awaiting body reads, so the instant-recall rebuild no longer reads `SDPage.tags` after an `await`.
- `V1-GATE-SWIFT-004`: REOPENED. `RuntimeValidationTests` compiles but the suite still fails on a stale landing source guard at `EpistemosTests/RuntimeValidationTests.swift:2412`. The `.xcresult` failure list did not include the new vault guards after the patch.
- No graph rendering files were changed. No user vault files were reset or deleted. The durable user store was inspected read-only only; the additive repair has not yet been applied to the live store outside app launch.

### Pass 5 - 2026-05-14

Result: Swift source-guard test gates cleared; zero-streak remains 0 because MAS/Pro live smoke, vault zero-crash/runtime proof, and MAS import-level triage remain unresolved.

- `V1-GATE-SWIFT-003`: PASS after test-only updates. ThemePair expectations now match the current production intent: pair-driven display typography, Platinum light heading glow, main-chat surface-variant backdrop sampling, and current LiquidGreeting task/timing shape.
- `V1-GATE-SWIFT-004`: PASS after test-only updates. RuntimeValidation source guards now match current RootView `HomeWindowIdentityObserver(themeIsDark:)` usage and cloud-agent routing across Pro/Fast/Thinking when the selected cloud surface supports the agent tier.
- No production files were changed in this pass. No graph rendering files were touched.

### Pass 6 - 2026-05-14

Result: required Rust/default, Rust/Pro, research tests, and clean App Store scanner checks passed; zero-streak remains 0 because live smoke, vault zero-crash/runtime proof, and the import-level MAS review risk remain unresolved.

- Clean isolated App Store Debug build passed at `/tmp/EpistemosAppStoreGateDD/Build/Products/Debug/Epistemos.app`.
- Release isolated App Store build attempt at `/tmp/EpistemosAppStoreReleaseDD` was stopped after it sat idle with only `xcodebuild` alive and no child compiler/script processes for more than 15 minutes. This is recorded as a Release-only tooling/build hang, not as a source compile failure.
- `V1-GATE-MAS-001`: PASS on the clean isolated App Store Debug app. Official scanner reported no prohibited runtime strings, exported/linkage symbols, or prohibited resource residue. Manifest narrow string scan and `libagent_core.dylib` narrow symbol scan also passed.
- `V1-GATE-MAS-002`: still OPEN as MAS review risk. Broader undefined-import inventory still shows `_execvp`, `_fork`, and `_posix_spawnp` in `Epistemos.debug.dylib`, plus `_execlp` and `_fork` in bundled `llama.framework`. No app-target object/archive scan identified a first-party object carrying those imports.
- `V1-GATE-RUST-PRO-001`: FAIL reproduced in `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build`: stale Pro tier tests expected legacy model-facing names (`vision_analyze`, `terminal`) even though the current catalog surfaces canonical V2 names (`media.vision_analyze`, `action.terminal`). Fixed test expectations only; no registry behavior changed.
- Rust verification now passes:
  - `cargo test --manifest-path agent_core/Cargo.toml --lib` - PASS, 1089 passed.
  - `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build` - PASS, 1302 passed.
  - `cargo test --manifest-path epistemos-research/Cargo.toml --features research` - PASS, 492 lib tests + 113 canonical consistency tests passed.

### Pass 7 - 2026-05-14

Result: live store schema repair and backup behavior verified; MAS live smoke reopened a chat UI livelock, now patched structurally; zero-streak remains 0 pending rerun of MAS and Pro smoke.

- `V1-GATE-VAULT-002`: PASS for runtime schema repair. Before relaunch, read-only SQLite inspection showed the live store still lacked `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`, and the existing `default.store.pre-column-repair.backup` was zero bytes from an interrupted backup attempt. After launching the rebuilt App Store app, the backup was replaced with a valid 377475072-byte SQLite database and the live `ZSDPAGE` table contained both wiki-link columns. Backup `PRAGMA integrity_check` returned `ok` and the backup preserved the pre-repair schema.
- `V1-GATE-LIVE-MAS-001`: REOPENED during main-chat vault-query smoke. App Store build passed Settings diagnostics, hidden HELIOS v1 posture, Cognitive DAG row, and main-chat `hi`. Submitting `What notes in my vault mention train?` caused the app to become unavailable to Computer Use (`noWindowsAvailable` / timeout) while PID 19240 stayed alive at about 99% CPU. `/tmp/epistemos-mas-vault-query-sample.txt` shows the main thread spending samples in SwiftUI `LazyStack` layout and `ScrollActionDispatcher.updateValue`, with a `ChatView.body` `onScrollGeometryChange` closure on the stack; Rust worker threads were parked.
- `V1-GATE-LIVE-MAS-002`: PATCHED structurally. `ChatView`, `MiniChatView`, and `NoteChatSidebar` now keep `onScrollGeometryChange` transforms pure by emitting a `CGFloat` distance-to-bottom. Hysteresis is applied in the action via `ScrollStability.updatedAutoFollowState`, avoiding reads of `@State autoFollow` inside the geometry transform that matched the observed AttributeGraph/scroll feedback loop. MAS live smoke rerun remains required.
- No graph rendering files were edited. `HologramSearchSidebar` was not touched because the reproduced failure was in the main-chat scroll stack, and graph rendering remains protected.

### Pass 8 - 2026-05-14

Result: the main-chat MAS vault-query silent-drop/livelock regression is patched and the exact current-file MAS Debug artifact scans clean; zero-streak remains 0 because note ask-bar smoke, graph inspector smoke, full Pro smoke, Release-only build-hang triage, broad undefined-import review triage, and the five-pass recursive streak remain incomplete.

- `V1-GATE-LIVE-MAS-001`: PATCHED/PARTIAL. After the scroll fix, the App Store app no longer became unavailable during `What notes in my vault mention train?`, but the local direct-chat pipeline dropped the turn after `Local agent stopped after 2 consecutive invisible repair turns`. `ChatCoordinator` now treats only invisible/empty repair-loop failures for explicit vault lookups as eligible for a deterministic indexed vault fallback, appends a visible assistant answer, and persists both the user and assistant rows. Non-vault pipeline errors now persist the visible user-facing error turn instead of silently dropping the submitted turn.
- Live MAS evidence: launching the App Store app initially showed the `Vault Rebuild Needed` overlay while the imported index had `0|0` page/file-path rows; no rebuild action was taken. The app import completed on its own and read-only SQLite later reported `592|592` for `ZSDPAGE` rows with file paths. Resubmitting `What notes in my vault mention train?` persisted `ZSDMESSAGE` rows `user|What notes in my vault mention train?` and `assistant|I found these indexed vault matches for "train": ...` with `ZISERROR=0`; Computer Use showed the answer and source count after manual scroll. This clears the original silent-drop/livelock blocker but leaves a v1 polish risk for initial chat auto-scroll and the transient startup rebuild overlay.
- Code evidence: `Epistemos/App/ChatCoordinator.swift:2028` gates the fallback to explicit vault lookups, `Epistemos/App/ChatCoordinator.swift:2124` uses it only after invisible/empty repair-loop errors, `Epistemos/App/ChatCoordinator.swift:3567` builds the indexed fallback answer, and `Epistemos/App/ChatCoordinator.swift:4199` extracts softer vault-query phrases such as `mention train`.
- Regression evidence: `EpistemosTests/PipelineServiceTests.swift:2636` covers soft vault mention fallback answer construction and `EpistemosTests/RuntimeValidationTests.swift:4564` guards the direct-chat error/fallback persistence shape.
- Clean exact-current MAS artifact verification: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosAppStoreGateFallbackPostFormat build CODE_SIGNING_ALLOWED=NO -quiet` passed. `scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateFallbackPostFormat/Build/Products/Debug/Epistemos.app` passed with no prohibited runtime strings, no prohibited runtime symbols, and no prohibited research/tool resource residue. The MAS manifest narrow strings scan and `libagent_core.dylib` narrow `nm -gU` scan also returned zero matches.
- No graph rendering files were edited. Vault/database actions in this pass were read-only inspections only; no rebuild was triggered.

### Pass 9 - 2026-05-14

Result: the MAS Notes-click crash is patched and rerun successfully; zero-streak remains 0 because note ask-bar actions, graph inspector smoke, Pro/direct smoke, Release-only build-hang triage, broad undefined-import review triage, and five consecutive recursive passes are still incomplete.

- `V1-GATE-VAULT-002`: REOPENED after Pass 8 when live MAS smoke clicked Notes. Crash report `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-011956.ips` shows `EXC_BREAKPOINT` on the main thread in `NotesSidebarFolderCacheSignature.init`, specifically `closure #2` at `NotesSidebar.swift:127` reading `SDPage.isArchived` from a `folder.pages` inverse relationship. This was a separate SwiftData invalidation path after the `ZWIKILINKREFERENCESCANSIGNATURE` columns had been repaired.
- Schema repair follow-up: before the follow-up patch, both `/Users/jojo/Library/Application Support/Epistemos/default.store` and `/Users/jojo/Library/Application Support/default.store` lacked the two wiki-link page columns. `AppBootstrap.preparePersistentModelStoreIfNeeded` now repairs the legacy root store before copy/adoption, repairs the app-scoped store, and verifies required message/page columns before returning the store URL. Runtime read-only verification after MAS launch showed both stores contain `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`.
- Notes crash fix: `NotesSidebar.rebuildCache()` now derives folder child pages and signature child-page IDs from the already-fetched active page query (`newPageItemsByFolderId`) instead of touching `folder.pages` during cache rebuild. Static guard `RuntimeValidationTests.notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans` now rejects reintroducing the two old `folder.pages` cache patterns.
- Verification: targeted tests passed with `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedNotesSidebarTests -only-testing:EpistemosTests/RuntimeValidationTests/notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans -only-testing:EpistemosTests/RuntimeValidationTests/bootstrapRepairsLegacyRootAndAppScopedStoresWhenBothExist test CODE_SIGNING_ALLOWED=NO -quiet`.
- Verification: clean MAS Debug build passed at `/tmp/EpistemosAppStoreGateNotesRepair/Build/Products/Debug/Epistemos.app`. `scripts/scan_appstore_bundle.sh` passed against that bundle, and both MAS manifest narrow scans returned zero matches.
- Live smoke evidence: launching `/tmp/EpistemosAppStoreGateNotesRepair/Build/Products/Debug/Epistemos.app` and clicking `2, notes` opened the Notes window with folders visible (`Epistemos-QuickCapture`, `EpistemosVault`, `Chat Transcripts`, etc.). The process stayed alive and the latest DiagnosticReports entry remained the pre-fix `Epistemos-2026-05-14-011956.ips`, with no new crash report after the rerun.
- Graph rendering files were not edited.

### Pass 10 - 2026-05-14

Result: the reproduced MAS note ask-bar vault-query classifier miss and inline-streaming crash are patched and rerun successfully; zero-streak remains 0 because note ask-bar simple rewrite, graph inspector smoke, full Pro/direct smoke, Release-only build-hang triage, broad undefined-import review triage, and five consecutive recursive passes are still incomplete.

- `V1-GATE-CHAT-001`: FAIL reproduced live in the MAS Notes window. Submitting `Find notes in my vault that mention train` from the note ask-bar showed the inline path instead of the tool-routing `Tools` intent, then streamed into the note instead of escalating to main chat. `ChatCapability.predictIntent` now classifies soft/plural vault corpus lookups (`vault`, `my notes`, `notes in`) plus lookup verbs (`find`, `search`, `what notes`, `related notes`, `mention(s)`, etc.) as `.agent` while keeping `needsCloud` false for current v1 local/tool-capable routing.
- `V1-GATE-NOTES-001`: FAIL reproduced live immediately after the misrouted note ask-bar submission. Crash report `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-014126.ips` shows `Fatal error: Range requires lowerBound <= upperBound` in `ProseTextView2.updateVisibleLineRange()` at `ProseTextView2.swift:698`, called through `ProseEditorRepresentable2.Coordinator2.appendNoteChatTokens(_:for:)`. `ProseTextView2.normalizedVisibleLineRange(startLine:endLine:lineCount:)` now clamps inverted TextKit fragment order before assigning `markdownDelegate.visibleLineRange`.
- Verification: targeted tests passed with `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedNoteAskFix -only-testing:EpistemosTests/ChatCapabilityIntentTests -only-testing:EpistemosTests/TextKit2FoundationTests/visibleLineRangeClampsInvertedFragmentOrder test CODE_SIGNING_ALLOWED=NO -quiet`.
- Verification: `git diff --check` passed for the changed ChatCapability, ChatInputBar, ProseTextView2, and test files. Static source search confirmed the stale local-cloud warning comments no longer mention local agent tier as cloud-only.
- Verification: clean MAS Debug build passed at `/tmp/EpistemosAppStoreGateNoteAskFix/Build/Products/Debug/Epistemos.app`. `scripts/scan_appstore_bundle.sh` passed against that bundle, and both MAS manifest narrow scans returned zero matches.
- Verification: Pro/direct build passed with `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProBuildNoteAskFix build CODE_SIGNING_ALLOWED=NO -quiet`.
- Live smoke evidence: launching `/tmp/EpistemosAppStoreGateNoteAskFix/Build/Products/Debug/Epistemos.app`, opening Notes, selecting `Terminal Saved Output`, and typing `Find notes in my vault that mention train` changed the ask-bar pill to `Tools` before submit. Pressing Return cleared the ask bar, did not stream into the note, did not create a new `<!-- ai-response -->`, and produced no new DiagnosticReports entry. Read-only SQLite inspection then showed persisted rows `user|Find notes in my vault that mention train` and `assistant|I found these indexed vault matches for "train": ...`, confirming escalation to the main chat/tool fallback path.
- Graph rendering files were not edited. Vault/database actions in this pass were read-only SQLite inspections only.

### Pass 11 - 2026-05-14

Result: MAS settings diagnostics, MAS graph inspector simple summarize, MAS graph related-notes escalation, graph-return visual smoke, Pro profile visibility, Pro local chat, and Pro local vault-tool smoke passed. Zero-streak remains 0 because note ask-bar simple rewrite was not executed against user vault data, Pro cloud/agent smoke is blocked by missing provider keys, the Release-only build hang and broad undefined-import review risk remain unresolved, and five consecutive recursive passes are still incomplete.

- `V1-GATE-LIVE-MAS-001`: PASS for settings diagnostics evidence. The MAS Settings General diagnostics screen rendered and showed Runtime truth, local Qwen provider/tool-loop state, Editor bundle, Halo backend, Background indexing, Process memory, OpLog projection, Agent events, Graph events, Projection snapshot, Audit projection, RRF flag, Cognitive DAG, and Deployment profile `App Store (MAS sandbox)`. The same screen listed CLI passthrough, Channels, Knowledge Fusion, iMessage Driver, Skills, NightBrain LaunchAgent, AX/computer-use, and Bash/MultiEdit/WebFetch local tools as unavailable in MAS.
- HELIOS V5 default-off evidence: the MAS Settings sidebar did not expose `HELIOS V5`. Source evidence in `Epistemos/Views/Settings/SettingsView.swift:131-135`, `:141-167`, and `:348` preserves the `heliosV5` deep-link/read-only scaffold but keeps it out of `SettingsSection.visibleSections`; `EpistemosTests/HELIOSInvariantSourceGuardTests.swift:1708-1725` guards that shape. `defaults read com.epistemos.appstore | grep -i helios` returned no runtime HELIOS key.
- `V1-GATE-LIVE-MAS-001`: PASS for graph inspector simple summarize. In `/tmp/EpistemosAppStoreGateNoteAskFix/Build/Products/Debug/Epistemos.app`, the graph rendered with nodes, edges, sidebar, toolbar overlay, and selection highlight. Selecting the `Consciousness` folder node and submitting `summarize this node` from the graph Chat tab returned an inline answer and left the graph responsive.
- `V1-GATE-LIVE-MAS-001`: PASS for graph inspector vault/related-notes escalation. Submitting `Find related notes in my vault for this node` from the selected graph node routed to main chat and produced indexed vault answers with `Sources`. Read-only SQLite evidence showed persisted rows `700|user|Find related notes in my vault for this node`, assistant rows `701` and `702` with `I found these indexed vault matches...`, and rerun user row `703`. Returning to graph after the handoff rendered the graph, sidebar, toolbar, nodes, and edges again. The graph overlay did not auto-close until the close control was clicked, but the escalation itself completed and no graph-rendering files were changed.
- No new `Epistemos-*.ips` crash report appeared after the MAS graph/settings smoke; the latest crash report remained the pre-fix `Epistemos-2026-05-14-014126.ips`.
- `V1-GATE-LIVE-PRO-001`: PASS for Pro profile startup and settings. Launching `/tmp/EpistemosProBuildNoteAskFix/Build/Products/Debug/Epistemos.app` (`com.epistemos.app`) imported the vault to completion and Settings showed Deployment profile `Pro (Developer ID)` with CLI passthrough, Channels, Knowledge Fusion, iMessage Driver, Skills, NightBrain LaunchAgent, AX/computer-use, and Bash/MultiEdit/WebFetch enabled. CLI Discovery reported Claude CLI `/Users/jojo/.local/bin/claude`, Codex CLI `/Applications/Codex.app/Contents/Resources/codex`, Gemini CLI not installed, and Kimi CLI `/Users/jojo/.local/bin/kimi`.
- `V1-GATE-LIVE-PRO-001`: PASS for Pro local routing and local tool fallback. The Pro model picker exposed 8 installed local models; selecting `Local Only` / `Qwen 3` enabled local chat. Sending `hi` returned a local Qwen response. Sending `What notes in my vault mention train?` switched the pill to `Tools`, used `Tools mode` with `Local Route`, and returned indexed vault matches. Read-only SQLite evidence showed `704|assistant|Hello!...`, `705|user|hi`, `706|user|What notes in my vault mention train?`, and `707|assistant|I found these indexed vault matches for "train": ...`.
- `V1-GATE-LIVE-PRO-001`: BLOCKED for Pro cloud/agent provider smoke. The Pro Settings diagnostics screen reported `No provider keys stored`; before selecting Local Only, the chat surface showed `Cloud — Cloud model. No tools active — plain chat` and a disabled send state for account-setup providers. Completing cloud-agent routing requires configured provider credentials or an explicit release waiver for this machine.
- No new `Epistemos-*.ips` crash report appeared after Pro smoke.

### Pass 12 - 2026-05-14

Result: the clean Release-wrapper build path now patches MLX package checkouts before compilation and removes the app-binary `_popen` import. Zero-streak remains 0 because the bundled binary `llama.framework` still imports `_fork` and `_execlp`, note ask-bar simple rewrite remains blocked by user-data safety, Pro cloud-agent smoke remains blocked by missing provider keys, and five consecutive recursive passes are still incomplete.

- `V1-GATE-MAS-002`: PATCHED PARTIAL. Direct source evidence showed upstream MLX `JitCompiler::exec()` used `popen` in `Source/Cmlx/mlx/mlx/backend/cpu/jit_compiler.cpp`. `scripts/patch_mlx_metal_warnings.sh` now also stubs that helper with an `Epistemos patch: MLX CPU JIT disabled.` throw, and `scripts/xcodebuild_epistemos.sh` runs the patcher immediately after `-resolvePackageDependencies` for the active DerivedData or cloned source-package directory.
- Failing/diagnostic check first: a raw clean `xcodebuild` package checkout retained `popen`, proving the scheme pre-action alone was too late for clean DerivedData builds. The wrapper path was then updated so package resolution and patching happen before compilation.
- Guard tests passed: `AppStoreHardeningTests/appStoreBuildPatchDisablesMLXCPUJITShellHelper` and `ReleaseScriptAuditTests/xcodebuildWrapperPatchesMLXPackageCheckoutsAfterResolution`.
- Clean Release wrapper build passed: `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/EpistemosAppStoreReleaseWrapperNoPopen CODE_SIGNING_ALLOWED=NO build`.
- Official App Store scanner passed against `/tmp/EpistemosAppStoreReleaseWrapperNoPopen/Build/Products/Release/Epistemos.app` and wrote reports to `build/codex-appstore-release-wrapper-nopopen`.
- MAS manifest narrow strings scan passed with no prohibited exact command-path strings. MAS manifest narrow `nm -gU` scan against `Contents/Frameworks/libagent_core.dylib` passed with no prohibited symbols.
- Broad undefined import scan now reports only the binary llama framework entries: `/tmp/EpistemosAppStoreReleaseWrapperNoPopen/Build/Products/Release/Epistemos.app/Contents/Frameworks/llama.framework/Versions/A/llama:_execlp` and `:_fork`. The previously observed MLX app-binary `_popen` import is gone.
- Remaining MAS action: the `llama.framework` binary target cannot be source-patched in this repository; MAS release needs a rebuilt/replaced framework without the backtrace fork/debugger path, an explicit App Review risk acceptance, or a product decision to remove that framework from the MAS bundle if local llama support is not required there.
- No graph rendering files were edited. No vault/database files or user data were mutated in this pass.

## Fix Log

### Commit `fbcc0aabb` - `fix(tests): restore Swift test compilation`

Changed:

- `EpistemosTests/SDPageQueryDescriptorTests.swift`: optional-map fix for decoded optional tags.
- `EpistemosTests/ThemePairTests.swift`: replaced stale `ThemePair.warmth` test reference with current `ThemePair.platinumViolet`.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SDPageQueryDescriptorTests/ExtractionAndMessageRegressionTests/extractionResultDecodesWithoutSources test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL after compile; stale ThemePair source-guard assertions listed in `V1-GATE-SWIFT-003`.

### Commit `60c3067cb` - `fix(mas): clear App Store artifact scan`

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

### Epdoc URL scheme race fix - 2026-05-14

Changed:

- `Epistemos/Engine/EpdocEditorBridge.swift`: kept Brotli decompression off-actor while returning to the inherited `@MainActor` task before calling `WKURLSchemeTask` response methods.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; `V1-GATE-EPDOC-001` warning absent.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; `V1-GATE-EPDOC-001` warning absent.

### Vault SwiftData/schema patch - 2026-05-14

Changed:

- `Epistemos/App/AppBootstrap.swift`: generalized the existing legacy SwiftData column repair and added additive `ZSDPAGE` repairs for `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`.
- `Epistemos/Sync/VaultIndexActor.swift`: added `PageIndexingSnapshot` and changed instant-recall/full-page rebuild paths to snapshot SwiftData page primitives before awaiting body reads.
- `EpistemosTests/RuntimeValidationTests.swift`: added regression guards for adopted-store `SDPage` column repair and for the snapshot-before-await shape in the instant-recall rebuild path.

Follow-up backup refinement:

- `Epistemos/App/AppBootstrap.swift`: creates a one-time `default.store.pre-column-repair.backup` via the existing SQLite backup helper before any legacy-column ALTER is applied.
- `EpistemosTests/RuntimeValidationTests.swift`: verifies the backup is created and preserves the pre-repair `ZSDPAGE` schema.

Verification:

- `sqlite3 "file:/Users/jojo/Library/Application%20Support/Epistemos/default.store?mode=ro" "SELECT name, sql FROM sqlite_master WHERE type='table' AND (name LIKE '%SDPAGE%' OR sql LIKE '%WIKILINK%' OR sql LIKE '%SCAN%') ORDER BY name;"` - PASS read-only evidence; old `ZSDPAGE` schema lacked the two wikilink columns.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL before and after patch due stale source guards outside the vault patch; latest `.xcresult` failure is `RuntimeValidationTests.landingGreetingRechecksWindowOcclusionAfterAppear()` at `EpistemosTests/RuntimeValidationTests.swift:2412`.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- Backup refinement verification: `RuntimeValidationTests` still fails only on stale source guards at `EpistemosTests/RuntimeValidationTests.swift:2420` and `:4492`; the new backup/schema guards are not in the `.xcresult` failure list. Pro and App Store builds both pass after the backup change.

### Swift source-guard cleanup - 2026-05-14

Changed:

- `EpistemosTests/ThemePairTests.swift`: updated stale theme, backdrop, and LiquidGreeting expectations to match current v1 production behavior.
- `EpistemosTests/RuntimeValidationTests.swift`: updated stale RootView and cloud-agent-routing source guards.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ThemePairTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.

### Pro Rust tier-catalog source-guard cleanup - 2026-05-14

Changed:

- `agent_core/src/tools/registry.rs`: updated Pro-only tier tests to assert the current model-facing V2 tool names for media, discovery, intelligence, terminal, and messaging surfaces.

Verification:

- `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build tools::registry::tier_tests` - PASS, 36 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build` - PASS, 1302 passed.

### Live schema repair and chat scroll livelock patch - 2026-05-14

Changed:

- `Epistemos/App/AppBootstrap.swift`: invalid or zero-byte pre-column-repair backups are now replaced before additive schema repair, and a failed preflight repair no longer deletes the live store artifacts.
- `Epistemos/Sync/VaultSyncService.swift`: SQLite backup now writes to a uniquely named temp file and only replaces the destination after a successful backup/copy; SQLite backup retry handling is bounded and no longer sleeps on every successful step.
- `EpistemosTests/RuntimeValidationTests.swift`: verifies invalid pre-column backups are replaced before page-column repair.
- `Epistemos/Views/Chat/ChatView.swift`, `Epistemos/Views/MiniChat/MiniChatView.swift`, `Epistemos/Views/Notes/NoteChatSidebar.swift`: scroll geometry observation emits distance-to-bottom and applies follow-mode hysteresis outside the transform.
- `EpistemosTests/ScrollStabilityTests.swift`, `EpistemosTests/MiniChatViewAuditTests.swift`: source guards prevent reintroducing `@State autoFollow` reads inside scroll geometry transforms.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ScrollStabilityTests -only-testing:EpistemosTests/MiniChatViewAuditTests -only-testing:EpistemosTests/RuntimeValidationTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO` - PASS; still prints the existing non-fatal SwiftLint plugin output-folder failures after `** BUILD SUCCEEDED **`.
- Live store schema check after App Store launch - PASS as noted in Pass 7.
- MAS live-smoke rerun after the scroll patch - pending.

### Main-chat vault lookup fallback after local repair loops - 2026-05-14

Changed:

- `Epistemos/App/ChatCoordinator.swift`: when the direct local pipeline returns an invisible/empty repair-loop error for an explicit vault lookup, main chat now falls back to indexed vault search, appends a visible assistant answer, and persists the completed turn. Other direct-pipeline errors now persist the visible error turn.
- `Epistemos/App/ChatCoordinator.swift`: softer vault-query phrase extraction now recognizes `mention` / `mentions` in addition to `mentioned` / `mentioning`.
- `EpistemosTests/PipelineServiceTests.swift`: added a regression test for the indexed fallback answer used by `What notes in my vault mention train?`.
- `EpistemosTests/RuntimeValidationTests.swift`: added a source guard for the direct-chat fallback/error persistence path.

Verification:

- Failing check first: the new targeted `PipelineServiceTests/softVaultMentionPromptBuildsIndexedFallbackAnswer` failed before implementation because `ChatCoordinator.buildIndexedVaultLookupFallbackAnswer` did not exist.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedFallbackTests -only-testing:EpistemosTests/PipelineServiceTests/softVaultMentionPromptBuildsIndexedFallbackAnswer -only-testing:EpistemosTests/RuntimeValidationTests/directMainChatVaultToolLoopFailuresPersistVisibleTurns test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `git diff --check -- Epistemos/App/ChatCoordinator.swift EpistemosTests/PipelineServiceTests.swift EpistemosTests/RuntimeValidationTests.swift` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosAppStoreGateFallbackPostFormat build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate-after-chat-fallback-postformat scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateFallbackPostFormat/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings scan against `/tmp/EpistemosAppStoreGateFallbackPostFormat/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- MAS manifest narrow `nm -gU` scan against `Contents/Frameworks/libagent_core.dylib` - PASS, no matches.
- MAS live main-chat vault query smoke - PASS for the original blocker: the app remained responsive and persisted visible user + assistant rows for `What notes in my vault mention train?`; manual scroll was required to see the latest answer, so auto-scroll remains a polish/manual-smoke risk.

### Dual-store schema and Notes sidebar invalidation patch - 2026-05-14

Changed:

- `Epistemos/App/AppBootstrap.swift`: repairs both the legacy root SwiftData store and the app-scoped store before opening SwiftData, and verifies required legacy message/page columns after additive repair.
- `Epistemos/Views/Notes/NotesSidebar.swift`: derives folder child-page IDs/pages from active page query snapshots instead of faulting `folder.pages` during cache rebuild.
- `EpistemosTests/RuntimeValidationTests.swift`: covers dual-store page-column repair and guards against reintroducing the two old `folder.pages` cache patterns.

Verification:

- Failing check first: live MAS Notes click created `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-011956.ips`, faulting in `NotesSidebarFolderCacheSignature.init` while reading `SDPage.isArchived` through `folder.pages`.
- `rg -n 'childPageIds = \(folder\.pages|let pages = \(folder\.pages' Epistemos/Views/Notes/NotesSidebar.swift` - PASS after patch, no matches.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedNotesSidebarTests -only-testing:EpistemosTests/RuntimeValidationTests/notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans -only-testing:EpistemosTests/RuntimeValidationTests/bootstrapRepairsLegacyRootAndAppScopedStoresWhenBothExist test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `git diff --check` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosAppStoreGateNotesRepair build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate-notes-repair scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateNotesRepair/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings and narrow `nm -gU` scans against `/tmp/EpistemosAppStoreGateNotesRepair/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- MAS live Notes click rerun - PASS: Notes window opened and no new DiagnosticReports entry appeared after the rerun.

### Note ask-bar vault routing and TextKit line-range clamp - 2026-05-14

Changed:

- `Epistemos/Engine/AgentHarness/ChatCapability.swift`: soft/plural vault lookup prompts now predict `.agent` without forcing a cloud-only warning, so current v1 local and cloud surfaces can use the tool-capable dispatch path.
- `Epistemos/Views/Chat/ChatInputBar.swift`: updated stale warning comments so local v1 tool-capable fallback is not described as cloud-only.
- `Epistemos/Views/Notes/ProseTextView2.swift`: clamps inverted TextKit visible-line ranges before assigning `markdownDelegate.visibleLineRange`.
- `EpistemosTests/ChatCapabilityIntentTests.swift`, `EpistemosTests/TextKit2FoundationTests.swift`: regression tests for soft/plural vault lookup prompts and inverted visible-line ranges.

Verification:

- Failing check first: live MAS note ask-bar vault query misrouted to inline streaming and crashed with `Range requires lowerBound <= upperBound` in `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-014126.ips`.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedNoteAskFix -only-testing:EpistemosTests/ChatCapabilityIntentTests -only-testing:EpistemosTests/TextKit2FoundationTests/visibleLineRangeClampsInvertedFragmentOrder test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `git diff --check -- Epistemos/Engine/AgentHarness/ChatCapability.swift Epistemos/Views/Chat/ChatInputBar.swift Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/ChatCapabilityIntentTests.swift EpistemosTests/TextKit2FoundationTests.swift` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosAppStoreGateNoteAskFix build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate-note-ask-fix scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreGateNoteAskFix/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings and narrow `nm -gU` scans against `/tmp/EpistemosAppStoreGateNoteAskFix/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- MAS live note ask-bar vault escalation rerun - PASS: ask-bar pill switched to `Tools`, submit did not stream into the note or crash, and persisted main-chat rows show the indexed vault answer.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProBuildNoteAskFix build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.

### MAS Release MLX `_popen` mitigation - 2026-05-14

Changed:

- `scripts/patch_mlx_metal_warnings.sh`: also patches fetched `mlx-swift` package checkouts by replacing `JitCompiler::exec()` in `Source/Cmlx/mlx/mlx/backend/cpu/jit_compiler.cpp` with a throwing stub, removing the `popen` reference from the compiled App Store app.
- `scripts/xcodebuild_epistemos.sh`: detects `-derivedDataPath` and `-clonedSourcePackagesDirPath`, resolves Swift packages, and runs the MLX patcher against the active checkout before invoking the real build.
- `EpistemosTests/AppStoreHardeningTests.swift`, `EpistemosTests/ReleaseScriptAuditTests.swift`: source guards for the MLX CPU JIT patch and wrapper patch timing.

Verification:

- `git diff --check -- scripts/patch_mlx_metal_warnings.sh scripts/xcodebuild_epistemos.sh EpistemosTests/AppStoreHardeningTests.swift EpistemosTests/ReleaseScriptAuditTests.swift` - PASS.
- `bash -n scripts/patch_mlx_metal_warnings.sh scripts/xcodebuild_epistemos.sh` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedWrapperPatchTests -only-testing:EpistemosTests/AppStoreHardeningTests/appStoreBuildPatchDisablesMLXCPUJITShellHelper -only-testing:EpistemosTests/ReleaseScriptAuditTests/xcodebuildWrapperPatchesMLXPackageCheckoutsAfterResolution test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/EpistemosAppStoreReleaseWrapperNoPopen CODE_SIGNING_ALLOWED=NO build` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-release-wrapper-nopopen scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreReleaseWrapperNoPopen/Build/Products/Release/Epistemos.app` - PASS.
- MAS manifest narrow strings scan against `/tmp/EpistemosAppStoreReleaseWrapperNoPopen/Build/Products/Release/Epistemos.app` - PASS, no matches.
- MAS manifest narrow `nm -gU` scan against `Contents/Frameworks/libagent_core.dylib` - PASS, no matches.
- Broad undefined import scan against the same Release app - PATCHED PARTIAL: `_popen` is gone; bundled `llama.framework` still imports `_execlp` and `_fork`.

## Current Verdict

Not release-ready. MAS still has an unresolved binary `llama.framework` fork/exec import review risk, note ask-bar simple rewrite smoke remains blocked by user-data safety, Pro cloud-agent smoke is blocked by missing provider keys, and the required five consecutive zero-new-blocker recursive passes have not been completed.
