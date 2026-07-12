# Epistemos

Epistemos is an in-development native macOS research workspace for local-first notes, retrieval, agent tooling, and explicit cloud-assisted workflows.

The current build is not a finished product and this README is intentionally grounded in the repository as it exists now. Older architecture notes in `docs/` include useful research history, but they should not be read as a promise that every described system is live, default, shipped, or owned by this repo.

## Current Direction

Epistemos is being built as a macOS app with a Swift/AppKit/SwiftUI shell, Rust static libraries, local vault/search infrastructure, MCP-style tool and resource plumbing, a rich `.epdoc` editor surface, and a receipt-gated cloud proxy path for opt-in remote inference.

The present trajectory is:

- keep the native macOS app as the primary product surface
- make local vault context and citations first-class through Eidos
- expose vault notes and app actions through bounded MCP tools/resources
- keep cloud use explicit, consent-gated, and separated from local workflows
- support embedded editor/runtime surfaces without pretending external agent projects are owned by Epistemos
- keep build claims tied to source, tests, and generated artifacts rather than old roadmap language

## Main Languages

- **C++ / C / Metal**: bridge headers, lower-level app interfaces, shader/kernel work, and language/runtime support around graph/syntax surfaces.
- **Swift**: macOS app shell, SwiftUI/AppKit views, WKWebView hosting, Keychain/session handling, StoreKit/client flows, and app coordination.
- **Rust**: core libraries linked into the app, Eidos retrieval types and bridges, MCP dispatch, vault execution, syntax/graph engines, and falsifier/test harnesses.
- **Python**: utility, research, and local tooling surfaces where scripting is the right tool.
- **TypeScript**: `.epdoc` editor bundle, CodeMirror/Tiptap integration, proxy server, and web/runtime support code.

## What Exists In This Repo

### Native macOS App

`project.yml` defines the main Epistemos macOS app targets. The app links Swift code with Rust static libraries through generated bindings and bridge headers.

Notable app surfaces include:

- SwiftUI/AppKit UI under `Epistemos/`
- local resources and shaders under `Epistemos/Resources/` and `Epistemos/Shaders/`
- Rust libraries linked through `OTHER_LDFLAGS`
- generated Swift bindings from `build-rust/swift-bindings`
- separate App Store and experimental build lanes

### Eidos Local Retrieval

Eidos is the current local context/retrieval layer. The Swift side mirrors Rust retrieval types and includes bridge paths for opening a vault index, inserting vault notes, retrieving context packets, and validating closed citations.

Relevant paths:

- `Epistemos/Eidos/Eidos.swift`
- `Epistemos/Eidos/EidosBridge.swift`
- `Epistemos/Eidos/EidosVaultBootstrapper.swift`
- `agent_core/src/eidos/`

Honest status: Eidos has real bridge/type/code paths in the repo, but individual comments may still mark some surfaces as wiring-in-progress. Treat current source and tests as truth, not older roadmap claims.

### MCP And Vault Tooling

`omega-mcp` provides a Rust MCP-style registry/dispatcher layer, execution logging, and vault-scoped resource/tool handling.

Relevant paths:

- `omega-mcp/src/dispatcher.rs`
- `omega-mcp/src/vault.rs`
- `omega-mcp/src/registry.rs`
- `omega-mcp/src/types.rs`

The current implementation includes JSON-RPC routing, `tools/list`, `tools/call`, execution records, vault-root configuration, Markdown resource listing/reading, path traversal checks, bounded reads, and atomic vault writes.

### Editor Bundle

The `.epdoc` editor stack is built from TypeScript using Tiptap and CodeMirror, then hosted inside the macOS app.

Relevant paths:

- `js-editor/package.json`
- `js-editor/src/`
- `build-tiptap-bundle.sh`
- `build-coreeditor-bundle.sh`
- `Epistemos/Resources/CoreEditor/`

The editor package includes checks for bridge messages, chart nodes, code blocks, markdown round-trips, minimal writeback, document graph behavior, suggestions, and related editor flows.

### Cloud And Receipt-Gated Proxy

Cloud use is now an explicit part of the app trajectory, but it is not the default privacy story and it should not be described as invisible fallback.

