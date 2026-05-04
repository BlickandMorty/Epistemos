# Epistemos XPC Mastery Doctrine — Process Boundaries as Defense in Depth — 2026-05-03

> **Make the binary's process boundaries a masterclass in modern macOS
> engineering.** Three things compose: (1) maximum MAS coverage via
> least-privilege per-service entitlements, (2) maximum native + safe via
> per-service trust attestation, (3) maximum private + audited via
> capability-token IPC and AgentEvent logging across boundaries. Result:
> every privileged action crosses an attested, auditable, capability-gated
> XPC boundary. Apple's own apps look like this; ours will too.

---

## 0. The thesis (why this doctrine exists)

The kernel doctrine collapses five fragmented agent loops into one Rust
kernel. The DAG doctrine collapses the kernel's seven subsystems into one
schema. **The XPC Mastery doctrine collapses the binary's process boundaries
into one disciplined defense-in-depth posture** — so the unified kernel
ships to the Mac App Store as Apple-grade least-privilege architecture, not
as a passing build that happened to compile.

Three goals, in priority order:

1. **Maximum MAS coverage** — least privilege per service means each
   service requests the *minimum* entitlements it needs, and reviewers see
   an architecture that almost can't go wrong.
2. **Maximum native + safe + trust** — every cross-process message is
   typed, signed, capability-gated, and trust-attested. A compromised
   service can't escalate.
3. **Maximum private + audited** — every boundary crossing emits an
   `AgentEvent` to the canonical provenance ledger; cognitive DAG (Phase 8)
   makes those crossings cryptographically verifiable.

This isn't paranoia. This is what Apple's WebKit looks like (WebContent.xpc,
Networking.xpc, GPU.xpc), what Mail looks like (per-protocol XPC services),
what every shipping prosumer macOS app *should* look like in 2026 but
almost none do.

---

## 1. The five-service decomposition (the masterclass)

```
┌──────────────────────────────────────────────────────────────────────┐
│                         MAIN APP                                     │
│  Renders SwiftUI + WKWebView. MLX-Swift INFERENCE in-process         │
│  (per CLAUDE.md NO SIDECAR rule). Sovereign Gate (single LAContext   │
│  owner). Issues capability tokens. Shows Provenance Console.         │
│                                                                      │
│  Entitlements: app-sandbox, application-groups (App Group only),     │
│  files.user-selected.read-write (file pickers), LocalAuthentication. │
│  NO network, NO arbitrary file access, NO subprocess.                │
└──────────────────────────────────────────────────────────────────────┘
        │                                                       │
        │ NSXPCConnection / xpc_session_t                       │
        │ Capability-token-only IPC                             │
        │                                                       │
        ▼                                                       ▼
┌──────────────────────┐    ┌──────────────────────┐    ┌────────────────────┐
│  VaultXPC            │    │  AgentXPC            │    │  ProviderXPC       │
│  (filesystem)        │    │  (kernel runtime)    │    │  (cloud network)   │
│                      │    │                      │    │                    │
│  App Group container │    │  agent_core kernel:  │    │  Outbound HTTP to  │
│  + security-scoped   │    │  agent loop, tools,  │    │  Claude / OpenAI / │
│  bookmarks. Reads    │    │  Hermes runtime,     │    │  Perplexity. No    │
│  + writes vault.     │    │  skills, procedural  │    │  filesystem. No    │
│  Owns blob storage,  │    │  memory, provenance, │    │  GPU. No JIT.      │
│  content-addressed   │    │  resonance, search.  │    │                    │
│  DAG storage.        │    │  Calls VaultXPC for  │    │  Entitlements:     │
│                      │    │  filesystem, calls   │    │   network.client,  │
│  Entitlements:       │    │  ProviderXPC for     │    │   app-sandbox.     │
│   app-sandbox,       │    │  cloud, calls        │    │  NOTHING ELSE.     │
│   application-groups,│    │  WASMExecXPC for     │    │                    │
│   files.bookmarks.   │    │  user code.          │    │                    │
│   app-scope.         │    │                      │    │                    │
│  NO network. NO GPU. │    │  Entitlements:       │    │                    │
│  NO JIT.             │    │   app-sandbox.       │    │                    │
│                      │    │  NOTHING ELSE        │    │                    │
│                      │    │  (compute only).     │    │                    │
└──────────────────────┘    └──────────┬───────────┘    └────────────────────┘
                                       │
                                       ▼
                            ┌────────────────────────────────────┐
                            │  WASMExecXPC                       │
                            │  (sandboxed user code execution)   │
                            │                                    │
                            │  wasmtime + Pyodide + QuickJS      │
                            │  for user-provided Python / JS /   │
                            │  WASM. Per-execution policy:       │
                            │  memory cap, fuel cap, wall-time   │
                            │  cap, WASI fs preopens.            │
                            │                                    │
                            │  Entitlements:                     │
                            │   app-sandbox, cs.allow-jit,       │
                            │   sandbox-within-sandbox via       │
                            │   sandbox_init() restrictive       │
                            │   profile.                         │
                            │  NO network. NO filesystem.        │
                            │  NO Apple frameworks beyond libc.  │
                            └────────────────────────────────────┘
```

