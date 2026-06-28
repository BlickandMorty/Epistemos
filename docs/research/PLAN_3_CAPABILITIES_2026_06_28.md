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
>
> **★ CLONE-READY CODE PACKS:** (Pass 3) `PLAN_3_EDGEPARSE_CODEPACK` (§1 PDF→md vendoring + coexistence) ·
> `PLAN_3_PROVENANCE_CODEPACK` (§4 honest-chip fix + hover-lineage moat) · `PLAN_3_VAULT_MCP_CODEPACK` (§5c
> vault-as-MCP-server). (Pass 4) `PLAN_3_OBSCURA_TIER1_CODEPACK` (§2 usable in-app browser) ·
> `PLAN_3_EXTENSIBILITY_CODEPACK` (§5a install UI + §5b best-of preset) · `PLAN_3_APPLE_NATIVE_CODEPACK` (§6 QuickLook/
> VisionKit/thumbnails). All `_2026_06_28.md`. Real code + integration/flip checklists.

---

## 1. Fast PDF→Markdown  ★ (answers "the super-fast one")

**★ TRUTH (Pass-1 verified — you were right, you have NEITHER today) `[VERIFIED-CODE]`:** you CANNOT parse a PDF→md
in the shipped app. `liteparse` source IS vendored and the whole Swift import UI IS wired, but it's dead three ways:
the `liteparse-pdf` Cargo feature is **NOT in `default`** (engine returns `EngineNotWired`), **no `libpdfium.dylib` is
bundled** (zero `pdfium` hits in `project.yml`/build scripts), and the import button is hidden behind
`EPISTEMOS_LITEPARSE_PDF_V0` (**OFF**). Built honest-inert — never fakes a note. **And there is NO PDF viewer at all**
(zero `PDFView`/`QuickLook`; PDFKit appears once as a headless extractor in `VaultParser.swift`). So your instinct was
correct on both counts.

**Best clone targets (Pass-1b, deep) — vendor a primary + 2 complementary `[WEB]`:**

| Repo | Lang | MAS-safe (no Python / no C blob) | Speed | Fidelity | Role |
|---|---|---|---|---|---|
| **EdgeParse** (`edgeparse-core`, Apache-2.0) | **pure Rust, zero ML** | ✅ | **#1 (~0.007 s/doc)** | **#1 overall (tables/headings/reading-order)** | **PRIMARY** born-digital |
| **unpdf** (iyulab, MIT) | **pure Rust, zero C deps** | ✅ | Rayon-parallel | strong **CJK/RTL/multi-column** | multilingual fallback |
| **Apple Vision + PDFKit** (native) | ✅ first-party | fast (HW) | best on-device OCR | DIY md glue | **scanned/OCR lane** |
| liteparse (run-llama) | Rust core + **PDFium+Tesseract C++ blobs** | ⚠️ notarization risk | ~0.2–0.8 s | heuristic + turnkey OCR | **Pro-first** only |
| ~~pdf_oxide~~ | Rust | ✅ | 0.8 ms | thin md layer | skip for md (great extractor, not fidelity-md) |

**Build (reuse the entire existing UI — swap the engine behind the same FFI envelope):**
1. Vendor **EdgeParse** (`agent_core/vendor/edgeparse/`, Rust core only) → ProvenanceGate `direct_import`. Cargo feature
   `edgeparse-pdf` **ON for MAS** (no dylib, nothing to sign). Keep envelope `{"ok":true,"markdown":…}` → the wired Swift
   import UI + tests work unchanged. Flip the UI flag `EPISTEMOS_LITEPARSE_PDF_V0` on.
2. Vendor **unpdf** (`agent_core/vendor/unpdf/`, feature `parser-unpdf`) as the CJK/RTL/multilingual fallback.
3. **Scanned lane = Apple Vision/PDFKit** (Swift `ScannedPdfMarkdownService` — `VNRecognizeTextRequest` over page
   rasters, reuse EdgeParse geometry for block order). Keep **liteparse Pro-first** only (PDFium+Tesseract = notarization proof needed).

