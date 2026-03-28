# Epistemos Distribution Decision & Compliance Report

**Date:** 2026-03-28
**Auditor:** Claude Opus 4.6

---

## 1. Recommended Shipping Model

### **Direct-distributed full app first, Mac App Store later (MAS-lite companion when ready)**

---

## 2. Why

Epistemos requires three hardened runtime exceptions that are **incompatible with the Mac App Store sandbox**:

1. **JIT compilation** (`com.apple.security.cs.allow-jit`) — MLX generates Metal compute kernels at runtime for model inference. MAS sandbox does not allow JIT.
2. **Unsigned executable memory** (`com.apple.security.cs.allow-unsigned-executable-memory`) — MLX loads model weights into executable memory regions. MAS sandbox does not allow this.
3. **Disabled library validation** (`com.apple.security.cs.disable-library-validation`) — App loads Rust FFI dynamic libraries (graph-engine, omega-ax, omega-mcp, epistemos-core) that are not signed by the same team certificate. MAS sandbox requires library validation.

Additionally, Omega desktop automation requires:
- **Apple Events** to Safari and System Events — possible but heavily scrutinized under MAS review
- **Accessibility API** for AX tree walking and UI automation — requires temporary exception entitlement, rarely granted for MAS
- **Runtime model download** from HuggingFace — violates App Review Guideline 2.5.2 ("may not download code which introduces or changes features")

Direct distribution via Developer ID + notarization avoids all of these restrictions while still providing Gatekeeper trust and malware scanning.

---

## 3. MAS Blockers for the Full Omega Build

| Blocker | Guideline | Severity |
|---------|-----------|----------|
| MLX JIT compilation | 2.5.1, 2.5.2 | **Hard block** — no workaround in sandbox |
| Unsigned executable memory | 2.5.1 | **Hard block** — required for MLX weight loading |
| Disabled library validation | 2.4.5(i) | **Hard block** — required for Rust FFI dylibs |
| Runtime model download | 2.5.2, 2.4.5(iv) | **Hard block** — "additional resources" violation |
| Apple Events automation | 2.5.9 | **High risk** — requires entitlement review |
| Accessibility API | 2.4.5(i) | **High risk** — temporary exception rarely granted |

A future **MAS-lite build** could ship with:
- CoreML models bundled in the app (instead of MLX runtime download)
- No Omega desktop automation
- Basic note-taking + graph + Apple Intelligence only
- All Rust FFI code compiled as static libraries (avoiding library validation)

This is a significant engineering effort and should be deferred to post-v1.

---

## 4. Direct-Distribution Checklist

| Item | Status | Notes |
|------|--------|-------|
| Developer ID certificate | `Needs setup outside repo` | Requires Apple Developer Program membership ($99/year) |
| Hardened runtime | `Ready` | `ENABLE_HARDENED_RUNTIME = YES` in Xcode project |
| Entitlements (release) | `Ready` | JIT + unsigned memory + library validation exceptions populated |
| Entitlements (debug) | `Ready` | Same exceptions + `get-task-allow` for debugging |
| Code signing | `Ready` | `CODE_SIGN_STYLE: Automatic`, team `3BNL2669SL` configured |
| Notarization | `Needs setup outside repo` | Run `xcrun notarytool submit` after archive build |
| DMG / installer packaging | `Needs setup outside repo` | Use `create-dmg` or similar tool |
| Privacy policy URL | `Needs setup outside repo` | Required for Gatekeeper transparency |
| Support URL | `Needs setup outside repo` | Recommended for user trust |
| Website / download page | `Needs setup outside repo` | Host DMG with HTTPS |

---

## 5. MAS-Lite Checklist (Future, Not Current)

| Item | Status | Notes |
|------|--------|-------|
| Sandbox entitlements | `Blocked` | Requires full re-architecture of inference (CoreML) and removal of Omega |
| CoreML model bundling | `Blocked` | No CoreML model conversion pipeline exists yet |
| Static Rust libraries | `Blocked` | FFI currently compiled as dynamic libraries |
| Apple Events removal | `Not started` | Strip Omega automation for MAS build |
| Accessibility removal | `Not started` | Strip AX tree walking for MAS build |
| App Review demo mode | `Not started` | Needed if reviewer can't download models |

---

## 6. Privacy Manifest Status

**File:** `Epistemos/Resources/PrivacyInfo.xcprivacy`
**Status:** `Ready`