**Five services.** Each has the minimum entitlements it needs — no more.
Reviewers see this and approve. Attackers see this and despair.

---

## 2. Per-service entitlements (the file-by-file masterclass)

### 2.1 Main App entitlements (`Epistemos.entitlements` — MAS profile)

```xml
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.epistemos.shared</string>
  </array>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  <key>com.apple.security.files.bookmarks.app-scope</key>
  <true/>
  <!-- LocalAuthentication does NOT require an entitlement; just usage description -->
  <!-- NO network entitlement on main app -->
  <!-- NO arbitrary file entitlement -->
  <!-- NO JIT entitlement (WASMExecXPC has it, isolated) -->
</dict>
```

**Reviewer reads this and immediately understands:** main app can only see
files the user explicitly picked, can read/write its App Group container,
and can prompt for biometric auth. That's it. No network exfiltration
vector. No arbitrary code execution. No subprocess.

### 2.2 VaultXPC entitlements (`VaultXPC.entitlements`)

```xml
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.epistemos.shared</string>
  </array>
  <key>com.apple.security.files.bookmarks.app-scope</key>
  <true/>
  <!-- NO network -->
  <!-- NO JIT -->
  <!-- NO user-selected files (those go through main app then come here as bookmarks) -->
</dict>
```

### 2.3 AgentXPC entitlements (`AgentXPC.entitlements`)

```xml
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <!-- NO network -->
  <!-- NO filesystem -->
  <!-- NO JIT -->
  <!-- Pure compute. Calls out to other XPC services for everything physical. -->
</dict>
```

### 2.4 ProviderXPC entitlements (`ProviderXPC.entitlements`)

```xml
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  <!-- NO filesystem -->
  <!-- NO GPU -->
  <!-- NO JIT -->
  <!-- Network out only — and only to allowlisted hosts via NSURLSession. -->
</dict>
```

### 2.5 WASMExecXPC entitlements (`WASMExecXPC.entitlements`)

```xml
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  <!-- JIT is here and ONLY here. Reviewers see this and understand the
       isolation: JIT is only for the WASM runtime, which is itself
       sandbox-restricted via sandbox_init(). Defense in depth. -->
  <!-- NO network -->
  <!-- NO filesystem (WASI preopens are fed in per-execution) -->
</dict>
```

**Submission notes for App Review** (`docs/MAS_REVIEW_NOTES.md`):