**★ PDF viewer + md COEXISTENCE (your exact idea — keep BOTH the original PDF and a parsed `.md`) `[INFERRED]`:**
- **Data model, ZERO migration:** on import, write the **original `.pdf`** verbatim into `<vault>/Imported PDFs/` AND a
  **parsed `.md` sibling**; the `.md` is the `SDPage` (file-first, as today); link them via the note's existing
  `frontMatterData` JSON → `source_pdf: "Imported PDFs/<name>.pdf"`, `source_kind: "pdf"` (front-matter is already
  arbitrary KV → no schema change). The `.md` = **edit + search truth** (flows into FTS/RRF/Spotlight/graph/editor);
  the `.pdf` = **view truth** (immutable provenance, always re-renderable/re-parseable). They never fight.
- **Default (pdf→md ON):** import → parse → **parsed note opens** + a persistent **"View original PDF"** button mounts
  the native viewer on `source_pdf` (round-trips back to the note).
- **2 settings:** `parsePDFOnImport` (default ON — OFF keeps only the viewable original, no `.md`) ·
  `defaultOpenForImportedPDF` `{ parsedNote (default) | originalPDF }`.
- **★ Plan boundary (no clash):** **Plan 2 (editor canonical) owns the PDF *VIEWER*** (PDFKit `PDFView`). **Plan 3 owns
  the PARSE engine + this link/storage contract.** Plan 2 only *consumes* the resolved `source_pdf` URL to mount
  `PDFView`; it must NOT invent its own PDF-import storage.

**MAS/Pro:** EdgeParse + unpdf + Apple Vision/PDFKit = **MAS-safe, on by default**; liteparse = Pro-first. Effort:
parser swap **LOW** (UI exists); coexistence **LOW** (one front-matter field + the "View original" button); viewer = Plan 2.

---

## 2. Obscura — in-app browser

**★ Pass-2 clarification (answers "why heavy / can I use it like a regular browser?"):** TWO different things got
bundled under one name. **(A) A browser TAB is LIGHT and behaves like a normal browser** — a `WKWebView` IS WebKit,
*the same engine as Safari*, so a `WKWebView` + address bar + back/forward lets you navigate, render modern JS sites,
log in, scroll, watch (non-DRM) video — by hand, exactly like Safari. MAS-safe. **(B) The "heavy" part is ONLY the
agentic automation** — the AI reliably reading the DOM, clicking the right element, filling forms, scraping across
arbitrary sites, plus anti-bot/stealth. That's the brittle, net-new, Pro-only work — NOT the browsing.
"I can't even see it" is correct: today both `WebKitBrowserEngine` and `ObscuraBrowserEngine` are `NotConfigured`
stubs (`browser_engine/mod.rs:273-364`) — nothing renders. Honest limits vs full Safari `[WEB]`: no Safari
extensions inside a WKWebView; some FairPlay-DRM premium video may not play; cookies/logins are isolated from Safari.

**★ Re-scoped into TIERS — pick where to stop:**
| Tier | What you get | Weight | Profile |
|---|---|---|---|
| **T1 — usable in-app browser** | a real tab you open + drive like Safari (navigate/login/scroll/non-DRM video) | **LIGHT** | MAS-safe |
| **T2 — + agent reads/extracts the open page** | the AI can read the current page → note/answer; you still drive | MEDIUM | MAS-plausible (read-only) |
| **T3 — full agent automation + stealth** | AI autonomously clicks/types/scrapes across sites + anti-fingerprint | **HEAVY** | Pro-only |
**Recommendation: START at T1** — wire a live `WKWebView` behind the existing `WebKitBrowserEngine` seam (instead of
`NotConfigured`) → turns "I can't see it" into a visible, usable browser fast. Climb to T2/T3 only if you want them.
The heaviness you worried about lives ONLY at T3. (Rest of the original heavy build = T3, below.)

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

