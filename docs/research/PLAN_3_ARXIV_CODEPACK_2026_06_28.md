# Plan 3 — arXiv pull (clone-ready code, Pass 6)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §7`. Search arXiv + ingest a paper (PDF + abstract + metadata) into
> the vault as a note. MAS-safe (arxiv.org public API + the existing PDF→md pipeline). `[VERIFIED-CODE]`/`[INFERRED]`.

## Verified reuse seams
- File-first vault import: write `.md`, then `SDPage` with `filePath`+`subfolder`+`needsVaultSync=false`
  (`LiteParsePDFImportController.swift:36-60`). `SDPage.frontMatter` = `[String:String]` over `frontMatterData`
  (`SDPage.swift:55-61,144-170`). PDF→md FFI seam = `LiteParsePDFImporter.importToMarkdown(pdfPath:)` →
  `LiteParseImportResult` (`LiteParseImport.swift:42-75`). Networking = `URLSession.data/download`
  (`URLSessionTransportSupport.swift:61`). `VaultSyncService.vaultURL` (`:401`). Gate pattern
  `LiteParseImportGateStatus` (`:13-41`).

## New files
- **`Epistemos/Arxiv/ArxivClient.swift`** — `search(query,maxResults)` against
  `https://export.arxiv.org/api/query?search_query=…&sortBy=submittedDate` → Atom XML parsed by an `XMLParser`
  delegate (`ArxivAtomParser`) into `ArxivPaper{id,title,authors,summary,published,pdfURL,categories}` (+ `shortID`).
  Defaults plain text to `all:`; honest errors. Networking only.
- **`Epistemos/Arxiv/ArxivIngestService.swift`** — `ingest(paper,vaultURL,modelContext,graphState,importer)`:
  (1) download the PDF into `<vault>/arXiv/` (URLSession); (2) convert via the SAME `LiteParsePDFImporter` FFI
  (off `@MainActor` via `Task.detached` — never block main); (3) file-first `SDPage` with body = abstract intro +
  parsed full text, frontmatter `source:arxiv, arxiv_id, authors, published, categories, source_pdf` (vault-relative,
  the §1 coexistence model), `url`. **Honest:** failed download / `.notWired` / `.failed` → no note + the real reason.
- **`Epistemos/Views/Arxiv/ArxivSearchView.swift`** — query field → results list → per-paper "Add to vault"
  (spinner/✓), reads `VaultSyncService`/`GraphState`/`modelContext` from env (like `LiteParsePDFImportButton`).
- **`Epistemos/Arxiv/ArxivPullGateStatus.swift`** — copy of `LiteParseImportGateStatus`, flag `EPISTEMOS_ARXIV_PULL_V0`.
  Note: search+metadata+abstract+download work immediately; only the parsed full-text degrades to `.notWired` until the
  PDF engine (EdgeParse §1) lands.

## Wiring
A gated landing button (§8) presents `ArxivSearchView` as a sheet. MAS-safe: networking + the existing PDF pipeline;
no Python, no subprocess, no fabricated notes. New code is only the Atom `XMLParser` + body composition; everything
else reuses verified seams.
