# EPISTEMOS PLUGIN ECOSYSTEM PORTING SPECIFICATION

**Version:** 1.0.0  
**Date:** March 27, 2026  
**Author:** AI Architecture Team  
**Classification:** Internal — AI Agent Training Document  
**Target Audience:** AI coding agents, senior Swift/Rust engineers  
**Codebase Context:** Epistemos (242K LOC — Swift 6.0 + Rust + Python)  
**Repository:** [BlickandMorty/Epistemos](https://github.com/BlickandMorty/Epistemos)

---

## Table of Contents

1. [Part 1: Obsidian Plugin Ecosystem Deep Scan](#part-1-obsidian-plugin-ecosystem-deep-scan)
2. [Part 2: Notion Features to Port](#part-2-notion-features-to-port)
3. [Part 3: Logseq Features to Port](#part-3-logseq-features-to-port)
4. [Part 4: Terminal Integration Deep Spec](#part-4-terminal-integration-deep-spec)
5. [Part 5: Plugin SDK Architecture](#part-5-plugin-sdk-architecture)
6. [Part 6: Production Quality Infrastructure](#part-6-production-quality-infrastructure)
7. [Part 7: Priority Matrix](#part-7-priority-matrix)
8. [Appendices](#appendices)

---

## Executive Summary

This specification catalogs the complete plugin and feature ecosystems of Obsidian (2,500+ community plugins), Notion (enterprise collaboration platform), and Logseq (outliner-first PKM), then maps each feature to a native Epistemos implementation. Epistemos already has significant coverage of AI, search, graph, and editing features — this document identifies gaps, defines porting strategies, and sequences work across 8 implementation waves.

**Key Insight:** Epistemos's existing architecture (MLX local LLM, HNSW vector search, Metal graph rendering, SwiftData persistence, MCP agent system) already covers approximately 30% of the combined feature surface. The remaining 70% can be built as modular extensions to existing services, not greenfield rewrites.

**Existing Epistemos Capabilities Referenced Throughout:**
- `SDPage`, `SDBlock`, `SDTag` — SwiftData models for notes, blocks, tags
- `LLMService`, `ChatState` — Local inference via MLX (Qwen 2.5 3B)
- `HNSWIndex` — Semantic vector search in Rust
- `GraphEngine` — Metal GPU-accelerated knowledge graph with 7 node types, 12 relationship types
- `QueryAST` — Structured query engine over vault content
- `VaultSyncService` — Vault synchronization
- `SDPageVersion` — Note version tracking
- `FSRSEngine` (Rust) — Spaced repetition flashcard scheduling
- `Screen2AXFusion` — Desktop vision + accessibility fusion
- `Views/Shell/` — Planned terminal integration directory
- `AgentCoordinator`, `OmegaAgent` — 6 specialist MCP agents

---

# PART 1: OBSIDIAN PLUGIN ECOSYSTEM DEEP SCAN

The Obsidian community plugin directory contains over 2,500 plugins as of March 2026. The top 10 by all-time downloads are: Excalidraw (~5.6M), Templater, Dataview, Tasks, Advanced Tables, Calendar, Git, Kanban, Style Settings, and Iconize. This section catalogs 85+ plugins across 12 categories with native porting strategies.

---

## Category 1: Data & Query Engines

### 1.1 Dataview
- **Downloads:** ~4.5M (Top 3 overall)
- **GitHub:** [blacksmithgu/obsidian-dataview](https://github.com/blacksmithgu/obsidian-dataview)
- **What it does:** Provides an SQL-like query language (DQL) over markdown frontmatter and inline fields. Supports `TABLE`, `LIST`, `TASK`, and `CALENDAR` output formats. Also supports `dataviewjs` blocks for JavaScript-powered queries with full DOM access.
- **PORT:** Extend Epistemos `QueryAST` with a Dataview-compatible syntax layer. Create `DataviewService.swift` that:
  1. Parses DQL syntax (`FROM`, `WHERE`, `SORT`, `GROUP BY`, `FLATTEN`, `LIMIT`) into `QueryAST` nodes
  2. Resolves frontmatter fields via `SDPage.properties` dictionary
  3. Supports inline field extraction (`key:: value` patterns) via a `InlineFieldParser.swift` regex scanner
  4. Renders results as SwiftUI `Table`, `List`, or `LazyVGrid` views
  5. Implements live-updating queries via SwiftData `@Query` observation — when any `SDPage` property changes, dependent Dataview blocks re-evaluate
  6. Adds `DataviewCodeBlockRenderer` to the editor's code-block rendering pipeline
- **Builds on:** `QueryAST`, `SDPage.properties`, FTS5 index
- **Complexity:** 4/5 — Query language parsing is substantial
- **New files:** `Services/DataviewService.swift`, `Parsers/DQLParser.swift`, `Views/DataviewResultView.swift`, `Models/InlineFieldParser.swift`

### 1.2 DB Folder
- **Downloads:** ~350K
- **GitHub:** [RafaelGB/obsidian-db-folder](https://github.com/RafaelGB/obsidian-db-folder)
- **What it does:** Turns folders into database views with sortable, filterable columns derived from frontmatter. Notion-like table interface for managing notes.
- **PORT:** Create `DatabaseFolderView.swift` that reads all `SDPage` objects in a given `SDFolder`, extracts their properties, and renders them in a `Table` with editable cells. Each column corresponds to a frontmatter key. Editing a cell writes back to `SDPage.properties` via SwiftData. Support sort/filter/group operations via `NSSortDescriptor` and `NSPredicate` chains compiled from user selections.
- **Builds on:** `SDFolder`, `SDPage.properties`, SwiftData queries
- **Complexity:** 3/5
- **New files:** `Views/DatabaseFolderView.swift`, `ViewModels/DatabaseFolderViewModel.swift`

### 1.3 Metadata Menu
- **Downloads:** ~250K
- **GitHub:** [mdelobelle/metadatamenu](https://github.com/mdelobelle/metadatamenu)
- **What it does:** Custom metadata types, file classes (templates for property schemas), auto-suggest values, and metadata-driven navigation.
- **PORT:** Extend `SDPage.properties` with a schema system. Create `PropertySchemaManager.swift` that defines typed property schemas (text, number, date, select, multi-select, checkbox, relation) per "file class." When a user creates a note from a file class, the schema auto-populates property stubs. Add `PropertyEditor.swift` with type-appropriate SwiftUI editors: `DatePicker` for dates, `Picker` for selects, `Toggle` for checkboxes, `TextField` for text. Store schemas as `SDPropertySchema` SwiftData model.
- **Builds on:** `SDPage.properties`, SwiftData
- **Complexity:** 3/5
- **New files:** `Models/SDPropertySchema.swift`, `Services/PropertySchemaManager.swift`, `Views/PropertyEditor.swift`

### 1.4 Projects
- **Downloads:** ~150K
- **GitHub:** [marcusolsson/obsidian-projects](https://github.com/marcusolsson/obsidian-projects)
- **What it does:** Project management views (table, board, calendar, gallery) derived from note metadata. Drag-and-drop between columns.
- **PORT:** Create `ProjectView.swift` as a container that switches between `ProjectTableView`, `ProjectBoardView`, `ProjectCalendarView`, and `ProjectGalleryView` via a `ViewType` enum. Each view reads from the same `SDPage` query filtered by folder or tag. Board view uses SwiftUI `LazyHStack` with drag-and-drop (`onDrag`/`onDrop` modifiers) that updates a status property on drop. Calendar view integrates `FSCalendar` or a custom `CalendarGrid.swift`. Gallery view uses `LazyVGrid` with thumbnail previews.
- **Builds on:** `SDPage.properties`, SwiftUI, existing drag-and-drop infrastructure
- **Complexity:** 4/5
- **New files:** `Views/Project/ProjectView.swift`, `Views/Project/ProjectBoardView.swift`, `Views/Project/ProjectCalendarView.swift`, `Views/Project/ProjectGalleryView.swift`, `Views/Project/ProjectTableView.swift`

### 1.5 Charts
- **Downloads:** ~180K
- **GitHub:** [phibr0/obsidian-charts](https://github.com/phibr0/obsidian-charts)
- **What it does:** Renders Chart.js charts (bar, line, pie, radar, doughnut, polar) from YAML or Dataview data in fenced code blocks.
- **PORT:** Integrate Swift Charts framework directly. Create `ChartBlockRenderer.swift` that parses `chart` fenced code blocks containing YAML config, maps them to Swift Charts `Chart { }` declarative syntax. Support `BarMark`, `LineMark`, `AreaMark`, `PointMark`, `RectangleMark`, `SectorMark`. Add a `ChartConfigParser.swift` to translate the YAML schema (labels, datasets, colors) into `ChartDataModel` structs. Charts render natively with smooth animations and Dark Mode support.
- **Builds on:** Swift Charts framework, code block rendering pipeline
- **Complexity:** 2/5
- **New files:** `Views/ChartBlockRenderer.swift`, `Models/ChartConfigParser.swift`, `Models/ChartDataModel.swift`

### 1.6 Bases (Core Plugin, new in 2025)
- **Downloads:** Bundled with Obsidian (estimated millions of activations)
- **What it does:** Native database views in Obsidian — essentially Obsidian's answer to Dataview and Notion databases. Table views over frontmatter with filters, sorts, groups, and computed columns.
- **PORT:** This is the same target as DB Folder + Projects above. Epistemos's `DatabaseFolderView.swift` should aim to match Bases' feature set: inline cell editing, formula columns (simple expressions evaluated via a `FormulaEvaluator.swift`), multi-view support per database definition stored as `SDDatabaseView` SwiftData model.
- **Builds on:** `SDPage`, `SDFolder`, SwiftData
- **Complexity:** 4/5
- **New files:** `Models/SDDatabaseView.swift`, `Services/FormulaEvaluator.swift`

---

## Category 2: Editor & Writing

### 2.1 Templater
- **Downloads:** ~5M+ (Top 2 overall)
- **GitHub:** [SilentVoid13/Templater](https://github.com/SilentVoid13/Templater)
- **What it does:** Dynamic templates with variables (`tp.date.now`, `tp.file.title`), JavaScript execution, system commands, user-defined functions, cursor positioning, folder-specific templates, and template suggestions on file creation.
- **PORT:** Create `TemplateEngine.swift` with a Swift-native template syntax using `{{ep.date.now}}`, `{{ep.file.title}}`, `{{ep.selection}}`, `{{ep.clipboard}}`, `{{ep.prompt("Enter value")}}` patterns. Template resolution pipeline:
  1. `TemplateParser.swift` tokenizes template into literal + expression nodes
  2. `TemplateContext.swift` provides runtime values (current date, file metadata, user input)
  3. `TemplateResolver.swift` evaluates expressions, including simple Swift expressions via `NSExpression` or a lightweight interpreter
  4. For advanced templates, support embedded Python snippets evaluated via the existing Python bridge
  5. `TemplateTriggerService.swift` auto-applies templates based on folder rules stored in `SDTemplateRule`
- **Builds on:** Existing template infrastructure (if any), SDPage, Python bridge
- **Complexity:** 4/5
- **New files:** `Services/TemplateEngine.swift`, `Parsers/TemplateParser.swift`, `Models/TemplateContext.swift`, `Models/SDTemplateRule.swift`

### 2.2 QuickAdd
- **Downloads:** ~1.5M
- **GitHub:** [chhoumann/quickadd](https://github.com/chhoumann/quickadd)
- **What it does:** Macros (chained commands), template-based capture (quick note creation with prompts), multi-step workflows triggered from command palette.
- **PORT:** Create `MacroSystem.swift` with:
  1. `MacroAction` protocol defining `execute(context: MacroContext) async throws`
  2. Built-in actions: `CreateNoteAction`, `AppendToNoteAction`, `OpenNoteAction`, `RunTemplateAction`, `PromptUserAction`, `SetPropertyAction`
  3. `MacroRecorder.swift` that records user actions and serializes them as `SDMacro` SwiftData objects
  4. `MacroRunner.swift` that executes action chains sequentially
  5. Command palette integration via `CommandPaletteProvider` protocol
  6. Keyboard shortcut binding per macro
- **Builds on:** Command palette system, `TemplateEngine.swift`
- **Complexity:** 3/5
- **New files:** `Services/MacroSystem.swift`, `Models/SDMacro.swift`, `Protocols/MacroAction.swift`

### 2.3 Advanced Tables
- **Downloads:** ~3.5M+ (Top 5 overall)
- **GitHub:** [tgrosinger/advanced-tables-obsidian](https://github.com/tgrosinger/advanced-tables-obsidian)
- **What it does:** Markdown table editing with tab-to-navigate, auto-formatting, column alignment, sort by column, formula cells, CSV export.
- **PORT:** Build `TableEditorComponent.swift` as a TextKit 2 custom `NSTextContentManager` extension:
  1. Detect markdown table regions via pipe-character pattern matching
  2. Override tab key to move between cells
  3. Auto-pad cells for alignment on edit
  4. Add toolbar buttons for add row/column, delete row/column, sort column, align left/center/right
  5. Formula cells: prefix with `=` to evaluate expressions (SUM, AVG, MIN, MAX over column references like `@col1`)
  6. CSV export via `TableCSVExporter.swift`
- **Builds on:** TextKit 2 editor, markdown parser
- **Complexity:** 4/5
- **New files:** `Editor/TableEditorComponent.swift`, `Editor/TableCSVExporter.swift`, `Editor/TableFormulaEvaluator.swift`

### 2.4 Linter
- **Downloads:** ~1.5M
- **GitHub:** [platers/obsidian-linter](https://github.com/platers/obsidian-linter)
- **What it does:** Auto-format notes on save — fixes heading levels, trailing whitespace, YAML frontmatter formatting, empty lines, ordered list numbering, and dozens more configurable rules.
- **PORT:** Create `NoteLinter.swift` with a rule-based pipeline:
  1. `LintRule` protocol: `func lint(_ content: String) -> [LintFix]`
  2. Built-in rules: `YAMLFrontmatterRule`, `HeadingLevelRule`, `TrailingWhitespaceRule`, `EmptyLineRule`, `OrderedListRule`, `ConsistentBulletRule`, `LinkFormattingRule`
  3. `LintConfiguration.swift` with per-rule enable/disable and parameters, stored in `UserDefaults` or `SDSettings`
  4. Run on save via editor delegate hook, or on-demand from command palette
  5. Preview mode: show diffs before applying fixes
- **Builds on:** Editor save hooks, markdown parser
- **Complexity:** 2/5
- **New files:** `Services/NoteLinter.swift`, `Models/LintRule.swift`, `Models/LintConfiguration.swift`

### 2.5 Typewriter Mode
- **Downloads:** ~300K
- **What it does:** Keeps the active line vertically centered in the editor as you type. Dims non-active paragraphs.
- **PORT:** Add `TypewriterScrollMode` to the editor as a `NSTextView` scroll behavior modifier:
  1. On cursor position change, calculate offset to center the current line in the visible rect
  2. Animate scroll using `NSAnimationContext`
  3. Apply reduced opacity (0.3–0.5) to `NSTextLayoutFragment`s above and below the current paragraph via custom `NSTextLayoutManager` delegate
  4. Toggle via `EditorSettings.typewriterMode: Bool`
- **Builds on:** TextKit 2 editor
- **Complexity:** 1/5
- **New files:** `Editor/TypewriterScrollMode.swift`

### 2.6 Writing Goals
- **Downloads:** ~80K
- **What it does:** Per-note and daily word count goals with progress bar.
- **PORT:** `WritingGoalsService.swift`:
  1. Track word count per `SDPage` (already available from content length)
  2. `SDWritingGoal` model: `targetWords: Int`, `deadline: Date?`, `scope: .note | .daily | .session`
  3. `WritingGoalBadge.swift` overlay in editor showing progress ring
  4. Daily aggregation: sum words written across all modified pages today
- **Builds on:** `SDPage`, editor word count
- **Complexity:** 1/5
- **New files:** `Services/WritingGoalsService.swift`, `Models/SDWritingGoal.swift`, `Views/WritingGoalBadge.swift`

### 2.7 Focus Mode / Zen Mode
- **Downloads:** ~200K combined
- **What it does:** Hides sidebars, status bar, ribbons — full-screen distraction-free writing.
- **PORT:** `FocusModeModifier.swift` as a SwiftUI environment modifier:
  1. Toggle via keyboard shortcut (Cmd+Shift+F)
  2. Animate sidebar collapse, hide toolbar, expand editor to full window
  3. Optional: dim everything except current paragraph (combine with typewriter mode)
  4. Store preference in `EditorSettings.focusMode: Bool`
- **Builds on:** Window management, sidebar state
- **Complexity:** 1/5
- **New files:** `Modifiers/FocusModeModifier.swift`

### 2.8 Reading Time Estimation
- **Downloads:** ~100K
- **What it does:** Shows estimated reading time in status bar.
- **PORT:** `ReadingTimeCalculator.swift` — simple utility: `wordCount / wordsPerMinute` (default 238 WPM). Display in editor footer. One-liner calculation, but wrapped as a reusable service for use in templates and queries.
- **Complexity:** 1/5
- **New files:** `Utilities/ReadingTimeCalculator.swift`

### 2.9 Natural Language Dates
- **Downloads:** ~800K
- **GitHub:** [argenos/nldates-obsidian](https://github.com/argenos/nldates-obsidian)
- **What it does:** Parse natural language dates ("next Tuesday", "in 3 weeks") into date links.
- **PORT:** `NaturalDateParser.swift` using Apple's `NSDataDetector` with `.date` checking type, supplemented by a custom parser for relative expressions. Integrate into editor autocomplete: when user types `@` followed by date text, show parsed date in a popover for confirmation.
- **Builds on:** `NSDataDetector`, editor autocomplete
- **Complexity:** 2/5
- **New files:** `Parsers/NaturalDateParser.swift`

---

## Category 3: Task Management

### 3.1 Tasks
- **Downloads:** ~3.5M+ (Top 4 overall)
- **GitHub:** [obsidian-tasks-group/obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks)
- **What it does:** Full task management with due dates, scheduled dates, start dates, priority levels (highest/high/medium/low/lowest), recurrence rules, custom statuses (TODO/IN_PROGRESS/DONE/CANCELLED), global task queries with filters and sorting, task completion tracking.
- **PORT:** Create comprehensive `TaskManager.swift`:
  1. `SDTask` SwiftData model: `content: String`, `status: TaskStatus`, `priority: TaskPriority`, `dueDate: Date?`, `scheduledDate: Date?`, `startDate: Date?`, `completedDate: Date?`, `recurrenceRule: SDRecurrenceRule?`, `parentPage: SDPage`
  2. `TaskStatus` enum: `.todo`, `.inProgress`, `.done`, `.cancelled`, `.delegated`, `.deferred`
  3. `TaskPriority` enum: `.highest`, `.high`, `.medium`, `.low`, `.lowest`
  4. `SDRecurrenceRule` model: `.daily`, `.weekly(days: Set<Weekday>)`, `.monthly(day: Int)`, `.yearly`, `.custom(interval: Int, unit: CalendarComponent)`
  5. `TaskQueryEngine.swift` — filter tasks across vault: `due before today`, `priority is high`, `path includes projects/`, `status is not done`, with boolean combinators
  6. `TaskCheckboxRenderer.swift` — render task checkboxes inline in the editor with tap-to-complete
  7. On completion of recurring task: auto-create next instance based on recurrence rule
  8. `TaskAggregateView.swift` — unified view of all tasks across vault with filters/sorts
- **Builds on:** `SDPage`, `SDBlock`, SwiftData, editor rendering
- **Complexity:** 5/5
- **New files:** `Models/SDTask.swift`, `Models/SDRecurrenceRule.swift`, `Services/TaskManager.swift`, `Services/TaskQueryEngine.swift`, `Views/TaskAggregateView.swift`, `Editor/TaskCheckboxRenderer.swift`

### 3.2 Kanban
- **Downloads:** ~2.5M+ (Top 8 overall)
- **GitHub:** [mgmeyers/obsidian-kanban](https://github.com/mgmeyers/obsidian-kanban)
- **What it does:** Markdown-backed Kanban boards with columns, cards, drag-and-drop, due dates, tags, and links.
- **PORT:** `KanbanView.swift`:
  1. `SDKanbanBoard` model: `columns: [SDKanbanColumn]`, each containing ordered `SDKanbanCard` references
  2. SwiftUI `ScrollView(.horizontal)` with `LazyVStack` per column
  3. Drag-and-drop via `Transferable` protocol conformance on `SDKanbanCard`
  4. Cards backed by `SDPage` references — card content is the page's first paragraph
  5. Quick-add card: text field at bottom of each column creates a new `SDPage` with appropriate status property
  6. Archive column for completed cards
  7. Markdown serialization: board state stored as structured YAML in a `.kanban.md` file for interop
- **Builds on:** SwiftUI drag-and-drop, `SDPage`
- **Complexity:** 3/5
- **New files:** `Views/KanbanView.swift`, `Models/SDKanbanBoard.swift`, `Models/SDKanbanColumn.swift`

### 3.3 Day Planner
- **Downloads:** ~300K
- **GitHub:** [ivan-lednev/obsidian-day-planner](https://github.com/ivan-lednev/obsidian-day-planner)
- **What it does:** Time-blocked daily planning with a visual timeline. Parse `- HH:MM Task` format from daily notes into a calendar-like day view. Integrates with Tasks plugin and online calendars.
- **PORT:** `DayPlannerView.swift`:
  1. Parse time-stamped entries from daily note content using `TimeBlockParser.swift`
  2. Render vertical timeline (24h) with colored blocks per task, sized proportionally to duration
  3. Drag to reschedule (update the markdown time prefix)
  4. Integration with system Calendar via EventKit: overlay CalendarKit events as read-only blocks
  5. Click block to navigate to the source note/task
- **Builds on:** `PeriodicNotesService`, `SDTask`, EventKit
- **Complexity:** 3/5
- **New files:** `Views/DayPlannerView.swift`, `Parsers/TimeBlockParser.swift`

### 3.4 Periodic Notes
- **Downloads:** ~1.5M
- **GitHub:** [liamcain/obsidian-periodic-notes](https://github.com/liamcain/obsidian-periodic-notes)
- **What it does:** Automated creation of daily, weekly, monthly, quarterly, and yearly notes from templates with date-based folder organization.
- **PORT:** `PeriodicNotesService.swift`:
  1. `PeriodicNoteConfig` per period: template `SDPage` reference, folder path format (e.g., `Daily/YYYY/MM/`), file name format (e.g., `YYYY-MM-DD`)
  2. `createPeriodicNote(for period: Period, date: Date)` — resolve template, substitute date variables, create `SDPage` in correct folder
  3. Auto-create on app launch (today's daily note if not exists)
  4. Navigation helpers: "Previous/Next" buttons for each period type
  5. Siri Shortcuts integration: "Create today's note" voice command
- **Builds on:** `TemplateEngine.swift`, `SDPage`, `SDFolder`, Siri/Shortcuts
- **Complexity:** 2/5
- **New files:** `Services/PeriodicNotesService.swift`, `Models/PeriodicNoteConfig.swift`

### 3.5 Calendar (Sidebar)
- **Downloads:** ~2.5M (Top 6 overall)
- **GitHub:** [liamcain/obsidian-calendar-plugin](https://github.com/liamcain/obsidian-calendar-plugin)
- **What it does:** Calendar widget in sidebar showing dots on days with daily notes. Click day to navigate to/create daily note.
- **PORT:** `CalendarSidebarView.swift`:
  1. Month grid using SwiftUI `LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7))`
  2. Query `SDPage` by daily note naming convention to detect which days have notes
  3. Dot indicators with intensity based on word count
  4. Tap to navigate; long-press to create from template
  5. Week number display, week start day preference
- **Builds on:** `PeriodicNotesService`, `SDPage`
- **Complexity:** 2/5
- **New files:** `Views/CalendarSidebarView.swift`

---

## Category 4: Visualization & Creative

### 4.1 Excalidraw
- **Downloads:** ~5.6M (Top 1 overall by downloads)
- **GitHub:** [zsviczian/obsidian-excalidraw-plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin)
- **What it does:** Full whiteboard/drawing environment embedded in notes. Hand-drawn style diagrams, mind maps, flowcharts, wireframes. OCR text recognition, LaTeX equations, embedded images, links to notes, PNG/SVG export. Arguably the single most popular Obsidian plugin.
- **PORT:** Create `CanvasView.swift` — this is a major feature, potentially the largest single port:
  1. **Rendering engine:** Metal-based 2D canvas with infinite pan/zoom. Use existing Metal infrastructure from `GraphEngine` for GPU rendering. Alternatively, use PencilKit for Apple Pencil support on iPad/macOS, though it has limited shape support.
  2. **Shape primitives:** Rectangle, ellipse, diamond, line, arrow, freehand path, text box. Each as a `CanvasElement` protocol with `render(in context: MTLRenderCommandEncoder)` and `hitTest(point: CGPoint) -> Bool`.
  3. **Hand-drawn style:** Apply Rough.js-like noise to paths using `BezierPathStylizer.swift` with configurable roughness, bowing, seed.
  4. **Text in shapes:** `NSTextView` overlays positioned via Metal coordinate transforms.
  5. **Note embedding:** Drag `SDPage` references onto canvas, rendering as linked cards that open the note on double-click.
  6. **Export:** Rasterize to PNG via `MTLTexture` readback, or generate SVG via `SVGExporter.swift`.
  7. **File format:** Store as `.excalidraw.json` or native `.epistemos-canvas` format with migration support.
  8. **OCR:** Integrate Vision framework `VNRecognizeTextRequest` for handwriting recognition.
- **Builds on:** Metal rendering infrastructure from `GraphEngine`, Vision framework
- **Complexity:** 5/5 (major feature)
- **New files:** `Views/Canvas/CanvasView.swift`, `Views/Canvas/CanvasElement.swift`, `Views/Canvas/CanvasRenderer.swift`, `Views/Canvas/BezierPathStylizer.swift`, `Views/Canvas/SVGExporter.swift`, `Models/SDCanvas.swift`

### 4.2 Mind Map
- **Downloads:** ~250K
- **GitHub:** [lynchjames/obsidian-mind-map](https://github.com/lynchjames/obsidian-mind-map)
- **What it does:** Converts markdown outlines (heading hierarchy) into visual mind maps.
- **PORT:** `MindMapView.swift`:
  1. Parse heading hierarchy from `SDPage` content into tree structure
  2. Apply radial tree layout algorithm (or force-directed for organic feel) — reuse layout algorithms from `GraphEngine`
  3. Render nodes as rounded rectangles with heading text, edges as curved Bezier paths
  4. Interactive: collapse/expand branches, click node to navigate to heading in editor
  5. **Key advantage:** Can leverage the existing Metal graph renderer by creating a temporary graph subview
- **Builds on:** `GraphEngine` layout algorithms, Metal rendering
- **Complexity:** 2/5
- **New files:** `Views/MindMapView.swift`, `Layout/TreeLayoutAlgorithm.swift`

### 4.3 Mermaid Diagrams
- **Downloads:** Built into Obsidian core; also standalone plugins ~150K
- **What it does:** Renders Mermaid diagram syntax (flowcharts, sequence diagrams, Gantt charts, class diagrams, ER diagrams, state diagrams) in fenced code blocks.
- **PORT:** `MermaidRenderer.swift`:
  1. **Option A (Recommended):** Embed a lightweight WebView (`WKWebView`) that loads the Mermaid.js library to render SVG, then snapshot the SVG as an image for native display. This is the fastest path to full Mermaid compatibility.
  2. **Option B (Native):** Build a native Mermaid parser + renderer in Swift. Parse the Mermaid DSL into a `DiagramModel`, then render using Core Graphics or Metal. Start with flowcharts and sequence diagrams, add others incrementally.
  3. Register as a code block renderer for ` ```mermaid ` blocks
- **Builds on:** Code block rendering pipeline, WKWebView or Core Graphics
- **Complexity:** 3/5 (Option A) or 5/5 (Option B)
- **New files:** `Renderers/MermaidRenderer.swift`, `Renderers/MermaidParser.swift` (if Option B)

### 4.4 Canvas (Obsidian Core Plugin)
- **Downloads:** Bundled (S-tier core plugin)
- **What it does:** Spatial note arrangement — infinite canvas where notes, images, and text cards are placed freely with connections between them. Different from Excalidraw: focuses on note organization rather than drawing.
- **PORT:** `SpatialCanvasView.swift`:
  1. Infinite scrollable canvas with zoom (NSScrollView with custom magnification)
  2. Cards: `SDPage` references rendered as preview cards, text-only cards, image cards, web embeds
  3. Connections: directional arrows between cards with optional labels
  4. Group selection, multi-select, alignment tools
  5. Canvas stored as `SDSpatialCanvas` with `SDCanvasNode` positions and `SDCanvasEdge` connections
  6. **Distinction from Excalidraw port:** This is for spatial note arrangement (structured), Excalidraw port is for freehand drawing (creative)
- **Builds on:** NSScrollView, `SDPage`, Metal for rendering large canvases
- **Complexity:** 4/5
- **New files:** `Views/SpatialCanvasView.swift`, `Models/SDSpatialCanvas.swift`, `Models/SDCanvasNode.swift`

---

## Category 5: AI & Intelligence

### 5.1 Copilot
- **Downloads:** ~1.5M (Top 10 last 30 days)
- **GitHub:** [logancyang/obsidian-copilot](https://github.com/logancyang/obsidian-copilot)
- **What it does:** AI chat sidebar, vault Q&A via semantic search, inline text editing (summarize, expand, rewrite), custom prompts, PDF/image chat, web search.
- **PORT:** **Already largely implemented.** Epistemos has `ChatState` + `LLMService` for AI chat, `HNSWIndex` for semantic search, and `OmegaAgent` for task execution. Enhancements:
  1. Add `InlineChatPopover.swift` — select text, right-click → AI actions (summarize, expand, simplify, translate)
  2. Add `VaultQAMode` to `ChatState` that automatically retrieves context from HNSW before each query
  3. Add PDF context extraction using PDFKit's `PDFPage.string`
- **Builds on:** `ChatState`, `LLMService`, `HNSWIndex`
- **Complexity:** 2/5 (incremental on existing)
- **New files:** `Views/InlineChatPopover.swift`

### 5.2 Smart Connections
- **Downloads:** ~1M
- **GitHub:** [brianpetro/obsidian-smart-connections](https://github.com/brianpetro/obsidian-smart-connections)
- **What it does:** Shows semantically similar notes in a sidebar panel. Uses local embeddings (no cloud). Smart chat that references vault content.
- **PORT:** **Already implemented.** Epistemos's `HNSWIndex` with local embeddings via MLX is exactly this. Enhancement: create `SmartConnectionsSidebar.swift` that shows top-10 semantically similar notes to the currently open note, updating on note switch. This is a simple HNSW query with the current note's embedding as the query vector.
- **Builds on:** `HNSWIndex`, embeddings, `SDPage`
- **Complexity:** 1/5
- **New files:** `Views/SmartConnectionsSidebar.swift`

### 5.3 Text Generator
- **Downloads:** ~400K
- **What it does:** Inline GPT completions — place cursor and generate text continuations.
- **PORT:** `InlineCompletionService.swift`:
  1. Trigger via keyboard shortcut (e.g., Cmd+Shift+G) or tab completion
  2. Send preceding context (last 500 tokens) to `LLMService`
  3. Stream response tokens into editor at cursor position with ghost text preview
  4. Accept/reject with Tab/Escape
  5. Configurable: system prompt, temperature, max tokens
- **Builds on:** `LLMService`, TextKit 2 editor
- **Complexity:** 2/5
- **New files:** `Services/InlineCompletionService.swift`, `Editor/GhostTextRenderer.swift`

### 5.4 AI-Enhanced Flashcards (Anki Sync)
- **Downloads:** ~200K combined across plugins
- **What it does:** Generate Anki-compatible flashcards from notes using AI, then sync to Anki.
- **PORT:** Extend existing `FSRSEngine` (Rust):
  1. `AICardGenerator.swift` — send note content to LLM with prompt: "Generate Q&A flashcard pairs from this content"
  2. Parse LLM response into `SDFlashcard` models (already exist for FSRS)
  3. Cloze deletion generation: identify key terms via NER and create cloze cards
  4. No Anki sync needed — Epistemos has native FSRS; but add `AnkiExporter.swift` for users who want it (export as `.apkg`)
- **Builds on:** `FSRSEngine` (Rust), `LLMService`
- **Complexity:** 2/5
- **New files:** `Services/AICardGenerator.swift`, `Export/AnkiExporter.swift`

### 5.5 Prompt Library (LLM Shortcut)
- **Downloads:** ~100K
- **What it does:** Save, organize, and quickly apply pre-written prompts.
- **PORT:** `PromptLibrary.swift`:
  1. `SDPrompt` SwiftData model: `name`, `content` (with `{{selection}}`, `{{note}}`, `{{clipboard}}` variables), `category`, `shortcut`
  2. UI: searchable list in command palette with fuzzy matching
  3. Apply prompt: substitute variables → send to LLMService → insert/replace result
  4. Ship with 20+ built-in prompts: summarize, expand, translate, extract tasks, generate tags, explain, simplify, formalize
- **Builds on:** `LLMService`, command palette
- **Complexity:** 1/5
- **New files:** `Services/PromptLibrary.swift`, `Models/SDPrompt.swift`

---

## Category 6: Version Control & Sync

### 6.1 Git
- **Downloads:** ~2.5M (Top 7 overall)
- **GitHub:** [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git)
- **What it does:** Git backup and sync — auto-commit on interval, push/pull, diff view, git history per file, branch management.
- **PORT:** `GitSyncService.swift`:
  1. Use `libgit2` via Swift wrapper ([SwiftGit2](https://github.com/SwiftGit2/SwiftGit2)) for native Git operations, or shell out to `git` CLI
  2. `GitAutoCommit` — background timer (configurable: every N minutes) that stages all changes, commits with auto-generated message, and pushes
  3. `GitDiffView.swift` — display file diffs using NSAttributedString with red/green highlighting
  4. `GitHistoryView.swift` — log viewer for a specific file showing commit messages, dates, authors
  5. `GitConflictResolver.swift` — three-way merge UI for conflicts
  6. Status bar indicator: uncommitted changes count, last push time
  7. Settings: remote URL, branch, SSH key path (Keychain), commit message format, auto-push toggle
- **Builds on:** `VaultSyncService`, shell access
- **Complexity:** 4/5
- **New files:** `Services/GitSyncService.swift`, `Views/GitDiffView.swift`, `Views/GitHistoryView.swift`

### 6.2 Version History
- **Downloads:** ~200K
- **What it does:** View previous versions of notes with diff comparison.
- **PORT:** **Already partially implemented** via `SDPageVersion`. Enhance:
  1. `VersionHistoryView.swift` — timeline of versions with diffs
  2. Snapshot on every save (debounced to 5-minute intervals)
  3. Diff algorithm: use `CollectionDifference` on line arrays for efficient line-level diffs
  4. Restore to previous version with confirmation dialog
- **Builds on:** `SDPageVersion`
- **Complexity:** 2/5
- **New files:** `Views/VersionHistoryView.swift`, `Services/VersionDiffService.swift`

---

## Category 7: Academic & Research

### 7.1 Zotero Integration / ZotLit
- **Downloads:** ~250K combined
- **GitHub:** [PKM-er/obsidian-zotlit](https://github.com/PKM-er/obsidian-zotlit)
- **What it does:** Pull citations from Zotero library, create literature notes with metadata, insert formatted citations, search Zotero database.
- **PORT:** `ZoteroService.swift`:
  1. Read Zotero's SQLite database directly (Better BibTeX JSON or CSL-JSON export)
  2. Or connect via Zotero's local web API (`http://localhost:23119/api/`)
  3. `ZoteroSearchView.swift` — search Zotero items with fuzzy matching, preview metadata
  4. On selection: create `SDPage` from citation template with title, authors, journal, year, abstract, DOI, PDF link
  5. Insert formatted citation in active note: `[@AuthorYear]` or full bibliography entry
  6. `BibTeXParser.swift` for `.bib` file import
- **Builds on:** SQLite (already using via FTS5), `TemplateEngine.swift`
- **Complexity:** 3/5
- **New files:** `Services/ZoteroService.swift`, `Views/ZoteroSearchView.swift`, `Parsers/BibTeXParser.swift`, `Parsers/CSLJSONParser.swift`

### 7.2 Citations
- **Downloads:** ~200K
- **GitHub:** [hans/obsidian-citation-plugin](https://github.com/hans/obsidian-citation-plugin)
- **What it does:** Read BibTeX/CSL-JSON bibliography files, search and insert citations.
- **PORT:** Folded into `ZoteroService.swift` above — the `BibTeXParser.swift` and `CSLJSONParser.swift` handle standalone bibliography files without Zotero.
- **Complexity:** Included in 7.1

### 7.3 PDF++
- **Downloads:** ~150K
- **GitHub:** [RyotaUshio/obsidian-pdf-plus](https://github.com/RyotaUshio/obsidian-pdf-plus)
- **What it does:** Advanced PDF annotation: highlight, underline, strikethrough, add notes to PDF pages, extract highlights as notes, backlinks from PDF annotations.
- **PORT:** `PDFAnnotationView.swift`:
  1. Use PDFKit's `PDFView` as the base viewer
  2. Add annotation toolbar: highlight (multiple colors), underline, strikethrough, text note, freehand drawing
  3. Annotations stored as `SDPDFAnnotation` linked to `SDPage` references
  4. `PDFHighlightExtractor.swift` — extract all highlighted text into a new `SDPage` as a literature note
  5. Backlinking: `SDPDFAnnotation` links bidirectionally to a `SDBlock` (the annotation creates a block reference in the graph)
  6. Page-level thumbnails in sidebar for navigation
- **Builds on:** PDFKit, `SDPage`, knowledge graph
- **Complexity:** 4/5
- **New files:** `Views/PDFAnnotationView.swift`, `Models/SDPDFAnnotation.swift`, `Services/PDFHighlightExtractor.swift`

### 7.4 Annotator
- **Downloads:** ~150K
- **What it does:** EPUB and web article annotation with highlight extraction.
- **PORT:** `AnnotationService.swift` — generalize `PDFAnnotationView` to support EPUB (via WKWebView with epub.js) and HTML articles (via Reader Mode + WKWebView). Highlights stored as `SDAnnotation` with source reference, position, color, and linked note.
- **Builds on:** WKWebView, PDFKit
- **Complexity:** 3/5
- **New files:** `Services/AnnotationService.swift`, `Models/SDAnnotation.swift`, `Views/EPUBReaderView.swift`

### 7.5 Spaced Repetition
- **Downloads:** ~300K
- **What it does:** FSRS-based flashcard review within Obsidian.
- **PORT:** **Already implemented.** Epistemos has a Rust `FSRSEngine`. Ensure review UI exists:
  1. `FlashcardReviewView.swift` — card front/back display with FSRS scheduling buttons (Again, Hard, Good, Easy)
  2. `FlashcardDeckView.swift` — deck management and statistics
  3. Integration with `AICardGenerator.swift` for auto-generation
- **Builds on:** `FSRSEngine` (Rust)
- **Complexity:** 1/5 (UI only)
- **New files:** `Views/FlashcardReviewView.swift`, `Views/FlashcardDeckView.swift`

### 7.6 Reading Highlights
- **Downloads:** ~100K
- **What it does:** Import highlights from Kindle, Readwise, Apple Books, and other reading apps.
- **PORT:** `HighlightImporter.swift`:
  1. Kindle: Parse `My Clippings.txt` file format
  2. Apple Books: Read from `~/Library/Containers/com.apple.iBooksX/Data/Documents/BKBookstore/` SQLite database
  3. Readwise: REST API integration (`readwise.io/api/v2/highlights`)
  4. Each highlight becomes a `SDBlock` in a reading notes `SDPage`, with source metadata
- **Builds on:** SQLite, REST networking, `SDPage`
- **Complexity:** 2/5
- **New files:** `Services/HighlightImporter.swift`, `Importers/KindleClippingsParser.swift`, `Importers/AppleBooksImporter.swift`

---

## Category 8: Navigation & Organization

### 8.1 Iconize
- **Downloads:** ~1.5M (Top 10 overall)
- **GitHub:** [FlorianWoworcel/obsidian-iconize](https://github.com/FlorianWoworcel/obsidian-iconize)
- **What it does:** Assign custom icons to files and folders. Supports emoji, Lucide icons, FontAwesome, and custom SVGs.
- **PORT:** `IconManager.swift`:
  1. `SDPage.icon: String?` property (emoji or icon identifier)
  2. `SDFolder.icon: String?` property
  3. `IconPickerView.swift` — searchable grid of SF Symbols (Apple's native icon set, 5000+ icons), emoji, and custom SVG support
  4. Icons rendered in file browser, tab bar, and graph nodes via `IconResolver.swift`
  5. **Native advantage:** SF Symbols are vector-based, scale perfectly, support Dynamic Type and accessibility
- **Builds on:** SF Symbols, `SDPage`, `SDFolder`, file browser
- **Complexity:** 2/5
- **New files:** `Services/IconManager.swift`, `Views/IconPickerView.swift`, `Utilities/IconResolver.swift`

### 8.2 Commander
- **Downloads:** ~500K
- **What it does:** Add custom commands to toolbar, title bar, status bar, right-click menu. Rearrange and hide default commands.
- **PORT:** `CommanderService.swift`:
  1. Configurable toolbar items: array of `ToolbarItem` definitions (icon, action, position)
  2. Right-click context menu customization per selection type (text, link, image, block)
  3. Drag-and-drop toolbar editor in settings
  4. Actions reference the command palette's registered commands
- **Builds on:** Command palette, NSToolbar
- **Complexity:** 2/5
- **New files:** `Services/CommanderService.swift`, `Views/ToolbarEditorView.swift`

### 8.3 Omnisearch
- **Downloads:** ~800K
- **What it does:** Unified search across file names, content, and metadata with fuzzy matching, OCR for images, PDF text search.
- **PORT:** **Already largely implemented.** Epistemos has FTS5, HNSW semantic search, and fuzzy matching. Enhancements:
  1. `UnifiedSearchView.swift` — single search bar that queries FTS5, HNSW, and file names simultaneously, ranking results by combined score
  2. Add OCR for image search via Vision framework `VNRecognizeTextRequest`, index results in FTS5
  3. Add PDF text extraction to FTS5 index
- **Builds on:** FTS5, HNSW, Vision framework
- **Complexity:** 2/5
- **New files:** `Views/UnifiedSearchView.swift`, `Services/OCRIndexer.swift`

### 8.4 Tag Wrangler
- **Downloads:** ~700K
- **What it does:** Rename, merge, and manage tags across vault. Batch tag operations.
- **PORT:** `TagManager.swift`:
  1. `TagRenameService` — rename a tag across all `SDPage` content and frontmatter (batch SwiftData update)
  2. `TagMergeService` — merge two tags into one (rename all instances of tag B to tag A)
  3. `TagHierarchyView.swift` — nested tag browser (`project/active`, `project/archived`)
  4. Tag usage statistics: count of pages per tag, shown in sidebar
  5. Orphan tag cleanup: find tags used zero times
- **Builds on:** `SDTag`, `SDPage`, SwiftData batch operations
- **Complexity:** 2/5
- **New files:** `Services/TagManager.swift`, `Views/TagHierarchyView.swift`

### 8.5 Hover Editor / Preview
- **Downloads:** ~500K
- **What it does:** Preview notes on hover over wikilinks without navigating away.
- **PORT:** `HoverPreviewModifier.swift`:
  1. On `onHover` of wikilink in editor, resolve target `SDPage`
  2. Show floating popover with first 300 characters of note content, rendered as markdown
  3. Popover pins on click, dismisses on mouse exit
  4. Support for transclusion preview: show the referenced block content
- **Builds on:** TextKit 2 link detection, `SDPage`, NSPopover
- **Complexity:** 2/5
- **New files:** `Modifiers/HoverPreviewModifier.swift`, `Views/NotePreviewPopover.swift`

### 8.6 Supercharged Links
- **Downloads:** ~350K
- **What it does:** Style wikilinks based on target note's frontmatter properties (e.g., color links to "status: complete" notes green).
- **PORT:** `StyledLinkRenderer.swift`:
  1. When rendering a wikilink, resolve target `SDPage` and read its properties
  2. Apply CSS-like style rules defined in settings: `{ property: "status", value: "complete", color: .green, bold: true }`
  3. Store rules as `SDLinkStyleRule` SwiftData model
  4. Update link styles reactively when target note properties change
- **Builds on:** TextKit 2 link rendering, `SDPage.properties`
- **Complexity:** 2/5
- **New files:** `Editor/StyledLinkRenderer.swift`, `Models/SDLinkStyleRule.swift`

### 8.7 Breadcrumbs
- **Downloads:** ~250K
- **What it does:** Hierarchical navigation breadcrumbs showing parent notes based on frontmatter relationships.
- **PORT:** `BreadcrumbView.swift`:
  1. Read `parent` property from current note's frontmatter
  2. Build ancestor chain by following `parent` links
  3. Render as horizontal breadcrumb bar above editor: `Root > Category > Subcategory > Current Note`
  4. Click any breadcrumb to navigate to that note
  5. Also support folder-based breadcrumbs as fallback
- **Builds on:** `SDPage.properties`, knowledge graph
- **Complexity:** 1/5
- **New files:** `Views/BreadcrumbView.swift`

### 8.8 Recent Files
- **Downloads:** ~600K
- **What it does:** Sidebar pane showing recently opened files.
- **PORT:** `RecentFilesView.swift` — maintain ordered list of recently opened `SDPage` IDs in `UserDefaults`, display in sidebar with file icon, title, and last modified date. Limit to configurable count (default 50).
- **Complexity:** 1/5
- **New files:** `Views/RecentFilesView.swift`

---

## Category 9: Publishing & Sharing

### 9.1 Digital Garden
- **Downloads:** ~200K
- **Website:** [dg-docs.ole.dev](https://dg-docs.ole.dev)
- **What it does:** Publish selected notes as a website. Supports wikilinks, backlinks, graph view, themes, and selective publishing via frontmatter flag.
- **PORT:** `PublishService.swift`:
  1. Filter notes where `publish: true` in frontmatter
  2. Resolve wikilinks to relative URLs
  3. Convert markdown to HTML via `MarkdownToHTMLConverter.swift` (using swift-markdown or cmark)
  4. Generate static site with index page, navigation, search, and graph visualization (reuse graph data as JSON for D3.js)
  5. Deploy options: export as folder, or push to GitHub Pages via `GitSyncService`
  6. Theme support: map current Epistemos theme to CSS variables
- **Builds on:** Markdown parser, `GitSyncService`, `SDPage`
- **Complexity:** 4/5
- **New files:** `Services/PublishService.swift`, `Converters/MarkdownToHTMLConverter.swift`, `Templates/SiteTemplate/` (HTML/CSS/JS template files)

### 9.2 Quartz (Static Site Generator)
- **Downloads:** External tool, very popular
- **Website:** [quartz.jzhao.xyz](https://quartz.jzhao.xyz)
- **What it does:** Full static site generator designed for Obsidian vaults — converts vault to searchable website with graph, backlinks, and explorer.
- **PORT:** Fold into `PublishService.swift` above. The native Epistemos publisher should match Quartz's output quality: full-text search (client-side via Lunr.js), interactive graph (D3.js), table of contents, backlink sections, tag pages.
- **Complexity:** Included in 9.1

### 9.3 HTML Export
- **Downloads:** ~200K
- **What it does:** Export individual notes as standalone HTML files with embedded styles.
- **PORT:** `HTMLExporter.swift`:
  1. Convert single `SDPage` to standalone HTML with inline CSS
  2. Resolve image references to base64 data URLs for single-file export
  3. Optional: include table of contents, reading time estimate
  4. Export via NSSavePanel or share sheet
- **Builds on:** Markdown parser
- **Complexity:** 2/5
- **New files:** `Export/HTMLExporter.swift`

### 9.4 Pandoc Integration
- **Downloads:** ~150K
- **What it does:** Convert notes to DOCX, PDF, LaTeX, EPUB, and other formats via Pandoc CLI.
- **PORT:** `DocumentConverter.swift`:
  1. Check for Pandoc installation (`which pandoc`)
  2. Shell out to `pandoc` with appropriate flags for target format
  3. UI: "Export As..." menu with format picker
  4. Formats: PDF (via LaTeX or wkhtmltopdf), DOCX, EPUB, LaTeX, ODT, PPTX
  5. If Pandoc not installed, show homebrew install command
- **Builds on:** Shell access, `SDPage` content export
- **Complexity:** 2/5
- **New files:** `Services/DocumentConverter.swift`

---

## Category 10: UI & Theming

### 10.1 Style Settings
- **Downloads:** ~2M+ (Top 9 overall)
- **GitHub:** [mgmeyers/obsidian-style-settings](https://github.com/mgmeyers/obsidian-style-settings)
- **What it does:** Exposes CSS variables from themes as configurable settings — fonts, colors, spacing, border radius, etc.
- **PORT:** Epistemos already has 12 themes. Extend with `ThemeCustomizer.swift`:
  1. Define theme variables as `SDThemeVariable` (name, type, default, current)
  2. Variables: primary color, background color, accent color, font family, font size, heading scale, line spacing, content width, border radius
  3. `ThemeCustomizerView.swift` — settings panel with color pickers, sliders, font selectors
  4. Live preview: changes apply in real-time
  5. Export/import custom themes as JSON
- **Builds on:** Existing 12 themes
- **Complexity:** 2/5
- **New files:** `Services/ThemeCustomizer.swift`, `Views/ThemeCustomizerView.swift`, `Models/SDThemeVariable.swift`

### 10.2 Pixel Banner
- **Downloads:** ~100K
- **What it does:** Decorative banner images at top of notes based on frontmatter property.
- **PORT:** `NoteBannerView.swift`:
  1. Read `banner` property from frontmatter (image URL or vault path)
  2. Render banner image with parallax scroll effect at top of note
  3. Support gradient overlay for text readability
  4. `banner-height` property for custom sizing
- **Builds on:** `SDPage.properties`, editor header area
- **Complexity:** 1/5
- **New files:** `Views/NoteBannerView.swift`

### 10.3 Hider
- **Downloads:** ~400K
- **What it does:** Hide UI elements — sidebar toggle, scrollbar, title bar, vault name, etc.
- **PORT:** `UICustomizationSettings.swift`:
  1. Boolean toggles for each UI element: sidebar, toolbar, status bar, tab bar, scrollbar
  2. Stored in `UserDefaults`
  3. Applied via SwiftUI conditional modifiers
- **Builds on:** Window layout
- **Complexity:** 1/5
- **New files:** `Settings/UICustomizationSettings.swift`

---

## Category 11: Graph Enhancements

### 11.1 Extended Graph (Juggl)
- **Downloads:** ~150K
- **What it does:** Images on graph nodes, multiple node shapes (circle, rectangle, diamond), colored edges by relationship type, SVG export, graph statistics (degree distribution, clustering coefficient).
- **PORT:** Extend existing Metal `GraphEngine`:
  1. **Node images:** Resolve `SDPage.icon` or first image in note, render as texture on graph node via Metal `MTLTexture`
  2. **Node shapes:** Add `NodeShape` enum (`.circle`, `.rectangle`, `.diamond`, `.hexagon`) to `GraphNode`, render different geometry in vertex shader
  3. **Edge colors:** Map `RelationshipType` (12 types exist) to colors, render edges with per-edge color uniform
  4. **SVG export:** `GraphSVGExporter.swift` — traverse graph layout, emit SVG elements with positions
  5. **Statistics panel:** `GraphStatisticsView.swift` — display node count, edge count, average degree, clustering coefficient, connected components
- **Builds on:** `GraphEngine` (Metal), existing 7 node types, 12 relationship types
- **Complexity:** 3/5
- **New files:** `Graph/GraphSVGExporter.swift`, `Views/GraphStatisticsView.swift`

### 11.2 Graph Analysis
- **Downloads:** ~100K
- **What it does:** Betweenness centrality, PageRank, community detection, closeness centrality, degree distribution.
- **PORT:** `GraphAnalyticsService.swift` — implement in **Rust** for performance on large graphs:
  1. `betweenness_centrality()` — Brandes algorithm, O(VE)
  2. `pagerank(damping: f64, iterations: usize)` — iterative PageRank
  3. `community_detection()` — Louvain modularity optimization
  4. `closeness_centrality()` — BFS-based
  5. `shortest_path(from: NodeId, to: NodeId)` — Dijkstra's on weighted graph
  6. Expose via Swift-Rust bridge (existing infrastructure)
  7. Results stored as node metadata and visualized as node size/color in graph
- **Builds on:** `graph-engine` Rust crate, Swift-Rust bridge
- **Complexity:** 4/5
- **New files:** `graph-engine/src/analytics.rs`, `Services/GraphAnalyticsService.swift`

### 11.3 Journey (Path Finder)
- **Downloads:** ~100K
- **What it does:** Find shortest path between two notes in the knowledge graph.
- **PORT:** `PathFinderView.swift`:
  1. Two-note selector (search fields for source and destination)
  2. BFS/Dijkstra via `GraphAnalyticsService.shortest_path()`
  3. Render path as highlighted subgraph with step-by-step navigation
  4. Show all paths up to length N (configurable, default 5)
- **Builds on:** `GraphAnalyticsService`, `GraphEngine`
- **Complexity:** 2/5
- **New files:** `Views/PathFinderView.swift`

---

## Category 12: Terminal & Shell Integration

### 12.1 Shell Commands
- **Downloads:** ~200K
- **GitHub:** [Taitava/obsidian-shellcommands](https://github.com/Taitava/obsidian-shellcommands)
- **What it does:** Run terminal commands from notes with variable substitution (file path, selection, clipboard), capture output back into notes.
- **PORT:** `ShellCommandService.swift` — see Part 4 for full terminal specification. This plugin's feature set is a subset of the planned terminal integration.
- **Complexity:** See Part 4

### 12.2 Terminal Plugin
- **Downloads:** ~50K
- **What it does:** Embedded terminal panel in Obsidian.
- **PORT:** Full terminal emulator — see Part 4 for complete specification.
- **Complexity:** See Part 4

---

# PART 2: NOTION FEATURES TO PORT

Notion represents the gold standard for structured data management in a document-first tool. While Obsidian plugins handle many of these use cases, Notion's native implementations are more polished. This section maps Notion's complete feature set to Epistemos.

---

## 2.1 Databases & Views

Notion's database system is its core differentiator — pages are database rows, properties are columns, and views are saved query+layout combinations.

### Table View
- **What it does:** Spreadsheet-like view of database pages with sortable, filterable, groupable columns. Inline editing of all property types.
- **PORT:** `DatabaseTableView.swift`:
  1. SwiftUI `Table` with dynamic columns generated from `SDPropertySchema`
  2. `TableColumn` per property with type-appropriate cell renderers
  3. Inline editing: tap cell to edit, changes write to `SDPage.properties`
  4. Header right-click: sort ascending/descending, filter, hide column
  5. Frozen first column (page title) with horizontal scroll for remaining columns
  6. Aggregate row at bottom: SUM, AVG, COUNT, MIN, MAX per numeric column

### Board (Kanban) View
- **PORT:** Reuse `KanbanView.swift` from Category 3.2, configured as a view type within the database system.

### Calendar View
- **PORT:** Month/week grid showing database pages on their date property. Drag to reschedule. Reuse `CalendarSidebarView.swift` components in an expanded main-area layout.

### Timeline / Gantt View
- **What it does:** Horizontal timeline with bars showing start-to-end date ranges. Dependencies between items.
- **PORT:** `TimelineView.swift`:
  1. Horizontal scrollable timeline with day/week/month zoom levels
  2. Bars rendered for each `SDPage` with `startDate` and `endDate` properties
  3. Drag bar edges to resize (update dates)
  4. Dependency arrows between items (stored as `SDRelation`)
  5. Today line indicator
  6. Grouping by property (e.g., group by assignee)
- **Complexity:** 4/5
- **New files:** `Views/Database/TimelineView.swift`

### Gallery View
- **PORT:** `GalleryView.swift` — `LazyVGrid` of cards showing page cover image (or first image), title, and up to 3 preview properties. Masonry layout option.

### Chart View
- **PORT:** Aggregate database data into Swift Charts visualizations. Reuse `ChartBlockRenderer.swift` components with database query integration.

### Relations Between Databases
- **What it does:** Link pages in one database to pages in another. Bidirectional.
- **PORT:** `SDRelation` SwiftData model already supports relationships via the knowledge graph. Extend:
  1. `RelationPropertyEditor.swift` — search and link to pages in a target database
  2. Bidirectional: when Page A relates to Page B, Page B auto-shows reverse relation
  3. Multi-select relations (one page links to many)
- **Builds on:** Knowledge graph edges, `SDPage`
- **Complexity:** 2/5

### Rollup Properties
- **What it does:** Aggregate data from related pages — sum, average, count, min, max, show original values, percent checked.
- **PORT:** `RollupEvaluator.swift`:
  1. Given a relation property and a target property, fetch all related pages' values
  2. Apply aggregation function: `.sum`, `.average`, `.count`, `.countUnique`, `.min`, `.max`, `.range`, `.percentChecked`, `.showOriginal`
  3. Cache results and invalidate on related page change via SwiftData observation
- **Complexity:** 3/5
- **New files:** `Services/RollupEvaluator.swift`

### Formula Properties
- **What it does:** Computed properties using expressions referencing other properties. Supports `if()`, `dateBetween()`, `format()`, `length()`, `contains()`, `map()`, `filter()`, mathematical operators.
- **PORT:** `FormulaEngine.swift`:
  1. Parse formula syntax into AST: `if(prop("Status") == "Done", "✅", "⏳")`
  2. Built-in functions: arithmetic, string manipulation, date math, logical operators, collection operations (`map`, `filter`, `reduce`)
  3. Property references resolved from the page's `SDPage.properties`
  4. Evaluate on read, re-evaluate when dependency properties change
  5. Formula editor with syntax highlighting and autocomplete
- **Complexity:** 4/5
- **New files:** `Services/FormulaEngine.swift`, `Parsers/FormulaParser.swift`, `Views/FormulaEditorView.swift`

### Multiple Views Per Database
- **PORT:** `SDDatabaseView` model stores view configurations (type, filters, sorts, groups, visible properties, property order). Each database can have N views, switchable via tab bar. All views query the same underlying `SDPage` collection.
- **New files:** `Models/SDDatabaseViewConfig.swift`

---

## 2.2 Automations

### Database Triggers
- **What it does:** Fire automations when: page added, property edited (with specific value conditions), or on recurring schedule (daily, weekly, monthly).
- **PORT:** `AutomationEngine.swift`:
  1. `SDAutomation` SwiftData model: `triggers: [SDAutomationTrigger]`, `actions: [SDAutomationAction]`, `enabled: Bool`
  2. `SDAutomationTrigger` variants: `.pageAdded(databaseId)`, `.propertyChanged(propertyName, condition)`, `.recurring(schedule: SDRecurrenceRule)`
  3. Trigger evaluation: SwiftData observers on `SDPage` changes → match against registered triggers → execute actions
  4. Conditions: `.equals`, `.contains`, `.startsWith`, `.greaterThan`, `.isEmpty`, `.isNotEmpty`

### Automation Actions
- **What it does:** Edit property, create page, send notification, define variable, send email (via connected Gmail), send Slack message.
- **PORT:** `SDAutomationAction` variants:
  1. `.editProperty(propertyName, value)` — set a property on the triggering page
  2. `.createPage(databaseId, properties)` — create a new page with specified properties
  3. `.editPagesIn(databaseId, filter, propertyChanges)` — bulk update matching pages
  4. `.notify(recipients, message)` — macOS notification via `UNUserNotificationCenter`
  5. `.defineVariable(name, formula)` — computed value for use in subsequent actions
  6. `.runShortcut(shortcutName)` — invoke Siri Shortcuts for external integrations (email, Slack, etc.)
  7. Actions execute sequentially; variables from earlier actions available in later ones

### Automation Builder UI
- **PORT:** `AutomationBuilderView.swift`:
  1. Visual builder: trigger card → condition cards → action cards
  2. Drag-and-drop to reorder actions
  3. Test button: simulate automation with a specific page
  4. Run history: log of all automation executions with timestamps and outcomes
- **Complexity:** 4/5
- **New files:** `Services/AutomationEngine.swift`, `Models/SDAutomation.swift`, `Models/SDAutomationTrigger.swift`, `Models/SDAutomationAction.swift`, `Views/AutomationBuilderView.swift`

---

## 2.3 AI Features

### Notion Agent
- **What it does:** AI that can create and edit pages, databases, and properties. Takes multi-step actions via natural language commands.
- **PORT:** **Already largely implemented** via `OmegaAgent` and MCP tools. Ensure the agent has tools for:
  1. `createPage(title, content, folder, properties)` — MCP tool
  2. `editPage(pageId, changes)` — MCP tool
  3. `queryDatabase(filter, sort)` — MCP tool
  4. `editProperty(pageId, propertyName, value)` — MCP tool
  5. These map directly to existing MCP tool infrastructure

### Custom Agents (Notion Custom Agents)
- **What it does:** Reusable AI workflows — user defines a name, instructions, knowledge sources, and triggers. Agent runs automatically or on-demand.
- **PORT:** `CustomAgentBuilder.swift`:
  1. `SDCustomAgent` model: `name`, `systemPrompt`, `knowledgeSources: [SDFolder]`, `triggers: [SDAutomationTrigger]`, `actions: [AgentAction]`
  2. Knowledge source scoping: restrict LLM context to specific folders/tags
  3. Trigger integration: run agent when automation trigger fires (e.g., new page in inbox → agent categorizes it)
  4. Agent history and audit log
- **Builds on:** `AgentCoordinator`, `OmegaAgent`, `AutomationEngine`
- **Complexity:** 3/5
- **New files:** `Services/CustomAgentBuilder.swift`, `Models/SDCustomAgent.swift`

### AI Autofill
- **What it does:** Auto-populate database properties using AI based on page content. Example: auto-generate tags, categories, summaries.
- **PORT:** `AIAutofillService.swift`:
  1. Define autofill rules per property: `{ property: "category", prompt: "Categorize this note into one of: Research, Meeting, Idea, Task" }`
  2. On new page creation or manual trigger, send page content + prompt to `LLMService`
  3. Parse LLM response and write to property
  4. Batch mode: autofill all pages in a database that have empty target properties
- **Builds on:** `LLMService`, `SDPage.properties`
- **Complexity:** 2/5
- **New files:** `Services/AIAutofillService.swift`

### AI Connectors
- **What it does:** Connect Slack, Google Drive, Jira, GitHub, Linear, Gmail, Outlook, Google Calendar to Notion AI for cross-tool search.
- **PORT:** `ConnectorService.swift`:
  1. `SDConnector` protocol: `func search(query: String) async -> [ConnectorResult]`, `func index() async`
  2. Implement connectors: `GitHubConnector`, `SlackConnector`, `GoogleDriveConnector`, `JiraConnector`, `GmailConnector`, `CalendarConnector`
  3. Each connector uses OAuth2 for authentication (stored in Keychain)
  4. Index external content as embeddings in `HNSWIndex` with source metadata
  5. Unified search queries HNSW across all sources
  6. **Alternative:** Use MCP servers for external tools (many already exist as open-source MCP servers for GitHub, Slack, Google Drive)
- **Builds on:** `HNSWIndex`, MCP infrastructure, OAuth2
- **Complexity:** 5/5 (per-connector effort)
- **New files:** `Services/ConnectorService.swift`, `Connectors/GitHubConnector.swift`, `Connectors/SlackConnector.swift`, etc.

---

## 2.4 Collaboration (Future Architecture)

### Real-Time Multiplayer Editing
- **What it does:** Multiple users editing the same page simultaneously with cursor presence.
- **PORT:** **Future feature.** Document architecture for when CRDT (Loro) integration goes live:
  1. `CollaborationService.swift` — manage WebSocket connections to sync server
  2. Loro CRDT integration in Rust: `loro-crdt` crate for conflict-free merge
  3. Cursor presence: broadcast cursor positions, render remote cursors with user color/name
  4. Operation transform: local edits apply immediately, remote edits merge via CRDT
  5. **Prerequisite:** Sync server infrastructure (WebSocket + persistent storage)
- **Complexity:** 5/5 (major infrastructure)
- **Status:** Architecture only — not for immediate implementation

### Comments & @Mentions
- **PORT:** `CommentService.swift`:
  1. `SDComment` model: `content`, `author`, `timestamp`, `blockReference: SDBlock`, `resolved: Bool`
  2. Inline comment markers in editor (highlight + gutter indicator)
  3. `@mention` autocomplete: type `@` → show user list (for future multi-user) or note list (for note linking)
  4. Comment thread view in sidebar
- **Complexity:** 3/5
- **New files:** `Services/CommentService.swift`, `Models/SDComment.swift`, `Views/CommentThreadView.swift`

### Permissions (7-Tier RBAC)
- **Notion levels:** Full Access, Can Edit, Can Edit Content, Can Comment, Can View, Can View Tasks, No Access
- **PORT:** `PermissionManager.swift` — when multi-user collaboration is implemented:
  1. `SDPermission` model: `userId`, `pageId`, `level: PermissionLevel`
  2. Permission inheritance: child pages inherit parent permissions, overridable
  3. Enforcement: check permissions before read/write operations
  4. **Note:** Single-user mode (current) has no permission checks; this is for future multi-user
- **Complexity:** 3/5 (architecture now, implementation later)

---

## 2.5 Templates & Blocks

### Block Types Extension
- **Notion blocks:** Toggle, callout, synced block, divider, table of contents, bookmark, file, audio, video, code, math (KaTeX), breadcrumb, template button
- **PORT:** Extend `BlockType` enum:
  1. `.toggle(title: String, children: [SDBlock])` — collapsible section
  2. `.callout(icon: String, color: Color, children: [SDBlock])` — highlighted info box
  3. `.syncedBlock(sourceId: BlockID)` — mirror of another block, edits propagate
  4. `.divider` — horizontal rule with optional style
  5. `.tableOfContents` — auto-generated from headings
  6. `.bookmark(url: URL, title: String?, description: String?, thumbnail: URL?)` — rich URL preview
  7. `.audio(url: URL)` — inline audio player via AVFoundation
  8. `.video(url: URL)` — inline video player via AVKit
  9. `.math(latex: String)` — rendered via MathJax in WKWebView or native LaTeX renderer
  10. `.aiBlock(prompt: String, output: String?)` — block powered by AI generation, re-runnable
- **Complexity:** 3/5
- **New files:** `Models/ExtendedBlockTypes.swift`, `Views/Blocks/ToggleBlockView.swift`, `Views/Blocks/CalloutBlockView.swift`, `Views/Blocks/SyncedBlockView.swift`, `Views/Blocks/AIBlockView.swift`

---

# PART 3: LOGSEQ FEATURES TO PORT

Logseq's outliner-first design and advanced query system offer unique features not found in Obsidian or Notion.

---

### 3.1 Datalog Queries
- **What it does:** Advanced queries using Datalog syntax (like Datomic) — more powerful than Dataview, can query blocks, their properties, and relationships with full logical programming.
- **PORT:** `DatalogQueryEngine.swift`:
  1. Implement a subset of Datalog: `:find`, `:where`, `:in` clauses
  2. Translate Datalog patterns to SwiftData predicates
  3. Example: `[:find ?page :where [?page :page/tags "project"] [?page :block/content ?c]]`
  4. This is the most powerful query language option — consider as an advanced mode alongside DQL (Dataview syntax)
- **Builds on:** SwiftData, `QueryAST`
- **Complexity:** 5/5
- **New files:** `Parsers/DatalogParser.swift`, `Services/DatalogQueryEngine.swift`

### 3.2 Block-Level References
- **PORT:** **Already implemented.** Epistemos has block transclusions and wikilinks. Verify that block-level granularity (not just page-level) is fully supported in backlinking panel.

### 3.3 SmartBlocks
- **What it does:** Intelligent template expansion with conditional logic, date math, random selection, dynamic content insertion.
- **PORT:** Extend `TemplateEngine.swift` with SmartBlock capabilities:
  1. Conditional blocks: `{{#if property "status" equals "active"}}...{{/if}}`
  2. Date math: `{{ep.date.add(days: 7)}}`
  3. Random selection: `{{ep.random(["Option A", "Option B", "Option C"])}}`
  4. Dynamic queries: `{{ep.query("tasks due today")}}`
- **Builds on:** `TemplateEngine.swift`
- **Complexity:** 2/5

### 3.4 Tabs Plugin
- **What it does:** Multi-tab interface for opening multiple notes simultaneously.
- **PORT:** `TabBarView.swift`:
  1. Horizontal tab bar above editor showing open `SDPage` tabs
  2. Tab management: close, close others, close all, pin tab
  3. Drag-and-drop tab reordering
  4. Middle-click to close, Cmd+W to close active, Cmd+T for new tab
  5. Persistent: restore tabs on app relaunch
- **Builds on:** Window management, `SDPage`
- **Complexity:** 2/5
- **New files:** `Views/TabBarView.swift`, `Services/TabManager.swift`

### 3.5 Automatic Linker
- **What it does:** Auto-detect text that matches existing page titles and offer to convert them to wikilinks.
- **PORT:** `AutoLinkerService.swift`:
  1. Maintain a trie or hash set of all `SDPage.title` values
  2. On note save (or live as-you-type), scan content for matches
  3. Highlight matches with subtle underline
  4. Click highlight or use shortcut to convert to `[[wikilink]]`
  5. Configurable: minimum word length, exclude list, case sensitivity
- **Builds on:** `SDPage` title index, editor
- **Complexity:** 2/5
- **New files:** `Services/AutoLinkerService.swift`

### 3.6 TODO Management with Workflow Keywords
- **What it does:** Logseq's `TODO`, `DOING`, `DONE`, `LATER`, `NOW`, `WAITING`, `CANCELLED` keywords with cycling behavior (click to advance state).
- **PORT:** Extend `TaskManager.swift` with workflow keywords:
  1. `TaskWorkflow` model: ordered list of statuses that cycle on click
  2. Default workflow: TODO → DOING → DONE
  3. Custom workflows: user-definable status sequences
  4. Editor integration: clicking the keyword cycles to next state
- **Builds on:** `TaskManager.swift`, `SDTask`
- **Complexity:** 1/5

### 3.7 Whiteboards
- **What it does:** Infinite canvas with embedded Logseq blocks, drawing tools, shapes, arrows, and connections to the knowledge graph. Built on tldraw.
- **PORT:** Covered by Excalidraw port (Category 4.1) and Canvas port (Category 4.4). Logseq whiteboards combine drawing (Excalidraw) with note embedding (Canvas). The Epistemos `CanvasView.swift` should support both use cases.

### 3.8 Logseq Outliner Mode
- **What it does:** Every line is a block. Blocks can be indented infinitely. Blocks have their own properties. Blocks can be referenced individually.
- **PORT:** Epistemos already has `SDBlock` with block references and transclusions. Ensure:
  1. Outline-mode toggle in editor (bullet point per line, with indent/outdent via Tab/Shift-Tab)
  2. Block-level properties (key-value pairs on individual blocks, not just pages)
  3. Block folding: collapse/expand children
- **Builds on:** TextKit 2 editor, `SDBlock`
- **Complexity:** 2/5

### 3.9 Logseq MCP Server & CLI
- **What it does:** Model Context Protocol server for AI agent interaction, and CLI for command-line vault management.
- **PORT:** **Already implemented.** Epistemos has MCP agent infrastructure. Ensure CLI access:
  1. `epistemos-cli` command-line tool: `epistemos search "query"`, `epistemos create "title"`, `epistemos list --tag project`
  2. MCP server exposes vault operations to external AI tools
- **Builds on:** MCP infrastructure
- **Complexity:** 2/5
- **New files:** `CLI/EpistemosCLI.swift`

---

# PART 4: TERMINAL INTEGRATION DEEP SPEC

Epistemos's `Views/Shell/` directory indicates terminal integration is planned. This section provides a comprehensive specification.

---

## 4.1 Embedded Terminal Emulator

### Architecture
- **Library:** [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza — VT100/Xterm terminal emulator library for Swift. Supports macOS and iOS. Renders via Metal shaders for animated backgrounds.
- **Integration point:** `Views/Shell/TerminalView.swift` wrapping `SwiftTerm.LocalProcessTerminalView`

### Features
| Feature | Implementation |
|---------|---------------|
| Shell support | bash, zsh, fish — detect via `$SHELL` environment variable |
| Split panes | `NSSplitView` with horizontal/vertical splits, keyboard shortcuts (Cmd+D horizontal, Cmd+Shift+D vertical) |
| Multiple sessions | Tab-based sessions managed by `TerminalSessionManager.swift`, each with independent `LocalProcess` |
| Color themes | Map Epistemos theme colors to terminal ANSI palette via `TerminalThemeAdapter.swift` |
| Font configuration | Use editor font by default, configurable independently |
| Scrollback buffer | 10,000 lines default, configurable. Searchable via Cmd+F |
| Hyperlink detection | Detect URLs in output via regex, make clickable |
| Image protocol | Support iTerm2 inline image protocol for `imgcat` |

### New Files
```
Views/Shell/TerminalView.swift
Views/Shell/TerminalTabBar.swift
Views/Shell/TerminalSplitView.swift
Services/TerminalSessionManager.swift
Services/TerminalThemeAdapter.swift
```

---

## 4.2 Note-Terminal Bridge

### Shell Commands from Notes
Execute shell commands embedded in notes via fenced code blocks or inline syntax:

```markdown
`= shell("ls -la ~/Documents")`
```

Or via executable code blocks:
````markdown
```bash {run}
echo "Current note: {{note.title}}"
grep -r "TODO" {{vault.path}}
```
````

### Variable Substitution
| Variable | Resolves To |
|----------|-------------|
| `{{note.title}}` | Current note's title |
| `{{note.path}}` | Absolute file path of current note |
| `{{note.content}}` | Full markdown content |
| `{{selection}}` | Currently selected text in editor |
| `{{clipboard}}` | System clipboard content |
| `{{date}}` | Today's date (ISO 8601) |
| `{{date:format}}` | Formatted date (e.g., `{{date:YYYY-MM-DD}}`) |
| `{{vault.path}}` | Vault root directory path |
| `{{cursor}}` | Cursor position after command execution |
| `{{prompt:label}}` | Show text prompt dialog, insert user input |

### Output Capture
- **Modes:** Replace selection, append to note, insert at cursor, new note, notification, clipboard
- **Streaming:** For long-running commands, stream output into a dedicated output pane below the editor
- **Error handling:** Display stderr in red; non-zero exit codes show error banner

### Code Block Execution
Run fenced code blocks directly:

| Language | Runtime | Implementation |
|----------|---------|----------------|
| bash/zsh | System shell | Direct `Process()` execution |
| python | System Python or venv | `Process()` with `python3` |
| swift | Swift REPL | `Process()` with `swift` |
| rust | cargo-script | `Process()` with `cargo-script` or `rust-script` |
| javascript | Node.js | `Process()` with `node` |
| applescript | osascript | `Process()` with `osascript` |

### REPL Integration
- `PythonREPLView.swift` — persistent Python REPL session with note context injection
- `SwiftREPLView.swift` — Swift REPL for quick calculations and prototyping
- Send code blocks to REPL with Cmd+Enter, results appear inline

### New Files
```
Services/ShellCommandService.swift
Services/CodeBlockRunner.swift
Services/VariableSubstitution.swift
Views/Shell/REPLView.swift
Editor/ExecutableCodeBlockRenderer.swift
```

---

## 4.3 Terminal Agent Integration

### Agent Terminal Tools
The MCP agent system gains terminal execution capability:

```json
{
  "tool": "execute_command",
  "parameters": {
    "command": "git status",
    "working_directory": "{{vault.path}}",
    "timeout_ms": 30000,
    "sandbox": "restricted"
  }
}
```

### Sandboxing
| Sandbox Level | Capabilities |
|---------------|-------------|
| `restricted` | Read-only filesystem access, no network, no process spawning |
| `standard` | Read-write in vault directory only, limited network (localhost) |
| `elevated` | Full filesystem access in home directory, network access — requires user approval |
| `unrestricted` | Full system access — requires explicit per-command approval |

Default agent sandbox level: `standard`. User can configure per agent profile.

### Command History as Knowledge
- All terminal commands and their outputs stored as `SDTerminalEntry` in SwiftData
- Indexed in FTS5 for search ("find that grep command I ran last week")
- Linked to the note that was open when command was executed
- `TerminalHistoryView.swift` — searchable command history with re-run capability

### Terminal Output → Note Conversion
- Select terminal output → right-click → "Save to Note"
- Auto-format: wrap in fenced code block with language detection
- `TerminalOutputParser.swift` — detect structured output (JSON, CSV, tables) and offer to convert to markdown tables or database entries

### New Files
```
MCP/Tools/TerminalExecuteTool.swift
Services/TerminalSandbox.swift
Models/SDTerminalEntry.swift
Views/TerminalHistoryView.swift
Services/TerminalOutputParser.swift
```

---

## 4.4 Developer-Focused Features

### Git Integration
Beyond `GitSyncService.swift`, the terminal provides a developer-friendly git experience:
1. **Git status sidebar:** Modified/staged/untracked files with diff preview
2. **Inline diff:** View file changes in the editor with gutter indicators (green add, red delete)
3. **Commit from sidebar:** Stage files, write commit message, commit+push
4. **Branch selector:** Dropdown in toolbar showing current branch, switch branches
5. **Blame view:** `git blame` annotations in editor gutter

### SSH Connection Manager
- `SSHManager.swift` — save SSH connection profiles (host, port, user, key path)
- Quick-connect from terminal session dropdown
- SSH keys stored in Keychain
- SFTP file browser for remote file access

### Environment Variable Management
- `EnvManager.swift` — per-project `.env` file management
- Variables loaded into terminal sessions automatically
- UI editor for `.env` files with secret masking

### Script Library
- `ScriptLibrary.swift` — save and organize frequently used commands/scripts
- Tag and search scripts
- One-click execution from library panel
- Share scripts between vaults

---

# PART 5: PLUGIN SDK ARCHITECTURE

Epistemos needs its own extension system to enable community contributions and custom workflows.

---

## 5.1 Architecture Options Analysis

| Option | Language | Performance | Ecosystem Size | Safety | Recommendation |
|--------|----------|-------------|----------------|--------|----------------|
| **A: Swift Packages** | Swift | Native (best) | Small (new) | Compiled, type-safe | Best for performance-critical plugins |
| **B: JavaScript/TS** | JS/TS | WKWebView bridge (moderate) | Huge (Obsidian compat) | Sandboxed in WebView | Best for ecosystem growth |
| **C: Python** | Python | Python bridge (moderate) | Large (ML/data) | Process isolation | Best for ML/data plugins |
| **D: MCP-based** | Any | JSON-RPC (good) | Growing | Process isolation | Best for tool integrations |

### RECOMMENDED: Hybrid Architecture

```
┌─────────────────────────────────────────────┐
│              Epistemos Plugin Host            │
├──────────┬──────────┬──────────┬────────────┤
│  Swift   │   MCP    │  Python  │  JS/TS     │
│ Packages │ Servers  │ Plugins  │ (Future)   │
│ (native) │ (tools)  │ (ML/AI)  │ (compat)   │
├──────────┴──────────┴──────────┴────────────┤
│           Plugin API Surface                 │
│  Notes · Search · UI · Events · Graph · AI  │
│  Terminal · Settings · Filesystem            │
└─────────────────────────────────────────────┘
```

**Wave 1:** MCP-based plugins (already have MCP infrastructure) + Swift Package plugins (native, type-safe)
**Wave 2:** Python plugins (leverage existing Python bridge for ML extensions)
**Wave 3:** JavaScript/TypeScript plugins (for Obsidian community migration)

---

## 5.2 Plugin API Surface

### Notes API
```swift
protocol NotesAPI {
    func getPage(id: PageID) async -> SDPage?
    func createPage(title: String, content: String, folder: String?, properties: [String: Any]?) async -> SDPage
    func updatePage(id: PageID, content: String) async
    func deletePage(id: PageID) async
    func getPages(filter: PageFilter) async -> [SDPage]
    func getBlocks(pageId: PageID) async -> [SDBlock]
    func createBlock(pageId: PageID, content: String, position: BlockPosition) async -> SDBlock
    func onPageCreated(_ handler: @escaping (SDPage) -> Void) -> Cancellable
    func onPageModified(_ handler: @escaping (SDPage) -> Void) -> Cancellable
    func onPageDeleted(_ handler: @escaping (PageID) -> Void) -> Cancellable
}
```

### Search API
```swift
protocol SearchAPI {
    func fullTextSearch(query: String, limit: Int) async -> [SearchResult]
    func semanticSearch(query: String, limit: Int) async -> [SearchResult]
    func fuzzySearch(query: String, limit: Int) async -> [SearchResult]
    func graphTraversal(from: NodeID, depth: Int, types: [RelationshipType]?) async -> GraphSubset
}
```

### UI API
```swift
protocol UIAPI {
    func registerSidebarPanel(id: String, title: String, icon: String, view: @escaping () -> AnyView)
    func registerToolbarButton(id: String, icon: String, tooltip: String, action: @escaping () -> Void)
    func registerCommand(id: String, name: String, shortcut: KeyboardShortcut?, action: @escaping () -> Void)
    func registerEditorDecoration(id: String, decorator: EditorDecorator)
    func registerCodeBlockRenderer(language: String, renderer: CodeBlockRenderer)
    func registerContextMenuItem(id: String, title: String, context: ContextMenuContext, action: @escaping (ContextMenuPayload) -> Void)
    func showNotification(title: String, body: String, type: NotificationType)
    func showModal(title: String, view: @escaping () -> AnyView) -> ModalHandle
}
```

### Settings API
```swift
protocol SettingsAPI {
    func get<T: Codable>(key: String, default: T) -> T
    func set<T: Codable>(key: String, value: T)
    func registerSettingsTab(view: @escaping () -> AnyView)
}
```

### Events API
```swift
protocol EventsAPI {
    func on(_ event: AppEvent, handler: @escaping (EventPayload) -> Void) -> Cancellable
    // Events: .appStarted, .appWillTerminate, .vaultOpened, .vaultClosed,
    //         .pageCreated, .pageModified, .pageDeleted, .pageOpened,
    //         .editorSelectionChanged, .searchPerformed, .commandExecuted
}
```

### Graph API
```swift
protocol GraphAPI {
    func getNode(id: NodeID) async -> GraphNode?
    func getEdges(from: NodeID) async -> [GraphEdge]
    func addNode(type: NodeType, metadata: [String: Any]) async -> GraphNode
    func addEdge(from: NodeID, to: NodeID, type: RelationshipType) async -> GraphEdge
    func removeEdge(id: EdgeID) async
    func queryGraph(predicate: GraphPredicate) async -> [GraphNode]
}
```

### AI API
```swift
protocol AIAPI {
    func complete(prompt: String, maxTokens: Int, temperature: Float) async -> String
    func stream(prompt: String, maxTokens: Int, temperature: Float) -> AsyncStream<String>
    func embed(text: String) async -> [Float]
    func embedBatch(texts: [String]) async -> [[Float]]
}
```

### Terminal API
```swift
protocol TerminalAPI {
    func execute(command: String, workingDirectory: String?, timeout: TimeInterval?) async -> CommandResult
    func startSession() -> TerminalSession
}
```

---

## 5.3 Sandboxing & Security

### Process Isolation
- **Swift plugins:** Run in-process but with capability restrictions enforced at API level
- **MCP plugins:** Run as separate processes communicating via JSON-RPC over stdio
- **Python plugins:** Run in subprocess with restricted `PATH` and filesystem access
- **JS plugins:** Run in `WKWebView` sandbox with message-passing bridge

### Permission System
Plugins declare required permissions in their manifest. Users approve on install.

| Permission | Grants Access To |
|------------|-----------------|
| `notes.read` | Read note content and properties |
| `notes.write` | Create, edit, delete notes |
| `search.fulltext` | Full-text search |
| `search.semantic` | Semantic/vector search |
| `ui.sidebar` | Register sidebar panels |
| `ui.toolbar` | Register toolbar buttons |
| `ui.commands` | Register command palette commands |
| `ui.editor` | Editor decorations and code block renderers |
| `graph.read` | Read graph nodes and edges |
| `graph.write` | Modify graph structure |
| `ai.inference` | Use LLM completion and streaming |
| `ai.embedding` | Generate embeddings |
| `terminal.execute` | Execute terminal commands |
| `filesystem.read` | Read files outside vault |
| `filesystem.write` | Write files outside vault |
| `network` | Make HTTP requests |
| `settings` | Per-plugin persistent storage |

### Resource Limits
| Resource | Default Limit | Configurable |
|----------|--------------|--------------|
| Memory | 256 MB per plugin | Yes |
| CPU | 25% of one core | Yes |
| Disk (plugin data) | 100 MB | Yes |
| Network requests/min | 60 | Yes |
| API calls/sec | 100 | Yes |

---

## 5.4 Plugin Manifest

```toml
[plugin]
id = "com.example.my-plugin"
name = "My Plugin"
version = "1.0.0"
min_epistemos_version = "2.0.0"
author = "Jane Developer"
description = "A brief description of what this plugin does"
homepage = "https://github.com/jane/my-plugin"
license = "MIT"

[plugin.permissions]
required = ["notes.read", "notes.write", "ui.sidebar"]
optional = ["ai.inference", "terminal.execute"]

[plugin.entry]
swift = "Sources/MyPlugin/Plugin.swift"     # Swift entry point
# python = "main.py"                        # Python entry point
# mcp = "server.json"                       # MCP server config

[plugin.ui]
settings = true                              # Has settings tab
sidebar = { title = "My Panel", icon = "star" }

[plugin.metadata]
tags = ["productivity", "editor"]
category = "Editor & Writing"
```

### Plugin Entry Point (Swift)
```swift
import EpistemosPluginSDK

@main
struct MyPlugin: EpistemosPlugin {
    static let manifest = PluginManifest(id: "com.example.my-plugin")
    
    func activate(context: PluginContext) async {
        // Register commands, UI elements, event handlers
        context.commands.register("my-plugin.doThing", name: "Do Thing") {
            let page = try await context.notes.getCurrentPage()
            // Plugin logic here
        }
    }
    
    func deactivate() async {
        // Cleanup
    }
}
```

---

## 5.5 Marketplace Architecture

### Plugin Registry
```json
{
  "plugins": [
    {
      "id": "com.example.my-plugin",
      "name": "My Plugin",
      "version": "1.0.0",
      "author": "Jane Developer",
      "description": "...",
      "downloads": 15234,
      "rating": 4.7,
      "repository": "https://github.com/jane/my-plugin",
      "release_url": "https://github.com/jane/my-plugin/releases/download/v1.0.0/my-plugin.zip",
      "checksum": "sha256:abc123...",
      "permissions": ["notes.read", "notes.write", "ui.sidebar"],
      "category": "Editor & Writing",
      "tags": ["productivity"],
      "min_version": "2.0.0",
      "updated": "2026-03-15T00:00:00Z"
    }
  ]
}
```

### Lifecycle
1. **Discovery:** `PluginMarketplaceView.swift` — browse/search registry, filter by category, sort by downloads/rating
2. **Install:** Download ZIP → verify checksum → extract to `~/Library/Application Support/Epistemos/Plugins/{id}/` → load manifest → prompt permission approval → activate
3. **Update:** Check for updates on app launch (compare installed version to registry), auto-update or prompt
4. **Uninstall:** Deactivate → delete plugin directory → remove settings → confirm

### Review System
- 1-5 star rating stored in registry
- Text reviews with upvote/downvote
- Automated security scan on submission (check for suspicious network calls, filesystem access patterns)
- Community moderators for manual review of flagged plugins

---

# PART 6: PRODUCTION QUALITY INFRASTRUCTURE

---

## 6.1 Linting

### Swift Linting
- **Tool:** SwiftLint (configured via `.swiftlint.yml`)
- **Key rules:** `force_cast`, `force_unwrapping`, `cyclomatic_complexity` (max 10), `function_body_length` (max 50), `file_length` (max 500), `type_body_length` (max 300)
- **Custom rules:** `epistemos_naming_convention` (prefix services with `*Service`, views with `*View`), `no_print_statements` (use `OSLog`)
- **Integration:** Pre-commit hook + CI check, auto-fix on save in Xcode

### Rust Linting
- **Tool:** Clippy (`cargo clippy -- -D warnings`)
- **Key lints:** `clippy::unwrap_used`, `clippy::expect_used` (prefer `?` operator), `clippy::pedantic`
- **Formatting:** `cargo fmt` with `rustfmt.toml` config (max width 100, imports merge)

### Python Linting
- **Tools:** Ruff (replaces flake8 + isort + black), mypy for type checking
- **Config:** `pyproject.toml` with strict type checking, max line length 100

---

## 6.2 CI/CD

### GitHub Actions Pipeline
```yaml
# .github/workflows/ci.yml
jobs:
  swift-build:
    runs-on: macos-15
    steps: [checkout, swift-lint, swift-build, swift-test, ui-test]
  rust-build:
    runs-on: ubuntu-latest
    steps: [checkout, clippy, cargo-test, cargo-bench]
  python-build:
    runs-on: ubuntu-latest  
    steps: [checkout, ruff, mypy, pytest]
  integration:
    needs: [swift-build, rust-build, python-build]
    runs-on: macos-15
    steps: [full-integration-test, performance-regression]
```

### Release Pipeline
1. Tag `vX.Y.Z` → trigger release build
2. Build universal macOS binary (arm64 + x86_64)
3. Code sign with Developer ID
4. Notarize via Apple notary service
5. Create DMG with drag-to-Applications installer
6. Upload to GitHub Releases + Sparkle update feed
7. Update Homebrew cask formula

---

## 6.3 Error Telemetry

### Structured Logging
```swift
import OSLog

extension Logger {
    static let editor = Logger(subsystem: "com.epistemos.app", category: "editor")
    static let graph = Logger(subsystem: "com.epistemos.app", category: "graph")
    static let llm = Logger(subsystem: "com.epistemos.app", category: "llm")
    static let sync = Logger(subsystem: "com.epistemos.app", category: "sync")
    static let search = Logger(subsystem: "com.epistemos.app", category: "search")
    static let terminal = Logger(subsystem: "com.epistemos.app", category: "terminal")
    static let plugins = Logger(subsystem: "com.epistemos.app", category: "plugins")
    static let automation = Logger(subsystem: "com.epistemos.app", category: "automation")
}
```

### Crash Reporting
- Write crash logs to `~/Library/Logs/Epistemos/crash-{timestamp}.log`
- Include: stack trace, OS version, app version, memory usage, active plugins
- **Local-first:** No automatic upload. User can share via "Report Issue" button that attaches logs.
- Parse MachO crash symbols via `atos` for symbolication

### Performance Metrics Dashboard
- In-app performance panel (developer mode): FPS, memory, GPU memory, query latency, LLM tokens/sec
- Metrics collected via `MetricsCollector.swift` using `os_signpost` for Instruments compatibility
- Historical metrics stored in local SQLite for trend analysis

---

## 6.4 Accessibility Audit

### VoiceOver Support
| View | Requirement | Implementation |
|------|------------|----------------|
| Knowledge Graph | Announce node name, type, and connection count on focus | `accessibilityLabel` on graph nodes, rotor for node navigation |
| Editor | Standard text editing accessibility | TextKit 2 provides this natively |
| Terminal | Announce new output lines | `UIAccessibilityPostNotification` on buffer update |
| Kanban | Announce card title, column, position | `accessibilityLabel` with context, drag-and-drop accessible via keyboard |
| Calendar | Announce date, whether note exists | `accessibilityLabel` per day cell |
| Chat | Announce new messages | Live region updates |

### Keyboard Navigation
- **Every feature** must be operable without a mouse
- Tab order follows visual flow
- Focus rings visible in all themes
- All toolbar actions have keyboard shortcuts
- Graph: arrow keys to navigate between nodes, Enter to open, Space to select

### Dynamic Type Support
- All text respects `@ScaledMetric` or `preferredFont(forTextStyle:)`
- Minimum touch target: 44×44pt
- Layout reflows gracefully at all text sizes

### Reduced Motion
- Respect `UIAccessibility.isReduceMotionEnabled`
- Replace animations with instant transitions
- Graph layout: disable force-directed simulation animation, show final state

### High Contrast
- Support `accessibilityDisplayShouldIncreaseContrast`
- Ensure WCAG AA contrast ratios (4.5:1 for text, 3:1 for UI elements) in all themes
- Test with `Accessibility Inspector`

---

## 6.5 Performance Infrastructure

### Instruments Profiles
Create custom Instruments templates for:
1. **Editor Performance:** Keystroke latency, scroll FPS, TextKit layout time
2. **Graph Rendering:** Metal frame time, GPU utilization, vertex count
3. **Search Performance:** FTS5 query time, HNSW recall, total search-to-results time
4. **LLM Inference:** Token generation speed, memory allocation, MLX kernel execution time
5. **Launch Time:** Measure cold start phases (dylib loading, SwiftData migration, UI render)

### Memory Budgets
| Component | Budget | Monitor |
|-----------|--------|---------|
| Editor (per tab) | 50 MB | Content + undo stack |
| Graph (active) | 200 MB | Nodes + edges + textures |
| LLM model | 2 GB | MLX model weights |
| HNSW index | 500 MB | Vector embeddings |
| Terminal (per session) | 20 MB | Scrollback buffer |
| Plugins (total) | 512 MB | All plugin memory |
| **Total app** | **4 GB** | Hard limit, warn at 3 GB |

### GPU Memory Tracking
- `MetalResourceTracker.swift` — track `MTLBuffer`, `MTLTexture` allocations
- Budget: 1 GB GPU memory
- Auto-reduce graph detail level when approaching limit

### Launch Time Optimization
- **Target:** < 2 seconds cold start
- Strategy: lazy-load non-critical services, defer graph loading until graph view opened, pre-warm FTS5 index in background
- Measure with `os_signpost` intervals: `dyld` → `didFinishLaunching` → `firstViewAppear`

### Background Task Energy
- Use `ProcessInfo.thermalState` to throttle background indexing during high thermal state
- Background tasks use `BGAppRefreshTask` and `BGProcessingTask` for energy-efficient scheduling
- Monitor with Energy Impact gauge in Xcode

---

## 6.6 Security Audit

### Keychain Usage
- All secrets (API keys, SSH keys, OAuth tokens) stored in Keychain via `Security.framework`
- Access control: `kSecAttrAccessibleWhenUnlocked`
- Never log or print keychain values, even at debug level

### File Permissions
- Vault files: user-only read/write (0600)
- Application support: user-only (0700)
- Plugin directories: user-only read/write, plugins cannot modify other plugin directories

### Agent Sandboxing
- Each agent runs with a defined `TerminalSandbox` level
- File access restricted to vault directory by default
- Network access disabled by default, enabled per-agent with user approval
- Command allowlist/blocklist per agent profile

### Network Request Audit
- **Local-first principle:** No outgoing network requests without explicit user action
- Exceptions: Git sync (user-initiated), plugin updates (user-initiated), AI API calls (if using cloud models, user-configured)
- `NetworkAuditLog.swift` — log all outgoing connections for transparency
- Setting to show notification on any network request

### Entitlements Minimization
```xml
<!-- Epistemos.entitlements -->
<key>com.apple.security.app-sandbox</key>              <true/>
<key>com.apple.security.files.user-selected.read-write</key> <true/>
<key>com.apple.security.network.client</key>            <true/>
<key>com.apple.security.device.gpu</key>                <true/>
<!-- Only add if terminal feature is enabled: -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
```

Review entitlements quarterly; remove any that are no longer needed.

---

# PART 7: PRIORITY MATRIX

All features scored by **Impact** (1-5, how much user value) and **Complexity** (1-5, engineering effort). **Priority Score** = Impact × 2 − Complexity. Higher score = higher priority.

| # | Feature Name | Source | Complexity | Impact | Priority Score | Wave | Dependencies |
|---|-------------|--------|-----------|--------|---------------|------|-------------|
| 1 | Tasks (full task management) | Obsidian | 5 | 5 | 5 | 1 | SDPage, editor |
| 2 | Templater (template engine) | Obsidian | 4 | 5 | 6 | 1 | SDPage |
| 3 | Periodic Notes (daily/weekly/monthly) | Obsidian | 2 | 5 | 8 | 1 | TemplateEngine |
| 4 | Calendar Sidebar | Obsidian | 2 | 4 | 6 | 1 | PeriodicNotes |
| 5 | Kanban Board | Obsidian | 3 | 4 | 5 | 1 | SDPage |
| 6 | Dataview (query engine) | Obsidian | 4 | 5 | 6 | 1 | QueryAST, SDPage |
| 7 | Smart Connections Sidebar | Obsidian | 1 | 4 | 7 | 1 | HNSW (exists) |
| 8 | Inline AI Completions | Obsidian | 2 | 4 | 6 | 1 | LLMService (exists) |
| 9 | Prompt Library | Obsidian | 1 | 3 | 5 | 1 | LLMService (exists) |
| 10 | Focus Mode | Obsidian | 1 | 3 | 5 | 1 | Window mgmt |
| 11 | Typewriter Mode | Obsidian | 1 | 3 | 5 | 1 | TextKit 2 |
| 12 | Reading Time | Obsidian | 1 | 2 | 3 | 1 | None |
| 13 | Breadcrumbs | Obsidian | 1 | 3 | 5 | 1 | SDPage.properties |
| 14 | Recent Files | Obsidian | 1 | 3 | 5 | 1 | SDPage |
| 15 | Writing Goals | Obsidian | 1 | 2 | 3 | 1 | Editor word count |
| 16 | Linter (note auto-format) | Obsidian | 2 | 4 | 6 | 2 | Editor, markdown parser |
| 17 | Advanced Tables | Obsidian | 4 | 4 | 4 | 2 | TextKit 2 |
| 18 | QuickAdd (macros) | Obsidian | 3 | 4 | 5 | 2 | TemplateEngine, commands |
| 19 | Iconize | Obsidian | 2 | 3 | 4 | 2 | SDPage, SDFolder |
| 20 | Tag Wrangler | Obsidian | 2 | 3 | 4 | 2 | SDTag |
| 21 | Natural Language Dates | Obsidian | 2 | 3 | 4 | 2 | NSDataDetector |
| 22 | Hover Preview | Obsidian | 2 | 3 | 4 | 2 | SDPage, editor |
| 23 | Supercharged Links | Obsidian | 2 | 3 | 4 | 2 | SDPage.properties |
| 24 | Version History UI | Obsidian | 2 | 3 | 4 | 2 | SDPageVersion (exists) |
| 25 | AI Card Generator | Obsidian | 2 | 4 | 6 | 2 | FSRSEngine, LLMService |
| 26 | Flashcard Review UI | Obsidian | 1 | 4 | 7 | 2 | FSRSEngine (exists) |
| 27 | Commander (toolbar customization) | Obsidian | 2 | 2 | 2 | 2 | NSToolbar |
| 28 | Tab Bar (multi-tab editor) | Logseq | 2 | 4 | 6 | 2 | Window mgmt |
| 29 | Auto Linker | Logseq | 2 | 3 | 4 | 2 | SDPage title index |
| 30 | TODO Workflow Keywords | Logseq | 1 | 3 | 5 | 2 | TaskManager |
| 31 | Git Sync | Obsidian | 4 | 4 | 4 | 3 | Shell access |
| 32 | Terminal Emulator | Obsidian/Original | 4 | 4 | 4 | 3 | SwiftTerm |
| 33 | Shell Commands from Notes | Obsidian | 3 | 3 | 3 | 3 | Terminal, editor |
| 34 | Code Block Execution | Original | 3 | 4 | 5 | 3 | Terminal, editor |
| 35 | Database Table View | Notion | 3 | 5 | 7 | 3 | SDPage.properties |
| 36 | Database Board View | Notion | 2 | 4 | 6 | 3 | KanbanView |
| 37 | Database Calendar View | Notion | 2 | 3 | 4 | 3 | CalendarSidebar |
| 38 | DB Folder | Obsidian | 3 | 3 | 3 | 3 | SDPage.properties |
| 39 | Metadata Menu (property schemas) | Obsidian | 3 | 3 | 3 | 3 | SDPage.properties |
| 40 | Charts | Obsidian | 2 | 3 | 4 | 3 | Swift Charts |
| 41 | Mermaid Diagrams | Obsidian | 3 | 3 | 3 | 3 | WKWebView |
| 42 | Zotero Integration | Obsidian | 3 | 4 | 5 | 3 | SQLite |
| 43 | PDF Annotation | Obsidian | 4 | 4 | 4 | 3 | PDFKit |
| 44 | Highlight Importer | Obsidian | 2 | 3 | 4 | 3 | SQLite, REST |
| 45 | OCR Indexer | Obsidian | 2 | 3 | 4 | 3 | Vision framework |
| 46 | Relations Between Databases | Notion | 2 | 4 | 6 | 3 | Knowledge graph |
| 47 | Rollup Properties | Notion | 3 | 3 | 3 | 4 | Relations |
| 48 | Formula Properties | Notion | 4 | 4 | 4 | 4 | FormulaEngine |
| 49 | Timeline / Gantt View | Notion | 4 | 3 | 2 | 4 | Database system |
| 50 | Gallery View | Notion | 2 | 2 | 2 | 4 | Database system |
| 51 | Multiple Views Per Database | Notion | 2 | 4 | 6 | 4 | Database system |
| 52 | Automation Engine | Notion | 4 | 4 | 4 | 4 | SwiftData observers |
| 53 | Automation Builder UI | Notion | 3 | 3 | 3 | 4 | AutomationEngine |
| 54 | Custom Agents | Notion | 3 | 4 | 5 | 4 | AgentCoordinator |
| 55 | AI Autofill | Notion | 2 | 3 | 4 | 4 | LLMService |
| 56 | Excalidraw / Whiteboard | Obsidian/Logseq | 5 | 5 | 5 | 4 | Metal rendering |
| 57 | Mind Map | Obsidian | 2 | 3 | 4 | 4 | GraphEngine |
| 58 | Spatial Canvas | Obsidian | 4 | 4 | 4 | 4 | NSScrollView |
| 59 | Projects (multi-view) | Obsidian | 4 | 3 | 2 | 4 | Database views |
| 60 | Day Planner | Obsidian | 3 | 3 | 3 | 4 | PeriodicNotes, EventKit |
| 61 | Graph Analytics (Rust) | Obsidian | 4 | 3 | 2 | 5 | graph-engine crate |
| 62 | Extended Graph (images, shapes) | Obsidian | 3 | 3 | 3 | 5 | GraphEngine Metal |
| 63 | Path Finder | Obsidian | 2 | 2 | 2 | 5 | GraphAnalytics |
| 64 | Graph SVG Export | Obsidian | 2 | 2 | 2 | 5 | GraphEngine |
| 65 | Terminal Agent Integration | Original | 3 | 4 | 5 | 5 | Terminal, MCP |
| 66 | Terminal Sandboxing | Original | 3 | 3 | 3 | 5 | Terminal |
| 67 | Terminal History as Knowledge | Original | 2 | 2 | 2 | 5 | Terminal, FTS5 |
| 68 | Plugin SDK (Swift) | Original | 5 | 5 | 5 | 5 | All APIs |
| 69 | Plugin Manifest & Loader | Original | 3 | 4 | 5 | 5 | Plugin SDK |
| 70 | Plugin Marketplace | Original | 4 | 4 | 4 | 6 | Plugin SDK |
| 71 | Publish Service (Digital Garden) | Obsidian | 4 | 3 | 2 | 6 | Markdown parser, Git |
| 72 | HTML Export | Obsidian | 2 | 2 | 2 | 6 | Markdown parser |
| 73 | Pandoc Integration | Obsidian | 2 | 2 | 2 | 6 | Shell |
| 74 | Theme Customizer | Obsidian | 2 | 2 | 2 | 6 | Existing themes |
| 75 | Pixel Banner | Obsidian | 1 | 1 | 1 | 6 | SDPage.properties |
| 76 | Hider (UI customization) | Obsidian | 1 | 1 | 1 | 6 | Window layout |
| 77 | Block Types Extension | Notion | 3 | 3 | 3 | 6 | Editor, SDBlock |
| 78 | AI Blocks | Notion | 2 | 3 | 4 | 6 | LLMService, SDBlock |
| 79 | Comments & Discussions | Notion | 3 | 3 | 3 | 7 | SDBlock |
| 80 | Connectors (GitHub, Slack, etc.) | Notion | 5 | 4 | 3 | 7 | OAuth2, MCP |
| 81 | Annotator (EPUB/HTML) | Obsidian | 3 | 2 | 1 | 7 | WKWebView |
| 82 | SSH Connection Manager | Original | 3 | 2 | 1 | 7 | Terminal |
| 83 | Datalog Query Engine | Logseq | 5 | 2 | -1 | 7 | QueryAST |
| 84 | REPL Integration | Original | 2 | 2 | 2 | 7 | Terminal |
| 85 | Script Library | Original | 2 | 2 | 2 | 7 | Terminal |
| 86 | Epistemos CLI | Logseq | 2 | 3 | 4 | 7 | Swift ArgumentParser |
| 87 | CRDT Collaboration | Notion | 5 | 5 | 5 | 8 | Loro, WebSocket server |
| 88 | Permissions (RBAC) | Notion | 3 | 3 | 3 | 8 | Collaboration |
| 89 | Plugin SDK (JS/TS) | Original | 5 | 3 | 1 | 8 | WKWebView bridge |
| 90 | Plugin SDK (Python) | Original | 3 | 3 | 3 | 8 | Python bridge |

---

# APPENDICES

---

## Appendix A: Complete Obsidian Plugin Catalog

| # | Plugin | Category | Est. Downloads | GitHub URL |
|---|--------|----------|---------------|-----------|
| 1 | Excalidraw | Visualization | 5,600,000+ | [zsviczian/obsidian-excalidraw-plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin) |
| 2 | Templater | Editor | 5,000,000+ | [SilentVoid13/Templater](https://github.com/SilentVoid13/Templater) |
| 3 | Dataview | Data & Query | 4,500,000+ | [blacksmithgu/obsidian-dataview](https://github.com/blacksmithgu/obsidian-dataview) |
| 4 | Tasks | Task Management | 3,500,000+ | [obsidian-tasks-group/obsidian-tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) |
| 5 | Advanced Tables | Editor | 3,500,000+ | [tgrosinger/advanced-tables-obsidian](https://github.com/tgrosinger/advanced-tables-obsidian) |
| 6 | Calendar | Task Management | 2,500,000+ | [liamcain/obsidian-calendar-plugin](https://github.com/liamcain/obsidian-calendar-plugin) |
| 7 | Git | Version Control | 2,500,000+ | [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git) |
| 8 | Kanban | Task Management | 2,500,000+ | [mgmeyers/obsidian-kanban](https://github.com/mgmeyers/obsidian-kanban) |
| 9 | Style Settings | UI & Theming | 2,000,000+ | [mgmeyers/obsidian-style-settings](https://github.com/mgmeyers/obsidian-style-settings) |
| 10 | Iconize | Navigation | 1,500,000+ | [FlorianWoworcel/obsidian-iconize](https://github.com/FlorianWoworcel/obsidian-iconize) |
| 11 | Copilot | AI | 1,500,000+ | [logancyang/obsidian-copilot](https://github.com/logancyang/obsidian-copilot) |
| 12 | Periodic Notes | Task Management | 1,500,000+ | [liamcain/obsidian-periodic-notes](https://github.com/liamcain/obsidian-periodic-notes) |
| 13 | QuickAdd | Editor | 1,500,000+ | [chhoumann/quickadd](https://github.com/chhoumann/quickadd) |
| 14 | Linter | Editor | 1,500,000+ | [platers/obsidian-linter](https://github.com/platers/obsidian-linter) |
| 15 | Smart Connections | AI | 1,000,000+ | [brianpetro/obsidian-smart-connections](https://github.com/brianpetro/obsidian-smart-connections) |
| 16 | Omnisearch | Navigation | 800,000+ | [scambier/obsidian-omnisearch](https://github.com/scambier/obsidian-omnisearch) |
| 17 | Natural Language Dates | Editor | 800,000+ | [argenos/nldates-obsidian](https://github.com/argenos/nldates-obsidian) |
| 18 | Tag Wrangler | Navigation | 700,000+ | [pjeby/tag-wrangler](https://github.com/pjeby/tag-wrangler) |
| 19 | Recent Files | Navigation | 600,000+ | [tgrosinger/recent-files-obsidian](https://github.com/tgrosinger/recent-files-obsidian) |
| 20 | Commander | Navigation | 500,000+ | [phibr0/obsidian-commander](https://github.com/phibr0/obsidian-commander) |
| 21 | Hover Editor | Navigation | 500,000+ | [nothingislost/obsidian-hover-editor](https://github.com/nothingislost/obsidian-hover-editor) |
| 22 | Text Generator | AI | 400,000+ | [nhaouari/obsidian-textgenerator-plugin](https://github.com/nhaouari/obsidian-textgenerator-plugin) |
| 23 | Hider | UI & Theming | 400,000+ | [kepano/obsidian-hider](https://github.com/kepano/obsidian-hider) |
| 24 | DB Folder | Data & Query | 350,000+ | [RafaelGB/obsidian-db-folder](https://github.com/RafaelGB/obsidian-db-folder) |
| 25 | Supercharged Links | Navigation | 350,000+ | [mdelobelle/obsidian_supercharged_links](https://github.com/mdelobelle/obsidian_supercharged_links) |
| 26 | Day Planner | Task Management | 300,000+ | [ivan-lednev/obsidian-day-planner](https://github.com/ivan-lednev/obsidian-day-planner) |
| 27 | Spaced Repetition | Academic | 300,000+ | [st3v3nmw/obsidian-spaced-repetition](https://github.com/st3v3nmw/obsidian-spaced-repetition) |
| 28 | Typewriter Mode | Editor | 300,000+ | [deathau/cm-typewriter-scroll-obsidian](https://github.com/deathau/cm-typewriter-scroll-obsidian) |
| 29 | Breadcrumbs | Navigation | 250,000+ | [SkepticMystic/breadcrumbs](https://github.com/SkepticMystic/breadcrumbs) |
| 30 | Metadata Menu | Data & Query | 250,000+ | [mdelobelle/metadatamenu](https://github.com/mdelobelle/metadatamenu) |
| 31 | Mind Map | Visualization | 250,000+ | [lynchjames/obsidian-mind-map](https://github.com/lynchjames/obsidian-mind-map) |
| 32 | Zotero / ZotLit | Academic | 250,000+ | [PKM-er/obsidian-zotlit](https://github.com/PKM-er/obsidian-zotlit) |
| 33 | Citations | Academic | 200,000+ | [hans/obsidian-citation-plugin](https://github.com/hans/obsidian-citation-plugin) |
| 34 | Shell Commands | Terminal | 200,000+ | [Taitava/obsidian-shellcommands](https://github.com/Taitava/obsidian-shellcommands) |
| 35 | Digital Garden | Publishing | 200,000+ | [oleeskild/obsidian-digital-garden](https://github.com/oleeskild/obsidian-digital-garden) |
| 36 | HTML Export | Publishing | 200,000+ | [KosmosisDire/obsidian-webpage-export](https://github.com/KosmosisDire/obsidian-webpage-export) |
| 37 | Version History | Version Control | 200,000+ | [kelszo/obsidian-file-diff](https://github.com/kelszo/obsidian-file-diff) |
| 38 | Focus Mode | Editor | 200,000+ | [ryanpcmcquen/obsidian-focus-mode](https://github.com/ryanpcmcquen/obsidian-focus-mode) |
| 39 | AI Anki Sync | AI | 200,000+ | [debanjandhar12/logseq-anki-sync](https://github.com/debanjandhar12/logseq-anki-sync) |
| 40 | Charts | Data & Query | 180,000+ | [phibr0/obsidian-charts](https://github.com/phibr0/obsidian-charts) |
| 41 | Projects | Data & Query | 150,000+ | [marcusolsson/obsidian-projects](https://github.com/marcusolsson/obsidian-projects) |
| 42 | PDF++ | Academic | 150,000+ | [RyotaUshio/obsidian-pdf-plus](https://github.com/RyotaUshio/obsidian-pdf-plus) |
| 43 | Annotator | Academic | 150,000+ | [elias-sundqvist/obsidian-annotator](https://github.com/elias-sundqvist/obsidian-annotator) |
| 44 | Pandoc | Publishing | 150,000+ | [OliverBalfour/obsidian-pandoc](https://github.com/OliverBalfour/obsidian-pandoc) |
| 45 | Extended Graph / Juggl | Graph | 150,000+ | [HEmile/juggl](https://github.com/HEmile/juggl) |
| 46 | Pixel Banner | UI & Theming | 100,000+ | [jparkerweb/obsidian-pixel-banner](https://github.com/jparkerweb/obsidian-pixel-banner) |
| 47 | Reading Time | Editor | 100,000+ | [avr/obsidian-reading-time](https://github.com/avr/obsidian-reading-time) |
| 48 | Reading Highlights | Academic | 100,000+ | Various |
| 49 | Graph Analysis | Graph | 100,000+ | [SkepticMystic/graph-analysis](https://github.com/SkepticMystic/graph-analysis) |
| 50 | Journey | Graph | 100,000+ | [alexobenauer/obsidian-journey](https://github.com/alexobenauer/obsidian-journey) |
| 51 | LLM Shortcut | AI | 100,000+ | Various |
| 52 | Writing Goals | Editor | 80,000+ | Various |
| 53 | Terminal | Terminal | 50,000+ | Various |

*Note: Download counts are estimates based on data from [Obsidian Stats](https://www.obsidianstats.com) and community plugin stats. Exact counts fluctuate.*

---

## Appendix B: Notion Feature Catalog

| # | Feature | Category | Ported Via |
|---|---------|----------|-----------|
| 1 | Table View | Database | DatabaseTableView.swift |
| 2 | Board View | Database | KanbanView.swift / DatabaseBoardView.swift |
| 3 | Calendar View | Database | DatabaseCalendarView.swift |
| 4 | Timeline View | Database | TimelineView.swift |
| 5 | Gallery View | Database | GalleryView.swift |
| 6 | List View | Database | DatabaseListView.swift |
| 7 | Chart View | Database | ChartBlockRenderer.swift |
| 8 | Relations | Database | SDRelation / Knowledge graph |
| 9 | Rollups | Database | RollupEvaluator.swift |
| 10 | Formulas | Database | FormulaEngine.swift |
| 11 | Filter/Sort/Group | Database | NSPredicate / NSSortDescriptor |
| 12 | Multiple Views | Database | SDDatabaseViewConfig.swift |
| 13 | Database Automations | Automation | AutomationEngine.swift |
| 14 | Recurring Triggers | Automation | SDRecurrenceRule |
| 15 | Automation Actions | Automation | SDAutomationAction |
| 16 | Notion Agent | AI | OmegaAgent (exists) |
| 17 | Custom Agents | AI | CustomAgentBuilder.swift |
| 18 | AI Autofill | AI | AIAutofillService.swift |
| 19 | AI Connectors | AI | ConnectorService.swift |
| 20 | Enterprise Search | AI | UnifiedSearchView.swift + HNSW |
| 21 | Real-time Editing | Collaboration | CollaborationService (future) |
| 22 | Comments | Collaboration | CommentService.swift |
| 23 | @Mentions | Collaboration | Mention autocomplete |
| 24 | Permissions (RBAC) | Collaboration | PermissionManager.swift (future) |
| 25 | Team Spaces | Collaboration | Future multi-user |
| 26 | Toggle Blocks | Blocks | ExtendedBlockTypes.swift |
| 27 | Callout Blocks | Blocks | ExtendedBlockTypes.swift |
| 28 | Synced Blocks | Blocks | ExtendedBlockTypes.swift |
| 29 | AI Blocks | Blocks | AIBlockView.swift |
| 30 | Template System | Blocks | TemplateEngine.swift |

---

## Appendix C: New Files to Create (Organized by Directory)

### Models/ (SwiftData)
```
Models/SDTask.swift
Models/SDRecurrenceRule.swift
Models/SDKanbanBoard.swift
Models/SDKanbanColumn.swift
Models/SDPropertySchema.swift
Models/SDDatabaseView.swift
Models/SDDatabaseViewConfig.swift
Models/SDTemplateRule.swift
Models/SDMacro.swift
Models/SDWritingGoal.swift
Models/SDCanvas.swift
Models/SDCanvasNode.swift
Models/SDSpatialCanvas.swift
Models/SDPDFAnnotation.swift
Models/SDAnnotation.swift
Models/SDPrompt.swift
Models/SDLinkStyleRule.swift
Models/SDThemeVariable.swift
Models/SDAutomation.swift
Models/SDAutomationTrigger.swift
Models/SDAutomationAction.swift
Models/SDCustomAgent.swift
Models/SDComment.swift
Models/SDTerminalEntry.swift
Models/SDConnector.swift
Models/ExtendedBlockTypes.swift
Models/PeriodicNoteConfig.swift
Models/TemplateContext.swift
Models/ChartDataModel.swift
Models/LintRule.swift
Models/LintConfiguration.swift
```

### Services/
```
Services/TaskManager.swift
Services/TaskQueryEngine.swift
Services/TemplateEngine.swift
Services/MacroSystem.swift
Services/PeriodicNotesService.swift
Services/DataviewService.swift
Services/NoteLinter.swift
Services/WritingGoalsService.swift
Services/InlineCompletionService.swift
Services/AICardGenerator.swift
Services/PromptLibrary.swift
Services/GitSyncService.swift
Services/VersionDiffService.swift
Services/ZoteroService.swift
Services/PDFHighlightExtractor.swift
Services/AnnotationService.swift
Services/HighlightImporter.swift
Services/IconManager.swift
Services/CommanderService.swift
Services/TagManager.swift
Services/AutoLinkerService.swift
Services/PublishService.swift
Services/DocumentConverter.swift
Services/ThemeCustomizer.swift
Services/AutomationEngine.swift
Services/CustomAgentBuilder.swift
Services/AIAutofillService.swift
Services/ConnectorService.swift
Services/CommentService.swift
Services/FormulaEngine.swift
Services/RollupEvaluator.swift
Services/FormulaEvaluator.swift
Services/PropertySchemaManager.swift
Services/ShellCommandService.swift
Services/CodeBlockRunner.swift
Services/VariableSubstitution.swift
Services/TerminalSessionManager.swift
Services/TerminalThemeAdapter.swift
Services/TerminalSandbox.swift
Services/TerminalOutputParser.swift
Services/OCRIndexer.swift
Services/GraphAnalyticsService.swift
Services/TabManager.swift
```

### Views/
```
Views/TaskAggregateView.swift
Views/KanbanView.swift
Views/DayPlannerView.swift
Views/CalendarSidebarView.swift
Views/FlashcardReviewView.swift
Views/FlashcardDeckView.swift
Views/SmartConnectionsSidebar.swift
Views/InlineChatPopover.swift
Views/MindMapView.swift
Views/GitDiffView.swift
Views/GitHistoryView.swift
Views/VersionHistoryView.swift
Views/ZoteroSearchView.swift
Views/PDFAnnotationView.swift
Views/EPUBReaderView.swift
Views/IconPickerView.swift
Views/ToolbarEditorView.swift
Views/UnifiedSearchView.swift
Views/TagHierarchyView.swift
Views/NotePreviewPopover.swift
Views/BreadcrumbView.swift
Views/RecentFilesView.swift
Views/NoteBannerView.swift
Views/GraphStatisticsView.swift
Views/PathFinderView.swift
Views/WritingGoalBadge.swift
Views/ThemeCustomizerView.swift
Views/AutomationBuilderView.swift
Views/CommentThreadView.swift
Views/TabBarView.swift
Views/TerminalHistoryView.swift

Views/Canvas/CanvasView.swift
Views/Canvas/CanvasElement.swift
Views/Canvas/CanvasRenderer.swift
Views/Canvas/BezierPathStylizer.swift
Views/Canvas/SVGExporter.swift

Views/SpatialCanvasView.swift

Views/Database/DatabaseTableView.swift
Views/Database/DatabaseFolderView.swift
Views/Database/TimelineView.swift
Views/Database/GalleryView.swift

Views/Project/ProjectView.swift
Views/Project/ProjectBoardView.swift
Views/Project/ProjectCalendarView.swift
Views/Project/ProjectGalleryView.swift
Views/Project/ProjectTableView.swift

Views/Blocks/ToggleBlockView.swift
Views/Blocks/CalloutBlockView.swift
Views/Blocks/SyncedBlockView.swift
Views/Blocks/AIBlockView.swift

Views/Shell/TerminalView.swift
Views/Shell/TerminalTabBar.swift
Views/Shell/TerminalSplitView.swift
Views/Shell/REPLView.swift
```

### Editor/
```
Editor/TableEditorComponent.swift
Editor/TableCSVExporter.swift
Editor/TableFormulaEvaluator.swift
Editor/TypewriterScrollMode.swift
Editor/TaskCheckboxRenderer.swift
Editor/GhostTextRenderer.swift
Editor/StyledLinkRenderer.swift
Editor/ExecutableCodeBlockRenderer.swift
```

### Parsers/
```
Parsers/DQLParser.swift
Parsers/TemplateParser.swift
Parsers/NaturalDateParser.swift
Parsers/TimeBlockParser.swift
Parsers/BibTeXParser.swift
Parsers/CSLJSONParser.swift
Parsers/FormulaParser.swift
Parsers/MermaidParser.swift
Parsers/DatalogParser.swift
```

### Renderers/
```
Renderers/MermaidRenderer.swift
Renderers/ChartBlockRenderer.swift
```

### Converters/
```
Converters/MarkdownToHTMLConverter.swift
```

### Export/
```
Export/HTMLExporter.swift
Export/AnkiExporter.swift
```

### Importers/
```
Importers/KindleClippingsParser.swift
Importers/AppleBooksImporter.swift
```

### Graph/
```
Graph/GraphSVGExporter.swift
graph-engine/src/analytics.rs  (Rust)
```

### Layout/
```
Layout/TreeLayoutAlgorithm.swift
```

### Utilities/
```
Utilities/ReadingTimeCalculator.swift
Utilities/IconResolver.swift
```

### Modifiers/
```
Modifiers/FocusModeModifier.swift
Modifiers/HoverPreviewModifier.swift
```

### Settings/
```
Settings/UICustomizationSettings.swift
```

### MCP/Tools/
```
MCP/Tools/TerminalExecuteTool.swift
```

### Connectors/
```
Connectors/GitHubConnector.swift
Connectors/SlackConnector.swift
Connectors/GoogleDriveConnector.swift
```

### ViewModels/
```
ViewModels/DatabaseFolderViewModel.swift
```

### CLI/
```
CLI/EpistemosCLI.swift
```

### Plugin SDK (separate package)
```
EpistemosPluginSDK/Sources/
  EpistemosPlugin.swift
  PluginManifest.swift
  PluginContext.swift
  NotesAPI.swift
  SearchAPI.swift
  UIAPI.swift
  SettingsAPI.swift
  EventsAPI.swift
  GraphAPI.swift
  AIAPI.swift
  TerminalAPI.swift
```

**Total new files: ~160+**

---

## Appendix D: Implementation Timeline (8 Waves)

### Wave 1 — Foundation (Weeks 1-4)
**Focus:** Core productivity features that users expect day-one.
- Tasks (full task management system)
- Template Engine + Periodic Notes
- Calendar Sidebar
- Kanban Board
- Dataview (query engine)
- Smart Connections Sidebar
- Inline AI Completions + Prompt Library
- Focus Mode + Typewriter Mode
- Breadcrumbs + Recent Files + Reading Time + Writing Goals
- **Deliverable:** 15 features, ~25 new files

### Wave 2 — Editor & Polish (Weeks 5-8)
**Focus:** Editor enhancements and remaining quick wins.
- Linter (auto-format)
- Advanced Tables
- QuickAdd (macros)
- Iconize + Tag Wrangler
- Natural Language Dates
- Hover Preview + Supercharged Links
- Version History UI
- AI Card Generator + Flashcard Review UI
- Tab Bar (multi-tab editor)
- Auto Linker + TODO Workflow Keywords
- Commander (toolbar customization)
- **Deliverable:** 14 features, ~30 new files

### Wave 3 — Data & Research (Weeks 9-12)
**Focus:** Database views, academic tools, and terminal foundation.
- Database Table View + Board View + Calendar View
- DB Folder + Metadata Menu (property schemas)
- Relations Between Databases
- Charts + Mermaid Diagrams
- Zotero Integration + PDF Annotation
- Highlight Importer + OCR Indexer
- Terminal Emulator (SwiftTerm integration)
- Shell Commands from Notes + Code Block Execution
- Git Sync
- **Deliverable:** 16 features, ~35 new files

### Wave 4 — Advanced Features (Weeks 13-16)
**Focus:** Complex features building on Wave 1-3 infrastructure.
- Rollup Properties + Formula Properties
- Timeline/Gantt View + Gallery View + Multiple Views Per Database
- Automation Engine + Automation Builder UI
- Custom Agents + AI Autofill
- Excalidraw / Whiteboard (Canvas)
- Mind Map + Spatial Canvas
- Projects (multi-view) + Day Planner
- **Deliverable:** 13 features, ~30 new files

### Wave 5 — Intelligence & SDK (Weeks 17-20)
**Focus:** Graph analytics, terminal intelligence, and plugin SDK foundation.
- Graph Analytics (Rust: PageRank, centrality, community detection)
- Extended Graph (images, shapes, SVG export)
- Path Finder + Graph Statistics
- Terminal Agent Integration + Sandboxing
- Terminal History as Knowledge
- Plugin SDK (Swift Packages) — API surface, manifest, loader
- **Deliverable:** 8 features, ~20 new files

### Wave 6 — Publishing & Ecosystem (Weeks 21-24)
**Focus:** Output, sharing, and ecosystem foundations.
- Plugin Marketplace (registry, install/update/uninstall)
- Publish Service (Digital Garden / Quartz equivalent)
- HTML Export + Pandoc Integration
- Theme Customizer
- Block Types Extension (toggle, callout, synced blocks, AI blocks)
- Pixel Banner + Hider (UI customization)
- **Deliverable:** 9 features, ~15 new files

### Wave 7 — Integration & Extended (Weeks 25-30)
**Focus:** External integrations and extended features.
- AI Connectors (GitHub, Slack, Google Drive)
- Comments & Discussions
- Annotator (EPUB/HTML)
- SSH Connection Manager
- REPL Integration + Script Library
- Epistemos CLI
- Datalog Query Engine (advanced)
- **Deliverable:** 8 features, ~15 new files

### Wave 8 — Collaboration (Weeks 31-40)
**Focus:** Multi-user capabilities.
- CRDT Collaboration (Loro integration)
- Real-time multiplayer editing
- Permissions (7-tier RBAC)
- Team Spaces
- Plugin SDK (JavaScript/TypeScript bridge)
- Plugin SDK (Python bridge)
- **Deliverable:** 6 features, ~20 new files

---

**Total estimated timeline:** 40 weeks (10 months) for full feature parity with Obsidian + Notion + Logseq combined ecosystem.

**Parallel tracks recommended:**
- Track A: Editor/UI features (Waves 1-2)
- Track B: Data/Backend features (Waves 1-3)
- Track C: AI/Agent features (Waves 1, 4-5)
- Track D: Terminal features (Wave 3, 5)
- Track E: SDK/Ecosystem (Waves 5-8)

With 3-4 parallel engineering tracks, the 40-week timeline can compress to **20-25 weeks**.

---

*End of specification. This document should be treated as a living document — update as features are implemented, new plugins emerge, or priorities shift based on user feedback.*
