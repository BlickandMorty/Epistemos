# macOS Multi-Vault File Access System for Epistemos
## Production-Grade Architecture, Security Analysis & Implementation Scaffolds

**Version:** 1.0  
**Date:** 2026  
**Classification:** Architecture Research / Implementation Scaffold  
**Scope:** macOS 14+ (Sonoma) / macOS 15+ (Sequoia), App Sandbox, Mac App Store & Pro Distribution

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [macOS LocalAuthentication Framework](#2-macos-localauthentication-framework)
3. [Security-Scoped Bookmarks & CVE-2025-31191](#3-security-scoped-bookmarks--cve-2025-31191)
4. [App Sandbox Entitlements](#4-app-sandbox-entitlements)
5. [NSOpenPanel & Persistent Resource Access](#5-nsopenpanel--persistent-resource-access)
6. [Multi-Vault Patterns from Industry](#6-multi-vault-patterns-from-industry)
7. [SwiftData / Core Data for Metadata Indexing](#7-swiftdata--core-data-for-metadata-indexing)
8. [Formal Vault Lifecycle](#8-formal-vault-lifecycle)
9. [Touch ID Integration with Vault Unlocking](#9-touch-id-integration-with-vault-unlocking)
10. [Bookmark Storage & Epistemos Core ↔ Hermes Sidecar](#10-bookmark-storage--epistemos-core--hermes-sidecar)
11. [Vault Data Model](#11-vault-data-model)
12. [Resonance Gate Classification](#12-resonance-gate-classification)
13. [Entitlements: MAS vs Pro Builds](#13-entitlements-mas-vs-pro-builds)
14. [Rust ↔ Swift FFI (UniFFI)](#14-rust--swift-ffi-uniffi)
15. [Swift Code Scaffold](#15-swift-code-scaffold)
16. [Rust Code Scaffold](#16-rust-code-scaffold)
17. [macOS Entitlement Configurations](#17-macos-entitlement-configurations)
18. [Multi-Vault Architecture Data Model Diagram](#18-multi-vault-architecture-data-model-diagram)
19. [Security Analysis & Threat Mitigation](#19-security-analysis--threat-mitigation)
20. [References](#20-references)

---

## 1. Executive Summary

Epistemos requires a **multi-vault file access system** that:

- Grants persistent, sandbox-compliant access to multiple user-selected directories
- Authenticates vault access via **Touch ID / Face ID** (LocalAuthentication)
- Stores access tokens as **security-scoped bookmarks** with full awareness of CVE-2025-31191
- Passes bookmark data between the Swift UI layer (Epistemos Core) and the Rust processing layer (Hermes sidecar) via **UniFFI**
- Maintains **zero-copy semantics** for file content ingestion (mmap / file descriptor passing)
- Indexes file metadata via **SwiftData** for fast vault search without loading file contents
- Ships to both **Mac App Store (MAS)** and **Pro (direct distribution)** channels

This document provides the formal architecture, code scaffolds, entitlement configurations, and security analysis required for production implementation.

---

## 2. macOS LocalAuthentication Framework

### 2.1 API Surface

The `LocalAuthentication` framework provides `LAContext`, the primary interface for biometric authentication on macOS [^3030^].

**Key API:**

```swift
// Policy evaluation
func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void)

// Policy types
public enum LAPolicy : Int {
    case deviceOwnerAuthenticationWithBiometrics = 1
    case deviceOwnerAuthentication = 2
    case deviceOwnerAuthenticationWithWatch = 3
    case deviceOwnerAuthenticationWithBiometricsOrWatch = 4
}
```

**Key Properties:**

| Property | Type | Purpose |
|----------|------|---------|
| `biometricType` | `LABiometryType` | `.touchID`, `.faceID`, or `.none` |
| `evaluatedPolicyDomainState` | `Data?` | Deprecated in iOS 15 / macOS 12; snapshot of biometric enrollment state |
| `domainState` | `LADomainState` | Modern replacement (macOS 15+ / iOS 18+); contains `biometry.stateHash` [^3034^] |
| `localizedFallbackTitle` | `String?` | Customizes fallback button; set to `nil` for default, `""` to hide |

### 2.2 Biometric Change Detection

Apple's `LADomainState` (introduced in macOS 15.0 / iOS 18.0) provides structured biometric state monitoring [^3034^]:

```objc
@interface LADomainStateBiometry : NSObject
@property (nonatomic, readonly) LABiometryType biometryType;
@property (nonatomic, readonly, nullable) NSData *stateHash;
@end

@interface LADomainState : NSObject
@property (nonatomic, readonly) LADomainStateBiometry *biometry;
@property (nonatomic, readonly, nullable) NSData *stateHash;
@end
```

**Critical Warning from Apple documentation:** [^3034^]
> "Please note that the value returned by this property can change exceptionally between major OS versions even if the state of biometry has not changed."

**Recommended Pattern for Epistemos:**

```swift
func detectBiometricChange() -> Bool {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return false
    }
    
    if #available(macOS 15.0, *) {
        guard let currentHash = context.domainState?.biometry.stateHash else { return false }
        let storedHash = KeychainVault.loadBiometricStateHash()
        return storedHash != nil && storedHash != currentHash
    } else {
        guard let currentHash = context.evaluatedPolicyDomainState else { return false }
        let storedHash = KeychainVault.loadBiometricStateHash()
        return storedHash != nil && storedHash != currentHash
    }
}
```

### 2.3 Secure Enclave & Keychain Integration

For vault encryption keys, Epistemos should use `kSecAccessControlBiometryCurrentSet` to ensure that **adding or removing a fingerprint invalidates the vault key** [^2423^][^2429^].

```swift
let flags: SecAccessControlCreateFlags = [.biometryCurrentSet, .privateKeyUsage]
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    flags,
    nil
)
```

**Behavior Matrix:**

| Flag | New fingerprint added? | Key valid? |
|------|------------------------|------------|
| `kSecAccessControlBiometryAny` | Yes | Yes |
| `kSecAccessControlBiometryCurrentSet` | Yes | **No** (invalidated) |
| `kSecAccessControlUserPresence` | N/A | Yes (passcode fallback) |

Epistemos **MUST** use `kSecAccessControlBiometryCurrentSet` for vault master keys to enforce re-authentication after biometric enrollment changes.

### 2.4 Entitlements for LocalAuthentication

No special entitlements are required for `LocalAuthentication.framework`. It is a standard public framework available to all sandboxed apps. However, apps that use `kSecAccessControlBiometryCurrentSet` require that the device has a passcode set; if not, key generation will fail.

---

## 3. Security-Scoped Bookmarks & CVE-2025-31191

### 3.1 Security-Scoped Bookmark Mechanics

Security-scoped bookmarks (SSBs) allow sandboxed apps to maintain persistent access to user-selected files across app restarts and system reboots [^3020^][^3068^].

**Architecture Flow:**

```
User selects file via NSOpenPanel
    ↓
com.apple.appkit.xpc.openAndSavePanelService.xpc (unsandboxed)
    ↓
Kernel issues sandbox extension token (HMAC-SHA256 signed, boot-ephemeral)
    ↓
App receives token → accesses file for current session
    ↓
App creates security-scoped bookmark via ScopedBookmarkAgent
    ↓
Bookmark stored in securebookmarks.plist (HMAC-SHA256 with app-specific key)
    ↓
On relaunch: Bookmark → ScopedBookmarkAgent → new sandbox extension
```

**Key APIs:**

```swift
// Creation
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Resolution
var isStale = false
let resolvedURL = try URL(
    resolvingBookmarkData: storedBookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)

// Access lifecycle
resolvedURL.startAccessingSecurityScopedResource()
// ... read/write file ...
resolvedURL.stopAccessingSecurityScopedResource()
```

### 3.2 Implicit vs Explicit Scope

| Type | Creation | Persistence | Use Case |
|------|----------|-------------|----------|
| **Implicit scope** | Received from NSOpenPanel, drag-and-drop, or another process | Valid for current session only | Immediate file operations |
| **Explicit scope (app-scope)** | Created with `.withSecurityScope` | Stored in `securebookmarks.plist`; valid across reboots | Long-term vault directories |
| **Document-scope** | Created with `.withSecurityScope` + document reference | Bound to a specific document | Document-based apps |

**Critical Rule:** Only the process that created a security-scoped bookmark can resolve it [^3075^]. To pass file access between processes (e.g., to an XPC service), use a **non-security-scoped bookmark** (options: `[]`), which embeds a sandbox extension that the receiving process can consume [^3068^][^3020^].

### 3.3 CVE-2025-31191: The SSB Sandbox Escape

**Discovery:** Microsoft Threat Intelligence discovered and disclosed this vulnerability in April 2024; Apple patched it in March 2025 [^3094^][^3023^].

**CVSS:** High severity (CWE-200: Information Exposure) [^3099^]

**Root Cause:** The `ScopedBookmarkAgent` stores its signing secret in the macOS Keychain under `com.apple.scopedbookmarksagent.xpc`. The Keychain ACL for this entry **only restricted read access**, but allowed **deletion and replacement** by any sandboxed process [^3094^][^3031^].

**Attack Chain:**

```
1. Attacker deletes legitimate keychain entry: com.apple.scopedbookmarksagent.xpc
2. Attacker inserts new entry with same name but known secret + permissive ACL
3. Attacker calculates cryptoKey = HMAC-SHA256(knownSecret, [bundle-id])
4. Attacker forges bookmark for arbitrary path, signs with cryptoKey
5. Attacker injects forged bookmark into securebookmarks.plist
6. App calls resolve → ScopedBookmarkAgent validates with attacker-controlled secret
7. Sandbox escape achieved without user interaction
```

**Impact:** Any sandboxed app using SSBs was vulnerable to generic sandbox escape [^3094^].

**Apple Fix:** "Improved state management" in macOS Ventura 13.7.5, Sonoma 14.7.5, Sequoia 15.4, iOS/iPadOS 18.4 [^3023^]. Microsoft reports the fix properly protects the keychain entry against deletion/replacement.

### 3.4 Epistenos Mitigations for CVE-2025-31191

1. **Minimum OS Version:** Require macOS 14.7.5+ or 15.4+ for MAS builds; document this in App Store metadata.
2. **Runtime Check:** Verify `NSProcessInfo.processInfo.operatingSystemVersion` on launch; warn users on unpatched systems.
3. **Bookmark Integrity Monitoring:** Store a SHA-256 hash of each bookmark's data at creation time; verify on resolution. Anomalies trigger vault re-authentication.
4. **Keychain Access Group Isolation:** Use app-specific keychain access groups (`com.epistenos.*`) with strict ACLs; never rely on system keychain entries.
5. **Audit Logging:** Log all `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` pairs for Hermes sidecar operations.

---

## 4. App Sandbox Entitlements

### 4.1 Required Entitlements (All Builds)

```xml
<!-- Base sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- User-selected file access -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Security-scoped bookmarks (app-scope) -->
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>

<!-- Network access for LLM sidecar -->
<key>com.apple.security.network.client</key>
<true/>
```

### 4.2 MAS-Specific Considerations

Apple requires all MAS apps to be sandboxed [^2342^]. The `com.apple.security.files.user-selected.read-write` entitlement grants read-write access to files the user selects via `NSOpenPanel` or `NSSavePanel` [^3042^].

**Temporary Exception Entitlements** should be avoided for MAS submission unless absolutely necessary and well-justified [^3096^][^3098^]:

```xml
<!-- AVOID unless strictly required -->
<key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
<array>
    <string>/Library/Application Support/Epistenos/</string>
</array>
```

Apple reviewers will reject apps using broad temporary exceptions (e.g., `/` or `~`) [^3059^]. Epistemos should not require temporary exceptions if designed correctly around user-selected directories + security-scoped bookmarks.

### 4.3 Pro Build (Direct Distribution) Differences

Pro builds distributed outside MAS can be **notarized without full sandboxing**, though sandboxing is still recommended for security. Pro builds may optionally claim:

```xml
<!-- Pro-only: broader file access (not MAS-compatible) -->
<key>com.apple.security.files.all</key>
<true/>
```

> ⚠️ `com.apple.security.files.all` is deprecated and will be rejected by MAS review.

---

## 5. NSOpenPanel & Persistent Resource Access

### 5.1 Directory Selection via NSOpenPanel

```swift
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.allowsMultipleSelection = false
panel.prompt = "Select Vault Directory"
panel.message = "Choose a folder to use as an Epistemos vault"

panel.begin { result in
    guard result == .OK, let url = panel.url else { return }
    // User selected directory; now create security-scoped bookmark
}
```

When the user selects a directory via `NSOpenPanel`, macOS **implicitly starts** security-scoped access on the returned URL [^3020^]. The app must still call `stopAccessingSecurityScopedResource()` when done, but does not need to call `startAccessingSecurityScopedResource()` for the URL returned directly from the panel.

### 5.2 Bookmark Storage Best Practices

**Storage Location Options:**

| Location | Pros | Cons |
|----------|------|------|
| `UserDefaults` | Simple, fast | Not encrypted; accessible to backups |
| `Keychain` | Encrypted at rest | Slower; size limits (~4KB per item) |
| `SwiftData` | Typed, queryable | Complex; not encrypted by default |
| `App Container plist` | Standard macOS pattern | Requires careful migration |

**Epistenos Recommendation:** Store bookmark **metadata** (vault ID, display name, path string, bookmark hash) in SwiftData. Store the raw `bookmarkData` (`Data`) in the **Keychain** with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for encryption at rest. This separates concerns: metadata is searchable, bookmarks are secure.

**Stale Bookmark Handling:** [^3053^][^3044^]

```swift
var isStale = false
let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

if isStale {
    // Re-create bookmark from resolved URL
    let freshData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    // Update stored bookmark
}
```

---

## 6. Multi-Vault Patterns from Industry

### 6.1 1Password: Dual-Key Encryption + Vault Isolation

1Password uses **dual-key encryption**: each vault is encrypted with a combination of the account password and a 128-bit Secret Key [^3047^]. Multiple vaults within the same account are protected by the same master credentials but maintain separate encryption contexts.

**Relevant for Epistenos:**
- Each vault has its own encryption key derived from a master secret + vault-specific salt
- Biometric authentication unlocks the master key cache, not individual vaults
- Vault metadata (names, counts) is visible without unlocking; contents require authentication

### 6.2 Obsidian: Directory-as-Vault Model

Obsidian treats **any folder on disk** as a vault [^3048^]. Multiple vaults are simply multiple directories. There is no central database; each vault is self-contained.

**Pros:** Simple, portable, git-friendly  
**Cons:** No cross-vault linking, settings isolation, mobile single-vault limitation [^3046^]

**Relevant for Epistenos:**
- Adopt the "directory = vault" mental model for user clarity
- Maintain a separate `.epistenos` metadata folder inside each vault for indexing
- Allow cross-vault search at the metadata level (SwiftData) even if content is isolated

### 6.3 Bear: Per-Note Encryption + Biometric Gate

Bear uses a **multi-cache key hierarchy** for encrypted notes [^3079^]:

```
user_passphrase (in user's mind)
    ↓
encrypted_user_passphrase (SecureEnclave / biometrics / iCloud Keychain)
    ↓
app_encryption_key (short-term memory cache while unlocked)
    ↓
note_encryption_key (derived per-note, zeroed after use)
```

Bear supports per-note encryption with biometric unlocking via Secure Enclave. However, encrypted notes do not support in-text search until decrypted [^3069^].

**Relevant for Epistenos:**
- Use a **two-tier cache**: biometric → vault master key → per-file ephemeral keys
- Maintain a **searchable metadata index** (SwiftData) that does not require file decryption
- File contents are only decrypted in-memory during embedding generation, then immediately zeroed

---

## 7. SwiftData / Core Data for Metadata Indexing

### 7.1 SwiftData Index Macro (iOS 18 / macOS 15)

SwiftData introduced the `#Index` macro in 2024 for query performance optimization [^3102^][^3105^]:

```swift
import SwiftData

@Model
final class VaultFile {
    #Index<VaultFile>([\.pathHash], [\.vaultID, \.contentType], [\.lastModified, \.vaultID])
    
    @Attribute(.unique) var id: UUID
    var vaultID: UUID
    var pathHash: String          // SHA-256 of relative path
    var fileName: String
    var contentType: String         // UTI / MIME type
    var sizeBytes: Int64
    var lastModified: Date
    var createdAt: Date
    var embeddingState: String      // "pending", "indexed", "failed"
    var resonanceClaimID: UUID?     // Link to Resonance Gate claim
    
    @Relationship(deleteRule: .cascade) var embeddings: [FileEmbedding]?
}

@Model
final class FileEmbedding {
    #Index<FileEmbedding>([\.fileID], [\.modelVersion])
    
    var id: UUID
    var fileID: UUID
    var modelVersion: String        // e.g., "text-embedding-3-large"
    var dimensionCount: Int
    var quantizedData: Data         // Compressed float16 array
    var createdAt: Date
}
```

**Index Strategy:**
- `[\.pathHash]` — Fast file lookup by path
- `[\.vaultID, \.contentType]` — Vault-scoped filtering by type
- `[\.lastModified, \.vaultID]` — Incremental sync queries
- `[\.fileID]` on `FileEmbedding` — Join optimization

### 7.2 Core Data Spotlight Integration (Optional)

For system-wide search integration, `NSCoreDataCoreSpotlightDelegate` can index vault file metadata into Core Spotlight [^3071^][^3072^]:

```swift
class VaultSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        return "com.epistenos.vault-files"
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        guard let file = object as? VaultFile else { return nil }
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.displayName = file.fileName
        set.contentDescription = "Vault: \(file.vaultID)"
        set.keywords = [file.contentType]
        return set
    }
}
```

> Note: `NSCoreDataCoreSpotlightDelegate` requires `NSPersistentHistoryTrackingKey` enabled on the SQLite store [^3072^].

### 7.3 Zero-Copy Metadata Reads

SwiftData's `ModelContext` supports background fetching. For large vaults (25k+ files, per Obsidian benchmarks [^3043^]), use `@ModelActor` for background indexing:

```swift
@ModelActor
final class VaultIndexer {
    func indexFiles(vaultID: UUID) async throws -> [VaultFile] {
        let descriptor = FetchDescriptor<VaultFile>(
            predicate: #Predicate { $0.vaultID == vaultID && $0.embeddingState == "pending" }
        )
        return try modelContext.fetch(descriptor)
    }
}
```

---

## 8. Formal Vault Lifecycle

```
┌─────────┐    ┌─────────────┐    ┌──────────┐    ┌───────┐    ┌─────────┐
│  CREATE │───→│ AUTHENTICATE│───→│  ACCESS  │───→│  LOCK │───→│ DELETE  │
└─────────┘    └─────────────┘    └──────────┘    └───────┘    └─────────┘
     │               │                  │              │            │
     ▼               ▼                  ▼              ▼            ▼
  NSOpenPanel    LAContext           Bookmark      Invalidate    Revoke
  Bookmark       evaluatePolicy      Resolution    Key Cache     Bookmark
  Creation       Keychain Unlock     File I/O      Zero Memory   SwiftData
  SwiftData      DomainState Check     Embedding                   Cleanup
  Insert
```

**State Machine:**

| State | Description | Transitions |
|-------|-------------|-------------|
| `created` | Vault directory selected, bookmark stored, metadata indexed | `authenticate` |
| `locked` | Vault metadata visible; contents inaccessible | `authenticate`, `delete` |
| `authenticated` | Biometric / passcode verified; vault key in Secure Enclave cache | `access`, `lock` |
| `accessing` | Bookmark resolved, sandbox extension active, file I/O in progress | `lock` |
| `deleted` | Bookmark revoked from Keychain and SwiftData; files untouched | (terminal) |

**Critical Invariant:** The vault encryption key (if any) and resolved bookmark sandbox extensions are **never persisted to disk**. They exist only in memory and Secure Enclave caches while the vault is in `authenticated` or `accessing` state.

---

## 9. Touch ID Integration with Vault Unlocking

### 9.1 Authentication Policy Selection

| Policy | Biometric Required? | Passcode Fallback? | Use Case |
|--------|---------------------|-------------------|----------|
| `.deviceOwnerAuthenticationWithBiometrics` | Yes | Optional (configurable) | Primary vault unlock |
| `.deviceOwnerAuthentication` | Optional | Yes | Recovery / fallback mode |
| `.deviceOwnerAuthenticationWithBiometricsOrWatch` | Yes (or Watch) | No | Wearable integration |

**Epistenos Primary Policy:** `.deviceOwnerAuthenticationWithBiometrics` with `localizedFallbackTitle = "Use Password"` for vaults with password fallback enabled.

### 9.2 Fallback to Password Pattern

```swift
enum VaultAuthentication {
    case biometric(LAPolicy)
    case password(derivedKey: Data)
    case biometricOrPassword
}

func unlockVault(_ vault: Vault, method: VaultAuthentication) async throws {
    let context = LAContext()
    context.localizedReason = "Unlock vault \(vault.displayName)"
    
    switch method {
    case .biometric(let policy):
        let success = try await context.evaluatePolicy(policy, localizedReason: context.localizedReason)
        if success {
            try await loadVaultKeyFromSecureEnclave(vaultID: vault.id)
        }
    case .password(let derivedKey):
        try await unlockWithPasswordKey(vaultID: vault.id, derivedKey: derivedKey)
    case .biometricOrPassword:
        // Try biometric first; on LAError.userFallback, prompt password
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: context.localizedReason)
            if success { try await loadVaultKeyFromSecureEnclave(vaultID: vault.id) }
        } catch let error as LAError where error.code == .userFallback {
            // Present password dialog
            let password = try await presentPasswordDialog()
            let derivedKey = deriveKey(password: password, salt: vault.salt)
            try await unlockWithPasswordKey(vaultID: vault.id, derivedKey: derivedKey)
        }
    }
}
```

### 9.3 Biometric Change Detection & Vault Key Invalidation

When `domainState.biometry.stateHash` changes (new fingerprint added/removed), Epistemos must:

1. **Detect** the change on next `canEvaluatePolicy` call
2. **Invalidate** the vault master key cache
3. **Require** full password re-authentication (not just biometric)
4. **Re-derive** the vault key with the new biometric context

This prevents an attacker who adds their fingerprint from accessing vaults using only biometrics.

---

## 10. Bookmark Storage & Epistemos Core ↔ Hermes Sidecar

### 10.1 Bookmark Storage Architecture

```
┌─────────────────────────────────────────┐
│           Epistemos Core (Swift)          │
│  ┌─────────────┐    ┌─────────────────┐  │
│  │  SwiftData  │    │    Keychain     │  │
│  │  (metadata) │    │ (bookmarkData)  │  │
│  │  - vaultID  │    │  - encrypted    │  │
│  │  - name     │    │  - accessible   │  │
│  │  - pathHash │    │    when unlocked│  │
│  └──────┬──────┘    └─────────────────┘  │
│         │                                │
│  ┌──────▼──────────────────────┐         │
│  │   VaultAccessManager        │         │
│  │   - resolveBookmark()      │         │
│  │   - start/stopAccess()       │         │
│  └──────┬──────────────────────┘         │
│         │                                │
│  ┌──────▼──────────────────────┐         │
│  │     UniFFI Bridge           │         │
│  │   - pass bookmarkData bytes │         │
│  │   - pass file descriptors   │         │
│  └──────┬──────────────────────┘         │
└─────────┼─────────────────────────────────┘
          │
┌─────────▼─────────────────────────────────┐
│         Hermes Sidecar (Rust)             │
│  ┌─────────────────────────────────┐      │
│  │   BookmarkResolver (unsafe)   │      │
│  │   - POSIX open() via fd       │      │
│  │   - mmap() for zero-copy      │      │
│  │   - embedding pipeline        │      │
│  └─────────────────────────────────┘      │
└─────────────────────────────────────────┘
```

### 10.2 Passing Bookmarks Between Processes

**Critical Finding:** Security-scoped bookmarks cannot be resolved by a different process [^3075^]. To give Hermes (an XPC service or separate process) access to vault files:

1. **Epistemos Core** resolves the security-scoped bookmark into a URL
2. **Epistemos Core** calls `startAccessingSecurityScopedResource()` on the URL
3. **Epistemos Core** creates a **non-security-scoped bookmark** (`options: []`) from the same URL — this embeds a sandbox extension
4. **Epistemos Core** passes the non-security-scoped bookmark data to Hermes via UniFFI
5. **Hermes** resolves the non-security-scoped bookmark and receives a URL with the sandbox extension already attached
6. **Hermes** can now `open()` / `mmap()` the file without further macOS permission dialogs
7. When done, **Hermes** resolves to completion; **Epistemos Core** calls `stopAccessingSecurityScopedResource()` [^3068^][^3075^]

**Alternative (Zero-Copy File Descriptor Passing):**

For true zero-copy, Epistenos Core can `open()` the file within its sandbox extension, then pass the raw file descriptor to Hermes via `sendmsg()` with `SCM_RIGHTS`. However, XPC does not directly support fd passing. The recommended pattern is:

1. Core opens file via bookmark
2. Core reads file into an `UnsafeMutablePointer<UInt8>` or `Data`
3. Core passes the byte buffer to Rust via UniFFI (zero-copy via `&[u8]` references where possible)
4. Rust processes and immediately drops the reference

UniFFI supports zero-copy string views and byte slices where safe [^677^].

---

## 11. Vault Data Model

### 11.1 Entity Hierarchy

```
Vault (1)
├── Directory (*)
│   ├── File (*)
│   │   ├── Metadata (1)
│   │   ├── Content (1) — external, on disk
│   │   └── Embedding (0..*)
│   └── Subdirectory (*)
├── AccessPolicy (1)
├── BookmarkData (1) — in Keychain
└── AuditLog (*)
```

### 11.2 SwiftData Schema

```swift
@Model
final class Vault {
    #Index<Vault>([\.name], [\.createdAt])
    
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var lastAccessedAt: Date?
    var state: String            // "created", "locked", "authenticated", "accessing"
    var bookmarkKeychainAccount: String  // Keychain account identifier for bookmark
    var pathHash: String         // SHA-256 of canonical path
    var accessPolicyID: UUID
    
    @Relationship(deleteRule: .cascade) var directories: [VaultDirectory]?
    @Relationship(deleteRule: .nullify) var accessPolicy: VaultAccessPolicy?
    @Relationship(deleteRule: .cascade) var auditLogs: [VaultAuditLog]?
}

@Model
final class VaultAccessPolicy {
    var id: UUID
    var vaultID: UUID
    var biometricRequired: Bool
    var passwordFallbackEnabled: Bool
    var autoLockTimeoutSeconds: Int
    var encryptionLevel: String   // "none", "metadata", "full"
    var keyDerivationParams: Data // Argon2id params JSON
}

@Model
final class VaultDirectory {
    #Index<VaultDirectory>([\.vaultID, \.relativePath])
    
    var id: UUID
    var vaultID: UUID
    var relativePath: String      // Path relative to vault root
    var depth: Int
    var fileCount: Int
    var lastScannedAt: Date
    
    @Relationship(deleteRule: .cascade) var files: [VaultFile]?
    @Relationship(deleteRule: .nullify) var parentDirectory: VaultDirectory?
}

@Model
final class VaultFile {
    #Index<VaultFile>([\.vaultID, \.relativePath], [\.contentType, \.embeddingState])
    
    @Attribute(.unique) var id: UUID
    var vaultID: UUID
    var directoryID: UUID
    var relativePath: String
    var fileName: String
    var contentType: String       // UTType identifier
    var sizeBytes: Int64
    var createdAt: Date
    var lastModified: Date
    var embeddingState: String    // "pending", "queued", "indexed", "failed", "excluded"
    var checksumSHA256: String?
    var resonanceClaimID: UUID?   // Foreign key to Resonance Gate
    
    @Relationship(deleteRule: .cascade) var embeddings: [FileEmbedding]?
}

@Model
final class FileEmbedding {
    #Index<FileEmbedding>([\.fileID, \.modelVersion])
    
    var id: UUID
    var fileID: UUID
    var modelVersion: String
    var dimensionCount: Int
    var quantizationScheme: String // "q8_0", "q4_0", "fp16"
    var vectorData: Data          // Compressed embedding bytes
    var createdAt: Date
    var inferenceEngine: String    // "openai", "local", "mixed"
}

@Model
final class VaultAuditLog {
    #Index<VaultAuditLog>([\.vaultID, \.timestamp])
    
    var id: UUID
    var vaultID: UUID
    var eventType: String         // "unlock", "lock", "file_access", "bookmark_refresh", "biometric_change"
    var timestamp: Date
    var success: Bool
    var errorCode: String?
    var processID: Int
}
```

---

## 12. Resonance Gate Classification

The Resonance Gate is Epistenos's epistemic classification system for file-derived claims. It must distinguish between **Prime** (user-authored) and **Composite** (derived/AI-generated) claims.

### 12.1 Classification Logic

| Source Type | Resonance Classification | Rationale |
|-------------|------------------------|-----------|
| User-written Markdown, text files | **Prime** | Direct user authorship; highest epistemic weight |
| Imported web articles (clippings) | **Composite** | Second-hand information; requires source attribution |
| LLM-generated summaries | **Composite** | Derived content; must flag provenance |
| Transcribed voice notes | **Prime-Transcribed** | User-authored but mediated; keep attribution |
| PDF annotations / highlights | **Prime-Annotated** | User-authored overlay on Composite base |
| Imported emails, Slack exports | **Composite-Imported** | External origin; metadata required |
| Screenshots with OCR | **Composite-OCR** | Derived from visual; low initial confidence |

### 12.2 SwiftData Schema for Resonance Gate

```swift
@Model
final class ResonanceClaim {
    #Index<ResonanceClaim>([\.fileID], [\.classification], [\.confidenceScore])
    
    var id: UUID
    var fileID: UUID
    var vaultID: UUID
    var classification: String   // "prime", "composite", "prime-transcribed", "composite-imported", "composite-ocr"
    var confidenceScore: Double  // 0.0 ... 1.0
    var sourceAttribution: String?
    var provenanceChain: Data      // JSON array of derivation steps
    var humanVerified: Bool
    var aiGenerated: Bool
    var createdAt: Date
    var lastReviewedAt: Date?
}
```

### 12.3 Classification Rules (Deterministic)

```swift
func classifyFile(_ file: VaultFile) -> ResonanceClaim {
    let ext = (file.fileName as NSString).pathExtension.lowercased()
    let isUserWritten = ["md", "txt", "org", "rst"].contains(ext)
    let isImport = file.relativePath.contains("/Imports/") || file.relativePath.contains("/Clippings/")
    let isLLMOutput = file.relativePath.contains("/Generated/") || file.embeddingState == "llm-output"
    
    if isLLMOutput {
        return ResonanceClaim(classification: "composite", confidenceScore: 0.6, aiGenerated: true)
    } else if isUserWritten && !isImport {
        return ResonanceClaim(classification: "prime", confidenceScore: 1.0, aiGenerated: false)
    } else if isUserWritten && isImport {
        return ResonanceClaim(classification: "composite-imported", confidenceScore: 0.75, aiGenerated: false)
    } else if ["pdf", "docx", "epub"].contains(ext) {
        return ResonanceClaim(classification: "composite", confidenceScore: 0.7, aiGenerated: false)
    } else {
        return ResonanceClaim(classification: "composite", confidenceScore: 0.5, aiGenerated: false)
    }
}
```

---

## 13. Entitlements: MAS vs Pro Builds

### 13.1 MAS Build (`Epistenos.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Mandatory sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- User-selected file access (read-write for vault directories) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Security-scoped bookmarks (app-scope) -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    
    <!-- Network for LLM sidecar -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Camera / microphone (optional, for future voice notes) -->
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    
    <!-- Printing (optional) -->
    <key>com.apple.security.print</key>
    <true/>
    
    <!-- Home directory downloads folder (convenience) -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

### 13.2 Pro Build (`Epistenos.pro.entitlements`)

Pro builds use the same entitlement base, but may add:

```xml
<!-- Pro-only: allow execution of helper tools in app container -->
<key>com.apple.security.files.user-selected.executable</key>
<true/>

<!-- Pro-only: disable library validation for plugin architecture (notarized only) -->
<!-- <key>com.apple.security.cs.disable-library-validation</key> -->
<!-- <true/> -->
```

> ⚠️ `com.apple.security.cs.disable-library-validation` is **not** MAS-compatible. Use only for direct distribution with notarization.

### 13.3 Hermes Sidecar XPC Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Inherits parent's sandbox extensions via non-scoped bookmarks -->
    <key>com.apple.security.inherits</key>
    <true/>
    
    <!-- Network for model downloads / API calls -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

> Note: `com.apple.security.inherits` enables child process inheritance of the parent's sandbox, but **does not work for XPC Services** [^3075^]. For XPC, use non-security-scoped bookmarks as described in Section 10.2.

---

## 14. Rust ↔ Swift FFI (UniFFI)

### 14.1 UniFFI Architecture

UniFFI generates Swift bindings from Rust UDL or proc-macro annotations [^3070^][^677^].

**Build Flow:**

```
Rust lib (cdylib + staticlib)
    ↓ uniffi-bindgen
Swift bindings (.swift + .h + .modulemap)
    ↓ Xcode SPM / CocoaPods
Swift app calls Rust functions directly
```

### 14.2 Security-Scoped Bookmark Passing via UniFFI

UniFFI natively supports `bytes` / `sequence<u8>` types. The recommended pattern for passing bookmark data:

```rust
// Rust side (lib.rs)
use std::sync::Arc;

#[derive(uniffi::Object)]
pub struct VaultBookmark {
    bookmark_data: Vec<u8>,
    vault_id: String,
    is_read_only: bool,
}

#[uniffi::export]
impl VaultBookmark {
    #[uniffi::constructor]
    pub fn new(bookmark_data: Vec<u8>, vault_id: String, is_read_only: bool) -> Arc<Self> {
        Arc::new(Self { bookmark_data, vault_id, is_read_only })
    }
}

#[uniffi::export]
pub fn process_file_with_bookmark(
    bookmark: Arc<VaultBookmark>,
    file_path: String,
) -> Result<EmbeddingResult, VaultError> {
    // The bookmark_data here is a non-security-scoped bookmark
    // received from Swift. On macOS, Rust cannot resolve it directly
    // because Rust lacks Foundation APIs.
    // 
    // SOLUTION: Swift resolves the bookmark, opens the file,
    // and passes the raw bytes (or fd) to Rust.
    unimplemented!("See Section 15 for full pattern")
}
```

### 14.3 Zero-Copy Byte Passing

UniFFI minimizes data copying by using Rust references where possible [^677^]:

```rust
// Zero-copy string view (where safe)
#[uniffi::export]
pub fn classify_content(content: &str) -> ResonanceClassification {
    // content is a borrowed string; no heap copy
    ...
}

// For large file content, Swift allocates Data and passes ownership
#[uniffi::export]
pub fn generate_embedding(content_bytes: Vec<u8>) -> EmbeddingResult {
    // UniFFI transfers ownership of the Vec; no additional copy
    ...
}
```

### 14.4 Error Handling Pattern

```rust
#[derive(uniffi::Error)]
pub enum VaultError {
    BookmarkStale,
    BiometricChanged,
    KeychainError { code: i32 },
    SandboxViolation { path: String },
    EmbeddingFailed { reason: String },
}

#[uniffi::export]
pub fn resolve_and_embed(
    bookmark_bytes: Vec<u8>,
    file_relative_path: String,
) -> Result<EmbeddingResult, VaultError> {
    ...
}
```

---

## 15. Swift Code Scaffold

### 15.1 Vault Creation & Bookmark Persistence

```swift
import Foundation
import LocalAuthentication
import SwiftData
import Security

// MARK: - Vault Manager

@MainActor
final class VaultManager: ObservableObject {
    private let modelContext: ModelContext
    private let keychain = VaultKeychain()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Creates a new vault from a user-selected directory
    func createVault(name: String, directoryURL: URL) async throws -> Vault {
        // 1. Create security-scoped bookmark
        let bookmarkData = try directoryURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // 2. Hash the canonical path for deduplication
        let pathHash = SHA256.hash(data: Data(directoryURL.path(percentEncoded: false).utf8))
            .compactMap { String(format: "%02x", $0) }.joined()
        
        // 3. Create vault entity
        let vault = Vault(
            id: UUID(),
            name: name,
            createdAt: Date(),
            state: "created",
            bookmarkKeychainAccount: "bookmark-\(UUID().uuidString)",
            pathHash: pathHash,
            accessPolicyID: UUID()
        )
        
        // 4. Create access policy
        let policy = VaultAccessPolicy(
            id: vault.accessPolicyID,
            vaultID: vault.id,
            biometricRequired: true,
            passwordFallbackEnabled: true,
            autoLockTimeoutSeconds: 300,
            encryptionLevel: "metadata",
            keyDerivationParams: Data() // Argon2id params
        )
        
        // 5. Persist bookmark to Keychain (encrypted at rest)
        try keychain.saveBookmarkData(bookmarkData, account: vault.bookmarkKeychainAccount)
        
        // 6. Insert into SwiftData
        modelContext.insert(vault)
        modelContext.insert(policy)
        try modelContext.save()
        
        return vault
    }
}

// MARK: - Keychain Wrapper

final class VaultKeychain {
    func saveBookmarkData(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.epistenos.vault-bookmark",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func loadBookmarkData(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "com.epistenos.vault-bookmark",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }
        return data
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
}
```

### 15.2 Biometric Authentication & Vault Unlock

```swift
import LocalAuthentication

@MainActor
final class BiometricVaultGate {
    private var vaultKeyCache: [UUID: SecKey] = [:]
    private var activeAccessTokens: [UUID: URL] = [:]
    
    /// Authenticates and unlocks a vault
    func authenticateVault(_ vault: Vault) async throws {
        let context = LAContext()
        context.localizedReason = "Unlock vault \"\(vault.name)\""
        context.localizedFallbackTitle = "Use Password"
        
        // Check biometric availability
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error as? LAError, error.code == .biometryNotAvailable {
                // Fallback to password
                try await authenticateWithPassword(vault)
                return
            }
            throw VaultError.biometricUnavailable
        }
        
        // Detect biometric enrollment changes
        if detectBiometricChange(context: context, vault: vault) {
            throw VaultError.biometricEnrollmentChanged
        }
        
        // Evaluate biometric
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: context.localizedReason
        )
        
        guard success else {
            throw VaultError.authenticationFailed
        }
        
        // Load or derive vault key
        try await loadVaultKey(vault, context: context)
        
        // Resolve bookmark and start access
        try await beginVaultAccess(vault)
        
        // Update vault state
        vault.state = "authenticated"
        vault.lastAccessedAt = Date()
    }
    
    private func detectBiometricChange(context: LAContext, vault: Vault) -> Bool {
        if #available(macOS 15.0, *) {
            guard let currentHash = context.domainState?.biometry.stateHash else { return false }
            let storedHash = UserDefaults.standard.data(forKey: "biometric-hash-\(vault.id.uuidString)")
            return storedHash != nil && storedHash != currentHash
        } else {
            guard let currentHash = context.evaluatedPolicyDomainState else { return false }
            let storedHash = UserDefaults.standard.data(forKey: "biometric-hash-\(vault.id.uuidString)")
            return storedHash != nil && storedHash != currentHash
        }
    }
    
    private func beginVaultAccess(_ vault: Vault) async throws {
        let keychain = VaultKeychain()
        let bookmarkData = try keychain.loadBookmarkData(account: vault.bookmarkKeychainAccount)
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            // Refresh bookmark
            let freshData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            try keychain.saveBookmarkData(freshData, account: vault.bookmarkKeychainAccount)
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            throw VaultError.sandboxAccessDenied
        }
        
        activeAccessTokens[vault.id] = url
        vault.state = "accessing"
    }
    
    func lockVault(_ vault: Vault) {
        if let url = activeAccessTokens.removeValue(forKey: vault.id) {
            url.stopAccessingSecurityScopedResource()
        }
        vaultKeyCache.removeValue(forKey: vault.id)
        vault.state = "locked"
    }
}

enum VaultError: Error {
    case biometricUnavailable
    case biometricEnrollmentChanged
    case authenticationFailed
    case sandboxAccessDenied
    case bookmarkStale
}
```

### 15.3 NSOpenPanel Integration

```swift
import AppKit

final class VaultDirectoryPicker {
    func selectVaultDirectory(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Vault"
        panel.message = "Choose a folder to use as your Epistenos vault"
        
        panel.begin { result in
            guard result == .OK else {
                completion(nil)
                return
            }
            completion(panel.url)
        }
    }
}
```

### 15.4 SwiftData Metadata Indexing

```swift
@ModelActor
final class VaultMetadataIndexer {
    /// Scans a vault directory and indexes file metadata without reading contents
    func scanVaultDirectory(vault: Vault, url: URL) async throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentTypeKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .contentModificationDateKey])
            
            let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "").trimmingCharacters(in: .init(charactersIn: "/"))
            let pathHash = SHA256.hash(data: Data(relativePath.utf8)).compactMap { String(format: "%02x", $0) }.joined()
            
            let file = VaultFile(
                id: UUID(),
                vaultID: vault.id,
                directoryID: UUID(), // lookup actual directory ID
                relativePath: relativePath,
                fileName: fileURL.lastPathComponent,
                contentType: resourceValues.contentType?.identifier ?? "public.data",
                sizeBytes: resourceValues.fileSize ?? 0,
                createdAt: Date(),
                lastModified: resourceValues.contentModificationDate ?? Date(),
                embeddingState: "pending",
                checksumSHA256: nil,
                resonanceClaimID: nil
            )
            
            modelContext.insert(file)
        }
        
        try modelContext.save()
    }
}
```

---

## 16. Rust Code Scaffold

### 16.1 Vault Indexing & Embedding Pipeline

```rust
use std::sync::Arc;
use std::collections::HashMap;
use uniffi;

// MARK: - Core Types

#[derive(uniffi::Record)]
pub struct EmbeddingResult {
    pub file_id: String,
    pub model_version: String,
    pub dimensions: u32,
    pub quantized_vector: Vec<u8>,
    pub quantization_scheme: String,
}

#[derive(uniffi::Record)]
pub struct FileMetadata {
    pub file_id: String,
    pub relative_path: String,
    pub content_type: String,
    pub size_bytes: i64,
    pub checksum_sha256: Option<String>,
}

#[derive(uniffi::Enum)]
pub enum ResonanceClassification {
    Prime,
    PrimeTranscribed,
    PrimeAnnotated,
    Composite,
    CompositeImported,
    CompositeOcr,
}

#[derive(uniffi::Error)]
pub enum VaultRustError {
    IoError { path: String, message: String },
    EmbeddingFailed { reason: String },
    InvalidContentType { mime: String },
    ChecksumMismatch { expected: String, actual: String },
}

// MARK: - Vault Index Engine

#[derive(uniffi::Object)]
pub struct VaultIndexEngine {
    model_version: String,
    embedding_dimensions: u32,
}

#[uniffi::export]
impl VaultIndexEngine {
    #[uniffi::constructor]
    pub fn new(model_version: String, embedding_dimensions: u32) -> Arc<Self> {
        Arc::new(Self {
            model_version,
            embedding_dimensions,
        })
    }
    
    /// Processes file content bytes received from Swift.
    /// This is the zero-copy entry point: Swift reads the file via bookmark
    /// and passes the byte slice directly.
    #[uniffi::export]
    pub fn index_file_content(
        &self,
        metadata: FileMetadata,
        content_bytes: Vec<u8>,
    ) -> Result<EmbeddingResult, VaultRustError> {
        // 1. Verify checksum if provided
        if let Some(expected) = &metadata.checksum_sha256 {
            let actual = sha256_hex(&content_bytes);
            if &actual != expected {
                return Err(VaultRustError::ChecksumMismatch {
                    expected: expected.clone(),
                    actual,
                });
            }
        }
        
        // 2. Classify resonance
        let classification = classify_by_metadata(&metadata);
        
        // 3. Extract text based on content type (zero-copy where possible)
        let text = extract_text(&metadata.content_type, &content_bytes)?;
        
        // 4. Generate embedding (mock implementation)
        let embedding = self.generate_embedding(&text)?;
        
        // 5. Quantize to q8_0 for storage efficiency
        let quantized = quantize_q8_0(&embedding);
        
        Ok(EmbeddingResult {
            file_id: metadata.file_id,
            model_version: self.model_version.clone(),
            dimensions: self.embedding_dimensions,
            quantized_vector: quantized,
            quantization_scheme: "q8_0".to_string(),
        })
    }
    
    /// Classifies a file for the Resonance Gate without loading content.
    /// Deterministic classification based on path, extension, and metadata.
    #[uniffi::export]
    pub fn classify_resonance(&self, metadata: &FileMetadata) -> ResonanceClassification {
        classify_by_metadata(metadata)
    }
}

// MARK: - Internal Helpers

fn classify_by_metadata(metadata: &FileMetadata) -> ResonanceClassification {
    let path = &metadata.relative_path;
    let ext = path.rsplit('.').next().unwrap_or("").to_lowercase();
    
    let is_generated = path.contains("/Generated/") || path.contains("/AI/");
    let is_import = path.contains("/Imports/") || path.contains("/Clippings/");
    let is_user_written = matches!(ext.as_str(), "md" | "txt" | "org" | "rst");
    
    if is_generated {
        ResonanceClassification::Composite
    } else if is_user_written && !is_import {
        ResonanceClassification::Prime
    } else if is_user_written && is_import {
        ResonanceClassification::CompositeImported
    } else if ext == "pdf" && path.contains("/OCR/") {
        ResonanceClassification::CompositeOcr
    } else {
        ResonanceClassification::Composite
    }
}

fn extract_text(content_type: &str, bytes: &[u8]) -> Result<String, VaultRustError> {
    match content_type {
        "public.plain-text" | "public.markdown" | "org.unknown.txt" => {
            String::from_utf8(bytes.to_vec())
                .map_err(|e| VaultRustError::InvalidContentType { mime: format!("utf8: {}", e) })
        }
        "public.html" => {
            // Strip HTML tags (simplified)
            Ok(String::from_utf8_lossy(bytes).to_string())
        }
        _ => Err(VaultRustError::InvalidContentType {
            mime: content_type.to_string(),
        }),
    }
}

fn generate_embedding(&self, text: &str) -> Result<Vec<f32>, VaultRustError> {
    // Integration point for local LLM or API call
    // Mock: return zero vector
    Ok(vec![0.0f32; self.embedding_dimensions as usize])
}

fn quantize_q8_0(embedding: &[f32]) -> Vec<u8> {
    // Simplified q8_0 quantization: scale + int8 values
    let max = embedding.iter().copied().fold(0.0f32, f32::max);
    let scale = max / 127.0;
    let mut result = Vec::with_capacity(4 + embedding.len());
    result.extend_from_slice(&scale.to_le_bytes());
    for &v in embedding {
        result.push((v / scale).clamp(-128.0, 127.0) as i8 as u8);
    }
    result
}

fn sha256_hex(data: &[u8]) -> String {
    use sha2::{Sha256, Digest};
    let hash = Sha256::digest(data);
    hash.iter().map(|b| format!("{:02x}", b)).collect()
}

uniffi::setup_scaffolding!();
```

### 16.2 Cargo.toml for UniFFI

```toml
[package]
name = "epistenos-vault-ffi"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["lib", "staticlib", "cdylib"]

[dependencies]
uniffi = { version = "0.29", features = ["cli"] }
sha2 = "0.10"

[build-dependencies]
uniffi = { version = "0.29", features = ["build"] }
```

### 16.3 Build Script for Swift Bindings

```bash
#!/bin/bash
# generate-bindings.sh

cargo build

cargo run --bin uniffi-bindgen generate \
  --library ./target/debug/libepistenos_vault_ffi.dylib \
  --language swift \
  --out-dir ./bindings
```

---

## 17. macOS Entitlement Configurations

### 17.1 Complete MAS Entitlements File

**File:** `Epistenos/Entitlements/Epistenos.mas.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Base App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- User-selected file read-write -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Downloads folder read-write -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <!-- Security-scoped bookmarks (app-scope) -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    
    <!-- Network client (LLM API, sync) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Camera and microphone (voice notes, future features) -->
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    
    <!-- Printing -->
    <key>com.apple.security.print</key>
    <true/>
    
    <!-- Address book (optional, for contact linking) -->
    <key>com.apple.security.personal-information.addressbook</key>
    <false/>
    
    <!-- Location (optional, for geo-tagged notes) -->
    <key>com.apple.security.personal-information.location</key>
    <false/>
</dict>
</plist>
```

### 17.2 Hermes XPC Service Entitlements

**File:** `Epistenos/Entitlements/Hermes.xpc.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Network for model API calls -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- No file entitlements: Hermes receives access via non-scoped bookmarks from Core -->
</dict>
</plist>
```

### 17.3 Pro Build Entitlements

**File:** `Epistenos/Entitlements/Epistenos.pro.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Base App Sandbox (still recommended) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- User-selected file read-write -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Security-scoped bookmarks -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    
    <!-- Network -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Pro-only: executable file creation in user-selected dirs -->
    <key>com.apple.security.files.user-selected.executable</key>
    <true/>
    
    <!-- Pro-only: helper tool execution (notarized, not MAS) -->
    <key>com.apple.security.inherits</key>
    <true/>
</dict>
</plist>
```

---

## 18. Multi-Vault Architecture Data Model Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EPISTEMOS CORE (Swift)                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     SwiftData Model Layer                       │   │
│  │                                                                 │   │
│  │  ┌──────────┐    ┌─────────────┐    ┌─────────────────────────┐ │   │
│  │  │  Vault   │───→│  VaultAccess│───→│     VaultDirectory      │ │   │
│  │  │          │    │   Policy    │    │                         │ │   │
│  │  │ id (PK)  │    │             │    │  id, vaultID (FK)       │ │   │
│  │  │ name     │    │ biometric   │    │  relativePath           │ │   │
│  │  │ state    │    │ passwordFB  │    │  depth, fileCount       │ │   │
│  │  │ pathHash │    │ autoLock    │    │  lastScannedAt          │ │   │
│  │  │ bkAccount│    │ encryption  │    │                         │ │   │
│  │  └────┬─────┘    └─────────────┘    └──────────┬────────────┘ │   │
│  │       │                                          │               │   │
│  │       │ 1:N                                      │ 1:N            │   │
│  │       ↓                                          ↓               │   │
│  │  ┌──────────┐    ┌───────────────────────────────┐              │   │
│  │  │VaultAudit│    │          VaultFile            │              │   │
│  │  │   Log    │    │                               │              │   │
│  │  │          │    │  id (PK), vaultID (FK)        │              │   │
│  │  │ eventType│    │  directoryID (FK)             │              │   │
│  │  │ timestamp│    │  relativePath, fileName       │              │   │
│  │  │ success  │    │  contentType, sizeBytes       │              │   │
│  │  └──────────┘    │  lastModified, embeddingState │              │   │
│  │                  │  checksumSHA256               │              │   │
│  │                  │  resonanceClaimID (FK) ────────┼─────┐        │   │
│  │                  └───────────────┬───────────────┘     │        │   │
│  │                                  │ 1:N                  │        │   │
│  │                                  ↓                    │        │   │
│  │                         ┌─────────────────┐           │        │   │
│  │                         │   FileEmbedding │           │        │   │
│  │                         │                 │           │        │   │
│  │                         │  id, fileID (FK)│           │        │   │
│  │                         │  modelVersion   │           │        │   │
│  │                         │  dimensionCount │           │        │   │
│  │                         │  vectorData     │           │        │   │
│  │                         └─────────────────┘           │        │   │
│  │                                                       │        │   │
│  │                         ┌─────────────────┐            │        │   │
│  │                         │ ResonanceClaim  │◄───────────┘        │   │
│  │                         │                 │                     │   │
│  │                         │  id (PK)        │                     │   │
│  │                         │  fileID (FK)    │                     │   │
│  │                         │  classification │                     │   │
│  │                         │  confidenceScore│                     │   │
│  │                         │  provenanceChain│                     │   │
│  │                         │  humanVerified  │                     │   │
│  │                         └─────────────────┘                     │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Keychain Layer                              │   │
│  │                                                                 │   │
│  │  ┌───────────────────────────────────────────────────────────┐   │   │
│  │  │  Vault Bookmark Data (Generic Password)                  │   │   │
│  │  │  - kSecAttrAccount: "bookmark-<UUID>"                    │   │   │
│  │  │  - kSecAttrService: "com.epistenos.vault-bookmark"       │   │   │
│  │  │  - kSecValueData: <bookmarkData bytes>                   │   │   │
│  │  │  - kSecAttrAccessible: WhenUnlockedThisDeviceOnly        │   │   │
│  │  └───────────────────────────────────────────────────────────┘   │   │
│  │                                                                 │   │
│  │  ┌───────────────────────────────────────────────────────────┐   │   │
│  │  │  Vault Master Key (Secure Enclave, non-exportable)       │   │   │
│  │  │  - kSecAttrTokenID: SecureEnclave                        │   │   │
│  │  │  - kSecAccessControl: BiometryCurrentSet + PrivateKeyUsage│   │   │
│  │  │  - Used to unwrap per-vault encryption keys                │   │   │
│  │  └───────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     UniFFI Bridge                               │   │
│  │  - VaultBookmark (Arc<Object>)                                │   │
│  │  - process_file_content(bytes) → EmbeddingResult              │   │
│  │  - classify_resonance(metadata) → ResonanceClassification     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  │ XPC / FFI
                                  ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                      HERMES SIDECAR (Rust)                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     VaultIndexEngine                              │   │
│  │  - Embedding generation pipeline                                │   │
│  │  - Content extraction (txt, md, pdf, html)                      │   │
│  │  - Resonance classification (deterministic rules)               │   │
│  │  - Vector quantization (q8_0 / fp16)                          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     LLM Inference Bridge                          │   │
│  │  - Local model loading (GGUF / ONNX)                            │   │
│  │  - Remote API client (OpenAI, Anthropic)                      │   │
│  │  - Token counting & rate limiting                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 19. Security Analysis & Threat Mitigation

### 19.1 Threat Model

| ID | Threat | Actor | Impact | Likelihood |
|----|--------|-------|--------|------------|
| T1 | Attacker adds fingerprint, unlocks vault | Local user / thief | High | Medium |
| T2 | Malicious app exploits SSB to read vault files | Third-party malware | High | Low (patched) |
| T3 | Bookmark stale / hijacked after directory move | System / user | Medium | Medium |
| T4 | Memory dump reveals decrypted file contents | Local attacker with root | High | Low |
| T5 | Rust sidecar compromised via crafted file | Network / supply chain | High | Low |
| T6 | Keychain extraction via backup restore | Remote attacker | Medium | Low |
| T7 | Biometric lockout / DoS | Accidental / malicious | Low | Medium |

### 19.2 Mitigations

#### T1: Biometric Enrollment Attacks

**Mitigation:**
- Use `kSecAccessControlBiometryCurrentSet` for vault master keys [^2423^]
- Store `domainState.biometry.stateHash` and invalidate keys on change
- Require full password re-authentication after biometric enrollment change
- Maintain audit log of all biometric authentication events

#### T2: SSB Sandbox Escape (CVE-2025-31191)

**Mitigation:**
- Require macOS 14.7.5+ / 15.4+ minimum version for MAS builds [^3094^]
- Runtime OS version check on launch
- Store bookmark integrity hashes; detect tampering
- Do not store sensitive data in app container (`~/Library/Containers/`) without additional encryption
- Monitor `securebookmarks.plist` size and modification time

#### T3: Stale / Hijacked Bookmarks

**Mitigation:**
- Always check `bookmarkDataIsStale` on resolution [^3053^]
- Re-create bookmarks when stale; update Keychain storage
- Store bookmark creation timestamp; enforce maximum age (e.g., 90 days)
- User notification when bookmark refresh is required

#### T4: Memory Dump Attacks

**Mitigation:**
- Use `memset_s` / `explicit_bzero` on Rust side after file processing
- Keep decrypted content in Rust heap only during embedding generation
- Swift side uses `Data` with `deallocate` on completion; avoid `NSString` bridging for sensitive content
- Leverage Secure Enclave for key operations so keys never enter app memory [^2421^]

#### T5: Rust Sidecar Compromise

**Mitigation:**
- Sandboxing via XPC with minimal entitlements
- Input validation on all file content bytes before processing
- Content-type whitelist (txt, md, pdf, html); reject executables
- Resource limits: max file size, max embedding dimensions, processing timeouts
- Rust `unsafe` code audit; fuzz test file parsers

#### T6: Keychain Backup Extraction

**Mitigation:**
- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to prevent iCloud backup of bookmarks [^2423^]
- Vault master keys use Secure Enclave (`kSecAttrTokenIDSecureEnclave`) which are non-exportable [^2429^]
- Document key rotation procedure in case of device compromise

#### T7: Biometric Lockout / DoS

**Mitigation:**
- Password fallback always enabled for vaults with valuable data
- Exponential backoff on failed biometric attempts (managed by macOS)
- Graceful degradation: vault remains in `locked` state; user can select alternative vault
- Emergency "lock all vaults" menu item that flushes all caches

### 19.3 Security Checklist for Production

- [ ] All bookmark data stored in Keychain with `WhenUnlockedThisDeviceOnly`
- [ ] Vault master keys generated in Secure Enclave with `BiometryCurrentSet`
- [ ] `domainState` hash persisted and validated on every unlock
- [ ] Minimum macOS version enforced (14.7.5+ for CVE-2025-31191 fix)
- [ ] Stale bookmark detection and refresh implemented
- [ ] `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` paired in all code paths
- [ ] Rust sidecar receives only non-security-scoped bookmarks (or raw bytes)
- [ ] All file I/O errors logged to `VaultAuditLog`
- [ ] Memory zeroing after sensitive operations on both Swift and Rust sides
- [ ] App Store and Pro entitlement configurations validated in CI

---

## 20. References

[^2342^]: Eclectic Light Co. "What are app entitlements, and what do they do?" March 2025. https://eclecticlight.co/2025/03/24/what-are-app-entitlements-and-what-do-they-do/

[^3020^]: Apple Developer Documentation. "Accessing files from the macOS App Sandbox." https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox

[^3023^]: SentinelOne. "CVE-2025-31191: Apple iPadOS Information Disclosure Flaw." https://www.sentinelone.com/vulnerability-database/cve-2025-31191/

[^3030^]: Grokipedia. "LAContext." https://grokipedia.com/page/LAContext

[^3031^]: Rewterz. "macOS Sandbox Escape Vulnerability Enables Keychain Deletion and Replacement." May 2025. https://rewterz.com/threat-advisory/macos-sandbox-escape-vulnerability-enables-keychain-deletion-and-replacement

[^3034^]: dotnet/macios Wiki. "LocalAuthentication iOS xcode16.0 b1." https://github.com/dotnet/macios/wiki/LocalAuthentication-iOS-xcode16.0-b1

[^3042^]: Apple Developer Documentation. "com.apple.security.files.user-selected.read-write." https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.files.user-selected.read-write

[^3044^]: De La Sign. "How to Persist File Access on macOS using Swift & Scoped URL Bookmarks." October 2024. https://www.delasign.com/blog/how-to-persist-file-access-on-macos-using-swift-and-scoped-url-bookmarks/

[^3045^]: Reddit r/1Password. "Benefit for having several vaults?" https://www.reddit.com/r/1Password/comments/10d1g05/benefit_for_having_several_vaults/

[^3047^]: 1Password Security Whitepaper. "Everything you need to know about 1Password's security." https://i.1password.com/media/msp/sales/1password-security.pdf

[^3048^]: Preslav Rachev. "Do You Use One Or Multiple Obsidian Vaults?" October 2022. https://preslav.me/2022/10/19/do-you-use-one-or-more-obsidian-vaults/

[^3053^]: SwiftLee. "Security-scoped bookmarks for URL access." October 2024. https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/

[^3059^]: Xojo Forum. "Sandboxed app: renaming files gives write error." February 2014. https://forum.xojo.com/t/sandboxed-app-renaming-files-gives-write-error/14015

[^3068^]: Mothers Ruin Software. "Archaeology | URL Bookmarks and Security-scoping." May 2025. https://www.mothersruin.com/software/Archaeology/reverse/bookmarks.html

[^3069^]: Bear Community. "Bear's Encryption Roadmap for 2025." February 2025. https://community.bear.app/t/bear-s-encryption-roadmap-for-2025/15401

[^3070^]: Mobile System Design. "Multiplatform with Rust on iOS." November 2025. https://mobilesystemdesign.substack.com/p/multiplatform-with-rust-on-ios-2c4

[^3075^]: Matt Rajca. "Accessing Resources From an XPC Service's Host App in the Sandbox." August 2016. https://www.mattrajca.com/2016/08/17/accessing-resources-from-an-xpc-services-host-app-in-the-sandbox.html

[^3079^]: Cossack Labs. "Implementing End-to-End encryption in Bear App." September 2019. https://www.cossacklabs.com/blog/end-to-end-encryption-in-bear-app/

[^3094^]: Microsoft Security Blog. "Analyzing CVE-2025-31191: A macOS security-scoped bookmarks-based sandbox escape." May 2025. https://www.microsoft.com/en-us/security/blog/2025/05/01/analyzing-cve-2025-31191-a-macos-security-scoped-bookmarks-based-sandbox-escape/

[^3096^]: Stack Overflow. "Is there any way to give my sandboxed Mac app read only access to files in ~/Library?" https://stackoverflow.com/questions/10952225

[^3098^]: Hacker News. Discussion of Microsoft Word entitlements. January 2019. https://news.ycombinator.com/item?id=18995754

[^3099^]: NIST NVD. "CVE-2025-31191 Detail." March 2025. https://nvd.nist.gov/vuln/detail/cve-2025-31191

[^3102^]: Yaacoub. "SwiftData's new Index and Unique macros." September 2024. https://yaacoub.github.io/articles/swift-tip/swiftdata-s-new-index-and-unique-macros/

[^3105^]: FatBobman. "SwiftData in WWDC 2024." June 2024. https://fatbobman.com/en/posts/swiftdata-in-wwdc2024/

[^2421^]: Medium. "App Security in Swift: Keychain, Biometrics, Secure Enclave." April 2025. https://medium.com/@gauravharkhani01/app-security-in-swift-keychain-biometrics-secure-enclave-69359b4cffba

[^2423^]: LAC. "Data Storage and Privacy Requirements (MSTG)." https://jp-east.mas.scc.lac.co.jp/iOS/en/build/html/subPage/Data_Storage_and_Privacy_Requirements.html

[^2429^]: OWASP MSTG. "Testing Data Storage on iOS." https://github.com/MobSF/owasp-mstg/blob/master/Document/0x06d-Testing-Data-Storage.md

[^677^]: MoFA. "UniFFI Bindings Overview." https://mintlify.com/mofa-org/mofa/bindings/overview

---

*Document generated for Epistenos Architecture Team. All code scaffolds are illustrative and require production hardening, unit testing, and security audit before deployment.*
