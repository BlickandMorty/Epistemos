# 08 - MAS Legality, Privacy, and Release Evidence

This document is a release gate, not background. If a feature touches App Store rules, privacy, networking, provider APIs, recording, file access, monetization, browser surfaces, or external sources, this doc must be checked.

## Official source spine checked for this fusion

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Upcoming Requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple Privacy Manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple Required Reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple macOS Sandbox file access: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox
- Apple WKWebView: https://developer.apple.com/documentation/webkit/wkwebview
- Apple StoreKit: https://developer.apple.com/documentation/storekit
- Apple App Store Server API: https://developer.apple.com/documentation/appstoreserverapi
- Apple EventKit event-store access: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- arXiv API: https://info.arxiv.org/help/api/index.html
- arXiv API Terms: https://info.arxiv.org/help/api/tou.html
- Crossref REST tips: https://www.crossref.org/documentation/retrieve-metadata/rest-api/tips-for-using-the-crossref-rest-api/
- NCBI E-utilities: https://www.ncbi.nlm.nih.gov/books/NBK25497/
- Semantic Scholar API: https://www.semanticscholar.org/product/api
- Semantic Scholar License: https://www.semanticscholar.org/product/api/license
- OpenAlex Docs: https://developers.openalex.org/
- Unpaywall API: https://unpaywall.org/products/api
- Europe PMC REST API: https://europepmc.org/RestfulWebService
- DOAJ docs/API: https://doaj.org/docs/faq/
- CORE API docs: https://api.core.ac.uk/docs/v3
- OSF API: https://developer.osf.io/
- GitHub REST API: https://docs.github.com/en/rest
- Reddit API: https://www.reddit.com/dev/api/
- X API: https://docs.x.com/x-api/introduction
- Mastodon API: https://docs.joinmastodon.org/api/
- Bluesky docs: https://docs.bsky.app/
- Open Library API: https://openlibrary.org/developers/api
- Internet Archive developer docs: https://archive.org/developers/
- Gutendex: https://gutendex.com/
- Zotero Web API: https://www.zotero.org/support/dev/web_api/v3/
- Readwise API: https://readwise.io/api_deets

## Apple rules that control the architecture

- App Review Guidelines require apps to be stable, complete, reviewable, and include detailed notes for non-obvious features and purchases.
- Mac App Store apps must be sandboxed and self-contained.
- Apps must not download, install, or execute code that changes app features/functionality after review.
- Web browsing surfaces must use WebKit unless a specific entitlement applies.
- Recording/logging user activity requires explicit consent and a clear indication.
- Apps accessing third-party service content must have permission under that service's terms.
- As checked on 2026-07-08, Apple upload requirements say new app uploads
  must use the current required Xcode/SDK family, and macOS uploads must not
  carry `com.apple.quarantine` extended attributes. Re-check before every
  release because this rule changes over time.
- Privacy manifests and required-reason API usage must be audited before archive submission.
- Provider/API integrations need permission under provider terms, attribution
  where required, and cache/purge/retention behavior that can be explained in
  App Review notes.
- EventKit access must be explicitly requested, limited to the access actually
  needed, denial-safe, and accompanied by the macOS Calendar sandbox
  entitlement when the app reads calendar data. Calendar and reminder stores
  remain external truth rather than a hidden Epistemos copy.
- The July 13 free-V1 boundary makes June, Browser, and ResearchHub future paid
  and hidden/inert. Paid status never relaxes their App Review, WebKit, source,
  privacy, or legality obligations.

## MAS legality matrix

| Area | Verdict | Release evidence |
|---|---|---|
| MAS June (future paid) | SAFE WITH CONDITIONS | hidden/inert in free V1; bundled assets, in-process `agent_core`, approval UI, no forbidden symbols when later activated |
| Epdoc Assist (future paid) | SAFE WITH CONDITIONS | hidden/inert in free V1; same June session/tool/provenance authority, no second DB/runtime when later activated |
| KEELSTONE | SAFE WITH CONDITIONS | entitlements, bookmarks, coordinated writes, conflict/soak tests |
| LUMENLENS/Epdoc planner | SAFE WITH CONDITIONS | bundled editor, no private APIs, readable Markdown task/Meeting truth, serializer/epoch/minimal-diff/rebuild proof |
| RECKONER | SAFE WITH CONDITIONS | bundled grid/WASM, IronCalc authority, artifact truth, no data room |
| Quick Capture/voice | SAFE WITH CONDITIONS | mic consent, visible recording, zero-loss crash recovery |
| Sync/iCloud | SAFE WITH CONDITIONS | file coordination, placeholder handling, conflict UI |
| Meeting/calendar/tasks | SAFE WITH CONDITIONS | EventKit least privilege, Calendar entitlement, consent/denial state, external-reference integrity, no second task/calendar/transcript DB |
| Kokoro local voice | SAFE WITH CONDITIONS | free-V1 exception; local routing, no general model/agent surface, no mic permission for read-aloud alone |
| ResearchHub (future paid) | SAFE WITH CONDITIONS | hidden/inert in free V1; provider matrix, attribution, retention/purge, no scraping |
| Browser (future paid) | SAFE only as WebKit | hidden/inert in free V1; no Chromium/browser-use in MAS |
| StoreKit/proxy/cloud (deferred) | SAFE WITH CONDITIONS | no free-V1 implementation dependency; later StoreKit/App Store Server proof and Keychain token |
| Local models | SAFE/RESEARCH NEEDED | Foundation Models preferred; no sidecar/downloaded runtime |
| Parked lanes | FORBIDDEN in archive | strings/nm/rg scans clean |

