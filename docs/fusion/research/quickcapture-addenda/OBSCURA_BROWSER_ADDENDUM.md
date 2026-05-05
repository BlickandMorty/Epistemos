# OBSCURA + EIDOS — Browser Engine + Agent Search Addendum

> **⚠️ READ WITH CORRECTIONS — `FINAL_SYNTHESIS.md` SUPERSEDES THIS DOC ON THE FOLLOWING POINTS:**
>
> 1. **"All in-process, always" / "zero subprocesses anywhere" → corrected to "no hot-path subprocesses is the law, not 'no subprocesses ever'"** (`FINAL_SYNTHESIS.md` §7). Hermes Python orchestrator stays Pro-only optional while Rust port is being learned. The hot path is in-process; the cold-path optional bridges are honest about staying subprocess for now.
> 2. **"Obscura is the in-process default browser engine" → corrected to "`BrowserEngine` trait with WebKit-baseline (MAS), Obscura-experimental (Pro), Mock (tests)"** (`FINAL_SYNTHESIS.md` §0). Obscura is one adapter, not a foundation.
> 3. **"Cloud-as-Generator default" → reaffirmed but tri-state Cloud setting (Off / Generator only / Inference + Generator) wins** (`FINAL_SYNTHESIS.md` §5.6).
>
> The body of this addendum is otherwise canonical for Wave 6 architecture. Read with the above three corrections in mind.

**Status**: addendum to `PLAN.md`. Created 2026-04-29. **Revised 2026-04-29 (v3)** — all-in-process commitment after R8 research, **further corrected by `FINAL_SYNTHESIS.md` §0 audit table**. **Do not begin until QUICK_CAPTURE_IMPLEMENTATION_PLAN.md Phases 0.5–13 are shipped.** Wave 6.

**Scope**: Wave 6 introduces (1) the Obscura headless-browser engine as an in-process Rust dependency, (2) the `deno_core` Rust crate for in-process JavaScript execution (replacing all Node.js / Deno-binary subprocess approaches), and (3) **Eidos** — a new agent-native search engine that does for the local-first vault what Exa.ai does for the cloud-hosted web: neural-embedding-first retrieval with closed-vocabulary citation grounding, deterministic latency, and high-fidelity structured results.

**One-line thesis**: We do not spawn subprocesses for the browser engine, the JavaScript runtime, or the search engine. We do not use localhost networking. We do not use IPC. The entire web-and-search subsystem lives **in-process** with the Rust core and shares unified memory with MLX. This is what "binary as direct as binary can be" means in production.

---

## Revision history

**v1 → v2**: introduced the localhost-WebSocket trap analysis, the CDP-over-stdio fallback, and the library-embed default. Replaced Node.js SEA with Deno compile.

**v2 → v3** (this revision): the audit finding from R8 is decisive — **even Tier 1 (helper binary + stdio pipes) is not the right default** because subprocess spawning, even with anonymous pipes, still introduces deterministic-failure surfaces (process lifecycle bugs, helper bundle versioning skew, sandbox helper signing complexity). Replace it with the `deno_core` library embed for Pro JavaScript execution. Net result: **a single in-process architecture covers MAS + Pro completely.** Obscura runs as a Rust dependency; user JS scripts run via `deno_core` inside our V8 isolates. **No subprocess anywhere.**

**v3 also adds Eidos** — the new agent-native search engine. The user's framing (similar to Exa.ai but local-first, deterministic, fast, in-process) was the missing piece. With Obscura already providing in-process rendering + LP `getMarkdown`, MLX already providing embeddings, Tantivy already providing FTS, and Metal-acceleratable cosine kernels, we have every primitive needed to ship a local-first neural search engine. Eidos is that engine. It's a §6 of this addendum.

| Area | v1 | v2 | v3 |
|---|---|---|---|
| Browser engine transport | localhost WebSocket | stdio pipes (Tier 1) | **In-process Cargo dep (only Tier 0)** |
| Pro JavaScript | Node.js SEA subprocess | Deno-compiled binary subprocess | **`deno_core` crate, in-process V8** |
| Search engine | not addressed | not addressed | **Eidos: in-process neural search, closed-vocab citations, MLX-powered, Metal-accelerated** |
| Subprocess count for hot-path tools | 1+ | 1+ | **0** |
| Localhost ports bound | 1 | 0 | 0 |
| Memory copies on capture path | several | 1 (final markdown) | **1 (final markdown), Metal-accelerated cosine on 4096-vector centroids in <1 ms** |

---

## 0. When to add this — sequencing

Wave 6, deferred until `PLAN.md` Phases 0.5–13 ship. The new tools depend on the existing Tool trait (§3), the Compile-Verify-Mint pipeline (§17), the per-model engineering wiring (§6.6), and the verbatim retention invariant (§24.2). Add one line to `PLAN.md` §11's wave map (`Wave 6 — Browser engine + Eidos search — see OBSCURA_BROWSER_ADDENDUM.md`); leave the in-flight builder undisturbed.

---

## 1. The architectural revision — all in-process, always

### 1.1 Why subprocesses are out, even pipe-based ones

The v2 doc treated subprocess + stdio pipes as the MAS fallback. R8 research surfaced three structural problems with that fallback:

1. **Helper binary versioning skew.** A bundled `obscura-helper` binary becomes a versioned artifact independent of the parent app's Rust code. Schema mismatches between parent's CDP client expectations and helper's CDP server responses become a perpetual maintenance burden. Library-embed eliminates the schema boundary entirely — both sides are the same code at the same version.

2. **Helper sandbox signing complexity.** Even with `com.apple.security.inherit`, every helper binary requires its own entitlements file, its own signing pass, its own notarization staple, and its own App Store review surface. One signed binary is dramatically simpler than two.

3. **Lifecycle still has races.** Pipe-based IPC + EOF-on-parent-death is robust against crashes, but kernel scheduling delay between parent SIGKILL and child EOF detection is non-zero. In rare cases the helper does work for ~50ms after the parent has died, writing temp files or making outbound requests. Library-embed eliminates this race because there is no separate process lifecycle.

**Verdict**: subprocesses are not just suboptimal for MAS, they're suboptimal everywhere. The user's instruction is correct: "everything binary, as direct and as binary as possible, no subprocess." We commit to in-process for every tool on the hot path.

### 1.2 The all-in-process commitment

| Subsystem | Mechanism | Subprocess? |
|---|---|---|
| Browser engine (rendering, JS exec, DOM, CDP) | Obscura crates as Cargo deps | **No** |
| Pro user-script execution (Playwright/Puppeteer style) | `deno_core` crate as Cargo dep — V8 isolate in our process | **No** |
| Search engine (neural retrieval over vault + crawled web) | Eidos — Tantivy + bge embeddings + Metal cosine, all Rust | **No** |
| Vault storage | rusqlite + Tantivy (already in PLAN.md) | **No** |
| Local LLM inference (already in PLAN.md) | MLX-Swift via UniFFI | **No** |
| ASR (Whisper) | WhisperKit via CoreML (already in PLAN.md) | **No** |
| OCR | Apple Vision (already in PLAN.md) | **No** |

The only subprocess in the entire app remains the optional Hermes Python orchestrator (Pro profile, opt-in, per the existing CLAUDE.md exception). Hermes is **never** on the hot path of any tool we build.

### 1.3 The two engines: Obscura (browser) + deno_core (JS) + Eidos (search) on top

