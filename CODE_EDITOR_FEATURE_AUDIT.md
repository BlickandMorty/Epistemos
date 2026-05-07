# Code Editor Feature Implementation Audit

Date: 2026-04-23
Scope: reconcile code-editor claims with live code per `docs/architecture/PLAN_V2.md` §23.1.

Status terms used in this audit:
- `verified`: live code exists and is wired in the current runtime path, with file:line evidence.
- `planned`: scaffolding or UI exists, but the feature is not active end-to-end; blocker is called out.
- `reverted`: the old claim is no longer true in the current architecture; the reason and replacement are called out.

## Runtime Truth

- Code-like notes route into `CodeEditorView`, while non-code notes route into `ProseEditorView`: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1033-1057`.
- The live editor surface is `SourceEditor`, not the older custom `NSTextView` + minimap stack: `Epistemos/Views/Notes/CodeEditorView.swift:1472-1480`.
- `CodeEditorView.swift` is currently 3,869 lines (`wc -l Epistemos/Views/Notes/CodeEditorView.swift` on 2026-04-23).

## Claim Audit

| Claimed feature | Status | Evidence / blocker |
| --- | --- | --- |
| Custom NSTextView stack with line gutter + minimap is the live editor architecture | `reverted` | The current runtime uses `SourceEditor` at `Epistemos/Views/Notes/CodeEditorView.swift:1472-1480`. The older custom stack is explicitly called out as removed in `Epistemos/Views/Notes/CodeEditorView.swift:2037-2043`. |
| VS Code-style indentation guides | `verified` | `EpistemosEditorCoordinator` installs `SegmentedIndentationGuideView` and refreshes it on scroll/cursor changes at `Epistemos/Views/Notes/CodeEditorView.swift:1843-1910`; the guide view lives at `Epistemos/Views/Notes/SegmentedIndentationGuideView.swift:30-58`. |
| Minimap | `reverted` | The minimap preference was removed in favor of the outline navigator comment at `Epistemos/Views/Notes/CodeEditorView.swift:1261-1263`, and the live editor configuration hardcodes `showMinimap: false` at `Epistemos/Views/Notes/CodeEditorView.swift:1755-1762`. |
| Outline navigator replacement for the minimap | `verified` | The outline navigator is parsed and updated at `Epistemos/Views/Notes/CodeEditorView.swift:1353-1362`, rendered at `Epistemos/Views/Notes/CodeEditorView.swift:1454-1465`, and exposed in the View menu at `Epistemos/Views/Notes/CodeEditorView.swift:1596-1602`. |
| Search / find bar | `planned` | The overlay and `SearchBar` UI are live at `Epistemos/Views/Notes/CodeEditorView.swift:1487-1500` and `Epistemos/Views/Notes/CodeEditorView.swift:3705-3779`, but actual search execution is still a stub at `Epistemos/Views/Notes/CodeEditorView.swift:1521-1544`. Blocker: the current `SourceEditor` path is not yet bridged to a real finder/search implementation. |
| Go to Line sheet | `verified` | The sheet is attached at `Epistemos/Views/Notes/CodeEditorView.swift:1439-1449`, the sheet UI/validation live at `Epistemos/Views/Notes/CodeEditorView.swift:3785-3840`, and navigation updates the cursor at `Epistemos/Views/Notes/CodeEditorView.swift:1391-1394`. |
| Semantic sidebar | `planned` | The sidebar view exists at `Epistemos/Views/Notes/CodeEditorView.swift:1503-1518`, but it is release-gated off by `CodeEditorReleasePolicy.semanticSidebarEnabled = false` at `Epistemos/Views/Notes/CodeEditorView.swift:320-323` and only conditionally mounted at `Epistemos/Views/Notes/CodeEditorView.swift:1373-1378`. |
| Old status bar layout (`Ln/Col`, line count, search, settings, view, language, encoding`) | `reverted` | The live chrome is `EditorBreadcrumbBar`, mounted at `Epistemos/Views/Notes/CodeEditorView.swift:1398-1449` and implemented in `Epistemos/Views/Notes/EditorBreadcrumbBar.swift:29-68`. The old status-bar layout does not exist in `HEAD`. |
| Search button in editor chrome | `verified` | Search toggle button is present in the breadcrumb overlay at `Epistemos/Views/Notes/CodeEditorView.swift:1412-1422`. |
| View options menu in editor chrome | `verified` | The View menu is mounted from the breadcrumb overlay at `Epistemos/Views/Notes/CodeEditorView.swift:1434-1435` and defined at `Epistemos/Views/Notes/CodeEditorView.swift:1596-1602`. |
| Settings menu in editor chrome | `verified` | The Settings menu is mounted from the breadcrumb overlay at `Epistemos/Views/Notes/CodeEditorView.swift:1434-1435` and defined at `Epistemos/Views/Notes/CodeEditorView.swift:1548-1592`. |
| `@AppStorage` word-wrap preference | `verified` | Stored at `Epistemos/Views/Notes/CodeEditorView.swift:1261`, exposed in the View menu at `Epistemos/Views/Notes/CodeEditorView.swift:1598-1600`, and wired into `SourceEditorConfiguration` at `Epistemos/Views/Notes/CodeEditorView.swift:1744-1751`. |
| `@AppStorage` show-invisibles preference | `verified` | Stored in `CodeEditorView`, exposed in the View menu, and now consumed by `SourceEditorConfiguration.Peripherals.invisibleCharactersConfiguration`, enabling spaces/tabs/line endings through CodeEditSourceEditor's native invisible-character renderer. |
| `@AppStorage` font-size preference | `verified` | Stored at `Epistemos/Views/Notes/CodeEditorView.swift:1267`, controlled via the Settings menu at `Epistemos/Views/Notes/CodeEditorView.swift:1567-1584`, and applied to the editor font at `Epistemos/Views/Notes/CodeEditorView.swift:1744-1749`. |
| `@AppStorage` use-spaces preference | `verified` | Stored and toggled in `CodeEditorView`, then consumed by `SourceEditorConfiguration.Behavior.indentOption` as `.spaces(count: tabWidth)` or `.tab`, so tab insertion now follows the preference. |
| `@AppStorage` tab-width preference | `verified` | Stored at `Epistemos/Views/Notes/CodeEditorView.swift:1269`, controlled in the Settings menu at `Epistemos/Views/Notes/CodeEditorView.swift:1556-1564`, and applied in `SourceEditorConfiguration` at `Epistemos/Views/Notes/CodeEditorView.swift:1749-1751`. |
| `@AppStorage` minimap preference | `reverted` | There is no live minimap preference anymore; the code keeps only the removal note at `Epistemos/Views/Notes/CodeEditorView.swift:1261-1263` and hardcodes `showMinimap: false` at `Epistemos/Views/Notes/CodeEditorView.swift:1759-1760`. |
| Line gutter / folding ribbon are active | `verified` | The live `SourceEditorConfiguration` now uses CodeEditSourceEditor's native left gutter via `showGutter: showLineGutter` and native fold arrows via `showFoldingRibbon: showLineGutter && showFoldingRibbon`. CodeEditSourceEditor's folding model is indentation-derived by default, so collapsible affordances follow nested code structure rather than acting as decorative arrows. The older Epistemos right-edge gutter remains dormant fallback scaffold and is not the visible user surface. |
| VS Code-style indentation guides | `verified` | `SegmentedIndentationGuideView` remains live and now aligns its vertical guide columns from the actual editor font, tab width, and text-container inset. The guide toggle is exposed as `Indent Guides` in the View menu. |

## Notes For Future Sessions

- Treat any doc or comment that still mentions the old minimap/gutter architecture as stale unless it cites the current `SourceEditor` path.
- The most important incomplete editor features are now explicit:
  - `planned`: real search execution for the existing search bar scaffold.
  - `planned`: semantic sidebar release enablement.
  - `verified`: native line numbers, native folding arrows, `showInvisibles`, and `useSpaces` are wired through CodeEditSourceEditor rather than bespoke overlays.