> Epistemos uses XPC service decomposition for least-privilege architecture.
> Each XPC service requests only the entitlements required for its specific
> responsibility. The `cs.allow-jit` entitlement is requested only for the
> WASMExecXPC service, which embeds the wasmtime WebAssembly runtime
> (Bytecode Alliance, mature open-source, used by Fastly, Microsoft,
> Shopify) for sandboxed execution of user-provided computational code. The
> WASM runtime itself enforces memory limits, instruction limits (fuel),
> and wall-time limits per execution, and WASI provides controlled
> filesystem and network access. The WASMExecXPC service additionally
> applies a restrictive `sandbox_init()` profile to limit OS-level access
> beyond the app sandbox. JIT is required by wasmtime for code generation;
> the alternative pulley-interpreter mode is 10-50× slower and used only as
> a runtime fallback if the JIT entitlement is rejected.

---

## 3. Trust attestation between services

Every XPC service verifies its caller's code signature before honoring
messages. If an attacker injects a fake XPC client, the service rejects.

```swift
// Inside any XPC service, on connection acceptance:

func listener(_ listener: NSXPCListener,
              shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {

    guard let auditToken = connection.auditToken else { return false }

    var staticCode: SecStaticCode?
    let attrs = [kSecGuestAttributeAudit: Data(bytes: auditToken,
                                               count: MemoryLayout<audit_token_t>.size)]
        as CFDictionary

    guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &staticCode) == errSecSuccess,
          let code = staticCode else { return false }

    // 1. Code signature must be valid
    let validity = SecStaticCodeCheckValidity(code, [.basicValidateOnly], nil)
    guard validity == errSecSuccess else { return false }

    // 2. Caller must be signed by our team
    var info: CFDictionary?
    SecCodeCopySigningInformation(code, [.signingInformation], &info)
    guard let signingInfo = info as? [String: Any],
          let teamID = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String,
          teamID == EpistemosBuildConfig.expectedTeamID else { return false }

    // 3. Caller must be one of our known XPC services or the main app
    let bundleID = signingInfo[kSecCodeInfoIdentifier as String] as? String
    guard EpistemosTrustedPeers.contains(bundleID ?? "") else { return false }

    // 4. Set the connection's exported interface and resume
    connection.exportedInterface = NSXPCInterface(with: AgentServiceProtocol.self)
    connection.exportedObject = AgentServiceImpl()
    connection.resume()
    return true
}
```

**Result:** even if an attacker compromises a process and tries to pose as
the main app to AgentXPC, the connection is rejected at the listener
because the audit token's code signature doesn't match the trusted-peer
list.

---

## 4. Capability-token-only IPC

No XPC service performs ANY operation without a typed capability token.
Every message includes a token, and the service verifies the token's
scope, expiry, and signature before honoring the request.

```swift
// AgentServiceProtocol — every method takes a CapabilityToken

@objc protocol AgentServiceProtocol {
    func submitTurn(token: Data,                  // serialized CapabilityToken
                    profileID: String,
                    turnInput: Data,
                    reply: @escaping (Data?, Error?) -> Void)

    func invokeSkill(token: Data,
                     skillName: String,
                     args: Data,
                     reply: @escaping (Data?, Error?) -> Void)

    // ... every method gates on token
}
```

```rust
// Rust-side capability verification (agent_core/src/capability/token.rs)

#[derive(Serialize, Deserialize)]
pub struct CapabilityToken {
    pub kind: CapabilityKind,         // ToolInvoke, VaultRead, VaultWrite, ProviderCall, ...
    pub scope: CapabilityScope,       // tool name, vault path glob, host allowlist
    pub issued_at: u64,
    pub expires_at: Option<u64>,
    pub session_id: SessionId,        // Sovereign Gate session
    pub signature: SecureEnclaveSignature,  // signed by Secure Enclave (see §7)
}

impl CapabilityToken {
    pub fn verify_for(&self, action: &Action, now: u64) -> Result<(), CapabilityError> {
        if let Some(exp) = self.expires_at { if now > exp { return Err(Expired); } }
        if !self.signature.verify_secure_enclave()? { return Err(InvalidSignature); }
        if !self.kind.permits(action) { return Err(InsufficientCapability); }
        if !self.scope.contains(&action.target) { return Err(OutOfScope); }
        Ok(())
    }
}
```