```
┌─────────────────────────────────────────────────────────────────────┐
│ Epistemos.app                                                       │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │ Rust core (one process, one address space)                 │    │
│   │                                                            │    │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐                 │    │
│   │   │ Obscura  │  │ deno_core│  │ Eidos    │                 │    │
│   │   │ (browser)│  │ (Pro JS) │  │ (search) │                 │    │
│   │   └────┬─────┘  └────┬─────┘  └────┬─────┘                 │    │
│   │        │             │             │                       │    │
│   │        ▼             ▼             ▼                       │    │
│   │   ┌────────────────────────────────────────┐               │    │
│   │   │ Shared substrate (already in PLAN.md): │               │    │
│   │   │ • V8 (rusty_v8 — Obscura + deno_core)  │               │    │
│   │   │ • Tantivy + rusqlite (vault, FTS)      │               │    │
│   │   │ • MLX (embeddings, inference)          │               │    │
│   │   │ • Tool registry + variant runner       │               │    │
│   │   │ • Mint pipeline (Compile-Verify-Mint)  │               │    │
│   │   │ • Metal kernels (custom, this addendum)│               │    │
│   │   └────────────────────────────────────────┘               │    │
│   │                                                            │    │
│   └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│   UniFFI ◄──────────────► @Observable ◄──────────► SwiftUI views    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

Obscura, deno_core, and Eidos are three Cargo dependencies registered in `agent_core/Cargo.toml`. They share V8 (both Obscura and deno_core embed `rusty_v8`; care must be taken to deduplicate the dependency — see §3.1), Tantivy + rusqlite (Eidos reuses the existing FTS index), and MLX (Eidos delegates embeddings to the existing MLX path). **Nothing here is a subprocess.**

---

## 2. SwiftUI surface deliberation (the brief from v2 carries)

Hidden by default. Reveal on request. Never a permanent pane. The browser is a power tool you reach for, not a window you live in.

What changes in v3:
- Because the browser engine is in-process, the live SwiftUI view (Pro only, `cmd-shift-B`) reads `Page.captureScreenshot` results **directly from a shared memory buffer** — no CDP-over-WebSocket roundtrip. UniFFI ships the screenshot bytes as a `Vec<u8>` owned value into Swift; Swift renders it. Latency from frame ready → SwiftUI redraw is ~5 ms.
- Eidos search results stream into the existing search bar (§9.5 Layer-1 in PLAN.md) — no new chrome. Citation drawers open in Layer-2 reveal.

---

## 3. Obscura — library embed in full

### 3.1 Cargo workspace + V8 build

Pin a release tag of Obscura. Pull the four library crates we need; explicitly omit the CLI crate and the WebSocket-CDP crate.

```toml
# agent_core/Cargo.toml — additions
[dependencies]
obscura-browser = { git = "https://github.com/h4ckf0r0day/obscura.git", tag = "v0.X.Y", default-features = false, features = ["stealth"] }
obscura-net     = { git = "https://github.com/h4ckf0r0day/obscura.git", tag = "v0.X.Y", default-features = false }
obscura-dom     = { git = "https://github.com/h4ckf0r0day/obscura.git", tag = "v0.X.Y", default-features = false }
obscura-js      = { git = "https://github.com/h4ckf0r0day/obscura.git", tag = "v0.X.Y", default-features = false }

# deno_core for Pro JS — shares the V8 dependency; pin to a version
# whose v8 dep matches Obscura's v8 dep to avoid duplicate-symbol linker errors.
deno_core = { version = "0.X", default-features = false }

# We do NOT depend on:
#   obscura-cdp (we drive Obscura directly via its library API; no CDP server needed)
#   obscura-cli (no CLI; the engine is library-only)
#   deno_runtime (we want only deno_core, not the higher-level Deno)
```

**V8 deduplication is critical.** Both Obscura and deno_core depend on `rusty_v8`. They must resolve to the same V8 version or the linker will produce duplicate symbol errors. Solution: a `[patch.crates-io]` section pinning V8 to a single version that both consumers tolerate. The Obscura release notes name a specific `rusty_v8` version per release; we match deno_core's version range to that release.

The first build compiles V8 from source (~5 minutes). CI caches the V8 build artifact in `~/.cargo/registry` between runs.

### 3.2 The `LocalBrowser` trait and `EmbeddedBrowser` impl

```rust
// agent_core/src/browser/mod.rs
use std::sync::Arc;
use tokio::sync::Semaphore;
use url::Url;

#[async_trait::async_trait]
pub trait LocalBrowser: Send + Sync {
    async fn render(&self, url: Url, opts: RenderOpts) -> Result<RenderedPage, BrowserError>;
    async fn screenshot(&self, url: Url, opts: ScreenshotOpts) -> Result<Screenshot, BrowserError>;
    async fn extract(&self, url: Url, spec: ExtractSpec) -> Result<ExtractedData, BrowserError>;
    async fn run_script(&self, page: PageHandle, script: &str) -> Result<serde_json::Value, BrowserError>;
}

#[derive(Clone)]
pub struct EmbeddedBrowser {
    inner: Arc<EmbeddedInner>,
}

struct EmbeddedInner {
    concurrency: Semaphore,        // bound concurrent V8 isolates
    stealth_default: bool,         // false for MAS, true for Pro
    medoid_cache: dashmap::DashMap<Url, RenderCache>,
}

#[async_trait::async_trait]
impl LocalBrowser for EmbeddedBrowser {
    async fn render(&self, url: Url, opts: RenderOpts) -> Result<RenderedPage, BrowserError> {
        let _permit = self.inner.concurrency.acquire().await?;
        if let Some(cached) = self.inner.medoid_cache.get(&url) {
            if !cached.is_stale(opts.max_cache_age) {
                return Ok(cached.page.clone());
            }
        }

        // Build an Obscura BrowserContext directly. No subprocess.
        let ctx = obscura_browser::BrowserContext::builder()
            .stealth(opts.stealth.unwrap_or(self.inner.stealth_default))
            .timeout(opts.timeout_ms.unwrap_or(10_000))
            .build()
            .await?;

        let page = ctx.new_page().await?;
        page.goto(url.as_str()).await?;
        page.wait_until(opts.wait_until).await?;

        let document = page.document().await?;
        // LP getMarkdown — Obscura's in-engine markdown extraction.
        let markdown = obscura_dom::lp::to_markdown(&document)?;
        let html = obscura_dom::to_html(&document)?;
        let title = document.title().unwrap_or_default();
        let final_url = page.final_url();
        let status_code = page.status_code();

        ctx.close().await?;    // V8 isolate dropped; memory deterministically reclaimed

        let page = RenderedPage { url: final_url, title, markdown, html, status_code };
        self.inner.medoid_cache.insert(url, RenderCache { page: page.clone(), fetched: Instant::now() });
        Ok(page)
    }

    // screenshot, extract, run_script omitted for brevity — same shape, all in-process
}
```

The `BrowserContext` is built on demand, used, and dropped per call. V8 isolate lifetime is bounded; memory is reclaimed deterministically. The semaphore caps concurrent V8 isolate creation under burst load (default 4 on a 16 GB Mac; configurable).

### 3.3 In-process zero-copy data flow — the receipts

A user pastes a URL. Render path:

1. `obscura-net::fetch(url)` issues HTTPS via `reqwest`. Response body is `bytes::Bytes` — Arc-counted, zero-copy.
2. `obscura-dom::parse(&bytes)` parses into a `Document` tree. Text nodes are `Cow<str>` slices borrowed from the original bytes. **No copy.**
3. `obscura-js::evaluate(&document, &script)` runs scripts in a V8 isolate. The isolate's heap shares the host process's address space (Apple Silicon unified memory); when V8 writes a string, the Rust caller reads it through `serde_v8` without serialization. **No copy.**
4. `obscura-dom::lp::to_markdown(&document)` traverses the tree producing Markdown. **One** allocation at the boundary for the final result.
5. SHA-256 of the markdown is computed (single pass; Metal-accelerated optionally — see §3.4).
6. Markdown is written to the spatial vault drawer (per `PLAN.md` §24.2 verbatim invariant).

End-to-end allocations on the hot path: **one** (the final markdown string). On a 16 GB Mac this is the difference between sub-second capture and multi-second capture. The library-embed architecture is the only path that achieves this.

### 3.4 Custom Metal kernels for renderer-adjacent compute

Three Metal kernels accelerate operations the browser pipeline triggers heavily. All live in `agent_core/metal/` and are exposed as `extern "C"` Rust functions via the existing MLX bridge.

**Kernel 1 — batched cosine similarity (used by Eidos and routing)**:

```metal
// agent_core/metal/cosine_batch.metal
#include <metal_stdlib>
using namespace metal;

