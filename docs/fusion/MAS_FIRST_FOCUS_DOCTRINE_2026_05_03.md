---
state: canon
canon_promoted_on: 2026-05-03
frontmatter_added_on: 2026-05-06
covers: active surface = MAS-shippable only; Pro = feature-gated stubs (cfg pro-build / PRO_BUILD); preserve Pro geometry but do not actively develop
---

# MAS-First Focus Doctrine — Pro Stays In The Plan, Not On The Critical Path — 2026-05-03

> **The user's instruction, verbatim (canonical):**
>
> > "Current focus: Mac App Store build only. Active work goes into the
> > MAS-shippable surface — Hermes XPC bridge, sandboxed extensions,
> > biometric stack, FoundationModels, MLX inference, the cognitive
> > substrate. The Pro/Developer-ID build is part of the long-term plan
> > but on hold; do not actively develop, test, or sign Pro-only
> > components right now.
> >
> > That said — keep the architecture Pro-ready. Cargo features
> > (mas-build, pro-build) stay in the workspace. Xcode configurations
> > (Release-MAS, Release-Pro) stay defined. Entitlement files stay
> > split per build. System extension targets exist in the project but
> > are excluded from the active scheme and not compiled. Endpoint
> > Security, NEAppProxy, and Authorization Plugin code paths exist as
> > feature-gated stubs with detailed comments describing what they'll
> > do when activated. Anything Pro-build-specific gets `#if PRO_BUILD`
> > or `#[cfg(feature = "pro-build")]` so it's invisible to MAS
> > compilation but trivial to flip on later.
> >
> > The architectural cost of keeping the Pro option open is near-zero
> > if we do it from day one. The cost of refactoring later if we don't
> > is enormous. So we keep the geometry, we just don't ship the second
> > binary yet."
>
> **The phrase to use:** *"Part of the plan, not on the critical path."*

---

## 0. Why this doctrine is canon

There's a real difference between "we're not building this now" and "we've
decided not to build this." This doctrine pins the difference in writing so
no agent (Codex, Claude, Kimi, Gemini, GPT) wastes cycles on Pro work
during MAS-first sprint, AND no agent silently ditches the Pro architecture
during a refactor.

Optionality preserved. Focus maintained. No premature optimization. No
architectural debt accumulating.

---

## 1. The active surface (what every agent works on)

| Surface                      | Active in MAS-first sprint? | Notes |
|---|---|---|
| Hermes XPC bridge (in-process) | **YES**       | Hermes Expert Mode landing surface; AgentXPC + ProviderXPC; the Hermes-in-Rust kernel module (kernel doctrine Phase 2) |
| Hermes Expert Mode            | **YES**       | Slices 1-8 + A shipped 2026-05-03; refinement continues |
| Sandboxed XPC services        | **YES**       | AgentXPC, VaultXPC, ProviderXPC, WASMExecXPC per XPC Mastery Doctrine §1 (5-service decomposition) |
| Biometric / Sovereign Gate    | **YES**       | LocalAuthentication, Secure Enclave, capability tokens |
| Apple FoundationModels        | **YES**       | Apple Intelligence integration via the `apple_intelligence` provider variant |
| MLX-Swift inference           | **YES**       | In-process per CLAUDE.md NO SIDECAR rule |
| Cognitive substrate           | **YES**       | T0 sub-tracks: Cognitive Kernel, Cognitive DAG, XPC Mastery, Schema-First GenUI |
| Simulation Mode v1.6 / Farm   | **YES**       | T6 hackathon Block B; all MAS-eligible (no subprocess) |
| Companion creation/delete/restore | **YES**   | Routes through canonical Sovereign Gate |
| Provenance Console            | **YES**       | Closes MAS feature trio |
| Resonance Gate                | **YES**       | Already shipped; mounting into production surface deferred |
| Halo / Contextual Shadows     | **YES**       | Already shipped |
| Vault Index / RRF Fusion      | **YES**       | Already shipped |

## 2. The deferred surface (PART OF THE PLAN — NOT ON THE CRITICAL PATH)