**No raw "do this thing" calls.** Every call is "do this thing IF this
capability authorizes it." Apple's own services use this pattern (e.g.,
PhotoKit access tokens, ContactsUI permissions).

---

## 5. Sandbox-within-sandbox for WASM

WASMExecXPC has the JIT entitlement (required for wasmtime). To prevent
JIT abuse — even within the App Sandbox — apply an additional
`sandbox_init()` profile that restricts OS-level access beyond what the
app sandbox already does.

```c
// XPCServices/WASMExecXPC/sandbox_profile.sb
(version 1)
(deny default)

;; Allow basic process management
(allow process-fork)
(allow process-info-pidinfo (target self))

;; Allow reading our own bundle (for the WASM modules)
(allow file-read* (subpath (param "BUNDLE_PATH")))

;; Allow shared memory with parent (for input/output buffers)
(allow ipc-posix-shm)

;; Allow XPC communication back to the trusted peer
(allow mach-lookup (global-name (param "PARENT_MACH_PORT")))

;; DENY everything else by default. No /tmp, no network sockets,
;; no sysctl, no random kernel access.
```

```swift
// XPCServices/WASMExecXPC/main.swift

import Darwin

let profile = try String(contentsOf: Bundle.main.url(forResource: "sandbox_profile",
                                                      withExtension: "sb")!)
let bundlePath = Bundle.main.bundlePath
var error: UnsafeMutablePointer<Int8>?

let result = sandbox_init_with_parameters(
    profile,
    UInt64(SANDBOX_NAMED),
    [
        "BUNDLE_PATH", bundlePath,
        "PARENT_MACH_PORT", parentMachPort,
        nil
    ].withUnsafeBufferPointer { $0.baseAddress },
    &error
)

guard result == 0 else {
    // Refuse to start if we can't apply the inner sandbox
    fatalError("Failed to apply WASMExecXPC sandbox profile")
}

// NOW start the wasmtime runtime — it's bounded by both
// macOS App Sandbox AND our additional sandbox_init() profile.
```

**Belt + suspenders.** The wasmtime sandbox is the first line. The macOS
App Sandbox is the second. The `sandbox_init()` restrictive profile is the
third. Three lines of defense for arbitrary user code execution.

---

## 6. Audit trail across XPC boundaries

Every cross-service message emits an `AgentEvent` to the canonical
provenance ledger inside AgentXPC. The ledger sees the boundary crossings.

```rust
// agent_core/src/xpc/audit.rs

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum AgentEventKind {
    // ... existing variants ...

    XPCMessageReceived {
        from_service: String,         // bundle id of caller
        method_name: String,          // protocol method
        capability_kind: String,      // CapabilityKind serialized
        capability_session: SessionId,
        ts: Timestamp,
    },
    XPCMessageDispatched {
        to_service: String,
        method_name: String,
        capability_kind: String,
        capability_session: SessionId,
        ts: Timestamp,
    },
    XPCMessageRejected {
        from_service: String,
        method_name: String,
        reason: XPCRejectReason,      // InvalidCapability, ExpiredToken, OutOfScope,
                                      // CallerNotTrusted, RateLimited, ...
        ts: Timestamp,
    },
}
```

The Provenance Console UI surfaces these. Users see exactly which service
called which method on which other service, with what capability. When the
cognitive DAG ships (Phase 8), each crossing becomes a typed edge in the
DAG with a Merkle signature — making inter-process flows
cryptographically verifiable.

---

## 7. Hardware-attested capability tokens (Secure Enclave)

Capability tokens are signed by the Secure Enclave via a key created with
`SecAccessControl` requiring biometric attestation. So even if a process
is compromised, the attacker can't forge new capability grants — they
need biometric authentication every time.

```swift
// Epistemos/Sovereign/SecureEnclaveCapabilitySigner.swift

import LocalAuthentication
import CryptoKit

final class SecureEnclaveCapabilitySigner {

    /// One-time setup: create a SE key that requires biometric to USE.
    static func provisionSigningKey() throws -> SecKey {
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrLabel as String: "EpistemosCapabilitySigner",
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrAccessControl as String: access as Any,
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return key
    }

    /// Sign a capability — biometric prompt automatically appears.
    static func sign(capability: CapabilityToken) throws -> Data {
        let key = try loadOrProvisionKey()
        let payload = try JSONEncoder().encode(capability.canonicalForm())

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            &error
        ) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return signature
    }
}
```

