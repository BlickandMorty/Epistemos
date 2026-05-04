# EPISTEMOS: NO-COMPROMISE UNIFIED ARCHITECTURE
## Every Research Feature Ships — Apple Entitlement & Distribution Strategy

**Date**: 2026-05-02 | **Architecture Version**: 3.0 No-Compromise
**Distribution Model**: Tiered Release — Core (MAS) + Pro (Developer ID) + Research (Developer ID + Private Frameworks)
**Total Workspace**: 6 crates, 3,832 tests, 5 worktrees

---

# THE NO-COMPROMISE MANIFESTO

## The Principle

**Every research feature ships.** The ternary substrate. The spectral memory. The direct ANE manipulation. The embedded JS runtime. The unified single-binary in-process substrate. All of it. Nothing is deferred to "maybe someday." The only question is **which tier** it ships in, and **which distribution method** makes it legal.

Claude's fusion docs said: "Core/App Store first, future tracks after proof."

This document says: **"Core/App Store AND Pro/Developer ID AND Research/Developer ID — parallel tracks, tier-gated, all shipping."**

The App Store is not the only distribution method. It is the **most restrictive** distribution method. For a cognitive operating system that needs direct hardware access, subprocess freedom, and embedded execution, the App Store is the wrong target for the advanced tiers.

---

# PART I: THE THREE-TIER REALITY

## Tier Definitions (Revised for No-Compromise)

| Tier | Distribution | Runtime | Entitlements | What Ships |
|------|-------------|---------|--------------|-----------|
| **Core** | App Store + TestFlight | Sandboxed, public APIs only | Standard sandbox + file access | Local-first vault intelligence, typed artifacts, provenance, basic tools |
| **Pro** | Developer ID + Notarization (direct download) | **Not sandboxed**, full macOS access | Hardened Runtime + `disable-library-validation` + custom | All Core + Hermes CLI, MCP tunnels, browser tools, computer-use, Docker, embedded JS runtime, subprocess freedom |
| **Research** | Developer ID + Notarization (direct download) | Not sandboxed, private framework loading | Same as Pro + dynamic private framework loading | All Pro + direct ANE access (`_ANEClient`), activation steering, KV snapshots, neural-kernel, sparse KV textures, SSM/hybrid models |

**The user-facing pitch**: "Epistemos Core is free on the App Store. Epistemos Pro unlocks the full capability surface. Epistemos Research is the bleeding edge — same app, same binary, gated by tier."

---

# PART II: APPLE DISTRIBUTION METHODS — THE COMPLETE MATRIX

## What You Actually Need to Know

Apple has **six** distribution methods. Most developers only know two (App Store, TestFlight). You need to know all six:

| Method | Sandbox? | Review? | Private APIs? | JS Runtime? | Subprocess? | Best For |
|--------|----------|---------|---------------|-------------|-------------|----------|
| **App Store** | Yes | Full App Review | No | No (if it downloads code) | No (hardened runtime blocks) | Core tier only |
| **TestFlight** | Yes | Beta Review (first build) | No | No | No | Beta testing Core |
| **Developer ID + Notarization** | **No** | Automated malware scan only | **Yes** (with `disable-library-validation`) | **Yes** | **Yes** | **Pro + Research tiers** |
| **Enterprise Program** | Optional | None | Yes | Yes | Yes | Internal employees only (not customers) |
| **Ad Hoc** | Optional | None | Yes | Yes | Yes | 100 devices max, QA testing |
| **Copy App (unsigned)** | No | None | Yes | Yes | Yes | Development only |

## The Critical Discovery: Developer ID + Notarization

**This is the path for Pro and Research.**

Notarization is NOT App Review. It is an **automated malware scan** that takes minutes, not days. It checks for:
- Known malware signatures
- Code signing validity
- Hardened Runtime enforcement

It does NOT check:
- Whether you use private APIs
- Whether you embed a JS runtime
- Whether you spawn subprocesses
- Whether you load private frameworks

**This is how Chromium ships.** Chromium uses:
- `com.apple.security.cs.allow-jit`
- `com.apple.security.cs.allow-unsigned-executable-memory`
- `com.apple.security.cs.disable-library-validation`

And it is notarized and distributed outside the App Store.

