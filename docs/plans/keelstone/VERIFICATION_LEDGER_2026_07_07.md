# KEELSTONE Verification Ledger

Date: 2026-07-07

Purpose: keep batched verification explicit while coding continues. This file
tracks what is already proven, what was checked in this audit pass, and what
still needs broader release-lane evidence.

## Proven In This Pass

- Phase 0 retired-surface source scan is clean across guarded source paths:
  `Epistemos`, `EpistemosTests`, `project.yml`, `scripts`, `.github`, and root
  `build-*.sh` scripts.
- `./scripts/keelstone-release-gate.sh` passes source-level drift, entitlement,
  witness, and hardening-finding gates.
- `KEELSTONE_SEED_HIGH_FINDING=1 ./scripts/keelstone-release-gate.sh` fails for
  the intended HIGH hardening finding.
- `./scripts/check-perf-budgets.sh` passes current enforceable budgets and logs
  missing Keelstone measurements explicitly.
- `KEELSTONE_SEED_PERF_REGRESSION=1 ./scripts/check-perf-budgets.sh` fails for
  Keelstone budget exceedances.
- Targeted AppStoreHardening tests passed after the body-truth and Phase 0 guard
  hardening. Latest checkpoint: 53 Swift Testing tests in
  `EpistemosTests/AppStoreHardeningTests` passed, including the neutral
  child-ledger filename guard, legacy ledger sweep, kill-9 replacement proof,
  FSEvents replay/escalation, reconcile convergence, conflict flow, source
  residue guard, seeded HIGH gate proof, MAS source guards, and App Store scan
  witness checks.
- Targeted NoteEditorLayout tests passed after stale source guards were updated
  to the file-first body-save path.
- Targeted EpdocVisibility source guards passed with the LumenLens L6
  file-first save expectation.
- App Store Keelstone lane passed locally:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' -derivedDataPath .derived-data-keelstone-appstore -only-testing:EpistemosAppStoreKeelstoneTests CODE_SIGNING_ALLOWED=NO`.
  The lane ran the dedicated five-test `EpistemosAppStoreKeelstoneTests` suite
  for surface macros, first-run/upgrade bootstrap, bookmark rejection/fallback,
  and unavailable-root write freeze.

## Deferred Verification Debt

- Run the full Swift/Xcode test suite when the next batch checkpoint justifies
  the time. Targeted suites have passed, but Phase 6 still says "full test suite
  green."
- Run built-app entitlement gates with real app paths:
  `scripts/keelstone-release-gate.sh --appstore-app <Epistemos.app>` and
  `scripts/keelstone-release-gate.sh --direct-app <Epistemos.app>`.
- Produce real `build/perf-budgets-keelstone.json` measurements for the 10k-note
  and 100k-note envelopes. The budget parser and seeded regression are proven;
  real measurement production is still the missing Phase 7 evidence.
- Run the final App Store artifact scan (`scan_appstore_bundle.sh`) against a
  produced Release app, not only the source-level residue scan.
- Re-run an end-to-end external editor test for Finder/vim style edits against
  a live vault. The code guards prove file-first saves and FSEvents wiring, but
  a human-visible external edit flow remains useful release evidence.
- Re-run legacy body migration fixtures for zero-loss `note-bodies` and
  `SDPage.body` migration. The release gate checks the witness test exists; a
  full fixture run belongs in the next broad batch.
- Run a release-style soak for external edit storms, sync races, and random
  kill-9 boundaries beyond the targeted kill-9 replacement test.

## Current Status Read

Keelstone is source-level clean through Phase 6 guardrails, has targeted
evidence for Phases 1-5, and has a passing dedicated App Store Keelstone lane.
Phase 6 still lacks the full Swift/Xcode suite. Phase 7 is partially
implemented: budget documents, parser coverage, CI wiring, seeded failure, and
child-process cleanup proof are present, but real Keelstone measurement output
is not present. Phase 8 is partially implemented: release gates and witnesses
are wired, but final built artifact gates and full lane soaks still need a
broad checkpoint run.

## 2026-07-10 Clean Prompt 2 Continuation Evidence

The earlier built-artifact debt is now closed for the current source state.
Manual exact-archive product behavior remains open because the objective's
standalone `go back` condition did not authorize controlling Epistemos.

### Passing evidence

- Focused MAS regression batch: 12 selected Swift Testing cases passed for
  literal June send, disabled prompt composition, Epdoc blank recovery and
  clean-switch fidelity, English Kokoro selection, vault cache-gap restore,
  graph startup/routing, editor editability/lease ownership, and typing hot
  paths. Result bundle:
  `build/xcode-results/2026-07-09-223559-9817.xcresult`.
  `xcresulttool` independently reports result `Passed`, 12 total, 12 passed,
  zero failed/skipped/expected failures.
- A new MAS privacy-manifest regression first failed with only `C617.1`
  present, then the full dedicated MAS suite passed 55/55 after adding
  `3B52.1`. Red result:
  `build/xcode-results/2026-07-09-225422-37418.xcresult`; green result:
  `build/xcode-results/2026-07-09-225835-42832.xcresult`.
  `xcresulttool` independently reports the green result as `Passed`, 55 total,
  55 passed, zero failed/skipped/expected failures.
- `./scripts/keelstone-release-gate.sh` passed after its privacy helper was
  changed from loose global string checks to category-bound plist traversal.
- `cargo check --manifest-path agent_core/Cargo.toml --bin
  materialize_release_audit_distribution_compliance_review --features
  mas-sandbox` passed.
- Xcode `26.4.1` build `17E202`, macOS SDK `26.4` produced this fresh Release
  archive:
  `build/appstore-release-archive-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100.xcarchive`.
- A fresh normal `Epistemos` Release `-showBuildSettings` still resolves to
  target `Epistemos-AppStore`, product `Epistemos`, bundle ID
  `com.epistemos.appstore`, App Store Info.plist/entitlements, App Sandbox
  enabled, and only `EPISTEMOS_APP_STORE MAS_SANDBOX
  EPISTEMOS_LINK_SUBSTRATE_RT` active conditions.
- The exact archived app passed `scripts/keelstone-release-gate.sh
  --appstore-app`, including category-bound checks for every required-reason
  API in the bundled `PrivacyInfo.xcprivacy`.
- The strengthened gate rejected the immediately preceding pre-fix archive
  specifically because its bundled FileTimestamp entry lacked `3B52.1`.
- `scripts/scan_appstore_bundle.sh` completed clean. Reports:
  `build/visible-mas-proof-2026-07-10-prompt2-privacy-manifest-hardening-20260709-230100`.
- `codesign --verify --deep --strict` passed. Effective entitlements retain
  App Sandbox, app-scoped bookmarks, user-selected read/write, network client,
  audio input, and the app group, with no network server, JIT, or disabled
  library validation.
