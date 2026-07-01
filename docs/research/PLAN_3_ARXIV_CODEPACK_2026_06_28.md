# Plan 3 — arXiv pull (shipped code, Pass 6)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §7`. Search arXiv + ingest a paper (PDF + abstract + metadata) into
> the vault as a note. MAS-safe (arxiv.org public API + the existing PDF→md pipeline).

## Shipped reuse seams
- File-first vault import: write `.md`, then `SDPage` with `filePath`+`subfolder`+`needsVaultSync=false`
  (`LiteParsePDFImportController.swift:36-60`). `SDPage.frontMatter` = `[String:String]` over `frontMatterData`
  (`SDPage.swift:55-61,144-170`). PDF→md FFI seam = `LiteParsePDFImporter.importToMarkdown(pdfPath:)` →
  `LiteParseImportResult` (`LiteParseImport.swift:42-75`). Networking = `URLSession.data/download`
  (`URLSessionTransportSupport.swift:61`). `VaultSyncService.vaultURL` (`:401`). Gate pattern
  `LiteParseImportGateStatus` (`:13-41`).

## Shipped files
- **`Epistemos/Arxiv/ArxivClient.swift` [DELIVERED]** — `search(query,maxResults)` against
  `https://export.arxiv.org/api/query?search_query=…&sortBy=submittedDate` → Atom XML parsed by an `XMLParser`
  delegate (`ArxivAtomParser`) into `ArxivPaper{id,title,authors,summary,published,pdfURL,categories}` (+ `shortID`).
  Search query length is bounded before request construction. Atom parsing disables external entity resolution and caps
  parsed papers, element text, and repeated authors/categories inside the 5 MiB response envelope.
  PDF links normalize to HTTPS only for canonical new-style or old-style `/pdf/<arxiv-id>` paths; credentials, queries,
  fragments, encoded path tricks, traversal suffixes, and arbitrary non-ID paths are rejected before download. Defaults
  plain text to `all:`; final Atom response URLs must stay on the requested HTTPS host/path/query after redirects;
  request/XML parser failures are reported as bounded domain/code diagnostics before status text.
  Networking only.
- **`Epistemos/Arxiv/ArxivIngestService.swift` [DELIVERED]** — `ingest(paper,vaultURL,modelContext,graphState,importer)`:
  (1) download the PDF into `<vault>/arXiv/` (URLSession); (2) convert via the SAME `LiteParsePDFImporter` FFI
  (off `@MainActor` via `Task.detached` — never block main); (3) create the paired PDF/Markdown files in a detached
  worker so conversion and file materialization run off `@MainActor`; (4) file-first `SDPage` with body = abstract intro
  + parsed full text, where abstract body text is bounded before the note write, plus bounded persisted metadata/frontmatter labels `source:arxiv, arxiv_id, authors, published, categories, source_pdf` (vault-relative,
  the §1 coexistence model), `url`. The paired PDF/Markdown writes use the shared reserved-file writer, including final
  symlink rejection after reservation. Downloaded temp PDFs are also opened with `O_NOFOLLOW`, checked with `fstat`,
  and rejected before import if the temp path is a symlink, is hardlinked, is not a regular file, exceeds the 128 MiB cap, or lacks
  `%PDF-` magic; extensionless `URLSession.download` temps are moved to a `.pdf` path and that final importer path is
  revalidated before `LiteParsePDFImporter` sees it. Successful ingest returns the vault-relative `source_pdf` path, and
  the sheet status reports that copied PDF
  evidence. Unexpected external download/import/write/model-save failures are reported as bounded domain/code diagnostics
  instead of raw localized filesystem strings. **Honest:** failed download / `.notWired` / `.failed`
  → no note + a bounded reason.
- **`Epistemos/Views/Arxiv/ArxivSearchView.swift` [DELIVERED]** — query field → results list → per-paper "Add to vault"
  (spinner/✓), reads `VaultSyncService`/`GraphState`/`modelContext` from env (like `LiteParsePDFImportButton`), and
  caps network-fed title/author/summary/metadata/status display strings before SwiftUI render. Search and ingest status
  failures route through the arXiv diagnostics helper instead of raw localized error descriptions; raw diagnostic and
  metadata-label strings are bounded, control/whitespace-normalized, and kept with ellipsis inside configured caps before display. The sheet's
  close/search/add controls render through shared `ToolbarCapsuleButton` chrome, the search field uses plain flat
  theme-token input chrome instead of a rounded bordered field, brand/status/result metadata reads `UIState` theme
  tokens, and result rows use spacing rather than hard `Divider()` rules. Sheet disappearance cancels live work and
  immediately clears busy indicators so a closing search sheet cannot leave stale search or per-paper ingest state.
- **`Epistemos/Arxiv/ArxivPullGateStatus.swift` [DELIVERED]** — flag `EPISTEMOS_ARXIV_PULL_V0`, default active,
  explicit `0/false/no/off` kill switch. Search+metadata+download are HTTPS-only; note creation still requires real
  markdown from the local PDF importer. If the parser bridge is absent in a Swift-only host or the parser rejects the
  PDF, ingest creates no note and reports the actual rejection.

## Wiring
A gated landing button (§8) presents `ArxivSearchView` as a sheet via `showingArxivSearch = true` in `LandingView`.
MAS-safe: networking + the existing PDF pipeline; no Python, no subprocess, no fabricated notes. Code is only the Atom
`XMLParser`, sheet UI, and body/frontmatter composition; everything else reuses verified seams.

## Verification
- `EpistemosTests/ArxivPlan3Tests.swift` covers search URL construction, Atom parsing, default-on kill switch behavior,
  draft frontmatter/body composition, successful ingest into an in-memory SwiftData vault, parser rejection with no note,
  bounded Atom parser shape, unsafe temp PDF envelope rejection, download rejection with no note, and redaction of
  unexpected external error descriptions before they reach UI-facing search or ingest status.
- `scripts/arxiv-ingest-live-smoke.swift` runs the live arXiv ingest path and checks that the imported outcome's
  vault-relative `source_pdf` matches the page frontmatter and copied PDF.
- `EpistemosTests/LandingFeatureButtonsPlan3Tests.swift` guards the landing button, arXiv sheet presentation, and
  `ArxivPullGateStatus` availability wiring.
