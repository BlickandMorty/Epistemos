# PLAN 3 — Capabilities (2026-06-28)

> **The THIRD plan. Standalone.** Sibling to — and NOT overlapping — the other two:
> - **Plan 1 = Goose surface** (`GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md` etc.) — untouched.
> - **Plan 2 = Editor canonical** (`EDITOR_CANONICAL_PLAN_2026_06_27.md`) — owns markdown-truth, Tolaria-supersede,
>   code-editor v2, HTML workspace, web clipper, wikilinks, PDF *viewer*. Untouched.
> - **Plan 3 = THIS** — five capabilities the owner explicitly chose to keep, grounded fresh in the real code.
>   Does NOT reuse the 4,498-line ledger; the ledger is curated/closed in `LEDGER_CURATION_2026_06_28.md`.
>
> **Scope (owner-selected, 2026-06-28):** Fast PDF→MD · Obscura browser · native ColBERT encoder · Provenance
> moat · Extensibility (skill/MCP install + best-of preset + vault-as-MCP-server). Nothing else.
> Tags: `[VERIFIED-CODE]` read this pass · `[WEB]` web-validated · `[INFERRED]` proposed.

---

## 1. Fast PDF→Markdown  ★ (answers "the super-fast one")

**What you remembered is real.** The repo already has a Rust-native parser (`liteparse`, ~0.196 s/doc) — but it's
**gated inert on the App Store build** by a PDFium C-dylib it must bundle + code-sign, so today the app ships an
honest *stub*, not a working fast parser. That's the "less-capable one" feeling. `[VERIFIED-CODE]`

**The fast one to adopt = EdgeParse** (`edgeparse-core`, Apache-2.0, **pure Rust**): ~0.064 s/doc (**~3× faster**
than the vendored liteparse) and better tables/headings/reading-order on the same 200-doc benchmark — and crucially
**zero native deps: no PDFium, no JVM, no GPU, no OCR, no Python.** A single pure-Rust crate links straight into
`agent_core` and is sandbox-clean, so it can be **ON for the MAS build** — that's the difference between "Pro-gated
stub" and "ships live." `[WEB]`

**Current state `[VERIFIED-CODE]`:** vendored `agent_core/vendor/liteparse/` (run-llama v2.1.1, PDFium via dlopen);
FFI seam `agent_core/src/liteparse.rs:1-161` (`pdf_to_markdown(path) -> Result<String,_>` + UniFFI export); Swift
import UI fully wired (`Epistemos/LiteParse/*`, Settings health rows, NotesSidebar). Feature `liteparse-pdf` OFF by
default → honest `EngineNotWired`. Blocker = the PDFium-dylib bundling/signing tax.

**Build (like-for-like swap, reuse everything):**
1. Vendor `edgeparse-core` (Rust core only; skip PyO3/NAPI/WASM bindings) → ProvenanceGate `direct_import` (Apache-2.0).
2. Cargo feature `edgeparse-pdf` — **ON for MAS** (no dylib, no `build.rs` download, nothing to sign).
3. Keep the FFI envelope unchanged (`{"ok":true,"markdown":…}`) → the entire Swift import UI + tests work as-is.
4. **PDFKit fast-path in Swift** as the instant default for born-digital PDFs (first-party, zero deps); EdgeParse
   for structure; **Vision OCR** (in-process) for scanned pages. Keep the liteparse seam behind its flag as a
   reference/second-opinion (swappable — same envelope).

**MAS/Pro:** EdgeParse + PDFKit + Vision = **MAS-safe, on by default.** Effort: **LOW** (swap, not rebuild).

---

## 2. Obscura — in-app browser

A Pro/Developer-ID-gated in-app browsing surface (WKWebView-hosted) + Rust automation/scraping tools. **Heavy,
multi-phase** — be honest with yourself about that.

**Current state `[VERIFIED-CODE]`:** the seam exists, the engines are stubs.
- `BrowserEngine` async trait + `PageSnapshot`/`AxNode` (`agent_core/src/browser_engine/mod.rs:83-104`).
  `MockBrowserEngine` works + CI-tested. `WebKitBrowserEngine` (`:273-317`) and `ObscuraBrowserEngine` (`:319-364`)
  are **NotConfigured stubs** — nothing renders a page in-app yet.
- Honest capability map already shipped: `Epistemos/Engine/BrowserCapabilityStatus.swift:14-41` (live: web
  fetch/extract/crawl/search, SSRF-guarded, `nonPersistent()`; stub: Obscura engine, anti-fingerprint, tracker-block).
