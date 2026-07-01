# SS-M — Obscura + agent-scraper + privacy via WebKit (2026-06-19)

Read-only research (subagent), code-grounded. Cross-references **SS-J** (browser-use everywhere) — does NOT
re-derive the 11-tool `browser.*` family / `BrowserEngine` trait / computer-use AX stack. Feeds the OBSCURA/
SCRAPER/PRIVACY ledger item. Owner: *"Obscura ... agent scraper things like that, privacy."* Doctrine:
APP-NATIVE BY EMBEDDING (clone source, never run the foreign program/sidecar), local-first, honest gating,
no-fake, engine-isolation.

## Headline
**Privacy primitives + a real HTTP scraper EXIST; Obscura the stealth engine and the *agentic* scraper do
NOT.** Epistemos ships (a) MAS-safe `web.fetch/extract/crawl` — real single-shot HTTP + BFS crawl with SSRF
guard, depth/page caps, HTML→text — and (b) WKWebView privacy hardening (`nonPersistent()` across 5 host
views). **Doctrine-landed but unbuilt:** Obscura is a pure trait stub returning `NotConfigured` (no `obscura-*`
crate, no `deno_core`); there's NO LLM-driven extract-to-schema/multi-page agentic scraper (only goal-blind
BFS dumping snippets); and ZERO anti-fingerprinting (no UA spoofing, no canvas/WebGL/navigator overrides, no
`WKContentRuleList`).

## Obscura — what it is + build status
- **Upstream:** Obscura = Rust-native headless browser engine (render + DOM + JS-exec + CDP) from GitHub
  `h4ckf0r0day/obscura`, pulled as 4 lib crates (`obscura-browser/-net/-dom/-js`) with a **`stealth` feature**,
  omitting the CLI + WS-CDP crates (library API only, never the IPC server). Addendum
  `docs/fusion/research/quickcapture-addenda/OBSCURA_BROWSER_ADDENDUM.md:62-72,122-142`. Paired with
  **`deno_core`** (V8 isolate Cargo dep, NOT the Deno binary — Pro Playwright/Puppeteer-style user JS via a
  `playwright-core` shim; `:277-301,394-452`); V8 dedup via `[patch.crates-io]` rusty_v8 pin (`:142`).
- **Doctrine correction:** "Obscura is the default browser engine" was CORRECTED to "Obscura is **one
  adapter**, not a foundation" — `BrowserEngine` trait with WebKit-baseline (MAS) / Obscura-experimental (Pro)
  / Mock (tests) (addendum `:6`). (Matches SS-J.)
- **Build status = TRAIT STUB ONLY.** `agent_core/src/browser_engine/mod.rs:319-363`: `ObscuraBrowserEngine`
  is a unit struct; EVERY method returns `BrowserError::NotConfigured("obscura not yet wired")`; `open_session`
  says integration "lands in Wave 6 — needs Rust-native engine + V8 entitlement + per-call ephemeral spawn." A
  test asserts the not-configured surface for every call (`:438-440`). **No `obscura`/`deno_core`/`rusty_v8`
  dep exists** in `agent_core/Cargo.toml` (grep empty). Lift targets sit as Stage-2 Phases W6-A…I gated behind
  sign-off (`docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md:91-103`).