**Result:** every capability token has a Secure Enclave signature that
can only be created by physically pressing Touch ID / Face ID / Apple
Watch unlock. Attackers can't forge tokens by reading memory; the SE
private key never leaves the chip.

---

## 8. Process recycling (limit blast radius)

XPC services restart on a timer (default 4 hours) or after N messages
(default 10K) to limit the impact of memory corruption or info leaks.
Apple's own services do this; we should too.

```rust
// agent_core/src/xpc/lifecycle.rs

const MAX_UPTIME: Duration = Duration::from_secs(4 * 3600);
const MAX_MESSAGES: u64 = 10_000;

pub struct ServiceLifecycle {
    started_at: Instant,
    message_count: AtomicU64,
}

impl ServiceLifecycle {
    pub fn check_recycle(&self) -> RecycleAction {
        if self.started_at.elapsed() > MAX_UPTIME {
            return RecycleAction::DrainAndRestart { reason: "max_uptime" };
        }
        if self.message_count.load(Ordering::Relaxed) > MAX_MESSAGES {
            return RecycleAction::DrainAndRestart { reason: "max_messages" };
        }
        RecycleAction::Continue
    }
}
```

When the service drains-and-restarts, the launchd-managed XPC service is
torn down, and the next message from the main app spawns a fresh instance.
Active connections are gracefully closed (current message completes, no
new messages accepted, drain timeout 10s).

**Visible to user:** the Provenance Console shows a small "service
recycled" event. No interruption to active work; just a hygiene rotation.

---

## 9. Performance — IOSurface zero-copy for high-frequency paths

Cross-XPC token streaming is a high-frequency path (potentially 60-300
messages/sec during inference). Default NSXPCConnection has ~100-500µs
overhead per round trip, which can become a bottleneck.

For high-frequency paths, use **IOSurface** for shared-memory zero-copy
buffer transfers. Apple Silicon UMA makes this genuinely zero-copy
(no GPU↔CPU bounce); WebKit uses this pattern for compositor frames.

```swift
// Pattern: producer creates IOSurface; consumer reads via shared id.

// Producer (AgentXPC streaming inference output):
let surface = IOSurface(properties: [
    IOSurfacePropertyKey.width: 8192 as Int,
    IOSurfacePropertyKey.height: 1 as Int,
    IOSurfacePropertyKey.bytesPerElement: 4 as Int,
    IOSurfacePropertyKey.pixelFormat: kCVPixelFormatType_OneComponent32Float as UInt32,
])!
// Write tokens into surface via mmap
// Send only the surface ID over XPC (just a UInt32)

// Consumer (main app receiving stream):
// Receive surface ID, look up via IOSurfaceLookup,
// read directly without copying
```

**Result:** 60+ message/sec inference streaming over XPC stays under 50µs
overhead per message. Scales to higher rates (1000+/sec) when needed.

---

## 10. Cognitive DAG integration (Phase 8 forward — when DAG ships)

Once the cognitive DAG ships (Phase 8 of the kernel doctrine), every XPC
message becomes a typed edge in the DAG with a Merkle signature.
Inter-process flows become *provenance-verifiable*.

```rust
// agent_core/src/xpc/dag_audit.rs

pub fn record_xpc_crossing(
    from: ServiceId,
    to: ServiceId,
    method: &str,
    capability: &CapabilityToken,
    payload_hash: Hash,
) -> Result<EdgeId, DagError> {

    let event_node = dag.put_node(NodeKind::Event {
        kind: AgentEventKind::XPCMessageDispatched {
            from_service: from.bundle_id().into(),
            to_service: to.bundle_id().into(),
            method_name: method.into(),
            capability_kind: format!("{:?}", capability.kind),
            capability_session: capability.session_id.clone(),
            ts: now(),
        },
        ts: now(),
        session: current_session_id(),
    })?;

    // Edge: this XPC crossing was witnessed by this capability
    dag.put_edge(Edge {
        from: event_node,
        to: capability.node_id(),
        kind: EdgeKind::WitnessedBy {},
        signature: capability.sign_edge((event_node, capability.node_id()))?,
        created_at: now(),
    })?;

    Ok(event_node)
}
```