| Declaration | Value | Status |
|-------------|-------|--------|
| NSPrivacyTracking | false | ✅ |
| NSPrivacyTrackingDomains | empty | ✅ |
| NSPrivacyCollectedDataTypes | empty | ✅ (all processing on-device) |
| NSPrivacyAccessedAPICategoryFileTimestamp | C617.1 | ✅ |
| NSPrivacyAccessedAPICategoryDiskSpace | E174.1 | ✅ |
| NSPrivacyAccessedAPICategoryUserDefaults | CA92.1 | ✅ (added this audit) |

**Not required (verified):**
- SystemBootTime — app does not check system boot time
- ActiveKeyboards — app does not enumerate keyboards
- ScreenCapture — ScreenCaptureKit is used for permission detection only, not data collection

---

## 7. Entitlements Status

### Release Entitlements (`Epistemos/Epistemos.entitlements`)
**Status:** `Ready`

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.security.cs.allow-jit` | true | MLX Metal shader JIT compilation |
| `com.apple.security.cs.allow-unsigned-executable-memory` | true | MLX model weight loading |
| `com.apple.security.cs.disable-library-validation` | true | Rust FFI dylib loading |

### Debug Entitlements (`Epistemos/Epistemos-Debug.entitlements`)
**Status:** `Ready`

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.security.app-sandbox` | false | Full access for development |
| `com.apple.security.cs.allow-jit` | true | MLX |
| `com.apple.security.cs.allow-unsigned-executable-memory` | true | MLX |
| `com.apple.security.cs.disable-library-validation` | true | Rust FFI |

---

## 8. Export Compliance Status

**Status:** `Ready`

- `ITSAppUsesNonExemptEncryption: false` added to Info.plist
- App does not implement custom encryption algorithms
- Uses Apple-provided CryptoKit/Security frameworks only (exempt under CCATS)
- No data transmission to foreign servers
- All AI inference runs locally
- HuggingFace model downloads use HTTPS (Apple-provided TLS, exempt)

**No EAR/BIS filing required** for standard HTTPS usage via Apple frameworks. `Needs legal review` if any future version adds custom encryption beyond Apple APIs.

---

## 9. Tax / Banking / Enrollment Checklist

| Item | Status | Notes |
|------|--------|-------|
| Apple Developer Program ($99/year) | `Needs setup outside repo` | Individual enrollment sufficient for direct distribution |
| D-U-N-S number | `Not required` | Only needed for organization enrollment |
| Organization enrollment | `Not required` | Individual enrollment works for v1 |
| Bank account for App Store payments | `Not required for direct distribution` | Only needed if/when MAS-lite ships |
| Tax forms (W-9 for US) | `Not required for direct distribution` | Only needed for App Store payments |
| Small Business Program (15% commission) | `Not applicable` | Only relevant for MAS sales |
| Sales tax registration | `Needs CPA review` | May be required if selling directly (not via App Store) |
| Business entity formation | `Needs CPA review` | Sole proprietor vs LLC for liability protection |

---

## 10. Items Needing Legal or CPA Review

| Item | Type | Why |
|------|------|-----|
| Privacy policy text | `Needs legal review` | Must accurately describe on-device processing, HuggingFace model downloads, accessibility/automation data access |
| Terms of service | `Needs legal review` | Standard EULA for direct-distributed macOS app |
| Sales tax obligations | `Needs CPA review` | Depends on state, distribution model (free vs paid), and entity structure |
| Business entity formation | `Needs CPA review` | LLC vs sole proprietor for liability |
| Open-source license compliance | `Needs legal review` | MLX (MIT), GRDB (MIT), swift-crypto (Apache 2.0) — likely fine but verify all transitive deps |

---

## 11. Official Apple / Government Sources Used

| Source | URL | Used For |
|--------|-----|----------|
| App Store Review Guidelines | `developer.apple.com/app-store/review/guidelines/` | MAS compatibility assessment (Guidelines 2.4.5, 2.5.1, 2.5.2, 2.5.9, 2.5.14, 4.2.3, 5.1.1, 5.1.2) |
| Developer ID and Notarization | `developer.apple.com/developer-id/` | Direct distribution requirements |
| Privacy Manifest Requirements | `developer.apple.com/support/third-party-SDK-requirements` | Privacy manifest API categories |
| App Privacy Details | `developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy` | Privacy disclosure requirements |
| Export Compliance Overview | `developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance` | Encryption compliance |
| Apple Developer Program | `developer.apple.com/programs/` | Enrollment requirements |
| BIS/EAR | CCATS exemption for standard HTTPS/TLS | Export compliance for Apple-framework encryption |
