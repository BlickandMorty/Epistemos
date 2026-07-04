# Epistemos — App Store review notes + verified trust posture (Front & Feel, 2026-07-04)

Reviewer-facing justifications + the internal evidence behind them. Every claim below was verified by
reading the actual code this session (not the comments). Scope: the Front & Feel surfaces (landing,
browser, notes, Epdoc/KaTeX, meeting, onboarding). Goose/agent lanes are out of scope here.

## Trust posture — the three surfaces users must trust

**Meetings.** Capture is on-device (`SpeechAnalyzer`) and **audio is never written to disk**. No
transcript text, speaker names, or titles are logged (`.public` sweep of all meeting files = clean).
The only on-disk transcript copy is a crash-recovery draft in the **sandboxed** Application Support
container, named `<sessionId>.json` (a UUID, not the meeting title), deleted on save.

**Research / notes.** Untrusted note links are gated deny-by-default (`NoteLinkClassifier`): only
http/https/mailto open; `file://`, `javascript:`, and custom schemes are consumed (proven 16/16).
Note titles + file paths are logged `.private`. KaTeX renders with `trust:false` (no `\href`→js XSS),
assets served locally. The Epdoc editor's `epistemos-doc://` file handler is path-traversal-safe
(component validation + symlink resolution + descendant-containment + regular-file-only).

**Browsing.** Ephemeral data store (`WKWebsiteDataStore.nonPersistent()`) — cookies/cache/history
never persist. A tracker content-blocker is installed, Safe-Browsing fraud warning is pinned on, and
strict ATS (HTTPS-only) is enforced. The JS→native bridge exposes exactly one handler (scroll →
toolbar hide/show, a cosmetic no-op) with a validated payload — untrusted pages can reach nothing
sensitive.

## Entitlements (Epistemos-AppStore.entitlements) — each justified
- `app-sandbox` — sandboxed (required).
- `device.audio-input` — on-device meeting/dictation transcription (see `NSMicrophoneUsageDescription`).
- `files.bookmarks.app-scope` + `files.user-selected.read-write` — the user's chosen vault folder.
- `network.client` — arXiv fetch, cloud LLM calls, Kokoro voice-model download (all HTTPS).
- `network.server` — **reviewer note:** this backs the optional local Goose/Work web surface
  (localhost only, no inbound WAN). If that surface is not in the submitted build, drop this entitlement.
- **No `allow-jit`, no `disable-library-validation`** — hardened runtime intact.

## Privacy manifest (PrivacyInfo.xcprivacy) — accurate
- `NSPrivacyTracking: false`, `NSPrivacyTrackingDomains: []`, `NSPrivacyCollectedDataTypes: []` — the
  app collects **no** data and does **no** tracking (verified: no Firebase/Mixpanel/Sentry/analytics
  anywhere; onboarding sends nothing external).
- Required-reason APIs declared with correct codes: FileTimestamp `C617.1`, SystemBootTime `35F9.1`,
  DiskSpace `85F4.1` (pre-download write-gate — corrected from the display code this session),
  UserDefaults `CA92.1`.

## Secrets
Provider API keys are stored in the **Keychain** (146 `SecItem`/`kSec` sites) — no hardcoded
credentials in source.

## Known non-blocking issues (documented, not shipping-app defects)
- **Test target won't compile** (`WorkSPAServerTests.swift` → removed Goose `GooseWebSurfaceView`) — a
  Goose-lane test-only break; the *app* builds green. Front & Feel tests are written + probe-verified
  out-of-target meanwhile. See `TEST_SUITE_BLOCKED_GOOSE_SYMBOL_2026_07_04.md`.
- **Kokoro voice model install** is a sanctioned external step — read-aloud stays disabled (with an
  install-pointer tooltip) until the user downloads the model via Settings → Voice.

## Session fixes contributing to this posture
Privacy log redaction (a4d73c170), untrusted-link gate (194a74c90 + NoteLinkClassifier 36f2f1195),
browser fraud-warning (d6c396e9d), mic usage string (0477cf961), disk-space reason code (022ebe914),
read-aloud install-pointer (#52, 6a745937d), plus the landing/graph perf fix and #41 dataview renderer.