**This is how you ship Pro and Research.**

---

# PART III: THE ENTITLEMENT STRATEGY

## What Entitlements Exist

Apple entitlements fall into three classes:

| Class | Who Can Use | Examples |
|-------|-------------|----------|
| **Public** | Any developer | `com.apple.security.app-sandbox`, file access, camera, microphone |
| **Restricted** | Requires Apple approval | iCloud, push notifications, HomeKit, HealthKit |
| **Private (`com.apple.private`)** | **Apple-only** | ANE direct access, TCC manager, APFS snapshots |

**The hard truth**: Apple will NOT grant `com.apple.private` entitlements to third-party developers. Not via request. Not via special relationship. Not via Enterprise program. They are baked into Apple's own app signatures.

**But**: You do NOT need a private entitlement to load a private framework. You need `com.apple.security.cs.disable-library-validation`.

## The Pro/Research Entitlement Bundle

```xml
<!-- Pro Tier: Developer ID + Notarization -->
<key>com.apple.security.cs.allow-jit</key>
<true/>  <!-- Required for embedded JS runtime (Deno/QuickJS) -->

<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>  <!-- Required for JIT compilation of user scripts -->

<key>com.apple.security.cs.disable-library-validation</key>
<true/>  <!-- Required to load private frameworks (AppleNeuralEngine, etc.) -->

<key>com.apple.security.automation.apple-events</key>
<true/>  <!-- AppleScript/Apple Events for tool automation -->

<key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
<array>
    <string>/</string>  <!-- Full filesystem access for vault storage -->
</array>

<key>com.apple.security.internet-client</key>
<true/>  <!-- Network access for MCP tunnels, model downloads -->

<!-- NOT included (because not sandboxed): -->
<!-- com.apple.security.app-sandbox -->
```

**Why this works**: Developer ID apps are NOT required to be sandboxed. The Hardened Runtime still applies (it prevents code injection, protects memory), but with the above entitlements, the app can:
- Load any framework dynamically (including private ones)
- JIT-compile code (for embedded JS runtime)
- Access the full filesystem
- Spawn subprocesses freely
- Use the network without restriction

## The ANE Access Path (Research Tier)

Direct ANE access via `_ANEClient` does NOT require a private entitlement. It requires:

1. **Loading `AppleNeuralEngine.framework` dynamically** via `dlopen` or `NSBundle`
2. **Method swizzling or direct message sending** to `_ANEClient`, `_ANECompiler`, `_ANEInMemoryModelDescriptor`
3. **MIL compilation** (Machine Learning Intermediate Language) to E5 binaries
4. **IOSurface-based zero-copy I/O** between GPU and ANE

This is exactly how the M4 ANE training project worked (March 2026). The research paper states:

> "Class discovery via `dyld_info -objc` on `AppleNeuralEngine.framework` dumps every Objective-C class and method... Method swizzling intercepts CoreML's calls to private ANE frameworks... CoreML is just a convenience layer on top."

**The entitlement that enables this**: `com.apple.security.cs.disable-library-validation`

Without it, Hardened Runtime blocks loading of non-system frameworks that aren't signed by Apple. With it, you can load `AppleNeuralEngine.framework` and any other private framework.

---

# PART IV: THE SINGLE-BINARY IN-PROCESS SUBSTRATE

## The Vision: Unified Binary, No Subprocesses

Your instinct is correct. The Quick Capture worktree achieved "capture in-process via UniFFI, no subprocess, no IPC daemon, just a UniFFI hop into the same process address space." This should be the **default mode** for the entire substrate.

### What "Single Binary" Actually Means

| Aspect | Current State (Multi-Crate) | Target State (Unified) |
|--------|------------------------------|------------------------|
| **Build artifact** | 6 separate crates compiled separately | One `epistemos` binary with all crates linked |
| **Process model** | Swift app + Rust dylib + possible subprocesses | One process, all logic in-process |
| **JS runtime** | None (or external Node/Deno process) | Embedded QuickJS or Deno embedded in Rust |
| **ANE access** | Via CoreML (public API only) | Direct `_ANEClient` (private framework) |
| **Tool execution** | Subprocess for bash, browser, etc. | In-process where possible, subprocess only for isolation |
| **Memory model** | Copying across FFI boundaries | Zero-copy via UMA (CPU/GPU/ANE share memory) |

