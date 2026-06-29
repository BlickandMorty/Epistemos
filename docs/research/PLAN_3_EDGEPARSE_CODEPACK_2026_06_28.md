# Plan 3 — EdgeParse PDF→md import (shipped code, Pass 3)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §1`. EdgeParse now lives behind the existing
> `liteparse_pdf_to_markdown` FFI envelope, so the already-wired Swift import UI keeps the same call path.

## Shipped ground truth
- **Rust engine [DELIVERED]:** `agent_core/src/liteparse.rs` owns the preserved FFI symbol
  `liteparse_pdf_to_markdown`. Default/MAS builds compile `edgeparse-pdf` plus `parser-unpdf`; the older
  run-llama/liteparse PDFium path remains opt-in with `liteparse-pdf` for Pro/dev builds only.
- **Cargo features [DELIVERED]:** `agent_core/Cargo.toml` has `default = ["mas-build"]` and
  `mas-build = ["edgeparse-pdf", "parser-unpdf"]`. `edgeparse-core` is path-dep vendored at
  `agent_core/vendor/edgeparse/crates/edgeparse-core`; `unpdf` is path-dep vendored at `agent_core/vendor/unpdf`.
- **Provenance [DELIVERED]:** EdgeParse is recorded as Apache-2.0 from
  `raphaelmansuy/edgeparse@98e2fa0132629078d07c19bfc8a8776fee85d8dd`; unpdf is MIT from
  `iyulab/unpdf@d41b4dff1a29411bd62d405b322c4589a025f1fb`. The FFI status JSON reports both licenses/sources and
  the `pdf+markdown,no-subprocess` scope.
- **Swift import [DELIVERED]:** `LiteParseImportEnvelope.decode` still accepts
  `{"ok":true,"markdown":...}` / `{"ok":false,"error":...}`. `LiveLiteParsePDFImporter` rejects non-PDF paths before
  FFI and calls the same symbol when `agent_coreFFI` is linked; Swift-only test hosts without that binding honestly
  fall back to `.notWired`.
- **Storage coexistence [DELIVERED]:** `LiteParsePDFImportController` runs conversion and file materialization off the
  main actor, writes the parsed `.md` into `<vault>/Imported PDFs/`, copies the original `.pdf` beside it with the same
  basename, and records `source_kind=pdf` plus `source_pdf=<vault-relative path>` in `SDPage.frontMatter`. If writing the
  note fails, the copied source PDF is removed too. Reserved PDF/Markdown destination writes reopen with `O_NOFOLLOW`
  and regular-file validation so a final symlink swap cannot redirect import output after reservation.
- **View-original contract [DELIVERED]:** `ViewOriginalPDFAffordance` shows the source PDF button only when
  `source_kind=="pdf"` and `LiteParseSourcePDFLink.resolve` resolves a file inside the current vault. Absolute paths,
  `..`, missing files, and traversal attempts are rejected. Plan 2 still owns any full PDF viewer; Plan 3 only owns the
  parse engine and storage/link contract.

## Rust path
`agent_core/src/liteparse.rs` is the single parser seam:
- Inert/no-engine builds: PDF inputs return `EngineNotWired`; non-PDF inputs return `UnsupportedFormat`.
- MAS/default builds: EdgeParse converts to Markdown in-process. Before rendering, `doc.source_path = None` prevents
  EdgeParse's optional `pdftotext` helper path.
- Fallback: with `parser-unpdf`, empty or failed EdgeParse output falls back to `unpdf::Unpdf::new().lenient()...`.
- FFI: `liteparse_pdf_to_markdown(pdf_path)` always returns a JSON envelope; failures never fabricate markdown.
- Status: `liteparse_status_json()` reports `engine_wired`, the kill-switch flag name, license/source metadata, and
  the no-subprocess scope.

## Swift path
- `LiteParseImportGateStatus` treats `EPISTEMOS_LITEPARSE_PDF_V0=0` as an emergency kill switch; absent/positive env
  leaves the Plan 3 PDF import surface active by default.
- `LiteParsePDFImportButton`, Settings, and sidebar import flow reuse the same importer/controller seam.
- `parsePDFOnImport` defaults ON; `defaultOpenForImportedPDF` defaults to `parsedNote`.
- Non-PDF, engine-not-linked, or conversion-failed outcomes return `.rejected(...)` and create no note.

## Verification
- Rust: `cargo test -p agent_core` exercises the default EdgeParse/unpdf MAS feature set, including a real sample PDF
  fixture and the FFI envelope.
- Swift focused guards: `EpistemosTests/LiteParseImportTests.swift` verifies envelope decoding, non-PDF rejection before
  FFI, off-main import materialization, paired Markdown/PDF basenames, source-PDF vault confinement, and this
  shipped-codepack status.
- Historical caveat: Swift unit-test hosts without `agent_coreFFI` still verify the honest fallback by expecting
  `.notWired` for a PDF. That is a test-linking condition, not the default MAS Rust engine state.