## Agent-scraper — exists vs gap
- **Exists (real, MAS-safe, single-pass):** `agent_core/src/tools/web.rs` — three handlers, no subprocess,
  shared reqwest client (honest static UA `Epistemos/1.0` `:119`):
  - `web_extract` (`:555`) — fetch 1–10 URLs in parallel (`join_all:591`), prefer `<article>`/`<main>`
    (`extract_main_region:709`), HTML→text, 32K cap. Single-shot, no LLM.
  - `web_crawl` (`:750`) — true **BFS frontier**: `VecDeque` + `visited` HashSet (`:775-779`), same-host
    default (`:771,849`), caps max_pages≤50 / max_depth≤3 (`:26-27,768-770`), discovery cap 4× max_pages
    (`:860`), per-page validate_url + `extract_links` (`:895`). Returns title + 4K snippet/page (`:833-839`).
    **Pure mechanical crawl — no LLM in the loop, no structured-output target.**
  - `web_search` (`:190`) — Tavily/Brave/Perplexity, env-key gated.
  - SSRF/redaction shared from `web_fetch.rs` (`validate_url:64`, `is_private_url:28`, `secure_redirect_policy
    :96` — blocks private IPs, embedded creds, metadata endpoints).
  - Registered AppStoreSafe: `web_crawl.rs:49 Profile::AppStoreSafe, small_model_safe:true`; on Core allowlist
    `registry.rs:446-452,1106-1154`.
- **Gap to "agent scraper":** NO agentic extract-to-structured-data loop (grep `extract_to_schema`/
  `structured_extract`/`llm.*extract` = empty). Missing = browser-use's `extract(query,schema)` + an LLM-driven
  crawl-decision loop (decide which links to follow toward a goal, extract to a typed schema, accumulate) +
  grammar-constrained structured output. Today `web_crawl` is goal-blind BFS; `web_extract` is dump-to-text.
  **The agentic scraper = `web_crawl`'s frontier + an LLM extract-to-schema head + a relevance-ranked
  frontier** (clean-room of crawl4ai/firecrawl "extract to JSON schema"), reusing grammar-bound dispatch
  (`LocalToolGrammar`) for closed output.

## Privacy / anti-fingerprint — primitives vs Obscura-adds
- **EXISTS:** ephemeral data stores `WKWebsiteDataStore.nonPersistent()` on all 5 WKWebView hosts
  (`EpdocEditorChromeView.swift:629`, `EpdocKaTeXPreview.swift:77`, `WebKitCodeEditorView.swift:45`,
  `HTMLWorkspacePDFExporter.swift:35`, `HTMLWorkspacePreviewView.swift:27`) — no persistent cookies/cache/
  IndexedDB/localStorage. SSRF guard + secret-free errors (`web.rs:404-419` `describe_web_request_error`, test
  `:1103`). Proxy passthrough — `browser.rs` CLI spawn allowlists `HTTP_PROXY/HTTPS_PROXY/NO_PROXY` via
  `harden_cli_subprocess_extending` (`:541-556`) — corporate-proxy reach, NOT an Obscura proxy-chain. The human
  Tier-1 Browser now installs a local `WKContentRuleList` tracker/ad blocker with host-anchored request URL filters.
- **ABSENT (Obscura-style):** no `customUserAgent`/UA spoofing (only honest app defaults), no
  canvas/WebGL/font spoofing, no `navigator.webdriver`/platform overrides, no proxy *chains*. All the Obscura
  `stealth` feature (`BrowserOptions{stealth}` addendum `:168-185,487,542`) — future Pro work.

## Native embedding path (honest)
- **Scraping (MAS-safe):** the SS-J `WebKitBrowserEngine` adapter (`mod.rs:273-317`, today `NotConfigured`) =
  in-process WKWebView (reuse `EpdocEditorChromeView` + shared `WKProcessPool`), `evaluateJavaScript` DOM →
  `PageSnapshot`/`AxNode`. **Agentic layer on top:** reuse `web_crawl`'s `VecDeque` frontier (`web.rs:775`) +
  an LLM extract-to-schema head (grammar-bound `LocalToolGrammar`) + relevance-ranked link selection. In-process,
  no entitlements, MAS-clean.
- **Obscura privacy (MAS-safe subset):** WKWebView hardening already real (`nonPersistent()`); the delivered
  MAS-safe add is WebKit-native + entitlement-free — **`WKContentRuleList`** compiled JSON ad/tracker block rules
  on the human Browser. Clean-room WebKit APIs, NOT the Obscura crate; UA/canvas/WebGL spoofing remains absent.
