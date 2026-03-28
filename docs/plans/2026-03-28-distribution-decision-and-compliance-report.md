# Epistemos Distribution Decision & Compliance Report

**Date:** 2026-03-28
**Auditor:** Claude Opus 4.6 (second pass, independent re-verification)

---

## 1. Recommended Shipping Model

### **Direct-distributed full app first, Mac App Store later (if ever)**

Ship as a Developer ID-signed, notarized `.dmg` for direct download. Do not attempt Mac App Store submission for v1.

---

## 2. Why

The app requires three hardened runtime exceptions that are incompatible with the Mac App Store sandbox:

1. **`com.apple.security.cs.allow-jit`** — Required for MLX/Metal shader compilation during local model inference. MAS rejects JIT.
2. **`com.apple.security.cs.allow-unsigned-executable-memory`** — Required for MLX model weight loading and inference buffers. MAS rejects unsigned executable memory.
3. **`com.apple.security.cs.disable-library-validation`** — Required to load Rust FFI dylibs (graph-engine, omega-ax, omega-mcp). MAS requires all loaded libraries to be signed by the same team or Apple.

Additionally, Omega desktop automation uses:
- **Accessibility API** (AX tree walking, click simulation) — incompatible with App Sandbox
- **Apple Events** (Safari control, System Events) — incompatible with App Sandbox
- **Terminal command execution** — incompatible with App Sandbox

These are fundamental architectural requirements, not optional features.

---

## 3. MAS Blockers for Full Omega Build

| Blocker | Category | Workaround? |
|---------|----------|-------------|
| JIT compilation (MLX inference) | Hardened Runtime | No — MLX requires JIT |
| Unsigned executable memory (MLX buffers) | Hardened Runtime | No |
| Disabled library validation (Rust FFI) | Hardened Runtime | Complex — sign Rust dylibs with same team ID |
| Accessibility API (Omega) | Sandbox | No |
| Apple Events (Safari/System Events) | Sandbox | No |
| Terminal command execution | Sandbox | No |
| AppStoreHelper gateway | Infrastructure | Not implemented (IPC stubs only) |

**Verdict:** A MAS build would require removing MLX local inference AND all Omega automation — gutting the two core features. Not viable.

---

## 4. Direct-Distribution Checklist

| Item | Status | Action Required |
|------|--------|----------------|
| Developer ID certificate | Needs setup | Enroll in Apple Developer Program ($99/yr) |
| Hardened Runtime | ✅ Ready | Enabled in build settings |
| Entitlements file | ✅ Ready | JIT, unsigned memory, library validation populated |
| Code signing | Needs setup | `codesign --deep --force --options runtime --sign "Developer ID Application: ..."` |
| Notarization | Needs setup | `xcrun notarytool submit Epistemos.dmg --apple-id ... --team-id ... --password ...` |
| Stapling | Needs setup | `xcrun stapler staple Epistemos.dmg` |
| DMG packaging | Needs setup | Create DMG with app + Applications symlink |
| Privacy policy URL | Needs setup | Host at website |
| Support URL | Needs setup | Host at website |
| Download hosting | Needs setup | GitHub Releases, personal website, or CDN |

---

## 5. MAS-Lite Checklist

**Not recommended for v1.** Would require:
- Remove all Omega automation agents
- Remove MLX local inference (Apple Intelligence only)
- Remove or re-sign Rust FFI dylibs
- Enable App Sandbox
- Implement AppStoreHelper gateway (currently stubs)
- Separate build target

Produces a severely limited app. Not recommended.

---

## 6. Privacy Manifest Status

### ✅ Ready

File: `Epistemos/Resources/PrivacyInfo.xcprivacy`

| Field | Value | Status |
|-------|-------|--------|
| NSPrivacyTracking | false | ✅ No tracking |
| NSPrivacyTrackingDomains | [] | ✅ Empty |
| NSPrivacyCollectedDataTypes | [] | ✅ No collection |
| NSPrivacyAccessedAPITypes | 3 entries | ✅ Complete |

API declarations:
1. File Timestamp (C617.1) — vault sync
2. Disk Space (E174.1) — model download
3. UserDefaults (CA92.1) — settings

---

## 7. Entitlements Status

### ✅ Ready for Direct Distribution

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.security.cs.allow-jit` | true | MLX/Metal shaders |
| `com.apple.security.cs.allow-unsigned-executable-memory` | true | MLX model loading |
| `com.apple.security.cs.disable-library-validation` | true | Rust FFI dylibs |

No sandbox entitlement present — correct for direct distribution.

---

## 8. Export Compliance Status

### ✅ Ready

`ITSAppUsesNonExemptEncryption: false` in Info.plist.

**Justification:** No custom encryption. Uses only system-provided HTTPS (TLS) for model downloads and API calls — exempt under BIS EAR §740.17(b)(1). No encryption of user data at rest beyond APFS.

---

## 9. Tax / Banking / Enrollment Checklist

| Item | Status | Notes |
|------|--------|-------|
| Apple Developer Program | Needs setup | $99/year |
| Individual vs Organization | Decision needed | Individual simpler; Org requires D-U-N-S |
| D-U-N-S number | If org, needs setup | Free, takes 1-2 weeks |
| Tax registration | Needs CPA review | Only if revenue > $400/yr |
| Business entity | Needs legal review | Only if charging money |
| App Store Small Business Program | N/A | Direct distribution only |

**For free direct distribution:** Only Apple Developer Program enrollment required.

---

## 10. Items Needing Legal or CPA Review

| Item | Why | Urgency |
|------|-----|---------|
| Privacy policy text | CCPA/GDPR compliance | Before distribution |
| Terms of service | AI content liability, data loss disclaimer | Before distribution |
| Business entity formation | Liability protection | Before charging |
| Tax obligations | Self-employment tax | Before charging |
| Open-source license compliance | GRDB (MIT), MLX (MIT), HuggingFace (Apache 2.0) — attribution may be required | Before distribution |

---

## 11. Official Apple / Government Sources Used

| Topic | Source |
|-------|--------|
| App Store review guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| App privacy details | https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy |
| Export compliance | https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance |
| Developer ID & notarization | https://developer.apple.com/developer-id/ |
| Third-party SDK requirements | https://developer.apple.com/support/third-party-SDK-requirements |
| D-U-N-S enrollment | https://developer.apple.com/help/account/membership/D-U-N-S/ |
| Small Business Program | https://developer.apple.com/app-store/small-business-program/ |

**Disclaimer:** This report is operational guidance, not legal or tax advice. Items marked "Needs legal/CPA review" require qualified professionals.
