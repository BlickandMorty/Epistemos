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
| PATCHED | 180 |
| PATCHED PARTIAL | 27 |
| PATCHED BUT NOT CLOSED | 1 |
| PATCHED BUT WATCH | 1 |
| REOPENED | 0 |
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
| V1-GATE-MAS-002 Undefined fork/exec imports | PASS after MAS GGUF exclusion | Packaging / third-party binary framework linkage | MAS broad fork/exec import risk cleared in wrapper-built Release app | Pro GGUF runtime preserved | Clean wrapper Release build at `/tmp/EpistemosAppStoreReleaseNoGGUF/Build/Products/Release/Epistemos.app` has no `llama.framework`, no `_popen`, and broad undefined fork/exec scan returns no matches; Pro build at `/tmp/EpistemosProNoGGUFCheck/Build/Products/Debug/Epistemos.app` still contains `llama.framework` | `./scripts/xcodebuild_epistemos.sh ... -scheme Epistemos-AppStore -configuration Release ... build`; official scanner PASS; manifest narrow scans PASS; broad undefined import scan PASS; Pro build PASS and packages llama | App Store target no longer links `GGUFRuntimeBridge`; MAS scrub removes stray `llama.framework`; Pro target keeps `GGUFRuntimeBridge` | Yes; done |
| V1-GATE-EPDOC-001 EpdocEditorBridge Swift 6 warning | PASS after fix | Epdoc WKURLSchemeHandler | MAS gate cleared for this warning | Pro gate cleared for this warning | `Epistemos/Engine/EpdocEditorBridge.swift:260-266`; assessment `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:25`, `:73` | Both schemes build without the warning; Epdoc targeted tests pass | Fixed with actor-safe URL scheme response delivery | Yes; done in Epdoc fix |
| V1-GATE-VAULT-001 RCA8-P0-003 SwiftData tags crash | PATCHED / MAS+PRO SCRATCH SOAK PASS | Vault / SwiftData lifecycle / instant recall | MAS crash gate has scratch-vault zero-crash evidence; broader user-data soak remains risk-managed/manual | Pro scratch-vault rerun is green; broader user-data soak remains risk-managed/manual | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:53-61`; pre-fix `Epistemos/Sync/VaultIndexActor.swift:2099-2119` now snapshots primitives before awaits; MAS scratch soak evidence below | Zero-crash rerun/soak on App Store and Pro bundles with existing user data untouched | Patched by primitive snapshot before async body reads; MAS and isolated Pro scratch reruns did not crash or report runtime issues | Yes; code patched |
| V1-GATE-VAULT-002 local store schema error | PATCHED / MAS+PRO SCRATCH STORE PASS | SwiftData/CoreData store compatibility | MAS runtime blocker cleared for reproduced Notes-click crash and scratch-vault schema/import path; broader MAS smoke still incomplete | Pro scratch-vault schema/import path is green; broader Pro user-data smoke remains manual | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-50`; read-only schema inspection showed `ZSDPAGE` missing `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE`; repair now runs for both legacy root and app-scoped stores in `Epistemos/App/AppBootstrap.swift:1247`, `:1255`, and verifies required columns at `:1256`; Notes crash stack was `NotesSidebarFolderCacheSignature.init` -> `SDPage.isArchived` at `Epistemos/Views/Notes/NotesSidebar.swift:127` before the cache patch; scratch-store evidence below | Launch MAS/Pro scratch bundles; verify stores contain required columns and Notes opens without audit-bundle crash | Additive, idempotent SQLite column repair before `ModelContainer`, with one-time pre-alter SQLite backup; Notes sidebar avoids inverse `folder.pages` faults and uses active-page query snapshots; no vault reset/delete | Yes; code patched |
| V1-GATE-LIVE-MAS-001 MAS live smoke incomplete | PATCHED/PARTIAL; note simple rewrite remains blocked by data-safety choice | Runtime UI / MAS | MAS blocker until full smoke completes | Pro not covered | `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md:42-51`; Pass 10 note ask-bar crash evidence in `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-14-014126.ips`; Pass 11 graph/settings smoke | Computer Use: settings diagnostics, HELIOS V5 off, Cognitive DAG row, chat `hi`, chat vault query, note ask-bar rewrite/escalation, graph inspector summarize/escalation, graph unchanged screenshots | Main chat, note ask-bar vault escalation, settings diagnostics, graph summarize, graph related-notes escalation, and graph return smoke passed; note ask-bar simple rewrite still not run because it would intentionally mutate a user note without a disposable scratch note | No broad UI changes without reproduced bug |
| V1-GATE-LIVE-PRO-001 Pro live smoke incomplete | PATCHED/PARTIAL; cloud-agent smoke BLOCKED by missing provider keys | Runtime UI / Pro routing | MAS non-blocker | Pro blocker until cloud-key-dependent smoke is resolved or waived | Required by user mission; manifest Pro identity at `docs/MAS_RELEASE_MANIFEST_2026_05_13.md:10-18`; Pass 11 Pro settings/runtime evidence | Computer Use: Pro surfaces, local/cloud routing, provider/tool tiers, no MAS restriction bleed | Pro profile surfaces and local model/tool routing passed; cloud provider/tool-agent smoke blocked because Pro settings report `No provider keys stored` | Yes, only evidence-backed |
| V1-GATE-GRAPH-001 MAS/Pro scratch-vault graph first-open framing | REOPENED / PROTECTED CAMERA PATCH NEEDS APPROVAL | Graph runtime / scratch vault | MAS blocker until first-open graph nodes are visible without manual recovery | Pro blocker until first-open graph nodes are visible without manual recovery | Isolated scratch stores have `5` graph nodes and `4` graph edges; the graph overlay opens with nodes off-screen/too small, but the existing Zoom to Fit control immediately reveals the same five nodes. Screenshots: `build/live-smoke-evidence/mas-vault-soak-graph-spinner-after35s-2026-05-14.png`, `build/live-smoke-evidence/mas-vault-soak-graph-after-zoom-fit-2026-05-14.png` | Reproduce with scratch vault, then patch the initial global camera/framing path only after explicit graph-surface approval | Evidence points to camera/bootstrap framing, not vault data, SwiftData schema, or graph-store load. No graph renderer/layout/physics code touched yet. | No, until approval for protected graph camera/bootstrap patch scope |
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

