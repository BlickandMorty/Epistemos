# Vendored: run-llama/liteparse (PDF→Markdown core)

**Owner directive (2026-06-19): APP-NATIVE BY EMBEDDING.** The real liteparse Rust source
is vendored here as a first-class native part of `agent_core` — not a wrapper that shells
out to an external CLI/service.

| | |
|---|---|
| Upstream | https://github.com/run-llama/liteparse |
| License | **Apache-2.0** (see `LICENSE`) → ProvenanceGate verdict `direct_import` |
| Vendored crates | `crates/pdfium-sys`, `crates/pdfium`, `crates/liteparse` (PDF path only) |
| Omitted | `liteparse-napi`, `liteparse-python`, `liteparse-wasm` (language bindings — Epistemos calls the Rust core directly) |
| Consumer | `agent_core/src/liteparse.rs` → `pdf_to_markdown` (UniFFI: `liteparse_pdf_to_markdown`) |

## Scope — PDF only, in-process (MAS-safe core)

The Epistemos seam calls liteparse with `ocr_enabled: false` and rejects non-PDF inputs
up front. So the only reachable path is **PDFium spatial-text extraction in-process**
(`liteparse-pdfium-sys` loads PDFium via `libloading`/dlopen) → Markdown. The reachable
path does **not** touch:
- Tesseract OCR — dropped at compile time (`default-features = false` removes the
  `tesseract-rs` build-from-source dependency).
- LibreOffice / ImageMagick Office/image conversion — those upstream paths spawn external
  **subprocesses** (`conversion.rs`) and are NOT MAS-safe; a non-PDF input is rejected
  honestly here, never shelled out.

## Build gating — `liteparse-pdf` feature (OFF by default)

`agent_core`'s `liteparse-pdf` feature gates this dependency. **OFF (default / MAS build):**
the crates are not linked and `pdf_to_markdown` returns `EngineNotWired` honestly — the MAS
binary carries no PDFium/bindgen. **ON (`--features liteparse-pdf`, Pro/dev):** the real
engine is compiled.

`pdfium-sys`'s `build.rs` auto-downloads the prebuilt PDFium binary to `~/Library/Caches/
pdfium-rs/...` at build time. **Runtime note (owner's signed-build step):** a sandboxed
Mac App Store app cannot `dlopen` from `~/Library/Caches`; to ship the live engine the
PDFium dylib must be **bundled into the `.app` and code-signed**, with the lib path
resolved to the bundle (`PDFIUM_LIB_PATH` / `vendor/pdfium/release/lib`). Until then the
engine is **embedded + Pro/dev-gated**, honest about needing that bundling to run in MAS.

Do not edit the vendored crate sources in place. To update, re-vendor from a pinned
upstream tag and re-run the ProvenanceGate review.
