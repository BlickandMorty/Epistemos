# Plan-3 Capabilities — Research Loop Tracker (2026-06-28)

> Running log for the `/loop 3m` deepening of `PLAN_3_CAPABILITIES_2026_06_28.md` (cron `a7c94e69`).
> GOAL: research each kept capability deeply enough to FULLY CLONE/vendor every kept repo with real code;
> harden; remove contradictions; NO clash/duplication with Plan 1 (Goose) or Plan 2 (editor canonical).
> Owner-CONFIRMED: provenance moat · extensibility/MCP/vault-as-MCP · fast PDF→md · Apple-native maximization.
> Owner-UNSURE (research the concern honestly, don't assume): Obscura · ColBERT.

## Pass checklist
- [x] **Pass 1 DONE** (2026-06-28): PDF cluster ground-truth + best repos + viewer/md coexistence + Apple-native scan.
  - **1a TRUTH (owner was right):** the app CANNOT parse a PDF→md today (vendored liteparse but `liteparse-pdf`
    feature OFF in `default`, no `libpdfium.dylib` bundled, UI flag `EPISTEMOS_LITEPARSE_PDF_V0` OFF) AND there is
    **NO PDF viewer** (zero `PDFView`/QuickLook; PDFKit used only as a headless extractor in `VaultParser.swift`).
    Everything honest-inert (never fakes a note).
  - **1b BEST REPOS:** EdgeParse (primary, pure-Rust, #1 accuracy+speed, Apache-2.0, MAS-safe) + unpdf (CJK/RTL/multi-
    lingual, zero-C-dep, MIT, MAS-safe) + Apple Vision/PDFKit (scanned-OCR lane, native). liteparse = Pro-first
    (PDFium+Tesseract C++ blobs, notarization risk). Drop pdf_oxide for md (thin md layer).
  - **1c COEXISTENCE + APPLE-NATIVE:** original `.pdf` + parsed `.md` sibling, linked via `SDPage.frontMatterData`
    `source_pdf` (no migration); pdf→md ON by default; parsed note opens + "View original PDF" affordance; 2 settings.
    Plan-2 owns the PDFView VIEWER, Plan-3 owns the PARSE + the link/storage contract. Apple-native top-6 listed.
  - → folded into `PLAN_3_CAPABILITIES §1` (rewritten) + new `§6 Apple-native maximization`.
- [x] **Pass 2 DONE** (2026-06-28): ColBERT + Obscura + ledger re-scan.
  - **ColBERT → KEEP search-only, CUT tool-selector.** Use (b) tool-select = app-side-agent plumbing (no live Swift
    wiring today; dies with Goose consolidation) → cut. Use (a) vault rerank = pure search infra on the *data* side of
    the MCP boundary → keep, deferred, flag-gated; sharpens Goose's MCP vault queries without touching its AI. Resolves
    the "don't muddy app-side AI" concern. → folded into §3.
  - **Obscura → clarified + tiered.** WKWebView IS Safari engine → a browser tab is LIGHT + behaves like a normal
    browser (T1, MAS-safe); only the agentic automation+stealth is HEAVY (T3, Pro). Recommend START at T1 (visible
    usable browser fast). Honest limits: no Safari extensions, some DRM video, isolated cookies. → folded into §2.
  - **Ledger re-scan** found owner-wanted skipped items → added §7 (arXiv pull, meeting/STT note, Eidos→chat) +
    an owner-decision queue (HF/BYOM marketplace, model stack, vision-lane, DeerFlow — hinge on Goose-only-AI).
- [x] **Pass 3 DONE** (2026-06-28): CLONE-READY CODE for the top-3 confirmed build items → 3 codepacks:
  - **`PLAN_3_EDGEPARSE_CODEPACK`** — vendor commands + `agent_core/src/pdf_parse.rs` (same FFI envelope, unpdf fallback,
    honest-inert) + Swift coexistence (settings + `source_pdf` frontmatter + "View original PDF" stub) + the 3 flips.
  - **`PLAN_3_PROVENANCE_CODEPACK`** — Fix A (`VRMLabel.honestLabel(for:)` gate + emitter derivation + test) + Fix B
    (tightened `VerifiedFloorChipStrip` audit) + Moat-1 (`VRMLabelView` hover-lineage card). Full cascade = flagged Rust FFI.
  - **`PLAN_3_VAULT_MCP_CODEPACK`** — `VaultMCPCore`/`VaultMCPServer`/`VaultMCPTokenStore`/`VaultMCPHost`/Settings row,
    reusing the audited `WorkNativeMCPServer` transport; read-only allowlist enforced at the core; persistent Keychain token.
- [x] **Pass 4 DONE** (2026-06-28): CLONE-READY CODE for 3 more confirmed items → 3 codepacks:
  - **`PLAN_3_OBSCURA_TIER1_CODEPACK`** — `ObscuraBrowserView` (WKWebView + chrome + URL guard + KVO + teardown) +
    `UtilityPanel.browser` + ⌘⇧B. Standalone, MAS-safe, behaves like Safari. Tier-2/3 seam noted, not built.
  - **`PLAN_3_EXTENSIBILITY_CODEPACK`** — `MCPRegistryClient` (Smithery/mcp.so/Glama/GitHub browse) + the missing
    `MCPUrlServerDirectory.write` + `ExtensionsDetailView` (Skills/MCP/Connectors tabs) + `BestOfPreset` + manifest.
  - **`PLAN_3_APPLE_NATIVE_CODEPACK`** — `FilePreview` (QuickLook), `LiveTextImageView` (VisionKit Live Text → search),
    `FileThumbnail` (QuickLookThumbnailing) + wiring into `NotesSidebar` rows.
- [x] **Pass 5 DONE** (2026-06-28): owner steering + 2 research lanes.
  - **Owner decisions:** 🔴 CUT local model-management (HF/BYOM/stack/vision/DeerFlow) — owner said no, AI=Goose.
    🟢 NEW REQ: every feature = a landing-page button (§8). 🟢 browser-use/automation confirmed wanted (§9).
  - **Landing buttons** → `PLAN_3_LANDING_BUTTONS_CODEPACK` (`LandingFeatureButton` enum + tile + dispatch over existing
    summon mechanisms; 1 case per feature; honest Pro pills).
  - **browser-use verdict (§9):** it drives ONLY Chromium (CDP) → CANNOT drive Obscura (WebKit); Python+Chromium → Pro
    only. Goose already has 11 Chromium/CDP browser tools (Pro). REC: Option B native (drive in-app Obscura WKWebView via
    the `WebKitBrowserEngine` stub, exposed to Goose) first; Option A (vendor real browser-use as a Pro power-mode) optional.
  - **Added a CLONES LEDGER** to Plan 3: real external clones = EdgeParse + unpdf (MAS) + ColBERT model + optional
    browser-use (Pro); everything else is native.
- [x] **Pass 6 DONE** (2026-06-28): owner steer + scope recovery. CUT Obscura→browser-use (browser = lite native tab
  for MAS + browser-use Chromium for Pro); CUT ColBERT; HTML Workspace stays Plan 2; **Goose-only confirmed → three-engine
  Act/Osaurus cluster + DeerFlow CUT.** Full scope recovery (`SCOPE_RECOVERY_2026_06_28.md`): added Voice + whole-app
  logos to Plan 3 §11; editor-graph trio → Plan 2; kill-MoLoRA/model-vault-staleness moot. Saved arXiv codepack.
- [ ] **Pass 7+** (queue): (a) meeting/STT note → code (re-run; was interrupted). (b) browser-use vendor plan (Pro:
  Python+Chromium+web-UI reskin in WebView, exposed to Goose) → concrete clone steps. (c) Voice → code. (d) whole-app
  logos → plan. (e) flag the editor-graph trio into Plan 2. (f) HARDEN + contradiction sweep across all 3 plans.