- Pro automation today = an **external `agent-browser` CLI** over a hardened subprocess (`tools/browser.rs`,
  registered `#[cfg(feature="pro-build")]`). MAS-safe HTTP tools (`tools/web.rs`: search/extract/crawl) are
  unconditional.
- Reusable patterns: `Epistemos/Goose/GooseWebSurfaceView.swift` (modern `WebView(WebPage)` + custom-scheme + bridge)
  and `Epistemos/Work/WorkRuntimeSupervisor.swift` (the honest Pro-gate `Status` enum — "launches NOTHING when
  unavailable, no fake green").

**Decision (from research):** **WebKit is the engine, not a Rust V8 browser.** The old Obscura+deno_core+V8 vision is
superseded (avoids the JIT-entitlement / duplicate-symbol minefield and stays MAS-conceivable).

**Build (phased):**
- **O-1** Swift `ObscuraWebHost` — offscreen `WKWebView` pool (copy Goose's `nonPersistent()`+scheme shape):
  navigate/snapshot(DOM-walk→`PageSnapshot` with `@e5` ref-ids)/click/type/scroll/read/extract via
  `evaluateJavaScript`; SSRF + scheme allowlist before any load.
- **O-2** UniFFI bridge → make `WebKitBrowserEngine` a **real** adapter (replace the NotConfigured stub;
  `DispatchQueue.main.async` in callbacks per CLAUDE.md).
- **O-3** Profile-aware `make_browser_engine(profile)` factory (WebKit MAS+Pro / Obscura Pro-when-built / Mock tests);
  re-point the `browser_*` registry block at the in-app engine, CLI becomes optional Pro fallback. Preserve per-action
  `RiskLevel`.
- **O-4** Transient SwiftUI browsing surface (summon on demand, e.g. ⌘⇧B) over the same WebView the agent drives →
  the agent's actions are visible.
- **O-5 (Pro)** Privacy stack: `WKContentRuleList` tracker-block (MAS-safe), `customUserAgent`, canvas/WebGL
  fingerprint dampening. **Honest label** — "fingerprint/UA hardening," NOT a full stealth bypass; authorized-use banner.
- **O-6** Agentic extract-to-schema scraper (URL + JSON-schema/CSS → LLM extract loop over rendered DOM); Eidos
  closed-citation as the grounding layer.

**MAS/Pro:** read-only viewing + MAS HTTP tools = both profiles. Automation (click/type/scrape) + privacy stack =
**Pro-gated, honest `.unavailable` on MAS, no hidden spawn.** Rust-native Obscura/V8 engine = **deferred** Pro-only,
owner sign-off. Effort: **HIGH** (the real `WebKitBrowserEngine` + UniFFI WKWebView automation is net-new).

---

## 3. Native ColBERT encoder (rerank + tool-select)

**The 2026-06-18 "no native path" verdict is STALE.** LiquidAI shipped **`LFM2.5-ColBERT-350M-GGUF`** (Q4_K_M 228MB…
Q8_0 378MB, 11 languages, per-token L2-normed output for MaxSim), and **the app already vendors full llama.cpp** with
the exact per-token API ColBERT needs — `LLAMA_POOLING_TYPE_NONE` + `llama_get_embeddings_ith`
(`LocalPackages/LocalLLMClient/.../llama.h:169,939`). So the in-process, **no-subprocess** path is real today. `[WEB]+[VERIFIED-CODE]`

**Current state `[VERIFIED-CODE]`:**
- Tool-select today is **purely lexical**: `agent_core/src/tool_preflight.rs` `score` (`:56`, name=3/keyword=2/desc=1).
  Its own doctrine comment (`:10-13`) **reserves the seam**: "the semantic/embedding preflight replaces `score`
  without changing this deterministic contract."
- Rerank today: RRF fuse (`epistemos-shadow/src/backend/rrf.rs`, k=60, primary) + EML rerank (`agent_core/src/
  eml_rerank.rs` + `storage/vault.rs:521`, secondary, flag OFF) + MMR diversity. **No late-interaction anywhere.**
- Embeddings: `Epistemos/Graph/EmbeddingService.swift` mean-pools `NLContextualEmbedding` to one vector — the
  per-token vectors already exist (`:125`) and are simply averaged away.

**Build (low blast-radius — two reserved seams):**
1. `agent_core/src/colbert/maxsim.rs` — `score(Q,D)=Σ_q max_d (q·d)` over L2-normed 128-d token matrices (~30 LOC,
   SIMD); always-compiled, feature-gated, unit-tested, inert until fed.
2. In-process libllama embedding FFI: load the GGUF with `pooling_type=NONE`, return per-token f32 matrices via
   `llama_get_embeddings_ith` (distinct from the Pro `llama-cli` subprocess lane — **do not reuse that**).
3. **Use (a) reranker:** RRF stays the candidate generator; ColBERT reranks its top-N as the `secondary` signal in
   `apply_eml_rerank` (`vault.rs:521`), behind `EPISTEMOS_COLBERT_RERANK_V1` (mirrors the EML gate). RRF untouched.
4. **Use (b) tool-select:** swap only the inner `score` fn behind a `ToolScorer { Lexical | ColBERT }` trait
   (`tool_preflight.rs:56`); pre-compute each tool's token matrix once at catalog build. `select_tools` + all 3
   downstream pipelines stay byte-identical.

**Honest value:** an **enhancement, not a gap** (tool-gating + RRF already work). Real wins are narrow but genuine:
multilingual/paraphrase/synonym queries the ≥3-char lexical scorer misses, and terse-query↔short-tool-desc matching.
**One ~250MB install serves BOTH consumers** and could later replace the mean-pooled single-vector arm. Gating:
`lfm1.0` license → ProvenanceGate; never commit weights; **exclude from the chat picker** (can't generate); Pro-gate
→ MAS only after the no-subprocess proof + RunEventLog + rollback. Effort: **LOW–MEDIUM.**

---

## 4. Provenance moat (visible + honest)  ★ your strongest differentiator

**Substrate is complete; the FFI is read-only; the chip is currently honest-by-omission.** `[VERIFIED-CODE]`
- Rust: `ClaimLedger` with full retraction (`ledger.rs:699` `retract_claim`, `:753` depth-capped `bfs_mark_at_risk`),
  `ReplayBundle`+BLAKE3 (`replay.rs`), Cognitive DAG (live writes route here via `dispatch::on_claim_committed`).
- FFI is **read-only** (`bridge.rs:3465/3497/3526` summary/recent/snapshot). **No claim-write / no retract FFI.**
- Swift: `AnswerPacket`/`VRMLabel` mirror; `AgentNoteEditProvenance`→EventStore (the real, buildable per-edit
  lineage); shipped Provenance Console (`ProvenanceConsoleView`), but its `retractionEventProvider` defaults to empty.

**The fake-chip finding `[VERIFIED-CODE]` (two surfaces):**
1. **The per-answer VRM chip renderer is DELETED** — `VRMLabelView` exists nowhere (grep = 0); the Rust comment
   claiming it renders is a stale lie. So **no "Verified" chip renders in chat today** (honest by omission). The
   latent trap: rebuilding `VRMLabelView` bound to `AnswerPacket.uiLabel` would show "Verified" with **zero backing
   claim** — `uiLabel` is hardcoded `.plausibleButUnverified` (`AnswerPacketEmitter.swift:397`) and the only claim is a
   tautological "turn completed: N tokens" self-witness.
2. **The Settings `VerifiedFloorChipStrip` green is computed from hand-written literals** (`productionWired &&
   falsifierPassed`, both passed in per `*HealthRow.swift`). A row can ship green with no real ledger/DAG entry. **This
   is the synthetic-chip vector that actually ships.**

**Honest fix (Swift-only, buildable now):**
- **Fix A** — `VRMLabel.honestLabel(for:) -> VRMLabel?`: returns `.verified` ONLY if the packet has ≥1 non-self-witness
  active claim with an evidence chain; `nil` (no chip) when claims are empty. Stop hardcoding the label; derive from
  the produced claims. Any future `VRMLabelView` binds to this, never to raw `uiLabel`. Test: no `.verified` unless a
  real active claim exists.
- **Fix B** — tighten `VerifiedFloorChipStripAuditTests` so a green also requires the named falsifier artifact to exist
  on disk AND (for ledger/DAG-backed rows) a non-zero claim/node count. Kills the literal-true loophole.

**Make-it-the-moat:**
- **Moat-1 (Swift, now):** rebuild `VRMLabelView` as a **hover-lineage card** on every assistant message — VRM label
  (honestly gated), claim list (kind/status), residency verification score, generatedAt vs acceptedAt, agent/model/tier
  from turn metadata. "A chip that proves itself when you hover."
- **Moat-2 retraction demo:** EventStore-based "undo this edit + downstream" is **buildable today** via
  `AgentNoteEditProvenance` sequence ordering. The **true ClaimLedger BFS cascade needs ONE new Rust FFI**
  (`record_claim_json` + `retract_claim_json`) — write through the DAG dispatch (Phase-8.E single-authority),
  **owner sign-off required** (CLAUDE.md canon-hardening; don't add the write FFI without it).
- **Moat-3 (now):** one-click "export this answer's verifiable lineage" via the snapshot/`.epbundle` + BLAKE3 (read-side
  already there) = the tamper-evident story.

**★ Critical:** Fix A must land **in the same change** as any `VRMLabelView` rebuild, or you reintroduce the exact fake
chip the owner is worried about. Effort: **LOW–MEDIUM** (Swift), the full retraction cascade = a gated Rust addition.

---

## 5. Extensibility — skill/MCP install · best-of preset · vault-as-MCP-server

**Mostly already built — this is wire + gate + surface, not a rebuild.** `[VERIFIED-CODE]`

**5a — Skill/tool/MCP install + management.** Skill install works end-to-end today (`SkillsSettingsView.swift` →
`skill_manage` create/edit/delete/install_from_{github,url,local}, `agent_core/src/tools/skills.rs:741`, with the
MAS/Pro gate already enforced at `:753`). External MCP: URL servers discovered from JSON (`mcp/url_servers.rs:56`,
HTTPS-only) but **read-only — no writer, no Settings UI**; stdio MCP spawns are **already hardened**
(`mcp/client.rs:221`). **Build:** a `MCPRegistryClient` (browse Smithery/mcp.so/glama/GitHub — networking, MAS-safe),
a `MCPUrlServerDirectory.write(...)` (one-click install of HTTPS servers — config write, MAS-safe), an
`ExtensionsDetailView` Settings surface (Skills · MCP Servers · Connectors), bearer tokens → Keychain.

**5b — Best-of preset.** Genuinely new (no preset concept exists). **Build:** a bundled `best_of_preset.json` +
`BestOfPreset.swift` — curated `{kind, id, why, minDistribution}` over what's real today (eidos_query, vault_search,
web_search, think, graph tools + vetted public skills/MCP). One-tap enable = a diff over the existing seams (surface
policy + skill install + URL-server writer); idempotent + reversible; honest gating (Pro-only rows show "unlocks in
Pro," never silently skipped).

**5c — Vault-as-MCP-server (the moat, outward-facing).** ~80% built: a **loopback bearer-token MCP HTTP server already
exists** (`WorkNativeMCPServer.swift` — `NWListener` loopback-only `:94`, per-launch token `:297`, constant-time auth
`:241`, Origin/DNS-rebind defense `:230`), and the **vault dispatcher already serves `resources/list`/`resources/read`
as `vault:///<rel>`, path-traversal-safe** (`omega-mcp/src/dispatcher.rs:292/320`). **Build:** a read-only `VaultMCPCore`
(vault_search/vault_read/eidos_query/graph-reads + resources only — no write/exec tools), reuse the transport verbatim,
**persistent** bearer token in Keychain (so users paste it into Claude Desktop/Cursor once) + rotate button, a Settings
toggle (off by default) showing `http://127.0.0.1:<port>/mcp` + masked token + copy-config.

**MAS/Pro split:**
| Capability | MAS | Pro |
|---|---|---|
| Skill create/edit/delete + local install | ✅ | ✅ |
| Skill install from GitHub/URL | ❌ honest-gated | ✅ |
| Add remote **URL** (HTTPS) MCP server | ✅ (config write) | ✅ |
| Add **stdio/subprocess** MCP server | ❌ show disabled | ✅ (hardened spawn) |
| Marketplace browse | ✅ (networking) | ✅ |
| Best-of preset | ✅ MAS subset | ✅ full |
| Vault-as-MCP-server | code-legal; **gate Pro** for review safety | ✅ primary home |

Effort: **5a LOW-MEDIUM · 5b LOW · 5c LOW-MEDIUM** (transport + dispatcher already exist).

---

## Suggested build order (within Plan 3)
1. **Fast PDF→MD** (LOW, MAS-shippable, immediate user value — and you already have the UI). 
2. **Provenance moat Fix A+B** (LOW, honesty-critical — do before any chip is rebuilt) → then Moat-1 hover card.
3. **Extensibility 5c vault-as-MCP-server** (LOW-MED, ~80% built — the outward moat) → 5a install UI → 5b preset.
4. **ColBERT** (LOW-MED, optional enhancement; the seams are reserved — land the inert `maxsim.rs` substrate anytime).
5. **Obscura** (HIGH, last — the only heavy net-new item; phase O-1…O-6, Pro-gated).

## NOT in Plan 3 (so the three plans never blur)
Editor/markdown/Tolaria/code-editor v2/HTML-workspace/web-clipper/wikilinks/PDF-*viewer* → **Plan 2**. Goose/Act/Work
agent surface → **Plan 1**. Everything else from the big ledger (models, voice, training, full-ports, etc.) → curated
in `LEDGER_CURATION_2026_06_28.md` (kept/deferred/cut there), not here.
