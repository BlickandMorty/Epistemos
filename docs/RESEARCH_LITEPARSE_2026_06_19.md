# R-LITEPARSE — ProvenanceGate verdict (2026-06-19)

**Owner ask:** dedicated PDF→Markdown import via run-llama/liteparse. Link the Rust core
as a crate into `agent_core` (like `epistemos-shadow` / the Goose Work seam), expose
`pdf_to_markdown` over UniFFI, **NO Python/Node sidecar**. Then: (1) native PDF→md in
agent_core; (2) note-sidebar IMPORT button → markdown note in vault; (3) BULK import many
PDFs; (4) Settings bulk PDF import; (5) polished feature (progress / honest per-file
status).

## What liteparse is (primary source: github.com/run-llama/liteparse)
- **License: Apache-2.0** (confirmed via `gh api`). Permissive, App-Store/closed-source
  compatible → ProvenanceGate **`direct_import`** OK.
- **84% Rust** workspace. Crates: `liteparse` (core), `pdfium` + `pdfium-sys` (in-process
  PDF rendering), `liteparse-napi` / `liteparse-python` / `liteparse-wasm` (bindings — NOT
  imported; the Node/Python bindings are the sidecar shape we reject).
- **Core public API** (`crates/liteparse/src/lib.rs`): `LiteParse` / `ParseResult` /
  `LiteParseConfig` / `OutputFormat` (incl. Markdown). The PDF→markdown engine is
  `parser.rs` + `extract.rs` + `projection.rs` (212 KB layout/projection algorithm) +
  `conversion.rs` + `ocr*`.
- **PDF path = IN-PROCESS** (PDFium via `pdfium-sys`, links the PDFium C library). **OCR =
  IN-PROCESS** (`tesseract-rs` with the `build-tesseract` feature, the default — compiles
  Tesseract in). Both are **MAS-safe** (no subprocess).

## The MAS hazard (the owner's caveat, confirmed)
`crates/liteparse/src/conversion.rs` routes **non-PDF** inputs through EXTERNAL BINARIES:
- `convert_to_pdf` / `execute_command` / `execute_powershell` → `tokio::process::Command`
  (LibreOffice / soffice / powershell) for Office formats.
- `resolve_image_magick_command` / `is_image_magick_binary` → ImageMagick for images.
- `reqwest` is also pulled (a remote-OCR API option).
These are **NOT MAS-safe** (hardened-runtime + sandbox block subprocess from a notarized
app; remote OCR leaks the document). The crate also enables `tokio` `process` + `fs`.

## Verdict: `direct_import`, PDF+OCR ONLY, subprocess/remote paths EXCLUDED
1. **Posture:** `direct_import` (Apache-2.0). Vendor/link `liteparse` + `pdfium` +
   `pdfium-sys` as crates (path or vendored). Do NOT pull the napi/python/wasm crates.
2. **Scope (NON-NEGOTIABLE, MAS):** accept **PDF only** (PDFium in-process) + **in-process
   Tesseract OCR** (`build-tesseract`). REJECT every non-PDF input at the seam — never
   call `convert_to_pdf` / `execute_command` / ImageMagick / the remote-OCR `reqwest`
   path. Compile-exclude or never-reach the subprocess code (`tokio` `process` feature off
   on the MAS surface; the seam's `is_supported_pdf` gate is the first guard).
3. **UniFFI:** expose `pdf_to_markdown(pdf_path) -> Result<String, LiteParseError>` from
   `agent_core` (wrapping `LiteParse` on PDF input) + a status JSON for the import UI.
4. **No-hidden-fallback:** a non-PDF returns `UnsupportedFormat` honestly; a PDF that
   can't parse returns `Failed` — NEVER fake markdown, NEVER a silent shell-out.
5. **Native-dep follow-on (heavy, multi-pass):** wiring PDFium (the prebuilt PDFium binary
   + `pdfium-sys` link) and `tesseract-rs` `build-tesseract` (compiles Tesseract +
   leptonica from source — a real build-script + bundled-data step) into the
   `build-agent-core.sh` / Xcode build, then signing/notarization of the added native
   libs. This is the bulk of the work and where owner build verification is essential.

## Sequenced slices
1. **S1 ✅ (this pass):** ProvenanceGate verdict + `agent_core/src/liteparse.rs` SEAM —
   always-compiled, INERT (`EngineNotWired`), PDF-only gate baked in (`is_supported_pdf`),
   non-PDF rejected honestly (no subprocess), `#[uniffi::export] liteparse_status_json`,
   flag `EPISTEMOS_LITEPARSE_PDF_V0`. cargo `--lib` green BOTH profiles. Mirrors the Goose
   Work Seam B / Osaurus S2 pattern.
2. **S2:** vendor the `liteparse` + `pdfium` + `pdfium-sys` crates into the workspace
   (Apache-2.0 `direct_import`), `tokio` `process`/`reqwest` features OFF, build the PDFium
   link + `tesseract-rs` — get a real PDF→markdown running under cargo (a fixture PDF).
3. **S3:** the real `pdf_to_markdown` body (replace the inert seam) behind the flag.
4. **S4:** Swift `LiteParseImport` (FFI bridge) + the note-sidebar IMPORT button (owner #1
   of the 5 sub-items) → a markdown note in the vault. build-for-testing + owner in-app.
5. **S5+:** bulk import (sidebar + Settings) + the polished feature (per-file progress /
   honest status). Owner build+run verify a real PDF imports in-app.

## Net
Apache-2.0 makes liteparse a license-clean `direct_import`, and its PDF (PDFium) + OCR
(Tesseract) paths are in-process = MAS-safe — a PERFECT fit for the no-sidecar mandate.
The ONLY hazard is the Office/image **subprocess** + remote-OCR paths, which the seam's
PDF-only scope excludes from day 1. S1 (verdict + inert MAS-safe seam) lands now; the
native-dep vendor (PDFium/Tesseract build) is the heavy multi-pass follow-on needing owner
build verification.
