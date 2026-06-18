# R-STEALTH + R-BESTOF — stealth browsing + best-of preset (verdict, 2026-06-18)

Research-backed verdicts for the owner's two adds. Authorized use only; everything
here is Pro/dev-gated or MAS-gated per the honesty constraints (no hidden
subprocess on MAS). Build is queued behind the picker/chat audit + Osaurus.

## 1) STEALTH / UNDETECTED BROWSING (P-STEALTH)

**TAKE: `vibheksoni/stealth-browser-mcp` via the MCP path** (MIT). It IS an MCP
server (FastMCP, stdio/HTTP) powered by **nodriver** (the leading undetected
Chrome engine, async) + **Chrome DevTools Protocol** — 97 tools across 11
sections (spawn/navigate, element interaction, pixel-accurate element cloning,
network interception, AI-generated Python network hooks, cookies/storage, JS
exec, raw CDP). Claims real-browser bypass of Cloudflare / Queue-It / social
blocks. MIT ⇒ vendorable.

- **Why this one:** the owner said "if it's not Rust-native, USE IT ANYWAY via
  the agent-browser/chrome-MCP path and VENDOR it." This is exactly an MCP server
  — it drops into our EXISTING MCP path (`MCPUrlServerDirectory` / `MCPBridge` /
  the connectors panel) with zero new transport. nodriver+CDP is the current
  best-practice stealth stack (2026).
- **Engines / alternatives** (if we want a narrower vendored core instead of the
  whole MCP): **nodriver** (Chrome, MIT, async, the de-facto undetected driver),
  **Camoufox** (Firefox-based antidetect, fingerprint injection), **SeleniumBase
  UC Mode** (undetected-chromedriver successor — driver-disconnect during
  sensitive actions). Heavy/enterprise (Bright Data Scraping Browser, GoLogin
  Orbita, Multilogin) are paid/off-device → SKIP (conflict with local-first).
- **Lane:** Python (nodriver) ⇒ external MCP server process ⇒ **Pro/dev only**
  (MAS sandbox + hardened runtime can't spawn subprocess). On MAS the honest
  surface is "available in Pro." Vendor + PIN the version; token-scope; never
  auto-run.
- **Two stealth targets, honestly different:**
  1. **browser-use heavy bypass** → the stealth-browser-mcp (nodriver) external
     server. This is where "sites don't know an agent is on the page" really
     lives.
  2. **In-app Obscura (WKWebView) browser** → stealth = fingerprint/UA hardening
     on the WebView (custom UA, navigator.webdriver removal, canvas/WebGL noise),
     NOT full nodriver bypass. Honest: label the Obscura "stealth" toggle as
     "fingerprint hardening", and route true anti-bot work to the Pro MCP.
- **Wiring (when built):** a `stealth: bool` option on the browser-use tool
  (browser.rs) + an Obscura "stealth" toggle; both Pro/dev-gated, authorized-use
  banner. browser-use mainly drives the in-app Obscura browser; stealth-MCP is the
  escalation for protected sites.
- **Security:** treat as untrusted-ish third-party (BlueRock 2026: 36.7% of public
  MCP servers have SSRF, 41% no auth). Vendor a pinned copy, run hardened
  (security.rs subprocess hardening), Pro-only, explicit user enable.

## 2) BEST-OF PRESET (P-BESTOF) — powerful out of the box

Ship a curated default set of the BEST **real, working** superpowers, each
Pro/MAS-gated, user-toggleable (wire into the P2.1 tool panel / capability
explorer). Research baseline: Anthropic's 7 reference servers (Everything, Fetch,
Filesystem, Git, Memory, Sequential Thinking, Time) + the community's "start
here" trio **GitHub MCP + Context7 + Playwright** (covers code/docs/web ≈ 80% of
agent needs). Prefer **vendor-maintained** servers (GitHub, Microsoft Playwright,
Cloudflare, Notion, Linear, Stripe, Supabase) — lowest supply-chain risk.

**The honest map — most of this is ALREADY native in Epistemos** (so the preset
is "curate + gate + expose", not "import everything):**

| Capability | Epistemos today | Gate | Preset action |
|---|---|---|---|
| Filesystem | `file_ops` (read/write/patch/list) | write=Pro, read=MAS | expose in preset |
| Web fetch/search | `web_fetch` + `web_search`/`web_extract`/`web_crawl` | MAS-ok (Tavily key) | expose |
| Browser use | `agent_core/src/tools/browser.rs` (navigate/click/snapshot/…) | Pro | surface in Act/Work + preset |
| Browser stealth | stealth-browser-mcp (above) | Pro/dev | add via MCP |
| Git/diff | Pro git/diff tools (cfg pro-build) | Pro | expose (Pro) |
| Code exec | `code_execution` (py/node/ruby/perl/shell, hardened) | Pro | expose (Pro) |
| Memory/vault | `memory` tool + vault.search/read/write + Knowledge Core + Eidos + Halo | MAS-ok | expose (the Epistemos edge) |
| Sequential thinking | `think` tool + reasoning-token isolation | MAS-ok | expose |
| Time | trivial local | MAS-ok | expose |
| CLI agents | claude_code/codex/gemini/kimi/goose/aider/openhands/mini/**opencode** | Pro | Work mode |
| External MCP | GitHub MCP, Context7, Playwright, Notion, Linear, Slack/Gmail/Drive | varies | connectors panel (wired-only) |

**Preset doctrine (honest):** (a) only ship picks that ACTUALLY run on the user's
build — MAS preset = the MAS-safe subset, Pro preset adds shell/git/browser/CLI;
(b) each pick is a real toggle into the runtime (P2.1 → disabledToolNames), never
decoration; (c) external MCP picks appear only when actually wired (keys in
Keychain) — otherwise "available, connect in Settings", never a fake-on toggle;
(d) prefer vendor-maintained MCPs for safety; (e) document each pick's
source/license/gate in the preset manifest.

**Deliverable when built:** an `EpistemosBestOfPreset` manifest (pure, tested) =
the curated list with {id, capability, gate, source, license}; a one-tap "Enable
the recommended power set" in the P2.1 panel that flips the MAS-safe subset on
(Pro adds the rest); honest per-pick status. Ties to the capability ceiling
(P7.1) + tool toggles (P2.1) already shipped.

## Sources
- [stealth-browser-mcp (GitHub, MIT)](https://github.com/vibheksoni/stealth-browser-mcp)
- [AI Browser Automation 2026: Camoufox, Nodriver & Stealth MCP (PROXIES.SX)](https://www.proxies.sx/blog/ai-browser-automation-camoufox-nodriver-2026)
- [Stealth for AI Browser Agents — 2026 guide (O-mega)](https://o-mega.ai/articles/stealth-for-ai-browser-agents-the-ultimate-2026-guide)
- [best-of-mcp-servers (ranked list, GitHub)](https://github.com/tolkonepiu/best-of-mcp-servers)
- [Best MCP Servers 2026 (Vibehackers)](https://vibehackers.io/blog/best-mcp-servers)
- [Awesome MCP Servers](https://mcpservers.org/)