- The bundled privacy manifest is byte-identical to source, has no quarantine
  attribute, and has SHA-256
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`.

### Remaining Prompt 2 debt

| Area | Status | Required evidence |
| --- | --- | --- |
| Base app opens MAS/June | HIGH OPEN | Launch the exact archived app and prove the visible base product is MAS/June. |
| Vault restore/save | HIGH OPEN | Select a security-scoped vault, quit/reopen, edit/save, and prove no loss or `no vault URL` path. |
| Epdoc blanking/fidelity | HIGH OPEN | Open/switch/reopen rich tables and formatting in the exact archive without blanking or normalization loss. |
| Editor/code/graph responsiveness | HIGH OPEN | Type and save in Epdoc, Prose, Source/Code, Quick Capture, embedded graph, and hologram graph with log/timing evidence. |
| Kokoro English voice | HIGH OPEN | Retained exact-archive logs prove checked Core ML render plus AVAudioEngine playback start/completion, and current source pins an English-only native surface matrix with visible install/failure states. Human audibility is still unclaimed and model reload is deferred under the owner resource steer. |
| June MAS send | HIGH OPEN | The exact matching `agent_core` receipt proves vault/session setup succeeded and GPT-5.5 stopped at turn 0 because `OPENAI_API_KEY` was not configured. Current source compile-parks OpenAI Codex OAuth in MAS, names the API-key requirement, and preserves safe typed/callback Rust diagnostics. A fresh archive is still required to prove that precise visible error; it is deferred under the low-memory owner steer. |
| Broad/repeated release validation | OPEN | Run the broader release-audit/manual/distribution matrix and repeated zero-fail passes after the manual HIGH blockers close. |

## 2026-07-10 Exact-Archive Manual Continuation And Resource Bound

- Base app, vault restore/save, and Epdoc blanking/rich-fidelity HIGHs now have
  exact signed-archive UI/file/log/reopen evidence in `INTENT_LEDGER.md`.
- Standard code editing, Quick Capture, hologram graph code editing, and
  hologram graph rich-Document editing/switch persistence are proven in the
  current signed archive. Embedded-in-home graph remains unproven.
- A Settings-navigation stress pass found a release-relevant 11.8 GB SwiftUI
  layout/preference hang. Sample:
  `build/runtime-samples/2026-07-10-settings-navigation-hang-sample.txt`.
  The source now coalesces rapid sidebar selection before constructing heavy
  detail panes and disables detail transition animations.
- Owner resource steer forbids massive tests. The in-flight clean Xcode run was
  interrupted and is not evidence. Current repair evidence is intentionally
  limited to Swift parse, diff, source-guard markers, and the pre-fix runtime
  sample until a narrow reusable build can run without large memory pressure.

### Current remaining Prompt 2 debt

| Area | Status | Required evidence |
| --- | --- | --- |
| Embedded-in-home graph | HIGH OPEN | Open the embedded host, route a node into an editor, type/save without hang, and collect timing/log evidence. |
| Settings navigation memory | SOURCE-PATCHED / RUNTIME OPEN | Reuse a narrow build to repeat rapid keyboard navigation and prove bounded footprint/responsiveness; no clean/broad build under the current owner constraint. |
| Kokoro English voice | HIGH OPEN | Audible English preview and remaining read-aloud surface matrix, or a precise truthful visible blocker. |
| June MAS send | HIGH OPEN | Real output or precise provider/model error with no Hermes/Prompt Forge normal-send path. |
| Broad/repeated release validation | DEFERRED BY OWNER RESOURCE STEER | Resume only with resource-bounded commands or later owner permission. |

## 2026-07-10 MAS Credential Truth Hardening

### Proven with low-memory evidence

- Official current docs were checked for the App Sandbox file boundary,
  Claude Code macOS credential storage, Claude API authentication, and Google
  desktop OAuth callbacks. They support an API-key-only MAS provider boundary;
  no documented sandbox-safe Claude Code import or admitted Google callback
  flow exists in the current product.
- `CloudProviderAuthService` now resolves saved OAuth sessions only outside MAS,
  rejects Claude Code import before touching the home directory in MAS, and
  compile-parks account-token refresh/import helpers from the MAS branch.
- `InferenceState` does not load or return legacy OAuth sessions in MAS and
  refuses non-`nil` OAuth persistence. Settings advertises no account-session
  connection, hides Google desktop OAuth controls, and opens provider API-key
  management for the primary action.
- `AppBootstrap` forwards OpenAI, Anthropic, and Google OAuth overrides only in
  the parked direct branch. MAS continues to scope provider API keys from
  Keychain around the in-process `agent_core` call.
- `CloudProviderResolvedCredential` exposes only `.apiKey` in MAS, and
  `LLMService` compiles all Anthropic/Google account bearer-token and Claude CLI
  request behavior only in the parked direct branch.
- June's unconfigured error and model catalog now name saved OpenAI/Anthropic
  API keys without claiming a Claude Code account connection.
- Added `appStoreCloudSetupUsesKeychainAPIKeysOnly` plus release-gate source
  witnesses. Artifact scanners now reject Claude home-credential paths, OAuth
  refresh endpoints, CLI user-agent markers, and account-only beta markers.
  MAS parser pass, direct parser pass, test-source parser pass, both scanner/gate
  shell syntax checks, and scoped `git diff --check` all passed.

### Deferred verification debt

- Do not claim a current-revision runtime credential flow yet. A resource-safe
  future archive must prove API-key save/check, literal June send, exact visible
  missing-key/provider error, and absence of account-session controls.
- No Xcode build/test/archive, Epistemos launch, model load, or provider call ran
  in this checkpoint because the owner explicitly prohibited massive tests.

## 2026-07-10 MAS June-Only Settings And Exact Model Admission

### Proven with low-memory source evidence

- One provider truth source now drives MAS Settings, June catalog/fallbacks,
  configured-provider discovery, credential bootstrap, and brain catalog:
  OpenAI and Anthropic only.
- One model truth source now drives MAS Settings and June selection. Every
  allowlisted model has an explicit Swift slug and fixed Rust constructor; rows
  that would silently collapse to another model are excluded and rejected at
  the gateway boundary.
- Legacy persisted provider/model choices are repaired onto the June list.
  Non-June providers cannot read/save/validate API keys through MAS
  `InferenceState`, and scoped `agent_core` environment construction loads only
  OpenAI and Anthropic API-key entries.
- MAS Runtime Lanes, Privacy, and Deployment Profile now expose only connected
  June cloud/local lanes and June's actual outbound provider boundary; parked
  Gemini/Z.AI/Kimi/Perplexity lanes are direct-build-only in the lane inventory.
- The retained `CloudLLMClient` rejects non-June providers/models at all MAS
  request entry points before credential or network work. The legacy
  all-provider chat-tool flag is compile-parked from MAS, and missing-access
  messages no longer direct MAS users toward account-session setup.
- The MAS Rust source branch now contains Claude API-key auth only at the source
  boundary; Claude account-token constants, variants, environment inputs,
  request headers, and tests are direct-lane-only.
- June bootstrap truth is no longer optimistic: the native bridge derives
  `providerConfigured` from cached OpenAI/Anthropic June access and the web
  fallback reports `providerConfigured: false`. The fallback send path retains
  its visible `5030` failure and does not synthesize output.
- The owner's June-only boundary is explicitly chat/agent-only. Agent Command
  Center recommendations now derive from `activeProductProviders`, while Voice
  Settings and the installed English Kokoro picker remain present and guarded.
- MAS Browser diagnostics retain the permitted native WebKit/scraper/privacy
  surface while compiling parked browser-use Pro, Obscura, and anti-fingerprint
  status rows out of the App Store product ledger.
- The Rust FFI now repeats the June boundary: MAS preview/instantiation admits
  only exact Claude/OpenAI June slugs, refuses auto/dynamic/parked overrides,
  and excludes Gemini, Perplexity, and generic OpenAI-compatible provider
  modules from `mas-build`. Direct builds retain those implementations.
- MAS Settings now labels the destination “June Models” and its section “June
  Provider Setup”; the separate Kokoro Voice destination remains intact.
- June's embedded Settings no longer feeds agent/chat rows into the
  transcription picker or lets transcription selection mutate the June agent
  default. It retains one local dictation row and all separate Kokoro voices.
- The donor June Settings hides static image-model rows when the host exposes
  no image-generation model. The build script pins that guard, but the staged
  web `dist` still predates this TSX edit because rebuilding is deferred by the
  owner RAM limit.
- The donor sidebar labels the MAS-hosted text catalog “June models”; the build
  script pins that marker for the next stage.
- MAS-hosted June Settings also hides disconnected Billing, Installed skills,
  and External skill directories while preserving Agent/models/audio/dictation;
  this is donor-source proof pending the same staged rebuild.
- June Settings model mutation now fails closed: disconnected generation IDs,
  non-local transcription IDs, and image/unknown modes reject the bridge
  promise instead of producing a false success banner. Local dictation remains
  separate, and Kokoro voice models/settings remain preserved.
- Active MAS `agent_core` callback errors now identify MAS June and contain no
  Pro/Goose/NightBrain product advertising. Its disposable fallback scratch
  directory uses the June namespace; selected vault storage is unchanged.
- The Swift model-to-FFI slug seam now has a dedicated MAS branch containing
  only June's exact eleven model IDs. Dynamic paths and parked provider/model
  heuristics remain direct-only; the Rust June-only factory is still the final
  admission layer.
- Native MAS provider help now describes only OpenAI/Anthropic API keys stored
  in Keychain for MAS June. It no longer advertises parked account-session or
  alternate-product routes; a stale Google path says it is not connected.
- The normal MAS landing entry now visibly says `june`, describes `June
  Workspace`, and mounts under the page title `June`; direct-build agent labels
  remain isolated to the direct compilation branch.
- MAS onboarding now describes June's actual vault/search/provenance,
  approval-gated tools, OpenAI/Anthropic, and Apple Intelligence boundary rather
  than claiming MCP/hidden skill surfaces. The separate Kokoro setup step and
  voice model download controls remain intact.
- Both the embedded sidebar and page heading label the MAS catalog “June
  models.”
- The staged and donor June shims are byte-identical. Their visible status names
  the in-process MAS agent gateway and no longer names Hermes or an external
  runtime/server.
- Passing checks: both Swift parser branches for the changed product files;
  parser checks for focused App Store/June source tests; `bash -n` for the
  release gate; `rustfmt --check` for the Claude provider; scoped
  `git diff --check`; and an RSS/process inspection showing no Xcode,
  compiler, model, or Epistemos process.

### Deferred verification debt

- `cargo check --manifest-path agent_core/Cargo.toml --lib` with the default
  `mas-build` feature is intentionally deferred under the owner's RAM limit.
- A resource-safe reusable MAS build must prove the actual Settings provider and
  model menus, stale-preference repair, API-key save/check, truthful bootstrap
  configuration state, one literal June turn, and artifact absence of parked
  Claude OAuth/CLI/Hermes markers.
- The retained signed archive predates this provider/model/bootstrap source
  checkpoint and cannot prove the current revision's visible or runtime state.
- Broad Xcode/release/repeated-zero-fail validation remains deferred; none of
  the source checks above is a runtime or release-ready claim.

## 2026-07-10 June Selected Local GGUF Restoration

### Source and artifact evidence

- Git history identifies the disablement precisely: commit `39df11d0f`
  (`Remove App Store llama runtime dependency`, 2026-07-06) replaced the live
  adapter with a false-returning stub and removed the App Store package link to
  prevent stale DerivedData linkage. This was a conservative release rollback,
  not an App Store ban or owner removal decision.
- The July 4 proven set is restored: Qwen3 4B, Qwen3 8B, and Qwen2.5 7B only.
  Cloud OpenAI/Anthropic models and Kokoro voices remain separate and intact.
- `project.yml` and the preserved PBX project link the local
  `EpistemosLlama` product only into `Epistemos-AppStore`. A fresh temporary
  XcodeGen project and the checked-in PBX project each contain ten matching
  EpistemosLlama reference roles.
- Official artifact metadata was checked without downloading model bytes:
  - Qwen3 4B revision `bc640142c66e1fdd12af0bd68f40445458f3869b`,
    2,497,280,256 bytes, SHA-256
    `7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5`;
  - Qwen3 8B revision `7c41481f57cb95916b40956ab2f0b139b296d974`,
    5,027,783,488 bytes, SHA-256
    `d98cdcbd03e17ce47681435b5150e34c1417f50b5c0019dd560e4882c5745785`;
  - Qwen2.5 7B revision `8911e8a47f92bac19d6f5c64a2e2095bd2f7d031`,
    4,683,074,240 bytes, SHA-256
    `65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423`.
- The official llama.cpp GitHub b9870 release reports archive SHA-256
  `792cb6560abc2e04262b105eb9ca3d5890814f358f998adea4e28497788e59f7`.
  The local macOS framework binary, module map, and Info.plist match their new
  extracted-file pins, and `scripts/fetch-llama-xcframework.sh` exits through
  its verified reuse path without downloading.
- The existing sandbox Qwen3 4B file was inspected by metadata only and has the
  exact pinned byte count. It was deliberately not hashed or loaded under the
  owner RAM/test constraint.

### Low-memory commands and results

- Initial source-contract probe: expected red on four retirement conditions
  (missing target dependency/live engine, five rows instead of three, missing
  MAS GGUF route), then PASS after implementation.
- Strict concurrency typecheck:
  `swiftc -typecheck -strict-concurrency=complete -warn-concurrency` over
  QuickChat models/catalog/downloader/backend: PASS.
- MAS/direct Swift parse plus focused test-source parse: PASS.
- `swift package dump-package --package-path LocalPackages/EpistemosLlama`:
  PASS; no package build executed.
- `plutil -lint Epistemos.xcodeproj/project.pbxproj`: PASS.
- Temporary `xcodegen` comparison: ten current and ten freshly generated
  EpistemosLlama reference occurrences with equivalent link roles: PASS.
- `scripts/fetch-llama-xcframework.sh`: existing b9870 artifact verified and
  reused: PASS.
- `rustfmt --check`, `bash -n`, scoped/source `git diff --check`, and exact
  catalog/revision/digest/receipt guards: PASS.
- `Tools/app-review-audit/app-review-audit.sh appstore`: first run red only
  because its parser included compile-parked Experimental/Goose branches; after
  tri-state MAS conditional parsing, all four checks PASS, including no
  executable download and no MAS subprocess surface.
- Process inspection found no Xcode, compiler, Cargo/Rust, llama, model, or
  Epistemos process after checks. Physical memory is 16 GB.

### Remaining verification debt

- Current source is not a current binary. Do not claim local models live until
  a resource-bounded MAS build proves `EpistemosLlama` compiles/links/signs and
  the exact app bundle contains only the admitted framework/runtime assets.
- The first launch of the new build must background-verify the pre-existing
  Qwen3 4B file, create its receipt, and keep June in a truthful `verifying`
  state until completion. No multi-GB hash was run in this source session.
- Prove June Settings shows exactly three local rows plus the admitted cloud
  rows, selection/download/cancel/delete states are truthful, Qwen3 4B streams
  one bounded answer, interrupt works, and memory-pressure teardown unloads.
- On this 16 GB Mac, Qwen3 8B and Qwen2.5 7B should remain visible but
  memory-gated under the current no-swap policy. Do not loosen this merely to
  make every row appear runnable.
- Re-prove exact archive bundle scan, signing, App Review notes, cloud June
  output/error, and audible Kokoro coexistence after the resource-safe build.

### Clean-checkout and bundle-size evidence

- `scripts/xcodebuild_epistemos.sh` invokes the digest-verifying llama artifact
  fetcher before its internal SPM resolution or main `xcodebuild` invocation.
  `.github/workflows/ci.yml` caches the pinned b9870 binary directory and runs
  the same fetcher before XcodeGen and `Resolve SPM dependencies`. A focused
  order check and updated Swift source guard both pass.
- The retained pre-restoration archive measures 222 MB total and 91 MB in its
  Frameworks directory. Adding the approximately 140 MB verified macOS llama
  framework gives a conservative 362 MB estimate, below the configured 600 MB
  gate. No current archive was built, so exact app size, slice stripping,
  signing, and bundle-scan proof remain verification debt.
- Post-change low-memory checks pass: focused Swift test-source parsing,
  `bash -n` for the wrapper/fetcher/gates, wrapper/CI order inspection,
  retirement-marker search, and `git diff --check`. No compiler, model,
  application, Xcode, or Cargo workload was started.

### Current staged JuneWeb evidence

- `build-june-web.sh` completed against `/Users/jojo/dev/june-epistemos` under
  a 768 MB JavaScript heap cap. It ran `bun install`, TypeScript, and Vite,
  staged 27 files, and reported a 523 KB gzipped main chunk. `/usr/bin/time -l`
  measured 755,367,936 bytes maximum RSS and zero swaps.
- The new staged main asset is
  `.june-web-stage/dist/assets/main-t19Qre-v.js`, SHA-256
  `9d38c92dea2a70bf15e88741c47ea9833da3fee8ecfc053fd593f4befc8a1144`.
  The staged index SHA-256 is
  `30790bb4f65afaf93dd9db5bd4fc9ec396708d4f22f7cb881a24c0cbeec2c00e`;
  the donor-identical shim SHA-256 is
  `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`.
- Artifact checks prove the `June models` marker, donor/stage shim byte
  identity, JavaScript syntax, and absence of service workers, source maps, and
  excluded commercial fonts. Package/lock files were not changed by the build.
- The first post-stage KEELSTONE gate run correctly failed on two stale guard
  contracts. `require_file_starts_with` now compares the actual byte prefix so
  it can validate the explicit multiline App Store llama import. The OAuth
  assertion now matches the stronger production rule that permits only active
  June providers and only credential removal in MAS. Swift parse, shell parse,
  diff check, and the complete rerun pass; the gate used about 10 MB maximum
  RSS and zero swap.
- The current stage is not yet a signed app artifact. A later resource-bounded
  App Store build must copy it into `Contents/Resources/JuneWeb` and prove its
  hashes/visible behavior through the exact archive.

## 2026-07-10 June Cloud Consent And Privacy Collection Truth

### Source evidence

- Expected-red probe found six absent consent/review contracts before the
  implementation. June now has one provider-specific consent store, Settings
  grant/revoke toggles for OpenAI and Anthropic, and a final cloud-admission
  check before `agentCoreRunner.streamGooseMASAgentCoreRun` can be created.
- Missing consent produces a visible provider/host disclosure, a direct path to
  `Settings > June Models`, and `Nothing was sent.` Generic Cloud Agent and
  exact cloud-model paths are both guarded; Apple Intelligence, GGUF, and
  Kokoro are unaffected.
- Official Apple App Privacy guidance, App Review Guideline 5.1.2, OpenAI API
  data controls, and Anthropic commercial retention guidance were rechecked.
  Standard OpenAI/Anthropic API use can retain prompt/output data up to 30 days,
  so zero collection or zero-retention cannot be assumed from a user API key.
- `PrivacyInfo.xcprivacy` now contains exactly
  `NSPrivacyCollectedDataTypeOtherUserContent` and
  `NSPrivacyCollectedDataTypeUserID`. Both are linked, tracking=false, and use
  only `NSPrivacyCollectedDataTypePurposeAppFunctionality`. Tracking and
  tracking domains remain false/empty.
- The in-app Privacy pane, App Review submission draft, `docs/PHASE_S_AUDIT.md`,
  and its consolidated mirror match that posture. The prior server-held-key,
  no-local-model, empty-collection, and unimplemented report/block claims were
  removed.

### Low-memory verification and debt

- Exact JSON/plist contract check: PASS; `plutil -lint`: PASS.
- MAS/direct Swift parse for the consent store, gateway, error, Settings, and
  Privacy surfaces: PASS. Focused test-source parse and shell syntax: PASS.
- KEELSTONE source gate: PASS with explicit consent and collected-data guards.
  App Review source audit: PASS in 15.76 seconds at 2,211,840 bytes maximum RSS
  and zero swap.
- No Xcode test/build/archive, provider request, app launch, model load, or
  multi-GB hash ran. The consent functional test is added but execution stays
  in the deferred resource-safe Xcode batch.
- Exact-archive debt: verify toggles and disclosure visually; capture a
  no-consent network witness; grant, send, revoke, and re-block each provider;
  verify the bundled privacy manifest; and update App Store Connect privacy
  answers to the same two linked, non-tracking App Functionality categories.

## 2026-07-10 June Literal Identity, Proxy Parking, And Kokoro Intake Hardening

### Source evidence

- Removed the active MAS WebView's DOM-wide June-to-Workspace text rewrite.
  The remaining overlay owns typography/layout only and explicitly renders
  `June` in the sidebar/composer. Native chat chrome, prompt/history identity,
  diagnostics, loading/errors, read-aloud fallback, and landing copy match.
- Compile-parked the unused receipt proxy, StoreKit subscription service, and
  proxy cloud engine behind `EPISTEMOS_LEGACY_RECEIPT_PROXY`. `project.yml`
  does not enable the flag and `JuneAgentGateway` references neither parked
  client. Cloud Agent copy now describes only BYOK + direct provider + consent.
- Consent is enforced before provider validation, Paste + Save validation, the
  retained `CloudLLMClient` credential seam, and final `agent_core` admission.
  This source pass found no remaining OpenAI/Anthropic request constructor
  outside the guarded direct client/June route.
- Kokoro model/voice visibility remains present in Settings, onboarding, June
  toolbar read-aloud, and installed English voice selection. The downloader
  now validates safe relative paths, exact 64-hex SHA-256, normalized duplicate
  destinations, at most 256 declared files, at most 1.25 GiB aggregate bytes,
  overflow safety, and exact downloaded byte count before hashing/install.

### Low-memory verification and debt

- Expected-red KEELSTONE runs recorded seven June-brand failures, three proxy-
  parking failures, one cloud-row-copy failure, and six Kokoro-manifest failures
  before their respective implementation patches.
- `swiftc -parse` passes for the changed MAS/direct sources and focused test
  sources. `bash -n`, donor-absent June stage validation, `git diff --check`,
  and the full KEELSTONE source gate pass; the final gate log ends
  `KEELSTONE release gate passed`.
- No Xcode build/test/archive, Cargo workload, app launch, provider request,
  GGUF/model load, multi-GB hash, or Kokoro download ran. Runtime and bundle
  evidence remain deferred to the resource-safe exact-archive batch.
- Donor/asset follow-up: expected-red checks caught the visible Workspace/local-
  API copy and incomplete MAS settings-tab hide set. One bounded TypeScript/
  Vite rebuild produced 27 staged files (2,600,960 bytes; 536,016-byte gzip
  main chunk) at 774,094,848 bytes maximum RSS and zero swap. Current hashes:
  main `0f28fac9126c5544093c02dd3f31bd2007ad6dc72b4249d9a751c8b410cda4c5`,
  index `0908895094ae980046643f1686b331329e93ef0eb66aab098ad88b818f62a630`,
  shim `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`.
  Donor-absent validation, JS syntax, shim byte identity, source/stage product-
  copy guards, donor diff check, and full KEELSTONE source gate pass.
- Final-call-graph proof: `rg` found `runAgentSession` only in the AppStore-
  excluded ACP server and `GooseMASAgentCoreRunner`; legacy native workspace is
  also compile-parked. Expected-red guards preceded the runner reverse-provider
  map and consent recheck. MAS Swift parse and full KEELSTONE gate pass.
- Repeated App Review source audit passed all four checks in 16.07 seconds at
  2,228,224 bytes maximum RSS and zero swap. No subprocess/compiler/model/app
  was launched.

## 2026-07-10 Vault Relaunch Grant Transaction

### Expected-red evidence and source outcome

- Before implementation, `connectSelectedVaultAsync` called
  `switchToVaultAsync` before `persistVaultSelection`, and the MAS failure test
  expected `lastVaultPath` to change despite bookmark creation failure.
- The old failure branch also removed bookmark/trust state, so a failed
  replacement could destroy the previous relaunch grant.
- `prepareVaultSelection` now creates bookmark data without changing defaults
  or recovery state. `commitPreparedVaultSelection` is the explicit commit
  seam. Folder selection follows prepare -> switch -> commit; recovery prepares
  before snapshot, watcher teardown, or derived-state clearing.
- Tests cover fresh MAS preparation failure, preservation of an existing
  bookmark/path/trust record, and lexical prepare/switch/commit ordering.

### Low-memory verification and debt

- `xcrun swiftc -parse` for the service and three focused test sources: PASS;
  0.60 seconds, 44,548,096 bytes maximum RSS, zero swap.
- Prepare/switch/commit source-order and non-mutating-prepare probe: PASS.
- `bash -n scripts/keelstone-release-gate.sh`: PASS.
- Full KEELSTONE source gate: PASS; retained log
  `/tmp/keelstone-source-gate-20260710-vault-transaction.log`; 2.52 seconds,
  10,321,920 bytes maximum RSS, zero swap.
- `git diff --check` for touched source/test/gate files: PASS.
- No Xcode build/test/archive, app launch, provider call, model/voice load, or
  large file hash ran. Exact MAS bookmark persistence across quit/relaunch and
  a real post-relaunch vault write remain HIGH OPEN runtime evidence.

## 2026-07-10 Cooperative Graph Store Intake

- Expected-red probes confirmed GraphStore had no cooperative bulk-load method
  and `GraphState.loadGraph(container:)` still performed one uninterrupted
  MainActor `loadFromRecords` pass after the background SwiftData fetch.
- The new async loader shares the synchronous loader's node/edge insertion
  helpers, yielding between 256-record batches by default. Startup uses it for
  both node and edge indexing; structural rebuild behavior is unchanged.
- Focused test source covers 600 nodes and 599 edges with a 64-record batch.
- `swiftc -parse` for GraphStore, GraphState, and the focused tests: PASS;
  0.48 seconds, 39,960,576 bytes maximum RSS, zero swap.
- Source-order/cooperative-yield probe and `git diff --check`: PASS. Exact MAS
  graph-open latency and UI responsiveness remain HIGH OPEN runtime proof.

## 2026-07-10 Epdoc Save-Registry Replacement Race

- Expected-red probes confirmed registration/unregistration had no ownership
  token, so an old coordinator's delayed onDisappear flush could remove the
  replacement coordinator's page-ID flusher.
- The registry now stores `{token, flush}` and unregisters only on an exact
  token match. Coordinators keep one token across their configured page and
  pass it on page change and final teardown.
- Focused replacement-race test source registers stale then replacement
  closures, unregisters stale, and confirms flush reaches replacement.
- Swift source/test parse: PASS; 0.17 seconds, 41,598,976 bytes maximum RSS,
  zero swap. Source ownership probe and `git diff --check`: PASS.
- Exact archive Document/Source/Prose switching with rich tables remains HIGH
  OPEN; this closes a concrete flush-registry race, not visual fidelity proof.

## 2026-07-10 Source Dirty-Before-Debounce Lease Guard

- Expected-red probes confirmed CodeEditor exposed no edit-start callback,
  CoreEditor did not forward its existing dirty metadata signal, and its idle
  timer used always-true `if (contentDirty)` rather than `.value`.
- The native bridge coalesces one `onContentDirty` callback per pending full
  text snapshot. `CodeEditorView` forwards it to the note workspace, which
  marks the session dirty immediately; the 900 ms save debounce is preserved.
- The fallback timer now reads `contentDirty.value`, avoiding idle snapshot
  scheduling caused by testing the holder object.
- Swift parse across coordinator, adapter, CodeEditor, workspace, and two test
  sources: PASS; 0.36 seconds, 44,466,176 bytes maximum RSS, zero swap.
- Source wiring probe and `git diff --check`: PASS. Runtime proof still needs a
  rapid type -> second-surface open/handoff attempt -> save/relaunch scenario.

## 2026-07-10 Shared Document/Source Dirty-Before-Debounce Seam

- Expected-red source checks showed MarkdownDocumentSurface had no edit-start
  callback into the outer note-session lease.
- Accepted Epdoc Markdown changes now invoke the same immediate dirty seam as
  Source before the two-second autosave task is scheduled. Initial load echoes
  remain suppressed inside EpdocEditorChromeController.
- The App Store early-edit test records exactly one edit start and preserves the
  existing current-snapshot flush assertion.
- Focused Swift parse: PASS; 0.38 seconds, 43,778,048 bytes maximum RSS, zero
  swap. Full KEELSTONE gate: PASS; retained log
  `/tmp/keelstone-source-gate-20260710-prompt2-editor-leases.log`; 2.40 seconds,
  10,469,376 bytes maximum RSS, zero swap.
- No Xcode, app, WebKit runtime, or model workload ran. Runtime race/fidelity
  proof remains outstanding.

## 2026-07-10 Installed Kokoro Reactivation Without Legacy Flag

### Expected-red evidence and source outcome

- The valid-package regression fixture deliberately used isolated UserDefaults
  with no `EPISTEMOS_KOKORO_VOICE_PRO_V0` value. Before implementation, source
  probes confirmed the gate exposed neither a defaults seam nor installed-
  package discovery, so it returned `unavailable` before package validation.
- `hasInstalledPackageCandidate` performs only a directory-presence check. Its
  result bypasses the legacy off branch but does not establish readiness: the
  existing no-follow path checks, manifest and package coverage, bounded bytes,
  SHA-256 validation, Core ML resource-shape validation, and linked-runtime
  check still own the final result.
- Missing-package copy now says `Kokoro voice: not installed`; readiness logs
  emit `legacyGateEnabled` and `installedPackageCandidate` independently.

### Low-memory verification and debt

- Focused parse of gate, synthesizer, and test source: PASS; 0.6 seconds,
  42,582,016 bytes maximum RSS, zero swap.
- Source-policy probe and scoped `git diff --check`: PASS.
- Full KEELSTONE source gate: PASS; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-reactivation.log`; 10,059,776
  bytes maximum RSS, zero swap.
