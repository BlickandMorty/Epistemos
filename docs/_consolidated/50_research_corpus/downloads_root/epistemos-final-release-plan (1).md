# Epistemos — Final Release Document

**Application:** Epistemos — Native macOS Cognitive OS / Personal Knowledge Management
**Tech Stack:** Rust + Swift + Metal | 137K lines Swift, 94K lines Rust | 370 Swift files, 99 Rust files, 115 test files | 25K+ total repo files
**Developer:** Jordan (Solo) — Jacksonville, Texas
**Date:** March 27, 2026

---

## Executive Summary

This document is the definitive pre-release checklist for Epistemos, covering every critical path from code fixes to legal formation to launch strategy. It is organized into six sections: Codebase Deep Review, App Store Submission, Legal & Business Formation, Brand Building & Launch Strategy, Financial Setup, and a consolidated Final Pre-Release Checklist. Every item is specific, actionable, and prioritized. Two items are **release blockers** that must be resolved before any distribution: the empty release entitlements file and the missing privacy manifest.

The recommended v1 distribution strategy is **direct distribution (notarized, outside the Mac App Store)**, which allows Epistemos to ship with full Omega agent capabilities without sandbox restrictions. A sandboxed Mac App Store version can follow as a "lite" release once the Gateway helper pattern is fully implemented.

---

## Section 1: Codebase Deep Review — Low-Risk, High-Impact Wins

### 1A. CRITICAL: Release Entitlements Are Empty (App Store Blocker)

The release entitlements file `Epistemos/Epistemos.entitlements` contains an empty `<dict/>`. The debug entitlements have sandbox disabled, JIT enabled, unsigned executable memory allowed, and library validation disabled. **Without a populated release entitlements file, the app cannot ship on the Mac App Store or pass notarization for direct distribution.**

**Required entitlements for release:**

| Entitlement Key | Purpose | Required? |
|-----------------|---------|-----------|
| `com.apple.security.app-sandbox` = `true` | App Store sandbox requirement | Yes (App Store) |
| `com.apple.security.files.user-selected.read-write` | Vault file access via user selection | Yes |
| `com.apple.security.network.client` | LLM API calls, Semantic Scholar, HuggingFace | Yes |
| `com.apple.security.cs.allow-jit` | Metal/MLX shader compilation | Yes |
| `com.apple.security.cs.allow-unsigned-executable-memory` | MLX model weight loading | Yes |
| `com.apple.security.cs.disable-library-validation` | Rust FFI dylibs (graph-engine, omega-ax, omega-mcp, epistemos-core) | Yes |
| `com.apple.security.files.bookmarks.app-scope` | Persistent vault access across app launches | Recommended |
| `com.apple.security.automation.apple-events` | Omega agent inter-app scripting | If Omega ships |

**Additional issue:** `AppStoreHelper.swift` line 166 contains a TODO: *"Actual UDS connection + auth handshake"* — `GatewayConnection.connect()` always throws. This is scaffold code. For v1, either implement the Gateway connection or disable it cleanly with a user-facing message.

- **File:** `Epistemos/Epistemos.entitlements`
- **Effort:** Small (< 1 hour)
- **Impact:** Release blocker

---

### 1B. CRITICAL: Missing Privacy Manifest (PrivacyInfo.xcprivacy)

The `project.yml` references `Epistemos/PrivacyInfo.xcprivacy` as a resource, but the file must actually exist and declare required information. Apple has required privacy manifests since [Spring 2024](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files). Without it, **Apple will reject the submission**.

The manifest must declare:

- **Required reason APIs used** — file timestamps (for vault sync), `UserDefaults`, system boot time, disk space, etc.
- **Data collection practices** — what data the app accesses and whether any leaves the device
- **Tracking domains** — list any domains used for tracking, or declare none
- **Third-party SDK privacy manifests** — ensure any bundled SDKs (MLX, GRDB, etc.) include their own manifests or are covered by yours

**Effort:** Small (1 hour)
**Impact:** Release blocker

---

### 1C. HIGH: 166 Unsafe Rust Blocks Without SAFETY Comments

The project's own `CLAUDE.md` Golden Rules require a `// SAFETY:` comment on every `unsafe` block. Currently, 77 unsafe blocks have SAFETY comments but **166 do not**. The most critical concentrations are:

