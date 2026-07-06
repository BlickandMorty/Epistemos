# LUMENLENS spine manifest (V2, 2026-07-06) — authority map

One spine per plan; this documents what superseded what across the two waves, so no agent builds
from a stale file. Every V2 file carries a BINDING "AUDIT AMENDMENT" header — read it first.

## Authoritative files (build from these)
| Concern | File | Provenance |
|---|---|---|
| Fork D load-vs-edit | `document-load-state.ts` | V2 wave + audit header (extends the LIVE 14-line module) |
| Bridge schemas | `inbound.ts` / `outbound.ts` | V2 wave |
| Fork A adapter | `SuggestionAdapter.ts` + `marks.ts` | V2 wave + dep-reality header |
| Fork B tiers | `tiers.ts` | V2 wave |
| Fork B writeback | `minimal-diff-writeback.ts` | V2 wave (serializer/ version) |
| Fork C session | `NoteSessionStateMachine.swift` | V2 wave + ported KEELSTONE ActiveEditorBridge seam header |
| Rust suggestion schema | `suggestion_schema.rs` | V2 wave + ledger-idiom header |
| GRDB durable spans | `EditorProvenanceStore.swift` | **V1 authored — kept** (no V2 equivalent) |
| Swift round-trip harness | `RoundTripTierTests.swift` | **V1 authored — kept** (no V2 equivalent) |
| Chrome dock slot | `EpdocEditorChromeView.DELTA.swift` | V2 wave — DELTA over ~1000-line live file |
| Surface writeback | `MarkdownDocumentSurface.DELTA.swift` | V2 wave — DELTA over live guard-pinned file |
| Native bridge | `EpdocEditorBridge.DELTA.swift` | V2 wave — DELTA; live scheme is `epistemos-doc://` |
| Gating reference | `Package.swift.NOT-APPLICABLE` | V2 wave — N/A (flags landed via xcodegen, 8a1ca87d1) |
| CI reference | `ci-matrix.REFERENCE.yml` | V2 wave — re-mapped onto the real .github/workflows CI |
| Researcher's README | `SPINE_README.md` | V2 wave verbatim |

## Superseded + removed (V1 authored files replaced by the V2 wave)
- `LensSessionCoordinator.swift` → `NoteSessionStateMachine.swift` (KEELSTONE seam header ported)
- `load-epoch.ts` → `document-load-state.ts`
- v1 `minimal-diff-writeback.ts` → V2 serializer version
- `suggestion-adapter.ts` → `SuggestionAdapter.ts`

## Moved
- `CompanionEditGate.swift` → `../kindred/spine/` (KINDRED's gating file; status header updated —
  flags already landed, the KINDRED×surface guard pair remains to land in K0)

## Historical (kept for the record, superseded where conflicting)
- `LUMENLENS_REVIEW_2026_07_06.md` (V1 review) + `INTEGRATION_SPINE_LUMENLENS_…md` (wave-1 doc):
  superseded by `LUMENLENS_REVIEW_V2_2026_07_06.md` + the V2 plan/prompt where they conflict.