## Entitlement checklist

```bash
find . \( -name "project.yml" -o -name "*.entitlements" -o -name "PrivacyInfo.xcprivacy" \) -print
xcodebuild -scheme Epistemos-AppStore -showBuildSettings | rg "SWIFT_ACTIVE_COMPILATION_CONDITIONS|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER"
codesign -d --entitlements :- /tmp/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app
```

Watch for:

- `com.apple.security.app-sandbox`
- user-selected read/write file access
- app-scoped bookmarks
- `network.client` if network features ship
- `network.server` only if explicitly justified and App Review-noted
- `com.apple.security.personal-information.calendars` only when the shipped
  EventKit feature reads calendar data, with matching permission copy and
  denial-safe UI
- no broad temporary exceptions without reason

## Privacy manifest / required reason checklist

Search for APIs and behaviors that may trigger privacy manifest or required-reason entries:

```bash
rg -n "UserDefaults|stat\(|fileSize|creationDate|modificationDate|disk|volume|mach_absolute_time|systemUptime|Speech|AVAudio|Microphone|Vision|PDFKit|URLSession|Keychain|WKWebView|NSFileCoordinator" Epistemos agent_core
find . -name "PrivacyInfo.xcprivacy" -print -exec plutil -p {} \;
```

## App Review notes checklist

Explain these plainly:

- MAS/June agent behavior and approval gates.
- What cloud lane sends off-device, if anything.
- StoreKit/proxy flow, if monetized.
- User-selected vault access, bookmarks, external edits, conflict handling.
- ResearchHub provider sources and legal OA-only rule.
- Reddit/X/BYO-source retention or limitations.
- Recording/voice capture and how users know recording is active.
- Meeting/calendar permission, external-event references, recording/transcript
  retention, and follow-up-task behavior.
- Kokoro local read-aloud and why it does not request microphone access.
- Browser/WebKit scope, ResearchHub source policy, and their paid-only hidden/
  inert state in free V1; no Chromium/browser-use automation.
- Any loopback/network.server entitlement if retained.

## Release evidence commands

```bash
# ZIP/source inventory
find . -maxdepth 2 -name "*.zip" -print
shasum -a 256 *.zip

# Current Apple toolchain/upload prerequisites
xcodebuild -version
xcrun --sdk macosx --show-sdk-version

# MAS lane and parked-lane search
rg -n --hidden "EPISTEMOS_APP_STORE|MAS_SANDBOX|EPISTEMOS_EXPERIMENTAL|KINDRED_ENABLED|OpenChamber|ProAgent|1Code|Goose|Kindred|browser-use|Chromium|terminal|subprocess|stdio|local server|network.server" .

# Build and archive
xcodegen generate
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build
xcodebuild -scheme Epistemos-AppStore -configuration Release archive -archivePath /tmp/Epistemos-AppStore.xcarchive

# Archive leak scans
codesign -d --entitlements :- /tmp/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app
strings /tmp/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/* | rg -i "goose|openchamber|kindred|browser-use|chromium|playwright|tauri|node|pty|subprocess|stdio|localhost"
find /tmp/Epistemos-AppStore.xcarchive -exec xattr -p com.apple.quarantine {} + 2>/dev/null

# Tests
swift test
cargo test --manifest-path agent_core/Cargo.toml
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' test
```

## Storage soak suite

- 10k-file initial mount.
- 1k-file sync-pull burst.
- nested rename storm.
- external edit while note open, clean and dirty cases.
- `kill -9` during write.
- corrupt index DB quarantine/rebuild.
- stale bookmark.
- volume unmount/remount.
- iCloud placeholder/dehydration.
- dataset CSV move/delete/edit.
- Quick Capture crash mid-record/save.
- ResearchHub purge/retention job.

## STOP triggers

Stop the unsafe branch, log `OWNER_DECISION_REQUIRED` when needed, and keep
working on safe adjacent hardening if:

- App Store archive still contains OpenChamber/ProAgent/Goose/Kindred/browser-use/subprocess/stdio/terminal symbols.
- Current Xcode/SDK upload requirement is not met.
- Any archived app file still has `com.apple.quarantine`.
- Entitlements include risky capability without written App Review note.
- PrivacyInfo is missing while required-reason APIs are present.
- Reconcile != rebuild.
- Atomic write soak produces partial files.
- MiniChat creates a second transcript DB or tool registry.
- ResearchHub adapter requires scraping or uncertain commercial terms.
- A build agent wants to make GRDB or proprietary opaque storage durable truth.
- Free V1 can enter or initialize June, Browser, or ResearchHub through any
  route, shortcut, deep link, restoration, provider startup, automatic job, or
  background task.
- EventKit denial, restricted access, deleted/changed event identifiers, or
  recording consent can cause silent data loss or hidden capture.

For overnight/autonomous work, these triggers do not mean "stop all useful
work." They mean: do not proceed with the unsafe release/product branch; record
the exact blocker, evidence, and owner decision needed; continue reversible MAS
cleanup, contradiction searches, source reading, tests, docs, and hardening
that do not require the blocked decision.
