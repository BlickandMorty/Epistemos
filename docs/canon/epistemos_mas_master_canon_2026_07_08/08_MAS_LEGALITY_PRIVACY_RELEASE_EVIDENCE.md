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

## MAS legality matrix

| Area | Verdict | Release evidence |
|---|---|---|
| MAS June | SAFE WITH CONDITIONS | bundled assets, in-process `agent_core`, approval UI, no forbidden symbols |
| Epdoc Assist | SAFE WITH CONDITIONS | same June session/tool/provenance authority, no second DB/runtime |
| KEELSTONE | SAFE WITH CONDITIONS | entitlements, bookmarks, coordinated writes, conflict/soak tests |
| LUMENLENS | SAFE WITH CONDITIONS | bundled editor, no private APIs, serializer/epoch proof |
| RECKONER | SAFE WITH CONDITIONS | bundled grid/WASM, IronCalc authority, artifact truth, no data room |
| Quick Capture/voice | SAFE WITH CONDITIONS | mic consent, visible recording, zero-loss crash recovery |
| Sync/iCloud | SAFE WITH CONDITIONS | file coordination, placeholder handling, conflict UI |
| ResearchHub | SAFE WITH CONDITIONS | provider matrix, attribution, retention/purge, no scraping |
| Browser | SAFE only as WebKit | no Chromium/browser-use in MAS |
| StoreKit/proxy/cloud | SAFE WITH CONDITIONS | StoreKit/App Store Server proof, Keychain token |
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
- Browser/WebKit scope and no Chromium/browser-use automation.
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

For overnight/autonomous work, these triggers do not mean "stop all useful
work." They mean: do not proceed with the unsafe release/product branch; record
the exact blocker, evidence, and owner decision needed; continue reversible MAS
cleanup, contradiction searches, source reading, tests, docs, and hardening
that do not require the blocked decision.
