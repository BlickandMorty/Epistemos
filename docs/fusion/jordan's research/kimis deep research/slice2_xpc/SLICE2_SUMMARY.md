# SLICE 2 — AgentXPC + ProviderXPC Services + Capability Grants

## Summary

**Mission:** Build the XPC service skeleton that moves Hermes execution from in-process to a sandboxed XPC helper. This is Hackathon Block A — first priority after the App Group arena (SLICE 1).

**Total files delivered:** 13  
**Total lines of code:** ~1,896  
**Tier:** Core (MAS-shippable)

---

## File Inventory

| # | File | Lines | Language | Purpose |
|---|------|-------|----------|---------|
| 1 | `Epistemos/XPC/AgentServiceProtocol.swift` | 155 | Swift | `@objc` protocols for AgentXPC + ProviderXPC + typed `XPCError` enum |
| 2 | `Epistemos/XPC/AgentServiceClient.swift` | 209 | Swift | `@MainActor` client for `com.epistenos.agentxpc` with auto-recovery |
| 3 | `Epistemos/XPC/ProviderServiceClient.swift` | 182 | Swift | `@MainActor` client for `com.epistenos.providerxpc` with auto-recovery |
| 4 | `XPCServices/AgentXPC/main.swift` | 44 | Swift | `NSXPCListener` entry point for AgentXPC helper |
| 5 | `XPCServices/AgentXPC/AgentService.swift` | 68 | Swift | `AgentServiceProtocol` implementation → `AgentRuntimeBridge` |
| 6 | `XPCServices/ProviderXPC/main.swift` | 42 | Swift | `NSXPCListener` entry point for ProviderXPC helper |
| 7 | `XPCServices/ProviderXPC/ProviderService.swift` | 75 | Swift | `ProviderServiceProtocol` implementation → `ProviderRuntimeBridge` |
| 8 | `Epistemos/Security/CapabilityBridge.swift` | 302 | Swift | `CapabilityIssuer` actor + Keychain root key + `CapFlags` |
| 9 | `EpistemosTests/XPCSmokeTests.swift` | 247 | Swift | Swift Testing `@Suite` + `@Test` — 7 XPC + capability tests |
| 10 | `XPCServices/AgentXPC/AgentXPC.entitlements` | 23 | XML | Sandboxed helper entitlements (App Group + network.client) |
| 11 | `XPCServices/ProviderXPC/ProviderXPC.entitlements` | 23 | XML | Sandboxed helper entitlements (App Group + network.client) |
| 12 | `agent_core/src/capability.rs` | 526 | Rust | HMAC-SHA256 grants + `CapFlags` + `CapabilityError` + 10 tests |
| 13 | `agent_core/Cargo.toml` | 28 | TOML | Crate manifest with `hmac`, `sha2`, `postcard`, `subtle`, `getrandom` |

---

## Swift Side — Design Decisions

### `@MainActor @unchecked Sendable` for clients
Both `AgentServiceClient` and `ProviderServiceClient` are `@MainActor`-bound and marked `@unchecked Sendable`. The unchecked conformance is safe because:
- `NSXPCConnection` is thread-safe by design.
- All mutable state (`connection`, `stateLock`) is protected by `NSLock`.
- Interruption/invalidation handlers trampoline to `@MainActor` via `Task`.

### Auto-reconnect (lazy + transparent)
`remoteProxy()` automatically reconnects if `connection == nil`. This means:
- Helper crashes are recovered on the next call.
- `disconnect()` + `connect()` can be used for deliberate recovery.
- The caller sees `XPCError.connectionInvalid` only if `NSXPCConnection` itself cannot be created.

### `Task.detached` for XPC reply callbacks
The service side (`AgentService`, `ProviderService`) uses `Task.detached` to run the Rust bridge off the main thread. This prevents the helper from blocking its own `RunLoop` while tools execute.

### `XPCError` typed enum
Every XPC failure maps to a stable error code (1000-series for transport, 2000-series for capability, 3000-series for arena, 4000-series for helper). This gives:
- Typed error handling on the Swift side (`catch XPCError.replyTimeout`).
- Human-readable descriptions for logs and UI.
- Stable `NSError` bridging for `NSXPCConnection` reply blocks.

---

## Rust Side — Design Decisions

