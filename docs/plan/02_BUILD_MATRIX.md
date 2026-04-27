# 02 — Build Matrix: MAS vs Pro

**Authority:** Subordinate to `docs/architecture/PLAN_V2.md`, `CLAUDE.md`, and
`docs/plan/01_DOCTRINE.md`. Governs Pro vs MAS feature gating.

**Targets:**
- **Epistemos MAS** — Mac App Store build. **Sandboxed** (`com.apple.security.app-sandbox = true`).
  Reviewed by Apple. Subset of features. "Bounded Intelligence OS."
- **Epistemos Pro** — Direct download, Developer ID notarized, **Hardened Runtime**,
  **non-sandboxed**. JIT entitlement (`com.apple.security.cs.allow-jit = true`).
  Full feature set. "Full Autonomy OS."

**Build mechanism:** xcodegen-generated Xcode targets from `project.yml`. Per-feature
gating via Swift compilation conditions:

- `EPISTEMOS_PRO` — defined for Pro target only.
- `EPISTEMOS_MAS` — defined for MAS target only.
- Code paths that only compile in one target use `#if EPISTEMOS_PRO` / `#if EPISTEMOS_MAS`.

**Rust crates** that are Pro-only do not build in MAS. The `agent_core` crate uses
Cargo features (`pro` / `mas`) to gate optional modules. The `omega-mcp` crate also
uses features for shell-execution dispatchers.

---

## 1. Capability matrix

Legend:
- ✅ ships, fully functional
- ⚠️ ships, gated/limited (footnote)
- ❌ does not ship in this target
- 🔒 ships behind explicit user approval per session