| File | Unsafe Blocks | Risk Level |
|------|---------------|------------|
| `graph-engine/src/lib.rs` | High | FFI boundary — raw pointer dereference from Swift callers |
| `graph-engine/src/knowledge_core/ring.rs` | High | Shared memory ring buffer — data races possible |

**Action:** Annotate all 166 blocks with `// SAFETY:` comments documenting the invariants that make each block sound. Prioritize the FFI boundary in `lib.rs` (most likely to cause crashes from incorrect Swift-side usage) and the ring buffer in `ring.rs` (concurrency-sensitive).

- **Effort:** Medium (2–3 hours of annotation)
- **Impact:** Code quality, maintainability, safety audit trail. Does not change runtime behavior but makes the codebase auditable and consistent with project standards.

---

### 1D. HIGH: 503 Silent `try?` Failures in Critical Paths

503 `try?` usages exist across the codebase. While `try?` is appropriate for truly optional operations, many are in **critical data paths** where silent failure means data loss or corruption with zero user notification.

**Highest-priority fixes (top 10):**

| File | Line | Code | Risk |
|------|------|------|------|
| `VaultIndexActor.swift` | 294 | `(try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []` | If fetching ALL pages fails, vault sync silently operates on zero pages — complete data blindness |
| `NoteFileStorage.swift` | 127 | `guard let data = try? Data(contentsOf: url)` | Reading note body silently fails — user sees blank note with no explanation |
| `NoteFileStorage.swift` | 74 | `try? FileManager.default.removeItem(at: url)` | Silent file deletion failure leaves orphaned files on disk |
| `VaultIndexActor.swift` | ~30 additional instances | Various SwiftData fetches | Sync engine runs on incomplete data |
| `NoteFileStorage.swift` | ~15 additional instances | Various file I/O operations | File operations silently fail |

**Quick win:** Convert the top 10 most critical `try?` sites in `VaultIndexActor.swift` and `NoteFileStorage.swift` to `do/catch` blocks with `Log.vault.error()` calls. This takes approximately 1–2 hours and prevents invisible data issues from reaching users.

```swift
// BEFORE (silent failure)
let pages = (try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []

// AFTER (logged failure)
let pages: [SDPage]
do {
    pages = try modelContext.fetch(FetchDescriptor<SDPage>())
} catch {
    Log.vault.error("Failed to fetch pages for sync: \(error.localizedDescription)")
    pages = []
}
```

- **Effort:** Small–Medium (1–2 hours for top 10 sites)
- **Impact:** High — prevents invisible data loss

---

### 1E. MEDIUM: Only 2 #if DEBUG Guards

The codebase has only 2 `#if DEBUG` checks. The logging system uses `os.Logger` which is zero-cost when not observed, so most logging is fine. However:

- **AudioTranscriber.swift lines 67 and 95** contain inline Python `print()` calls that will print to stdout in release builds
- Any development-only features or test endpoints should be gated behind `#if DEBUG`

**Action:** Audit for any remaining development-only code paths. Wrap the Python `print()` calls or remove them.

- **Effort:** Small (30-minute audit)

---

### 1F. MEDIUM: Only 50 Accessibility Labels Across All Views

With 370 Swift files, 50 accessibility labels is sparse. For [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/accessibility) compliance and to serve users who rely on VoiceOver:

- All interactive controls need `accessibilityLabel`
- Navigation elements need `accessibilityHint`
- The Metal-rendered graph view likely has **zero** VoiceOver support — consider adding an `accessibilityRepresentation` or summary
- No `.strings` localization files exist — all 800+ user-facing strings are hardcoded English

**Quick win:** Add labels to the top-level navigation elements (sidebar, toolbar, main content area) and all buttons. This can be done incrementally. Full localization is a post-v1 effort.

- **Effort:** Medium-High for full coverage; Small for key navigation elements

---

### 1G. MEDIUM: Deployment Target Mismatch

`project.yml` contains **two conflicting deployment targets**:

| Setting | Value | Meaning |
|---------|-------|---------|
| Global setting | `MACOSX_DEPLOYMENT_TARGET: "15.0"` | macOS Sonoma (released, broad install base) |
| Target override | `MACOSX_DEPLOYMENT_TARGET: "26.0"` | macOS Tahoe (unreleased, WWDC 2026 beta only) |

**Decision required:**

- **To ship now:** Set both to `15.0` or `15.4`. This maximizes the addressable audience (all Apple Silicon Macs on Sonoma or later).
- **To target cutting-edge only:** Keep `26.0`, but understand the audience is limited to developers running the beta.
- **Recommended:** Set to `15.0` for v1, unless specific macOS 26.0 APIs are required.