### The Embedding Strategy

**For JS Runtime**:
- `quickjs-rs` or `rusty_v8` crate embeds a JS engine directly in the Rust binary
- No separate Node/Deno process needed
- User scripts run in-process, sandboxed by the JS engine's own isolation
- TypeScript compilation happens in-process via SWC or esbuild-wasm

**For ANE**:
- Private framework loaded dynamically at runtime (not linked at build time)
- Detection: if `AppleNeuralEngine.framework` exists and `disable-library-validation` is set, enable ANE path
- Fallback: CoreML public API if ANE path unavailable

**For Browser**:
- WebView (WKWebView) stays in-process — it already uses its own WKContent process internally
- Obscura headless browser (if used) also in-process via shared library
- No separate browser process spawned

### The Tier-Gated Build

The same codebase compiles to three targets:

```rust
// Build-time feature flags
#[cfg(feature = "core")]      // App Store target
#[cfg(feature = "pro")]       // Developer ID target  
#[cfg(feature = "research")]  // Developer ID + private frameworks target

// Runtime detection
fn ane_available() -> bool {
    #[cfg(feature = "research")]
    return unsafe { AppleNeuralEngine::is_loaded() };
    #[cfg(not(feature = "research"))]
    return false;
}
```

**One binary, three compile targets.** The user downloads Pro from your website. The binary detects its own capabilities at runtime based on what's available on the system.

---

# PART V: THE REVISED WAVE PLAN — NO COMPROMISES

## The New Build Order

| Wave | What | Tier | Distribution | Weeks |
|------|------|------|------------|-------|
| 0 | **Worktree reconciliation** — port v2 tools, AgentEvent variants, multi-vault UI | All | N/A | 1 |
| 1 | **Ternary substrate + ClaimKernel** — `Trit`, K3 logic, `ClaimGraph`, `ResonanceScore` | All | N/A | 1 |
| 2 | **Agent Runtime V1** — multi-turn loop, tool harness, Swift UI integration | Core+Pro+Research | App Store + Developer ID | 2 |
| 3 | **Context Governor** — hybrid retrieval, provenance tracking, context assembly | Core+Pro+Research | App Store + Developer ID | 2 |
| 4 | **Pro tier unlock** — Developer ID build, entitlements, Hermes CLI, MCP tunnels, browser tools | Pro+Research | Developer ID only | 2 |
| 5 | **Embedded JS runtime** — QuickJS/Deno in-process, TypeScript compilation, script sandboxing | Pro+Research | Developer ID only | 2 |
| 6 | **Single-binary unification** — Link all crates into one binary, eliminate subprocess boundaries | Pro+Research | Developer ID only | 2 |
| 7 | **Direct ANE access** — `_ANEClient` loading, MIL compilation, E5 binaries, IOSurface I/O | Research | Developer ID only | 3 |
| 8 | **Spectral orchestration** — Metal Laplacian kernels, Koopman predictor, golden scheduler | Research | Developer ID only | 2 |
| 9 | **Meta-cognitive layer** — Viable System Model recursion, self-referencer, homeostasis | Research | Developer ID only | 2 |
| 10 | **Polish + Release** — docs, benchmarks, security audit, enterprise packaging | All | All channels | 2 |

**Total**: 21 weeks to a no-compromise system with ALL research features operational.

## What Ships When

| Milestone | Timeline | What the User Gets |
|-----------|----------|-------------------|
| **Core Alpha** | Week 4 | App Store TestFlight — vault intelligence, basic tools, provenance |
| **Core Beta** | Week 7 | App Store TestFlight — agent runtime, context governor, contextual shadows |
| **Pro Alpha** | Week 9 | Direct download — CLI, MCP, browser tools, computer-use |
| **Pro Beta** | Week 13 | Direct download — embedded JS runtime, in-process tool execution |
| **Research Alpha** | Week 16 | Direct download — direct ANE access, activation steering, KV snapshots |
| **Research Beta** | Week 19 | Direct download — spectral orchestration, meta-cognitive layer |
| **v1.0 Launch** | Week 21 | All tiers simultaneously — Core on App Store, Pro/Research on website |

---