- No Xcode build/test/archive, app launch, audio engine, Core ML runtime, voice
  package read/hash, download, or model load ran. Exact archive package
  discovery, Settings status, installed English voice choice, audible playback,
  stop/cancel, and relaunch persistence remain HIGH OPEN.

## 2026-07-10 Same-Coordinator Epdoc Registration Reactivation

- Expected-red source probing showed no lifecycle registration snapshot and a
  fixed coordinator token. The original registry test covered replacement
  coordinators only, not the same SwiftUI coordinator disappearing and
  reappearing while its asynchronous teardown was still flushing.
- A real surface appearance now arms UUID renewal; ordinary content/config
  registration reuses the current token. Disappearance
  captures a `SurfaceRegistration` before starting async work; unregister uses
  that immutable page/token pair. Registry token comparison remains the final
  stale-removal guard.
- New serialized MAS regression:
  `reactivatedDocumentCoordinatorSurvivesDelayedTeardown`.
- Focused source/test parse and scoped diff check: PASS; 41,500,672 bytes
  maximum RSS, zero swap. Full KEELSTONE source gate: PASS; 10,289,152 bytes
  maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-reactivation-registration.log`.
- No compiled test execution or runtime lifecycle proof ran. Rapid exact-
  archive Document/notebook/lens reactivation and persisted Markdown remain
  runtime debt.

Self-audit correction: renewal was initially configuration-scoped, which could
leave a new token registered if a save-triggered configuration raced after
disappearance. It is now appearance-scoped. Focused parse: PASS at 41,517,056
bytes maximum RSS; full KEELSTONE: PASS at 10,141,696 bytes maximum RSS; zero
swap; log `/tmp/keelstone-source-gate-20260710-epdoc-appearance-token.log`.

## 2026-07-10 CoreEditor In-Place Writable-State Transition

- Expected-red probes confirmed `MarkEditCoreEditorState.requiresReload`
  treated `isEditable` changes as a full editor reload and the coordinator had
  no call to CoreEditor's already-bundled `setReadOnlyMode` API.
- `replacingEditable` now advances Swift's applied-state model after the live
  config call. `applyReadOnlyMode` calls the bundled API, verifies CodeMirror's
  `state.readOnly`, and uses separate load/application generations so stale
  completion callbacks cannot overwrite newer lease state.
- A failed live call restores the prior applied editability and queues the
  desired state. It waits when a text snapshot is pending; otherwise it falls
  back to an initial-state reload whose config contains the desired mode.
- Focused Swift source/test parse, semantic source probe, and scoped diff check:
  PASS; 40,747,008 bytes maximum RSS, zero swap. Full KEELSTONE source gate:
  PASS; 10,665,984 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-code-editability-inplace.log`.