---

### 1H. LOW: Code Hygiene (Excellent)

The codebase is remarkably clean for a 231K-line project:

| Metric | Count | Assessment |
|--------|-------|------------|
| TODO/FIXME comments | 5 | Very clean |
| `print()` statements | 4 | All in Python helper code, acceptable |
| Hardcoded localhost/dev URLs | 0 | Excellent |
| Force-unwraps (`!`) | 0 | Excellent — matches CLAUDE.md Golden Rules |
| `try!` | 0 | Excellent |
| `[weak self]` captures | 124 | Very good capture hygiene |
| Closures with `self.` without weak | 5 | Minimal risk |
| `DispatchQueue.main` usage | 9 | Mostly appropriate |

Notification observers are properly managed with `removeObserver` in the EpistemosApp delegate. No action needed.

---

### 1I. LOW: Test Coverage

115 test files cover FFI lifecycle, data integrity, concurrency stress, block parsing, search, and adapters. Draft tests exist for `GraphSync` and `MetalRender`. Previous sanitizer runs (ASAN, TSAN, UBSAN) exist in `artifacts/reliability/`.

**Action:** Run a final pass of all three sanitizers before release:

```bash
# Address Sanitizer
xcodebuild test -scheme Epistemos -enableAddressSanitizer YES

# Thread Sanitizer
xcodebuild test -scheme Epistemos -enableThreadSanitizer YES

# Undefined Behavior Sanitizer
xcodebuild test -scheme Epistemos -enableUndefinedBehaviorSanitizer YES
```

---

### 1J. PERFORMANCE: Already Well-Optimized

The codebase has already undergone significant optimization:

- ReactiveQuery debounce reduced from 100ms to 35ms (from 150ms floor)
- Mapped file reads for bulk operations
- Batched FFI accessors (6x faster summary decode, 3x faster row access)
- Incremental watcher refresh (167x faster than full rerun)
- `os.Logger` zero-cost logging
- GraphBuilder uses memory-mapped reads

**Remaining low-hanging fruit** (from `TOP_LATENCY_WINS.md`):

1. **Swift-side BTK payload materialization** — still allocation-heavy; consider pooling or arena allocation
2. **ReactiveQuery broad notification invalidation** — narrow the invalidation scope to reduce unnecessary re-renders
3. **Repeated note body hydration in non-editor surfaces** — cache hydrated bodies or use lazy loading

These are post-v1 optimizations that improve perceived responsiveness but are not release blockers.

---

## Section 2: App Store Submission Checklist