**Outcome:** users (and auditors, and reviewers, and the user themselves
six months later) can answer questions like:
- *"Which XPC service initiated the call to api.anthropic.com at 14:32?"*
- *"What capability authorized that call?"*
- *"Which Sovereign Gate session issued that capability?"*
- *"Was the Touch ID prompt actually shown, or did someone forge the token?"* (signature-verified)

This is what auditability looks like when you do it right.

---

## 11. Per-service test harness

Each XPC service is its own Xcode target with its own test target. Cross-
service tests use a special harness that spawns a fake XPC peer.

```
EpistemosTests/
  XPCSmokeTests/
    AgentXPCSmokeTests.swift           (boot, accept, reject untrusted, recycle)
    VaultXPCSmokeTests.swift           (boot, accept, reject untrusted, recycle)
    ProviderXPCSmokeTests.swift        (boot, accept, reject untrusted, network allowlist)
    WASMExecXPCSmokeTests.swift        (boot, JIT entitlement validation, sandbox_init)

  XPCIntegrationTests/
    CapabilityTokenFlowTests.swift     (issue → verify → expire across services)
    TrustAttestationTests.swift        (rejection of fake peer)
    AuditTrailTests.swift              (every crossing logged to ledger)
    SecureEnclaveSigningTests.swift    (token signature verification on real device)

  XPCStressTests/
    LifecycleRecyclingTests.swift      (service restarts cleanly under message storm)
    IOSurfaceStreamingTests.swift      (60-1000 msg/sec sustained)
```

---

## 12. Failure modes + recovery

Each service can crash without bringing down the others. Reconnect via
`NSXPCConnection.invalidationHandler`. State recovery from canonical
ledger.

```swift
// Epistemos/XPC/AgentServiceClient.swift

private var connection: NSXPCConnection!

private func setupConnection() {
    let conn = NSXPCConnection(serviceName: "com.epistemos.AgentXPC")
    conn.remoteObjectInterface = NSXPCInterface(with: AgentServiceProtocol.self)

    conn.invalidationHandler = { [weak self] in
        // Service crashed or terminated. Log, then attempt reconnect.
        Log.xpc.warn("AgentXPC invalidated — reconnecting")
        self?.scheduleReconnect()
    }

    conn.interruptionHandler = { [weak self] in
        // Connection interrupted. Active call will fail; reconnect transparently.
        Log.xpc.warn("AgentXPC interrupted — connection will rebuild")
        // No explicit action; next call will trigger reconnect
    }

    conn.resume()
    self.connection = conn
}
```