### Pass 13 - 2026-05-14

Result: the MAS broad fork/exec import risk is cleared by excluding the GGUF/llama runtime from the App Store target while preserving it in Pro. Zero-streak remains 0 because note ask-bar simple rewrite remains blocked by user-data safety, Pro cloud-agent smoke remains blocked by missing provider keys, and five consecutive recursive passes are still incomplete.

- `V1-GATE-MAS-002`: PASS. The App Store target no longer links `GGUFRuntimeBridge`, and the App Store scrub phase now removes any stray `llama.framework`. Source evidence: `project.yml:207-226`, `Epistemos.xcodeproj/project.pbxproj:406-416`, `:649-657`, and `EpistemosTests/AppStoreHardeningTests.swift:366-392`.
- Pro/direct preservation evidence: the Pro target still declares `GGUFRuntimeBridge` in `project.yml:121-122`; `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProNoGGUFCheck build CODE_SIGNING_ALLOWED=NO -quiet` passed, and `/tmp/EpistemosProNoGGUFCheck/Build/Products/Debug/Epistemos.app/Contents/Frameworks/llama.framework` exists.
- Clean MAS Release verification: `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/EpistemosAppStoreReleaseNoGGUF CODE_SIGNING_ALLOWED=NO build` passed.
- Official MAS scanner passed against `/tmp/EpistemosAppStoreReleaseNoGGUF/Build/Products/Release/Epistemos.app` and wrote reports to `build/codex-appstore-release-no-gguf`.
- MAS manifest narrow strings scan passed with no prohibited exact command-path strings. MAS manifest narrow `nm -gU` scan against `Contents/Frameworks/libagent_core.dylib` passed with no prohibited symbols.
- Broad undefined import scan against the same clean MAS Release app returned no `_fork`, `_execv`, `_execvp`, `_execl`, `_execlp`, `_posix_spawn`, `_posix_spawnp`, `_system`, or `_popen` matches. `llama.framework` is absent from the MAS bundle and `otool -L Contents/MacOS/Epistemos` reports no `llama`/`GGUFRuntimeBridge` linkage.
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

### MAS GGUF/llama exclusion with Pro preservation - 2026-05-14

Changed:

- `project.yml`, `Epistemos.xcodeproj/project.pbxproj`: removed `GGUFRuntimeBridge` from only the `Epistemos-AppStore` target and added `llama.framework` to the MAS scrub phase. The Pro `Epistemos` target still links `GGUFRuntimeBridge`.
- `EpistemosTests/AppStoreHardeningTests.swift`: added a source guard that the App Store target does not link the GGUF/llama runtime while Pro keeps it.

Verification:

- Failing check first: the broad undefined import scan on the prior clean Release app reported `Contents/Frameworks/llama.framework/Versions/A/llama:_execlp` and `:_fork`.
- `git diff --check -- project.yml Epistemos.xcodeproj/project.pbxproj EpistemosTests/AppStoreHardeningTests.swift` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTargetedNoGGUFMasTest -only-testing:EpistemosTests/AppStoreHardeningTests/appStoreTargetDoesNotLinkGGUFLlamaRuntime test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/EpistemosAppStoreReleaseNoGGUF CODE_SIGNING_ALLOWED=NO build` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-release-no-gguf scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreReleaseNoGGUF/Build/Products/Release/Epistemos.app` - PASS.
- MAS manifest narrow strings and narrow `nm -gU` scans against `/tmp/EpistemosAppStoreReleaseNoGGUF/Build/Products/Release/Epistemos.app` - PASS, no matches.
- Broad undefined import scan against `/tmp/EpistemosAppStoreReleaseNoGGUF/Build/Products/Release/Epistemos.app` - PASS, no matches.
- MAS bundle `llama.framework` presence/linkage check - PASS: `llama.framework` absent and `otool -L Contents/MacOS/Epistemos` shows no llama/GGUF linkage.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProNoGGUFCheck build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- Pro bundle GGUF preservation check - PASS: `/tmp/EpistemosProNoGGUFCheck/Build/Products/Debug/Epistemos.app/Contents/Frameworks/llama.framework` exists.

### Pro/cloud managed agent tool budget - 2026-05-14

Changed:

- `Epistemos/App/ChatCoordinator.swift`: added `cloudToolBudget(...)` so current v1 cloud tool routing is explicit and testable. Pro cloud turns now use `chat_pro` with 3 max turns in both the direct cloud branch and promoted `managedAgentSession` branch.
- `Epistemos/App/ChatCoordinator.swift`: kept Fast/Thinking cloud direct turns on `chat_lite` with 1 max turn, while Fast/Thinking turns promoted to `managedAgentSession` retain the full Agent tier so explicit tool-required requests can still execute.
- `EpistemosTests/ProCloudToolLoopGuardTests.swift`: updated stale source-string guards to assert the real budget helper behavior and the managed-branch `toolTier`/`maxTurns` handoff.

Verification:

- Failing check first: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentToolBudgetTests -only-testing:EpistemosTests/ProCloudToolLoopGuardTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL before patch because the old guard still expected literal `toolTier: "chat_pro"`/`maxTurns: 3` in the direct branch and did not cover promoted managed plans.
- `git diff --check -- Epistemos/App/ChatCoordinator.swift EpistemosTests/ProCloudToolLoopGuardTests.swift` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentToolBudgetTests -only-testing:EpistemosTests/ProCloudToolLoopGuardTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentToolBudgetTests -only-testing:EpistemosTests/ProCloudToolLoopGuardTests -only-testing:EpistemosTests/PipelineServiceTests/cloudFastToolPromptsUseManagedAgentSession -only-testing:EpistemosTests/PipelineServiceTests/proModeUsesChatProToolTier test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProAgentToolBudgetBuild build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosMASAgentToolBudgetBuild build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-agent-tool-budget scripts/scan_appstore_bundle.sh /tmp/EpistemosMASAgentToolBudgetBuild/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings scan and narrow `nm -gU` scan against `/tmp/EpistemosMASAgentToolBudgetBuild/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- `./scripts/xcodebuild_epistemos.sh -quiet -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/EpistemosAppStoreReleaseAgentToolBudget CODE_SIGNING_ALLOWED=NO build` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-release-agent-tool-budget scripts/scan_appstore_bundle.sh /tmp/EpistemosAppStoreReleaseAgentToolBudget/Build/Products/Release/Epistemos.app` - PASS.
- MAS manifest narrow strings scan, narrow `nm -gU` scan, and refined broad undefined import scan against `/tmp/EpistemosAppStoreReleaseAgentToolBudget/Build/Products/Release/Epistemos.app` - PASS, no matches.
- `cargo test --manifest-path agent_core/Cargo.toml --lib` - PASS, 1089 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build` - PASS, 1302 passed.
- `cargo test --manifest-path epistemos-research/Cargo.toml --features research` - PASS, 492 lib tests, 113 canonical consistency tests, 0 doctests.

### Native approval gate for read-only network tools - 2026-05-14

Changed:

- `Epistemos/Bridge/StreamingDelegate.swift`: read-only network/web research tools (`web.search`, `web.fetch`, `web.extract`, `web.crawl`, and supported legacy backend names) now set `requiresHumanApproval` so they enter the native approval queue instead of bypassing the authority gate as generic read-only tools.
- `Epistemos/Bridge/StreamingDelegate.swift`: read-only Pro browser inspection tools (`browser_snapshot`, `browser_get_images`, `browser_vision`, `browser_console`) also enter the approval gate; internal non-network generic read tools such as `think` still auto-approve.
- `Epistemos/Engine/AgentHarness/AgentAuthority.swift`: authority categorization now names `web.crawl` as Network Fetch and the read-only browser tools as external app automation.
- `EpistemosTests/AgentPermissionRequestTests.swift`, `EpistemosTests/PipelineServiceTests.swift`: added regressions for native approval on `web.search` and for preserving auto-approval on non-network generic reads.

Verification:

- Failing check first: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentPermissionGateTests -only-testing:EpistemosTests/AgentPermissionRequestTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL before product patch. Failure summary: `AgentPermissionRequestTests.webSearchRoutesThroughNativeApprovalGate()` at `EpistemosTests/AgentPermissionRequestTests.swift:32`; `request.requiresHumanApproval` was `false` for `web.search`.
- `git diff --check -- Epistemos/Bridge/StreamingDelegate.swift Epistemos/Engine/AgentHarness/AgentAuthority.swift EpistemosTests/AgentPermissionRequestTests.swift EpistemosTests/PipelineServiceTests.swift` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentPermissionGateTests -only-testing:EpistemosTests/AgentPermissionRequestTests -only-testing:EpistemosTests/PipelineServiceTests/observedLocalToolExecutorGatesReadOnlyNetworkFetches test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosProApprovalGateBuild build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosMASApprovalGateBuild build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-approval-gate scripts/scan_appstore_bundle.sh /tmp/EpistemosMASApprovalGateBuild/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings scan and narrow `nm -gU` scan against `/tmp/EpistemosMASApprovalGateBuild/Build/Products/Debug/Epistemos.app` - PASS, no matches.

### Managed Rust agent read-approval delegation guard - 2026-05-14

Changed:

- `EpistemosTests/AuditFixRegressionTests.swift`: added a source regression proving both `runCommandCenterRustAgentPath` and `runRustAgentPath` pass `autoApproveReads: false`/`autoApproveWrites: false` into `AgentConfigFFI`, so read-only web/tool calls still surface through Swift's native approval queue.
- `agent_core/src/agent_loop.rs`: added a Rust unit regression proving `resolve_approval_requirement` still emits an approval requirement for `RiskLevel::ReadOnly` when read auto-approval is disabled.

Verification:

- `git diff --check -- EpistemosTests/AuditFixRegressionTests.swift agent_core/src/agent_loop.rs` - PASS.
- `cargo test --manifest-path agent_core/Cargo.toml --lib read_only_tools_require_approval_when_read_auto_approval_is_disabled` - PASS, 1 passed, 1089 filtered out.
- First Swift targeted attempt was BLOCKED by `/tmp` derived-data exhaustion: `No space left on device` while building Swift package objects under `/tmp/EpistemosAgentApprovalDelegationTests`.
- Removed only Epistemos-named `/tmp` build artifacts, freeing about 205 GiB; no source, vault, graph, or user data paths were touched.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentApprovalDelegationTests -only-testing:EpistemosTests/AuditFixRegressionTests/managedRustAgentEntryPointsKeepReadApprovalsDelegatedToSwift test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.

### Agent/tool routing follow-up checks - 2026-05-14

Changed:

- No production code changed in this follow-up. This pass verifies the user's reopened priority that local and cloud agents/tool use must work, including deterministic local tool behavior.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentApprovalDelegationTests -only-testing:EpistemosTests/LocalAgentLoopTests/reflexModeInjectsMissingToolStepsUntilRequiredReadWriteSequenceCompletes -only-testing:EpistemosTests/LocalAgentLoopTests/reflexModeRejectsExamplePathToolDriftUntilExactRequestedFilePathIsUsed -only-testing:EpistemosTests/LocalAgentLoopTests/reflexModeRejectsExamplePathDriftForExplicitAbsoluteFilesystemPaths test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosAgentApprovalDelegationTests -only-testing:EpistemosTests/PipelineServiceTests/cloudManifestIncludesProviderNativeWebSearch -only-testing:EpistemosTests/PipelineServiceTests/cloudFastToolPromptsUseManagedAgentSession -only-testing:EpistemosTests/PipelineServiceTests/proModeUsesChatProToolTier -only-testing:EpistemosTests/PipelineServiceTests/explicitLocalWebSearchQueriesUseToolCapableRoute -only-testing:EpistemosTests/ProCloudToolLoopGuardTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- Local deterministic coverage: `LocalAgentLoop` reflex mode forces the required read/write tool sequence, rejects example-path drift, and rejects absolute-path drift before allowing the loop to complete.
- Cloud/tool routing coverage: fake-key/in-memory tests prove provider-native web-search manifest wiring, Pro `chat_pro` tool tier selection, Fast cloud managed-agent escalation for explicit tool prompts, and local web-search prompt routing. These checks do not prove live provider calls on this machine.

### Isolated Pro and MAS live-smoke continuation - 2026-05-14

Changed:

- No production source changed. This pass used isolated audit bundles and app-support roots to avoid attaching or mutating the user's normal vault.

Pro/direct smoke:

- Prepared Pro audit bundle at `/Users/jojo/Downloads/Epistemos/build/audit-app/EpistemosAudit.app`, bundle id `com.epistemos.audit`, app data `/Users/jojo/Downloads/Epistemos/build/audit-app-support`.
- Launched Pro audit app and selected `Continue Without a Vault`. Result: first-run no-vault path rendered; no user vault was attached.
- Settings diagnostics rendered. Runtime truth reported Pro deployment, no active vault, Cognitive DAG `0 nodes, 0 edges, schema version 1`, no provider keys stored, and Pro-only surfaces enabled: CLI passthrough, Channels, Knowledge Fusion, iMessage Driver, Skills, NightBrain LaunchAgent, AX/computer-use, and Bash/MultiEdit/WebFetch local tools.
- Pro Agent settings rendered with MCP tool plane: `40 tools`, `0 executions`, `4 approvals`; Authority defaults showed file access outside vault `Ask first`, network fetch `Ask first`, destructive file operations `Ask first`, and system/protected paths `Never`.
- Pro mini chat initially blocked on `Set Up Model` in the isolated app-support root. Copied only the production model manifest into the isolated support root, then symlinked the isolated DeepSeek active-model slot to the existing production DeepSeek model directory so the smoke could read installed model weights without attaching a vault.
- Pro mini chat then selected `Tools/Thinking - R1 7B`. Fast mode correctly rejected DeepSeek R1 with the user-facing guard that this model always emits thinking traces. Thinking mode reached local model resolution and failed at memory preflight: `DeepSeek R1 7B needs about 12 GB of free memory but only 5 GB is available right now`.
- Pro cloud live execution remains BLOCKED: no OpenAI/Anthropic/Google provider account or API key is available in the isolated app (`No provider keys stored`).

MAS smoke:

- Built exact MAS Debug app with `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath build/audit-appstore-derived-data build CODE_SIGNING_ALLOWED=NO` - PASS.
- Cloned that product into `/Users/jojo/Downloads/Epistemos/build/audit-appstore-app/EpistemosMASAudit.app`, bundle id `com.epistemos.audit.mas`, app data `/Users/jojo/Downloads/Epistemos/build/audit-appstore-support`.
- MAS onboarding rendered. Skipped vault, local model setup, and cloud provider setup. Continued without a vault; no user vault was attached.
- MAS Settings diagnostics rendered. Runtime truth reported `Mode Fast`, `Provider Local - Qwen/Qwen3-4B-MLX-4bit`, `Capability Local - Running on-device. Fast replies, no tools, no network`, `Tool loop Local direct stream`, and `Subprocess CLIs are not available in this build`.
- MAS deployment profile rendered as `App Store (MAS sandbox)` with Pro-only surfaces listed as not available: CLI passthrough, Channels, Knowledge Fusion, iMessage Driver, Skills, NightBrain LaunchAgent, AX/computer-use, and Bash/MultiEdit/WebFetch local tools.
- MAS Agent authority settings rendered without the Pro `Less Interruptions` posture and with network fetch `Ask first`, file access outside vault `Ask first`, destructive file operations `Ask first`, and system/protected paths `Never`.
- MAS mini chat rendered and stayed disabled with `Fast - Set Up Model`; no tool/chat generation was attempted because the isolated MAS support root has no installed model or provider key.
- MAS graph view opened to the no-vault empty canvas and toolbar without crashing. No graph code or graph state was changed.

Verification:

- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-live-mas-2026-05-14 scripts/scan_appstore_bundle.sh build/audit-appstore-derived-data/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings scan against `build/audit-appstore-derived-data/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- MAS manifest narrow `nm -gU` scan against `build/audit-appstore-derived-data/Build/Products/Debug/Epistemos.app/Contents/Frameworks/libagent_core.dylib` - PASS, no matches.
- MAS built product bundle id check: `com.epistemos.appstore`.