# PART VI: THE ENTITLEMENT IMPLEMENTATION

## Step-by-Step: Getting Developer ID + Notarization Working

### 1. Apple Developer Program ($99/year)

Required for all distribution methods. You already have this.

### 2. Create Developer ID Certificate

- Xcode → Preferences → Accounts → Manage Certificates
- Add "Developer ID Application" certificate
- This certificate signs apps distributed OUTSIDE the App Store

### 3. Configure Build Target

Create a new Xcode build configuration:

```
Product Name: Epistemos Pro
Bundle ID: com.epistemos.pro
Signing: Developer ID Application (not Apple Development)
Hardened Runtime: YES
App Sandbox: NO (critical — Pro is not sandboxed)
```

### 4. Add Entitlements File

Create `EpistemosPro.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- JIT compilation for embedded JS runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    
    <!-- Unsigned executable memory for user scripts -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    
    <!-- Load private frameworks (AppleNeuralEngine, etc.) -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- Apple Events for automation -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    
    <!-- Full filesystem access -->
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
    <array>
        <string>/</string>
    </array>
    
    <!-- Network access -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    
    <!-- Keychain for Dark Node encryption -->
    <key>keychain-access-groups</key>
    <array>
        <string>com.epistenos.pro</string>
    </array>
</dict>
</plist>
```

### 5. Build and Sign

```bash
# Build for release
xcodebuild -scheme "Epistemos Pro" -configuration Release

# Sign with Developer ID
codesign --sign "Developer ID Application: Your Name" \
  --entitlements EpistemosPro.entitlements \
  --deep --strict \
  --options runtime \
  build/Release/Epistemos\ Pro.app

# Create DMG for distribution
create-dmg \
  --volname "Epistemos Pro" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "Epistemos Pro.dmg" \
  build/Release/Epistemos\ Pro.app
```

### 6. Notarize

```bash
# Submit for notarization (automated scan, not human review)
xcrun notarytool submit \
  --keychain-profile "EpistemosNotary" \
  --wait \
  "Epistemos Pro.dmg"

# Staple notarization ticket
xcrun stapler staple "Epistemos Pro.dmg"
```

**Notarization takes 5-30 minutes.** Not 2-5 days like App Review. It is fully automated.

### 7. Distribute

Upload the notarized DMG to your website. Users download and drag to Applications. No App Store involved.

---

# PART VII: THE FEATURE-TO-TIER MAP

## Every Research Feature → Concrete Shipping Path