- No WebKit runtime or Xcode test executed. Exact archive edit focus, user input,
  read-only/writable handoff, buffered-text preservation, and file-first save
  remain HIGH OPEN.

## 2026-07-10 CoreEditor Web-Content Process Recovery

- Expected-red probes confirmed the default Source coordinator had no recovery
  selector or reload and retained `editor blanked; reopen to recover`.
- `webViewWebContentProcessDidTerminate` now chooses
  `pendingState ?? lastAppliedState ?? loadingState`, prefers non-empty host text
  over an empty selected state, and calls `loadEditor` with the recovered state.
  The helper preserves a newer non-empty state over stale host text.
- Recovery logs distinguish ordinary retained-state reload from termination
  after an unsnapshotted edit signal. It does not claim recovery of bytes that
  never crossed the WebKit bridge.
- Focused Swift parse, semantic probe, and scoped diff check: PASS; 40,648,704
  bytes maximum RSS, zero swap. Full KEELSTONE source gate: PASS; 10,518,528
  bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-code-process-recovery.log`.
- No runtime termination was induced. Exact archive recovery without blanking,
  post-recovery editability, and file-first save remain HIGH OPEN.

## 2026-07-10 Note Workspace Async-Close Generation Guard

- Expected-red source check confirmed the owner-session disappearance task
  performed `await flushCurrentEditor(reason: .disappear)` and then closed
  without knowing whether the same workspace had since reappeared.
- `noteSessionLifecycleGeneration` now changes at both lifecycle boundaries.
  The async owner close captures the disappearance generation and checks it
  after the flush before releasing the lease.
- Focused Swift source/test parse, lexical flush/guard/close order proof, and
  scoped diff check: PASS; 43,614,208 bytes maximum RSS, zero swap. Full
  KEELSTONE source gate: PASS; 10,469,376 bytes maximum RSS, zero swap; log
  `/tmp/keelstone-source-gate-20260710-note-session-reactivation.log`.
- No runtime view reactivation was exercised. Exact archive lease continuity,
  Source focus, input, and save remain HIGH OPEN.

## 2026-07-10 Cooperative Structural Graph Full-Reload Fallback

- Expected-red source isolation proved `refreshStructuralDataAsync` called
  synchronous `store.loadFromRecords` after a failed incremental application.
- That branch now awaits `loadFromRecordsCooperatively`; the synchronous API is
  retained for callers whose contracts require it, but is absent from the
  background structural-refresh function.
- Focused Swift source/test parse, semantic refresh-section probe, and scoped
  diff check: PASS; 43,073,536 bytes maximum RSS, zero swap. Full KEELSTONE
  source gate: PASS; 10,256,384 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-graph-structural-cooperative.log`.
- No runtime rebuild was induced. Exact archive graph/editor concurrency,
  visible consistency during yields, latency, and renderer recommit remain
  HIGH OPEN.

## 2026-07-10 Non-Destructive Automatic Vault Restore Failure

- Expected-red source isolation found four
  `defaults.removeObject(forKey: Self.bookmarkKey)` calls between bookmark
  resolution and `startWatching`: generic resolution failure, invalid MAS scope,
  stale refresh failure, and suspicious-folder reconfirmation.
- All automatic failure branches now retain the bookmark and report
  `bookmarkExists: true`. The suspicious trust record can still be removed to
  require explicit reconfirmation. Explicit user disconnect remains unchanged.
- Focused Swift source/test parse, automatic-restore section no-removal proof,
  and scoped diff check: PASS; 43,909,120 bytes maximum RSS, zero swap. Full
  KEELSTONE source gate: PASS; 10,158,080 bytes maximum RSS, zero swap; log
  `/tmp/keelstone-source-gate-20260710-vault-restore-retention.log`.
- No real security-scoped bookmark lifecycle ran. Exact archive retry,
  quit/relaunch restoration, warning behavior, and post-relaunch file-first save
  remain HIGH OPEN.

## 2026-07-10 Source Final Flush Reads The Mounted Editor Buffer

