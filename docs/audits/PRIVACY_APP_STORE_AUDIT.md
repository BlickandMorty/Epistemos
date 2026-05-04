# Privacy + App Store Audit

Date: 2026-04-28

Verdict: MAS unsafe-surface posture is now freshly verified for the current code-level gate, but this is not a final ship claim because manual Phase S checks, copy review, bundle-size review, and entitlement review remain deferred. Computer-use and shell-like automation must stay direct-build-only or stubbed in the MAS profile.

## Evidence

- MAS entitlements exist at `Epistemos/Epistemos-AppStore.entitlements`.
- Privacy manifest exists at `Epistemos/Resources/PrivacyInfo.xcprivacy`.
- MAS computer-use stubs exist at `Epistemos/AppStore/AppStoreComputerUseStubs.swift`.
- Direct-build screen capture code is gated out of MAS in `Epistemos/Omega/Vision/ScreenCaptureService.swift`.
- `Epistemos/Omega/OmegaPermissions.swift` and `Epistemos/Omega/Vision/TCCPermissionState.swift` now provide inert `EPISTEMOS_APP_STORE` branches that do not import ScreenCaptureKit or call Apple Events APIs.
- App Store Info.plist and scheme files are present in the worktree.
- Fresh MAS build passed in `/tmp/epistemos_mas_tcc_build.log` (`** BUILD SUCCEEDED **`, `EXIT:0`).
- Fresh binary audit passed in `/tmp/epistemos_mas_tcc_binary_audit.log`: no ScreenCaptureKit/AXorcist/`omega_ax` links or bundle paths, no dangerous `libomega_mcp` process/PTY symbols, and no MAS object references to ScreenCaptureKit. The only `python` path hit is the CodeEdit `tree-sitter-python` grammar resource, not a Python runtime.
- Raw Thoughts provider-surface patch preserved the MAS build in `/tmp/epistemos_mas_build_after_raw_thoughts_patch5.log` (`** BUILD SUCCEEDED **`, `EXIT:0`) and added explicit Anthropic `redacted_thinking` capture tests without claiming hidden chain-of-thought access.
- Focused App Store privacy manifest tests passed in `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log` (`** TEST SUCCEEDED **`, `EXIT:0`): no tracking, no tracking domains, no collected-data types, and the expected accessed API reason codes.
- `PrivacyDetailView.swift` was rechecked during S.6 automation: it is ASCII-clean and its cloud-provider/telemetry wording stays limited to the current local-first behavior. Manual App Store Connect copy review remains deferred.
- `.epdoc` editor resource packaging was pruned and rechecked in `/tmp/epistemos_tiptap_bundle_prune_patch44_gate.log`: source and built editor resources are 1.1M, `Contents/Resources/Editor` exists in the MAS build, there are no root-level flattened editor duplicates, no stale plain JS/CSS counterparts for `.br` assets, and no KaTeX `.ttf`/`.woff` files.
- Clean Debug MAS size probe is recorded in `/tmp/epistemos_mas_bundle_size_audit_patch45_clean_probe.log` and `docs/audits/APP_BUNDLE_SIZE_AUDIT_2026_04_29.md`: no test plug-in contamination, app 650M, resources 8.6M, editor resources 1.1M. Release App Store size proof is still blocked by disk pressure.

## Required Classification Table