| Capability | MAS | Pro | Mechanism |
|---|---|---|---|
| **Local inference (MLX-Swift, in-process)** | ✅ | ✅ | mlx-swift dynamic library, signed and bundled |
| **Apple Foundation Models (`@Generable`)** | ✅ | ✅ | macOS 26+ runtime API |
| **Cloud LLM APIs (URLSession)** | ✅ | ✅ | API keys in Keychain. Network entitlement. |
| **MCP server hosting (in-process)** | ✅ | ✅ | swift-sdk; STDIO via internal pipes only in MAS |
| **Vault file access (notes/journal)** | ✅ | ✅ | Security-scoped bookmarks via NSOpenPanel |
| **Vault file access (any path)** | ❌ | ✅ | MAS limited to user-granted scope; Pro is unrestricted |
| **Tantivy + usearch (Halo Shadow index)** | ✅ | ✅ | Rust dylib, signed and bundled |
| **GRDB persistence** | ✅ | ✅ | Both |
| **Tiptap WKWebView editor** | ✅ | ✅ | Pre-built bundle in Resources/Editor (no runtime npm) |
| **Metal graph rendering** | ✅ | ✅ | Both |
| **Cost dashboard (W9.6)** | ✅ | ✅ | Both — required UX surface |
| **Approval modal (W9.8)** | ✅ | ✅ | Both — required for any irreversible action |
| **Daily notes + FSRS (W9.13)** | ✅ | ✅ | Both |
| **Block references (W9.14)** | ✅ | ✅ | Both — substrate-level feature |
| **Ledger + retraction propagation** | ✅ | ✅ | Both — substrate-level (the doctrine's keystone) |
| **A2UI catalog (closed)** | ✅ | ✅ | Both |
| **ReplayBundle export** | ✅ | ✅ | Both — provenance is universal |
| **MLX KIVI / TurboQuant KV quant (W9.30/W9.10)** | ✅ | ✅ | Both |
| **Honest FFI / Typestate (W9.21/22)** | ✅ | ✅ | Both — architectural |
| **B-tree rope (W9.26)** | ✅ | ✅ | Both |
| **Append-only OpLog (W9.27)** | ✅ | ✅ | Both |
| **ScreenCaptureKit** | ⚠️ A | ✅ | Both with `NSScreenCaptureUsageDescription` + per-window grant |
| **Hermes Python subprocess (orchestration)** | ❌ | ✅ | Sandbox forbids unbundled Python; Pro only |
| **Hermes ACP HTTP (remote provider)** | ⚠️ B | ✅ | MAS allows HTTP-based ACP only |
| **Bollard / Docker (Tier C sandbox)** | ❌ | 🔒 | Bollard 0.19, ephemeral containers, `--network=none` |
| **JavaScriptCore (Tier A sandbox)** | ✅ | ✅ | In-process, both targets |
| **Wasmtime (Tier B sandbox)** | ✅ | ✅ | In-process, signed binary; both targets |
| **portable-pty shell exec (Tier D)** | ❌ | 🔒 | Pro only, per-session approval |
| **rexpect (interactive subprocess)** | ❌ | 🔒 | Pro only |
| **AXorcist (Accessibility)** | ❌ | 🔒 | `NSAccessibilityUsageDescription`; TCC prompt |
| **CGEvent synthesis (input injection)** | ❌ | 🔒 | TCC prompt; explicit user grant |
| **NSAppleEvents (cross-app automation)** | ❌ | 🔒 | `NSAppleEventsUsageDescription`; TCC |
| **iMessage integration** | ❌ | 🔒 | Cross-app automation route; Pro only |
| **External CLI integration (Claude Code, Codex CLI, Gemini CLI)** | ❌ | ✅ | Subprocess + non-interactive flags |
| **MCP STDIO with external clients** | ⚠️ C | ✅ | MAS limited to embedded; Pro can serve to external |
| **ETL crawler with AFM sidecars (R16)** | ⚠️ D | ✅ | MAS works inside bookmark scope only |
| **Background ETL/Night Brain jobs** | ✅ | ✅ | Both, but MAS limited to bookmark scope |
| **Per-vault model identity (W9.7)** | ✅ | ✅ | Both |
| **EndpointSecurity** | ❌ | ❌ | Per Architect D: entitlement infeasible for solo dev |
| **Open `epistemos-trace` CLI (separate distribution)** | n/a | n/a | Distributed via Homebrew + GitHub releases; not part of either app target |

**Footnotes:**
- A. ScreenCaptureKit MAS: works but cannot share captures across app boundaries; no cross-process screen analysis.
- B. Hermes ACP in MAS: must use HTTP/WebSocket to a remote ACP endpoint. No local subprocess.
- C. MCP STDIO in MAS: in-process server only. Cannot serve to external sandboxed processes per Apple's IPC rules.
- D. ETL in MAS: walks only paths the user has granted via NSOpenPanel security-scoped bookmarks. Cannot crawl `~/Documents` wholesale.

---

## 2. Provider matrix per target

The Provenance Plane validates every provider's `ProposedEnvelope` regardless of
target. Differences are in *which providers are available*.

| Provider | MAS | Pro | Sandbox impact |
|---|---|---|---|
| **Local Qwen (MLX-Swift)** | ✅ | ✅ | In-process |
| **Local Hermes-3 (MLX-Swift)** | ✅ | ✅ | In-process |
| **Apple Foundation Models** | ✅ | ✅ | macOS API |
| **Claude API (HTTP)** | ✅ | ✅ | URLSession |
| **Perplexity Sonar Pro (HTTP)** | ✅ | ✅ | URLSession |
| **OpenAI / Codex API (HTTP)** | ✅ | ✅ | URLSession |
| **Gemini API (HTTP)** | ✅ | ✅ | URLSession |
| **Kimi/Moonshot HTTP** | ✅ | ✅ | URLSession |
| **Hermes ACP local (subprocess)** | ❌ | ✅ | Subprocess forbidden in MAS |
| **Hermes ACP remote (HTTP)** | ✅ | ✅ | URLSession |
| **Claude Code CLI** | ❌ | ✅ | Subprocess |
| **OpenAI Codex CLI** | ❌ | ✅ | Subprocess |
| **Gemini CLI** | ❌ | ✅ | Subprocess |
| **OpenHands** | ❌ | ✅ | Subprocess + container |

**Honest capability gating** (per `CLAUDE.md`):
- Local models → fast / thinking / research modes only.
- Cloud models → fast / thinking / research / agent / liveAgent modes.
- The UI must surface the available mode set per provider; never offer a mode the
  provider cannot deliver.

---

## 3. Sandbox tier ladder (Pro)

Per `01_DOCTRINE.md` Architect D ruling. Risk class → tier mapping:

| Risk class | Tier | Mechanism | Egress | Filesystem | Approval |
|---|---|---|---|---|---|
| Trusted DSL (loop profiles, EBNF grammars) | **A** | JavaScriptCore in-process | none | none | none |
| Untrusted code, bounded compute | **B** | Wasmtime 25+ linear-memory isolate | none | virtual FS only | once-per-source |
| Shell-heavy untrusted work | **C** | Bollard 0.19 ephemeral container, `--network=none` | none | mounted scratch only | per-session |
| Host execution | **D** | portable-pty 0.9 + rexpect 0.6 | host network | host FS | per-command |

**MAS:** only Tier A and Tier B. Tier C and D are absent (the Rust modules don't
build under the `mas` Cargo feature).

**Pro:** all four tiers. Tier C and D require explicit per-session approval surfaced
through W9.8 approval modal.

---

## 4. Entitlements & Info.plist (Pro)

```xml
<!-- Epistemos.entitlements (Pro target) -->
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>
<key>com.apple.security.cs.disable-library-validation</key>
<false/>
<key>com.apple.security.app-sandbox</key>
<false/>
<!-- Network entitlement is implicit in non-sandbox; left out -->
```

```xml
<!-- Info.plist TCC keys (Pro) -->
<key>NSAccessibilityUsageDescription</key>
<string>Epistemos uses Accessibility to automate workflows you approve.</string>
<key>NSScreenCaptureUsageDescription</key>
<string>Epistemos captures screen content only when you explicitly start a workflow that needs it.</string>
<key>NSAppleEventsUsageDescription</key>
<string>Epistemos uses cross-app automation only when you explicitly approve a workflow.</string>
```

**Notarization workflow (Pro):**
1. Inside-out codesign (Rust dylibs → frameworks → app shell). **No `--deep`.**
2. `xcrun notarytool submit Epistemos.app.zip --keychain-profile <profile> --wait`.
3. `xcrun stapler staple Epistemos.app`.
4. TCC prompt sequencing: prompts fire one at a time, gated by user action that
   needs the capability — never on first launch.

---

## 5. Entitlements & Info.plist (MAS)

```xml
<!-- Epistemos.entitlements (MAS target) -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
<!-- No JIT, no AppleEvents, no Accessibility, no ScreenCapture-cross-process -->
```

```xml
<!-- Info.plist TCC keys (MAS) -->
<key>NSScreenCaptureUsageDescription</key>
<string>Epistemos captures only the windows you select.</string>
<!-- Accessibility / AppleEvents keys absent — those entitlements not granted -->
```

**MAS submission workflow:**
1. Build with `EPISTEMOS_MAS` defined; verify no `EPISTEMOS_PRO`-gated symbol leaks.
2. `xcodebuild archive` → Mac App Store distribution method.
3. Upload via Transporter. App Review.
4. Privacy Manifest (`PrivacyInfo.xcprivacy`) declares: NetworkUserAgent (LLM APIs),
   FileTimestamp (vault sync), UserDefaults (telemetry preferences only — no PII).

---

## 6. Per-feature gating recipes (Swift)

```swift
// Example: shell-exec tool registration
import Foundation

#if EPISTEMOS_PRO
import AXorcist
import EpistemosShell  // wraps portable-pty
#endif

extension ToolRegistry {
    static func registerHostTools(_ registry: ToolRegistry) {
        #if EPISTEMOS_PRO
        registry.register(ShellExecTool(approval: .perCommand))
        registry.register(AccessibilityNavigateTool(approval: .perWorkflow))
        #endif
        // Tools available in both targets always register
        registry.register(VaultSearchTool())
        registry.register(NoteCreateTool())
    }
}
```

```swift
// Example: provider availability gate
@MainActor
final class ProviderRegistry {
    func availableProviders() -> [Provider] {
        var providers: [Provider] = [
            QwenLocalProvider(),
            HermesLocalProvider(),
            ClaudeAPIProvider(),
            PerplexityProvider(),
            // ... cloud HTTP providers
        ]
        #if EPISTEMOS_PRO
        providers.append(contentsOf: [
            ClaudeCodeCLIProvider(),
            CodexCLIProvider(),
            GeminiCLIProvider(),
            OpenHandsProvider(),
            HermesACPLocalProvider(),  // subprocess
        ])
        #endif
        return providers
    }
}
```

```rust
// agent_core/Cargo.toml — Cargo feature gating
[features]
default = []
mas = []
pro = ["shell-exec", "container-sandbox", "interactive-pty"]
shell-exec = []
container-sandbox = ["dep:bollard"]
interactive-pty = ["dep:portable-pty", "dep:rexpect"]

[dependencies]
bollard = { version = "0.19", optional = true }
portable-pty = { version = "0.9", optional = true }
rexpect = { version = "0.6", optional = true }
```

---

## 7. Cross-target obligations (always true)

These hold regardless of target. Violating any of these is a doctrine violation, not
a target-gating decision:

- **Telemetry surface** for every behavior (per `00_AUTHORITY_AND_ANTI_DRIFT.md §7`).
  This includes Pro-only features — the user must always see what the app is doing.
- **Approval modal** is the only path for irreversible actions in both targets. MAS
  uses it for vault deletions, network calls; Pro uses it additionally for shell
  exec, AXorcist actions, AppleEvents.
- **Retraction propagation** runs in both targets. The substrate's integrity does
  not depend on which capabilities the host process has.
- **No silent fallback** — if a Pro-only provider is selected in MAS, the UI must
  surface "this provider is Pro-only" rather than silently substituting an
  alternative.
- **6 GB realtime budget** applies to both. MAS effectively has more headroom
  because subprocess providers are absent, but the budget is the same.
- **Schema validation** of every emitted event/envelope. Both targets validate.
- **A2UI catalog** is shared — same components in both targets. No "Pro-only"
  components.

---

## 8. Open-standard distribution (NOT part of either app target)

Per `01_DOCTRINE.md §5`, the **`epistemos-provenance-standard`** project is a
separate, independently distributed open-source ecosystem:

- **Repo:** public GitHub (Apache 2.0).
- **`epistemos-trace` CLI binary:** Homebrew tap + GitHub release artifacts (macOS
  arm64/x86_64, Linux x86_64).
- **Provenance crates** (`epistemos-provenance`, `epistemos-provider`, etc.):
  crates.io.
- **Reference SDKs:** crates.io (Rust), PyPI (Python), npm (TypeScript). Python
  and TS bind to the Rust validator via FFI.
- **Conformance suite:** GitHub repo with CI badge.
- **Not bundled** with either Epistemos MAS or Pro. The native app *uses* these
  crates internally as Cargo dependencies of `agent_core`, but the crates are also
  consumable by anyone independently.

This separation is the moat: the native app is closed; the substrate format is open.

---

## 9. Last updated

2026-04-26 — Initial creation. Pro/MAS gating per item. Sandbox tier ladder. Open
standard separated from app distribution.
