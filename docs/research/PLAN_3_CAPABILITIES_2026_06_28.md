# PLAN 3 — Capabilities (2026-06-28)

> **The THIRD plan. Standalone.** Sibling to — and NOT overlapping — the other two:
> - **Plan 1 = Goose surface** (`GOOSE_MASTER_BUILD_PROMPT_2026_06_27.md` etc.) — untouched.
> - **Plan 2 = Editor canonical** (`EDITOR_CANONICAL_PLAN_2026_06_27.md`) — owns markdown-truth, Tolaria-supersede,
>   code-editor v2, HTML workspace, web clipper, wikilinks, PDF *viewer*. Untouched.
> - **Plan 3 = THIS** — the owner-final capability set below, grounded fresh in the real code.
>   Does NOT reuse the 4,498-line ledger; the ledger is curated/closed in `LEDGER_CURATION_2026_06_28.md`.
>
> **Scope (owner-FINAL, 2026-06-28):** Fast PDF→MD · Provenance moat · Extensibility (skill/MCP install + best-of preset
> + vault-as-MCP-server) · Apple-native maximization · Landing-page buttons · Browser (lite native WKWebView tab for the
> App Store + `browser-use` Chromium robot for Pro) · arXiv pull · Meeting/STT note · Voice · Whole-app brand logos.
> **CUT:** ~~Obscura native engine~~ (→ browser-use) · ~~ColBERT~~ (no local model) · ~~local model-management~~ ·
> ~~three-engine Chat/Act/Work + Osaurus~~ (Goose-only). HTML Workspace / web clipper / wikilinks / PDF *viewer* = Plan 2.
> Tags: `[VERIFIED-CODE]` read this pass · `[WEB]` web-validated · `[INFERRED]` proposed.
>
> **★ PLAN 3 CODEPACK STATUS:** shipped/staged codepacks are tracked in the `_2026_06_28.md` files:
> (Pass 3 shipped) `PLAN_3_EDGEPARSE_CODEPACK` (§1 PDF→md vendoring + coexistence) ·
> `PLAN_3_PROVENANCE_CODEPACK` (§4 honest-chip fix + hover-lineage moat) · `PLAN_3_VAULT_MCP_CODEPACK` (§5c
> vault-as-MCP-server). (Pass 4 shipped) `PLAN_3_OBSCURA_TIER1_CODEPACK` (§2 usable in-app browser; historical filename,
> product name "Browser") · `PLAN_3_EXTENSIBILITY_CODEPACK` (§5a install UI + §5b best-of preset) ·
> `PLAN_3_APPLE_NATIVE_CODEPACK` (§6 QuickLook/VisionKit/thumbnails). (Pass 6 shipped)
> `PLAN_3_LANDING_BUTTONS_CODEPACK` + `PLAN_3_ARXIV_CODEPACK`. (Pass 7 staged Pro)
> `PLAN_3_BROWSER_USE_CODEPACK`. (Pass 8 shipped) `PLAN_3_VOICE_CODEPACK` +
> `PLAN_3_WHOLE_APP_LOGOS_CODEPACK`. (Pass 9 shipped) `PLAN_3_MEETING_STT_CODEPACK`. All real code +
> integration/flip checklists.

---

## ⚛️ HARDENING & THERMONUCLEAR REVIEW DOCTRINE (how this plan stays strict + safe)
This plan is built under the SAME strictness as the Goose plan (R-CODEREVIEW). It is binding — an implementing agent
must obey it, and the build prompt (`docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md`) carries it too.
- **Thermonuclear review (recurring):** run `[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)`
  over the touched code AT EACH stage + a full-app pass periodically. Honest, real findings only — correctness bugs,
  dead/stale code, honesty-constraint violations, perf, arch drift, contradictions. It's a recurring gate, not a one-shot.
- **Harden-before → build → re-harden-after:** every capability gets its own hardening pass + regression tests + a
  "HARDENED <item>" note before it's called done.
- **Deletion guardrail:** harden/dedupe/wire-up OVER delete. NEVER delete new/in-progress/owner-requested code; when
  uncertain KEEP + flag; commit any deletion separately (easy revert).
- **No-contradictions gate:** before a stage is done, grep this plan + the codepacks for any claim that contradicts it
  and fix the SOURCE. (The 2026-06-28 cross-plan audit found stale Obscura/ColBERT claims this way — keep doing it.)
- **PROVEN-DONE bar (5 criteria for any ✅):** real-state · live in-app · migrates existing data · end-to-end · witnessed
  by a re-runnable artifact. Build-green ≠ done.
- **Full-clone law:** whatever is cloned is cloned in FULL — settings and all, no capability lost (EdgeParse/unpdf full
  feature set; browser-use the COMPLETE app).
- **No hidden subprocess/Python on the MAS path; keys in Keychain; honest capability gating; @Observable; never block
  @MainActor** (CLAUDE.md NON-NEGOTIABLES). **No-collision** with Plan 1 (Goose) / Plan 2 (editor) — see "NOT in Plan 3".

---