| Feature | App Store safe? | Entitlement needed | Privacy disclosure needed | Recommended action |
|---|---|---|---|---|
| Prose editor | App Store V1 safe | sandbox file access/bookmarks | file timestamp/user defaults as applicable | Ship |
| `.epdoc` documents | App Store V1 safe if local assets only | sandbox file access/bookmarks; JIT if WKWebView requires it | file access; no collection unless cloud sync added | Ship only after smoke proof; editor resource tree is pruned and packaged correctly |
| Search/readable blocks | App Store V1 safe | none beyond file/db access | no collection | Ship |
| Instant Recall/local embeddings | App Store V1 safe if local-only and bounded | none beyond local file/model access | disclose model downloads if network used | Ship behind recall flag until tested |
| Cloud model providers | Safe with disclosure/settings clarity | network client | disclose user-sent prompts/content in privacy policy/App Privacy answers | Ship if copy is exact |
| Local model downloads | Safe with disclosure | network client; disk storage | disclose downloads/cache; size impact | Ship with storage controls |
| Raw Thoughts | App Store V1 safe if local and honest | file access/bookmarks | no collection; explain local run logs | Ship behind feature flag until live run-link smoke passes |
| Anthropic/OpenAI reasoning surfaces | Safe if only provider-returned data stored | network client for cloud calls | disclose provider calls; do not claim hidden CoT | Ship with exact wording; redacted-thinking storage tests are green |
| Computer use / ScreenCaptureKit | Not MAS V1 surface | screen recording/TCC; possible review risk | sensitive screen data | Direct build only; MAS stubs |
| Accessibility/CGEvent automation | Not MAS V1 surface | Accessibility/Apple Events; automation TCC | sensitive control of apps | Direct build only; MAS hidden |
| Shell/PTY/Docker tools | Not MAS V1 safe | process execution; user files | high risk | Direct build only; hidden in MAS |
| NightBrain LaunchAgent scheduler | Not MAS V1 surface | LaunchAgent/background helper behavior | background activity | Direct build only; MAS launch path and plist bundle copy are gated/excluded |
| iMessage drivers | Unclear/high risk | automation/contacts/messages entitlements or private behaviors | sensitive communications | Hide until dedicated review |
| MCP external servers | Risky if arbitrary | network/file/process depending on server | depends on tool | MAS allow only safe built-in tools |
| Diagnostics/signposts | Safe if local only | none | no collection | Ship hidden under Advanced |
| JIT entitlement | Potential review risk | `com.apple.security.cs.allow-jit` if retained | justify WKWebView/local JS use | P0 review note |

## P0/P1 Privacy Risks

| Risk | Severity | Required fix |
|---|---:|---|
| MAS-visible computer-use controls | P0 | Code-level and binary-level gates are green; runtime UI smoke remains manual-deferred |
| Direct-build LaunchAgent leaking into MAS | P1 | NightBrain scheduler registration and fallback inline launch are compile-time gated out of MAS/sandbox builds; App Store target excludes `Resources/LaunchAgents/com.epistemos.nightbrain.plist`; focused release-packaging tests and fresh MAS bundle gate are green |
| Privacy copy overclaims telemetry/cloud behavior | P0 manual-gate / automated slice green | Settings privacy copy and `PrivacyInfo.xcprivacy` are covered by `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`; App Store Connect metadata wording still needs manual review before submission |
| JIT entitlement lacks review rationale | P1 | Add App Review note explaining local WKWebView/editor requirement or remove entitlement if not needed |
| External MCP/tool execution in MAS | P0 | Built-in safe tools only; no arbitrary process execution |
| Bundled model/data size not gated | P1 | Clean Debug size audit is recorded; Release App Store size proof remains required before submission because the Release build hit disk pressure |

## App Store V1 Safe With Entitlement/Disclosure

- Vault file access with security-scoped bookmarks.
- Network client for cloud model providers and model downloads.
- WKWebView/Tiptap document editor if local assets and message handlers are constrained.
- Local model cache if storage controls and disclosures are present.

## Direct Build Only

- ScreenCaptureKit visual automation.
- Accessibility tree control and CGEvent typing/clicking.
- Shell, PTY, Docker, arbitrary local process tools.
- NightBrain LaunchAgent scheduler/background helper path.
- External MCP servers that can execute processes or read broad filesystem areas.
- iMessage automation unless separately reviewed.

## Required Fresh Verification

1. Re-run `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-mas-tcc-build build CODE_SIGNING_ALLOWED=NO` after any MAS/privacy/computer-use change.
2. Confirm `Epistemos-AppStore` links `AppStoreComputerUseStubs.swift`.
3. Confirm direct ScreenCaptureKit/AX/CGEvent code is absent from MAS binary or unreachable under MAS symbols; current evidence is `/tmp/epistemos_mas_tcc_binary_audit.log`.
4. Confirm direct-build LaunchAgent resources are absent from the MAS bundle; current evidence is `/tmp/epistemos_nightbrain_mas_scheduler_patch41_gate.log`.
5. Confirm PrivacyInfo reason APIs match tests; current automated proof is `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`.
6. Confirm Settings privacy copy does not claim no cloud data is sent when cloud providers are enabled; current source review is green, final App Store Connect copy remains manual-deferred.
7. Capture full Release bundle size and top bundled resources. Current partial evidence: clean Debug MAS app is 650M, resources are 8.6M, `.epdoc` editor resources are 1.1M, and the Release proof is blocked by disk pressure.