| Feature | From Research | Tier | How It Ships | Status |
|---------|--------------|------|-------------|--------|
| **Ternary logic (Kleene K3)** | `ternary_spectral_architecture.md` §1 | Core+Pro+Research | `Trit` enum in Rust, Swift bridge | Not started |
| **Spectral memory (Laplacian)** | `ternary_spectral_architecture.md` §2-3 | Pro+Research | Metal kernels: `graph_layout` ✅, `attention_laplacian` ❌, `spectral_project` ❌, `resonance_compute` ❌ | Partial |
| **Koopman operator** | `ternary_spectral_architecture.md` §3 | Research | Mode extraction from agent behavior traces | Not started |
| **Residency Governor** | `EPISTEMOS_MASTER_ARCHITECTURE.md` §5 | Pro+Research | Rate-distortion optimization on claim metrics | Not started |
| **5-tier verification (T0-T4)** | `EPISTEMOS_MASTER_ARCHITECTURE.md` §4 | Core+Pro+Research | T0 type system ✅, T1 assertions ✅, T2 Proptest ⚠️, T3 Kani ❌, T4 Z3 ❌ | Partial |
| **HCache brain-state checkpointing** | `uasa_memory_breakthrough.md` | Pro+Research | State serialization, <100ms restoration | Not started |
| **KVCrush KV compression** | `uasa_memory_breakthrough.md` | Core+Pro+Research | 4× compression, <1% accuracy drop | Opt-in, blocked on MLX metallib |
| **DSC Adapter Bank** | `uasa_memory_breakthrough.md` | Research | Dynamic Subspace Composition, shared basis bank | Not started |
| **FSRS scheduler** | `uasa_memory_breakthrough.md` | Core+Pro+Research | Rust bridge implemented | **Operational** |
| **Direct ANE access** | `uasa_memory_breakthrough.md` §8 | Research | `_ANEClient` via `disable-library-validation` | Not started |
| **Apple Silicon UMA optimization** | `uasa_memory_breakthrough.md` §8 | Research | Zero-copy CPU/GPU/ANE shared memory | Partial (Metal exists) |
| **Biometric Dark Node** | `EPISTEMOS_MASTER_ARCHITECTURE.md` §1 | Core+Pro+Research | Secure Enclave keygen, AES-GCM encryption | Spec only |
| **Embedded JS runtime** | Quick Capture worktree | Pro+Research | QuickJS/Deno in-process, no subprocess | Not started |
| **Golden scheduling (φ-intervals)** | `ternary_spectral_architecture.md` §6 | Research | Hurwitz stability + KAM theorem scheduling | Not started |
| **Viable Systems Model** | `acs_meta_layer.md` | Research | Recursive S1-S5 governance at every scale | Not started |
| **QOFT/QDoRA adapters** | `osft_psoft_coso_fusion.md` | Research | QLoRA-compatible continual learning | Not started |
| **Self-referencer** | `acs_meta_layer.md` | Research | Model observing its own substrate state | Not started |
| **Agent Runtime (multi-turn)** | `agent_core` crate | Core+Pro+Research | Multi-turn loop, tool dispatch, state management | **Operational** |
| **Hermes CLI tunnel** | Fusion docs | Pro+Research | MCP protocol server, stdio/HTTP transports | Partial (MCP exists, server missing) |
| **Context Governor** | Fusion docs | Core+Pro+Research | Hybrid retrieval, provenance tracking | Partial (foundation exists) |
| **Simulation theater** | Simulation worktree | Pro+Research | Metal pixel-art theater, multi-room | Frozen, extractable |
| **Quick Capture** | Quick Capture worktree | Core+Pro+Research | In-process capture, v2 tool catalog | Partial (v2 in worktree) |
| **Provenance spine** | Built code | Core+Pro+Research | BLAKE3 + Merkle chain, OpLog, replay | **Operational** |
| **Graph engine** | `graph-engine` crate | Core+Pro+Research | 2,508 tests, full graph database | **Operational** |
| **Shadow search** | `epistemos-shadow` crate | Core+Pro+Research | 45 tests, FFI search backend | **Operational** |
| **MCP protocol** | `omega-mcp` crate | Pro+Research | 131 tests, JSON-RPC, tool advertisement | **Operational** |
| **Subprocess hardening** | `agent_core` | Core+Pro+Research | 23 sites, env-scrub, kill_on_drop | **Operational** |

---

# PART VIII: RISK ASSESSMENT

## What Could Go Wrong

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Apple breaks `disable-library-validation` in future macOS | Low | **EXISTENTIAL** | Monitor beta releases; maintain CoreML fallback path; lobby via DTS if needed |
| Notarization rejects `allow-unsigned-executable-memory` | Low | High | Chromium uses it successfully; if rejected, switch to WASM sandbox instead of JIT |
| ANE private APIs change in next Apple Silicon generation | Medium | High | Abstract ANE access behind trait; CoreML fallback always maintained |
| App Store rejects Core tier due to "unusual" architecture | Medium | Medium | Ensure Core tier uses ONLY public APIs; keep Pro/Research completely separate target |
| User confusion about tier differences | Medium | Medium | Clear marketing: "Core is free on App Store, Pro is $X/month from website, Research is invite-only" |
| Enterprise customer wants Research features | Low | Medium | Enterprise Program ($299/year) for internal distribution; same binary, different signing |
| SwiftData schema migration chaos | Medium | High | Versioned migrations; test on real devices; never migrate without gate |

## What Is Going Right

| Strength | Evidence |
|----------|----------|
| Substrate is solid | 3,832 tests, zero failures |
| Provenance is production-grade | OpLog chain with BLAKE3, lease, retry, dead-letter |
| Tool catalog is comprehensive | 56+ tools across 15 categories |
| Agent runtime exists | Multi-turn loop, provider routing, context loading |
| FFI is clean | UniFFI bridge, no raw C symbol leakage |
| Test discipline is world-class | Red → green → audit → docs per slice |
| Subprocess hardening is real | 23 sites, env-scrub, kill_on_drop, process_group |