### Note ask-bar rewrite verification follow-up - 2026-05-14

Changed:

- No production source changed. This pass separated automated note rewrite coverage from the still-blocked live MAS scratch-vault smoke.

Verification:

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosNoteAskRewriteVerification -only-testing:EpistemosTests/NoteChatStateTests/toolbarAskStreamsInlineAndAutoCommits -only-testing:EpistemosTests/NoteChatStateTests/operationSubmitRoutesThinkTagsAwayFromInlineEditor -only-testing:EpistemosTests/TriageServiceTests/notesSimpleOperationsUseAppleIntelligence -only-testing:EpistemosTests/TriageServiceTests/notesGenerateUsesLocalPath test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- Automated coverage proves the simple note ask-bar rewrite path streams inline, auto-commits through `NoteChatState`, routes think-tag output away from the inline editor, and classifies simple note operations onto the expected local/Apple Intelligence path.

Live MAS scratch-vault smoke:

- BLOCKED by vault-safety constraints in this environment. The isolated MAS audit app correctly rejected a CLI-created bookmark for `build/live-smoke-scratch-vault` as not security-scoped, which confirms the sandbox gate is active.
- A Computer Use file-picker attempt did not reliably navigate to the scratch folder and instead selected the currently open user vault location. The app was killed before any note rewrite or note mutation was executed.
- No source, graph files, or user vault note content was changed. Runtime-only scratch files under `build/` were used for this attempt.