| Pro-only surface                | Status               | Why deferred                                            |
|---|---|---|
| Endpoint Security extension     | feature-gated stub   | System extension; requires Developer ID + notarization  |
| NetworkExtension (NEAppProxy)   | feature-gated stub   | System extension; same                                  |
| Authorization Plugin            | feature-gated stub   | Plugin bundle; same                                     |
| Native CLI passthrough (claude/codex/gemini/kimi) | feature-gated stub | Subprocess — App Sandbox forbids        |
| Native shell / Docker           | feature-gated stub   | Subprocess                                              |
| Native Python / Node subprocess | feature-gated stub   | Subprocess (WASM via wasmtime is the MAS path)          |
| External user-installed MCP servers | feature-gated stub | Subprocess (bundled MCPs run in-process)              |
| iMessage osascript bridge       | feature-gated stub   | Subprocess                                              |
| Long-horizon untrusted automation| feature-gated stub  | Sandbox would block real-world autonomy                  |
| `/run`, `/shell`, `/kill`, `/execute` Hermes commands | feature-gated stub | Match the surfaces above |

These remain in the canon. They appear in `HermesCapabilityRegistry.all`
with `tier: .pro`. They're listed in `PRO_TO_CORE_MIGRATION_2026_05_03.md`
(Phase 5 deliverable of kernel doctrine). They WILL ship — just not now.

---

## 3. The build-flag pattern (mandatory for every Pro-only file)

### 3.1 Rust — Cargo features

Every Pro-only crate / module / function / struct guards on
`#[cfg(feature = "pro-build")]`:

```rust
// agent_core/Cargo.toml

[features]
default = ["mas-build"]
mas-build = []
pro-build = []
research = []  # T14 / T15 — separate, gated independently

# Pro-only feature dependencies — empty for MAS, populated for Pro
[target.'cfg(feature = "pro-build")'.dependencies]
# example: nix = "0.27"  # POSIX subprocess primitives Pro-only
```

```rust
// Inside any Pro-only file (e.g., agent_core/src/tools/cli_passthrough.rs)

#[cfg(feature = "pro-build")]
pub fn passthrough_cli(binary: &str, args: &[String]) -> Result<...> {
    // PRO_BUILD: spawn external CLI binary. App Sandbox forbids this
    // on MAS. When pro-build feature is active, this routes through
    // harden_cli_subprocess and emits AgentEvent provenance.
    todo!("Activate when pro-build feature flag is set")
}

#[cfg(not(feature = "pro-build"))]
pub fn passthrough_cli(_binary: &str, _args: &[String]) -> Result<...> {
    Err(AgentError::FeatureGated("cli_passthrough requires pro-build feature"))
}
```

**Build commands:**
```bash
# MAS build — what every agent runs by default
cargo build --no-default-features --features mas-build

# Pro build — only when explicitly testing Pro path
cargo build --no-default-features --features pro-build

# Verification gate (CI must run BOTH)
cargo build --no-default-features --features mas-build --tests
cargo test  --no-default-features --features mas-build
```

### 3.2 Swift — `#if PRO_BUILD` blocks

Pro-only Swift code lives behind compiler conditionals:

```swift
// Epistemos/Pro/EndpointSecurityClient.swift (NEW — placeholder)

#if PRO_BUILD
import EndpointSecurity

/// Tamper-detection client. PRO_BUILD only — App Sandbox doesn't permit
/// the EndpointSecurity client entitlement; this code is invisible to
/// the MAS compiler.
///
/// When activated, this becomes the audited tamper detector for
/// Sovereign Gate operations. Watches:
/// - process forks within the app's own process tree
/// - mount points changing under the vault path
/// - kext loads on the host
final class EndpointSecurityClient {
    func startWatching() async throws {
        // Activate when PRO_BUILD ships.
    }
}
#endif
```

`PRO_BUILD` lives in the Pro Xcode configuration's Swift compiler flags
(`OTHER_SWIFT_FLAGS = -DPRO_BUILD`). The MAS configuration omits it. The
MAS compiler literally never sees the contents of `#if PRO_BUILD` blocks.

### 3.3 Xcode configurations

Two configurations exist, both kept in `project.pbxproj`:

- **Release-MAS** — App Sandbox + Hardened Runtime + `Apple Distribution:`
  signing identity. Default for `Epistemos-AppStore` scheme.
- **Release-Pro** — Hardened Runtime + `Developer ID Application:`
  signing identity. Default for the (deferred) `Epistemos-Pro` scheme.