**★ Pass-2 verdict (answers your "no local AI except Goose — what do I do with ColBERT?"): KEEP it SEARCH-ONLY,
CUT the tool-selector.** Your concern is exactly right, and resolving it is clean:
- **Use (b) tool-selection = app-side-agent plumbing → CUT.** It exists to narrow the tool catalog for a *local agent
  loop*. That loop is gone (Goose owns agents), and `tool_preflight.rs` has **NO live Swift wiring today anyway** (the
  named consumer `SchemaPreflightToolNarrowing.swift` doesn't exist — verified). Building a ColBERT tool-selector is
  exactly the "muddy app-side AI" you want to avoid → don't build it.
- **Use (a) vault-search rerank = pure SEARCH infra → KEEP (deferred/optional).** It lives entirely on the *data* side
  of the MCP boundary: it sharpens instant-recall + the vault results that **Goose itself queries via the
  vault-as-MCP-server (§5c)**. So a better reranker makes Goose's answers sharper **without ColBERT ever touching
  Goose's model, reasoning, or tool loop.** Zero new chat/agent path. Slots in as the `secondary` signal in
  `apply_eml_rerank` (`storage/vault.rs:521`) behind `EPISTEMOS_COLBERT_RERANK_V1`; RRF stays primary, untouched.

**Honest value (search-only):** an **enhancement, not a gap** (RRF + EML rerank already work). Real wins are narrow but genuine:
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

## 6. Apple-native maximization (owner-confirmed keep; Pass-1c)

The big ledger wanted "max out Apple-native frameworks." Baseline already in the app `[VERIFIED-CODE]`: NaturalLanguage,
Vision (OCR), AVFoundation, Speech (STT), AVSpeech (TTS), Translation, ScreenCaptureKit, CoreSpotlight, AppIntents,
CoreML. **Greenfield (absent):** PDFKit `PDFView`, QuickLook, VisionKit Live Text, QuickLookThumbnailing, PencilKit.

**Top-6 to prioritize (all MAS-safe, on-device, no new entitlement):**
1. **PDFKit `PDFView` viewer** (high/low) — free: selection/copy, zoom, page nav, find, `PDFThumbnailView`, `PDFOutline`
   TOC, `PDFAnnotation`. Wrap as `NSViewRepresentable`. **The view half of §1 coexistence — Plan 2 owns it.**
2. **QuickLook** (high/low) — `.quickLookPreview(_:)` previews ANY vault file (PDF/docx/iWork/images/csv) with zero
   per-format code. One file-row action covers dozens of types.
3. **Vision OCR + VisionKit Live Text** (high/med) — Vision (`VNRecognizeTextRequest`) already exists; add VisionKit
   `ImageAnalyzer` + `ImageAnalysisOverlayView` for selectable Live-Text on image/PDF previews → scanned PDFs become
   first-class searchable.
4. **QuickLookThumbnailing** (med/low) — `QLThumbnailGenerator` real thumbnails for PDF/file rows + the Imported-PDFs folder.
5. **Translation expansion** (med/low) — already wired in notes; extend to PDF selections + chat messages (near-zero effort, on-device).
6. **AppIntents / Spotlight for PDFs** (med/low) — expose "Open/OCR/Preview file" as Shortcuts/Siri actions; index imported PDFs in system Spotlight.

Deferred (still MAS-safe): PencilKit/`PDFAnnotation` markup, FileProvider. Needs-new-usage-string (out of scope): PhotosUI, EventKit, camera/document-scan.

## 7. Ingest capabilities (Pass-2 ledger re-scan — owner-wanted, were skipped)

The re-scan found concrete items you explicitly asked for that got flattened/omitted in the curation. These fit Plan 3
(standalone capabilities, MAS-safe, don't conflict with Goose-only AI):
- **arXiv pull** — search arXiv + ingest a paper's PDF/abstract/metadata into the vault (→ then PDF→md §1 parses it).
  Was **omitted entirely** from the curation. MAS-safe (arxiv.org API + the §1 PDF pipeline). Pairs with the web clipper
  (Plan 2). LOW effort.
- **Meeting/lecture note** — record audio → **on-device STT** (Apple Speech / local Whisper) → a note + AI summary.
  Was buried as one line; it's a flagship capability (Granola/Notion-AI territory), fully on-device, MAS-safe. Uses the
  Apple-native Speech framework (§6). MEDIUM effort.
- **Eidos→chat / "Retrieved by Eidos" panel** — fold into §4 (provenance moat): the closed-citation retrieval panel is
  the *visible payoff* of the moat; substrate is ~done, only the surfacing remains.

## ⏳ Owner-decision queue (hinges on "no local app-side AI except Goose")
The re-scan also surfaced **model-management** items you wanted — but they collide with the Goose-only-AI direction, so
they need your call before they enter Plan 3: **HuggingFace/GitHub model marketplace + bring-your-own-model**, the
**Settings model "stack"** (pick which models appear), the **on-device vision runtime (mlx-vlm)** for VLMs, and
**DeerFlow multi-agent research** (~80% built). Question for you: with AI consolidated to Goose, do you still want the
app to **install/manage local models** (which Goose/the runtime would then use)? If yes → these become Plan-3 sections;
if no → they're cut. Flagged, not assumed.

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