- Expected-red source probing found no parent-callable live-buffer query. The
  existing dirty signal preceded a deliberately delayed 240–700 ms complete
  text snapshot, so a rapid save/switch/close could select an older Swift host
  snapshot.
- `MarkEditCoreEditorLiveTextRegistry` now exposes a workspace-keyed on-demand
  query with registration-token ownership. The coordinator reads the exact
  CoreEditor buffer with a one-second bound. Dismantle swaps the registration
  to a bounded final WebView query before detaching, retains it for two seconds,
  and token-unregisters it; lookup retries once if detach replaced an in-flight
  closure.
- `flushCurrentEditor` queries that buffer before Source persistence, awaits the
  shared Markdown/code writer, fails closed when a dirty buffer is unavailable,
  and prevents lease close after a blocked write. Parent-managed teardown also
  disables the old stale-host debouncer flush so two writes cannot race.
- Focused Swift source/test parse and scoped diff check: PASS; 44,843,008 bytes
  maximum RSS, zero swap. Bash syntax and expanded KEELSTONE source gate: PASS;
  10,272,768 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-live-flush.log`.
- No Xcode typecheck/test/archive or WebKit/app runtime ran. Exact archive live
  query, rapid-close durability, Markdown frontmatter fidelity, code-file
  fidelity, focus, and timeout behavior remain HIGH OPEN.

## 2026-07-10 Source Persistence Is Ordered And Revision-Aware

- Expected-red probing found no Source persistence task chain. A second
  debounced/final async writer could begin while its predecessor was suspended,
  and an older completion could both finish last and mark a newer edit clean.
- `enqueueSourceEditorPersistence` now chains every Markdown/code Source write
  behind the previous task; final live-buffer persistence uses and awaits the
  same chain. Early dirty and changed-snapshot events advance a Source editor
  revision captured by each write.
- Successful completion updates host snapshots and marks the lease clean only
  when its captured revision is still current. A newer revision keeps its
  in-memory snapshot and is explicitly returned to dirty state.
- Focused Swift source/test parse and diff checks: PASS; 44,417,024 bytes
  maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS; 9,846,784 bytes
  maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-save-order.log`.
- No compiled/runtime concurrent-write test ran. Exact archive burst ordering,
  disk bytes, stale-completion handling, failure retry, and reopen remain HIGH
  OPEN.

## 2026-07-10 Epdoc Markdown Persistence Is Ordered And Revision-Aware

- Expected-red probing confirmed the Document surface had no durability tail,
  editor revision, or coalesced flush. Canceling an async autosave task could
  not guarantee its already-started `saveMarkdown` stopped before a newer write.
- Debounce and durability are now separate. Every captured writer/page/content
  revision awaits `markdownWriteTail`; same-page success updates the actual
  persisted Markdown marker but clears dirty state only for the current
  revision. Page replacement queues old-page content using its old writer.
- Concurrent flushes share `markdownFlushTask`. The flush cancels debounce work
  it subsumes, handles outstanding old writes even when current content equals
  the prior baseline, and loops through up to three revisions arriving while
  writes are suspended.
- Added deterministic MAS regression
  `concurrentDocumentFlushesPreserveNewestEdit`; source-only in this pass.
- Focused Swift source/test parse and diff checks: PASS; 42,565,632 bytes
  maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS; 10,715,136
  bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-save-order.log`.
- No Xcode typecheck/test or app/WebKit runtime ran. Exact archive delayed-save
  ordering, disk bytes, failure retry, table fidelity, and reopen remain HIGH
  OPEN.

## 2026-07-10 File-First Transactions Serialize Per Page Across Callers

- Expected-red probing found no service-level task tail. Prose, Source, Epdoc,
  graph inline editing, intents, and diff application could each call the same
  reentrant async file-first function from independent surface queues.
- Public `savePageBodyFileFirst` now chains the complete transaction per page
  and calls the original logic through `performPageBodyFileFirstSave`. A
  generation guard cleans up only the latest tail; different pages are not
  globally serialized.
- Added source-only deterministic test
  `fileFirstBodySavesSerializePerPage`, which blocks the first export override
  and requires the second same-page invocation to remain outside it.
- Focused Swift source/test parse and diff checks: PASS; 44,122,112 bytes
  maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS; 10,633,216
  bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-file-first-order.log`.
- No compiled/runtime concurrency test ran. Exact archive cross-lens ordering,
  filesystem bytes, errors, cancellation, and reopen remain HIGH OPEN.

## 2026-07-10 Authorized Quit Awaits Mounted Note Durability

- Expected-red inspection showed synchronous teardown ran before
  `applicationWillTerminate`/SwiftUI termination publishers, so Prose could
  stage its newest buffer after teardown started and Source/Epdoc writes could
  still be suspended when exit was approved.
- Mounted note workspaces now register token-owned final flushes; Document can
  flush all mounted surfaces; VaultSync can drain every per-page file-first
  tail. Authorized quit returns `.terminateLater`, stages visible Prose,
  awaits workspace/Document/file-first/dirty-save work, persists recovery
  drafts, then tears down and replies once.
- The wait has a 12-second one-shot deadline. Timeout/failure is logged and
  recovery drafts remain; the already-authorized quit proceeds.
- Added source-only regression `quitAwaitsActiveNoteDurability`.
- Focused Swift source/test parse and diff checks: PASS; 44,285,952 bytes
  maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS; 10,240,000
  bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-termination-flush.log`.
- No app quit/relaunch, WebKit runtime, compiled test, or archive ran. Exact
  cancellation, timeout, last-keystroke bytes, and relaunch remain HIGH OPEN.

## 2026-07-10 Local GGUF Pressure Unload Excludes New Turns

- The immediate memory-pressure branch previously launched
  `engine.unload()` without first changing backend state. A new June turn could
  still observe the prior model identity, skip its load, and then execute only
  after the queued unload removed the context.
- The backend now marks itself unloading and clears loaded identity before
  either immediate or deferred unload work is scheduled. New generations are
  rejected until completion; repeated pressure signals do not schedule
  overlapping unloads.
- Qwen3 4B remains admitted on the 16 GB profile. Qwen3 8B and Qwen2.5 7B
  remain visible but memory-gated; the selected catalog and keep-warm policy
  did not change.
- Focused Swift source/test parse and diff checks: PASS; 40,468,480 bytes
  maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS; 10,665,984
  bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-gguf-unload-race.log`.
- No compiled/runtime model test ran. Exact signed-archive pressure handling,
  generation completion, next-turn reload, cancellation, and reclaimed RAM
  remain HIGH OPEN.

## 2026-07-10 Epdoc June Context Rejects Clean Blank Bridge State

- Visible reactivation already recovered a non-empty host document after a
  clean empty WebKit snapshot, but June assist still read
  `latestMarkdownSnapshot ?? markdown`; an empty optional value therefore hid
  the canonical Markdown body.
- Assist context now resolves through the Document coordinator. Clean state
  uses host Markdown. Dirty state uses the live bridge snapshot so unsaved
  edits—and an intentional empty edit—remain truthful.
- Added source-only resolver regressions and MAS source-gate witnesses.
- Focused Swift source/test parse: PASS; 45,809,664 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-assist-context.log`.
- No compiled test, WebKit/app runtime, model request, or archive ran. Exact
  June context bytes across clean/dirty Epdoc reactivation remain HIGH OPEN.

## 2026-07-10 Epdoc Parent Lease Is Revision-Aware

- Epdoc's ordered coordinator preserved toolbar dirtiness, but the parent save
  callback still marked `NoteSessionStateMachine` clean after any successful
  write. A newer edit arriving during an older suspended save could therefore
  lose its shared dirty-lease protection.
- The note workspace now advances a Document revision on the early edit signal
  and captures it at save start. Only a matching completion updates the mode
  snapshot and marks the session clean; a stale success keeps persisted truth
  but reasserts the user's dirty lease.
- Focused Swift source/test parse: PASS; 47,218,688 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,108,928 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-parent-revision.log`.
- No compiled/runtime delayed-writer test ran. Exact archive edit-during-save,
  lens-switch, conflict, and reopen behavior remain HIGH OPEN.

## 2026-07-10 Prose Recovery Draft Cleanup Is Content-Ordered

- An already-started Prose save could outlive cancellation and unconditionally
  delete a newer crash draft. Launch reconciliation had the same shape: read a
  draft, await vault recovery, then remove that path even if it was replaced.
- Draft writes and cleanup now share one lock. Cleanup succeeds only when the
  current draft text exactly equals the body observed by that save/recovery
  operation. Empty draft files now represent intentional document clears and
  participate in recovery.
- Added pure exact-match regression and MAS source witnesses.
- Focused Swift source/test parse: PASS; 45,105,152 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,584,064 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-draft-order.log`.
- No compiled concurrency test, crash/relaunch, or real filesystem overlap ran.
  Exact archive recovery and cleanup order remain HIGH OPEN.

## 2026-07-10 Prose Marks The Shared Lease Dirty Before Debounce

- Document and Source had immediate dirty callbacks, but Prose only scheduled
  persistence. Its shared note session could therefore appear clean during the
  save debounce despite unsaved TextKit content.
- `ProseEditorView` now reports an accepted non-persisted body change before it
  schedules save/draft work, and the workspace routes that signal into the
  existing note-session dirty transition.
- Focused Swift source/test parse: PASS; 46,841,856 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-early-dirty.log`.
- No compiled/runtime two-window test ran. Exact archive handoff, input, focus,
  autosave, and reopen behavior remain HIGH OPEN.

## 2026-07-10 Quick Capture Preview Scanning Leaves MainActor Typing

- `PreviewSignals(text: captureText)` was a render-time derived property read
  from both header and preview-strip paths. Its hashtag, mention, task, URL, and
  date scans therefore repeated synchronously during every keystroke render.
- Preview signals are now cached, coalesced behind a 120 ms quiet window,
  computed at utility priority, and committed only for the still-current text.
  Authoritative capture submission is unchanged.
- Focused Swift source/test parse: PASS; 45,481,984 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-quick-capture-preview.log`.
- No compiled/runtime latency test ran. Exact archive typing, paste, preview
  update, and submit behavior remain HIGH OPEN.

## 2026-07-10 Cooperative Graph Load Orders Nodes Off MainActor

- Background record fetch and bounded graph-store intake already avoided one
  long MainActor pass, but `rebuildCreatedOrderIndex()` still synchronously
  sorted the full dictionary immediately after node intake.
- Cooperative loading now computes the deterministic newest-first ID order at
  utility priority from Sendable records and installs it after bounded node
  ingestion. Hidden types and equal-date ID ordering are preserved.
- Added a source-only newest-first regression.
- Focused Swift source/test parse: PASS; 45,481,984 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-graph-created-order.log`.
- No compiled test, large graph, Metal runtime, or archive ran. Exact startup
  and graph-to-editor timing remain HIGH OPEN.

## 2026-07-10 Hidden Hologram Sidebar Quiesces During Editing

