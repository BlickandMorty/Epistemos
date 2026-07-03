# Owner actions — hardening items that need YOUR input, hardware, or a validated rebuild

The autonomous deep-hardening wave is complete: 18 findings fixed + build-verified (all CRITICAL/HIGH on the kept surfaces), 3 regression tests passing, KEEP set intact. Full detail in HARDENING_AUDIT.md + PROGRESS.md. The items below are the ONLY ones left, and each is blocked on something I can't safely do autonomously. Ordered by value.

## 1. SEC-1 (HIGH) — drop `cs.disable-library-validation` from the direct-distribution lane?
- **What:** `Epistemos/Epistemos.entitlements` still has `com.apple.security.cs.disable-library-validation` (allows loading dylibs not signed by your team). The MAS lane never had it and works — and the third-party unsigned framework that needed it (llama.framework/MLX) was REMOVED this session.
- **Why I didn't just do it:** removing it is RISKY — if ANY dylib the direct app loads (the Rust dylibs via embed-and-sign-rust-dylib.sh, Kokoro CoreML, etc.) is not signed with your Developer ID at build time, the app fails to launch. A prior memory says "KEEP it."
- **Your action:** decide risk tolerance. To test safely: build the direct/Developer-ID Release, remove the key, re-sign, and launch — if it runs (all embedded dylibs are team-signed), keep it removed (least-privilege win). If it crashes on a code-signing/dylib error, restore it. This needs a real signed build + launch, which I can't validate headless.

## 2. SEC-8 (LOW, but MAS-blocking if wrong) — app group prefix
- **What:** `Epistemos-AppStore.entitlements` uses `group.com.epistemos.shared`. MAS provisioning may require the app group to match what's registered in App Store Connect (often TEAMID-prefixed).
- **Your action:** in App Store Connect → Identifiers → App Groups, confirm the exact registered app-group ID and make the entitlement string match it exactly (both the app target and the widgets target if you ship widgets). I can't see your ASC registration.

## 3. WEB-4 (MED) — add CSP to the 3 bundled editor UI docs
- **What:** `Resources/Editor/editor.html`, `Resources/Editor/code-editor.html`, `Resources/CoreEditor/index.html` have no Content-Security-Policy.
- **Why I didn't just do it:** the fix must be at the SOURCE (js-editor/ + the CoreEditor source, not the built artifacts) and requires a `npm`/esbuild rebuild + tuning `script-src`/`style-src`/`connect-src` to the editor's actual loads (custom scheme, inline bootstrap, KaTeX, bridge). A too-strict CSP silently breaks notes/code editing, and I can't load-test the editor headless.
- **Your action:** on a machine with `node`/`npm`, add a `<meta http-equiv="Content-Security-Policy">` to the source HTML, run `bash build-tiptap-bundle.sh` + `bash build-coreeditor-bundle.sh`, launch, and confirm the editor still renders + edits. I can draft the CSP string if you want.

## 4. MEET-8 (MED) — AirPods disconnect mid-meeting stalls transcription
- **What:** `EpistemosSpeechAnalyzer.observeRouteChanges` is wired to `.AVAudioEngineConfigurationChange` but has 0 callers; a route change (AirPods connect/disconnect) can silently stall capture.
- **Why I didn't just do it:** the fix (wire it up to restart the audio engine/tap on route change) needs runtime verification with actual audio-route changes — done wrong it causes worse issues (double-start, lost audio) — and I can't test audio hardware headless.
- **Your action:** confirm you want this, then it needs a device test (start a meeting, disconnect/reconnect AirPods, verify transcription resumes). I can implement the wiring for you to test.

## 5. Removal test-debt (in progress, NOT owner-blocked) — informational
The cloud-only + Omega removal left a cluster of source-guard tests that assert removed strings (LocalTextModelID, ComputerUseBridge, omega-ax, etc.). They COMPILE but fail at runtime. A subagent is reconciling them now (flip/remove the dead assertions, keep the valid ones). This is test-debt, NOT app breakage — the app is verified cloud-only. Tracked as F-REMOVAL-CASUALTY-TESTS in HARDENING_AUDIT.md.

## Lower-value / already-handled
- BRW-3 (private KVC `drawsBackground`): no clean public WKWebView API exists; the private KVC is the standard workaround. App Review MAY flag it — accept or find an alternative if flagged.
- A11Y-1 (graph VoiceOver): a large accessibility build-out for the Metal graph; scope separately.
- ARX-1/ARX-2 (arXiv dedup + rate-limit): moderate; deferred with analysis in HARDENING_AUDIT.md.
- SEC-5/6/7, MEET-5/6, CONC-15-storage: verified already-resolved or moot (see audit).