## ⚛️ NATIVENESS & UNIFIED LOOK (binding 2026-06-29 — see `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`)
Everything Plan 3 ships joins the ONE unified Apple-native look (AppKit + WebView + Goose CONVERGE; shared SF Pro
`-apple-system` + shadcn Apple tokens (Action Blue #0066cc) + macOS HIG geometry + macOS-26 Liquid Glass + the
EXACT SwiftUI springs). **PLAN-3 split:** NATIVE = Apple-native shared views (QuickLook/VisionKit/Live-Text/
thumbnails) + landing-feature buttons + the lite Browser tab CHROME + arXiv/meeting/voice/provenance UI + the
"View original PDF" affordance/URL handoff into Plan 2's PDFKit viewer (do not re-invent the viewer). WEB = browser-use's Chromium UI (Pro, its OWN surface — reskin its
hosted web UI with the same tokens where feasible; HONEST that CDP-Chromium ≠ WKWebView). Native views = REAL
Liquid Glass (`Theme/GlassModifiers.swift`, `Views/Shared/UnifiedFrostedGlass.swift`); any hosted web panel (incl.
the lite Browser tab) = **transparent-over-glass** (`drawsBackground=false`) + SF Pro + theme tokens + the verified
springs (.smooth {0.5,0} · .snappy {0.5,0.15} · .bouncy {0.5,0.3}). GRAPH = already full AppKit/Metal → DO NOT
TOUCH. SF Symbols real only in native views; web panels keep web icons restyled (never bundle SF Symbols into a
webview). Deeply fluid ProMotion + MINIMAL; A/B pixel-diff = the bar. CODE-RESEARCH (real openable code, in-repo
first) + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive, no-contradiction/preserve-nuance/break-nothing).

## 1. Fast PDF→Markdown  ★ (answers "the super-fast one")

**★ SHIPPED (Pass-3 verified) `[VERIFIED-CODE]`:** PDF→Markdown import now has a real Plan 3 parser path. The
existing Swift import UI still calls the preserved `liteparse_pdf_to_markdown` FFI envelope, but the default MAS Rust
feature set is now `mas-build = ["edgeparse-pdf", "parser-unpdf"]`: EdgeParse is the primary in-process parser and
unpdf is the fallback. `EPISTEMOS_LITEPARSE_PDF_V0=0` remains an emergency kill switch, not the default state. Swift
unit-test hosts that do not link `agent_coreFFI` still see the honest `.notWired` fallback for PDFs; that is a
test-linking condition, not the shipped MAS parser state.

**Best clone targets (Pass-1b, deep) — vendor a primary + 2 complementary `[WEB]`:**

| Repo | Lang | MAS-safe (no Python / no C blob) | Speed | Fidelity | Role |
|---|---|---|---|---|---|
| **EdgeParse** (`edgeparse-core`, Apache-2.0) | **pure Rust, zero ML** | ✅ | **#1 (~0.007 s/doc)** | **#1 overall (tables/headings/reading-order)** | **PRIMARY** born-digital |
| **unpdf** (iyulab, MIT) | **pure Rust, zero C deps** | ✅ | Rayon-parallel | strong **CJK/RTL/multi-column** | multilingual fallback |
| **Apple Vision + PDFKit** (native) | ✅ first-party | fast (HW) | best on-device OCR | DIY md glue | **scanned/OCR lane** |
| liteparse (run-llama) | Rust core + **PDFium+Tesseract C++ blobs** | ⚠️ notarization risk | ~0.2–0.8 s | heuristic + turnkey OCR | **Pro-first** only |
| ~~pdf_oxide~~ | Rust | ✅ | 0.8 ms | thin md layer | skip for md (great extractor, not fidelity-md) |

**Delivered build:**
1. **EdgeParse vendored** at `agent_core/vendor/edgeparse/` with `edgeparse-core` as the MAS primary parser
   (`edgeparse-pdf`). The render path clears `source_path` before Markdown output so optional external helpers are not
   used on the MAS path.
2. **unpdf vendored** at `agent_core/vendor/unpdf/` and compiled through `parser-unpdf` as the fallback for failed or
   non-substantive EdgeParse output.
3. **Same FFI envelope preserved:** Swift decodes `{"ok":true,"markdown":...}` / `{"ok":false,"error":...}` from
   `liteparse_pdf_to_markdown`, rejecting oversized response/Markdown payloads and capping engine error strings before
   untrusted parsing/trimming work, so the import button, Settings row, and controller did not need a new UI contract.
4. **PDF-only scope enforced:** Office/image inputs are rejected before FFI on Swift and as `UnsupportedFormat` in Rust;
   no subprocess/sidecar fallback is introduced.
5. **Parser input envelope hardened:** Swift and Rust both reject symlink/hardlink/non-regular PDF paths, empty files, bodies over
   the 512 MiB cap, and missing `%PDF-` magic before the parser lane receives the path. Rust preflight also reopens the
   header read with `O_NOFOLLOW|O_CLOEXEC` and revalidates the opened handle before magic sniffing. Import materialization also
   revalidates the copied source PDF with a no-follow descriptor before streaming it into the vault, and the parser runs
   against the revalidated vault copy instead of the transient source path; Swift magic reads revalidate empty/oversized
   files after the final no-follow open, import status reports the copied `source_pdf` path, and import filename
   reservation has a hard attempt cap. Swift-side
   Foundation/file failures are mapped to bounded domain/code diagnostics before import status text, avoiding raw
   localized filesystem descriptions in the PDF import UI, with raw messages bounded before trimming and ellipsis kept
   inside the configured cap; sidebar status display values are control/whitespace-normalized before alert rendering.

**★ PDF viewer + md COEXISTENCE (keep BOTH the original PDF and a parsed `.md`) `[VERIFIED-CODE]`:**
- **Data model, ZERO migration:** on import, Plan 3 writes the **original `.pdf`** into `<vault>/Imported PDFs/` and a
  parsed `.md` SDPage sibling, linked through existing `frontMatterData` keys `source_pdf: "Imported PDFs/<name>.pdf"`
  and `source_kind: "pdf"`. The `.md` remains edit/search truth; the `.pdf` remains view/provenance truth.
