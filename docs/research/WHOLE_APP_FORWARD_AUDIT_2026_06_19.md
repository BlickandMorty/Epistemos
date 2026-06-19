# WHOLE-APP FORWARD AUDIT (S6, 2026-06-19)

Read-only research (subagent), code-grounded. Feeds DEEP_PLAN_AUDIT_HUB. Inventories CURRENT
app surfaces + readiness for the coming work. Does NOT repeat the clone/reskin/settings/tools/
competitor/consistency siblings.

## ⚠️ Structural finding: the 3-engine toggle does NOT exist yet as a primitive
- Sidebar `SidebarMode` = only `.myVault/.modelVaults/.system` (content sidebar, not the engine toggle).
- The "engine toggle" today = `CoworkChatMode` (`Engine/CoworkChatMode.swift`) = only `.chat` + `.act`, and **Act is a presentation over `operatingMode==.agent`, explicitly "not a new engine."** There is **NO `.work` mode and NO `ActEngine.{osaurusLocal,openClaw}` enum** in current code (grep empty). The owner's "3 buttons Chat/Act/Work on the search page" + Act=Osaurus + Work=Goose assume an axis the code hasn't modeled. **This is the #1 prep item** — build the Chat/Act/Work axis in `CoworkChatMode`/`ChatCoordinator`/`InferenceState` before Osaurus/Goose lanes can surface honestly.

## Surface inventory (maturity)
- **SOLID + ready to receive coming work:** Notes/Epdoc editor (most mature — Tiptap WKWebView + Brotli bundle), native Notes (but many overlapping editors), Graph (Metal real), Vault/Knowledge-Core, Search (tantivy+usearch+RRF), Eidos, Cognitive DAG (Rust), Provenance/ReplayBundle, MCP protocol, computer-use substrate (AXorcist/ScreenCaptureKit), MLX inference lane, Landing/search.
- **SOLID UI / PARTIAL execution:** Chat (tool/Eidos boxes ready, but tool loop gated — S4); MiniChat (shares chat model).
- **PARTIAL / demo-ish:** Capture, Model stack/picker (reductive vs LM-Studio), Workspace/Canvas (HTMLWorkspace — P7.2 broken).
- **PARTIAL-REAL voice:** AVSpeechSynthesizer TTS + SpeechAnalyzer/Whisper STT already wired into the composer (`EpistemosSpeechSynthesizer`, `ComposerMicButton`) — R-VOICE (Kokoro/MOSS) is an ADDITIVE upgrade over a ready seam.
- **STUBBED / NOT BUILT:** Act=Osaurus (inert conformer, `isLive=false`), Work=Goose (`runWorkSession` throws `engineNotWired`), OpenClaw (only an `AgentBackend` string — no UI host/scheme handler).
- **Routers/constrained-decoder STUBBED** (S1): MLX solid, but `DualBrainRouter`/`HybridRouter`/`ConfidenceRouter` dead, constrained decoder fake.

## Orphans / dead surfaces (prune or revive — IN PAIRS with dead backends)
True orphans (0 non-test refs): `Views/Skills/SkillEvolutionView.swift` (pairs with dead self_evolution/procedural_memory — S1/S2), `Views/Omega/ResearchRequestView.swift` (superseded by the in-composer deep-research button), `Views/Sessions/FSRSReviewSidebar.swift`, `Views/Chat/BTMView.swift`, `Views/Workspace/ArtifactHostView.swift` (only a doc-comment ref — REVIVE for the planned live-Artifacts/dashboards or prune). Legacy-but-reachable: `Views/Omega/OmegaPanel.swift` (legacy agent panel via StatusBar utility window — review prune vs reframe-as-tools-dashboard). **Prune views in pairs with their dead Rust twins or you leave half-dead paths.**

## Integration seams the coming work MUST NOT break
1. **`ChatCoordinator.swift` (6.3K lines)** — the chat-execution spine; every engine route/tool path/provider branch funnels here. Highest blast radius.
2. **`InferenceState.swift`** — `canActAsAgent`/`supportsAgentTier`/`preferredChatModelSelection`/`availableOperatingModes` — gates tool-attach (S4) AND `CoworkChatMode.actAvailable`. **Tools-repair + model-stack + 3-engine work ALL converge on ChatCoordinator+InferenceState — sequence them or they collide (top risk).**
3. **Theme bridge** `EpistemosTheme.resolved → .color / .nsColor → --epdoc-* CSS` — the single token source the reskin + OpenClaw skin ride. Don't fork.
4. **Shadow/RRF crawl roots** — crawls `<vault>/notes/**` + `<vault>/chats/**`; **Hermes session-search reads `<vault>/sessions/` which the index does NOT crawl (OQ-1) — reconcile before the session-search lift or it returns zero hits.**
5. **Engine seam protocols** (`ActOsaurusBridge`/`WorkBacking`/`AgentBackend`) — the `#if !EPISTEMOS_APP_STORE` INERT-conformer is the MAS-honesty firewall; a real conformer must keep `isLive=false` until live + no silent cloud fallback.
6. **Tool-event→UI render chain** (`.toolUse`/`.toolResult` → `InlineToolTranscriptSegment`/`ToolExecutionPreviewList`/`EidosRetrievedSection`) — intact; boxes empty only because no calls fire. **Fix the loop, not the UI.**
7. **`UtilityWindowManager` + `EpistemosDocumentController`** — new hosted surfaces (OpenClaw) mount through this, not a 4th window system.

## Top forward-readiness risks
1. 3-engine toggle missing as a primitive (foundational — build first).
2. ChatCoordinator+InferenceState are the convergence point for 3 workstreams — sequence.
3. Search-dir mismatch silently breaks Hermes session-search.
4. Canvas/ArtifactHostView broken/orphaned — no healthy surface for live-Artifacts; repair-or-rebuild decision needed.
5. Orphan UI ↔ dead backend pairs — prune in pairs.
6. MAS-honesty firewall fragility when arming Osaurus/Goose/OpenClaw.

**Net:** CONTENT surfaces (Notes/Epdoc, Graph, Vault, Eidos, provenance, search, computer-use) are solid and ready. AGENT/ENGINE surfaces (3-engine toggle, Act=Osaurus, Work=Goose, OpenClaw, canvas) are seams/stubs/missing — where the forward work lands AND risks most. #1 prep = model the Chat/Act/Work axis in CoworkChatMode/ChatCoordinator/InferenceState.

Key files: `Engine/CoworkChatMode.swift` · `App/{RootView,ChatCoordinator,AppBootstrap}.swift` · `State/InferenceState.swift` · `Views/Sidebar/SidebarModeStore.swift` · `ActOsaurus/ActOsaurusBridge.swift` · `Work/WorkBackend.swift` · the orphan views listed above.