- The overlay hid its sidebar host on note/folder routes but kept its SwiftUI
  graph-version observer alive. Note mutations could still snapshot every node
  and edge and rebuild sidebar caches behind the embedded editor.
- Sidebar graph-version work now skips non-canvas routes; route exit cancels
  the cache task and canvas re-entry refreshes stale cache/search state.
- Focused Swift source/test parse: PASS; 45,219,840 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 9,945,088 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-hologram-sidebar-quiesce.log`.
- No compiled/runtime graph-editor test ran. Exact archive cache freshness and
  graph-native editor latency remain HIGH OPEN.

## 2026-07-10 Explicit June Model Selection Is Exact And Honest

- Explicit selection reused stale-state repair logic. A configured provider's
  previously preferred cloud model could replace the exact row just selected;
  memory-gated GGUF rejection collapsed to misleading “not connected” copy.
- User-initiated changes now pass a separate exact admission function and keep
  their requested ID. Restore/turn repair retains fallback behavior only for
  stale persisted state. Selection failure distinguishes connected-but-memory-
  gated GGUF from cloud-provider setup requirements.
- Focused Swift source/test parse: PASS; 44,269,568 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,977,280 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-exact-model-selection.log`.
- No model, download, provider, keychain, app, compiled test, or archive runtime
  ran. Exact picker UI and persisted selection behavior remain HIGH OPEN.

## 2026-07-10 June Submit And Session Creation Cannot Hide Model Rejection

- `prompt.submit` previously replied success and `startTurn` ignored a failed
  requested-model update; catalog-valid but RAM-gated local IDs could silently
  run the session's old model. Session creation also treated catalog membership
  as sufficient admission.
- Session creation and prompt submission now exact-admit before success. Failed
  admission returns the precise model blocker without appending the prompt or
  starting a turn. The ignored startup mutation and catalog-only validator are
  removed.
- Focused Swift source/test parse: PASS; 44,105,728 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,534,912 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-submit-model-admission.log`.
- No compiled/runtime model-selection flow ran. Exact archive UI error handling,
  session state, and routing remain HIGH OPEN.

## 2026-07-10 Active Handoff No Longer Requires A Keyword

- Reconciled the current handoff with the owner's later explicit steer: the
  retired `go back` pause is historical only and is not an active prerequisite
  for continuing the MAS-only plan.
- The same handoff preserves the later 25 GB RAM constraint by allowing focused
  source/static work now and deferring Xcode/Cargo/model/broad-manual work to a
  single resource-safe exact evidence batch after source convergence.
- Focused `rg` found no actionable wait-for-keyword condition in the active
  handoff, and `git diff --check` passed for the document.
- This is instruction/verification-debt reconciliation only. No build, test,
  archive, app, browser, provider, or model runtime ran. Continue Prompt 2.

## 2026-07-10 June Session Ensure Cannot Hide Model Rejection

- June's web send path synchronizes its session model through
  `ensure_hermes_bridge_session`, but the bridge previously discarded a failed
  `setSessionModel` result. It could therefore acknowledge model synchronization
  while retaining the previous model.
- The command now uses a validating invoke handler: exact model admission and
  persistence succeed or the invoke rejects with the precise local-RAM/cloud-
  configuration blocker. Bounded title-only synchronization is preserved.
- Focused Swift source/test parse: PASS; 40,943,616 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,502,144 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-session-model-sync.log`.
- No compiled/runtime June send test ran. Exact archive invoke error rendering,
  session state, and next-turn model identity remain HIGH OPEN.

## 2026-07-10 Persisted June Sessions Keep Their Exact Model

- Turn startup previously repaired unavailable or changed session models onto a
  fallback and rewrote persisted state. June could therefore appear tied to one
  model while a different local/cloud lane actually answered.
- Non-empty session model identity is now preserved. Known lanes surface their
  real current blocker; unknown legacy IDs fail visibly and cannot fall through
  to Apple Intelligence or an arbitrary installed GGUF. A valid global cloud
  default also keeps its exact allowed model ID on restore.
- Focused Swift source/test parse: PASS; 40,861,696 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,436,608 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-persisted-model-identity.log`.
- No compiled/runtime restored-session test ran. Exact archive blocker UI,
  persistence, and AnswerPacket/reply model identity remain HIGH OPEN.

## 2026-07-10 June Reply And Reasoning Bounds Apply Before Emission

- Reply deltas previously crossed the 512 KB limit before the check; reasoning
  was capped only in persistence while its original delta still entered the
  webview. The old helper also allocated `text + delta` and trimmed repeatedly.
- Both normal and Apple-FM-fallback streams now append on valid Unicode-scalar
  boundaries with incremental byte budgets and emit only accepted slices. A
  truncated delta seals that channel, preserving order and preventing later
  smaller deltas from appearing after dropped content.
- Focused Swift source/test parse: PASS; 40,910,848 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,731,520 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-stream-bounds.log`.
- No compiled/adversarial event or exact webview runtime ran. Exact UI memory,
  cap rendering, persistence, and cancellation behavior remain HIGH OPEN.

## 2026-07-10 Kokoro Readiness Does Not Rehash Per SwiftUI Render

- Default readiness checks previously re-read and SHA-256-validated every
  declared 0.5–1 GB package file whenever a SwiftUI derived property or button
  queried availability.
- Only the normal default-root/environment/defaults request now uses a
  thread-safe process cache after full validation. Installer/staging/custom
  requests remain uncached. Install/remove invalidate; successful install
  publishes its fully validated final status, while removal stays invalidated.
- Foundation compile probe: PASS; 133,660,672 bytes maximum RSS, zero swap.
  Focused Swift source/test parse: PASS; 42,532,864 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,272,768 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-readiness-cache.log`.
- No real package hash, CoreML/audio, app, or archive runtime ran. One cold full
  validation per process and audible English playback timing remain HIGH OPEN.

## 2026-07-10 Loading Source Teardown Avoids WebKit JavaScript

- CoreEditor dismantle previously evaluated `getEditorText` unconditionally,
  including while the page was still loading immediately before handlers and
  navigation were torn down.
- The exact live query now runs only for a loaded, non-navigating editor. A
  loading/not-ready editor resolves the bounded final-text registry handoff from
  its host binding without touching WebKit.
- Focused Swift source/test parse: PASS; 40,583,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,076,160 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-detach-safety.log`.
- No WebKit/runtime lens switch or quit test ran. Exact teardown timing and
  persisted bytes remain HIGH OPEN.

## 2026-07-10 Source Timeout Failure Does Not Inject Into A Loading Page

- CoreEditor readiness exhaustion previously used `force` to bypass `isLoading`
  and run `evaluateJavaScript` against the still-loading page.
- Forced loading failure now stops navigation and loads an escaped local error
  document. Its load generation is terminal, so the error document's `didFinish`
  cannot restart the readiness-poll cycle; reload/detach resets the marker.
- Focused Swift source/test parse: PASS; 40,648,704 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,452,992 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-loading-failure.log`.
- No exact WebKit timeout/appearance/reload runtime ran. Crash absence and
  visible recovery remain HIGH OPEN.

## 2026-07-10 Retained v1 Source Fallback Recovers In Place

- The explicit legacy WebKit fallback previously logged that its editor blanked
  after content-process termination and required manual reopen.
- It now reloads from pending-or-last-applied host state and restores pending
  selection through its existing readiness flush. Missing host state fails
  explicitly without writing an empty replacement.
- Focused Swift source/test parse: PASS; 38,895,616 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,469,376 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-legacy-source-recovery.log`.
- No exact v1 fallback process-loss or save runtime ran. Editability and
  persisted-byte recovery remain HIGH OPEN.

## 2026-07-10 Loading Epdoc Snapshot Queries Reuse Host Markdown

- Epdoc's async snapshot provider previously evaluated getMarkdown whenever it
  retained a WebView, including while the editor shell was loading/recovering.
- Loading queries now return the controller's last full-fidelity Markdown and
  skip JavaScript. Stable-page queries remain getMarkdown-authoritative;
  detached/missing views remain fail-closed.
- Focused Swift source/test parse: PASS; 40,583,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,256,384 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-loading-snapshot.log`.
- No exact WebKit/table/format/lens-switch runtime ran. Rich-fidelity proof
  remains HIGH OPEN.

## 2026-07-10 Epdoc Dismantle Invalidates Host Callbacks First

- Epdoc teardown previously stopped WebKit before detaching its coordinator,
  delegates, and script handler, leaving a callback window against live host
  state.
- Dismantle now shuts down the coordinator, removes delegates and the bridge
  handler, then stops loading while preserving leak accounting.
- Focused Swift source/test parse: PASS; 40,468,480 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,305,536 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-dismantle-order.log`.
- No exact WebKit teardown race or archive runtime ran. Runtime crash absence
  remains HIGH OPEN.

## 2026-07-10 HTML App-Bridge Replies Are Navigation-Safe

- A queued safe-app-bridge request could previously evaluate its reply after a
  preview reload had begun, injecting into an unstable or replacement page.
- Response dispatch now requires both coordinator and WebView loading state to
  be stable. Stale prior-document replies are discarded rather than replayed.
- Focused Swift source/test parse: PASS; 39,174,144 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,420,224 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-app-bridge-navigation.log`.
- No exact WebKit navigation/message race or archive runtime ran. Runtime crash
  absence remains HIGH OPEN.

## 2026-07-10 HTML Data-Patch Completions Are Revision-Safe

- An older async `data.json` patch could previously finish after a newer
  preview render began and reload its stale fallback HTML over the new page.
- Patch completion now checks stable loading state and exact current shell,
  data, and HTML identities before fallback or DOM refresh.
- Focused Swift source/test parse: PASS; 39,272,448 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,289,152 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-data-patch-revision.log`.
- No exact delayed-patch/reload runtime ran. Ordering proof remains HIGH OPEN.

## 2026-07-10 HTML Preview Completion Is Navigation-Identity Guarded

- Preview loading previously used one boolean, so a delayed cancellation or
  completion from an older navigation could finish a newer load's state.
- The coordinator now retains the active `WKNavigation`; only a matching
  finish/fail callback may advance state, and detach clears it.
- Focused Swift source/test parse: PASS; 39,288,832 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,371,072 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-html-navigation-identity.log`.
- No exact reordered-navigation runtime or focused typecheck ran. Runtime and
  compile proof remain HIGH OPEN for the resource-safe evidence batch.

## 2026-07-10 Bounded Local June Streams Fail Closed On Backpressure

- All three local output buffers previously ignored `yield` results, allowing
  a slow consumer to silently lose llama tokens or June events and still show
  a successful corrupted answer.
- The llama engine, GGUF adapter, and June event wrapper retain 256-event bounds
  but now stop on termination and finish with a precise error on drop. The
  adapter cancels the in-process engine when downstream pressure overflows.
- Focused Swift source/test parse: PASS; 40,992,768 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,731,520 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-local-stream-backpressure-final.log`.
- No model, slow-consumer, focused typecheck, or archive runtime ran. Exact
  cancellation and visible-error proof remain HIGH OPEN.

