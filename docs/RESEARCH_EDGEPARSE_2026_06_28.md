# EdgeParse + unpdf ProvenanceGate — Plan 3 PDF Parser

Status: `direct_import` for the MAS PDF-to-Markdown parser lane.

## Pinned Sources

- EdgeParse: `https://github.com/raphaelmansuy/edgeparse`
- EdgeParse SHA: `98e2fa0132629078d07c19bfc8a8776fee85d8dd`
- EdgeParse license: Apache-2.0
- unpdf: `https://github.com/iyulab/unpdf`
- unpdf SHA: `d41b4dff1a29411bd62d405b322c4589a025f1fb`
- unpdf license: MIT

## Vendored Scope

- `agent_core/vendor/edgeparse/crates/edgeparse-core`
- `agent_core/vendor/edgeparse/crates/pdf-cos`
- `agent_core/vendor/unpdf`

Binding crates and CLI/UI packages are intentionally excluded from the active workspace:
EdgeParse Python, Node, WASM, and CLI crates are not linked into the app. unpdf CLI and
WASM crates are not linked into the app.

## MAS Posture

The app path is local and in-process. EdgeParse is the primary parser and unpdf is the
fallback parser. No Python, Node, Chromium, shell, or helper process is invoked by the
Epistemos FFI route.

Upstream EdgeParse includes optional external helpers for Poppler/Tesseract/RapidOCR.
For Epistemos, the Poppler markdown helper is patched inert and raster OCR is feature
gated behind `external-ocr`, which is not enabled by `agent_core`. Scanned/OCR PDFs belong
to the Apple Vision lane, not the EdgeParse vendor path.

## FFI Contract

The exported Swift-facing function remains `liteparse_pdf_to_markdown` so the existing
LiteParse import UI can stay wired. The implementation now returns the same JSON envelope
using EdgeParse primary extraction and unpdf fallback:

- success: `{"ok":true,"markdown":"..."}`
- failure: `{"ok":false,"error":"..."}`

Non-PDF inputs are rejected before parsing. The function never fabricates markdown.