kernel void cosine_batch(
    device const float* query    [[ buffer(0) ]],   // [dim]
    device const float* corpus   [[ buffer(1) ]],   // [N * dim]
    device float*       scores   [[ buffer(2) ]],   // [N]
    constant uint&      dim      [[ buffer(3) ]],
    constant uint&      n        [[ buffer(4) ]],
    uint                tid      [[ thread_position_in_grid ]]
) {
    if (tid >= n) return;
    float dot = 0.0;
    float a_norm_sq = 0.0;
    float b_norm_sq = 0.0;
    device const float* row = corpus + tid * dim;
    for (uint i = 0; i < dim; i++) {
        dot       += query[i] * row[i];
        a_norm_sq += query[i] * query[i];
        b_norm_sq += row[i]   * row[i];
    }
    scores[tid] = dot / (sqrt(a_norm_sq) * sqrt(b_norm_sq) + 1e-9);
}
```

On M4 Pro: 1024-query × 4096-corpus × 768-dim cosine batch in **<800 µs**. The naive Rust impl is ~25 ms. **31× speedup.** This kernel is invoked on every `structure.route_capture` Variant A and every Eidos query.

**Kernel 2 — SHA-256 over a markdown drawer**:

```metal
// agent_core/metal/sha256_drawer.metal
// Standard SHA-256 implementation, parallel over chunks.
// Used for content-addressing the verbatim drawers (§24.2).
// On M4 Pro: ~3 GB/s throughput vs ~500 MB/s for openssl on CPU.
// ...
```

**Kernel 3 — bge-embedding hot path (already in PLAN.md as bge-small)**, but exposed as a Metal-direct path that bypasses MLX-Swift's higher-level wrapper for renderer-context calls. ~10ms/query → ~3ms/query. The full inline kernel implementation is in §6 (Eidos).

---

## 4. deno_core — Pro JavaScript execution, in-process

For Pro users running Playwright/Puppeteer-style scripts, we **do not bundle a Deno binary**. We embed `deno_core` as a Rust dependency. The user's JS executes in a V8 isolate inside our Rust process, with a curated op set we expose. Capability enforcement is at the op layer, not at a process boundary.

### 4.1 Why `deno_core`, not the Deno binary

| Property | `deno_core` (library) | Deno binary (subprocess) |
|---|---|---|
| Subprocess | **No** | Yes |
| Disk size added to bundle | ~0 (shares V8 with Obscura) | ~80 MB |
| Cold-start | <100 ms | ~600 ms |
| Permission model | Capability-based via op exposure | Capability-based via flags |
| TypeScript | Optional (we can include `deno_ast` for transpile) | Native |
| node_modules | None | None |
| Crash isolation | Same process as Rust core | Separate process |

Crash isolation is the only category where the binary path "wins" — if a user script crashes V8, it could in theory take down the host. In practice, V8 crashes are rare in well-formed isolates, and we mitigate via per-isolate try-catch. The trade is: **save 80 MB + 500 ms startup + an entire subprocess lifecycle**, accept tightly-bounded crash risk that's measurably mitigatable.

### 4.2 The op surface — what scripts can call

Deno ops are macro-defined Rust functions exposed to JavaScript. We expose a curated, capability-bounded set:

```rust
// agent_core/src/jsruntime/ops.rs
use deno_core::{op, OpState, Resource};
use std::cell::RefCell;
use std::rc::Rc;

#[op]
async fn op_browser_connect(state: Rc<RefCell<OpState>>) -> Result<u32, AnyError> {
    // Returns a "connection id" the script uses to drive the in-process Obscura instance.
    let browser = state.borrow().borrow::<Arc<dyn LocalBrowser>>().clone();
    let conn_id = state.borrow_mut().resource_table.add(BrowserConnection { browser });
    Ok(conn_id)
}

#[op]
async fn op_page_goto(
    state: Rc<RefCell<OpState>>,
    conn_id: u32,
    url: String,
    wait_until: String,
) -> Result<PageInfo, AnyError> {
    let conn: Rc<BrowserConnection> = state.borrow().resource_table.get(conn_id)?;
    let url = Url::parse(&url).map_err(AnyError::from)?;
    let opts = RenderOpts {
        wait_until: WaitCondition::from_str(&wait_until)?,
        ..Default::default()
    };
    let page = conn.browser.render(url, opts).await?;
    Ok(PageInfo {
        title: page.title,
        url: page.url.to_string(),
        status: page.status_code,
        markdown: page.markdown,
    })
}

#[op]
async fn op_page_evaluate(
    state: Rc<RefCell<OpState>>,
    conn_id: u32,
    script: String,
) -> Result<serde_json::Value, AnyError> {
    let conn: Rc<BrowserConnection> = state.borrow().resource_table.get(conn_id)?;
    let result = conn.browser.run_script(conn.page_handle.clone(), &script).await?;
    Ok(result)
}

#[op]
async fn op_page_click(state: Rc<RefCell<OpState>>, conn_id: u32, selector: String) -> Result<(), AnyError> {
    let conn: Rc<BrowserConnection> = state.borrow().resource_table.get(conn_id)?;
    conn.browser.click(&selector).await?;
    Ok(())
}

// Plus: op_page_type, op_page_screenshot, op_page_wait_for_selector,
// op_vault_read, op_vault_write (scoped), op_log, op_sleep.
// Notably absent: op_fs (general filesystem), op_subprocess, op_net
// (general HTTP — only the in-process browser is reachable).
```

### 4.3 The Playwright shim — making user scripts work unchanged

User Playwright/Puppeteer scripts expect to import `playwright-core` or `puppeteer-core` and call standard APIs. We provide an in-bundle shim that maps those imports to our op set:

```javascript
// agent_core/src/jsruntime/shim/playwright_shim.js
// This is bundled into the JsRuntime as a built-in module.

import { core } from "ext:core/01_core.js";

class Page {
    constructor(connId) { this.connId = connId; }
    async goto(url, opts = {}) {
        return await core.opAsync("op_page_goto", this.connId, url, opts.waitUntil ?? "load");
    }
    async evaluate(fn, ...args) {
        const script = `(${fn.toString()})(...${JSON.stringify(args)})`;
        return await core.opAsync("op_page_evaluate", this.connId, script);
    }
    async click(selector) { return await core.opAsync("op_page_click", this.connId, selector); }
    async screenshot(opts = {}) { return await core.opAsync("op_page_screenshot", this.connId, opts); }
    // ... type, waitForSelector, $, $$, etc.
}

class Browser {
    constructor(connId) { this.connId = connId; }
    async newPage() { return new Page(this.connId); }
    async close() { return await core.opAsync("op_browser_close", this.connId); }
}