- **Default (pdf→md ON):** import → parse → parsed note opens; the Plan 3 affordance exposes a "View original PDF"
  action only when `source_pdf` resolves inside the current vault. The source-PDF sheet revalidates no-follow `%PDF-`
  magic before PDFKit opens the URL, uses flat theme-token Find input chrome instead of rounded bordered fields, and caps
  file names, search text, outline labels, annotation traversal, and annotation labels before sidebar display with
  filename ellipsis inside configured caps.
- **2 settings:** `parsePDFOnImport` defaults ON; `defaultOpenForImportedPDF` defaults to `parsedNote`.
- **★ Plan boundary (no clash):** **Plan 2 (editor canonical) owns the PDF *VIEWER***. **Plan 3 owns the parse engine
  plus `source_pdf` storage/link contract.** Plan 2 should only consume the resolved `source_pdf` URL.

**MAS/Pro:** EdgeParse + unpdf are **MAS-safe and on by default**; run-llama/liteparse remains Pro/dev-only
(`liteparse-pdf`) because its PDFium/Tesseract lane needs separate notarization proof. Scanned/OCR lane remains future
Apple Vision/PDFKit work.

---

## 2. BROWSER = lite native tab (App Store) + browser-use (Pro automation)  [owner-confirmed 2026-06-28]
> **★ Resolution:** (a) **KEEP a lite native WKWebView "Browser" tab for the MAS build** = the **Obscura Tier-1 code**
> (`PLAN_3_OBSCURA_TIER1_CODEPACK`), kept as-is, just renamed/de-"Obscura"-fied — a real browser the user drives like
> Safari, App-Store-safe. (b) **ADD `browser-use` (Pro)** for power automation — see §9 (Chromium robot, reskinned UI in
> a webview, connected to Goose). The heavy native automation engine (old Obscura Tier 2/3) is **dropped** in favor of
> browser-use. Tier-1 codepack = LIVE; Tier-2 native-robot codepack = parked (browser-use replaces it).
> The historical Obscura research below is superseded by this split.

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
**T1 is shipped:** the standalone lite Browser tab (`BrowserView`, human-driven, NOT the agent engine seam) now turns
"I can't see it" into a visible, usable browser. Climb to T2/T3 only if you want them. The heaviness you worried about
lives ONLY at T3. (Rest of the original heavy build = T3, below.)

**Current state `[VERIFIED-CODE]`:** the user-driven Browser tab is live; the agent browser engines remain parked.
- `Epistemos/Views/Browser/BrowserView.swift` ships `BrowserURLGuard`, `BrowserTab`, SwiftUI browser chrome, and a
  non-persistent `WKWebView` wrapper with strict http/https navigation action/response policy, bounded-before-trim
  address input and bounded page-controlled title/address/error display state with ellipsis inside configured caps,
  sanitized URL-only reloads for new-window navigations, flat theme-token address-field chrome
  without a stroke outline, and teardown.
- `UtilityPanel.browser`, the Browser command (`⌘⇧B`), and `LandingFeatureButton.browser` all summon the same
  human-driven Browser surface.
- `BrowserEngine` async trait + `PageSnapshot`/`AxNode` still exist for the parked native robot seam. `WebKitBrowserEngine`
  and `ObscuraBrowserEngine` remain **NotConfigured stubs**; no agent drives the native Browser tab.
- Pro automation today = browser-use/`agent-browser` over Chromium/CDP behind Pro gates. MAS-safe HTTP tools
  (`tools/web.rs`: search/extract/crawl) remain unconditional.

**★ FINAL build (owner 2026-06-28) — the native robot O-1..O-6 below is PARKED, do NOT build it:**
- **App Store = the shipped lite native "Browser" tab ONLY** — standalone `BrowserView` from
  `PLAN_3_OBSCURA_TIER1_CODEPACK` (a human-driven `WKWebView` + address bar; NOT the `WebKitBrowserEngine` agent seam).
  The `WebKitBrowserEngine` stub STAYS `NotConfigured`. No agent drives this tab.
- **Pro automation = vendor the real `browser-use`** (§9) — Chromium robot, reskinned UI, exposed to Goose. Separate browser.

**~~Build (phased) O-1..O-6~~ — PARKED/superseded (the native WKWebView automation robot the owner CUT).** Kept for
reference only; do NOT execute. Original steps were: O-1 `ObscuraWebHost` agent pool · O-2 make `WebKitBrowserEngine`
real (it stays NotConfigured) · O-3 re-point `browser_*` registry at the in-app engine · O-4 agent-driven surface ·
O-5 privacy stack · O-6 agentic scraper. All superseded by browser-use (§9).

**MAS/Pro:** lite Browser tab = shipped and MAS-safe (human-driven, no robot). browser-use automation = **Pro only**
(Chromium, honest `.unavailable` on MAS). browser-use vendor codepack, staged payload, signed `BrowserUsePro.bundle`
packaging with `PACKAGE_RESULT.json` checkpoint evidence, loopback shell/control, task-submit dry-run UI, and gate smokes have landed. Release notarization remains
distribution ops, not a fake runtime gate. The loopback Web UI shell and runtime readiness/status text share
origin-only URL redaction rather than raw `absoluteString`; loopback host normalization and redacted URL diagnostics
are bounded before trim/compare, invalid loopback address failures use a bounded secret-aware host diagnostic instead
of echoing raw `host:port`, and signature payload enumeration is capped with symlink descendants skipped before target
resolution. The Developer ID resource bundler and runtime gate both validate the signed manifest plus package-result
checkpoint through no-follow regular-file evidence before a signed package can report ready. Browser-use Pro
gate/settings/runtime diagnostics bound raw status/domain/path strings, normalize control/whitespace characters, and keep
ellipsis inside configured caps before display. Decoded browser-use settings JSON is validated before returning UI/runtime
state, not only before saves or launch planning.

---