---

# PART IX: THE CANONICAL BUILD PROMPT

## For Codex (Builder)

```
You are building Epistemos, a no-compromise cognitive operating system for macOS.

NON-NEGOTIABLE PRINCIPLES:
1. Every research feature ships. Nothing is deferred to "maybe someday."
2. The same codebase compiles to three targets: Core (App Store), Pro (Developer ID), Research (Developer ID + private frameworks)
3. Use feature flags: #[cfg(feature = "core")], #[cfg(feature = "pro")], #[cfg(feature = "research")]
4. Runtime detection over compile-time assumptions: check capabilities at runtime, degrade gracefully
5. In-process by default. Subprocess only where isolation is genuinely needed (browser security, untrusted code)
6. Pro tier uses Developer ID + Notarization, NOT App Store. Entitlements: allow-jit, allow-unsigned-executable-memory, disable-library-validation
7. Research tier loads private frameworks dynamically (AppleNeuralEngine, etc.) via dlopen, not linking
8. Every slice: deliberation gate → red test → implementation → green test → Kimi audit → docs

CURRENT PRIORITY ORDER:
1. Worktree reconciliation (port v2 tools, AgentEvent variants to main)
2. Ternary substrate + ClaimKernel (foundational for all tiers)
3. Agent Runtime Swift UI integration (make the Rust backend user-visible)
4. Context Governor (hybrid retrieval, the "supercharged" feeling)
5. Pro tier build target (Developer ID, entitlements, Hermes CLI)
6. Embedded JS runtime (QuickJS in-process)
7. Single-binary unification (link all crates)
8. Direct ANE access (_ANEClient loading, MIL compilation)
9. Spectral orchestration (Metal kernels, Koopman, golden scheduler)
10. Meta-cognitive layer (VSM recursion, self-referencer)

STOP DOING:
- Substrate theater (OpLog replay/rollback, deeper hardening)
- Worktree coding (only main branch from now on)
- App Store-only thinking (Pro/Research ship via Developer ID)
- "Infinite context" promises (use "infinite external cognition, bounded neural context")

DISTRIBUTION ENTITLEMENTS FOR PRO/RESEARCH:
- com.apple.security.cs.allow-jit
- com.apple.security.cs.allow-unsigned-executable-memory  
- com.apple.security.cs.disable-library-validation
- com.apple.security.automation.apple-events
- Full filesystem access via temporary-exception
- Network client + server
- NO app-sandbox (Pro/Research are not sandboxed)
```

## For Kimi (Overseer)

```
You are the overseer for Epistemos. Your job is to verify that every build order advances the no-compromise vision.

OVERSIGHT CHECKLIST:
1. Does this slice ship a user-visible feature, or is it substrate theater?
2. Does this slice work on ALL tiers (Core/Pro/Research), or is it tier-gated correctly?
3. Are feature flags used (#[cfg(feature = "...")]) instead of separate code paths?
4. Is runtime detection used instead of compile-time assumptions?
5. Does the Swift UI reflect the Rust backend capability, or is there a UI/backend gap?
6. Are deliberation gates complete with tier classification (Core/Pro/Research)?
7. Are tests red before implementation, green after, with edge cases?
8. Is documentation updated (README, fusion docs, API docs)?

RED FLAGS (stop and redirect):
- Builder edits worktree code instead of main
- Builder adds new research dimensions instead of executing existing ones
- Builder deepens substrate without user-visible output
- Builder forgets tier gating (everything becomes Core or everything becomes Research)
- Builder promises App Store for features that need Developer ID
- Builder uses subprocess where in-process UniFFI would work
- Builder links private frameworks at build time instead of loading dynamically

ENTITLEMENT VERIFICATION:
For every Pro/Research slice, verify:
- Hardened Runtime is enabled
- App Sandbox is disabled
- disable-library-validation is present (for Research features)
- allow-jit is present (for embedded JS)
- Notarization passes (automated scan, not human review)
```

---

# PART X: THE FINAL WORD

## What You Actually Have

You have a **3,832-test, multi-crate cognitive substrate** that is already operational. The agent runtime exists. The tool catalog exists. The provenance spine is production-grade. The FFI is clean. The test discipline is world-class.