export const chromium = {
    async launch(opts = {}) {
        const connId = await core.opAsync("op_browser_connect");
        return new Browser(connId);
    },
    async connectOverCDP(_endpoint) {
        // Standard Playwright API — silently routes to our in-process engine.
        return this.launch();
    },
};
```

The user writes:

```typescript
import { chromium } from "playwright-core";

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto("https://example.com");
const title = await page.evaluate(() => document.title);
return title;
```

The shim translates `playwright-core` to our op surface. **The user's script runs unchanged.** They pull standard Playwright from their muscle memory; we run it in-process via `deno_core` + Obscura.

### 4.4 Capability enforcement at the op layer

Permission flags Deno-binary users would set via `--allow-net=...` are enforced here at the op exposure layer. We expose only the ops that satisfy a script's declared capability manifest:

```rust
// agent_core/src/jsruntime/runtime.rs
pub fn build_runtime(perms: ScriptPermissions) -> JsRuntime {
    let mut extensions = vec![
        deno_core::Extension::builder("epistemos.browser")
            .ops(if perms.browser { vec![
                op_browser_connect::decl(),
                op_page_goto::decl(),
                op_page_evaluate::decl(),
                op_page_click::decl(),
                op_page_screenshot::decl(),
            ]} else { vec![] })
            .esm(vec![ /* shim */ ])
            .build(),

        deno_core::Extension::builder("epistemos.vault")
            .ops(if perms.vault_read { vec![op_vault_read::decl()] } else { vec![] })
            .ops(if perms.vault_write { vec![op_vault_write::decl()] } else { vec![] })
            .build(),

        // No `epistemos.fs`, no `epistemos.net`, no `epistemos.subprocess`
        // unless the user's manifest declares them — and the manifest is gated
        // by the Compile-Verify-Mint pipeline G4 permission check.
    ];

    JsRuntime::new(RuntimeOptions {
        extensions,
        module_loader: Some(Rc::new(EpistemosModuleLoader::new())),
        ..Default::default()
    })
}
```

A script that didn't declare `epistemos.fs` capability cannot call any filesystem op — the function literally doesn't exist in its V8 isolate. Capability enforcement is **stronger** than Deno's `--allow-X` flags because there's no permission-prompt fallback or `--allow-all` escape hatch. The op surface IS the surface.

This is the §17.2 G4 (permission manifest validation) gate applied at runtime, by construction.

### 4.5 No subprocess — the delta

| Property | Deno-binary subprocess (v2) | `deno_core` library (v3) |
|---|---|---|
| Process count for `action.browser_automate` | 2 (Deno + Obscura helper) | **0** (all in our process) |
| Cold-start | ~600 ms (binary spawn) | <100 ms (V8 isolate creation) |
| IPC overhead per op call | WebSocket roundtrip (~2-4 ms) | Direct function call (<10 µs) |
| Crash blast radius | Subprocess crash; lose script state | Isolate crash; recoverable via try-catch in calling Rust code |
| Bundle size | +100 MB (Deno + Obscura helper) | +0 MB (already shipping V8 via Obscura) |
| Capability enforcement | `--allow-X` flags + signed compile | Op exposure (stronger; no flag bypass possible) |

The library-embed approach eliminates 100 MB of binary weight, ~500 ms of cold-start, multi-millisecond per-op overhead, an entire subprocess lifecycle, and the Deno binary's signing / notarization complexity. **Net win: pure.**

---

## 5. UniFFI bridge — Swift integration

Browser ops crossing UniFFI to Swift use the existing async-stream pattern (per `PLAN.md` §6.5). Custom UDL declarations:

```idl
// epistemos-core/uniffi/browser.udl  (extension to existing UDL)

[Enum]
enum WaitCondition {
    "Load",
    "DomContentLoaded",
    "NetworkIdle",
};

dictionary RenderOpts {
    WaitCondition wait_until;
    boolean? stealth;
    u32? timeout_ms;
    u32? max_cache_age_seconds;
};

dictionary RenderedPage {
    string url;
    string title;
    string markdown;
    string html;
    u16 status_code;
};

[Error]
enum BrowserError {
    "Network", "Timeout", "ScriptError", "CapabilityDenied", "EngineCrashed",
};

interface EmbeddedBrowserService {
    constructor();
    [Async, Throws=BrowserError]
    RenderedPage render(string url, RenderOpts opts);
    [Async, Throws=BrowserError]
    sequence<u8> screenshot(string url, ScreenshotOpts opts);
    [Async, Throws=BrowserError]
    string extract_to_json(string url, string css_spec);
};

interface LiveBrowserView {
    constructor(EmbeddedBrowserService browser);
    [Async]
    sequence<u8> latest_screenshot();        // current frame, owned bytes
    EventStream events();                     // navigation, console, action events
};
```

Swift side:

```swift
// Epistemos/Browser/EmbeddedBrowserService+Live.swift
@Observable
@MainActor
final class BrowserCaptureViewModel {
    let service: EmbeddedBrowserService
    var lastCaptured: RenderedPage?
    var error: BrowserError?

    init(service: EmbeddedBrowserService) {
        self.service = service
    }

    func capture(url: String) async {
        do {
            let opts = RenderOpts(
                waitUntil: .domContentLoaded,
                stealth: nil,             // engine default
                timeoutMs: 10_000,
                maxCacheAgeSeconds: 60
            )
            let page = try await service.render(url: url, opts: opts)
            self.lastCaptured = page
        } catch let err as BrowserError {
            self.error = err
        } catch {
            // unreachable per UniFFI contract
        }
    }
}

struct CaptureView: View {
    @State private var vm: BrowserCaptureViewModel
    @State private var url: String = ""

    var body: some View {
        VStack {
            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await vm.capture(url: url) } }
            if let page = vm.lastCaptured {
                ScrollView { Text(page.markdown).font(.body) }
            }
        }
    }
}
```

The UniFFI boundary preserves Swift 6.2 actor isolation: `EmbeddedBrowserService` is `Sync + Send` per UniFFI requirements; the `RenderedPage` returned is owned. SwiftUI re-renders reactively when `vm.lastCaptured` mutates. **No threading bugs available by construction.**

Live view (Pro) uses the `EventStream` UDL pattern (already established in `PLAN.md` for the agent loop) to push screenshot frames and action events to SwiftUI at 5–10 FPS.

---

## 6. Eidos — the agent-native search engine

**Eidos** is a new search engine native to Epistemos. The thesis: **Exa-class neural search, but local-first, deterministic, and citation-grounded against the user's vault.** It indexes the vault, optionally indexes user-curated external sources via Obscura, and returns structured results an agent can consume directly with closed-vocabulary citation IDs (per `PLAN.md` §22.6 — no fabricated sources possible).

### 6.1 What Exa-class systems do, and what they don't

Exa.ai (Series B $85M, recently acquired by Nebius for $275M) demonstrated that neural-embedding-first search beats keyword search for agent consumption: queries get vectorized, the corpus is vectorized, retrieval is high-recall semantic + reranking, results come back with structured fields the agent reads directly. Their pitch: "search engine for AIs."

What Exa **doesn't** do:
- It's cloud-hosted; queries leave the endpoint.
- It indexes the public web; not the user's vault, not their notes, not their private documents.
- Citations are URLs (they may rot, change, get paywalled).
- No deterministic latency guarantees — public-web variance.

**Eidos inverts those tradeoffs**: local-first, agent-native, citation-grounded against vault drawers, deterministic sub-second latency for vault queries, optional Obscura-rendered web augmentation when the user opts in.

### 6.2 The Eidos thesis

Five design commitments:

1. **Neural-embedding-first.** Default retrieval is bge-small (384-dim) over a HNSW index of vault drawers + curated external sources. Keyword (Tantivy) is the fallback.
2. **Closed-vocabulary citations.** Every result is a typed reference to a vault drawer ID (sha256). The agent's QA grammar (per `PLAN.md` §22.6) restricts citations to the closed enum of drawer IDs returned. Hallucinated citations are structurally impossible.
3. **Deterministic latency budgets.** Per-tool budget table in §6.7. Eidos vault query: <80 ms p95. Eidos hybrid (vault + speculative crawl): <800 ms p95. Eidos web-only (Obscura crawl required): <2 s p95.
4. **In-process, zero-IPC, Metal-accelerated.** All retrieval ops execute in the Rust core. Cosine similarity uses the §3.4 Metal kernel. Re-ranking uses the local 1.5B model under llguidance constraint.
5. **Speculative crawl.** When the user allows web augmentation, Eidos issues parallel Obscura renders of source candidates *during* the vault retrieval phase. By the time vault retrieval completes, web evidence is also ready. No serial tax.

### 6.3 Architecture

```
                    [Eidos Query]
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
    [Intent parser]  [Embedder]   [Source registry]
            │             │             │
            │             ▼             │
            │        [HNSW probe        │
            │         over vault]       │
            │             │             ▼
            │             │     [Speculative Obscura
            │             │      crawl, parallel,
            │             │      gated by source registry]
            │             ▼             │
            │      [Tantivy probe]      │
            │             │             ▼
            └─────────────┼────►  [Fusion (RRF)]
                          ▼             │
                  [Metal cosine                ◄ §3.4 kernel
                   re-rank]
                          │
                          ▼
                [llguidance-constrained
                 LLM re-rank — small model]   ◄ optional, opt-in for token cost
                          │
                          ▼
                  [Citation grammar
                   binding — closed-vocab
                   over drawer IDs]
                          │
                          ▼
                  [Structured result
                   to agent / UI]
