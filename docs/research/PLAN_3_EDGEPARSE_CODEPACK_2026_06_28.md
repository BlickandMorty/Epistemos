# Plan 3 — EdgeParse PDF→md vendoring (clone-ready code, Pass 3)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §1`. Swap EdgeParse in behind the EXISTING liteparse FFI envelope
> so the wired Swift import UI works unchanged. `[VERIFIED-CODE]` = read this pass; `[INFERRED]` = bind at vendor time.

## Verified ground truth
- FFI envelope the Swift side decodes: `{"ok":true,"markdown":…}` / `{"ok":false,"error":…}` — produced by
  `liteparse_pdf_to_markdown` (`agent_core/src/liteparse.rs:129-141`), decoded by `LiteParseImportEnvelope.decode`
  (`Epistemos/LiteParse/LiteParseImport.swift:22-37`, ignores unknown keys, matches `"not wired"`/`"unsupported format"`).
- Vendoring template: `agent_core/vendor/liteparse/` (workspace; napi/python/wasm crates deliberately NOT vendored).
  Path-dep `Cargo.toml:692`, feature `liteparse-pdf` (`:42`) OFF (`default=["mas-build"]`, `mas-build=[]` `:11-12`).
- `SDPage.frontMatter` = `[String:String]` over JSON `frontMatterData: Data?` (`SDPage.swift:144-170`); setting
  `page.frontMatter["k"]=v` round-trips. Import writes file-first into `<vault>/Imported PDFs/`
  (`LiteParsePDFImportController.swift:14,37-59`, `needsVaultSync=false`).
- **DONE:** Settings keys `parsePDFOnImport`/`defaultOpenForImportedPDF`, frontmatter `source_pdf`/`source_kind`,
  and `ViewOriginalPDFAffordance` now exist. `LiteParseSourcePDFLink` resolves `source_pdf` only inside the current
  vault and rejects absolute or `..` paths; Plan 2 still owns the actual `PDFView` viewer.

## 1. Vendor (clone the pure-Rust core only, pin a SHA)
```bash
# core + path-dep sub-crates only; SKIP *-py / *-napi / *-wasm (same rule liteparse got)
git clone --depth 1 --branch <SHA> <edgeparse-repo> /tmp/edgeparse
mkdir -p agent_core/vendor/edgeparse/crates
for c in core pdf unpdf; do cp -R /tmp/edgeparse/crates/edgeparse-$c agent_core/vendor/edgeparse/crates/ 2>/dev/null; done
cp /tmp/edgeparse/{Cargo.toml,LICENSE*,NOTICE*} agent_core/vendor/edgeparse/ 2>/dev/null
( cd /tmp/edgeparse && git rev-parse HEAD ) > agent_core/vendor/edgeparse/VENDOR_SHA.txt
# then hand-edit vendor/edgeparse/Cargo.toml [workspace].members → ONLY core(+pdf/unpdf); drop binding members
```
`agent_core/Cargo.toml`:
```toml
edgeparse-pdf = ["dep:edgeparse-core"]   # pure-Rust, no PDFium/Tesseract/subprocess → MAS-SAFE
parser-unpdf  = ["dep:edgeparse-unpdf"]  # multilingual fallback
mas-build     = ["edgeparse-pdf", "parser-unpdf"]   # was []  → flips the default MAS engine ON
# [dependencies]
edgeparse-core  = { path = "vendor/edgeparse/crates/edgeparse-core",  default-features = false, optional = true }
edgeparse-unpdf = { path = "vendor/edgeparse/crates/edgeparse-unpdf", default-features = false, optional = true }
```
ProvenanceGate: Apache-2.0 + pure-Rust + in-process → `direct_import` (strictly safer than liteparse — no native
dylib). Write `docs/RESEARCH_EDGEPARSE_2026_06_28.md` (template = `RESEARCH_LITEPARSE_2026_06_19.md`) recording
license + pinned SHA + excluded binding crates + "no subprocess/no network" scope.

## 2. Rust — new `agent_core/src/pdf_parse.rs` (re-exports the SAME FFI symbol)
Owns EdgeParse + unpdf fallback; emits the same envelope. Inert build returns honest `EngineNotWired`; live build
(`--features edgeparse-pdf`) does real in-process extraction; low-confidence/empty → unpdf fallback; non-PDF rejected.
Re-exports `liteparse_pdf_to_markdown` (so a single binding regen flips the engine, no Swift change) + adds additive
`json_boxes`. **Gate the original `liteparse.rs:101,129` live body + FFI export with
`#[cfg(all(feature="liteparse-pdf", not(feature="edgeparse-pdf")))]`** to avoid a duplicate symbol. Add a
`pdf_parse_status_json` mirroring `liteparse_status_json`. Integration seam (bind to EdgeParse's real API at vendor
time, `[INFERRED]`): `edgeparse_core::Document::open(path) → .to_markdown() → .confidence()/.text()/.boxes_json()`;
`edgeparse_unpdf::extract_markdown(path)`. Confidence threshold `EDGEPARSE_MIN_CONFIDENCE=0.55`. Register
`pub mod pdf_parse;` at `lib.rs:170`.

## 3. Swift coexistence (keep original PDF + parsed md) — DONE
- **`LiteParseImportSettings.swift`:** `parsePDFOnImport` (default **ON**), `defaultOpenForImportedPDF` (default OFF).
- **`LiteParsePDFImportController.importPage`:** gates on `parsePDFOnImport` at top (honest `.rejected` when off);
  after writing the `.md`, **`copyItem` (never move) the original `.pdf`** into `<vault>/Imported PDFs/` and set
  `page.frontMatter["source_kind"]="pdf"` + `["source_pdf"]=<copied path>` (copy is non-fatal — note still imports).
- **`ViewOriginalPDFAffordance.swift`:** a button shown when `source_kind=="pdf"` + file exists; calls an injected
  `openOriginalPDF(path)` that defaults to a **no-op stub** — the actual `PDFView` viewer is **Plan 2**; this only
  emits the link + button. `source_pdf` resolution is vault-bound and traversal-safe.

## 4. What stays vs what to flip
**Unchanged (zero edits):** `LiteParseImport.swift` decoder + `LiveLiteParsePDFImporter`; `LiteParseImportHealthRow`;
the file-first note creation; the gate reader. **Flip:** (1) `Cargo.toml:12` `mas-build=[] → ["edgeparse-pdf","parser-unpdf"]`
(turns the default MAS engine from inert→real); (2) the `EPISTEMOS_LITEPARSE_PDF_V0` UI default (keep as kill-switch,
drive "active" off compiled-engine status); (3) regen UniFFI (`bash build-agent-core.sh`) — symbol name preserved, no
Swift call-site change. **Verify:** `cargo test --features edgeparse-pdf,parser-unpdf` (engine) + `cargo test` (inert
default stays green) + `swift test` (envelope decoder).

**Caveats:** EdgeParse public API symbols are the integration seam — bind to the real names when the crate is on disk.
Pin a real SHA + confirm Apache-2.0 before `direct_import`.
