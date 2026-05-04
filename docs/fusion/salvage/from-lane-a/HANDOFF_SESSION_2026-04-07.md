# Session Handoff: Xcode-Style Editor + AI Partner Implementation

**Date:** 2026-04-07  
**Focus:** Code Editor Redesign, AI Coding Partner, Weighted Context Engine, Graph Inspector Fixes

---

## Executive Summary

This session implemented a comprehensive Xcode-style code editor redesign for Epistemos with:

1. **Xcode-Style Editor Design** - Collapsible outline, breadcrumb navigation, segmented indentation guides
2. **AI Coding Partner** - Inline suggestions, weighted context engine, retro styling
3. **Code Ask Bar** - Dual response modes (Focused/Inline) different from prose editor
4. **Graph Inspector Fix** - Code files show only preview (no editor) to prevent crashes

---

## 1. Xcode-Style Editor Design

### 1.1 Files Created

#### `OutlineNavigatorView.swift` (25KB)
- Collapsible outline view for headers (MARKs, #, ##, ###)
- Native macOS 26 sidebar styling
- Line number navigation
- Auto-expansion tracking

```swift
struct OutlineItem: Identifiable, Equatable {
    let title: String
    let type: OutlineItemType  // .markdownHeader, .markComment, .symbol
    let lineNumber: Int
    let level: Int
    var isExpanded: Bool = true
    var children: [OutlineItem] = []
}

struct OutlineNavigatorView: View {
    let items: [OutlineItem]
    let currentLine: Int
    let onSelect: (OutlineItem) -> Void
}
```

**Key Feature:** Auto-parses document structure and shows hierarchical navigation.

#### `EditorBreadcrumbBar.swift` (8.7KB)
- File > Class > Method breadcrumb navigation
- Shows current scope based on cursor position
- Navigation to specific lines

```swift
struct BreadcrumbItem {
    let title: String
    let icon: String
    let lineNumber: Int
    let type: BreadcrumbType  // .file, .folder, .symbol, .section
}

struct EditorBreadcrumbBar: View {
    let items: [BreadcrumbItem]
    let currentLine: Int
    let onSelect: (BreadcrumbItem) -> Void
}
```

#### `MinimapAnnotationsView.swift` (9.9KB)
- Inline header labels on minimap
- Section annotations with relative positioning

### 1.2 Segmented Indentation Guides

#### `SegmentedIndentationGuideView.swift` (11.5KB)

**Problem:** Old implementation drew continuous vertical lines through empty space.

**Solution:** VS Code-style segmented guides that only appear on lines with actual code.

```swift
final class SegmentedIndentationGuideView: NSView {
    var indentWidth: CGFloat = 16
    var lineHeight: CGFloat = 17
    
    // Draws segments only where code exists at that indent level
    private func drawIndentGuide(atX x: CGFloat, level: Int, ...) {
        var segments: [(startY: CGFloat, endY: CGFloat)] = []
        var currentStart: CGFloat?
        
        for info in lineInfos {
            let hasIndentAtLevel = info.indentLevel >= level && info.hasContent
            
            if hasIndentAtLevel {
                if currentStart == nil { currentStart = info.yPosition }
            } else {
                if let start = currentStart {
                    segments.append((startY: start, endY: info.yPosition - lineHeight/2))
                    currentStart = nil
                }
            }
        }
        // Draw segments with round caps
    }
}
```

**Visual Result:**
```
struct Example {          │  <- Line shows (has code)
                             (empty - no guide)
    let x = 5            │  <- Line shows
    func test() {        │  <- Line shows
        print("hi")      │  │  <- Nested line
    }                    │  <- Line shows
}                        <- Line shows
```

**Apple-Native Styling:**
- `systemGray` at 20% opacity for inactive
- `accentColor` at 40% opacity for active level
- 1.0pt normal, 1.5pt active
- Small dots at block boundaries

---

## 2. AI Coding Partner System

### 2.1 Files Created

#### `AIPartnerService.swift` (Enhanced)

**Core Philosophy:** "Living specialist working alongside you"

```swift
@MainActor
final class AIPartnerService: ObservableObject {
    @Published var configuration: AIPartnerConfiguration
    @Published var currentSuggestion: InlineSuggestion?
    @Published var activeContextHighlights: [ContextHighlight]
    @Published var partnerStatus: PartnerStatus  // .idle, .reading, .analyzing, .weighting, .suggesting
    
    // NEW: Weighted context insights
    @Published var currentComplexity: CodeComplexityAnalyzer.ComplexityScore?
    @Published var topWeightedMatches: [WeightedSemanticMatch]
    @Published var contextInsights: ContextInsights?
}
```

**Status Flow:**
1. `idle` → `reading` (gathering context)
2. `reading` → `analyzing` (complexity analysis)
3. `analyzing` → `weighting` (graph weighting)
4. `weighting` → `suggesting` (generating response)

#### `AIPartnerInlineView.swift` (19.8KB)

**Components:**
- `InlineSuggestionOverlay` - Modern suggestion UI with confidence indicators
- `RetroAIResponseBox` - Terminal/cyberpunk aesthetic option
- `GhostTextRenderer` - Native ghost text for inline completions
- `ContextHighlightView` - Visual indicators for AI-used context

```swift
struct InlineSuggestion: Identifiable {
    let text: String
    let type: SuggestionType  // .completion, .insertion, .replacement, .multiLine, .refactor
    let confidence: Double  // 0.0 to 1.0
    let context: SuggestionContext
}

struct InlineSuggestionOverlay: View {
    let suggestion: InlineSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    // Shows: type icon, code preview, confidence bar, actions
}
```

**Retro Styling Option:**
```swift
struct RetroAIResponseBox: View {
    // Purple/cyan gradient border
    // Terminal-style header: "AI PARTNER — ACTIVE"
    // Monospaced font
    // Neon glow effect
}
```

#### `AIPartnerControlPanel.swift` (21.1KB)

**Presets:**
```swift
enum Frequency: String, Codable {
    case calm = "Calm"           // 60s interval, 1 suggestion
    case balanced = "Balanced"   // 30s interval, 2 suggestions  
    case frequent = "Frequent"   // 10s interval, 3 suggestions
    case aggressive = "Aggressive" // 3s interval, 5 suggestions
}

enum InsightDepth: String, Codable {
    case surface = "Surface"       // 100 tokens
    case standard = "Standard"     // 500 tokens
    case deep = "Deep"            // 2000 tokens
    case exhaustive = "Exhaustive" // 8000 tokens
}
```

**Granular Controls (Manual Mode):**
- Suggestion frequency slider
- Insight depth slider
- Context window size (Narrow/Medium/Wide/Full)
- Weight sliders: Semantic (0-1), Recent Edits (0-1), Vault Graph (0-1)
- Max concurrent suggestions (1-5)
- Context highlights toggle
- Retro styling toggle

### 2.2 Weighted Context Engine

#### `WeightedContextEngine.swift` (17.6KB)

**Core Innovation:** Uses Epistemos' graph weights for "uncanny" understanding.

```swift
struct WeightedSemanticMatch: Comparable {
    let nodeId: String
    let semanticScore: Float
    let nodeWeight: Double        // From graph
    let complexityScore: Double   // Alignment with current code
    let connectionStrength: Double // Graph connectivity
    let recencyScore: Double      // Time decay
    let finalScore: Double        // Weighted combination
}

struct WeightedContext {
    let query: String
    let codeContext: String
    let matches: [WeightedSemanticMatch]
    let summary: ContextSummary
    let complexity: CodeComplexityAnalyzer.ComplexityScore
    
    var routingRecommendation: RoutingRecommendation {
        if complexity.overallScore > 0.8 { return .deepAnalysis }
        else if complexity.overallScore > 0.5 { return .standard }
        else { return .quickSuggestion }
    }
}
```

**Weight Formula:**
```swift
finalScore =
    semanticScore * 0.35 +      // Semantic similarity
    nodeWeight * 0.25 +          // Graph node importance
    complexityAlignment * 0.20 + // Code complexity match
    connectionStrength * 0.15 +  // Graph connectivity
    recency * 0.05               // Time decay (30-day exp)
```

**Code Complexity Analysis:**
```swift
struct ComplexityScore {
    let cyclomaticComplexity: Int    // Branch counting
    let cognitiveComplexity: Int     // Nesting + branches
    let nestingDepth: Int
    let hasAsync: Bool
    let hasConcurrency: Bool
    let hasRecursion: Bool
    let overallScore: Double  // 0.0 to 1.0
}
```

**Usage in Prompt:**
```
Code Complexity Analysis:
- Overall Score: 75%
- Cyclomatic Complexity: 8
- Uses Async/Await
- Has Concurrency

Relevant Context from Vault (weighted):
[1] GPU Optimization Patterns ████████ 89%
Weight: 95% | Semantic: 92%
Use Accelerate framework for vector operations...
```

---

## 3. Code Ask Bar (Different from Prose Editor)

### 3.1 Key Difference

| Prose Editor (MD/TXT) | Code Editor |
|----------------------|-------------|
| AI responds at cursor | AI responds in focused panel OR inline highlights |
| Response appended to text | Response overlays on code |
| Simple text insertion | Context-aware annotations |
| No visual highlighting | Hoverable advice on specific lines |

### 3.2 Files Created

#### `CodeAskBar.swift` (19.2KB)

```swift
enum CodeAskBarResponseMode: String, Codable {
    case focused = "Focused"   // Blurred background + detailed panel
    case inline = "Inline"     // Highlights on code + hover tooltips
}

@MainActor
final class CodeAskBarService: ObservableObject {
    @Published var responseMode: CodeAskBarResponseMode = .focused
    @Published var focusedResponse: FocusedCodeResponse?
    @Published var showFocusedPanel = false
    @Published var inlineAnnotations: [InlineResponseAnnotation] = []
}
```

#### `FocusedResponsePanel.swift` (18.7KB)

**Features:**
- Blurred background overlay
- Section navigator sidebar
- Code blocks with copy/apply buttons
- Related code location chips
- Summary card at top

```swift
struct FocusedCodeResponse {
    let query: String
    let summary: String
    let sections: [ResponseSection]  // .explanation, .suggestion, .warning, .example
    let relatedCodeRanges: [NSRange]
}

struct FocusedResponsePanel: View {
    let response: FocusedCodeResponse
    let onDismiss: () -> Void
    let onApplyCode: (String) -> Void
    let onNavigateToLine: (Int) -> Void
}
```

#### `InlineResponseHighlighter.swift` (17.8KB)

```swift
struct InlineResponseAnnotation: Identifiable {
    let text: String
    let codeRange: NSRange
    let lineNumber: Int
    let type: AnnotationType  // .suggestion, .explanation, .warning, .optimization, .pattern
    let severity: Severity    // .info, .suggestion, .important
}

struct InlineResponseHighlighter: View {
    let annotations: [InlineResponseAnnotation]
    let code: String
    // Shows: Highlight overlays + hover tooltips
}
```

**Annotation Colors:**
- 🟡 Yellow: Suggestions
- 🔵 Blue: Explanations
- 🟠 Orange: Warnings
- 🟢 Green: Optimizations
- 🟣 Purple: Patterns from vault

### 3.3 UI Location

```swift
private var mainEditorPane: some View {
    VStack(spacing: 0) {
        breadcrumbBar
        editorWithSearch
        
        // Code Ask Bar (different from prose editor)
        if showAskBar {
            codeAskBarInput
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
        }
        
        statusBar
    }
}

private var codeAskBarInput: some View {
    CodeAskBarInput(
        query: $askBarQuery,
        responseMode: $askBarResponseMode,  // Focused | Inline toggle
        isQuerying: codeAskBar.isQuerying,
        onSubmit: { submitAskBarQuery() },
        onModeChange: { newMode in
            // Clear existing responses when switching modes
        }
    )
}
```

---

## 4. Graph Inspector Fix (Crash Prevention)

### 4.1 Problem
- Graph crashed when using editor preview for code files
- Code editor was being loaded in inspector panel

### 4.2 Solution

**File:** `HologramNodeInspector.swift`

```swift
// Added helper function
private func isCodeFile(pageId: String) -> Bool {
    let ext = (path as NSString).pathExtension.lowercased()
    // Code files: .swift, .rs, .py, etc.
    // NOT code files: .txt, .md, .markdown
    if ext == "txt" || ext == "md" || ext == "markdown" {
        return false
    }
    return CodeLanguage.detect(from: path) != nil
}

// Hide mode picker for code files
if node.type == .note, node.sourceId != nil, !isCodeFile(pageId: node.sourceId!) {
    modePicker  // Only show for prose files
}

// Code files: Show only Preview
if let lang = detectedCodeLanguage(pageId: pageId) {
    // Code file: Only show Preview, no Edit mode
    CodeInspectorPreview(content: editorText, language: lang, theme: theme)
}
```

### 4.3 Behavior

| File Type | Mode Picker | Editor View |
|-----------|-------------|-------------|
| .txt, .md | ✅ Profile \| Editor | ✅ Edit + Preview toggle |
| .swift, .rs, .py, etc. | ❌ Hidden | ✅ Preview only (read-only) |

---

## 5. Integration in CodeEditorView.swift

### 5.1 State Management

```swift
struct CodeEditorView: View {
    // MARK: - AI Coding Partner
    @StateObject private var aiPartner = AIPartnerService(...)
    @State private var aiPartnerConfiguration = AIPartnerConfiguration.default
    
    // MARK: - Code Ask Bar
    @StateObject private var codeAskBar = CodeAskBarService(...)
    @State private var askBarQuery = ""
    @AppStorage("codeEditor.askBarResponseMode") 
    private var askBarResponseMode: CodeAskBarResponseMode = .focused
    
    // MARK: - Outline Navigation
    @State private var outlineItems: [OutlineItem] = []
    @State private var showOutlineNavigator = false
}
```

### 5.2 Editor Content Stack

```swift
private var editorContent: some View {
    ZStack {
        HStack(spacing: 0) {
            mainEditorPane      // Breadcrumb + Editor + Ask Bar + Status
            outlineNavigator    // Right sidebar
            semanticSidebar     // AI sidebar
        }
        
        // Overlays
        aiPartnerOverlay           // Inline suggestions
        retroResponseBox           // Retro-styled AI responses
        codeAskBarFocusedPanel     // Blurred background + panel
        codeAskBarInlineHighlighter // Code annotations
    }
}
```

### 5.3 Status Bar Integration

```swift
private var statusBar: some View {
    HStack {
        // ... cursor position, search, etc.
        
        // AI Partner compact control
        AIPartnerCompactControl(configuration: $aiPartnerConfiguration) {
            showPartnerControlPanel = true
        }
        .popover(isPresented: $showPartnerControlPanel) {
            AIPartnerControlPanel(...)
        }
    }
}
```

---

## 6. Performance Optimizations

### 6.1 Indentation Guides
- Debounced scroll updates (50ms)
- Only redraw visible segments
- Dirty rect checking
- No Auto Layout constraints (uses autoresizingMask)

### 6.2 Weighted Context Engine
- GPU-accelerated semantic search (MetalComputeEngine)
- Batch cosine similarity
- Visible range optimization (±100 lines)
- LRU buffer cache

### 6.3 AI Partner
- Actor-based synchronization
- Throttled cursor updates (~60fps)
- Debounced analysis (1.5s for standard, 0.5s for aggressive)
- Task cancellation for rapid changes

### 6.4 Logging
- All interactions logged with:
  - Timestamp
  - Context metrics (node weights, complexity)
  - Performance metrics (duration, GPU usage)
  - Suggestion acceptance/dismissal
- Log rotation (max 1000 entries)

---

## 7. Native macOS 26 Feel

### 7.1 Visual Design
- `.ultraThinMaterial` for panels
- `.glassEffect()` for inspector
- Native sidebar styling (`listStyle(.sidebar)`)
- System colors (`.accentColor`, `.systemGray`)

### 7.2 Typography
```swift
// Breadcrumb
Text(title).font(.system(size: 12))

// Outline
Text(item.title).font(.system(size: 12))
Text("\(lineNumber)").font(.system(size: 10, design: .monospaced))

// Status Bar
Text("Ln \(cursorLine), Col \(cursorCol)")
    .font(.system(size: 11, design: .monospaced))
```

### 7.3 Animations
```swift
.transition(.move(edge: .trailing).combined(with: .opacity))
.animation(.spring(response: 0.35, dampingFraction: 0.85), ...)
.animation(.easeInOut(duration: 0.2), ...)
```

### 7.4 Haptics
- `NSHapticFeedbackManager` for suggestion presentation
- Level change feedback for AI responses

---

## 8. Files Created/Modified

### New Files (6)
1. `OutlineNavigatorView.swift` - Collapsible outline
2. `EditorBreadcrumbBar.swift` - Breadcrumb navigation
3. `MinimapAnnotationsView.swift` - Minimap labels
4. `SegmentedIndentationGuideView.swift` - VS Code-style indent guides
5. `AIPartnerInlineView.swift` - AI suggestion UI
6. `AIPartnerControlPanel.swift` - Control panel with presets
7. `AIPartnerService.swift` - AI partner engine
8. `WeightedContextEngine.swift` - Weighted context analysis
9. `CodeAskBar.swift` - Ask bar service
10. `FocusedResponsePanel.swift` - Focused response UI
11. `InlineResponseHighlighter.swift` - Inline annotations

### Modified Files (2)
1. `CodeEditorView.swift` - Main editor integration
2. `HologramNodeInspector.swift` - Graph inspector fix

---

## 9. Audit Checklist for Next Session

### 9.1 High-Signal Features (Priority)
- [ ] **Weighted Context Engine** - Verify node weights are being pulled from graph
- [ ] **Code Complexity Analysis** - Test on real complex files
- [ ] **Segmented Indent Guides** - Verify segments break on empty lines
- [ ] **AI Partner Presets** - Test all 4 presets (calm → aggressive)
- [ ] **Code Ask Bar Modes** - Verify both focused and inline modes work

### 9.2 Native Feel
- [ ] Colors match system appearance (light/dark mode)
- [ ] Fonts use system metrics
- [ ] Animations are smooth (no jank)
- [ ] Haptics work on supported hardware
- [ ] Glass effects render correctly

### 9.3 Performance
- [ ] Indent guides don't lag on scroll
- [ ] AI suggestions don't block UI
- [ ] Semantic search uses GPU
- [ ] Memory usage is reasonable (check for leaks)
- [ ] Log files don't grow unbounded

### 9.4 Crash Prevention
- [ ] Graph inspector doesn't crash on code files
- [ ] Code files show only preview (no edit mode)
- [ ] Mode picker hidden for code files

### 9.5 Edge Cases
- [ ] Empty files
- [ ] Very large files (>10K lines)
- [ ] Files with mixed indentation
- [ ] Files with no extensions
- [ ] Cursor at EOF

---

## 10. Known Limitations

1. **Ghost Text** - Not yet integrated with CodeEditSourceEditor's NSTextView
2. **Apply Suggestion** - Needs proper text range integration
3. **Go To Line** - Depends on CodeEditSourceEditor's API
4. **Outline Parser** - Simplified symbol detection (regex-based)

---

## 11. Extension Ideas

### High-Value Additions
1. **Real-time Collaboration** - Show other users' cursors
2. **Git Blame** - Inline blame annotations
3. **Code Folding** - Custom folding ranges
4. **Multi-cursor** - Sublime-style multi-selection
5. **Vim Mode** - Modal editing option

### AI Enhancements
1. **Test Generation** - Auto-generate tests from code
2. **Refactor Suggestions** - "Extract method" etc.
3. **Documentation** - Auto-generate doc comments
4. **Security Scan** - Find vulnerabilities
5. **Performance Profile** - Identify hot paths

---

**End of Handoff**