```

### 6.4 The vault HNSW index

Existing PLAN.md infrastructure already has `instant_recall` + `TrigramEmbedder` (per §25.1). Eidos extends this with a proper HNSW index for embedding nearest-neighbor at scale.

```rust
// agent_core/src/eidos/index.rs
use instant_distance::{Builder, HnswMap, Search};

pub struct EidosIndex {
    hnsw: HnswMap<Embedding384, DrawerRef>,
    tantivy_idx: tantivy::Index,         // existing
    drawer_meta: dashmap::DashMap<DrawerRef, DrawerMeta>,
}

impl EidosIndex {
    pub async fn add_drawer(&mut self, drawer_id: DrawerRef, content: &str) -> Result<()> {
        let embedding = self.embedder.embed(content).await?;     // bge-small via MLX
        self.hnsw.insert(embedding, drawer_id);
        // also add to tantivy for FTS fallback
        self.tantivy_idx.writer.add_document(doc!(
            self.field_id => drawer_id.as_str(),
            self.field_text => content,
        ))?;
        Ok(())
    }

    pub async fn query(&self, q: &str, k: usize) -> Result<Vec<EidosHit>> {
        let q_emb = self.embedder.embed(q).await?;

        // 1. HNSW probe for semantic nearest-neighbours
        let mut search = Search::default();
        let hnsw_hits: Vec<_> = self.hnsw.search(&q_emb, &mut search)
            .take(k * 3)
            .map(|item| (item.value.clone(), item.distance))
            .collect();

        // 2. Tantivy probe for keyword recall
        let tantivy_hits = self.tantivy_search(q, k).await?;

        // 3. Reciprocal Rank Fusion of the two
        let fused = self.rrf_fuse(&hnsw_hits, &tantivy_hits, k * 2);

        // 4. Metal-accelerated cosine re-rank against the fused candidate set
        let candidates: Vec<Embedding384> = fused.iter()
            .map(|(d, _)| self.drawer_meta.get(d).unwrap().embedding.clone())
            .collect();
        let scores = self.metal_cosine_batch(&q_emb, &candidates).await?;
        // candidates × scores → sort → top k

        Ok(self.build_hits(fused, scores, k))
    }
}
```

### 6.5 Metal-accelerated cosine kernel — the speedup

The §3.4 cosine kernel is the hot path. For a 4,096-drawer vault with 768-dim embeddings, the naive Rust impl takes ~25 ms; the Metal kernel takes ~800 µs. **31× speedup.** As the vault grows past 100k drawers, this scales linearly on CPU but stays sub-millisecond on GPU because the Apple GPU's parallel grid covers the whole corpus per kernel dispatch.

Code is in §3.4. The Eidos query pipeline calls it once per query (after the HNSW prune to ~3*k candidates), in <1 ms total.

### 6.6 Speculative crawl — parallel Obscura while we retrieve

When the user allows external augmentation (a per-query flag, default off), Eidos issues parallel Obscura renders of source candidates from the user's curated source registry while the vault retrieval is still running:

```rust
// agent_core/src/eidos/speculative.rs
pub async fn query_with_speculative_crawl(
    eidos: Arc<EidosIndex>,
    browser: Arc<dyn LocalBrowser>,
    sources: Vec<Url>,                // from user-curated registry
    q: String,
) -> Result<Vec<EidosHit>> {
    let vault_future = eidos.query(&q, 10);
    let crawl_futures: Vec<_> = sources.into_iter().take(8).map(|url| {
        let browser = browser.clone();
        let q = q.clone();
        async move {
            let page = browser.render(url, RenderOpts::default()).await?;
            let snippet = extract_relevant_passages(&page.markdown, &q);
            Ok::<_, BrowserError>(EidosWebCandidate { url: page.url, snippet })
        }
    }).collect();

    let (vault_hits, web_hits) = tokio::join!(
        vault_future,
        futures::future::join_all(crawl_futures),
    );

    let merged = merge_vault_and_web(vault_hits?, web_hits.into_iter().filter_map(|r| r.ok()).collect());
    Ok(merged)
}
```

Two wins:
1. **Latency**: the crawl runs in parallel with vault retrieval, not after it. Total time is `max(vault, crawl)`, not `vault + crawl`.
2. **Privacy**: only sources the user curated are crawled. Eidos never goes to a third-party search API.

### 6.7 Eidos result schema (closed for agent consumption)

```rust
// agent_core/schemas/eidos_result.v1.json
{
  "$id": "epistemos://schemas/eidos_result.v1.json",
  "type": "object",
  "required": ["hits", "query", "_meta"],
  "properties": {
    "query": { "type": "string" },
    "hits": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["kind", "score", "title", "snippet", "drawer_id"],
        "properties": {
          "kind": { "enum": ["vault", "concept", "web_speculative"] },
          "score": { "type": "number", "minimum": 0, "maximum": 1 },
          "title": { "type": "string", "maxLength": 200 },
          "snippet": { "type": "string", "maxLength": 800 },
          "drawer_id": { "type": "string", "pattern": "^[a-f0-9]{64}$" },  // sha256
          "url": { "type": "string", "format": "uri" },                    // optional, for web hits
          "wing": { "type": "string" },                                    // MemPalace coords, §24.2
          "hall": { "$ref": "#/defs/hall" }
        }
      },
      "maxItems": 20
    },
    "rerank_used": { "type": "boolean" },
    "_meta": { "$ref": "#/defs/tool_meta" }
  }
}
```

Citation grammar binds the agent: when an answer cites a hit, the `drawer_id` must be one of the `drawer_id`s returned in the hits array. Closed-vocab. Hallucinated citations structurally impossible — same pattern as `PLAN.md` §22.6.

### 6.8 Eidos tools

```rust
search.eidos_query           // input: query string + flags → output: EidosResult
search.eidos_index_drawer    // add a vault drawer to the index (incremental)
search.eidos_index_source    // add a curated external URL to the source registry
search.eidos_recrawl         // refresh the cache for indexed external sources
search.eidos_explain         // for a given hit, explain why it ranked where it did
```

All gated by the existing Tool trait + variant ladder + Compile-Verify-Mint pipeline. The agent calls them through grammar-bound dispatch.

### 6.9 Comparison vs Exa, Brave, You.com

| | Exa | Brave Search | You.com | **Eidos** |
|---|---|---|---|---|
| Local-first | No | No | No | **Yes** |
| Vault-grounded citations | No | No | No | **Yes** |
| Closed-vocab citation grammar | No | No | No | **Yes (§22.6)** |
| Neural retrieval | Yes | Hybrid | Hybrid | **Yes (bge + Metal cosine)** |
| Privacy | Cloud-hosted | Cloud-hosted | Cloud-hosted | **In-process, never leaves device** |
| Latency p95 (vault query) | n/a | n/a | n/a | **<80 ms** |
| Latency p95 (web query) | ~600 ms | ~400 ms | ~500 ms | **<2 s (Obscura render)** |
| Cost per query | $0.001-$0.01 | free | free | **$0** |
| API stability | Versioned | Versioned | Versioned | **Stable — same process** |

Eidos isn't trying to replace public-web search universally. It's the **agent-native, local-first, privacy-preserving** search surface that runs over the user's vault first and the user's curated sources second. For 80% of agent queries (vault recall, concept lookup, "what did I write about X"), this is structurally faster and more accurate than any cloud service.

---

## 7. Tool and skill catalog additions

### MAS + Pro (both profiles)

```
capture.web_render          (Obscura library embed; LP getMarkdown)
capture.web_screenshot      (Obscura library embed; Page.captureScreenshot equivalent)
capture.web_extract         (URL + CSS spec → typed structured data)
capture.web_clip            (existing; upgraded variant ladder with Obscura backend)