- **Pro path:** `ObscuraBrowserEngine` (`mod.rs:319`) = Obscura `stealth` (canvas/WebGL/navigator evasion) +
  `deno_core` V8 user-JS + CDP + proxy chains — per-call ephemeral V8 isolate, V8 entitlement, `#[cfg(pro-build)]`,
  all `Profile::ProOnly`.

## Honest gating
- **MAS-safe:** `web.fetch/extract/crawl` (already AppStoreSafe); future in-process `WebKitBrowserEngine` scrape
  + `nonPersistent()`. The human Browser's `WKContentRuleList` tracker-block is already delivered. New tools must join
  `coreAppStoreAllowedToolNames` (SS-J: `ToolTierBridge.swift:194-235`).
- **Pro-only:** Obscura `deno_core`/V8 stealth engine, anti-fingerprint spoofing, CDP, proxy chains, the
  existing `agent-browser` CLI — all `#[cfg(pro-build)]`/`Profile::ProOnly`.
- **No-fake/engine-isolation:** stubs honestly return `NotConfigured` (`mod.rs:294,340`); the agentic-scraper
  tool registers ONCE in the shared `ToolRegistry` → Chat/Act/Work all bind via the tier ladder, no per-engine
  logic import.

## Ordered plan
1. **[S — DELIVERED/PARTIAL]** `WKContentRuleList` MAS-safe tracker/ad blocker on the human Browser
   (extends the existing `nonPersistent()` posture; pure WebKit, no entitlement). `customUserAgent` spoofing is not
   built and remains outside the MAS-safe honesty claim.
2. **[M]** **Agentic scraper** = `web_crawl`'s frontier (`web.rs:775`) + LLM extract-to-schema head
   (grammar-bound `LocalToolGrammar`) + goal-relevance link ranking; register once, AppStoreSafe, add to
   `coreAppStoreAllowedToolNames`. Clean-room firecrawl/crawl4ai "extract to JSON schema."
3. **[M]** Implement `WebKitBrowserEngine` (`mod.rs:273`, = SS-J's [M]) so the agentic scraper runs JS-heavy SPA
   pages in-process, not just static HTTP.
4. **[L]** `ObscuraBrowserEngine` (Pro): `obscura-*` + `deno_core` deps (V8 dedup `[patch.crates-io]`), `stealth`
   anti-fingerprint, proxy chains, per-call ephemeral V8 — `#[cfg(pro-build)]` + owner sign-off (B3 W6-A…I).

## Unverified
Whether `agent_core/src/research/acs/`, `agent_core/src/eidos/`, or UAS probes contain a partial multi-step
extract loop (names grep-matched, files not opened). Obscura upstream security posture is itself an open
sign-off question (B3 `:123`). `WKContentRuleList`/ITP being natively MAS-allowed asserted from WebKit API
knowledge, not an in-repo code ref.

Key files: `agent_core/src/tools/web.rs` (web_extract `:555`, web_crawl BFS `:750-876`, frontier `:775`, links
`:895`) · `web_fetch.rs` (`validate_url:64`, `is_private_url:28`, `html_to_text:130`) · `tools_v2/v2_catalog/
web_crawl.rs:49` · `browser_engine/mod.rs` (Obscura stub `:319-363`, WebKit stub `:273-317`, NotConfigured
`:294,340`) · `tools/browser.rs:541-556` (HTTP_PROXY allowlist) · WKWebView hosts `EpdocEditorChromeView
.swift:629` + `EpdocKaTeXPreview.swift:77` + `Views/Notes/WebKitCodeEditorView.swift:45` + `Views/HTMLWorkspace/
HTMLWorkspacePreviewView.swift:27` + `Engine/HTMLWorkspacePDFExporter.swift:35` · `docs/B3_OBSCURA_BROWSER_LIFT
_TARGETS_2026_05_05.md` · `docs/fusion/research/quickcapture-addenda/OBSCURA_BROWSER_ADDENDUM.md` · cross-ref
SS-J doc.
