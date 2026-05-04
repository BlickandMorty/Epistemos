# XPC Research Intake — No-Compromise MAS / Pro Trust Spine

> Source-first pointer for the user's latest XPC research. This doc does not
> replace `XPC_MASTERY_DOCTRINE_2026_05_03.md`; it sharpens the canonical
> implementation requirements and records platform nuances that future briefs must not
> lose.

## Source

- Primary local source:
  `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/XPC.md`
- User-pasted expanded research in the 2026-05-04 Codex thread:
  "Epistemos Sandbox-Depth Audit: The XPC, Sandbox, ExtensionKit,
  System-Extensions, and Biometrics Synthesis for a MAS-First /
  Pro-Notarized Dual Build"
- Official validation pass, 2026-05-04:
  Apple `NSXPCConnection.setCodeSigningRequirement(_:)`,
  Apple App Groups entitlement docs, Apple app group container docs, and Apple
  Endpoint Security / System Extensions docs.

## Canonical Adoption

### 1. Trust spine first

Every future XPC implementation brief starts with the trust spine:

- bundled in-app XPC service under `Contents/XPCServices/`
- `NSXPCConnection` for the current implementation unless a brief deliberately adopts `XPCSession`
- `setCodeSigningRequirement(_:)` before `resume()` on both app-to-service and
  service-to-app callback connections
- `NSXPCInterface.setClasses` whitelists for every nontrivial payload
- no trust decision based on `processIdentifier`
- no temporary App Sandbox exception unless the brief explicitly proves there
  is no MAS-safe alternative

This is the concrete "build the geometry first" rule. Cognition can be moved;
the trust spine is expensive to retrofit.

### 1.1 No date gates, no compromise semantics

This intake is not a May 4 time-box, V1 shortcut, or "do less now" permission.
Implementation may be sliced for reviewability, but slices must preserve the
final trust geometry:

- the five-service end-state remains the canonical target
- temporary physical co-location does not erase named service contracts
- any reduced local/debug path must be marked as signing/build accommodation,
  never doctrine
- Pro-only capability work may be build-gated out of MAS, but the MAS build does
  not receive weaker peer validation, payload validation, provenance, or key
  handling

### 2. Hermes is a boundary, not a second brain

Hermes / ProviderXPC owns cloud/provider/tool chaos. Epistemos owns memory,
permissions, provenance, planning, truth routing, and local substrate state.
XPC briefs must preserve this split:

- Main app / in-process Rust: vault, local memory, Resonance Gate, Sovereign
  Gate, MLX / FoundationModels-style local cognition where applicable.
- Hermes / ProviderXPC: network client, provider adapters, cloud escalation,
  pass-through execution with structured provenance back to Epistemos.

### 3. App Group naming is a two-path decision, not a slogan

The pasted research emphasizes `<TEAMID>.<name>` identifiers. Current Apple
docs say `group.<name>` is the recommended provisioned format on macOS, and
`<TEAMID>.<name>` is also supported on macOS with limitations. Therefore future
briefs must declare which path they use:

- `group.<name>`: provisioned App Group, Developer portal/profile coordinated.
- `<TEAMID>.<name>`: macOS-only unprovisioned form, useful for some notarized
  workflows, but not a replacement for provisioned App Groups where profiles
  and keychain sharing need to line up.

Current repo state has a local-build accommodation: direct/debug builds avoid
App Group entitlements until signing profiles are coordinated. That is not a
doctrine exception. MAS / Pro implementation must restore the chosen App Group
path with matching provisioning, signing, and built-entitlement verification.

### 4. MAS and Pro are compile-time separated

MAS may include bundled XPC services, App Intents, Spotlight / metadata
surfaces, Quick Look, Credential Provider, FileProvider-style extension work
where appropriate, smart-card/authentication services, and App Group sharing.

Pro-only surfaces include Endpoint Security, Network Extension system
extensions / NEAppProxy, Authorization Plugin experiments, and any daemon/root
helper path. Future code must keep those symbols behind the existing
capability lattice and build flags so App Review never sees Pro-only surfaces
in the MAS build.

### 5. Secure Enclave + biometric nuance carries forward

Sovereign / vault briefs must preserve the flag-level nuance:

- default vault-class key material is device-bound and non-syncing
- `.privateKeyUsage` is mandatory for Secure Enclave signing/key use
- `.biometryCurrentSet` is the high-security default because enrollment
  changes invalidate access
- Apple Watch / companion auth is an explicit relaxed-mode alternative, not
  a silent replacement
- `evaluatedPolicyDomainState` drift is a vault-lock / rekey signal

### 6. Zero-copy XPC is staged

The doctrine's zero-copy direction remains correct, but staged:

- control plane first: typed `Data` / Codable / FlatBuffer-ish payloads, bounded
  and whitelisted
- high-frequency streaming later: coalescing first, then shared memory /
  IOSurface only where profiling proves XPC serialization is the bottleneck
- no hot-path tensor copies; no inference sidecar unless a later brief
  explicitly overturns the `NO SIDECAR` rule with profiling evidence

### 7. ExtensionKit and App Intents are part of the XPC surface

Future native integration briefs must consider App Intents, Spotlight /
metadata import, Quick Look, Credential Provider, FileProvider, and menu/status
surfaces as clients of the same trust spine, not ad hoc side channels. If an
extension needs data, it crosses the same capability-gated XPC / App Group
boundary and emits provenance.

## Future Brief Checklist

Every XPC/Hermes/native-integration brief must answer:

1. Which distribution tier is this: Core MAS, Pro notarized, Research, or both?
2. Which process owns the capability, and which process merely requests it?
3. Does every peer validate code signing before `resume()`?
4. Does the payload interface whitelist classes / schemas and cap size?
5. Are App Group identifiers and signing profiles coordinated?
6. Are Pro-only ES/NE/AuthPlugin symbols impossible to ship in MAS?
7. Are network calls impossible from the main app unless deliberately allowed?
8. Does every boundary crossing emit or preserve `AgentEvent` provenance?

## Usefulness

usefulness: +1

This intake changes future XPC/Hermes briefs by adding exact trust-spine,
App Group, MAS/Pro, and biometric requirements before code is authorized.