| Step | Status | Action Required |
|------|--------|-----------------|
| [Apple Developer Program](https://developer.apple.com/programs/) enrollment | Needed | $99/year — enroll immediately |
| Bundle ID | Done | `com.epistemos.app` registered in project |
| App Icon | Done | `AppIcon.icon` exists with assets |
| Release Entitlements | **BLOCKER** | Populate `Epistemos/Epistemos.entitlements` (see Section 1A) |
| PrivacyInfo.xcprivacy | **BLOCKER** | Create privacy manifest (see Section 1B) |
| [Privacy Policy URL](https://developer.apple.com/app-store/review/guidelines/#privacy) | Needed | Must be a live URL before submission |
| App Store Screenshots | Needed | 5–10 screenshots at required resolutions |
| App Preview Video | Recommended | 15–30 second video showing key features |
| App Description | Needed | 4000 character max, keyword-optimized |
| Keywords | Needed | 100 character limit, comma-separated |
| [Privacy Nutrition Labels](https://www.apple.com/privacy/labels/) | Needed | Declare data collection in App Store Connect |
| Category Selection | Needed | "Productivity" or "Education" |
| Age Rating | Needed | Complete questionnaire in App Store Connect |
| Xcode Archive & Upload | Needed | Archive release build, upload via Xcode or `altool` |
| App Review Notes | Recommended | Explain non-obvious features, include demo content |
| Support URL | Needed | Public URL for user support |
| Copyright | Needed | "© 2026 [Your LLC Name]" |

### Key Apple Review Risks

1. **Sandbox compliance** — The Omega agent system (AX tree, CGEvent, osascript) requires the [helper app pattern](https://developer.apple.com/documentation/servicemanagement/smappservice). `AppStoreHelper.swift` is currently scaffold-only. For v1, either fully implement the helper binary or **disable Omega features in the sandboxed release build**.

2. **Hardened Runtime** — JIT, unsigned memory, and disabled library validation entitlements are necessary for MLX but will receive extra scrutiny from Apple reviewers. Document the justification in App Review notes: "Metal shader compilation via MLX framework requires JIT; Rust FFI libraries require disabled library validation."

3. **Helper app registration** — `SMAppService` login item for EpistemosGateway must reference a real binary. If the binary does not exist yet, do not reference it in the entitlements or Info.plist.

4. **Architecture** — The Xcode config targets ARM64 only, which is correct for Apple Silicon Macs. No Intel testing needed.

### Alternative: Direct Distribution (Outside App Store)

For Epistemos v1, direct distribution is likely the better path, per [community discussions on macOS app distribution](https://www.reddit.com/r/macapps/comments/1l6nw4f/just_built_my_first_macos_app_should_i_launch_on/):

| Factor | App Store | Direct Distribution |
|--------|-----------|---------------------|
| Sandbox required | Yes | No |
| Omega agent capabilities | Limited (needs helper pattern) | Full access |
| Revenue share | 15–30% to Apple | 2.5–5% to payment processor |
| Discovery | Built-in via App Store search | Requires marketing effort |
| Updates | App Store handles | You handle (Sparkle framework) |
| Notarization | Automatic | Required (free with dev account) |
| Payment processing | Apple handles | Gumroad/LemonSqueezy/Stripe |

**Recommendation:** Ship direct distribution first with full Omega capabilities. Add a Mac App Store "lite" version (PKM features only, no Omega) once the Gateway helper is implemented.

---

## Section 3: Legal & Business Formation

### 3A. Form a Texas LLC

A single-member LLC provides liability protection, professional credibility, and a clean separation between personal and business finances. Texas is one of the [most business-friendly states for LLC formation](https://www.nerdwallet.com/business/legal/learn/starting-an-llc-in-texas).

**Step-by-step:**

| Step | Action | Cost | Notes |
|------|--------|------|-------|
| 1 | Choose LLC name (e.g., "Epistemos Labs LLC") | Free | Check availability at [Texas SOS](https://www.sos.state.tx.us/corp/sosda/index.shtml) |
| 2 | File Certificate of Formation (Form 205) | $308.10 online | File at [SOSDirect](https://www.sos.state.tx.us/corp/sosda/index.shtml) |
| 3 | Designate Registered Agent | $0–150/year | You can serve as your own agent (home address becomes public) or use a service |
| 4 | Get an EIN | Free | Apply at [IRS.gov](https://www.irs.gov/businesses/small-businesses-self-employed/apply-for-an-employer-identification-number-ein-online) — 10 minutes online |
| 5 | Open business bank account | $0–25 | Use EIN + Certificate of Formation; keep ALL business money separate |
| 6 | Draft Operating Agreement | Free (DIY) | Not legally required in Texas but strongly recommended. Defines ownership and management |
| 7 | Register with [Texas Comptroller](https://comptroller.texas.gov/) | Free | Required for franchise tax reporting; file annually by May 15; no tax due if revenue < $1,230,000/year |
| 8 | File Assumed Name Certificate (if DBA) | $25 | Only if doing business under a name other than the LLC name |

**Total estimated cost: $400–600 to start.** See also the [post-formation guide from Collective](https://www.collective.com/guides/single-member-llc-post-formation-texas) for ongoing compliance requirements.

---

### 3B. Intellectual Property Protection

1. **Trademark "Epistemos"**: File with the [USPTO](https://www.uspto.gov/trademarks) ($250–350 per class). Register in:
   - **Class 9** — Downloadable computer software
   - **Class 42** — Software as a service (if cloud features are planned)

2. **Copyright registration**: Copyright exists automatically upon creation, but [registering with the US Copyright Office](https://www.copyright.gov/) ($65) enables enforcement and statutory damages.

3. **AI-generated code**: Document creative direction and human authorship decisions. The copyright status of AI-generated code remains legally unsettled. Maintain logs of architectural decisions and human-authored specifications.

4. **Open source audit**: Dependencies in `Cargo.toml` (GRDB, MLX, Loro, Cozo, UniFFI, etc.) use permissive licenses (MIT/Apache). Verify each dependency's license and maintain a `NOTICES` file in the repo listing all third-party licenses.

---

### 3C. Privacy Policy (Required Before Any Distribution)

A privacy policy is required by [Apple](https://developer.apple.com/app-store/review/guidelines/#privacy), GDPR, and CCPA before any form of distribution. Epistemos's local-first architecture is a major selling point — the privacy policy should lead with it.

**Must cover:**

- **What data Epistemos collects:** Notes, vault files, user preferences, on-device model interactions
- **Where data is stored:** Locally on the user's Mac — this is the headline
- **External services used:** Semantic Scholar API (search queries sent), HuggingFace (model downloads), any LLM API endpoints
- **Data sharing:** No user data is sold or shared with third parties
- **Data deletion:** Users delete the app + vault folder; no server-side data to purge
- **GDPR compliance:** Right to access, right to erasure, data portability (all trivially satisfied by local-first architecture)
- **CCPA compliance:** "Do Not Sell My Personal Information" — not applicable (no data is sold)

**Hosting:** Publish at a public URL such as `epistemos.app/privacy`. Use [Termly](https://termly.io/resources/templates/app-privacy-policy/) or [FreePrivacyPolicy.com](https://www.freeprivacypolicy.com/) as a starting template, then customize for Epistemos's specific data practices.

---

### 3D. Terms of Service / EULA

Per [legal guidance for app developers](https://www.forwardlawfirm.com/legal-requirements-for-your-app-what-you-need-to-know/), a Terms of Service or EULA should cover:

- **Usage rights:** What users may and may not do with Epistemos
- **Intellectual property:** You own the app; users own their notes and vault data
- **Limitation of liability:** The app is provided "as is"; no guarantee against data loss (recommend user backups)
- **Termination:** Conditions under which a license may be revoked
- **Dispute resolution:** Texas law governs; disputes resolved in Cherokee County, Texas
- **Apple standard EULA:** If distributing via the Mac App Store, Apple provides a [standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), but a custom one addressing data ownership is recommended

See also [GalkinLaw's summary of 10 key legal issues for apps](https://galkinlaw.com/legal-issues-for-apps/).

---

### 3E. Business Insurance (Optional, Recommended Post-Revenue)

| Policy Type | Annual Cost | Covers |
|-------------|-------------|--------|
| General Liability | $500–1,000 | Third-party bodily injury, property damage claims |
| Errors & Omissions (E&O) | $500–1,500 | Claims that your software caused data loss or business harm |

Not essential for day 1. Consider once revenue exceeds $5K/month or if enterprise customers require it.

---

## Section 4: Brand Building & Launch Strategy

### 4A. Brand Assets Inventory

| Asset | Status | Priority |
|-------|--------|----------|
| App Icon (macOS) | Done | — |
| Website (epistemos-site repo, Next.js + Tailwind) | In progress | **HIGH** — deploy to Vercel |
| Logo / Wordmark | Needed | **HIGH** |
| Social Media (@epistemos on X, LinkedIn, GitHub) | Needed | **HIGH** — claim handles immediately |
| Brand Color Palette | Exists in app (Opulent theme) | Document formally in a brand guide |
| App Store Screenshots | Needed | **CRITICAL** for launch |
| Demo Video | Needed | **HIGH** |
| Press Kit | Needed | **MEDIUM** |

---

### 4B. Pre-Launch (2–4 Weeks Before Release)

Per [standard pre-launch marketing practices](https://www.mobileaction.co/blog/pre-launch-marketing/):

1. **Deploy the landing page.** The `epistemos-site` repo (Next.js + Tailwind) is already built. Deploy to Vercel, connect the domain (`epistemos.app` or similar), and ensure the privacy policy is hosted there.

2. **Set up an email waitlist.** Add a signup form using ConvertKit, Buttondown, or Loops. Even 100 emails before launch provides a critical first-day audience.

3. **Claim social media handles.** Register `@epistemos` on X/Twitter, LinkedIn, GitHub, Mastodon, and Bluesky. Consistency across platforms builds brand recognition.

4. **Build in public.** Post development updates on X with hashtags: `#buildinpublic`, `#indiedev`, `#macOS`, `#rust`, `#swift`. The narrative is compelling: solo developer, 231K lines of code, native macOS cognitive OS built with AI assistance.

5. **Prepare Product Hunt.** Create a [maker profile](https://www.producthunt.com/), draft the Product Hunt page (tagline, description, first comment), and line up 5–10 supporters to upvote and comment on launch day.

6. **Recruit beta testers.** Target 20–50 macOS users through r/macapps, the macOS dev community on X, and indie dev Discord servers. Distribute via TestFlight (if App Store) or a signed/notarized DMG (if direct).

---

### 4C. Launch Day Strategy

Drawing from [successful app launch playbooks](https://screencharm.com/blog/product-launch-checklist):

| Channel | Action | Timing |
|---------|--------|--------|
| [Product Hunt](https://www.producthunt.com/) | Launch post — go live at 12:01 AM PT | Day 1, pre-dawn |
| [Hacker News](https://news.ycombinator.com/) | "Show HN: Epistemos — A native macOS cognitive OS built in Rust + Swift + Metal" | Day 1, morning |
| Reddit | Post in r/macapps, r/productivity, r/ObsidianMD, r/PKM, r/apple | Day 1, staggered |
| X / Twitter | Thread: "I'm a solo dev from East Texas. I built a 231K-line native macOS app in 2 months. Here's how." | Day 1 |
| Dev blogs | Architecture deep-dive on Dev.to, Hashnode, or personal Substack | Day 1 or Day 2 |
| Mac press | Pitch to 9to5Mac, MacStories, The Verge (Apple desk), Daring Fireball | 1 week before launch |

**The story angle:** A solo developer built a 231K-line native macOS cognitive OS using Rust, Swift, and Metal, with AI-assisted development. This is an extremely shareable narrative on tech Twitter and Hacker News.

---

### 4D. Post-Launch (First 30 Days)

1. **Monitor and respond to reviews** — Reply to every App Store review (or Gumroad comment) within 24 hours
2. **Ship bug fixes fast** — Release v1.0.1 and v1.0.2 within the first two weeks for any issues found
3. **Maintain content cadence** — 2–3 posts per week: feature spotlights, tips, behind-the-scenes development stories
4. **Collect testimonials** — Ask early users for quotes and ratings; feature them on the landing page
5. **Refine App Store Optimization (ASO)** — Update keywords based on search impression data from App Store Connect
6. **Consider [Indie App Santa](https://indieappsanta.com/2025/11/21/10349/)** — A promotional campaign for indie macOS/iOS apps ($300–800 per campaign)

---

### 4E. Distribution Strategy Decision

Given Epistemos's architecture — the Omega agent system requires unsandboxed access to the accessibility tree (AX), `CGEvent`, and `osascript` — the recommended v1 approach is:

**Phase 1: Direct Distribution (Launch)**
- Notarize the app (free with [Apple Developer account](https://developer.apple.com/programs/))
- Sell via [Gumroad](https://gumroad.com/) (2.5% + $0.30/sale) or [LemonSqueezy](https://www.lemonsqueezy.com/) (5% + $0.50/sale)
- Full Omega agent capabilities — no sandbox restrictions
- Handle licensing via Gumroad/LemonSqueezy license keys
- Handle updates via [Sparkle](https://sparkle-project.org/) (the standard macOS auto-update framework)

**Phase 2: Mac App Store (Post-Launch)**
- Build a sandboxed "lite" version with PKM features only (no Omega agent)
- Or: fully implement the EpistemosGateway helper binary using `SMAppService` for privileged operations
- Broader discovery through App Store search
- Seamless Apple payment integration

This approach lets Epistemos ship faster with its full feature set while the sandboxed version is developed in parallel, per recommendations from [experienced macOS developers](https://www.avanderlee.com/swiftui/macos-development-powerful-utilities/).

---

## Section 5: Financial Setup & Costs

### Startup Budget

| Item | Cost | Timing |
|------|------|--------|
| Texas LLC Formation (Form 205) | $308 | Now |
| EIN (IRS) | Free | After LLC |
| [Apple Developer Program](https://developer.apple.com/programs/) | $99/year | Now |
| Domain (epistemos.app) | $12–40/year | Now |
| Registered Agent service (optional) | $50–150/year | If you prefer not to use your home address |
| [USPTO Trademark](https://www.uspto.gov/trademarks) (Class 9) | $250–350 | Within 3 months |
| Privacy Policy Generator | Free–$10/month | Before launch |
| Business Bank Account | $0–25 | After EIN |
| **Total Day-1 Budget** | **~$500–800** | |

### Revenue Model Options

| Model | Price Point | Pros | Cons |
|-------|-------------|------|------|
| One-time purchase | $29–49 | Simple, no subscription fatigue | Revenue plateaus; must constantly acquire new customers |
| Annual subscription | $49–99/year | Recurring revenue, funds ongoing development | Users dislike subscriptions for local-first apps |
| Monthly subscription | $5–10/month | Highest LTV potential | Highest churn risk |
| Freemium | Free PKM + Paid Omega/AI ($29–49) | Maximizes adoption, upsells power users | Engineering cost of maintaining two tiers |

**Recommendation for v1:** Start with a one-time purchase at $39–49 via Gumroad/LemonSqueezy. This aligns with indie macOS app norms and avoids the subscription backlash common in the PKM space. Consider adding a subscription tier later for cloud sync or advanced AI features.

---

## Section 6: Final Pre-Release Checklist (Priority Order)

### Must-Do Before Release (Blockers)

These items prevent shipping. Complete all before any form of distribution.

- [ ] **1. Populate release entitlements file** — `Epistemos/Epistemos.entitlements` must contain all required entitlement keys (see Section 1A). Effort: < 1 hour.
- [ ] **2. Create PrivacyInfo.xcprivacy manifest** — Declare required reason APIs, data collection practices, and tracking domains (see Section 1B). Effort: 1 hour.
- [ ] **3. Form LLC** — File Certificate of Formation at [SOSDirect](https://www.sos.state.tx.us/corp/sosda/index.shtml), get EIN, open business bank account. Effort: 1–2 days for processing.
- [ ] **4. Enroll in Apple Developer Program** — [$99/year at developer.apple.com](https://developer.apple.com/programs/). Required for notarization even if not using the App Store. Effort: 1 day (enrollment review).
- [ ] **5. Write and host privacy policy** — Draft using [Termly](https://termly.io/) or [FreePrivacyPolicy.com](https://www.freeprivacypolicy.com/), customize for Epistemos, publish at your domain. Effort: 2–3 hours.
- [ ] **6. Resolve deployment target** — Decide between `MACOSX_DEPLOYMENT_TARGET: "15.0"` (ship now to all Apple Silicon) or `"26.0"` (macOS Tahoe beta only). Update both settings in `project.yml`. Effort: 5 minutes.
- [ ] **7. Decide distribution strategy** — Direct distribution (recommended for v1) or Mac App Store. This affects entitlements, sandbox requirements, and payment setup. Effort: Decision only.
- [ ] **8. Run full sanitizer suite** — Execute ASAN, TSAN, and UBSAN test runs. Fix any issues found. Effort: 2–4 hours depending on findings.
- [ ] **9. Prepare distribution listing** — Set up Gumroad/LemonSqueezy product page (direct) or App Store Connect listing (App Store). Effort: 2–3 hours.

### Should-Do Before Release (High Impact)

These significantly improve quality and professionalism. Complete as many as time allows.

- [ ] **10. Add `do/catch` error logging to top 10 critical `try?` sites** — Focus on `VaultIndexActor.swift` and `NoteFileStorage.swift` (see Section 1D). Effort: 1–2 hours.
- [ ] **11. Add SAFETY comments to top 50 most critical unsafe Rust blocks** — Prioritize FFI boundary in `graph-engine/src/lib.rs` and ring buffer in `ring.rs` (see Section 1C). Effort: 1–2 hours for the top 50.
- [ ] **12. Disable or gate Omega agent features** — If the EpistemosGateway helper binary is not implemented, disable Omega features that depend on it. Users should not encounter scaffold code that always throws. Effort: 1–2 hours.
- [ ] **13. Create Terms of Service / EULA** — Define usage rights, liability limits, and IP ownership (see Section 3D). Effort: 2–3 hours.
- [ ] **14. Prepare 5–10 App Store screenshots** — Capture at required resolutions showing key workflows: vault view, graph view, note editing, Omega agent (if shipping). Effort: 2 hours.
- [ ] **15. Write App Store / product page description** — 4000 characters max for App Store; optimize for keywords. Effort: 1–2 hours.
- [ ] **16. Deploy landing page** — Push `epistemos-site` to Vercel, connect domain, verify privacy policy link works. Effort: 1 hour.
- [ ] **17. Set up business bank account** — Open with EIN + Certificate of Formation. Keep all revenue separate from personal funds. Effort: 1 hour at a bank.

### Nice-To-Have Before Release (Polish)

These improve the overall launch quality but are not essential for day 1.

- [ ] **18. Add accessibility labels to main navigation elements** — Sidebar, toolbar, main content views. Effort: 2–3 hours for key elements.
- [ ] **19. Create open source NOTICES file** — List all third-party dependencies with their licenses (MIT, Apache 2.0, etc.). Effort: 1 hour.
- [ ] **20. Record app demo video** — 15–30 seconds showing the core workflow. Use for App Store, Product Hunt, and social media. Effort: 2–3 hours.
- [ ] **21. Set up social media accounts** — Claim @epistemos on X, LinkedIn, GitHub, Mastodon, Bluesky. Effort: 30 minutes.
- [ ] **22. Prepare Product Hunt page** — Create maker profile, draft tagline, description, and first comment. Effort: 1 hour.
- [ ] **23. Draft Hacker News "Show HN" post** — Title: "Show HN: Epistemos — A native macOS cognitive OS built in Rust + Swift + Metal." Keep the post body under 300 words. Effort: 30 minutes.
- [ ] **24. Set up privacy-respecting analytics** — Consider [TelemetryDeck](https://telemetrydeck.com/) (free tier available, privacy-first, built for Swift). Effort: 1–2 hours.
- [ ] **25. Add onboarding / "What's New" screen** — `SetupAssistantView` already exists; ensure it provides a good first-run experience. Effort: 1–2 hours.
- [ ] **26. Create press kit** — Bundle logo, screenshots, app description, founder bio, and brand assets into a downloadable ZIP. Effort: 1–2 hours.

### Post-Release (First Month)

- [ ] **27. File trademark for "Epistemos"** — [USPTO](https://www.uspto.gov/trademarks), Class 9 ($250–350). Effort: 2–3 hours to prepare and file.
- [ ] **28. Get E&O insurance** — Errors & Omissions coverage for software liability. Effort: 1–2 hours to quote and purchase.
- [ ] **29. Set up customer support channel** — Dedicated email (support@epistemos.app) and/or a Discord server for community support. Effort: 1 hour.
- [ ] **30. Begin Mac App Store version** — Implement EpistemosGateway helper binary, sandbox Omega agent, and prepare a sandboxed build for broader distribution. Effort: Multi-week project.

---

## Appendix A: Quick Reference — File Paths & Line Numbers

| Item | File Path | Line(s) | Issue |
|------|-----------|---------|-------|
| Empty entitlements | `Epistemos/Epistemos.entitlements` | All | Empty `<dict/>` |
| Privacy manifest reference | `project.yml` | (resource reference) | File must exist |
| Gateway scaffold TODO | `AppStoreHelper.swift` | 166 | `GatewayConnection.connect()` always throws |
| Deployment target conflict | `project.yml` | Global + target override | `15.0` vs `26.0` |
| Silent vault fetch | `VaultIndexActor.swift` | 294 | `try?` on full page fetch |
| Silent note read | `NoteFileStorage.swift` | 127 | `try?` on file read |
| Silent file delete | `NoteFileStorage.swift` | 74 | `try?` on file removal |
| Python print in release | `AudioTranscriber.swift` | 67, 95 | Not gated by `#if DEBUG` |
| Unsafe FFI boundary | `graph-engine/src/lib.rs` | Multiple | Missing SAFETY comments |
| Unsafe ring buffer | `graph-engine/src/knowledge_core/ring.rs` | Multiple | Missing SAFETY comments |
| Sanitizer artifacts | `artifacts/reliability/` | — | Previous ASAN/TSAN/UBSAN runs |
| Latency opportunities | `TOP_LATENCY_WINS.md` | — | BTK payload, ReactiveQuery, note hydration |

---

## Appendix B: Estimated Timeline

Assuming full-time effort from a single developer:

| Phase | Duration | Items Covered |
|-------|----------|---------------|
| **Week 1: Legal & Blockers** | 5 days | LLC formation, Apple Developer enrollment, entitlements, privacy manifest, deployment target, privacy policy |
| **Week 2: Code Quality & Distribution Setup** | 5 days | Top `try?` fixes, SAFETY comments, sanitizer runs, Omega feature gating, Gumroad/LemonSqueezy setup |
| **Week 3: Brand & Marketing Prep** | 5 days | Landing page deployment, screenshots, demo video, social media, Product Hunt prep, press outreach |
| **Week 4: Launch** | 5 days | Final testing, launch day execution (PH, HN, Reddit, X), monitor and respond, ship v1.0.1 if needed |

**Total: ~4 weeks from starting this checklist to public launch.**

---

*This document was prepared on March 27, 2026. All costs, filing fees, and guidelines reflect current information as of that date. Verify current fees at the linked official sources before filing.*