## 3. ~~Native ColBERT encoder~~ (CUT, 2026-06-28)
> **★ ColBERT is CUT** — owner is not using a local model, so no ColBERT. Vault search stays on the existing RRF + EML
> rerank (already shipped). The text below is historical research — superseded.


_(Historical ColBERT research removed — it contradicted the CUT. See git history if needed.)_

## 4. Provenance moat (visible + honest)  ★ your strongest differentiator

**Substrate is complete; the FFI is read-only; the shipped Swift chip is now honestly gated.** `[VERIFIED-CODE]`
- Rust: `ClaimLedger` with full retraction (`ledger.rs:699` `retract_claim`, `:753` depth-capped `bfs_mark_at_risk`),
  `ReplayBundle`+BLAKE3 (`replay.rs`), Cognitive DAG (live writes route here via `dispatch::on_claim_committed`).
- FFI is **read-only** (`bridge.rs:3465/3497/3526` summary/recent/snapshot). **No claim-write / no retract FFI.**
- Substrate health FFI/JSON fallback status maps external failures to bounded domain/code diagnostics before UI display,
  with raw message/domain strings bounded before trimming and ellipsis inside configured caps.
- Swift: `VRMLabel.honestLabel(for:)` gates every per-answer label; `AnswerPacketEmitter` derives stored labels through
  the honest gate for Rust-produced packets; `VRMLabelView` renders only `honestLabel(for:)` and never reads raw
  `packet.uiLabel`; `ChatMessageVRMLabelView` hydrates packets through `LatestAnswerPacketSink`; the hover-lineage card
  bounds runtime-fed metadata, claim text, and displayed claim count before SwiftUI render, before trimming and keeps
  ellipsis inside configured caps, filters non-finite verification scores before display, and `VRMLineageExport`
  copies deterministic full-fidelity verifiable lineage JSON from the hover card without Rust writes, encoding non-finite
  residency floats deterministically instead of returning `encoding_failed`. Durable `AnswerPacketStore`
  JSONL uses regular-file/no-follow reads and writes, rejects append lines or projected post-append logs over 8 MiB,
  rejects symlinked log directories before opening the file, and caps read/restore decoding at 8 MiB.
- `VerifiedFloorChipStrip` green now requires `productionWired && falsifierPassed && artifactSatisfied &&
  liveBackingSatisfied`. `requiresLiveBacking: .ledger/.dag` probes `RustProvenanceLedgerClient`/`RustCognitiveDagClient`;
  declared artifact backing requires a readable regular non-symlink file. `AnswerPacketHealthRow` opts into ledger
  backing. `FalsifierArtifactsHealthRow` shallow-enumerates a capped set of falsifier artifact candidates, requires a
  readable bounded regular `result.json`, reads it through a no-follow regular-file envelope, and skips symlinked artifact
  directories. Verified-floor pill tints are sourced from `UIState.theme` semantic success/warning/error/muted tokens,
  not raw SwiftUI colors.
- `AgentNoteEditProvenance`→EventStore remains the real, buildable per-edit lineage; shipped Provenance Console
  (`ProvenanceConsoleView`) is read-only, its `retractionEventProvider` defaults to empty, and
  `ProvenanceConsoleProjectionService` bounds projection counts, caps untrusted display values, and normalizes
  control/whitespace characters before GenUI render.

**The fake-chip vector is closed for shipped Swift per-answer chips `[VERIFIED-CODE]`:**
1. `VRMLabelView` exists again, but it binds only to `VRMLabel.honestLabel(for:)`; empty packets render no chip, and
   `.verified` requires an active empirical/mathematical/code-invariant claim with an ACS verification anchor;
   UAS remains address identity and cannot promote a claim by itself.
2. Settings rows can no longer force green with literals once they declare artifact or live backing. Provenance-facing
   `AnswerPacketHealthRow` declares ledger backing; remaining rows keep source-compatible defaults until deliberately
   opted in.

**Make-it-the-moat, remaining work:**
- **Moat-2 substitute (delivered):** the Provenance Console now renders an EventStore-derived
  `AgentEditSuperseded` trace from committed `AgentNoteEditProvenance` / `MutationEnvelope` rows on the same artifact,
  so "this edit was superseded by edit X" is visible without a second write authority.
