# Plan-3 Capabilities — Research Loop Tracker (2026-06-28)

> Running log for the `/loop 3m` deepening of `PLAN_3_CAPABILITIES_2026_06_28.md` (cron `a7c94e69`).
> GOAL: research each kept capability deeply enough to FULLY CLONE/vendor every kept repo with real code;
> harden; remove contradictions; NO clash/duplication with Plan 1 (Goose) or Plan 2 (editor canonical).
> Owner-CONFIRMED: provenance moat · extensibility/MCP/vault-as-MCP · fast PDF→md · Apple-native maximization.
> Owner-UNSURE (research the concern honestly, don't assume): Obscura · ColBERT.

## Pass checklist
- [x] **Pass 1 DONE** (2026-06-28): PDF cluster ground-truth + best repos + viewer/md coexistence + Apple-native scan.
  - **1a TRUTH (owner was right):** the app CANNOT parse a PDF→md today (vendored liteparse but `liteparse-pdf`
    feature OFF in `default`, no `libpdfium.dylib` bundled, UI flag `EPISTEMOS_LITEPARSE_PDF_V0` OFF) AND there is
    **NO PDF viewer** (zero `PDFView`/QuickLook; PDFKit used only as a headless extractor in `VaultParser.swift`).
    Everything honest-inert (never fakes a note).
  - **1b BEST REPOS:** EdgeParse (primary, pure-Rust, #1 accuracy+speed, Apache-2.0, MAS-safe) + unpdf (CJK/RTL/multi-
    lingual, zero-C-dep, MIT, MAS-safe) + Apple Vision/PDFKit (scanned-OCR lane, native). liteparse = Pro-first
    (PDFium+Tesseract C++ blobs, notarization risk). Drop pdf_oxide for md (thin md layer).
  - **1c COEXISTENCE + APPLE-NATIVE:** original `.pdf` + parsed `.md` sibling, linked via `SDPage.frontMatterData`
    `source_pdf` (no migration); pdf→md ON by default; parsed note opens + "View original PDF" affordance; 2 settings.
    Plan-2 owns the PDFView VIEWER, Plan-3 owns the PARSE + the link/storage contract. Apple-native top-6 listed.
  - → folded into `PLAN_3_CAPABILITIES §1` (rewritten) + new `§6 Apple-native maximization`.
- [ ] **Pass 2+** (queue): (2) ColBERT role given Goose-only AI — does it earn a place via vault SEARCH (independent
  of chat AI) without muddying app-side AI? keep/cut honest recommendation. (3) Obscura clarify — why "heavy", how a
  WebView browser behaves, usable-as-a-regular-browser? (4) re-scan `OWNER_REQUESTS_LEDGER_2026_06_18.md` for owner-
  wanted items SKIPPED in the curation → add good ones to Plan 3 with rationale. (5) deepen Provenance moat + MCP/
  extensibility into clone-ready code. (6) deepen Apple-native (the rest of the top-6). (7) harden + contradiction
  sweep across all 3 plans (no duplication/clash). Each: clone targets + real code snippets.