### Constant-time HMAC verification
`verify()` uses `subtle::ConstantTimeEq` to compare the computed HMAC with the stored signature. This prevents timing attacks even though the helper runs inside its own sandbox.

### Root key isolation via per-subject derivation
`CapabilityGrant::derive_verification_key(root_key, subject)` produces a helper-scoped key using HMAC-SHA256(root_key || subject). Even if a derived key leaks, it is useless for other subjects.

### Postcard serialization
Grants are serialized with `postcard` (compact, `no_std` friendly) before HMAC computation. The same serialization order is used for signing and verification.

### `CapabilityError` typed errors
All failure modes are explicit: `Expired`, `SignatureInvalid`, `SubjectMismatch`, `FlagDenied`, `Serialize`, `MacInit`, `KeyDerivation`.

### 10 inline tests
- `capability_issue_verify_roundtrip`
- `capability_expired_rejected`
- `capability_wrong_key_rejected`
- `capability_tampered_rejected`
- `capability_subject_mismatch_rejected`
- `capability_allows_checks`
- `capability_provider_ids_roundtrip`
- `capability_derive_key_isolation`
- `capability_verify_without_subject_check`
- `capability_max_bytes_roundtrip`

---

## Security Invariants

1. **Root key in Keychain only.** `CapabilityIssuer` fetches the 32-byte root key from the Keychain under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The key is cached in memory for the actor's lifetime but never persisted outside the Keychain.
2. **Helpers never receive the root key.** The app derives per-subject verification keys and passes only those to helpers via the arena or XPC metadata.
3. **Grants are short-lived.** Default TTL is configurable; the test suite verifies 1-second expiry rejection.
4. **Tampered grants fail verification.** Any mutation to `flags`, `subject`, `expires_at_unix`, `vault_ids`, etc. breaks the HMAC signature.
5. **Constant-time comparison.** Signature verification uses `subtle::ConstantTimeEq` to prevent timing side-channels.
6. **Sandboxed helpers.** Both XPC services have `com.apple.security.app-sandbox` = true, `com.apple.security.application-groups` = `group.com.epistemos.shared`, and `com.apple.security.network.client` = true. No user-selected file access, no Keychain access group.

---

## Integration Notes for Existing Code

### `HermesGatewayPolicy` (cloud boundary)

**Current state:** Runs in-process. Routes to Anthropic/OpenAI/Perplexity adapters directly.

**After this slice:** Cloud calls should route through `ProviderServiceClient`:

```swift
// In HermesGatewayPolicy.submitCloudRequest(...)
let client = ProviderServiceClient()
try await client.connect()

// 1. Stage request in arena
let seq = try await arena.submitRequest(slot)

// 2. Issue a capability grant scoped to this provider
let grant = try await capabilityIssuer.issue(
    subject: "provider_xpc",
    flags: [.callProvider],
    vaultIds: [],
    ttlSeconds: 60
)

// 3. Submit via XPC
let providerID = request.provider.rawValue // "anthropic" | "openai" | "perplexity"
try await client.submitProviderRequest(sequence: seq, providerID: providerID)
```

**Sovereign Gate gating (doctrine §4.2):** Before the XPC call, `SovereignGate` should classify the action. `Sensitive+` actions (cloud escalation, export, write) require biometric approval before the request even reaches the helper. The capability grant is issued only after the gate passes.

### `ToolTierBridge` (bounded tools)

**Current state:** Runs in-process. Dispatches to 26 `HermesCommandDispatcher` commands.

**After this slice:** Bounded tool execution routes through `AgentServiceClient`:

```swift
// In ToolTierBridge.executeTool(...)
let client = AgentServiceClient()
try await client.connect()

// 1. Stage tool request in arena with capability grant
let seq = try await arena.submitRequest(toolSlot)

// 2. Submit via XPC
try await client.submit(sequence: seq)
```

**AgentEvent provenance:** Every XPC boundary crossing adds `actor = agent_xpc` or `actor = provider_xpc` to the `AgentEvent.metadata` dictionary. The existing `AgentEvent` persistence (PR39–PR44) already records every tool call — the XPC split only adds the actor label.

### `AgentRuntimeBridge` / `ProviderRuntimeBridge` (UniFFI placeholders)

The Swift placeholder actors (`AgentRuntimeBridge`, `ProviderRuntimeBridge`) document the exact surface area the Rust side must expose:

```rust
// agent_core/src/lib.rs (future UniFFI exports)
#[uniffi::export]
pub fn process_request(sequence: u64) -> Result<(), CoreError>;

#[uniffi::export]
pub fn cancel_request(sequence: u64);

#[uniffi::export]
pub fn process_provider_request(sequence: u64, provider_id: String) -> Result<(), CoreError>;
```

These should be wired to the existing `agent_core::runtime` and `agent_core::providers` modules.

---

## Test Matrix

| Test | Type | Status |
|------|------|--------|
| `capabilityIssueVerifyRoundtrip` | Swift Testing | Pure Swift — runs everywhere |
| `capabilityExpiry` | Swift Testing | Pure Swift — runs everywhere |
| `capabilityTamper` | Swift Testing | Pure Swift — documents Rust-side rejection |
| `capabilityDerivedKeyIsolation` | Swift Testing | Pure Swift — runs everywhere |
| `capabilityProviderIds` | Swift Testing | Pure Swift — runs everywhere |
| `testAgentXPCPing` | Swift Testing | Requires installed AgentXPC helper bundle |
| `testAgentXPCSubmitCancel` | Swift Testing | Requires installed AgentXPC helper bundle |
| `testProviderXPCPing` | Swift Testing | Requires installed ProviderXPC helper bundle |
| `testXPCConnectionRecovery` | Swift Testing | Requires installed AgentXPC helper bundle |
| `capability_issue_verify_roundtrip` | Rust `#[test]` | `cargo test` — runs everywhere |
| `capability_expired_rejected` | Rust `#[test]` | `cargo test` — runs everywhere |
| `capability_wrong_key_rejected` | Rust `#[test]` | `cargo test` — runs everywhere |
| `capability_tampered_rejected` | Rust `#[test]` | `cargo test` — runs everywhere |

---

## Next Steps (post-slice integration)

1. **Wire UniFFI exports** for `AgentRuntimeBridge` and `ProviderRuntimeBridge` placeholders.
2. **Implement arena read/write** on the Rust side (`agent_core/src/arena.rs`) so the helpers can read request slots and write response slots.
3. **Migrate `HermesGatewayPolicy`** to use `ProviderServiceClient` for cloud calls.
4. **Migrate `ToolTierBridge`** to use `AgentServiceClient` for bounded tool execution.
5. **Add Sovereign Gate pre-flight** before XPC submission for `Sensitive+` actions.
6. **Build and embed XPC service bundles** into the app target so smoke tests run in CI.
7. **Add `Info.plist` for XPC services** with `XPCService` dictionary and `ServiceType` = `Application`.

---

## Canonical Source Compliance

| Source | Requirement | Implementation |
|--------|-------------|----------------|
| `hermes.md` | XPC is the right primitive, stateless helpers | AgentXPC + ProviderXPC are `NSXPCListener`-based, no ambient state |
| `hermes.md` | Handles not payloads | Protocol methods pass `sequence: UInt64` only |
| `mac store edition.md` | App Group shared container | Entitlements reference `group.com.epistemos.shared` |
| `mac store edition.md` | HMAC-scoped, time-bounded grants | `CapabilityGrant` with `expires_at_unix` + HMAC-SHA256 |
| `mac store edition.md` | Keychain root key, never handed to helpers | `CapabilityIssuer` + `derive_verification_key` |
| `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §4 | Hermes XPC split is 🔥 YES first | This slice implements the full skeleton |
| `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 | Sovereign Gate action-class matrix | Integration note: gate before XPC for Sensitive+ actions |
| `AGENTS.md` | `@MainActor @Observable`, never `ObservableObject` | Clients are `@MainActor @unchecked Sendable` |
| `AGENTS.md` | `Task { @MainActor in }`, never `DispatchQueue.main.asyncAfter` | Recovery handlers use `Task { @MainActor in }` |
| `AGENTS.md` | Swift Testing (`@Suite` + `@Test` + `#expect`) | `XPCSmokeTests.swift` uses Swift Testing exclusively |
| `AGENTS.md` | `#[repr(C)]` on FFI structs | `CapabilityGrantFfi` is `#[repr(C)]` |
| `AGENTS.md` | `// SAFETY:` on unsafe | One `SAFETY:` comment in `capability.rs` for getrandom fallback |