System extension targets (Endpoint Security extension, NEAppProxy
extension, Auth Plugin) exist in `project.pbxproj` but are **unchecked
in the MAS scheme's Build action**. They're scaffolding, not artifacts.

### 3.4 Entitlements files

Two files, both checked in:

- `Epistemos-AppStore.entitlements` — minimum entitlements for MAS
- `Epistemos-Pro.entitlements` — broader entitlements for Pro
  (system extension client, file access, etc.)

The two files NEVER merge. They're independent surfaces; if a new
capability is needed, it gets added to whichever file's profile
authorizes it (often only the Pro file).

---

## 4. The agent instruction (paste verbatim into Codex / handoff prompts)

```
Active focus: Mac App Store build only.

DO actively develop:
- Hermes XPC bridge (in-process) and Hermes Expert Mode
- AgentXPC, VaultXPC, ProviderXPC, WASMExecXPC services
- Sovereign Gate biometric / Secure Enclave / capability tokens
- Apple FoundationModels integration
- MLX-Swift in-process inference
- Cognitive substrate (T0: Kernel + DAG + XPC Mastery + GenUI)
- Simulation Mode v1.6 / Companion Farm
- Provenance Console
- Vault, Halo, Resonance Gate refinements

DO NOT actively develop:
- Endpoint Security extension
- NEAppProxy / NetworkExtension
- Authorization Plugin
- Native CLI passthrough (claude/codex/gemini/kimi)
- Native shell, Docker, native Python/Node subprocess
- External user-installed MCP servers (bundled MCPs OK)
- iMessage osascript bridge
- /run, /shell, /kill, /execute Hermes commands

The deferred surfaces are PART OF THE PLAN, NOT ON THE CRITICAL PATH.
Keep them as feature-gated stubs with detailed comments describing
what they'll do when activated:
- Rust: cfg(feature = "pro-build") blocks
- Swift: #if PRO_BUILD blocks
- Xcode targets: exist in project.pbxproj, unchecked in MAS scheme
- Entitlements: Epistemos-Pro.entitlements lives next to
  Epistemos-AppStore.entitlements; do not merge

When you encounter a Pro-only surface, do not delete it, do not
refactor it away, do not "clean it up." Add the gate, add the
comment, leave the geometry. The cost of preserving optionality
is near-zero; the cost of recovering it is enormous.

Verification: every build must pass with
  cargo build --no-default-features --features mas-build
  xcodebuild -scheme Epistemos-AppStore build
```

---

## 4.5 Free-Tier Build Adaptations (TEMP-FREE-TIER, 2026-05-03)

**The user's current signing certificate is a free Personal Team** (no
paid $99/yr Apple Developer Program membership yet). Free Personal
Teams can build, run, and debug locally indefinitely — they CANNOT
generate provisioning profiles for App Groups, push notifications,
CloudKit, or anything that requires Apple Developer Portal
registration.

To unblock local development NOW, two surgical adaptations are made
under explicit `TEMP-FREE-TIER` markers. Each adaptation is fully
documented in the file it touches with restoration steps.

### 4.5.1 App Groups removed from `Epistemos-AppStore.entitlements`

| What | Why | Impact | Restoration |
|---|---|---|---|
| `com.apple.security.application-groups` block removed | Free tier can't generate provisioning profiles for App Groups | Main app + bundled XPC services cannot share a filesystem container; the data path between processes MUST be XPC messages (not shared `/Library/Group Containers/group.com.epistemos.shared/` files) | When paid Developer Team available: register App Group at developer.apple.com → update Xcode signing → restore the block per the file header comment → verify XPC services work |

**This is actually a more secure architecture.** Per the advice that
prompted this adaptation, "the XPC boundary becomes the only data path"
— exactly what the XPC Mastery Doctrine §1.4 prescribes
(capability-token-only IPC). The App Group is operational convenience
for the future paid build; living without it forces the architectural
discipline we want anyway.

### 4.5.2 XPC services design under TEMP-FREE-TIER

Every Hermes XPC service authored during the MAS-first sprint MUST:

- **Pass data via XPC messages, not shared container files.** Even when
  paid Developer Team is restored, this stays as the canonical path —
  shared container is fallback for high-frequency / high-volume cases
  only (per IOSurface zero-copy pattern in XPC Mastery Doctrine §9).
- **Persist into the main app's container, not the App Group container.**
  The vault directory resolved by `URL.applicationSupportDirectory`
  (sandbox-scoped, single-app) is the active path.
- **NOT call `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
  in any active code path.** If a future surface needs that API, gate
  it behind a runtime check + fall back to per-process container,
  with a clear `TEMP-FREE-TIER` comment.

### 4.5.3 The marker discipline

Every `TEMP-FREE-TIER` change MUST include:

1. A `TEMP-FREE-TIER YYYY-MM-DD:` comment in the file at the change site
2. Restoration steps in the file's header comment block (entitlements,
   plists) OR inline (code files)
3. A row in this §4.5 table noting what + why + impact + restoration

When paid Developer Team is added:
- `grep -rn 'TEMP-FREE-TIER'` returns the full restoration list
- Each row in §4.5 is restored
- This §4.5 section gets a "RESTORED YYYY-MM-DD" header line; left as
  historical context for future free-tier developers / forks

### 4.5.4 What's NOT being removed (still works on free tier)

- App Sandbox itself (`com.apple.security.app-sandbox`)
- Hardened Runtime (`com.apple.security.cs.*`)
- Network client (`com.apple.security.network.client`)
- File bookmarks (`com.apple.security.files.bookmarks.app-scope`)
- User-selected file access (`com.apple.security.files.user-selected.read-write`)
- JIT entitlement (`com.apple.security.cs.allow-jit` — needed for
  wasmtime; works on free tier)
- LocalAuthentication / Sovereign Gate (no entitlement needed)
- All Apple frameworks (MLX-Swift, FoundationModels, ScreenCaptureKit,
  etc.) — work on free tier

The substrate-foundational work (T0 sub-tracks 1-4, T5 Hermes XPC
in-process bridge, T6 Simulation v1.6) all proceed unaffected.

---

## 5. The hardening cycle (what NOT to confuse this with)

The MAS-first focus does NOT mean:

- Pro architecture is "removed" — it stays in the geometry
- Pro is "abandoned" — it's planned for a later release
- Pro tests are "deleted" — they're skipped under `#[cfg(not(feature = "pro-build"))]`
- Pro entitlements are "stripped" — they live in their own file
- Pro Hermes commands are "removed from registry" — they stay tagged `tier: .pro`

The MAS-first focus DOES mean:

- The default `cargo build` and the default `xcodebuild` produce a MAS binary
- CI runs MAS-only tests; Pro tests run only when explicitly requested
- Code review priority is MAS surface; Pro changes are batched / deferred
- Documentation effort prioritizes MAS surface; Pro doc updates batch

---

## 6. The discipline (so this doesn't drift)

Every PR that touches the project must declare:
- **MAS impact:** what changes for the AppStore build
- **Pro impact:** what changes for the (deferred) Pro build (often "no
  change — gated as before")
- **Optionality preserved:** confirms `#[cfg]` / `#if PRO_BUILD` gates
  intact for any touched Pro-only surface

Any PR that wants to remove Pro-only code MUST get an explicit user
sign-off ("yes, decommission this Pro feature") rather than a quiet
delete. The default answer is "leave the gated stub."

---

## 7. The single sentence

> **Active work is MAS-shippable; Pro stays in the plan as feature-gated
> stubs; the architectural cost of keeping Pro optional is near-zero if
> we do it from day one and enormous if we refactor it back in later.**

The phrase: ***Part of the plan, not on the critical path.***

---

## 8. Cross-references

```
docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md      ← this doc (canon)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md  (capability lattice)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md      (T0 sub-track 1)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md         (T0 sub-track 2)
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md           (T0 sub-track 3)
docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md       (T0 sub-track 4)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md       (full track register)
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md   (current runtime inventory)
project_deployment_profiles                              (memory: AppStore vs Pro split)
project_app_store_first_sequencing                       (memory: MAS-First Phase S sequencing)
CLAUDE.md                                                (NON-NEGOTIABLE constraints)
```

This doctrine is the authoritative answer to "should I work on this Pro
thing now?" The answer is **no** — but the geometry stays.