## 2026-07-10 Bounded Cloud June Events Fail Closed On Backpressure

- The active OpenAI/Anthropic `agent_core` stream previously ignored bounded
  event drops, allowing partial text/tool/permission output to look successful.
- Bounded emission now returns acceptance to the delegate. A drop finishes with
  a precise error, cancels the exact session, terminates the delegate, and
  clears pending permission state while retaining the 256-event cap.
- Focused Swift source/test parse: PASS; 41,795,584 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,502,144 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-cloud-stream-backpressure.log`.
- No provider/slow-consumer/typecheck/archive runtime ran. Exact cloud
  cancellation and UI error proof remain HIGH OPEN.

## 2026-07-10 June Renderer Recovery Is Page- And Navigation-Guarded

- The process-lifetime June WebView previously had no content-process recovery,
  and native bridge frames could evaluate while its page was loading or dead.
- The holder now tracks page readiness plus exact navigation identity. Renderer
  loss cancels all native turns/approvals and reloads the bundled `june://`
  entry; native session storage retains cancelled/error truth for reload.
- Focused Swift source/test parse: PASS; 40,960,000 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,485,760 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-webcontent-recovery.log`.
- No renderer-loss/typecheck/archive runtime ran. Visible recovered-session and
  output proof remain HIGH OPEN.

## 2026-07-10 June Native-To-WebKit IPC Is Serialized And Bounded

- Bounded model/event streams previously fed one asynchronous JavaScript
  evaluation per frame with no bound on WebKit IPC or completion backlog.
- The holder now serializes and order-batches native scripts, capped at 256
  queued scripts and 2 MiB. Generation-guarded completion prevents old IPC from
  reviving after reset; overflow/error cancels turns and reloads bundled June.
- Focused Swift source/test parse: PASS; 41,254,912 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,207,232 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-webkit-ipc-bounds.log`.
- No IPC stress/typecheck/archive runtime ran. Exact memory, throughput, and UI
  recovery proof remain HIGH OPEN.

## 2026-07-10 Every New June Document Invalidates Bridge Readiness

- Host initial/recovery loads had identity tracking, but a full same-origin
  navigation initiated by June could replace the page while `pageReady` stayed
  true.
- `didStartProvisionalNavigation` now registers every main-frame token, resets
  bounded bridge delivery, and cancels turns/approvals when replacing a ready
  document. Registered host-start callbacks remain idempotent.
- Focused Swift source/test parse: PASS; 41,254,912 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,289,152 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-navigation-start.log`.
- No exact self-navigation/typecheck/archive runtime ran. Replacement behavior
  remains HIGH OPEN.

## 2026-07-10 Vault Bookmark Timeout Does Not Await A Blocked Resolver

- The prior throwing task-group timeout could not return until its synchronous
  bookmark-resolution child exited, defeating the five-second deadline.
- A lock-protected one-shot continuation now races unstructured resolver and
  timer tasks. The winner resumes once; a late result is ignored, while saved
  bookmark bytes remain retryable.
- Focused Swift source/test parse: PASS; 44,204,032 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,764,288 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-bookmark-real-timeout.log`.
- No blocked-resolver/typecheck/exact archive runtime ran. Timeout and visible
  restore proof remain HIGH OPEN.

## 2026-07-10 Production Vault Preflight Uses One Bounded Resolution

- Startup integrity and automatic restore previously performed synchronous
  bookmark validation before the bounded async restore; an initial conversion
  also risked two consecutive five-second async resolutions.
- Integrity now awaits the bounded validator once and stores its validation in
  the report; restore orchestration reuses it. Timeout remains fail-closed and
  preserves saved bytes/local data.
- Focused Swift source/test parse with bare-regex enabled: PASS; 46,333,952
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS;
  10,240,000 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-preflight-timeout-final.log`.
- No blocked-preflight/typecheck/exact archive runtime ran. Startup timing and
  visible restore proof remain HIGH OPEN.

## 2026-07-10 Successful Vault Preflight Resolution Is Reused Once

- Even after async preflight hardening, successful startup still resolved the
  same bookmark bytes again inside restore.
- Preflight now caches only the successful in-memory resolution beside exact
  bookmark data. Restore consumes it once on byte equality; mismatch/absence
  re-enters the bounded resolver, and clearing pending restore clears the cache.
- Focused Swift source/test parse with bare-regex enabled: PASS; 46,186,496
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS;
  10,567,680 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-vault-preflight-reuse.log`.
- No exact resolution/security-scope/typecheck/archive runtime ran. One-pass
  restore timing and durability remain HIGH OPEN.

## 2026-07-10 Kokoro CoreML Rendering Is Single-Flight And Cancellable

- Canceling read-aloud previously canceled only its outer task; the unstructured
  detached CoreML render kept running while a new preview could start another.
- Outer cancellation now cancels the render handle. Synthesis is serialized
  process-wide and checks cancellation before/after each chunk, preventing
  overlapping CoreML renders while preserving English voice selection.
- Focused Swift source/test parse: PASS; 42,811,392 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,436,608 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-render-cancellation.log`.
- No CoreML/audio/typecheck/archive runtime ran. Cancellation, memory, and
  audible-English proof remain HIGH OPEN.

## 2026-07-10 Kokoro Failures Surface A Bounded Precise Reason

- All Kokoro failures previously showed the same generic Settings toast,
  hiding whether the package, runtime assets, input, synthesis, or audio path
  failed.
- Toasts now use only curated loader/synthesizer descriptions through the
  normalized 512-character voice bound, otherwise sanitized domain/code.
- Focused Swift source/test parse: PASS; 42,778,624 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 10,076,160 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-kokoro-visible-errors.log`.
- No induced failure/typecheck/CoreML/audio/archive runtime ran. Visible reason
  and audible-English proof remain HIGH OPEN.

## 2026-07-10 Newly Mounted Editors Reclaim Clean Write Leases

- Clean automatic handoff was previously graph-only, so a normal Source/Prose/
  Epdoc mount could remain read-only behind an older clean mounted session.
- All presentations now attempt the existing clean-owner handoff after open.
  Dirty owners still refuse transfer and preserve unsaved work.
- Focused Swift source/test parse with bare-regex enabled: PASS; 44,253,184
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS;
  10,125,312 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-editor-clean-lease-handoff.log`.
- No two-window/edit/save/typecheck/archive runtime ran. Exact editability and
  one-writer behavior remain HIGH OPEN.

## 2026-07-10 Prose Friction Telemetry Is Input-Batched

- Edit and cursor events no longer start one detached telemetry task apiece.
  The editor preserves complete timestamped events in order, flushes once per
  50 ms window, and cancels pending work at teardown.
- The friction actor checks the live opt-in once per batch and retains its
  existing note-switch and substantial-window flush behavior for every event.
- Focused Swift source/test parse: PASS; 10,158,608 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-friction-batching.log`.
- No live input stress, telemetry-store validation, focused typecheck, app,
  Xcode, or archive runtime ran. Exact typing latency and event fidelity remain
  HIGH OPEN.

## 2026-07-10 Initial Hologram Payload Construction Leaves MainActor

- Mini/full hologram presentation and `viewDidMoveToWindow` no longer call the
  synchronous full graph commit. They share the existing version-coalesced
  utility payload builder, preventing duplicate initial work.
- Page-mode anchor placement remains before scheduling, while close-camera
  behavior is deferred until the payload is actually committed.
- Focused Swift source/test parse: PASS; 10,289,704 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-hologram-initial-commit-final.log`.
- No large graph, Metal rendering, page camera, focused typecheck, app, Xcode,
  or archive runtime ran. Startup and graph-to-editor timing remain HIGH OPEN.

## 2026-07-10 Source Snapshot Publication Uses One Worker

- The 140 ms Source/Code snapshot debounce no longer creates a canceled task
  that captures every full text revision. One worker observes a scalar revision
  until quiet and then publishes the current visible text.
- Teardown invalidates that worker and retains the exact synchronous snapshot,
  durability flush, and detach ordering.
- Focused Swift source/test parse: PASS; 10,240,528 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-snapshot-single-worker.log`.
- No large editor, allocation profiling, lens switch, focused typecheck, app,
  Xcode, or archive runtime ran. Exact typing and save proof remain HIGH OPEN.

## 2026-07-10 MAS Diagnostics No Longer Claim GGUF Was Removed

- Startup reports the MAS June boundary and compile-time GGUF linkage without
  touching the backend singleton. Empty June replies preserve cloud, Apple,
  and installed-GGUF recovery choices.
- Generic `Local Models Removed` copy is gone; only the retired MLX selection is
  named unavailable. The active three-model GGUF catalog and Kokoro stay intact.
- Focused Swift source/test parse with bare-regex enabled: PASS; 10,289,680
  bytes maximum RSS, zero swap. Expanded KEELSTONE source gate: PASS;
  2,752,824 bytes maximum RSS, zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-june-local-truth-copy-final.log`.
- No model/backend/provider/Keychain runtime, focused typecheck, app, Xcode, or
  archive ran. Exact local/cloud June output remains HIGH OPEN.

## 2026-07-10 Prose Debouncers Retain One Worker Each

- Binding sync and data detection no longer cancel/recreate tasks capturing a
  complete note for every keystroke. Scalar revisions drive one worker per
  feature, with generation-safe flush/page-switch/teardown invalidation.
- Contextual recall waits, then reads only the bounded live cursor window; it
  no longer retains a full-note fallback revision.
- Focused Swift source/test parse: PASS; 10,240,504 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,736,440 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-prose-single-workers.log`.
- No large-note typing, allocation profile, data-detection/recall UI, focused
  typecheck, app, Xcode, or archive ran. Exact latency/fidelity remain HIGH OPEN.

## 2026-07-10 Source Live Preview Retains One Worker

- Enabled Code/Source live preview no longer cancels tasks that each capture a
  full text revision. One generation-safe worker observes a scalar revision and
  reads current text after the existing 260 ms quiet window.
- Immediate preview enable and disable/teardown cancellation remain intact.
- Focused Swift source/test parse: PASS; 10,224,168 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-live-preview-worker.log`.
- No large-file typing, allocation profile, WebKit preview, focused typecheck,
  app, Xcode, or archive ran. Exact preview latency/fidelity remain HIGH OPEN.

## 2026-07-10 Source Outline Retains One Worker

- A visible outline no longer calculates/captures each full text revision into
  a canceled task. One generation-safe worker applies the existing adaptive
  delay and parses current text only after the scalar revision becomes quiet.
- Immediate reveal/replacement, cache behavior, 256 KiB cap, language, and
  hide/teardown cancellation remain intact.
- Focused Swift source/test parse: PASS; 10,224,144 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,752,824 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-source-outline-worker.log`.
- No large-file outline UI, typing profile, focused typecheck, app, Xcode, or
  archive ran. Exact Source latency remains HIGH OPEN.

