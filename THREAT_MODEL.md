# THREAT_MODEL.md — Epistemos (Phase 2)

> Built 2026-07-02 from the six Phase-0 audit sweeps (security, webview, rust, features, performance, forensic). Scope: non-Goose surfaces (Goose lane documented at boundaries only). Every security finding in HARDENING_AUDIT.md references a boundary ID below. "Verified how" = the check that proves the control holds (test / runtime guard / documented manual check).

## Assets

| Asset | Where it lives | Sensitivity |
|-------|----------------|-------------|
| Meeting audio (transient) | AVAudioEngine buffers → SpeechAnalyzer; **never persisted** | high (never leaves device; transient loss risk = MEET-1/2) |
| Meeting transcripts / notes | SDPage (SwiftData) + vault markdown, in-container | high |
| arXiv queries / cached metadata / downloaded PDFs | `<vault>/arXiv/`, in-container | medium |
| Browser history / cookies / page content | ephemeral WKWebsiteDataStore (non-persistent) for human browser; named-persistent isolated store for browser-use | medium |
| Agent commands + tool access | agent_core in-process (FFI); tools deny-by-default | critical (tool surface = enterprise trust core) |
| Bridge messages (web↔native) | WKScriptMessageHandler(WithReply), page content world | high |
| Swift↔Rust FFI traffic | UniFFI + raw extern "C"; pointers/strings | high |
| Local files + security-scoped bookmarks | vault dir; UserDefaults bookmark blob | high |
| Secrets / tokens (LLM API keys, OAuth) | **Keychain only** (kSecUseDataProtectionKeychain, AfterFirstUnlockThisDeviceOnly, non-synchronizable) → setenv → Rust from_env | critical |
| Logs / crash data | os.Logger (unified log); traces/production/*.jsonl | medium (MEET-7: note title leaks to trace) |
| Entitlements / privacy prompts | 3 .entitlements files; Info.plist usage strings | high (App Review) |

## Trust boundaries

### B1 — App-UI WKWebView ↔ native bridge
- **Trusted:** native Swift (bridge handlers). **Untrusted:** JS in the app-UI webviews (Epdoc editor, CoreEditor/MarkEdit, HTML Workspace preview, code editor) — treated hostile even though locally-bundled.
- **Crosses:** editor content, selection, image assets, theme, workspace diagnostics via 8 handlers (epdoc, epistemosMarkEditCoreEditor, bridge×2, epistemosCodeEditor, htmlWorkspaceSafeAPI, epistemosWorkspaceConsole, epistemosWorkspaceInspector).
- **Allowed:** typed/bounded editor ops. **Denied:** filesystem, agent, arbitrary native (MarkEdit native `bridge` returns canned-deny for all file/save/open; htmlWorkspaceSafeAPI is diagnostic-echo-only).
- **Validation:** fail-closed typed enums / fixed allowlists / bounded strings / isMainFrame checks; Swift→JS structured/escaped (jsStringLiteral/JSONEncoder) everywhere except WEB-5.
- **Open gaps:** WEB-1 (Epdoc webview no decidePolicyFor), WEB-2 (MarkEdit isInspectable=true in release), WEB-3 (CORS disabled on notes host), WEB-4 (no CSP on 3 bundled UI docs), WEB-5 (KaTeX literal escaping).
- **Verified how:** WEB sweep enumerated all handlers + injection sites; Phase 5 adds tests proving page JS can't reach denied ops + release isInspectable=false.

### B2 — Browser / browser-use WKWebView ↔ everything (different trust domain)
- **Trusted:** native app. **Untrusted:** arbitrary remote web content (human browser) / vendored Gradio UI (browser-use).
- **Crosses:** rendered remote pages; page→agent flow (browser-use only, via its own loopback runtime — NOT via any Swift bridge).
- **Allowed:** navigation within policy. **Denied:** any bridge handler (both register ZERO), file URL access, non-loopback (browser-use pinned to 127.0.0.1/localhost/::1), data:/file:/javascript:/credentials-in-URL (BrowserURLGuard).
- **Validation:** isolation by construction — no shared process pool / data store / userContentController / handlers with B1; ephemeral store (human) / isolated named store + clear affordance (browser-use).
- **Open gaps:** BRW-1 (no download delegate → silent dead-end), BRW-2 (no external handoff), BRW-3 (private drawsBackground KVC), BRW-4 (cookie session lives until quit), BUP-1 (orphaned python+Chromium on quit + env-file survives), BUP-2 (duplicate supervisors).
- **Verified how:** WEB sweep confirmed zero-handler + no-shared-config by construction; Phase 5 test asserts browser webview handler count == 0.

### B3 — Agent ↔ tools (enterprise trust core)
- **Trusted:** the app's approval + gating layers. **Untrusted:** LLM-chosen tool calls.
- **Crosses:** 90 registered tools (50 ReadOnly / 24 Modification / 16 Destructive).
- **Allowed:** read-only auto; **Denied by default:** modification + destructive (PermissionConfig defaults NO/NO → user approval required); all subprocess/exec/shell tools **compiled OUT of MAS** (#[cfg(feature="pro-build")], default=mas-build).
- **Validation:** 4-layer gate (compile → tier → optional Command Center allowlist → runtime SmartApproval); Forbidden command patterns blocked unconditionally.
- **Open gaps:** prompt-injection test (hostile fetched content → no tool call) not yet present for the non-Goose agent path — Phase 6/9 (deferred: agent core is largely Goose-adjacent; the untrusted-content pipeline B7 is the mitigation to verify).
- **Verified how:** RUST sweep extracted the tool table + gate layers; Phase 9 adds the hostile-page walkthrough.

### B4 — Swift ↔ Rust FFI
- **Trusted:** neither fully — each validates at the boundary. **Untrusted (to Rust):** all pointers/strings from Swift.
- **Crosses:** UniFFI (96 exports in bridge.rs, 79 ffi_guard-wrapped) + raw extern "C" (graph-engine 168, agent_core 30, shadow 18, substrate 25, syntax 13, code-index 5).
- **Validation:** all 10 sampled entry points null-check + UTF-8-validate + length-bound; graph-engine NaN/Inf-sanitizes + clamps; panics caught → error sentinel (no crate UB-unwinds into Swift; epistemos-core/omega-mcp/substrate-core documented panic=abort).
- **Open gaps:** RUST-7 (41 unsafe blocks lack //SAFETY comments vs CLAUDE.md rule); RUST-10 (omega-mcp abort-on-lock).
- **Verified how:** RUST sweep; Phase 6 (non-goose) comment pass + `deny(clippy::undocumented_unsafe_blocks)`.

### B5 — App / agent ↔ network
- **Trusted:** the app. **Untrusted:** all cloud responses (LLM SSE, arXiv XML, HF downloads).
- **Crosses:** HTTPS to Anthropic/OpenAI/Gemini/Perplexity/arXiv/HuggingFace/etc.; OAuth callbacks.
- **Allowed:** TLS only (ATS default, 0 exceptions, 0 cleartext remote endpoints). **Denied:** cleartext, arbitrary loads.
- **Validation:** Rust cloud clients 300s timeout + bounded retry (jittered); arXiv 15s + strict host/path pinning; Kokoro downloads SHA256-verified.
- **Open gaps:** SEC-3 (Swift LLMService.shared no explicit timeout), RUST-4 (epistemos-core provider client no timeout → app-hang candidate).
- **Verified how:** SEC network table + RUST timeout audit; Phase 4 adds the endpoint/TLS/timeout/retry/cancel table + fixes.

### B6 — App ↔ filesystem
- **Trusted:** the app within its container. **Untrusted:** paths derived from user/web/agent input.
- **Crosses:** vault reads/writes, security-scoped bookmarks, temp files.
- **Allowed:** in-container + user-selected scope. **Denied:** traversal (guards at file_ops/filesystem/agent-vault/omega-mcp-vault), writes outside container.
- **Validation:** start/stop bookmark pairing disciplined (8/12); 4 traversal guards present.
- **Open gaps:** RUST-8 (agent_core vault resolve_path doesn't canonicalize → in-vault symlink escapes), SEC-4 (user content logged .public), SEC-7 (dev paths in binary), MEET-7 (note title in trace).
- **Verified how:** SEC filesystem section + RUST path audit; Phase 4/6 fixes + traversal test.

### B7 — Untrusted content (arXiv XML/PDF, page content, transcripts) ↔ agent/render
- **Trusted:** the app's parsers/renderers. **Untrusted:** fetched XML/PDF, page text, transcript text.
- **Crosses:** arXiv Atom XML, PDF bytes, browser page content, meeting transcripts → notes/graph/agent.
- **Allowed:** parse-as-data. **Denied:** external entities (XXE off), oversize (5MiB/64KiB/32/50 caps), executable render (no unsanitized HTML→loadHTMLString; HTML Workspace CSP-sandboxed).
- **Validation:** defensive XMLParser; PDF magic/symlink/size checks; content enters editors as non-executing document model.
- **Open gaps:** MEET-1 (transcript silently truncated at 10k), MEET-2 (persist failure → data loss), B3 prompt-injection test pending.
- **Verified how:** FEAT + WEB sweeps; Phase 9 hostile-page + oversize-input walkthroughs.

### B8 — Local servers ↔ local processes / webviews
- **Trusted:** the launching app. **Untrusted:** any other local process (or LAN peer if misconfigured).
- **Servers found:** (a) agent_core channel relay axum 127.0.0.1:8787 — **pro-build+channel-relay-tools gated, manual-launch only, NOT in shipped/MAS build**; (b) browser-use Gradio python 127.0.0.1:7788 — Dev-ID Pro only, compiled OUT of MAS, loopback-pinned, no auth token; (c) OAuth callback listener (CloudProviderAuthService.swift:514); (d) VaultMCPServer/WorkNativeMCPServer/WorkSPAServer loopback (pro/work surfaces, DNS-rebinding defense present). **No listening server exists in the shipped MAS build (verified fact).**
- **Allowed:** loopback only. **Denied:** non-loopback bind (relay accepts 0.0.0.0 silently — RUST-2b, pro-only), unauthenticated privileged access (relay no-auth when token absent — RUST-1, pro-only; browser-use Gradio no-auth — PLAN-3, Dev-ID posture).
- **Verified how:** RUST socket sweep proved MAS build has zero listeners; Phase 6 (deferred, pro-lane) hardens relay auth; APP_REVIEW_NOTES documents browser-use is not in MAS.

## Redaction / logging rules (enforced target)
- User-derived data (queries, note content, filenames, transcripts, URLs, keys): os.Logger `privacy: .private` — SEC-4 fixes the current .public search-query/filename sites; keys/transcript content already never logged.
- Secrets: never logged (verified: no tracing/log macro prints key material); RUST-5 removes latent Debug-derive leak on ClaudeAuth/credential_pool.
- Traces: MEET-7 — hash/omit content-derived note title in production trace JSONL.

## How boundary IDs are used
From Phase 2 onward every HARDENING_AUDIT.md finding carries the boundary it crosses (already applied retroactively to SEC-/WEB-/RUST-/MEET-/FEAT- rows). CRITICAL = exploitable across B1/B2/B3/B4 or data loss across B7; local-server exposure = B8.
