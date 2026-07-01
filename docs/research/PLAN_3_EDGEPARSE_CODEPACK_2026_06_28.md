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
  `{"ok":true,"markdown":...}` / `{"ok":false,"error":...}` while rejecting oversized engine envelopes/Markdown and
  capping engine error strings before untrusted parsing/trimming work. `LiveLiteParsePDFImporter` rejects explicit
  non-PDF extensions before FFI while still accepting extensionless PDF downloads by `%PDF-` magic, and mirrors the Rust
  input envelope by rejecting symlink/non-regular paths, empty files, and PDFs over 512 MiB before parser dispatch. The
  Swift magic read revalidates empty/oversized files after the final no-follow open. It calls
  the same symbol when `agent_coreFFI` is linked; Swift-only test hosts without that binding honestly fall back to
  `.notWired`. Swift-side Foundation/file failures are mapped to bounded domain/code diagnostics before reaching import
  status text, so raw localized filesystem descriptions are not displayed; raw messages are bounded before trimming and
  ellipsis stays inside the configured cap. The sidebar status alert caps each file line, caps the total status string,
  and reports an overflow marker instead of rendering unbounded bulk-import output.
- **Storage coexistence [DELIVERED]:** `LiteParsePDFImportController` runs conversion and file materialization off the
  main actor, writes the parsed `.md` into `<vault>/Imported PDFs/`, copies the original `.pdf` beside it with the same
  basename, and records `source_kind=pdf` plus `source_pdf=<vault-relative path>` in `SDPage.frontMatter`. If writing the
  note fails, the copied source PDF is removed too. Reserved PDF/Markdown destination writes reopen with `O_NOFOLLOW`
  and regular-file validation so a final symlink swap cannot redirect import output after reservation. Source PDF copy
  reopens through `openValidatedPDFForReading` with no-follow, regular-file, 512 MiB, and `%PDF-` magic checks on the
  copied file descriptor. Import basename normalization starts from a bounded prefix and duplicate filename reservation
  has a hard attempt cap. Successful imports return the copied vault-relative `source_pdf` path so sidebar and landing
  status lines can show the exact stored source-PDF evidence.
- **View-original contract [DELIVERED]:** `ViewOriginalPDFAffordance` shows the source PDF button only when
  `source_kind=="pdf"` and `LiteParseSourcePDFLink.resolve` resolves a file inside the current vault. Frontmatter
  `source_pdf` is length-bounded before trimming, and absolute paths, `..`, `.`, empty path components, missing files,
  symlink escapes, and traversal attempts are rejected. The source-PDF sheet revalidates `%PDF-` magic through the same
  no-follow signature helper before PDFKit opens the URL, then caps outline traversal depth/node/item count, outline
  labels, file names, annotation page/item/title traversal, and find-query/result state so malformed PDFs cannot force
  unbounded UI work; filename ellipsis stays inside the configured cap, and original-PDF help text is capped too. The sheet chrome uses a flat theme-token Find input, theme-derived separators/text colors, `ToolbarCapsuleButton`, and
  `NativeCardButtonStyle` instead of generic dividers, rounded bordered fields, or plain buttons. Plan 2 still owns any
  full PDF viewer; Plan 3 only owns the parse engine and storage/link contract.
- **DONE:** Settings keys `parsePDFOnImport`/`defaultOpenForImportedPDF` and frontmatter `source_pdf`/`source_kind`
  are present in shipped code. `source_pdf` resolution is vault-bound and traversal-safe through
  `LiteParseSourcePDFLink`; the import and view-original triggers render through `ToolbarCapsuleButton` native chrome.

## Rust path
`agent_core/src/liteparse.rs` is the single parser seam:
- Inert/no-engine builds: PDF inputs return `EngineNotWired`; non-PDF inputs return `UnsupportedFormat`.
- Preflight uses `symlink_metadata` and rejects symlink/non-regular paths, empty files, bodies over the 512 MiB cap,
  and files without `%PDF-` magic before EdgeParse, unpdf, or the legacy liteparse lane receives the path. The Rust
  header read reopens with `O_NOFOLLOW|O_CLOEXEC` and revalidates the opened file handle before sniffing `%PDF-`, so a
  final-symlink swap cannot redirect the parser preflight after the metadata check.
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
- Swift focused guards: `EpistemosTests/LiteParseImportTests.swift` verifies envelope decoding, non-PDF and unsafe local
  PDF rejection before FFI, off-main import materialization, paired Markdown/PDF basenames, source-PDF vault confinement,
  source-copy revalidation, and this shipped-codepack status.
- Historical caveat: Swift unit-test hosts without `agent_coreFFI` still verify the honest fallback by expecting
  `.notWired` for a PDF. That is a test-linking condition, not the default MAS Rust engine state.