- **True ClaimLedger cascade (still blocked):** the full BFS cascade needs ONE new Rust write FFI
  (`record_claim_json` + `retract_claim_json`) — write through the DAG dispatch (Phase-8.E single-authority),
  **owner sign-off required** (CLAUDE.md canon-hardening; don't add the write FFI without it).
- **Moat-3 (delivered):** one-click "Copy lineage JSON" exports the visible answer's verifiable lineage snapshot from
  the hover card. Snapshot/`.epbundle` + BLAKE3 read-side packaging remains available for deeper bundle exports.

Effort remaining: none for the EventStore demo; the full ClaimLedger cascade remains a gated Rust addition.

---

## 5. Extensibility — skill/MCP install · best-of preset · vault-as-MCP-server

**Shipped Plan 3 surface; remaining work is optional hardening, not first wiring.** `[VERIFIED-CODE]`

**5a — Skill/tool/MCP install + management.** Skill install works end-to-end today (`SkillsSettingsView.swift` →
`skill_manage` create/edit/delete/install_from_{github,url,local}, `agent_core/src/tools/skills.rs:741`, with the
MAS/Pro gate already enforced at `:753`). Skills settings status text caps skill-manager messages and maps external
caught Swift/Foundation failures to bounded domain/code diagnostics before SwiftUI display, with raw message/domain
strings bounded and control/whitespace-normalized before trim/validation. External HTTPS URL MCP now
has the shipped Swift trio:
`MCPRegistryClient` (Smithery/mcp.so/Glama/GitHub browse, network-read only, bounded fields/limits, secret-bearing remote
or GitHub repo URLs filtered, registry display fields raw-capped and control-stripped, redirected responses must stay on
the requested HTTPS host/path),
`MCPUrlServerDirectory.write/install/uninstall` (bare-array HTTPS config writer, no token values,
final-symlink/non-regular config reads plus symlinked config-directory components rejected, 256 KiB config cap). Rust URL
server discovery mirrors that no-userinfo/query/fragment URL policy, strict env-key shape, inline-token rejection, and
256 KiB no-follow read envelope before forwarding config to the provider, and
`ExtensionsDetailView` (Skills · MCP Servers ·
Connectors · browser-use). MCP server settings status text caps success/failure messages and maps external config-write
failures to bounded domain/code diagnostics before SwiftUI display, with raw failure/domain strings and success-message display names
bounded and control/whitespace-normalized before trimming or punctuation validation; write-error LocalizedError descriptions are bounded at the source before any
SwiftUI status layer can render them. `MCPBridge.dispatch` rejects oversized JSON-RPC
requests before policy parsing or Rust dispatch, and its Swift policy-gate responses bound denied tool names plus
scalar JSON-RPC request IDs before echoing them. `ToolTierBridge` list/execution failures remain visible but external
caught errors are bounded to domain/code
diagnostics and tool JSON error payloads are capped before surfacing, with raw message/domain strings bounded before
trimming and ellipsis inside configured caps. Stdio MCP spawns remain hardened and Pro-only
(`mcp/client.rs:221`).

**5b — Best-of preset.** Shipped: `Epistemos/Resources/best_of_preset.json`, `BestOfPreset.swift`, and
`BestOfPresetCard`. Apply is idempotent and reversible for owned remote-MCP rows; built-ins report `.alreadyEnabled`;
Pro-only skill rows show `.proLocked` instead of silently enabling. The bundled manifest and receipt files are bounded
regular-file JSON reads and reject final symlinks. Apply/revert row failure text is capped and
control/whitespace-normalized, with external caught failures mapped to bounded domain/code diagnostics before display.

**5c — Vault-as-MCP-server (the moat, outward-facing).** Shipped: `VaultMCPCore` (read-only tools/resources allowlist),
`VaultMCPServer` (loopback `/mcp`, reuses `WorkNativeMCPServer` auth/framing helpers), `VaultMCPTokenStore` (persistent
Keychain bearer + rotate), `VaultMCPHost` (off-by-default lifecycle), `VaultMCPServerSettingsRow` (masked token +
trusted-loopback-validated structured JSON client config copy), and the Rust resource-dispatch parity adapter. The host uses `ChatToolTier.readOnly` plus
`allowedToolNames: Set(VaultMCPCore.readToolNames)` while the core rejects writes before executor dispatch. Core
JSON-RPC handling and the loopback HTTP server both cap request bodies at 8 MiB before JSON parsing/dispatch; the core
also requires a JSON-RPC 2.0 object envelope, caps echoed string request IDs and protocol error diagnostics, and rejects
overlong relative vault paths before containment/file work. Listener failure status is bounded to domain/code
diagnostics, with raw listener/domain strings and protocol diagnostic strings bounded and control/whitespace-normalized before trim/validation. Host registration scope canonicalizes vault roots so symlink aliases do not create stale or mismatched
read-only servers.
`resources/list` and `resources/read` delegate to `MCPDispatcher.dispatch()` after `set_vault_root`; `tools/list` and
`tools/call` stay on the Swift read-only surface so write verbs are never advertised by the app-hosted server. Rust
resource reads use a dedicated Markdown-only path with the same 8 MiB cap, hidden/symlink refusal, regular-file check, and
UTF-8 rejection as the Swift fallback, instead of delegating to the broader `vault.read` file tool.
Settings start/rotate completions re-check the active canonical vault path before mutating UI state.
Vault MCP host retries discard both terminal `.failed` listeners and synchronous `start()` throws before the next start
attempt, so Settings retry creates a fresh loopback listener.

**MAS/Pro split:**
| Capability | MAS | Pro |
|---|---|---|
| Skill create/edit/delete + local install | ✅ | ✅ |
| Skill install from GitHub/URL | ❌ honest-gated | ✅ |
| Add remote **URL** (HTTPS) MCP server | ✅ (config write) | ✅ |
| Add **stdio/subprocess** MCP server | ❌ show disabled | ✅ (hardened spawn) |
| Marketplace browse | ✅ (networking) | ✅ |
| Best-of preset | ✅ MAS subset | ✅ full |
| Vault-as-MCP-server | compiled; **gated/hidden for review safety** | ✅ primary home |

Effort remaining: none for first wiring; Rust resource byte-parity is now live. Future work is polish only.

---

## 6. Apple-native maximization (shared components shipped; Plan 2 owns mounts)

The big ledger wanted "max out Apple-native frameworks." Baseline already in the app `[VERIFIED-CODE]`: NaturalLanguage,
Vision (OCR), AVFoundation, Speech (STT), AVSpeech (TTS), Translation, ScreenCaptureKit, CoreSpotlight, AppIntents,
CoreML. **Plan 3 shared components are now present:** QuickLook preview (`FilePreview.swift`), VisionKit Live Text
overlay (`LiveTextImageView.swift`), and QuickLookThumbnailing (`FileThumbnail.swift`) under `Views/Shared/`, with
source guards proving no Plan 1, Plan 2, or Pro-only runtime drift. QuickLook and thumbnail URLs go through a shared
`O_NOFOLLOW` + `fstat` bounded regular-file envelope with a 512 MiB cap, while Live Text analysis rejects invalid or
oversized in-memory images before invoking VisionKit, and thumbnail requests reject non-finite/oversized dimensions and
scale before generation. QuickLook preview titles keep ellipsis inside configured caps. **Still not Plan 3-owned:** PDFKit `PDFView` viewer and PencilKit annotations; the PDF viewer
remains Plan 2.

**Top-6 to prioritize (all MAS-safe, on-device, no new entitlement):**
1. **PDFKit `PDFView` viewer** (high/low) — free: selection/copy, zoom, page nav, find, `PDFThumbnailView`, `PDFOutline`
   TOC, `PDFAnnotation`. Wrap as `NSViewRepresentable`. **The view half of §1 coexistence — Plan 2 owns it.**
2. **QuickLook** (done as shared Plan 3 component) — `FilePreviewController`, `FilePreviewButton`, and `.filePreview(_:)`
   preview already-granted vault URLs after no-follow regular-file and 512 MiB envelope checks. Plan 2 owns consumer mounts.
3. **Vision OCR + VisionKit Live Text** (shared component done) — `LiveTextImageView` wraps `ImageAnalyzer` +
   `ImageAnalysisOverlayView`, rejects invalid or oversized images before analysis, returns recognized text to
   consumers, and does not index or edit Plan 2 surfaces itself.
4. **QuickLookThumbnailing** (shared component done) — `FileThumbnailer` + `FileThumbnailView` produce thumbnails with
   fallback symbols and reject invalid, unreadable, symlink, non-regular, oversized, non-finite, or over-scale inputs
   before generation.
5. **Translation expansion** (med/low) — already wired in notes; extend to PDF selections + chat messages (near-zero effort, on-device).
6. **AppIntents / Spotlight for PDFs** (med/low) — expose "Open/OCR/Preview file" as Shortcuts/Siri actions; index imported PDFs in system Spotlight.

Deferred (still MAS-safe): PencilKit/`PDFAnnotation` markup, FileProvider. Needs-new-usage-string (out of scope): PhotosUI, EventKit, camera/document-scan.

## 7. Ingest capabilities (arXiv shipped; meeting/STT tracked separately)

The re-scan found concrete items you explicitly asked for that got flattened/omitted in the curation. These fit Plan 3
(standalone capabilities, MAS-safe, don't conflict with Goose-only AI):
- **arXiv pull — SHIPPED (Pass 6):** search arXiv, parse Atom metadata, download the PDF, convert through the local
  PDF→md importer, and write a file-first vault note with abstract, parsed full text, bounded metadata frontmatter, and
  `source_pdf` pointing at the copied PDF under `<vault>/arXiv/`. The landing button opens `ArxivSearchView` as a sheet.
  MAS-safe (arxiv.org API + the §1 PDF pipeline); Atom parsing disables external entity resolution and caps parsed
  papers/field growth inside the 5 MiB response envelope; final Atom response URLs must stay on the requested HTTPS
  host/path/query; search query length and network-fed SwiftUI display strings are bounded and
  control/whitespace-normalized before display; abstract text written into the note body is bounded before file
  materialization; successful ingest status reports the vault-relative `source_pdf` path; the search field uses flat
  theme-token input chrome; request/parser/status failures are mapped to bounded
  domain/code diagnostics; downloaded temp PDFs are opened with `O_NOFOLLOW`,
  regular-file checked, symlink rejected, capped at 128 MiB, magic-sniffed, and renamed to `.pdf` before parsing;
  sheet close cancels live work and clears search/ingest busy indicators; failures create no note and unexpected external errors are reported with bounded domain/code diagnostics instead of
  raw localized filesystem strings.
- **Meeting/lecture note — SHIPPED (Pass 9):** user-driven on-device Apple Speech/SpeechAnalyzer capture through
  `LiveVoiceInputService`, buffered by `MeetingNoteCaptureService`, then saved through `TextCapturePipeline` as a
  searchable note with `source=meeting_stt`, `source_kind=audio_transcript`, `captured_at`, `duration_seconds`, and
  `stt_engine=apple_speechanalyzer` frontmatter. The landing button opens `MeetingNoteView` in the Plan 3 utility
  window; the live transcript buffer is capped to the capture pipeline envelope before save; progress/status/error
  display values are bounded before UI state; finalize failures use bounded categorical diagnostics instead of raw
  localized filesystem descriptions; toolbar status text truncates before it can expand the row; auto-stop follows the
  dictation preference with capture-generation and silence-window token guards, manual stop/save stays available, and
  window teardown drains pending final/partial text before clearing the shared voice facade; repeat Save is disabled after `.saved` so the same
  transcript cannot create duplicate notes.
  No hidden audio retention, no cloud STT, no Whisper/Kokoro/Python/subprocess on the MAS path.
- **Eidos / "Retrieved by Eidos" panel** — fold into §4 (provenance moat): Eidos-origin `VaultRecallTrace` records now
  retain bounded candidate previews in `VaultRecallMetrics` and the Vault Recall health row renders a visible
  "Retrieved by Eidos" closed-citation panel. A per-answer chat card still requires an answer-bound trace pointer so a
  global last trace is never misbound to the wrong response.

## Owner decisions (2026-06-28)
- **🔴 CUT — local model-management.** Owner: "no" to HuggingFace/BYOM model marketplace, the Settings model "stack",
  the mlx-vlm vision runtime, and DeerFlow. AI is consolidated to Goose; the app does NOT install/manage local models.
- **🟢 NEW REQUIREMENT — every Plan-3 feature is a LANDING-PAGE BUTTON.** Each capability must be a button/shortcut on
  the landing page for one-tap access (e.g. a **"Browser"** button → the native Browser utility panel). See §8.
- **🟢 BROWSER (owner-confirmed 2026-06-28) = lite native WKWebView tab (App Store) + `browser-use` (Pro automation).**
  Keep a lightweight native browser tab for the MAS build = the **Obscura Tier-1 WKWebView code, KEPT** (just drop the
  "Obscura" heavy-automation name/framing → call it "Browser"). PLUS vendor the real **`browser-use`** (Chromium, Pro),
  web UI reskinned in a webview, connected to Goose, for power automation. ⚠️ browser-use drives **Chromium** (not
  WKWebView) — the lite tab is for human browsing; browser-use's Chromium is the robot. Native Tier-2 robot (Option B)
  superseded by browser-use. See §2/§9.
- **🔴 CUT — ColBERT.** Owner: "not using the model… I don't think I should use the model then." No local model →
  no ColBERT. §3 cut.
- **🟢 RECOVERED — narrowed-scope issue is complete.** Every owner-wanted item is now homed in a plan. HTML Workspace
  + web clipper + PDF viewer + editor-graph items belong to Plan 2; Voice + whole-app logos stay in Plan 3. See §10.

## 8. Landing-page feature buttons (owner requirement, shipped Pass 6) — code: `PLAN_3_LANDING_BUTTONS_CODEPACK`
Every Plan-3 capability is a one-tap button on the landing page (`LandingView` `:37`, the existing `landingPixelCommands`
grid `:492`). `LandingFeatureButton` enum (pdfImport/arxiv/provenance/extensions/vaultMCP/browser/browserUsePro/
meetingNote/voice) reuses the existing `PixelLandingCommandTile` and summons Plan 3-owned surfaces only:
`UtilityWindowManager.showSettings(section: .provenance)`, `UtilityWindowManager.showSettings(section: .skills)`,
`UtilityWindowManager.showSettings(section: .voice)`, `UtilityWindowManager.show(.browser)`,
`UtilityWindowManager.show(.meetingNote)`, the arXiv sheet, and `LiteParsePDFImportController.importPage`.
Honest compile-time Pro pills; unavailable/help/status text is bounded and control/whitespace-normalized, then shown in
tooltips and alerts with ellipsis inside configured caps.
Adding a feature = 1 enum case + 1 switch line.
Pure additive UI, MAS-safe.

## 9. Browser automation + browser-use + Goose (Pass 5 honest verdict)
**The owner asked for two things that are in TENSION — they can't be the same thing:**
- **`browser-use` (the repo) drives ONLY Chromium (CDP/Playwright), NOT WKWebView.** So it **cannot** drive Obscura
  (WebKit). browser-use is Python + MIT + 101k★, "desktop app" = a Gradio web-UI server (not native). Embedding it =
  **Pro/Developer-ID only** (bundle Python 3.11 + Playwright **Chromium** ~hundreds of MB + host its Gradio UI in a
  WebView + reskin CSS). The robot would drive a **separate bundled Chromium**, invisible to the in-app Obscura.
- **Goose ALREADY has the same category of robot today** `[VERIFIED-CODE]`: 11 browser tools (`browser_navigate/click/
  type/snapshot/scroll/...`, `agent_core/src/tools/browser.rs` + `registry.rs:2676-2750`) via an external `agent-browser`
  CLI over Chromium/CDP — **Pro-only**, user-installed binary.
- **"Robot heaviness":** agentic browser automation is the **least reliable** agent category (DOMs change, anti-bot,
  CAPTCHAs, login expiry, CDP/Chrome version drift — browser-use itself keeps rewriting its driver). Worth it only for
  **bounded, repeatable tasks on cooperative sites**, not "do anything anywhere." Heavy maintenance for a solo dev.

**★ FINAL decision (owner 2026-06-28) — the native Option-B robot is NOT built:**
- **App Store build = lite native WKWebView "Browser" tab, human-driven, NO robot** (the Obscura Tier-1 codepack).
- **Pro automation = vendor the REAL `browser-use`** (browser-use + web-ui + cdp-use + Python + Chromium), reskin its
  web UI in a WebView, expose to Goose as MCP tools. browser-use drives **Chromium** (not the WKWebView tab). The
  vendor codepack, settings contract, staged payload, signed Pro packaging, runtime shell, and adapter lane have landed;
  release notarization remains distribution ops; the loopback shell/control and task-submit dry-run UI smokes have
  landed; the Pro gate
  rejects symlink-routed, non-regular, or >1 MiB vendor manifests before no-follow JSON decode and rejects staged
  artifact symlink aliases before file/directory shape checks; runtime status/domain/path diagnostics are bounded,
  path-redacted, and control/whitespace-normalized before Settings display.
  Full-clone requirement: the COMPLETE browser-use app, settings and all, no capability lost.
- ~~Option B (native `WebKitBrowserEngine`-driven robot)~~ = **PARKED/superseded** by browser-use — do NOT build it
  (the owner cut the heavy native automation engine). The `WebKitBrowserEngine` stub stays `NotConfigured`.

## ★ CLONES LEDGER — what you'll actually vendor (honest)
Most of Plan 3 is **native code reusing your own seams — NOT repo clones.** The real external clones:
| Item | What's cloned/added | License | MAS/Pro |
|---|---|---|---|
| **EdgeParse** (`edgeparse-core`) | Rust PDF→md primary | Apache-2.0 | MAS |
| **unpdf** | Rust PDF→md multilingual fallback | MIT | MAS |
| liteparse | already vendored (keep, Pro-first) | Apache-2.0 | Pro |
| **browser-use + web-ui + cdp-use** | the FULL browser-use app (Python+Chromium robot), settings and all, reskinned | MIT | **Pro only** |
**Native (NO clone):** provenance moat · vault-as-MCP-server · lite native Browser tab · Apple-native (QuickLook/VisionKit/
thumbnails) · extensibility install UI + best-of preset · landing buttons · arXiv · meeting/STT · voice · whole-app logos.
So you clone **2 repos for the App Store (EdgeParse + unpdf)** + **browser-use for Pro**; everything else is your own code.

## 10. Scope recovery complete (owner: HTML Workspace + other wanted items were homed)
Scope recovery is complete; do not re-open Plan 2 editor work inside Plan 3.
- **DONE (2026-06-28):** every owner-wanted item is now homed in a plan (the transient SCOPE_RECOVERY doc was folded
  in + retired). HTML Workspace + web clipper + PDF viewer + the editor-graph trio →
  **Plan 2 §13** (added there). Voice + whole-app logos → §11 below. The full ledger remains in `LEDGER_CURATION`.

## 11. Recovered additions (owner-confirmed 2026-06-28)
Folded in as clean Plan-3 capabilities:
- **Voice — STT SHIPPED; TTS KOKORO-ONLY GATED (Pass 8):** live Apple STT facade through `LiveVoiceInputService`,
  consumer-backed Auto/Manual toggles, Kokoro-only read-aloud availability, and legacy Apple voice compatibility helpers
  are wired with
  partial/final transcript output capped to the capture pipeline envelope and finite/clamped download progress plus
  capped, domain/code-redacted status/error text for UI display, with raw status/domain strings bounded and
  control/whitespace-normalized before punctuation validation; status ellipsis stays inside the configured cap.
  `EpistemosSpeechSynthesizer.speak()` refuses playback while the Kokoro gate is not ready; with a checked Pro
  `mattmireles/kokoro-coreml` package, the linked native
  Swift/CoreML `KokoroPipeline` path tokenizes supported raw vocabulary text, synthesizes 24 kHz PCM, and plays through
  `AVAudioEngine` with observable read-aloud progress derived from `AVAudioPlayerNode` render time.
  Read-aloud/Quick Capture/Settings controls surface TTS unavailable instead of silently falling back
  to AVSpeech when that gate is not ready.
  `VoiceInputButton` consumes the live facade and no longer points at the removed composer stub. Kokoro-82M is Pro-only
  status-gated and rejects symlink-routed, hardlinked, non-regular, placeholder, oversized, invalid-manifest, or digest-mismatched
  model artifacts with integer declared package byte caps and bounded, control/whitespace-normalized model-relative
  status diagnostics with ellipsis inside configured caps and requires the complete manifest-declared duration/bucket
  CoreML package families plus exact runtime vocab/HNSF/starter-voice shapes before reporting ready. A checked package reports `packageReady` with manifest-derived package evidence
  (Core ML package count, voice count, runtime asset count, checked file count, declared bytes, and a bounded printable
  bundle profile) and flips
  `isReady=true` only when the native playback path is linked. Developer ID builds now show a Pro-only Voice settings
  status/runtime affordance labelled `TTS unavailable` / `Kokoro neural voice` plus a local checked-package
  installer/remover; no Apple AVSpeech fallback, committed model asset, network downloader, Python, subprocess, or
  MAS-visible Kokoro row enters the App Store path.
- **Whole-app brand-logo coverage — SHIPPED:** the non-model `IntegrationBrand` registry and
  `IntegrationBrandMarkView` cover Plan 3 extensibility rows, skill rows, arXiv, Browser, browser-use diagnostics,
  Meeting, local Hugging Face skill/connector marks, settings sidebar marks for branded Plan 3 rows, and every Plan 3 landing feature button without runtime logo downloads or official-logo claims. Classifier input for arbitrary MCP/skill/connector names is raw-capped and
  control-stripped before normalization. Later slices can add utility metadata or licensed assets, but the shared fallback registry is live.

**Editor-graph items recovered → belong to PLAN 2 (not here):** graph inline-edit of doc nodes (no detached window),
home-graph tunnel to Epdoc + HTML-workspace, the 2 data-loss fixes (Prose image drop / Epdoc lossy shadow.md), and the
instant-recall/Halo popup scoped to the editors. Flagged so Plan 2 picks them up.

**Honestly CUT by the Goose-only + model-management decisions (NOT dropped):** three-engine Chat/Act/Work + Osaurus-as-Act
cluster · DeerFlow · kill-MoLoRA-Python + model-vault-staleness (moot without local models). Stealth browsing = re-confirm.

## Follow-up hardening order (within Plan 3)
1. **Fast PDF→MD** — shipped; continue parser hardening/perf checks around EdgeParse primary + unpdf fallback.
2. **Provenance moat** — shipped; EventStore edit supersession demo is live, Rust write FFI only with owner sign-off.
3. **Extensibility** — shipped; UI/MCP install, Best-of, vault-MCP server, and Rust resource dispatcher byte-parity are live.
4. **Apple-native · Landing buttons · arXiv pull** — shipped; continue focused regression coverage only.
5. **Browser** — lite native WKWebView tab is shipped for MAS; browser-use Pro vendor code/payload exists, continue
   signed Pro UI/MCP hardening without touching MAS.
6. **Meeting/STT note · Voice · whole-app logos** — shipped; continue recurring hardening passes, Pro Kokoro gating,
   and logo utility/sidebar metadata slices.

## NOT in Plan 3 (so the three plans never blur)
Editor/markdown/Tolaria/code-editor v2/HTML-workspace/web-clipper/wikilinks/PDF-*viewer* → **Plan 2**. Goose/Act/Work
agent surface → **Plan 1**. Everything else from the big ledger (models, voice, training, full-ports, etc.) → curated
in `LEDGER_CURATION_2026_06_28.md` (kept/deferred/cut there), not here.