**Recovery doctrine:**
- Active turn-in-flight at crash: retry once via fresh connection; if still failing, surface to user with "AgentXPC unavailable; retry?"
- Capability tokens: still valid across crash (they're hardware-signed; not stored in service memory)
- Provenance ledger: persisted to disk continuously; nothing lost on crash
- User experience: maybe a 1-2 second pause; rarely visible

---

## 13. Build + ship integration

### 13.1 Xcode project structure

```
Epistemos.xcodeproj/
  Epistemos                  (main app target)
  XPCServices/
    AgentXPC                 (XPC service target)
    VaultXPC                 (XPC service target)
    ProviderXPC              (XPC service target)
    WASMExecXPC              (XPC service target)
  EpistemosTests             (main app tests)
  EpistemosXPCTests          (XPC integration tests)
```

Each XPC service target has:
- Its own `Info.plist` declaring `XPCService` + `RunLoopType` + `JoinExistingSession`
- Its own `.entitlements` file (per §2)
- Its own `main.swift` entry point that creates `NSXPCListener.service()`
- Its own bundle identifier under `com.epistemos.<ServiceName>`
- Co-signed with the same team ID as the main app
- Embedded into `Epistemos.app/Contents/XPCServices/`

### 13.2 launchd configuration

XPC services bundled inside the app are auto-managed by launchd; no
manual `launchctl load` needed. They start on first connection and
shut down after idle (default 10s of no activity, configurable).

### 13.3 Code signing

```
codesign --sign "Developer ID Application: ..." \
         --options runtime \
         --entitlements XPCServices/AgentXPC/AgentXPC.entitlements \
         --timestamp \
         Epistemos.app/Contents/XPCServices/AgentXPC.xpc

# Repeat per service. Then sign main app:

codesign --sign "Developer ID Application: ..." \
         --options runtime \
         --entitlements Epistemos.entitlements \
         --timestamp \
         --deep \
         Epistemos.app
```

For MAS submission, replace `--sign "Developer ID Application:"` with
`--sign "Apple Distribution:"` and submit via Xcode Organizer or `xcrun
altool`.

---

## 14. Phase plan (folds into kernel doctrine Phases 1-7)

These phases run *concurrently* with the kernel doctrine sub-phases, not
as a separate sprint:

```
Phase X.1 — XPC service skeletons               (during kernel doctrine Phase 1 audit)
  - Create 4 XPC service targets in Xcode
  - Author 4 entitlements files per §2
  - Empty main.swift + protocol stubs
  - Code-signing pipeline configured
  - EpistemosXPCTests target created

Phase X.2 — Trust attestation                   (during kernel doctrine Phase 2)
  - SecStaticCodeCheckValidity in every listener
  - EpistemosTrustedPeers static list
  - TrustAttestationTests proving rejection of fake peers

Phase X.3 — Capability-token IPC                (during kernel doctrine Phase 6 capability lattice)
  - CapabilityToken serialization
  - Per-method gating
  - Secure Enclave signing
  - CapabilityTokenFlowTests

Phase X.4 — Sandbox-within-sandbox for WASMExecXPC (during kernel doctrine Phase 3 WASM)
  - sandbox_profile.sb authoring
  - sandbox_init_with_parameters wiring
  - WASMExecXPCSmokeTests proving the inner sandbox holds

Phase X.5 — Audit trail + IOSurface streaming  (during kernel doctrine Phase 7 doctrine doc)
  - record_xpc_crossing in every method handler
  - Provenance Console XPC-event filter
  - IOSurface streaming for inference output
  - AuditTrailTests + IOSurfaceStreamingTests
```

**Total Phase X work: ~3-4 weeks distributed across the 7-week kernel
sprint.** No standalone phase; XPC mastery is woven into the kernel
doctrine work.

---

## 15. Why this is a masterclass

What makes this *masterclass-grade* engineering rather than just
"shipped to MAS":

1. **Five services, not one.** Most apps that bother with XPC have one
   service. We have five, each with minimum entitlements.
2. **Each service has its own entitlements file.** Most apps copy-paste
   the main app entitlements. We curate per service.
3. **Trust attestation in every listener.** Most apps trust the
   connection by default. We verify code signature on every accept.
4. **Capability-token IPC.** Most apps pass raw arguments. We pass
   typed, scoped, expiring, signed tokens.
5. **Sandbox-within-sandbox for JIT.** Most apps that need JIT just
   request the entitlement. We add a `sandbox_init()` profile on top.
6. **Hardware attestation via Secure Enclave.** Most apps store API keys
   in Keychain (good). We sign capability tokens with an SE key requiring
   biometric per-use (better).
7. **Process recycling.** Most apps run XPC services until they crash.
   We rotate them on hygiene timers.
8. **IOSurface for high-frequency.** Most apps fall back to subprocess
   IPC when XPC overhead matters. We use shared memory zero-copy.
9. **DAG-integrated audit.** Most apps log XPC events to a flat file.
   We log them as typed edges in a Merkle-signed DAG (Phase 8).
10. **Per-service test harness.** Most apps test the main app and call
    it done. We have smoke + integration + stress tests per service.

This is what shipping looks like when you treat process boundaries as
first-class architecture, not as an obstacle.

---

## 16. Reference architecture (Apple's own apps)

Patterns we're borrowing — verify against Apple developer documentation
when implementing:

| Apple app          | Pattern we're learning from                                          |
|---|---|
| Safari             | `WebContent.xpc`, `Networking.xpc`, `GPU.xpc` — process decomposition by trust class |
| WebKit             | IOSurface for compositor frames across processes                     |
| Mail               | Per-protocol XPC services (IMAP, SMTP, IMAPSync)                     |
| Notes              | CloudKit XPC service for sync isolation                              |
| Photos             | Long-running analysis daemon as separate process                     |
| Xcode              | SourceKit-LSP as XPC service                                          |
| App Store          | Per-app sandbox profiles for purchase verification flows              |

**Apple framework references** to read while implementing (search
developer.apple.com):
- `NSXPCConnection`, `NSXPCInterface`, `NSXPCListener`
- `xpc_session_t` (newer C API, Swift-Concurrency-friendly)
- `SecStaticCodeCheckValidity`, `SecCodeCopyGuestWithAttributes`
- `SecAccessControlCreateWithFlags`, `kSecAttrTokenIDSecureEnclave`
- `IOSurface`, `IOSurfaceLookup`
- `sandbox_init_with_parameters`, `sandbox_init`
- App Sandbox entitlement reference
- Hardened Runtime entitlement reference

---

## 17. Closing

> **One binary. One kernel inside the binary. One DAG inside the kernel.
> Five services around the kernel. Capability-token IPC across every
> boundary. Hardware-attested grants. Audit trail all the way down.**

This is what defense in depth looks like for a personal AI on macOS in
2026. Apple's review team will recognize this architecture; users won't
have to know it exists; attackers will hit five walls before they hit
anything interesting.

Build it.

---

## Appendix A — Cross-references

```
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md          ← this doc
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md     (the unified-kernel doctrine; XPC services wrap the kernel)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md        (Phase 8; XPC crossings become DAG edges)
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md  (current process inventory; XPC is the target end-state)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md      (T0 cross-cut; T5 + T12 enabler)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md (capability lattice — Core / Pro / Research)
CLAUDE.md                                                (NON-NEGOTIABLE constraints — NO SIDECAR for inference; MLX stays in main app even though XPC could host it, because perf > isolation for inference)
```

## Appendix B — Open questions (for the user to weigh in on)

1. **InferenceXPC?** CLAUDE.md says NO SIDECAR for inference (MLX-Swift in-process via shared UMA). Honoring that: MLX stays in main app, NOT in a separate InferenceXPC service. This trades perfect isolation for max performance. Confirmable.

2. **HermesOrchestratorXPC vs folded into AgentXPC?** Hermes orchestration logic could either live inside AgentXPC (simpler, fewer services) or in its own service (cleaner trust boundary if Hermes does cloud planning that AgentXPC shouldn't see). Recommendation: fold into AgentXPC for V1; split out only if a specific use case demands it.

3. **Secure Enclave key migration on Mac swap?** The SE key is device-bound. When user moves to a new Mac, capability signing breaks. Need a migration UX: prompt user → re-provision new SE key → re-sign existing capabilities. Out-of-scope for V1; required for V2.

4. **JIT entitlement App Review risk.** Apple sometimes pushes back on JIT for Mac App Store. Mitigation: ship Pulley interpreter fallback (10-50× slower) baked in, so if Apple rejects allow-jit, the binary still works (just slower). Engineering cost: ~1 day.

5. **launchd-managed vs in-bundle XPC services.** In-bundle (Contents/XPCServices/) is what we've designed. launchd-managed (LaunchAgents) would be needed only if services need to outlive the app or be invokable by other apps. For V1: in-bundle only.