## 2026-07-10 Epdoc Autosave Retains One Worker

- Editor changes update authoritative `latestMarkdown` and a scalar generation
  instead of creating canceled two-second tasks that each capture full Markdown.
- One worker waits until quiet and loops when edits arrive during the serialized
  durability write. Flush/page switch invalidation and dirty revision ordering
  remain explicit.
- Focused Swift source/test parse: PASS; 10,404,392 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,703,672 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-epdoc-autosave-worker-final.log`.
- No Epdoc editing, allocation/save-failure/switch runtime, focused typecheck,
  app, Xcode, or archive ran. Exact autosave/fidelity remain HIGH OPEN.

## 2026-07-10 Embedded Editor Routes Cancel Inspector Work

- Embedded graph note/folder routes now clear graph selection and
  `NodeInspectorState` when leaving canvas, matching hologram behavior. This
  cancels profile, summary, and reveal tasks before an editor loads.
- Focused Swift source/test parse: PASS; 10,256,960 bytes maximum RSS, zero
  swap. Expanded KEELSTONE source gate: PASS; 2,769,208 bytes maximum RSS,
  zero swap; retained log
  `/tmp/keelstone-source-gate-20260710-embedded-inspector-quiesce-final.log`.
- No graph/editor runtime or latency measurement ran. The reproduced embedded
  and hologram load/typing hang remains HIGH OPEN pending exact evidence.

## 2026-07-10 Hologram Editor Routes Stop Pinned-Panel Wakeups

- Leaving the hologram canvas now stops the 30 Hz pinned-inspector timer and
  releases graph force-alive state before the editor owns the main thread.
- Canvas re-entry restores tracking; all timer start sites fail closed while a
  non-canvas editor route is active.
- Focused Swift source/test parse: PASS; 45,580,288 bytes maximum RSS,
  11,043,344 bytes peak footprint, zero swap. Expanded KEELSTONE source gate:
  PASS; 9,977,856 bytes maximum RSS, 2,720,056 bytes peak footprint, zero swap;
  retained log
  `/tmp/keelstone-source-gate-20260710-hologram-editor-timer.log`.
- No graph/editor runtime or latency measurement ran. Exact embedded/hologram
  responsiveness remains HIGH OPEN.

## 2026-07-10 Retained MAS Archive Fails GGUF Runtime Linkage

- Primary artifact pages confirm the current catalog filenames and SHA-256
  pins for Qwen3 4B, Qwen3 8B, and Qwen2.5 7B.
- Existing sandbox data includes the exact-size Qwen3 4B file but no current
  verification receipt. No model bytes were opened or hashed.
- The newest retained MAS archive exposes Qwen copy but has no embedded
  `llama.framework` and no executable load command for it. Targeted artifact
  proof is retained at
  `/tmp/keelstone-retained-archive-gguf-link-20260710.log`.
- The release gate now requires both physical framework embedding and app-
  executable linkage whenever a MAS artifact is supplied.
- Focused test-source parse and shell syntax: PASS. Source-only KEELSTONE gate:
  PASS; 10,256,384 bytes maximum RSS, 2,736,440 bytes peak footprint, zero
  swap; retained log
  `/tmp/keelstone-source-gate-20260710-appstore-gguf-link.log`.
- A current archive, receipt migration, model load, token, cancellation, and
  visible June reply are unproven. Exact local GGUF behavior remains HIGH OPEN.
- Saved non-secret state selects `openai:gpt-5.5`; Swift and `agent_core` both
  admit that exact ID. No cloud-consent preference is present, so the expected
  current behavior is a visible pre-send consent blocker. No Keychain read or
  provider request ran. Cloud output remains HIGH OPEN.

## 2026-07-10 Epdoc Cross-Surface Source Reconciliation

- Each lens transition awaits the active surface flush. Document stays mounted
  while inactive; Source and Prose remount from the shared Markdown snapshot;
  hidden Epdoc reloads only after another lens changes canonical Markdown.
- Existing App Store regressions cover early edits before load settlement,
  concurrent flush ordering, hidden reactivation, blank recovery, table and
  blockquote projection, and stale surface-registration teardown.
- Focused Swift source/test parse: PASS; 45,694,976 bytes maximum RSS,
  11,010,600 bytes peak footprint, zero swap.
- No editor/WebKit runtime or persisted round trip ran. Exact Epdoc → Source →
  Prose → Epdoc content and formatting fidelity remains HIGH OPEN.

## 2026-07-10 Kokoro Installed-Package Reconciliation

- The MAS sandbox retains the full Kokoro package at roughly 942 MB. All 75
  manifest-declared files exist at their exact declared sizes; the manifest
  supports `en-US` and the saved voice is English `af_bella`.
- The newest retained MAS executable contains the statically linked
  `KokoroPipeline` runtime symbols. This is not the disconnected-runtime failure
  found in the GGUF artifact.
- Earlier exact-archive evidence records readiness, nine-chunk English-path
  rendering, audio-engine start, playback start, and playback completion with
  no Kokoro failure. Evidence remains at
  `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/runtime-logs/exact-archive-runtime-kokoro-completed.log`.
- No model/Core ML load or audio ran in this reconciliation. A fresh current-
  source Settings preview, owned-surface matrix, and owner-audible confirmation
  remain HIGH OPEN.

## 2026-07-10 Retained MAS Artifact Gate Is Finite And Red

- The newest retained archive fails with 12 findings: two GGUF framework/link
  findings, one parked account/backend marker finding, seven stale JuneWeb
  identity/configuration findings, and two privacy-manifest findings.
- Full retained log: `/tmp/keelstone-retained-app-gate-20260710.log`.
- The artifact scan used 59,719,680 bytes maximum RSS, 6,209,872 bytes peak
  footprint, and zero swap. It built nothing and loaded no model.
- Current source-only KEELSTONE checks are green. The next meaningful proof is
  one serial current-source MAS archive followed by only the four owner-visible
  runtime legs; additional optional source hardening is out of scope.

## 2026-07-12 Durable-Handoff Resume And Current-Tip Preflight

- Remote identity: PASS. The handoff commit, local `HEAD`, fetched
  `origin/feat/goose-surface`, and live `git ls-remote` value are all
  `f73b3244c09a76a14961050964969bcb5ac9fa70`.
- Worktree at resume: clean. The Xcode package-resolution inspection modified
  only `Package.resolved`; that tool-created delta was restored exactly and the
  worktree was clean again before feature edits.
- Resource preflight: PASS. `memory_pressure` reported 77% free; `vm.swapusage`
  reported 0.25 MiB used of 1 GiB; the volume had 808 GiB free; no competing
  Xcode/compiler/model/Epistemos process was present.
- `bash -n scripts/keelstone-release-gate.sh`: PASS.
- `bash scripts/keelstone-release-gate.sh`: PASS with 40 source checks, but
  this is not equivalent to the recorded 827-check gate and is insufficient
  archive evidence.
- Focused executable source-guard probe: EXPECTED RED. The committed gate is
  missing `require_tree_contains()`, staged/built JuneWeb prompt-drift checks,
  `require_appstore_local_gguf_runtime`, the canonical llama framework path,
  and the built-executable linkage witness.
- Focused App Store test attempt: NOT EXECUTED. The signed invocation stopped
  before tests because no matching `com.epistemos.appstore` development profile
  exists. A `CODE_SIGNING_ALLOWED=NO` retry stopped in `build-rust.sh` because
  `cargo`/`rustc` are absent. These are environment failures, not test passes
  or product failures.
- JuneWeb source prerequisite: RED. `.june-web-stage` has zero tracked files,
  the stage directory is absent, and `$HOME/dev/june-epistemos` is absent.
  `build-june-web.sh` and CI require one of those exact sources.
- Fresh build/archive/artifact/runtime evidence: NOT RUN. Signing, Rust, and
  JuneWeb prerequisites are unresolved; no app, model, provider, Keychain,
  owner vault, Core ML, or audio operation ran.
- Verification debt: rerun the focused App Store source-guard test after the
  Rust toolchain is installed; restore the exact owner-modified June donor or
  reviewed staged output; obtain valid signing; then perform one serial Release
  archive, all artifact gates, and the finite owner-visible runtime matrix.

## 2026-07-12 Canon-First Reset Continuity Evidence

- Full external master canon restore: PASS. Recursive comparison with
  `/Volumes/treasure/Epistemos-External-Plan-Assets-2026-07-12` passed after
  excluding only `._*`; 36 content files and 18 original source ZIPs exist at
  the canonical Downloads path.
- Corrected preparation restore: PASS. Recursive comparison passed for all nine
  files at the canonical Downloads path.
- Offline assets: PASS at the pre-continuity publication tip. Both existing Git
  bundles verify as complete histories at `f73b3244c09a76a14961050964969bcb5ac9fa70`;
  the external plan-assets copy and Codex-state backup pass their recorded
  checksums. A new bundle is required after this continuity commit.
- June donor recovery: BLOCKED, not fabricated. GitHub retains the durable
  `BlickandMorty/os-june` `epistemos-vendor` base, but not local commit
  `7105c43c8622cc546075f7ff1e20680e2009f8bb` or the 92-file dirty overlay.
  Git fetch, all current remote heads, the GitHub commit endpoint, and the
  commit archive endpoint do not expose that object. The prior Codex-state
  backup preserves exact patch records; reconstructed output must match the
  recorded main/index/shim SHA-256 values before being called the reviewed
  July 10 stage.
- Reset/resume script syntax: PASS. Current dry run verifies canon, preparation,
  branch, fetched/live origin, Prompt 2 key, free memory, swap, pages throttled,
  and no competing process. Before this commit it intentionally reports the
  dirty worktree as fatal and reports five environment prerequisites as
  blocked: Rust, Bun, exact June stage, exact June donor, and Apple signing.
- Full restore backup scripts now include the June donor and Rust toolchain when
  present, record missing optional paths instead of implying restoration, and
  no longer require a nonexistent standalone canon ZIP when the full canon
  folder already contains its original archives.
- No Xcode test/build/archive, app launch, model/provider/Keychain/vault/audio
  operation, or runtime evidence ran during continuity hardening.
- Surgical correction: `scripts/keelstone-release-gate.sh` now enforces the
  committed staged/built JuneWeb contract and, when a MAS app is supplied,
  requires both `llama.framework/Versions/A/llama` and a matching `otool -L`
  load command. The active App Store source-guard test now owns the GGUF
  embedding/linkage strings as well as JuneWeb drift checks.
- Post-correction lightweight evidence: `bash -n`, `xcrun swiftc -parse` for
  the active App Store test file, `git diff --check`, and every explicit
  source-contract marker all PASS.
- Post-correction source gate: correctly RED with exactly two findings: the
  missing `.june-web-stage/dist/index.html` and missing
  `.june-web-stage/tauri-internals-shim.js`. This is the truthful current
  release blocker; the prior 40-check green can no longer bypass it.
