# Osaurus in MAS — deep ENTITLEMENTS research (owner 2026-06-21)

Owner directive: bring in the **FULL Osaurus** (the experience seen in the videos), don't lose
its "osaurus-ness," **no clashes**, and **don't cut corners hiding behind "MAS structure."**
First question to answer deeply: **can the full Osaurus dependency/capability set fit in the Mac
App Store via ENTITLEMENTS?** If yes → keep MAS + full Osaurus. If a genuine capability truly
can't → drop MAS for it (don't be strict at the cost of features). Researched against primary
Apple sources below — NOT asserted from memory.

## Per-capability entitlement verdict (grounded)
| Osaurus capability | Dependency | Entitlement needed | MAS-grantable? |
|---|---|---|---|
| Local OpenAI/Anthropic/Ollama server (:1337) | swift-nio | `com.apple.security.network.server` | **YES** — Apple docs: this entitlement exists precisely to "listen for incoming network connections" in a sandboxed App-Store app. |
| Identity/relay (outbound WebSocket → agent.osaurus.ai) | swift-secp256k1 | `com.apple.security.network.client` | **YES** — standard MAS entitlement. |
| Crash + analytics telemetry | Sentry, Aptabase | `network.client` + privacy-nutrition labels | **YES** — common in MAS apps; needs honest privacy disclosure (owner sign-off on telemetry, separate from MAS). |
| On-device inference | vmlx-swift (MLX) | none special (Metal compute) | **YES** — MLX is MAS-fine. |
| Encrypted storage | vendored SQLCipher | none special | **YES**. |
| MCP server/client | swift-sdk | network entitlements | **YES**. |
| System plugins (Mail/Calendar/Browser automation) | — | `com.apple.security.automation.apple-events` (+ temporary-exception per target) | **YES, with review** — MAS-allowed but App-Review-scrutinized; per-target. |
| File/Folder tools | — | `com.apple.security.files.user-selected.*` / bookmarks | **YES**. |
| **Linux container/VM sandbox** ("shell, Python, Node, compilers" — Osaurus's headline isolation feature) | **apple/containerization** → Virtualization.framework | **`com.apple.security.virtualization`** | **NO (realistically)** — see below. |
| Auto-update | Sparkle | n/a (distribution mechanism) | **NO** — MAS apps update via the App Store; Sparkle is for direct distribution. *Zero osaurus-ness loss* (just the updater; drop it on the MAS build). |

## The ONE real MAS blocker: the virtualization entitlement (RESTRICTED)
`com.apple.security.virtualization` gates Virtualization.framework, which Apple's
**Containerization** framework (the one-VM-per-container Linux sandbox) is built on. Per Apple
Developer Forums, this entitlement is **"restricted to developers of virtualization software"** —
it is NOT auto-granted; you must contact an Apple representative, justify the use, and get
explicit approval, which is realistically reserved for dedicated virtualization tools (Parallels,
UTM-class), not a general PKM/agent app. So the **Containerization Linux-VM sandbox cannot ship in
a Mac-App-Store build** of Epistemos by entitlement. This is a genuine Apple restriction, NOT a
"MAS-struct excuse" or a hallucinated corner-cut — it is the documented gate.

## Verdict (honest, per the owner's own rule)
- **~95% of the full Osaurus fits MAS** with standard entitlements (server, relay, MLX, MCP,
  storage, plugins, file tools, telemetry) — these are NOT reasons to drop MAS.
- **The Linux-VM sandbox does NOT fit MAS** (restricted virtualization entitlement). It is a real
  Osaurus feature (the headline "zero-risk Linux sandbox" in the videos).
- **Owner's decision rule applies:** "if [I can't fit it all in MAS] then ofc don't [be strict]."
  Since keeping the FULL osaurus-ness *requires* the VM sandbox, and the VM sandbox cannot be
  MAS-distributed, the honest path to the full video experience is: **do NOT constrain to MAS for
  the VM-sandbox capability.** Recommended shape (no feature cut):
  - **Primary build = direct-distribution (Developer-ID/notarized), NOT sandboxed** → ships the
    FULL Osaurus including the Linux-VM sandbox + everything else, 1:1 with the videos.
  - (Optional later) a MAS build that simply omits ONLY the VM sandbox (everything else works under
    MAS entitlements) — but that's a *choice*, not a constraint imposed on the main app.

## Separate TECHNICAL clash to resolve (NOT a MAS issue): dual-MLX
OsaurusCore pulls `osaurus-ai/vmlx-swift` (a consolidated MLX fork: MLX/MLXLLM/MLXVLM/
MLXLMCommon/MLXEmbedders/Tokenizers). Epistemos already vendors `mlx-swift-lm`. Two packages
defining the same `MLX*` modules in one binary ⇒ duplicate-module link error. To link the full
OsaurusCore **without clashes** (owner's "no clashes"): **consolidate Epistemos onto Osaurus's
`vmlx-swift`** — drop `mlx-swift-lm`, repoint Epistemos's `import MLX*` at vmlx-swift (same upstream
lineage, largely API-compatible). This keeps osaurus-ness intact (Osaurus's own MLX stack) and
removes the only hard build clash. Same applies to SQLCipher-vs-system-SQLite (OsaurusCore already
hand-patches the FTS5 typedef collision; we adopt its vendored SQLCipher).

## Net (what to build next)
1. **Drop the MAS hard-constraint for the main app** (owner-confirmed) → direct-distribution build
   carries the FULL Osaurus, VM sandbox included. No feature cut, no "MAS-struct" excuse.
2. **Resolve the dual-MLX clash by consolidating on `vmlx-swift`** so OsaurusCore links cleanly.
3. Then link OsaurusCore for real + reskin to Epistemos pixel-art chrome (the video experience).

## Sources
- [com.apple.security.network.server — Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server)
- [com.apple.security.virtualization — Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.virtualization)
- [App Sandbox — Apple Developer Documentation](https://developer.apple.com/documentation/security/app_sandbox_entitlements)
- [Apple Developer Forums — "This entitlement is restricted to developers of virtualization software"](https://discussions.apple.com/thread/255626985)
- [Will the Virtualization Framework work for App Store apps? — Apple Developer Forums](https://developer.apple.com/forums/thread/707459)
- [apple/containerization (Swift package, Linux VMs on macOS)](https://github.com/apple/containerization)