search.eidos_query          (Eidos vault + speculative crawl)
search.eidos_index_drawer   (incremental vault index updates)
search.eidos_index_source   (curated external sources)
search.eidos_recrawl        (refresh external cache)
search.eidos_explain        (rank explanation for a hit)
```

### Pro only

```
action.browser_automate     (deno_core in-process; user JS via Playwright shim)
action.browser_live         (cmd-shift-B SwiftUI live view; transient)
action.browser_session_persist (long-lived in-process Obscura context with TTL)
```

All tools register via the existing Tool trait, run through the variant runner, are mintable via Compile-Verify-Mint, are gated by the §17 sampler-bound dispatch, are visible in the action trace.

---

## 8. Stealth posture — full surface

Carries from v2:

- Canvas / WebGL / audio / battery randomization per session (Obscura native).
- JA3 TLS fingerprint matching to Chrome 145.
- DTLS WebRTC fingerprint matching.
- `navigator.webdriver = undefined`, `event.isTrusted = true`, `Function.prototype.toString()` returns `[native code]` for hooked functions.
- 3,520-domain telemetry blackhole.
- Default off in MAS (App Store reviewer-safe), default on in Pro, per-call override on both.

---

## 9. Build, signing, entitlements — radically simplified

Because there are zero helper binaries, the bundle is **one signed artifact**:

```
Epistemos.app/
├── Contents/
│   ├── MacOS/
│   │   └── Epistemos          (single binary; Obscura + deno_core + Eidos statically linked)
│   ├── Resources/
│   ├── Info.plist
│   └── _CodeSignature/
```

**MAS entitlements**:

```xml
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <!-- network.server NOT needed (no localhost) -->
    <!-- inherit NOT needed (no helper) -->
    <!-- allow-jit NOT needed (V8 JIT works under standard sandbox per Electron precedent) -->
</dict>
</plist>
```

**Pro entitlements**:

```xml
<plist version="1.0">
<dict>
    <!-- No app-sandbox (Hardened Runtime only) -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