### First-run appearance default and live readable-font toggle - 2026-05-14

Changed:

- `Epistemos/State/UIState.swift`: fresh installs now default to `.custom` theme mode and the `.platinumViolet` theme pair. Legacy stored `.systemDefault` theme mode is migrated to `.custom` without discarding the stored theme pair, so users no longer land in the native "Follows macOS" appearance on first launch.
- `Epistemos/Views/Settings/SettingsView.swift`: removed the visible Follow macOS/System appearance section from Appearance settings. Theme cards now select directly into app themes, and the selected state follows the active pair.
- `Epistemos/Views/Settings/SettingsView.swift`: removed the restart-based Regular Mode control and replaced it with a live `Readable fonts` toggle under Typography.
- `Epistemos/Theme/EpistemosTheme.swift`: replaced `AppDisplayMode` with `AppDisplayTypography.readableFontsEnabled`, migrated the old `epistemos.display.mode = regular` preference, and routes display-font helpers to Avenir Next when readable fonts are enabled, falling back to system UI fonts if Avenir Next is unavailable.
- `Epistemos/App/AppBootstrap.swift`: removed the relaunch-based display-mode application path.
- `Epistemos/App/RootView.swift`, `Epistemos/Views/Shell/PageShell.swift`, `Epistemos/Theme/PhysicsModifiers.swift`: removed Regular Mode animation suppression, kept landing display behavior intact, and added a root-level observation hook so readable-font changes redraw live without using `.id(...)` resets that would disturb graph/navigation identity.
- `Epistemos/Resources/Localizable.xcstrings`: removed obsolete Regular Mode/restart strings.
- No graph rendering files were edited.

Verification:

- Failing check first: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosThemeDefaultBeforeFix -only-testing:EpistemosTests/ThemePairTests -only-testing:EpistemosTests/ThemePickerRestorationTests test CODE_SIGNING_ALLOWED=NO -quiet` - FAIL before product patch because fresh `UIState` still restored system-default appearance semantics and source guards still expected the old Settings surface.
- `rg -n "AppDisplayMode|Regular Mode|applyDisplayModeAndRelaunch|Restart to Apply Display Mode|ui\.displayMode|setDisplayMode" Epistemos EpistemosTests` - PASS for production/test source. Remaining hits are negative test assertions and generated MOHAWK training-data artifacts, which are not current shipping UI code.
- `git diff --check -- Epistemos/State/UIState.swift Epistemos/Views/Settings/SettingsView.swift Epistemos/Theme/EpistemosTheme.swift Epistemos/App/AppBootstrap.swift Epistemos/App/RootView.swift Epistemos/Views/Shell/PageShell.swift Epistemos/Theme/PhysicsModifiers.swift Epistemos/Resources/Localizable.xcstrings EpistemosTests/ThemePairTests.swift EpistemosTests/ThemePickerRestorationTests.swift` - PASS.
- `jq empty Epistemos/Resources/Localizable.xcstrings` - PASS. `plutil -lint` does not parse this checkout's `.xcstrings` JSON file and reports `Unexpected character { at line 1`, so JSON validation is the resource integrity check for this file.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosThemeDefaultAfterFix2 -only-testing:EpistemosTests/ThemePairTests -only-testing:EpistemosTests/ThemePickerRestorationTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosMASAppearanceBuild build CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-appearance-2026-05-14 scripts/scan_appstore_bundle.sh /tmp/EpistemosMASAppearanceBuild/Build/Products/Debug/Epistemos.app` - PASS.
- MAS manifest narrow strings scan against `/tmp/EpistemosMASAppearanceBuild/Build/Products/Debug/Epistemos.app` - PASS, no matches.
- MAS manifest narrow `nm -gU` scan against `/tmp/EpistemosMASAppearanceBuild/Build/Products/Debug/Epistemos.app/Contents/Frameworks/libagent_core.dylib` - PASS, no matches.
- Live MAS smoke used `/Users/jojo/Downloads/Epistemos/build/audit-appearance-app/EpistemosAppearanceAudit.app`, bundle id `com.epistemos.audit.appearance`, and app data `/Users/jojo/Downloads/Epistemos/build/audit-appearance-support`. First-run setup skipped vault/model/cloud without attaching a vault. Settings > Appearance showed Platinum Violet selected by default, no Follow macOS/System section, and `Readable fonts` toggled on live without restart. Defaults confirmed `epistemos.theme.pair = platinumViolet`, `epistemos.theme.mode = custom`, and `epistemos.typography.readableFontsEnabled = 1`.
- Screenshot evidence: `build/live-smoke-evidence/mas-appearance-default-readable-toggle-2026-05-14.png`.

### MAS scratch-vault RCA8/schema soak and graph protected evidence - 2026-05-14

Changed:

- No source code changed in this pass. The pass used the isolated MAS audit bundle `/Users/jojo/Downloads/Epistemos/build/audit-vaultsoak-mas-app/EpistemosMASVaultSoak.app`, bundle id `com.epistemos.audit.vaultsoak.mas`, app data `/Users/jojo/Downloads/Epistemos/build/audit-vaultsoak-mas-support`, and scratch vault `/Users/jojo/Downloads/Epistemos/build/vault-soak-scratch-vault`.
- No user vault files were reset, deleted, migrated, or mutated. Scratch-vault setup imported five markdown notes with wikilinks/tags.
- No graph rendering, Metal/SDF renderer, layout, camera, physics, selection, or hologram files were edited.

Verification:

- Targeted vault release-gate tests: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosVaultReleaseGateTests -only-testing:EpistemosTests/RuntimeValidationTests/bootstrapAdoptsLegacyRootStoresIntoAppScopedPathAndRepairsMessageColumns -only-testing:EpistemosTests/RuntimeValidationTests/bootstrapReplacesInvalidPreColumnBackupsBeforeRepairingPageColumns -only-testing:EpistemosTests/RuntimeValidationTests/bootstrapRepairsLegacyRootAndAppScopedStoresWhenBothExist -only-testing:EpistemosTests/RuntimeValidationTests/instantRecallRebuildSnapshotsSwiftDataPagePrimitivesBeforeAwaitingBodyReads -only-testing:EpistemosTests/RuntimeValidationTests/notesSidebarCacheRebuildObservesFolderStructureAndOffloadsEpdocScans -only-testing:EpistemosTests/RuntimeValidationTests/instantRecallRebuildLeavesTheHeavyVaultWatcherWorkOffTheMainActor test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- Live MAS scratch-vault import completed: `Vault ready: 5/5 files`, `Result: 5 new, 0 updated, 0 unchanged, 0 deleted`, `Diagnostics: 0 unreadable, 0 failed, 0 duplicate tracked paths`.
- Live MAS Notes opened scratch-vault notes and rendered `Vault Soak Note 1` without a new crash.
- `find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f -name 'Epistemos*' -mmin -30 -print` - PASS, no new crash reports.
- Runtime diagnostics summary `build/audit-vaultsoak-mas-support/Epistemos/runtime_diagnostics/2026-05-14-summary.json` reported `"issues": []`.
- Scratch SwiftData store read-only check: `SELECT COUNT(*) FROM ZSDPAGE;` - PASS, `5`.
- Scratch SwiftData schema read-only check confirmed `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE` are present on `ZSDPAGE`.
- Scratch search index read-only check: `(indexed_pages, indexed_blocks, readable_blocks)` - PASS, `5|0|0`.
- Reopened graph from the same scratch-vault MAS audit app. Result: REOPENED/BLOCKED. The graph stayed on the red loading spinner immediately after launch and after a 35-second dwell. Screenshot evidence: `build/live-smoke-evidence/mas-vault-soak-graph-spinner-2026-05-14.png` and `build/live-smoke-evidence/mas-vault-soak-graph-spinner-after35s-2026-05-14.png`.
- Because graph rendering is protected, this pass documents evidence only. Any patch touching graph rendering/layout/camera/physics/selection/overlay requires explicit approval before editing those files.

### Agent/tool executable surface closure - 2026-05-14

Changed:

- `Epistemos/Bridge/ToolTierBridge.swift`: MAS-visible tool aliases now canonicalize the note/research/composer surfaces consistently, Pro-only delegation/model-loop/skill-management tools stay out of the MAS allowlist, and Rust `modification` risk now maps to Swift `requiresConfirmation` instead of only `destructive`.
- `agent_core/src/tools/registry.rs`, `agent_core/src/tools/note_tools.rs`, `agent_core/src/tools/web.rs`, and `agent_core/src/tools/knowledge.rs`: tools that were previously catalog-visible but inert in the real chat executor now have executable Rust handlers for `vault.list`, `note.create`, `note.edit`, `research.collect_snippet`, `research.search_papers`, `citation.save`, and `knowledge.evidence_score`.
- `Epistemos/App/ChatCoordinator.swift`, `Epistemos/Bridge/StreamingDelegate.swift`, and `agent_core/src/resources/tool_authz.rs`: approved vault-note write requests now derive matching R.5 `vault://.../note/...` resource grants for note templates, note create/edit, research snippet collection, and citation saving before Rust enforces resource writes.
- `Epistemos/Engine/AgentHarness/ChatCapability.swift`: soft first-person vault lookup prompts such as `what did I write about graph rendering?` now route to the local/cloud tool-capable path instead of plain chat.
- `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` and `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md`: MAS tool inventory updated to reflect executable note/research tools and native approval/R.5 gating.
- No graph rendering files were edited. No user vault/database files were reset, deleted, migrated, or mutated.

Failing checks first:

- Targeted Swift parity failed before the `knowledge.evidence_score` Rust handler because `ToolSurfacePolicy.coreAppStoreAllowedToolNames` referenced a Rust tool that did not exist at any tier.
- The same parity run showed stale test policy for `web_fetch`; MAS manifest allows canonical `web.fetch` over HTTPS, so the legacy alias now canonicalizes into the allowed surface instead of being treated as hidden.
- The broader Swift batch then failed on `ChatCapabilityIntentTests/softPluralVaultLookupPromptsPredictAgentIntent()` because `what did i write about graph rendering?` predicted `.local` instead of `.agent`.

Verification:

- `git diff --check` - PASS.
- `cargo test --manifest-path agent_core/Cargo.toml --lib tools::knowledge::tests::` - PASS, 12 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib tier_tests::` - PASS, 38 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib resources::tool_authz::tests` - PASS, 25 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib note_tools::tests::` - PASS, 10 passed.
- `xcodebuild ... -only-testing:EpistemosTests/AgentPermissionRequestTests -only-testing:EpistemosTests/ToolSurfacePolicyTests -only-testing:EpistemosTests/ToolTierCrossRuntimeParityTests -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests/toolTierBridgeCoreAllowlistIsInProcess test CODE_SIGNING_ALLOWED=NO -quiet` - PASS, 21 passed.
- `xcodebuild ... -only-testing:EpistemosTests/ChatCapabilityIntentTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS after classifier fix.
- `xcodebuild ... -only-testing:EpistemosTests/AppStoreHardeningTests/appStoreSourceCannotCanImportGGUFRuntimeFromSharedDerivedData -only-testing:EpistemosTests/ReleaseScriptAuditTests/xcodebuildWrapperPatchesMLXPackageCheckoutsAfterResolution -only-testing:EpistemosTests/ToolSurfacePolicyTests -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests/toolTierBridgeCoreAllowlistIsInProcess -only-testing:EpistemosTests/ToolTierCrossRuntimeParityTests -only-testing:EpistemosTests/ChatCapabilityIntentTests -only-testing:EpistemosTests/AgentPermissionRequestTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS, 32 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib` - PASS, 1098 passed.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build` - PASS, 1311 passed.
- `cargo test --manifest-path epistemos-research/Cargo.toml --features research` - PASS, 492 unit tests and 113 canonical-consistency tests passed.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosV1ProBuildPostAgentTools build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; known MLX C++17 warnings only.
- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/EpistemosV1MASBuildPostAgentTools build CODE_SIGNING_ALLOWED=NO -quiet` - PASS; wrapper patched the MLX Metal warning and MLX CPU JIT shell helper before build.
- `EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-agent-tools-2026-05-14 scripts/scan_appstore_bundle.sh /tmp/EpistemosV1MASBuildPostAgentTools/Build/Products/Debug/Epistemos.app` - PASS; no prohibited runtime strings, symbols, research residues, or tool residues.
- MAS manifest narrow strings scan against `/tmp/EpistemosV1MASBuildPostAgentTools/Build/Products/Debug/Epistemos.app` - PASS, no matches for exact forbidden executable paths.
- MAS manifest narrow `nm -gU` scan against `/tmp/EpistemosV1MASBuildPostAgentTools/Build/Products/Debug/Epistemos.app/Contents/Frameworks/libagent_core.dylib` - PASS, no forbidden process-launch symbols.

### Sidebar and graph-note glass polish - 2026-05-14

Changed:

- `Epistemos/App/UtilityWindowManager.swift`: the Notes utility panel now uses transparent Mini Chat-style window chrome (`isOpaque = false`, clear background, transparent hosted layer) so SwiftUI material can blur what is actually behind the window instead of an opaque panel backing.
- `Epistemos/Views/Notes/NotesSidebar.swift`: the Notes sidebar now uses real material plus the Mini Chat light/dark tint ratios `Color.white.opacity(0.55)` and `Color.black.opacity(0.32)`, with the extra painted gradient removed and pixel dither reduced so the surface reads as see-through glass rather than fake blur.
- `Epistemos/Views/Graph/GraphNotePage.swift`: graph-launched note editing now inherits `GraphWorkspaceContainer`'s existing graph-page blur; the separate graph-note wallpaper/tint layer was removed so the transparent editor sits on the same graph blur already used by that workspace route.
- `Epistemos/Views/Notes/ProseEditorView.swift` and `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`: the shared TextKit editor only becomes transparent when `navigationContext == .graph`; normal note tabs keep the existing solid editor background.
- No graph renderer, Metal/SDF renderer, node layout, edge geometry, selection visuals, camera behavior, graph physics, vault schema, or vault data code was changed.

Verification:

- `git diff --check` - PASS.
- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosSidebarGraphGlassTests -only-testing:EpistemosTests/SidebarShellValidationTests test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosNotesSidebarRealGlassTests -only-testing:EpistemosTests/NoteWindowManagerTests/notesUtilityWindowUsesCustomChrome -only-testing:EpistemosTests/SidebarShellValidationTests/notesSidebarSharesMiniChatFrostGlassAndPixelAccents -only-testing:EpistemosTests/SidebarShellValidationTests/graphNoteEditorInheritsGraphWorkspaceBlurWithoutChangingNormalNoteTabs test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.

### Graph note route true transparency follow-up - 2026-05-14

Changed:

- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift`: the graph note route now uses `graphNoteBackdrop` (`Color.clear`) instead of the shared full-page `.ultraThinMaterial` backdrop. Folder routes keep the existing material page backdrop.
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`: the graph-only transparent editor mode now clears the entire AppKit scroll stack (`NSScrollView`, clip view, enclosing scroll view, and `ProseTextView2`) on make/update/theme-change. Normal notes still do not pass `usesTransparentEditorBackground: true`.
- `EpistemosTests/SidebarShellValidationTests.swift`: source guard tightened so graph notes inherit the graph panel backdrop rather than painting a themed page slab.
- No graph renderer, Metal/SDF renderer, node layout, edge geometry, selection visuals, camera behavior, graph physics, vault schema, or vault data code was changed.

Verification:

- `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosGraphNoteBlurTests -only-testing:EpistemosTests/SidebarShellValidationTests/graphNoteEditorInheritsGraphWorkspaceBlurWithoutChangingNormalNoteTabs test CODE_SIGNING_ALLOWED=NO -quiet` - PASS.
- `./scripts/launch_audit_app.sh --no-launch` - PASS; built a fresh isolated Pro audit app from the patched source.
- Seeded only isolated `com.epistemos.audit` defaults with the scratch vault `/Users/jojo/Downloads/Epistemos/build/vault-soak-scratch-vault`; no user vault content was attached.
- Read-only scratch store check after launch: `ZSDPAGE=5`, `ZSDGRAPHNODE=5`, `ZSDGRAPHEDGE=4`.
- Live graph route could not be opened through the sidebar list because those rows only select/isolate nodes; the route transparency is therefore verified by source guard plus fresh compile. The remaining live graph blocker is the first-open camera/framing issue tracked as `V1-GATE-GRAPH-001`.

### Pro scratch-vault RCA8/schema rerun - 2026-05-14

Changed:

- No production source changed for this pass. It used the isolated Pro audit bundle `/Users/jojo/Downloads/Epistemos/build/audit-app/EpistemosAudit.app`, bundle id `com.epistemos.audit`, app data `/Users/jojo/Downloads/Epistemos/build/audit-app-support`, and scratch vault `/Users/jojo/Downloads/Epistemos/build/vault-soak-scratch-vault`.
- Seeded only the isolated audit defaults with a plain non-MAS bookmark for the scratch vault, then launched the audit bundle with `EPISTEMOS_SKIP_VAULT_RESTORE=0`. The normal app domain and user vault were not attached.
- A Computer Use misclick created `New Note.md` in the scratch vault only. The file was removed from `build/vault-soak-scratch-vault`; no user vault content was touched.

Verification:

- Pro audit Notes opened and listed `Vault Soak Note 1` through `Vault Soak Note 5` from `VAULT-SOAK-SCRATCH-VAULT`.
- Isolated Pro SwiftData store read-only check: `SELECT count(*), sum(case when ZFILEPATH is not null and length(ZFILEPATH)>0 then 1 else 0 end) FROM ZSDPAGE;` - PASS before the scratch-only misclick, `5|5`.
- Isolated Pro SwiftData schema read-only check confirmed `ZWIKILINKREFERENCES` and `ZWIKILINKREFERENCESCANSIGNATURE` are present on `ZSDPAGE`.
- Isolated Pro search index read-only check: `(indexed_pages, indexed_blocks, readable_blocks)` - PASS, `5|0|0`.
- Runtime diagnostics summary `build/audit-app-support/Epistemos/runtime_diagnostics/2026-05-14-summary.json` reported `"issues": []`.
- DiagnosticReports entries observed during this window were `com.epistemos.appstore` missing-`llama.framework` dyld reports from an unrelated DerivedData App Store debug product, not the isolated Pro audit bundle. The Pro audit process stayed alive through the vault/schema checks.
- `V1-GATE-VAULT-001` and `V1-GATE-VAULT-002`: Pro/direct scratch rerun evidence is now PASS for the isolated five-note vault path.

### Recursive register reconciliation - 2026-05-14

Changed:

- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`: reconciled stale reopened release-gate statuses with current verification evidence. RCA8-P1-004, RCA9-P0-002, and RCA12-P0-002 are now marked `PATCHED-2026-05-14`; RCA8-P0-003 is now `PATCHED-2026-05-14 / MAS+PRO SCRATCH SOAK PASS`.
- Updated the snapshot count above from `REOPENED = 4` to `REOPENED = 0` and `PATCHED = 180`. Remaining release blockers are runtime/live-smoke gates, not stale reopened artifact/Epdoc entries.

Verification:

- `rg -n "Status: (REOPENED|SOURCE REOPENED|OPEN|PATCHED PARTIAL|DEFERRED|TODO)|reopened|REOPENED" docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` - PASS for release-gate reconciliation; only the historical prose, one source-reopened runtime-smoke item, one `OPEN`, and non-release `PATCHED PARTIAL`/`DEFERRED` items remain.
- `git diff --check` - PASS.

## Current Verdict

Not release-ready. MAS build/scanner/live UI smoke are green for the isolated no-vault path, MAS Pro-only surfaces are hidden in diagnostics, the MAS and Pro scratch-vault import/Notes/schema paths now have isolated zero-runtime-issue evidence, and the first-run Platinum appearance/readable-font settings fix is green. Pro/direct diagnostics and Agent settings render with the expected Pro-only tool surfaces and approval posture. Local deterministic tool-loop, cloud routing contract checks, executable note/research tool parity, approval-to-R.5 grant bridging, automated note ask-bar rewrite checks, and the requested real-glass sidebar/graph-note source guards are green, but live Pro local generation is blocked on this machine by memory pressure for the only installed agent-capable model, and live Pro cloud-agent execution is blocked by missing provider keys. Remaining blockers: the scratch-vault graph has a protected first-open camera/framing bug where persisted nodes exist but are invisible until the user clicks Zoom to Fit, live MAS note ask-bar simple rewrite smoke remains incomplete in a safe scratch-vault/model-ready setup, first-run web approval live smoke is still pending because no live local/cloud tool turn can execute here, and the required five consecutive zero-new-blocker recursive passes have not been completed.
