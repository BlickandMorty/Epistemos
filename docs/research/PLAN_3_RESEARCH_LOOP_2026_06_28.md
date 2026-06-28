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
- [x] **Pass 2 DONE** (2026-06-28): ColBERT + Obscura + ledger re-scan.
  - **ColBERT → KEEP search-only, CUT tool-selector.** Use (b) tool-select = app-side-agent plumbing (no live Swift
    wiring today; dies with Goose consolidation) → cut. Use (a) vault rerank = pure search infra on the *data* side of
    the MCP boundary → keep, deferred, flag-gated; sharpens Goose's MCP vault queries without touching its AI. Resolves
    the "don't muddy app-side AI" concern. → folded into §3.
  - **Obscura → clarified + tiered.** WKWebView IS Safari engine → a browser tab is LIGHT + behaves like a normal
    browser (T1, MAS-safe); only the agentic automation+stealth is HEAVY (T3, Pro). Recommend START at T1 (visible
    usable browser fast). Honest limits: no Safari extensions, some DRM video, isolated cookies. → folded into §2.
  - **Ledger re-scan** found owner-wanted skipped items → added §7 (arXiv pull, meeting/STT note, Eidos→chat) +
    an owner-decision queue (HF/BYOM marketplace, model stack, vision-lane, DeerFlow — hinge on Goose-only-AI).
- [ ] **Pass 3+** (queue): (5) deepen Provenance moat (Fix A/B + hover card) + Extensibility/MCP into clone-ready code
  with real snippets. (6) deepen Apple-native (rest of top-6: QuickLook/VisionKit/thumbnails wiring). (7) deepen the
  PDF parser clone (EdgeParse vendoring + FFI + unpdf fallback, concrete). (8) Provenance fake-chip fix → real code.
  (9) harden + contradiction sweep across all 3 plans (no duplication/clash). Each: clone targets + real code.