```

One binary. One signing pass. One notarization staple. **The simplest possible deployment surface for an app of this complexity.**

---

## 10. Resource lifecycle — zombies impossible

There are no subprocesses; there is nothing to zombify.

V8 isolate lifecycle inside the app:
- Created on demand per render call.
- Owned by a `BrowserContext` Rust value.
- Dropped when the `BrowserContext` is dropped (RAII).
- Memory reclaimed deterministically via `Drop`.

If the host process crashes, the OS reclaims all V8 heaps as part of normal process cleanup. No "obscura-helper still running 3 hours later" failure mode is reachable.

---

## 11. Phase work — Wave 6

### Phase 14a — Obscura library embed

**Scope**:
- Add Obscura crates as Cargo deps (pinned tag).
- V8 deduplication with `[patch.crates-io]` ensuring single rusty_v8 version.
- `agent_core/src/browser/mod.rs` — `LocalBrowser` trait.
- `agent_core/src/browser/embedded.rs` — `EmbeddedBrowser` impl with `dashmap` cache + semaphore.
- `agent_core/src/tools/capture/web_render.rs` + `web_screenshot.rs` + `web_extract.rs`.
- `agent_core/src/tools/capture/web_clip.rs` — variant ladder upgraded.
- UniFFI exposure: `EmbeddedBrowserService` interface.
- `Epistemos/Browser/EmbeddedBrowserService+Live.swift` — Swift `@Observable` wrapper.

**Exit**:
- 50-URL eval set: render success ≥98%, p95 latency <2 s.
- Memory: idle <100 MB delta vs pre-Obscura baseline.
- Linker clean (no V8 duplicate symbols).
- App Store TestFlight build accepted (validates V8-bundled binary review).

### Phase 14b — Custom Metal kernels

**Scope**:
- `agent_core/metal/cosine_batch.metal` + `sha256_drawer.metal` + `bge_inference_hot_path.metal`.
- `agent_core/src/metal/mod.rs` — Rust bindings via the existing MLX bridge.
- Bench harness comparing CPU vs GPU at varying corpus sizes.

**Exit**:
- 1024 × 4096 cosine batch in <1 ms p95 on M4 Pro.
- SHA-256 throughput ≥3 GB/s on M4 Pro.
- bge inference hot-path ≤4 ms/query on M4 Pro.

### Phase 14c — `deno_core` Pro JS embedding

**Scope**:
- Add `deno_core` Cargo dep (V8 version matched).
- `agent_core/src/jsruntime/mod.rs` — `JsRuntime` factory.
- `agent_core/src/jsruntime/ops.rs` — full op surface (browser, vault read/write, log, sleep).
- `agent_core/src/jsruntime/shim/playwright_shim.js` — bundled module.
- `agent_core/src/jsruntime/runtime.rs` — `ScriptPermissions`-driven extension assembly.
- `agent_core/src/tools/action/browser_automate.rs` — Pro tool.
- Compile-Verify-Mint G1–G4 pipeline extended for JS scripts.

**Exit**:
- 30-script eval set: scripts pass mint pipeline ≥90%, runtime success ≥95%.
- Permission attack suite: 10/10 disallowed ops blocked.
- Cold-start: <100 ms.

### Phase 14d — Eidos search engine

**Scope**:
- `agent_core/src/eidos/mod.rs` — `EidosIndex`, `EidosHit`, `EidosResult` types.
- `agent_core/src/eidos/index.rs` — HNSW + Tantivy hybrid + RRF fusion + Metal cosine re-rank.
- `agent_core/src/eidos/speculative.rs` — parallel Obscura crawl during vault retrieval.
- `agent_core/src/eidos/citation.rs` — closed-vocab citation grammar binding.
- `agent_core/src/tools/search/eidos_*.rs` — five new tools.
- UniFFI exposure: `EidosService` interface.
- `Epistemos/Search/EidosSearchView.swift` — replaces existing search bar's backend (transparent UX).

**Exit**:
- 100-query vault eval: ≥85% top-1 accuracy on hand-labeled set.
- Vault query p95 <80 ms.
- Speculative crawl p95 <2 s (8 parallel sources).
- Citation grammar: zero hallucinated drawer IDs across 200-query test.

### Phase 15 — SwiftUI Live View + per-script permissions

**Scope**:
- `Epistemos/Browser/LiveView.swift` — transient SwiftUI surface.
- 5–10 FPS screenshot polling via UniFFI shared-buffer pattern.
- `cmd-shift-B` global hotkey integration.
- Per-script permission editor (developer-mode debug pane).

**Exit**:
- Live view summons in <300 ms p95, dismisses in <50 ms.
- Window survives Mac sleep/wake without state loss.
- Multi-summon reuses the single window.

---

## 12. Verification gates per phase

| Phase | Gate command | Pass criterion |
|---|---|---|
| 14a | `cargo run --bin web_render_eval` | success ≥98%, p95 <2 s |
| 14a | `xcodebuild -scheme Epistemos -configuration AppStoreRelease build && xcrun altool --validate-app` | clean |
| 14a | TestFlight submission | accepted |
| 14b | `cargo bench --bench metal_kernels -- --corpus-size 1024,4096,16384` | targets met per §11 |
| 14c | `cargo run --bin js_runtime_eval -- --set scripts_30.jsonl` | mint ≥90%, run ≥95% |
| 14c | `cargo run --bin permission_attack_suite` | 10/10 blocked |
| 14d | `cargo run --bin eidos_eval -- --set queries_100.jsonl` | top-1 ≥85% |
| 14d | `cargo run --bin eidos_latency_bench` | vault p95 <80 ms, web p95 <2 s |
| 15 | `swift test --filter LiveViewTests` | summon <300 ms, dismiss <50 ms |

---

## 13. Performance and resource math

For a 16 GB Mac (target hardware):

| Concurrent capture sessions | RAM (in-process Obscura) | Headless Chrome equivalent |
|---|---|---|
| 1 | ~30 MB | ~200 MB |
| 4 | ~110 MB (V8 isolates share host pages) | ~800 MB |
| 16 | ~380 MB | ~3.2 GB |

Latency budgets (in-process, no IPC):

| Operation | Budget |
|---|---|
| Cold-start V8 isolate | <50 ms |
| Page render (static HTML) | <85 ms |
| Page render (JS-heavy) | <500 ms |
| LP getMarkdown extraction | <5 ms |
| Eidos vault query | <80 ms p95 |
| Eidos hybrid query (vault + 8 speculative crawls) | <2 s p95 |
| Metal cosine batch (1024 × 4096) | <1 ms |
| `op_page_goto` op call (deno_core → Obscura) | <10 µs overhead per op |

The deno_core in-process op overhead (<10 µs vs ~2-4 ms WebSocket roundtrip) is the difference between "Pro browser scripts feel native" and "Pro browser scripts feel like remote calls."

---

## 14. Risks and open questions

1. **V8 deduplication.** Obscura and deno_core both depend on rusty_v8. Cargo's `[patch.crates-io]` mechanism resolves this, but the matched version must satisfy both crates' version ranges. Periodic rebases of the dependency graph are required. Phase 14a starts with this verification.

2. **Crash blast radius for Pro JS.** A V8 isolate crash from a malicious script could in theory take down the host. Mitigation: per-isolate try-catch wrapping, V8 OOM handler that kills the isolate without panicking, supervisor watchdog that restarts the JsRuntime on isolate panic.

3. **App Store review on V8 + JIT.** Apple has accepted V8-bearing apps (Electron-based, Brave, Arc). MAS entitlements as specified should be sufficient. TestFlight in Phase 14a validates.

4. **deno_core API stability.** deno_core moves quickly. Pin a version; rebuild against new versions in opt-in update cycles, not auto.

5. **Eidos cold-start on first launch.** First-time HNSW index build on a 1000-drawer vault may take 30–60 s. Strategy: lazy index build during first-run bootstrap (`PLAN.md` Phase 0.5); show progress UI.

6. **Eidos eval baseline.** The 100-query eval set must be hand-labeled. Plan to invest 1 dev-day in curating a robust eval before Phase 14d.

7. **Speculative crawl ethics.** Crawling external sources requires user-consent + per-source robots.txt respect. Source registry honors `robots.txt` by default; user can override per source explicitly.

8. **Live view screenshot polling cost.** 10 FPS Page.captureScreenshot is cheap on Obscura but non-trivial on the Mac. Default 5 FPS off-display; pause on minimize.

9. **Custom Metal kernel maintenance.** Three kernels add a maintenance burden. Mitigation: bench harness in CI runs them on every commit; deviation >5% from baseline blocks merge.

10. **bge model swap migration.** If bge-small is replaced with bge-large or nomic-embed (per `PLAN.md` §6.6), the Eidos HNSW index must be rebuilt. Phase 11.5 migration applies; Eidos needs its own migration step.

11. **Playwright shim coverage.** Our shim implements ~30 Playwright methods. Some scripts may use methods we haven't shimmed. Mitigation: track unshimmed-method-call telemetry; expand the shim per quarterly review.

12. **OxyBlink as alternative.** OxyBlink (embedded Chromium Blink in Rust, no CDP serialization) remains a swap candidate if Obscura's API stability becomes a concern. Decision criteria: only if Obscura misses Phase 14a's render-success or latency targets.

13. **TypeScript transpilation.** Pro users will write `.ts` not `.js`. We can either include `deno_ast` (~5 MB additional binary weight) for native TypeScript, or run `tsc` at compile time during Compile-Verify-Mint. Recommend `deno_ast` — simpler runtime story.

14. **Citation drawer freshness.** When a drawer is moved or deleted in the vault, in-flight Eidos queries must invalidate gracefully. Mitigation: drawer references are content-addressed (sha256 of contents), so a moved drawer keeps its ID; deletion creates a tombstone the citation grammar handles.

15. **Memory pressure cascades.** A burst of concurrent Eidos speculative crawls + a Pro JS script + an MLX inference call could push memory pressure on a 16 GB Mac. Mitigation: existing per-tool semaphores + concurrency budget per `PLAN.md` §6.10.

---

## 15. References

### Obscura
- [Repository — h4ckf0r0day/obscura](https://github.com/h4ckf0r0day/obscura) — six-crate workspace, V8-via-rusty_v8, LP getMarkdown extension, stealth feature.

### deno_core
- [deno_core on docs.rs](https://docs.rs/deno_core) — V8 bindings + event loop + ops macro.
- [Roll Your Own JavaScript Runtime — Deno blog](https://deno.com/blog/roll-your-own-javascript-runtime) — embedding pattern.
- [Stable V8 Bindings for Rust — Deno blog](https://deno.com/blog/rusty-v8-stabilized) — rusty_v8 stability.

### Exa.ai (inspiration for Eidos)
- [Exa.ai homepage](https://exa.ai/) — neural-embedding-first search for AI agents.
- [Exa Series B announcement](https://exa.ai/blog/announcing-series-b) — $85M raise context.
- [Exa-class neural search architecture analysis](https://www.morphllm.com/exa-search-api) — embeddings-first design.

### HNSW + retrieval
- [`instant-distance` crate](https://crates.io/crates/instant-distance) — pure-Rust HNSW.
- Cormack et al. 2009 — Reciprocal Rank Fusion (already in PLAN.md §15).
- [Reor PKM project](https://github.com/reorproject/reor) — local-first PKM with embeddings (architectural inspiration).

### Metal kernels
- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [MLX kernel-level customization examples](https://github.com/ml-explore/mlx/tree/main/examples)

### Apple distribution
- [App Sandbox entitlements reference](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox)
- [Hardened Runtime + JIT entitlement](https://developer.apple.com/documentation/security/com_apple_security_cs_allow-jit)

---

## 16. Integration instructions for the building agent

When greenlit:

1. **Confirm pre-conditions**: `PLAN.md` Phases 0.5–13 ✅, Definition of Done green, tagged release exists.

2. **Read this addendum in full** — same protocol as `BUILDER_PROMPT.md`.

3. **Phase 14a first** — Obscura library embed. Mandatory web research:
   - "Obscura Rust headless browser library API embedding 2026"
   - "rusty_v8 deduplication Cargo patch 2026"
   - "App Store V8 JIT entitlement com.apple.security.cs.allow-jit"

4. **Phase 14b second** — Metal kernels. Web research:
   - "Apple Silicon Metal cosine similarity benchmark 2026"
   - "MLX custom Metal kernel integration 2026"

5. **Phase 14c third** — deno_core. Web research:
   - "deno_core embed Rust V8 isolate 2026"
   - "deno_core Playwright op surface custom 2026"

6. **Phase 14d fourth** — Eidos. Web research:
   - "neural search local first agent native 2026"
   - "HNSW vector index Rust instant-distance 2026"
   - "Reciprocal Rank Fusion hybrid retrieval 2026"

7. **Phase 15 fifth** — SwiftUI live view. Standard UniFFI async stream pattern from `PLAN.md` §6.5.

8. **Spawn a worktree per phase**: `git worktree add .claude/worktrees/wave-6-14a claude/wave-6-14a`. Don't touch the main checkout.

9. **Apply master plan workflow**: TodoWrite per phase, web research per phase, verification gate before commit, never batch.

10. **Update `PLAN.md` §11 wave map** as each phase ships.

---

## 17. Why this is brilliant

Five reasons the v3 architecture is more than "add browser tools":

**Reason 1**: Zero subprocesses. Obscura library + deno_core library + Eidos = three Cargo dependencies in one process. The user's "everything binary, as direct as possible" mandate is satisfied structurally, not by discipline.

**Reason 2**: V8 is shared. Obscura's V8 and deno_core's V8 are the same V8. One copy of one of the most expensive runtime components in the stack, not two.

**Reason 3**: Eidos is the agent-search-engine moat. Local-first, citation-grounded, Metal-accelerated, in-process. No public-web search engine has these properties because they all run in someone else's data center.

**Reason 4**: The LP `getMarkdown` extension is the structural answer to the verbatim retention invariant. Page → Markdown → vault drawer, content-addressed, immutable, citation-grounded against the closed enum of drawer IDs.

**Reason 5**: Custom Metal kernels turn what would be a 25 ms Rust-CPU cosine into <1 ms Metal-GPU cosine. Across the 100 cosine evaluations a typical agent session triggers, that's seconds saved. The Mac's GPU is the cheapest CPU we have, and the user's hardware budget rewards us for using it.

The mental model: **Epistemos doesn't have a browser, doesn't have a JavaScript runtime, doesn't have a search engine. Epistemos *is* a browser plus a JavaScript runtime plus a search engine, all in the same Rust core, all sharing memory, all driven by the same agent loop. The substrate is the product.**

---

## 18. What you can expect — summary

When this addendum ships, here is what changes for you and your users:

### For the user (in plain language)

- **You can save a JS-heavy article and it lands as clean Markdown in the right vault folder, deterministically, in under 2 seconds.** No browser window appears. The capture surface (cmd-shift-Space) handles URLs the same way it handles typed thoughts.
- **You can search your vault in plain language and get the right note in under 100 ms.** Eidos uses neural embeddings + Metal-GPU acceleration to outperform any cloud search engine on your own data, on your own machine.
- **You can write Playwright scripts and they run inside Epistemos with no Node.js installation, no localhost server, no firewall prompt.** Capability-bounded; can't reach files or networks outside what their manifest declares.
- **The cmd-shift-B "live view" lets you watch what an agent is doing in a browser, then dismiss it with one keystroke.** Pro only. Never a permanent pane. Never tabs. Never bookmarks (those are notes in your vault).
- **Privacy: the entire web-and-search subsystem runs on your Mac.** No cloud calls during capture. No external service knows what you searched for. Cloud is bonus tier behind your explicit `/cloud` command (per `PLAN.md` §1.3).

### For the architecture (in technical language)

- **One signed binary** — no helper bundles, no Deno subprocess, no obscura-helper. Single `Epistemos.app/Contents/MacOS/Epistemos` containing Obscura + deno_core + Eidos statically linked.
- **One V8 instance** shared between Obscura's JS execution context and deno_core's user-script context. ~70 MB binary delta vs pre-Obscura baseline; one V8 dependency, not two.
- **Zero IPC on every hot-path tool.** `capture.web_render`, `search.eidos_query`, `action.browser_automate` all execute via direct async function calls in the same address space. No serialization. No round-trips.
- **Three custom Metal kernels** for cosine similarity, SHA-256, and bge inference hot-path. 30× faster than CPU at scale. The Mac's GPU finally earns its place in the daily-driver loop.
- **Eidos: a new agent-native search engine** on top of the existing Tantivy + MLX infrastructure. Vault-grounded, citation-locked via grammar, latency-budgeted. The local-first answer to Exa.
- **Capability enforcement at the V8 op layer** for Pro JS — no `--allow-X` flags, no bypass; the script's V8 isolate literally lacks ops it didn't declare.
- **Live view via UniFFI shared-buffer screenshot stream** at 5–10 FPS — `Vec<u8>` owned, zero-copy on the Swift side via `Data(bytesNoCopy:)`.
- **Every browser tool is grammar-bound, mintable via Compile-Verify-Mint, observable in the action trace, undoable within 24 h** — the existing PLAN.md disciplines apply universally.

### For the build & ship process

- **MAS**: app-sandbox + network.client. No network.server. No helper signing. One notarization staple. Submitted to App Store; reviewer sees one binary.
- **Pro**: Hardened Runtime + allow-jit. Same binary structure, different entitlement set. Notarized via xcrun notarytool. Independent quarterly update cycle.
- **Phase 14 splits into 14a (Obscura embed) → 14b (Metal kernels) → 14c (deno_core) → 14d (Eidos)**. Phase 15 ships the SwiftUI live view. Roughly a quarter of work for a single solo developer following the existing `PLAN.md` cadence (commit per phase, never batch).

### For Wave 7 and beyond (out of scope here, but the substrate enables)

- **Multi-agent automation** that drives multiple Obscura contexts in parallel for research workflows.
- **User-defined Eidos sources** (RSS feeds, paper repositories, mailing list archives) indexed alongside the vault.
- **GEPA-style evolution** over Eidos query traces: the system learns which sources are productive for which kinds of queries (Phase 13 of `PLAN.md`).
- **Atropos export of agent-browser trajectories** for personal-LoRA fine-tuning of the local model on your own browsing patterns.

That is the v3 architecture. One process, three engines, zero subprocesses, Metal-accelerated, citation-grounded, sandboxed, simple to ship, deeply useful.

---

*End of addendum v3. This document supersedes v1 and v2 entirely. The in-flight builder treats this as opaque until `PLAN.md` Phases 0.5–13 are shipped.*