The app has consent and session code for cloud provider access:

- `Epistemos/AgentWorkspace/AgentCloudConsent.swift`
- `Epistemos/AgentWorkspace/EpistemosProxyClient.swift`
- `Epistemos/JuneAgent/JuneCloudEngine.swift`

The reference proxy server is TypeScript/Node:

- `proxy-server/src/index.ts`
- `proxy-server/src/appstore.ts`
- `proxy-server/src/proxy.ts`
- `proxy-server/src/tokens.ts`

The intended shape is explicit consent before personal/vault data reaches a provider, StoreKit receipt/session exchange for cloud access, short-lived Keychain-held session tokens on the client, and OpenAI-compatible streaming through the proxy.

### Embedded Runtime Surfaces

The repo contains experimental runtime plumbing for local web/agent surfaces inside the macOS app. These are integration surfaces, not ownership claims over upstream projects.

Relevant paths:

- `Epistemos/ExperimentalAgent/`
- `Epistemos/AgentSurface/`
- `bundle-app-runtime-assets.sh`
- `build-opencode-runtime.sh`
- `build-experimental-web.sh`

The current code includes WKWebView hosting, nonpersistent web data stores, supervised local Node runtime launch, loopback port allocation, sanitized child environments, provider-key bridging from Keychain into child process environments, and warm-start/preload behavior.

## Build Shape

The Xcode project is generated from `project.yml`. The main prebuild pipeline builds the Rust libraries and editor/runtime bundles before app compilation.

Common build-related scripts include:

- `build-rust.sh`
- `build-syntax-core.sh`
- `build-omega-mcp.sh`
- `build-epistemos-core.sh`
- `build-agent-core.sh`
- `build-epistemos-shadow.sh`
- `build-epistemos-code-index.sh`
- `build-substrate-rt.sh`
- `build-tiptap-bundle.sh`
- `build-coreeditor-bundle.sh`
- `bundle-app-runtime-assets.sh`

The project has separate lanes for regular app builds, App Store-oriented builds, and experimental/developer surfaces. Those lanes do not all imply the same capabilities.

## Repo Map

| Path | Purpose |
| --- | --- |
| `Epistemos/` | Native macOS app source, app views, app services, resources, shaders, and Swift integration code. |
| `agent_core/` | Rust agent/retrieval/runtime code, features, harnesses, and research-gated binaries. |
| `omega-mcp/` | MCP registry, dispatcher, execution logging, and vault tool/resource layer. |
| `epistemos-core/` | Rust core library linked into the app. |
| `graph-engine/` | Rust graph/syntax-related engine surfaces and FFI-safe library code. |
| `syntax-core/` | Rust tree-sitter parsing core for app/editor language support. |
| `epistemos-code-index/` | Code-indexing library surface. |
| `substrate-rt/` | Runtime/event substrate library surface. |
| `js-editor/` | TypeScript Tiptap/CodeMirror editor bundle for `.epdoc`. |
| `proxy-server/` | TypeScript reference cloud proxy with receipt/session/chat routes. |
| `LocalPackages/` | Local Swift package dependencies and editor-related app code. |
| `docs/` | Research, audits, historical plans, and design notes. Useful context, not automatically live product truth. |

## What This README Does Not Claim

- It does not claim every historical roadmap item in `docs/` is implemented.
- It does not claim cloud is absent; current source includes explicit cloud consent, proxy, and streaming work.
- It does not claim every runtime surface is first-party authored; embedded surfaces may integrate external tools.
- It does not claim one-process/no-subprocess purity across every lane; current experimental runtime code includes supervised local runtime launch and loopback handling.
- It does not claim App Store, Developer ID, and experimental builds expose the same capabilities.
- It does not claim local retrieval, cloud inference, editor integration, and MCP tooling are all equally complete.

## Development Status

Epistemos is active, fast-moving work. The most accurate description of a capability is the source path plus the tests/build scripts that exercise it. When in doubt:

1. read `project.yml`
2. read the relevant Swift/Rust/TypeScript source
3. check feature flags and build lanes
4. inspect current tests or harnesses
5. treat old docs as research context until source proves otherwise

## License

To be determined.