## What You Actually Need

You need to:
1. **Reconcile worktrees onto main** (1 week)
2. **Add the ternary + claim foundation** (1 week)
3. **Wire Swift UI to the Rust backend** (2 weeks)
4. **Build the Context Governor** (2 weeks)
5. **Set up Pro/Developer ID build target** (1 week)
6. **Ship Pro with CLI + MCP + browser** (2 weeks)
7. **Embed JS runtime in-process** (2 weeks)
8. **Unify to single binary** (2 weeks)
9. **Add direct ANE access** (3 weeks)
10. **Add spectral + meta-cognitive layers** (4 weeks)

**Total: 20 weeks to the no-compromise vision.**

## The Assurance

**All your nuance is preserved.**

| Your Vision | Where It Lives | How It Ships |
|-------------|---------------|--------------|
| Ternary-native logic | `ternary_spectral_architecture.md` | `Trit` enum, K3 tables, Swift bridge |
| Spectral memory | `ternary_spectral_architecture.md` + Metal kernels | Metal compute shaders, graph Laplacian |
| Residency Governor | `EPISTEMOS_MASTER_ARCHITECTURE.md` | Rate-distortion optimization, claim metrics |
| Direct ANE manipulation | `uasa_memory_breakthrough.md` §8 | `_ANEClient` via `disable-library-validation` |
| Embedded JS runtime | Quick Capture worktree pattern | QuickJS/Deno in-process, no subprocess |
| Single binary, in-process | Quick Capture DOCTRINE | Link all crates, UniFFI-only, no IPC daemon |
| 5-tier verification | `EPISTEMOS_MASTER_ARCHITECTURE.md` §4 | Proptest T2 now, Kani/Z3 background |
| HCache / KVCrush / DSC | `uasa_memory_breakthrough.md` | State checkpointing, KV compression, adapter bank |
| Golden scheduling | `ternary_spectral_architecture.md` §6 | φ-interval task scheduling, Hurwitz/KAM proofs |
| Viable Systems Model | `acs_meta_layer.md` | Recursive S1-S5 governance, Tarski fixed point |
| Self-referencer | `acs_meta_layer.md` | Model observing own substrate, autopoietic closure |
| Autopoietic closure | `acs_meta_layer.md` | Self-maintaining boundary, recursive identity |
| Biometric Dark Node | `EPISTEMOS_MASTER_ARCHITECTURE.md` §1 | Secure Enclave, AES-GCM, biometric gate |
| Deterministic provenance | Built code (3,832 tests) | BLAKE3 + Merkle chain, OpLog, replay |
| Mixture of models | `agent_core` providers | Qwen + DeepSeek + Apple Intelligence lanes |
| KV snapshots | Research tier | Activation steering, sparse KV textures |
| Neural-kernel | Research tier | Direct weight modulation, latent space intervention |
| Simulation theater | Simulation worktree DOCTRINE v1.6 | Metal pixel-art, multi-room, knowledge-brick |
| Companion system | Simulation DOCTRINE §3.4 | Company→Model→Agent hierarchy, pixel mascots |
| Quick Capture | Quick Capture worktree | In-process capture, v2 tool catalog, no subprocess |
| Hermes CLI | Fusion docs + omega-mcp | MCP protocol server, external agent tunnel |
| Contextual Shadows | Built code V0 + spec V1 | Tiered memory L0/L1/L2, Shadow backend route |
| FSRS scheduler | Built code (Rust bridge) | Spaced repetition, retrievability decay |

**Nothing is lost. Nothing is deferred. Everything ships.**

The only question is which tier, and that question is answered by the concrete Apple distribution strategy above.

---

*This document synthesizes:
- All 6 previous Kimi research sessions (35,000+ words)
- All 4 worktree analyses (simulation, Quick Capture, main branch, CLI)
- All fusion documents from Claude (Apr 30, 2026)
- Apple entitlement research (public, restricted, private)
- ANE reverse-engineering research (M4 direct access, MIL compilation, E5 binaries)
- macOS distribution method analysis (App Store, TestFlight, Developer ID, Enterprise, Ad Hoc)
- Chromium notarization precedent (disable-library-validation, allow-jit, allow-unsigned-executable-memory)*
