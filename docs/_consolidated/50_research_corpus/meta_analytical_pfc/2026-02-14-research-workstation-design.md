# Brainiac Research Workstation Design

> Transforms Brainiac from a chat-with-notes app into a full research workstation.
> Four interconnected features under one Integrated Workspace architecture.

**Date:** 2026-02-14
**Approach:** Integrated Workspace (shared data layer, panel manager, cross-feature connections)

---

## Table of Contents

1. [Embedded Chat System](#1-embedded-chat-system)
2. [Writer Mode for Notes](#2-writer-mode-for-notes)
3. [Research Hub](#3-research-hub)
4. [Consensus Engine](#4-consensus-engine)
5. [Data Model Summary](#5-data-model-summary)
6. [Integration Map](#6-integration-map)

---

## 1. Embedded Chat System

The core integration mechanism. Chats are draggable, embeddable, and context-aware.

### Interaction Model

1. User has a mini-chat open with a conversation
2. User drags the mini-chat toward a note in the block editor
3. A drop zone appears: "Drop to embed"
4. On drop: the chat embeds inline as a special block in the note
5. While embedded, the chat becomes a **brain for that note** -- its system prompt includes the note's content as context
6. Multiple chats can be embedded in one note
7. To detach: drag the embedded chat out, or click "Detach" -- it returns to a floating mini-chat, loses note context
8. Embedded chats persist across sessions (SQLite)

### Inline Visual

```
# My Research Note

Some markdown content here...

+-- Research Chat --------------------------------+
| You: What papers support this claim?            |
| AI: Based on your note, here are 3 relevant     |
|     studies...                                   |
| [message input]                                  |
|                                   [Detach icon]  |
+--------------------------------------------------+

More note content below...
```

### Chat Purposes

Each chat thread (whether floating or embedded) can be set to a purpose preset:

| Purpose | System Prompt Focus | Icon |
|---------|-------------------|------|
| **Research** | Citation finding, evidence analysis, Semantic Scholar queries | magnifying glass |
| **Writing** | Prose improvement, style suggestions, continuation | pen |
| **Creativity** | Brainstorming, ideation, divergent thinking, no constraints | lightbulb |
| **General** | Standard assistant behavior | chat bubble |

Purpose is selected when creating a thread or changed from the thread dropdown.

### Data Model

```typescript
// New block type in NoteBlock
type BlockType = 'text' | 'heading' | 'list' | 'code' | 'chat-embed'

// Chat embed block stores the thread reference
interface ChatEmbedBlock extends NoteBlock {
  type: 'chat-embed'
  properties: {
    threadId: string    // references ChatThread.id
    purpose: ChatPurpose
  }
}

type ChatPurpose = 'research' | 'writing' | 'creativity' | 'general'

// ChatThread gets new optional fields
interface ChatThread {
  // ...existing fields
  purpose?: ChatPurpose
  embeddedInPageId?: string | null  // null when floating
  embeddedInBlockId?: string | null
}
```

### Mini-Chat Changes

- Mini-chat tabs get a 📌 badge when the thread is embedded in a note
- Navigating to a note with embedded chats: mini-chat auto-opens and shows those threads
- Thread dropdown: "Pin to current note" option (embeds at cursor position)
- Drag handle on mini-chat title bar enables drag-to-embed

---

## 2. Writer Mode for Notes

### Dual-Mode Toggle

Top of notes page, prominent toggle:

```
[ Notes Mode ] <--> [ Writer Mode ]
```

### Notes Mode (Enhanced Current)

Block editor, slash commands, `[[links]]`, canvas -- everything as-is.

**Sub-toggle:** Markdown (default) | Plain Text (.txt)

- **Markdown:** Full block editor with formatting toolbar, slash commands, links
- **Plain Text (.txt):** Monospace font (SF Mono / Menlo), no formatting toolbar, no slash commands, raw text editing. Different background tint for visual distinction. Good for code notes, logs, quick capture.

### Writer Mode (New -- Ulysses Clone)

Block editor disappears. Replaced with a clean, full-width document editor.

**Format Presets** (cycled via dropdown in minimal toolbar):

| Preset | Font | Size | Line Height | Max Width | Background |
|--------|------|------|-------------|-----------|------------|
| Freewrite | SF Pro / system | 16px | 1.6 | max-w-2xl | default |
| Academic | Times New Roman | 14px | 2.0 (double) | max-w-3xl | warm white |
| Manuscript | Courier New | 13px | 2.0 | max-w-3xl | cream (#FFF8E7) |
| Novel | Georgia | 15px | 1.8 | max-w-xl | parchment (#F5F0E8) |
| Minimal | Inter | 15px | 1.5 | max-w-lg | pure white |

**Switching format instantly changes the entire screen.** No transition animation -- just snap to the new aesthetic. The writing environment becomes that format immediately.

**Writer Mode toolbar** (minimal):
- Format picker (dropdown)
- Word count
- Save status indicator
- Focus mode toggle (iA Writer style: dims all paragraphs except current)
- Exit to Notes Mode

### Persistence

Mode and format selection stored **per-page** in page metadata:

```typescript
interface PageMetadata {
  // ...existing
  editorMode?: 'notes' | 'writer'
  writerFormat?: 'freewrite' | 'academic' | 'manuscript' | 'novel' | 'minimal'
  notesSubMode?: 'markdown' | 'plaintext'
}
```

Each note remembers its last mode and format.

---

## 3. Research Hub

Dedicated `/research` route for discovery, saving, and organizing research papers.

### Layout: Three-Pane

```
+-------------+----------------------+---------------------+
| Library     | Paper Detail         | Discovery Graph     |
| (sidebar)   | (center)             | (right)             |
|             |                      |                     |
| Collections |  Title, abstract,    | Citation network    |
|  > ML       |  authors, year       | (D3 force-directed) |
|  > Climate  |  Key findings (LLM)  |                     |
|  > Saved    |  Your notes          | Click node -> loads |
|             |  Related papers      | in center pane      |
| Recent      |  Consensus summary   |                     |
| Trending    |                      |                     |
+-------------+----------------------+---------------------+
```

### Left -- Library Sidebar

- **Collections:** User-created folders for organizing papers
- **Recent:** Last 20 papers viewed
- **Saved:** Quick-bookmarked papers
- **Search:** Searches Semantic Scholar live + local library
- **Import:** Paste DOI or URL to add a paper

### Center -- Paper Detail

- Full metadata: title, authors, year, venue, citation count
- Abstract
- Key findings: LLM-summarized (cached after first generation)
- User notes: inline editing, auto-saves
- Related papers: from Semantic Scholar references/citations
- Consensus badge: if consensus analysis exists for this topic, shows summary
- Actions: Save to collection, Open PDF (if open access), Export BibTeX, Run consensus, Pin chat

### Right -- Discovery Graph

- Force-directed citation network (reuses D3 from concept atlas)
- Center node = current paper
- Edges = citations (blue) and references (green)
- Gold highlight = papers in your library
- Click node -> loads in center pane
- Zoom/pan interaction model from concept atlas

### Data Model

```typescript
interface ResearchCollection {
  id: string
  name: string
  description?: string
  paperIds: string[]
  createdAt: number
  updatedAt: number
}

interface SavedPaper {
  id: string               // paperId from Semantic Scholar
  title: string
  authors: string[]
  year: number
  venue: string
  abstract: string
  citationCount: number
  url?: string
  openAccessPdfUrl?: string
  notes: string            // user annotations
  collectionIds: string[]  // which collections
  savedAt: number
  consensusReportId?: string
  bibtex: string
  keyFindings?: string     // LLM-generated, cached
}
```

Extends existing `researchPapers` store and `semantic-scholar.ts` module.

---

## 4. Consensus Engine

Surfaces what the evidence says by aggregating across multiple papers.

### Trigger Points (Auto-Suggest + Manual)

1. **Manual:** "Find Consensus" pill in chat input. Click before sending -> query runs through consensus pipeline.
2. **Auto-suggest:** After research questions, AI includes a chip: "Want consensus analysis?" Click to run.
3. **From Research Hub:** "Run Consensus" button on any paper detail page.

### Pipeline

```
User Question
    |
    v
1. Query Decomposition
   Break into specific testable claims
    |
    v
2. Literature Search
   Semantic Scholar: 10-30 papers per claim
    |
    v
3. Evidence Extraction
   LLM reads abstracts/findings per paper:
   - Supporting evidence (with citation)
   - Contradicting evidence (with citation)
   - Inconclusive/mixed results
    |
    v
4. Consensus Scoring
   Per claim:
   - Strong consensus (>80% agreement)
   - Moderate consensus (60-80%)
   - Contested (<60%)
   - Insufficient evidence (<3 papers)
    |
    v
5. Synthesis
   LLM generates structured consensus report
```

### Consensus Report (Special Chat Message Type)

```
+-- Consensus Report --------------------------------+
| Topic: "Effects of intermittent fasting on         |
| cognitive performance"                             |
|                                                    |
| Overall: Moderate Consensus (68%)                  |
| Papers analyzed: 23                                |
|                                                    |
| Strong Consensus:                                  |
|   - IF improves insulin sensitivity (89%, 12/14)   |
|   - No negative effect on muscle mass (82%, 9/11)  |
|                                                    |
| Contested:                                         |
|   - Effect on working memory (54%, mixed)          |
|   - Long-term adherence rates (46%, conflicting)   |
|                                                    |
| Insufficient Evidence:                             |
|   - Impact on creativity (only 2 papers)           |
|                                                    |
| Key Sources: [expandable paper list]               |
| [Save to Research Hub]                             |
+----------------------------------------------------+
```

- Each claim expandable -> shows supporting/contradicting papers with quotes
- "Save to Research Hub" -> saves report + referenced papers to library
- Consensus summary appears on paper detail pages in Research Hub

### Data Model

```typescript
interface ConsensusReport {
  id: string
  query: string
  claims: ConsensusClaim[]
  overallScore: number           // 0-1
  overallLevel: ConsensusLevel
  papersAnalyzed: number
  paperIds: string[]
  createdAt: number
}

interface ConsensusClaim {
  claim: string
  supporting: EvidenceItem[]
  contradicting: EvidenceItem[]
  inconclusive: EvidenceItem[]
  score: number                  // 0-1
  level: ConsensusLevel
}

interface EvidenceItem {
  paperId: string
  quote: string
  relevance: number              // 0-1
}

type ConsensusLevel = 'strong' | 'moderate' | 'contested' | 'insufficient'
```

---

## 5. Data Model Summary

### New Database Tables

| Table | Purpose |
|-------|---------|
| `researchCollection` | User-created paper folders |
| `savedPaper` | Papers in user's library |
| `savedPaperCollection` | Many-to-many join |
| `consensusReport` | Saved consensus analyses |
| `consensusClaim` | Individual claims within a report |

### Modified Tables

| Table | Change |
|-------|--------|
| `noteBlock` | New type: `chat-embed` |
| `notePage` | New metadata: `editorMode`, `writerFormat`, `notesSubMode` |

### New Store Slices / Extensions

| Slice | New State |
|-------|-----------|
| `research` | `collections`, `savedPapers`, `consensusReports`, `activeCollection` |
| `notes` | Writer mode state, format selection |
| `ui` | ChatThread `purpose`, `embeddedInPageId` fields |

---

## 6. Integration Map

How the four features connect:

```
Mini-Chat <--drag-to-embed--> Notes (inline chat blocks)
    |                              |
    v                              v
Consensus Engine        Writer Mode (format presets)
    |                              |
    v                              |
Research Hub <----save reports------+
    |
    +----> Paper Detail <-- consensus badge
    +----> Discovery Graph (D3)
    +----> Collections (organize)
```

**Cross-feature flows:**

1. **Research in chat -> Hub:** Ask research question in chat -> consensus report -> "Save to Research Hub" -> papers added to library
2. **Hub -> Notes:** Found a great paper -> pin a chat to discuss it -> drag chat into a note -> chat becomes note-aware brain
3. **Notes -> Research:** Writing in Writer Mode -> embedded research chat auto-suggests consensus -> results flow to Research Hub
4. **Hub -> Chat:** From paper detail -> "Run Consensus" -> opens in chat with structured report

All four features share the Semantic Scholar integration, the LLM provider system, and the SQLite persistence layer.
