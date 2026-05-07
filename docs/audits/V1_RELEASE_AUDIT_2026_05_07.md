# V1 Release Audit — 2026-05-07

Scope: Phase B catalog of complete-but-possibly-orphaned surfaces for the v1 hardening pass. HELIOS substrate remains frozen; this audit records wiring, gates, and v1/v2 disposition only.

Runtime evidence captured during this pass:
- CLI detection: `claude` 2.1.126, `codex-cli` 0.125.0, and `kimi` 1.40.0 are installed; `gemini` and `agent-browser` are not installed.
- CLI smoke: `claude -p`, `codex exec`, and `kimi -p` all returned the `epistemos-cli-ok` sentinel under an env-clear allowlist. Kimi included a reasoning preface before the sentinel. Codex returned the sentinel and also exposed a local malformed-skill-frontmatter warning, fixed in `.agents/skills/recursive_app_audit/SKILL.md`.
- Phase A gate note: the requested repo-root `cargo test --workspace` is not runnable because `/Users/jojo/Downloads/Epistemos` has no root `Cargo.toml`; crate-local Rust gates still need to be run in the verification phase.

- Cognitive DAG (Phase 8.A-8.G) — wired · `RustCognitiveDagClient` exposes node count, edge count, and Merkle root through `CognitiveDagHealthRow` in Settings diagnostics; authority/promotion remains future work. · ship-in-v1
- Per-model memory / model profiles v2 — wired · `SDModelProfile`, `ModelProfileManager`, `ModelVaultsSettingsView`, `ModelVaultsSidebarSection`, and profile/vault selector views expose model-scoped vault identity and compiled knowledge status. · ship-in-v1
- Skills + procedural memory + self-evolution — wired · Skill Hub can discover/create/install `SKILL.md` files and Rust context loading includes skills; generated tool runtime registration and autonomous promotion stay deferred. · ship-in-v1
- CLI passthrough (Claude / Codex / Gemini / Kimi) — gated-correctly · Pro-build handlers exist for all four CLIs, use hardened subprocess spawning, and return install hints when missing; live smoke passed for installed Claude/Codex/Kimi, while Gemini is absent. · ship-in-v1
- Computer Use / Visual Verify — gated-correctly · `DeviceAgentService`, `ScreenCaptureService`, and `Screen2AXFusion` are lazy, but `VisualVerifyLoop` is intentionally not injected into `AppBootstrap`; source-guard tests assert the loop stays unreachable for v1. · defer-to-v2
- Browser automation — gated-correctly · Pro-build `browser_*` tools wrap the optional `agent-browser` CLI with missing-binary errors; `agent-browser` is not installed here and no Claude-in-Chrome MCP surface was found. · defer-to-v2
- Local agent (LocalAgentLoop / LocalAgentPromptBuilder / ConfidenceRouter) — wired · `LocalAgentLoop` owns MLX/constrained grammar/tool parsing paths, and `LocalAgentGatewayPolicy` separates local deterministic answers from external-context routes with tests. · ship-in-v1
- MCP bridge — wired · `AppBootstrap` owns `MCPBridge`, which registers the `omega-mcp` builtin tool catalog and records executions through the local dispatcher. · ship-in-v1
- Halo Shadow index (W8.4 / W8.7) — wired · `AppBootstrap` opens the production `RustShadowFFIClient`, bootstraps vault notes/chats into Shadow, and feeds `ShadowSearchService` into `HaloController`; continuous FSEvents crawling remains deferred. · ship-in-v1
- RRF Fusion search (Phases 0-7) — wired · `SearchFusionHealthRow` reports the `EPISTEMOS_RRF_FUSION_V1` flag, latency, p95, per-source hits, and errors from `SearchIndexService` diagnostics. · ship-in-v1
- Provenance Console — wired · Settings exposes `ProvenanceConsoleView` over run/mutation/claim/agent/graph projections, and the Rust `epistemos_trace verify-replay` path exists for bundle verification. · ship-in-v1
- Note Editor Tiptap chrome — wired · Epdoc chrome, slash, bubble, KaTeX, block-context, insert-link, gutter, complexity-meter, thought badge, and bundled Tiptap assets are present with focused source guards/smokes. · ship-in-v1
- Memory + energy hardening — wired · `MLXInferenceService` idle unload and pressure paths call `MetalRuntimeManager.deepUnload`, runtime diagnostics log pressure state, and WK process-pool reset logic is present. · ship-in-v1
- LSP runtime — wired · `RustLSPTransport` uses in-process FFI to the tree-sitter Rust/Swift `LspKernel`; hover and definition behavior has Swift Testing coverage. · ship-in-v1
- iMessage routing — gated-correctly · The iMessage driver/settings surface is non-MAS only, starts disabled unless explicitly configured, and is hidden from the App Store build. · ship-in-v1
