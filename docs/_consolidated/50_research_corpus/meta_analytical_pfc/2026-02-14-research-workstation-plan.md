# Research Workstation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Brainiac into a full research workstation with embedded chats, writer mode, a research hub, and a consensus engine.

**Architecture:** Integrated Workspace — all four features share the Zustand store, SQLite via Drizzle ORM, Semantic Scholar API, and the LLM provider system. Cross-feature flows connect chat to notes to research hub to consensus.

**Tech Stack:** Next.js 16, React 19, TypeScript 5.9, Zustand 5, Drizzle ORM + SQLite, Tailwind CSS 4, Framer Motion, D3.js, Radix UI, AI SDK (Anthropic/OpenAI/Google)

**Design Doc:** `docs/plans/2026-02-14-research-workstation-design.md`

**Test Command:** `npm test` (Vitest 4 + happy-dom). Test files go in `pfc-app/tests/`.

---

## Task 1: Database Schema — New Tables

**Files:**
- Modify: `pfc-app/lib/db/schema.ts`
- Modify: `pfc-app/lib/db/index.ts` (if migration needed)
- Test: `pfc-app/tests/schema-research.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/schema-research.test.ts
import { describe, it, expect } from 'vitest'
import * as schema from '@/lib/db/schema'

describe('Research Workstation Schema', () => {
  it('exports researchCollection table', () => {
    expect(schema.researchCollection).toBeDefined()
  })
  it('exports savedPaper table', () => {
    expect(schema.savedPaper).toBeDefined()
  })
  it('exports savedPaperCollection join table', () => {
    expect(schema.savedPaperCollection).toBeDefined()
  })
  it('exports consensusReport table', () => {
    expect(schema.consensusReport).toBeDefined()
  })
  it('exports consensusClaim table', () => {
    expect(schema.consensusClaim).toBeDefined()
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/schema-research.test.ts`
Expected: FAIL — tables not yet defined

**Step 3: Add tables to schema**

Add to `pfc-app/lib/db/schema.ts` after the existing `notePageLink` table:

```typescript
// ── Research Workstation ──────────────────────────

export const researchCollection = sqliteTable('researchCollection', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  paperIds: text('paperIds', { mode: 'json' }).$type<string[]>().default([]),
  createdAt: integer('createdAt', { mode: 'timestamp_ms' }).notNull(),
  updatedAt: integer('updatedAt', { mode: 'timestamp_ms' }).notNull(),
})

export const savedPaper = sqliteTable('savedPaper', {
  id: text('id').primaryKey(), // S2 paperId
  title: text('title').notNull(),
  authors: text('authors', { mode: 'json' }).$type<string[]>().default([]),
  year: integer('year'),
  venue: text('venue'),
  abstract: text('abstract'),
  citationCount: integer('citationCount').default(0),
  url: text('url'),
  openAccessPdfUrl: text('openAccessPdfUrl'),
  notes: text('notes').default(''),
  collectionIds: text('collectionIds', { mode: 'json' }).$type<string[]>().default([]),
  savedAt: integer('savedAt', { mode: 'timestamp_ms' }).notNull(),
  consensusReportId: text('consensusReportId'),
  bibtex: text('bibtex').default(''),
  keyFindings: text('keyFindings'),
})

export const savedPaperCollection = sqliteTable('savedPaperCollection', {
  id: text('id').primaryKey(),
  paperId: text('paperId').notNull(),
  collectionId: text('collectionId').notNull(),
})

export const consensusReport = sqliteTable('consensusReport', {
  id: text('id').primaryKey(),
  query: text('query').notNull(),
  claims: text('claims', { mode: 'json' }).$type<ConsensusClaim[]>().default([]),
  overallScore: real('overallScore').default(0),
  overallLevel: text('overallLevel').$type<ConsensusLevel>().default('insufficient'),
  papersAnalyzed: integer('papersAnalyzed').default(0),
  paperIds: text('paperIds', { mode: 'json' }).$type<string[]>().default([]),
  createdAt: integer('createdAt', { mode: 'timestamp_ms' }).notNull(),
})

export const consensusClaim = sqliteTable('consensusClaim', {
  id: text('id').primaryKey(),
  reportId: text('reportId').notNull(),
  claim: text('claim').notNull(),
  supporting: text('supporting', { mode: 'json' }).$type<EvidenceItem[]>().default([]),
  contradicting: text('contradicting', { mode: 'json' }).$type<EvidenceItem[]>().default([]),
  inconclusive: text('inconclusive', { mode: 'json' }).$type<EvidenceItem[]>().default([]),
  score: real('score').default(0),
  level: text('level').$type<ConsensusLevel>().default('insufficient'),
})
```

Also add the TypeScript types near the top of the file (or in a shared types file):

```typescript
export type ConsensusLevel = 'strong' | 'moderate' | 'contested' | 'insufficient'

export interface EvidenceItem {
  paperId: string
  quote: string
  relevance: number
}

export interface ConsensusClaim {
  claim: string
  supporting: EvidenceItem[]
  contradicting: EvidenceItem[]
  inconclusive: EvidenceItem[]
  score: number
  level: ConsensusLevel
}
```

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/schema-research.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/lib/db/schema.ts pfc-app/tests/schema-research.test.ts
git commit -m "feat: add research workstation database tables (collections, papers, consensus)"
```

---

## Task 2: Shared Types — ChatPurpose, WriterFormat, ConsensusReport

**Files:**
- Create: `pfc-app/lib/types/research-workstation.ts`
- Test: `pfc-app/tests/research-workstation-types.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/research-workstation-types.test.ts
import { describe, it, expect } from 'vitest'
import {
  CHAT_PURPOSES,
  WRITER_FORMATS,
  CONSENSUS_LEVELS,
  type ChatPurpose,
  type WriterFormat,
  type EditorMode,
  type NotesSubMode,
} from '@/lib/types/research-workstation'

describe('Research Workstation Types', () => {
  it('defines 4 chat purposes', () => {
    expect(CHAT_PURPOSES).toHaveLength(4)
    expect(CHAT_PURPOSES).toContain('research')
    expect(CHAT_PURPOSES).toContain('writing')
    expect(CHAT_PURPOSES).toContain('creativity')
    expect(CHAT_PURPOSES).toContain('general')
  })

  it('defines 5 writer formats', () => {
    expect(WRITER_FORMATS).toHaveLength(5)
    expect(WRITER_FORMATS).toContain('freewrite')
    expect(WRITER_FORMATS).toContain('academic')
    expect(WRITER_FORMATS).toContain('manuscript')
    expect(WRITER_FORMATS).toContain('novel')
    expect(WRITER_FORMATS).toContain('minimal')
  })

  it('defines 4 consensus levels', () => {
    expect(CONSENSUS_LEVELS).toHaveLength(4)
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/research-workstation-types.test.ts`
Expected: FAIL — module not found

**Step 3: Create the types file**

```typescript
// pfc-app/lib/types/research-workstation.ts

// ── Chat Purpose ──────────────────────────────
export const CHAT_PURPOSES = ['research', 'writing', 'creativity', 'general'] as const
export type ChatPurpose = (typeof CHAT_PURPOSES)[number]

export const CHAT_PURPOSE_LABELS: Record<ChatPurpose, string> = {
  research: 'Research',
  writing: 'Writing',
  creativity: 'Creativity',
  general: 'General',
}

export const CHAT_PURPOSE_ICONS: Record<ChatPurpose, string> = {
  research: '🔍',
  writing: '✏️',
  creativity: '💡',
  general: '💬',
}

// ── Writer Mode ───────────────────────────────
export type EditorMode = 'notes' | 'writer'
export type NotesSubMode = 'markdown' | 'plaintext'

export const WRITER_FORMATS = ['freewrite', 'academic', 'manuscript', 'novel', 'minimal'] as const
export type WriterFormat = (typeof WRITER_FORMATS)[number]

export interface WriterFormatConfig {
  label: string
  fontFamily: string
  fontSize: string
  lineHeight: string
  maxWidth: string
  background: string       // CSS color or class
  backgroundDark: string   // Dark mode variant
}

export const WRITER_FORMAT_CONFIGS: Record<WriterFormat, WriterFormatConfig> = {
  freewrite: {
    label: 'Freewrite',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro", system-ui, sans-serif',
    fontSize: '16px',
    lineHeight: '1.6',
    maxWidth: '42rem',
    background: 'inherit',
    backgroundDark: 'inherit',
  },
  academic: {
    label: 'Academic',
    fontFamily: '"Times New Roman", "Times", Georgia, serif',
    fontSize: '14px',
    lineHeight: '2.0',
    maxWidth: '48rem',
    background: '#FFFDF5',
    backgroundDark: '#1a1a17',
  },
  manuscript: {
    label: 'Manuscript',
    fontFamily: '"Courier New", "Courier", monospace',
    fontSize: '13px',
    lineHeight: '2.0',
    maxWidth: '48rem',
    background: '#FFF8E7',
    backgroundDark: '#1a1812',
  },
  novel: {
    label: 'Novel',
    fontFamily: 'Georgia, "Times New Roman", serif',
    fontSize: '15px',
    lineHeight: '1.8',
    maxWidth: '32rem',
    background: '#F5F0E8',
    backgroundDark: '#1a1815',
  },
  minimal: {
    label: 'Minimal',
    fontFamily: '"Inter", -apple-system, system-ui, sans-serif',
    fontSize: '15px',
    lineHeight: '1.5',
    maxWidth: '28rem',
    background: '#FFFFFF',
    backgroundDark: '#111111',
  },
}

// ── Consensus Engine ──────────────────────────
export const CONSENSUS_LEVELS = ['strong', 'moderate', 'contested', 'insufficient'] as const
export type ConsensusLevel = (typeof CONSENSUS_LEVELS)[number]

export interface EvidenceItem {
  paperId: string
  quote: string
  relevance: number
}

export interface ConsensusClaim {
  claim: string
  supporting: EvidenceItem[]
  contradicting: EvidenceItem[]
  inconclusive: EvidenceItem[]
  score: number
  level: ConsensusLevel
}

export interface ConsensusReport {
  id: string
  query: string
  claims: ConsensusClaim[]
  overallScore: number
  overallLevel: ConsensusLevel
  papersAnalyzed: number
  paperIds: string[]
  createdAt: number
}

// ── Research Hub ──────────────────────────────
export interface ResearchCollection {
  id: string
  name: string
  description?: string
  paperIds: string[]
  createdAt: number
  updatedAt: number
}

export interface SavedPaper {
  id: string
  title: string
  authors: string[]
  year: number
  venue: string
  abstract: string
  citationCount: number
  url?: string
  openAccessPdfUrl?: string
  notes: string
  collectionIds: string[]
  savedAt: number
  consensusReportId?: string
  bibtex: string
  keyFindings?: string
}
```

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/research-workstation-types.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/lib/types/research-workstation.ts pfc-app/tests/research-workstation-types.test.ts
git commit -m "feat: add shared types for chat purposes, writer formats, consensus engine"
```

---

## Task 3: Research Slice Extension — Collections, Saved Papers, Consensus

**Files:**
- Modify: `pfc-app/lib/store/slices/research.ts`
- Test: `pfc-app/tests/store-research-hub.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/store-research-hub.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { usePFCStore } from '@/lib/store/use-pfc-store'

describe('Research Hub Store', () => {
  beforeEach(() => {
    localStorage.clear()
    usePFCStore.setState({
      researchCollections: [],
      savedPapers: [],
      consensusReports: [],
      activeCollectionId: null,
      activePaperId: null,
    })
  })

  it('creates a collection', () => {
    const { createCollection } = usePFCStore.getState()
    createCollection('ML Papers', 'Machine learning research')
    const { researchCollections } = usePFCStore.getState()
    expect(researchCollections).toHaveLength(1)
    expect(researchCollections[0]?.name).toBe('ML Papers')
  })

  it('saves a paper', () => {
    const { savePaper } = usePFCStore.getState()
    savePaper({
      id: 'test-paper-1',
      title: 'Test Paper',
      authors: ['Author A'],
      year: 2024,
      venue: 'NeurIPS',
      abstract: 'Abstract text',
      citationCount: 42,
      notes: '',
      collectionIds: [],
      savedAt: Date.now(),
      bibtex: '@article{test}',
    })
    const { savedPapers } = usePFCStore.getState()
    expect(savedPapers).toHaveLength(1)
    expect(savedPapers[0]?.title).toBe('Test Paper')
  })

  it('adds paper to collection', () => {
    const state = usePFCStore.getState()
    state.createCollection('My Papers')
    const collectionId = usePFCStore.getState().researchCollections[0]?.id ?? ''
    state.savePaper({
      id: 'paper-1', title: 'P1', authors: [], year: 2024, venue: '',
      abstract: '', citationCount: 0, notes: '', collectionIds: [],
      savedAt: Date.now(), bibtex: '',
    })
    usePFCStore.getState().addPaperToCollection('paper-1', collectionId)
    const paper = usePFCStore.getState().savedPapers[0]
    expect(paper?.collectionIds).toContain(collectionId)
  })

  it('saves a consensus report', () => {
    const { saveConsensusReport } = usePFCStore.getState()
    saveConsensusReport({
      id: 'report-1',
      query: 'Is coffee good?',
      claims: [],
      overallScore: 0.75,
      overallLevel: 'moderate',
      papersAnalyzed: 15,
      paperIds: [],
      createdAt: Date.now(),
    })
    const { consensusReports } = usePFCStore.getState()
    expect(consensusReports).toHaveLength(1)
    expect(consensusReports[0]?.overallLevel).toBe('moderate')
  })

  it('removes a paper', () => {
    const state = usePFCStore.getState()
    state.savePaper({
      id: 'paper-del', title: 'Delete Me', authors: [], year: 2024,
      venue: '', abstract: '', citationCount: 0, notes: '',
      collectionIds: [], savedAt: Date.now(), bibtex: '',
    })
    expect(usePFCStore.getState().savedPapers).toHaveLength(1)
    usePFCStore.getState().removeSavedPaper('paper-del')
    expect(usePFCStore.getState().savedPapers).toHaveLength(0)
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/store-research-hub.test.ts`
Expected: FAIL — state properties and actions not defined

**Step 3: Extend the research slice**

Modify `pfc-app/lib/store/slices/research.ts` — add new state and actions. Keep existing `researchPapers`, `currentCitations`, `pendingReroute`, `researchBooks` unchanged. Add:

```typescript
// New state
researchCollections: ResearchCollection[]
savedPapers: SavedPaper[]
consensusReports: ConsensusReport[]
activeCollectionId: string | null
activePaperId: string | null

// New actions
createCollection: (name: string, description?: string) => void
deleteCollection: (id: string) => void
renameCollection: (id: string, name: string) => void
savePaper: (paper: SavedPaper) => void
removeSavedPaper: (id: string) => void
updatePaperNotes: (id: string, notes: string) => void
addPaperToCollection: (paperId: string, collectionId: string) => void
removePaperFromCollection: (paperId: string, collectionId: string) => void
setActiveCollection: (id: string | null) => void
setActivePaper: (id: string | null) => void
saveConsensusReport: (report: ConsensusReport) => void
deleteConsensusReport: (id: string) => void
```

Import types from `@/lib/types/research-workstation`. Generate IDs with `crypto.randomUUID()`. Persist collections, savedPapers, and consensusReports to localStorage with `writeVersioned`.

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/store-research-hub.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/lib/store/slices/research.ts pfc-app/tests/store-research-hub.test.ts
git commit -m "feat: extend research slice with collections, saved papers, consensus reports"
```

---

## Task 4: UI Slice Extension — ChatPurpose, Embedded Thread Fields

**Files:**
- Modify: `pfc-app/lib/store/slices/ui.ts`
- Test: `pfc-app/tests/store-chat-purpose.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/store-chat-purpose.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { usePFCStore } from '@/lib/store/use-pfc-store'

describe('Chat Purpose & Embedding', () => {
  beforeEach(() => {
    localStorage.clear()
    usePFCStore.setState({ chatThreads: [], activeThreadId: '' })
  })

  it('creates a thread with purpose', () => {
    const { createThread } = usePFCStore.getState()
    createThread('assistant', 'Research Thread')
    usePFCStore.getState().setThreadPurpose(
      usePFCStore.getState().chatThreads[0]?.id ?? '',
      'research'
    )
    const thread = usePFCStore.getState().chatThreads[0]
    expect(thread?.purpose).toBe('research')
  })

  it('embeds a thread in a page', () => {
    const { createThread } = usePFCStore.getState()
    createThread('assistant', 'Embed Me')
    const threadId = usePFCStore.getState().chatThreads[0]?.id ?? ''
    usePFCStore.getState().embedThreadInPage(threadId, 'page-123', 'block-456')
    const thread = usePFCStore.getState().chatThreads[0]
    expect(thread?.embeddedInPageId).toBe('page-123')
    expect(thread?.embeddedInBlockId).toBe('block-456')
  })

  it('detaches a thread from a page', () => {
    const { createThread } = usePFCStore.getState()
    createThread('assistant', 'Detach Me')
    const threadId = usePFCStore.getState().chatThreads[0]?.id ?? ''
    usePFCStore.getState().embedThreadInPage(threadId, 'page-1', 'block-1')
    usePFCStore.getState().detachThread(threadId)
    const thread = usePFCStore.getState().chatThreads[0]
    expect(thread?.embeddedInPageId).toBeNull()
    expect(thread?.embeddedInBlockId).toBeNull()
  })

  it('finds threads embedded in a page', () => {
    const state = usePFCStore.getState()
    state.createThread('assistant', 'Thread A')
    state.createThread('assistant', 'Thread B')
    const threads = usePFCStore.getState().chatThreads
    usePFCStore.getState().embedThreadInPage(threads[0]?.id ?? '', 'page-x', 'block-a')
    usePFCStore.getState().embedThreadInPage(threads[1]?.id ?? '', 'page-x', 'block-b')
    const embedded = usePFCStore.getState().getThreadsForPage('page-x')
    expect(embedded).toHaveLength(2)
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/store-chat-purpose.test.ts`
Expected: FAIL

**Step 3: Add fields and actions to UI slice**

Extend `ChatThread` interface in `pfc-app/lib/store/slices/ui.ts`:

```typescript
interface ChatThread {
  // ...existing fields
  purpose?: ChatPurpose
  embeddedInPageId?: string | null
  embeddedInBlockId?: string | null
}
```

Add new actions:

```typescript
setThreadPurpose: (threadId: string, purpose: ChatPurpose) => void
embedThreadInPage: (threadId: string, pageId: string, blockId: string) => void
detachThread: (threadId: string) => void
getThreadsForPage: (pageId: string) => ChatThread[]
```

Import `ChatPurpose` from `@/lib/types/research-workstation`.

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/store-chat-purpose.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/lib/store/slices/ui.ts pfc-app/tests/store-chat-purpose.test.ts
git commit -m "feat: add chat purpose and thread embedding to UI slice"
```

---

## Task 5: Notes Slice Extension — Writer Mode State

**Files:**
- Modify: `pfc-app/lib/store/slices/notes.ts`
- Test: `pfc-app/tests/store-writer-mode.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/store-writer-mode.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { usePFCStore } from '@/lib/store/use-pfc-store'

describe('Writer Mode State', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('sets editor mode for a page', () => {
    const state = usePFCStore.getState()
    state.setPageEditorMode('page-1', 'writer')
    const mode = usePFCStore.getState().getPageEditorMode('page-1')
    expect(mode).toBe('writer')
  })

  it('defaults editor mode to notes', () => {
    const mode = usePFCStore.getState().getPageEditorMode('nonexistent')
    expect(mode).toBe('notes')
  })

  it('sets writer format for a page', () => {
    usePFCStore.getState().setPageWriterFormat('page-1', 'academic')
    const format = usePFCStore.getState().getPageWriterFormat('page-1')
    expect(format).toBe('academic')
  })

  it('defaults writer format to freewrite', () => {
    const format = usePFCStore.getState().getPageWriterFormat('nonexistent')
    expect(format).toBe('freewrite')
  })

  it('sets notes sub-mode', () => {
    usePFCStore.getState().setPageNotesSubMode('page-1', 'plaintext')
    const mode = usePFCStore.getState().getPageNotesSubMode('page-1')
    expect(mode).toBe('plaintext')
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/store-writer-mode.test.ts`
Expected: FAIL

**Step 3: Add writer mode state to notes slice**

Use the existing `NotePage.properties` field (already `Record<string, string>`) to store per-page mode preferences. Add actions to notes slice:

```typescript
setPageEditorMode: (pageId: string, mode: EditorMode) => void
getPageEditorMode: (pageId: string) => EditorMode
setPageWriterFormat: (pageId: string, format: WriterFormat) => void
getPageWriterFormat: (pageId: string) => WriterFormat
setPageNotesSubMode: (pageId: string, mode: NotesSubMode) => void
getPageNotesSubMode: (pageId: string) => NotesSubMode
```

These read/write from `page.properties['editorMode']`, `page.properties['writerFormat']`, `page.properties['notesSubMode']`. Defaults: `'notes'`, `'freewrite'`, `'markdown'`.

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/store-writer-mode.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/lib/store/slices/notes.ts pfc-app/tests/store-writer-mode.test.ts
git commit -m "feat: add writer mode state (editor mode, format, sub-mode) to notes slice"
```

---

## Task 6: Consensus Engine — Core Pipeline

**Files:**
- Create: `pfc-app/lib/engine/research/consensus.ts`
- Test: `pfc-app/tests/consensus-engine.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/consensus-engine.test.ts
import { describe, it, expect } from 'vitest'
import {
  decomposeQuery,
  scoreConsensus,
  buildConsensusReport,
  type ClaimEvidence,
} from '@/lib/engine/research/consensus'

describe('Consensus Engine', () => {
  describe('scoreConsensus', () => {
    it('scores strong consensus when >80% agree', () => {
      const evidence: ClaimEvidence = {
        claim: 'Coffee improves focus',
        supporting: [
          { paperId: 'p1', quote: 'yes', relevance: 0.9 },
          { paperId: 'p2', quote: 'yes', relevance: 0.8 },
          { paperId: 'p3', quote: 'yes', relevance: 0.7 },
          { paperId: 'p4', quote: 'yes', relevance: 0.6 },
          { paperId: 'p5', quote: 'yes', relevance: 0.9 },
        ],
        contradicting: [{ paperId: 'p6', quote: 'no', relevance: 0.5 }],
        inconclusive: [],
      }
      const result = scoreConsensus(evidence)
      expect(result.level).toBe('strong')
      expect(result.score).toBeGreaterThan(0.8)
    })

    it('scores contested when <60% agree', () => {
      const evidence: ClaimEvidence = {
        claim: 'Tea is better than coffee',
        supporting: [{ paperId: 'p1', quote: 'yes', relevance: 0.9 }],
        contradicting: [
          { paperId: 'p2', quote: 'no', relevance: 0.8 },
          { paperId: 'p3', quote: 'no', relevance: 0.7 },
        ],
        inconclusive: [{ paperId: 'p4', quote: 'maybe', relevance: 0.5 }],
      }
      const result = scoreConsensus(evidence)
      expect(result.level).toBe('contested')
    })

    it('scores insufficient when <3 total papers', () => {
      const evidence: ClaimEvidence = {
        claim: 'Rare claim',
        supporting: [{ paperId: 'p1', quote: 'yes', relevance: 0.9 }],
        contradicting: [],
        inconclusive: [],
      }
      const result = scoreConsensus(evidence)
      expect(result.level).toBe('insufficient')
    })
  })

  describe('buildConsensusReport', () => {
    it('builds report with overall score from claims', () => {
      const report = buildConsensusReport('test query', [
        {
          claim: 'Claim A',
          supporting: [{ paperId: 'p1', quote: 'q', relevance: 0.9 }],
          contradicting: [],
          inconclusive: [],
          score: 0.9,
          level: 'strong' as const,
        },
        {
          claim: 'Claim B',
          supporting: [],
          contradicting: [{ paperId: 'p2', quote: 'q', relevance: 0.8 }],
          inconclusive: [],
          score: 0.2,
          level: 'contested' as const,
        },
      ])
      expect(report.query).toBe('test query')
      expect(report.claims).toHaveLength(2)
      expect(report.overallScore).toBeCloseTo(0.55, 1)
      expect(report.papersAnalyzed).toBe(2)
    })
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/consensus-engine.test.ts`
Expected: FAIL — module not found

**Step 3: Implement the consensus engine**

Create `pfc-app/lib/engine/research/consensus.ts`:

```typescript
import type { LanguageModel } from 'ai'
import { searchPapers, type S2Paper } from './semantic-scholar'
import type {
  ConsensusReport, ConsensusClaim, ConsensusLevel, EvidenceItem
} from '@/lib/types/research-workstation'

export interface ClaimEvidence {
  claim: string
  supporting: EvidenceItem[]
  contradicting: EvidenceItem[]
  inconclusive: EvidenceItem[]
}

// ── Stage 1: Query Decomposition ──────────────

export async function decomposeQuery(
  model: LanguageModel,
  query: string,
): Promise<string[]> {
  // LLM call to break query into testable claims
  // Returns array of specific claims
  const { generateObject } = await import('ai')
  const { object } = await generateObject({
    model,
    prompt: `Break this research question into 2-5 specific, testable claims that could be verified by scientific literature. Return only the claims as a JSON array of strings.\n\nQuestion: ${query}`,
    schema: { type: 'object', properties: { claims: { type: 'array', items: { type: 'string' } } }, required: ['claims'] } as any,
  })
  return (object as any).claims ?? [query]
}

// ── Stage 2: Literature Search ────────────────

export async function searchForClaim(
  claim: string,
  limit: number = 15,
): Promise<S2Paper[]> {
  const result = await searchPapers(claim, { limit })
  return result.data
}

// ── Stage 3: Evidence Extraction ──────────────

export async function extractEvidence(
  model: LanguageModel,
  claim: string,
  papers: S2Paper[],
): Promise<ClaimEvidence> {
  const { generateObject } = await import('ai')
  const paperSummaries = papers
    .filter(p => p.abstract)
    .slice(0, 20)
    .map(p => `[${p.paperId}] ${p.title} (${p.year}): ${p.abstract}`)
    .join('\n\n')

  const { object } = await generateObject({
    model,
    prompt: `Analyze these paper abstracts for evidence about this claim: "${claim}"\n\nPapers:\n${paperSummaries}\n\nFor each paper, classify its stance as supporting, contradicting, or inconclusive. Extract a key quote (max 100 chars). Rate relevance 0-1.`,
    schema: {
      type: 'object',
      properties: {
        supporting: { type: 'array', items: { type: 'object', properties: { paperId: { type: 'string' }, quote: { type: 'string' }, relevance: { type: 'number' } }, required: ['paperId', 'quote', 'relevance'] } },
        contradicting: { type: 'array', items: { type: 'object', properties: { paperId: { type: 'string' }, quote: { type: 'string' }, relevance: { type: 'number' } }, required: ['paperId', 'quote', 'relevance'] } },
        inconclusive: { type: 'array', items: { type: 'object', properties: { paperId: { type: 'string' }, quote: { type: 'string' }, relevance: { type: 'number' } }, required: ['paperId', 'quote', 'relevance'] } },
      },
      required: ['supporting', 'contradicting', 'inconclusive'],
    } as any,
  })

  const result = object as any
  return {
    claim,
    supporting: result.supporting ?? [],
    contradicting: result.contradicting ?? [],
    inconclusive: result.inconclusive ?? [],
  }
}

// ── Stage 4: Consensus Scoring (pure function) ─

export function scoreConsensus(evidence: ClaimEvidence): { score: number; level: ConsensusLevel } {
  const total = evidence.supporting.length + evidence.contradicting.length + evidence.inconclusive.length

  if (total < 3) {
    return { score: 0, level: 'insufficient' }
  }

  const supportRatio = evidence.supporting.length / total
  const score = supportRatio

  if (score >= 0.8) return { score, level: 'strong' }
  if (score >= 0.6) return { score, level: 'moderate' }
  return { score, level: 'contested' }
}

// ── Stage 5: Build Report ─────────────────────

export function buildConsensusReport(
  query: string,
  scoredClaims: ConsensusClaim[],
): ConsensusReport {
  const allPaperIds = new Set<string>()
  for (const claim of scoredClaims) {
    for (const e of [...claim.supporting, ...claim.contradicting, ...claim.inconclusive]) {
      allPaperIds.add(e.paperId)
    }
  }

  const avgScore = scoredClaims.length > 0
    ? scoredClaims.reduce((sum, c) => sum + c.score, 0) / scoredClaims.length
    : 0

  let overallLevel: ConsensusLevel = 'insufficient'
  if (avgScore >= 0.8) overallLevel = 'strong'
  else if (avgScore >= 0.6) overallLevel = 'moderate'
  else if (allPaperIds.size >= 3) overallLevel = 'contested'

  return {
    id: crypto.randomUUID(),
    query,
    claims: scoredClaims,
    overallScore: avgScore,
    overallLevel,
    papersAnalyzed: allPaperIds.size,
    paperIds: Array.from(allPaperIds),
    createdAt: Date.now(),
  }
}

// ── Full Pipeline ─────────────────────────────

export async function runConsensusPipeline(
  model: LanguageModel,
  query: string,
  onProgress?: (stage: string, detail: string) => void,
): Promise<ConsensusReport> {
  onProgress?.('decompose', 'Breaking query into claims...')
  const claims = await decomposeQuery(model, query)

  const scoredClaims: ConsensusClaim[] = []

  for (const claim of claims) {
    onProgress?.('search', `Searching papers for: ${claim}`)
    const papers = await searchForClaim(claim)

    onProgress?.('extract', `Analyzing ${papers.length} papers for: ${claim}`)
    const evidence = await extractEvidence(model, claim, papers)

    const { score, level } = scoreConsensus(evidence)

    scoredClaims.push({
      claim: evidence.claim,
      supporting: evidence.supporting,
      contradicting: evidence.contradicting,
      inconclusive: evidence.inconclusive,
      score,
      level,
    })
  }

  onProgress?.('synthesize', 'Building consensus report...')
  return buildConsensusReport(query, scoredClaims)
}
```

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/consensus-engine.test.ts`
Expected: PASS (only pure function tests — `scoreConsensus` and `buildConsensusReport`)

**Step 5: Commit**

```bash
git add pfc-app/lib/engine/research/consensus.ts pfc-app/tests/consensus-engine.test.ts
git commit -m "feat: implement consensus engine with 5-stage pipeline"
```

---

## Task 7: Consensus API Route — SSE Streaming

**Files:**
- Create: `pfc-app/app/api/consensus/route.ts`
- Test: `pfc-app/tests/api-consensus.test.ts`

**Step 1: Write the failing test**

```typescript
// pfc-app/tests/api-consensus.test.ts
import { describe, it, expect } from 'vitest'

describe('Consensus API Route', () => {
  it('module exports POST handler', async () => {
    const mod = await import('@/app/api/consensus/route')
    expect(mod.POST).toBeDefined()
    expect(typeof mod.POST).toBe('function')
  })
})
```

**Step 2: Run test to verify it fails**

Run: `cd pfc-app && npm test -- tests/api-consensus.test.ts`
Expected: FAIL — module not found

**Step 3: Create the SSE route**

Create `pfc-app/app/api/consensus/route.ts`. Follow the exact same pattern as `app/api/notes-ai/route.ts` and `app/api/notes-learn/route.ts`:

- Use `withMiddleware()` wrapper (30 req/60sec)
- Parse body with `parseBodyWithLimit` (10MB cap)
- Validate `query` string (max 50k chars via `capStr()`)
- Accept `inferenceConfig` to resolve LLM provider
- Stream SSE events: `progress` (stage updates), `report` (final ConsensusReport JSON), `error`
- Use `runConsensusPipeline()` with `onProgress` callback mapped to SSE events
- AbortSignal from `request.signal` for client disconnect

Key SSE event format (match existing patterns):
```
data: {"type":"progress","stage":"search","detail":"Searching papers..."}\n\n
data: {"type":"report","report":{...ConsensusReport}}\n\n
data: {"type":"done"}\n\n
```

**Step 4: Run test to verify it passes**

Run: `cd pfc-app && npm test -- tests/api-consensus.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add pfc-app/app/api/consensus/route.ts pfc-app/tests/api-consensus.test.ts
git commit -m "feat: add consensus SSE API route"
```

---

## Task 8: Writer Mode UI — Format Presets & Editor

**Files:**
- Create: `pfc-app/components/notes/writer-editor.tsx`
- Modify: `pfc-app/app/notes/page.tsx` (add mode toggle and conditional rendering)

**Step 1: Build the WriterEditor component**

Create `pfc-app/components/notes/writer-editor.tsx`:

- A clean, distraction-free `<textarea>` or `contentEditable` that fills the screen
- Reads format from `getPageWriterFormat(activePageId)` via store
- Applies `WRITER_FORMAT_CONFIGS[format]` as inline styles: `fontFamily`, `fontSize`, `lineHeight`, `maxWidth`, `background`
- Minimal toolbar: format dropdown (cycles through 5 presets), word count, save indicator, focus toggle, "Exit" button
- Focus mode: CSS that dims all paragraphs except the one containing the cursor (opacity 0.3 on non-focused, 1.0 on focused)
- Content syncs with the page's blocks — on entering Writer Mode, all blocks are concatenated into a single text. On exiting, text is split back into blocks.
- Word count: computed from the text content via `text.split(/\s+/).filter(Boolean).length`
- Auto-save: debounced 500ms save on keystroke, same pattern as existing `_notesContentTimer`

**Step 2: Add mode toggle to notes page**

Modify `pfc-app/app/notes/page.tsx`:

- Add a `[ Notes ] [ Writer ]` toggle near the top (above the title area)
- When `editorMode === 'writer'`, render `<WriterEditor pageId={activePageId} />` instead of the block editor
- When `editorMode === 'notes'`, show current block editor (no change)
- In Notes Mode, add sub-toggle for Markdown / Plain Text
- Plain text mode: swap block editor font to monospace (`font-mono`), hide formatting toolbar, disable slash commands
- Read mode/format from store via `getPageEditorMode()`, `getPageWriterFormat()`, `getPageNotesSubMode()`

**Step 3: Test manually**

Navigate to /notes, create a page, toggle Writer Mode, verify:
- Format dropdown cycles through all 5 presets
- Each preset visually changes the entire editing area
- Word count updates on typing
- Focus mode dims non-active paragraphs
- Switching back to Notes Mode preserves content
- Plain text mode shows monospace

**Step 4: Commit**

```bash
git add pfc-app/components/notes/writer-editor.tsx pfc-app/app/notes/page.tsx
git commit -m "feat: add Writer Mode with 5 format presets and plain text sub-mode"
```

---

## Task 9: Embedded Chat Block — Block Editor Integration

**Files:**
- Modify: `pfc-app/components/notes/block-editor.tsx` (add chat-embed block renderer)
- Create: `pfc-app/components/notes/chat-embed-block.tsx`
- Modify: `pfc-app/lib/store/slices/notes.ts` (add `createChatEmbedBlock` action)

**Step 1: Add `chat-embed` to block type system**

In `block-editor.tsx`, find the block type rendering switch and add a case for `'chat-embed'`. When a block has `type === 'chat-embed'`, render `<ChatEmbedBlock>` instead of the normal contentEditable.

**Step 2: Create ChatEmbedBlock component**

Create `pfc-app/components/notes/chat-embed-block.tsx`:

```typescript
interface ChatEmbedBlockProps {
  block: NoteBlock
  pageId: string
}
```

- Reads `threadId` from `block.properties.threadId`
- Reads `purpose` from `block.properties.purpose`
- Displays the thread's messages in a compact chat view (scrollable, max-height 300px)
- Shows a message input at the bottom (uses existing `useAssistantStream` or `useChatStream` pattern for sending)
- **Context injection**: When sending a message from an embedded chat, the system prompt includes the note's full content (all blocks concatenated). This makes the chat a "brain" for the note.
- Detach button (top-right): calls `detachThread(threadId)` and `deleteBlock(blockId)` to remove the embed and restore the thread to floating mini-chat
- Purpose badge (top-left): shows the chat purpose icon + label
- Draggable: the embed block has a drag handle that, when dragged outside the notes area, triggers detachment
- Visual: rounded border, subtle background tint, purpose-colored left accent bar

**Step 3: Add `createChatEmbedBlock` to notes slice**

```typescript
createChatEmbedBlock: (pageId: string, threadId: string, purpose: ChatPurpose, afterBlockId?: string) => void
```

Creates a new NoteBlock with:
- `type: 'chat-embed'`
- `content: ''` (no text content)
- `properties: { threadId, purpose }`

Also calls `embedThreadInPage(threadId, pageId, newBlockId)` on the UI slice.

**Step 4: Test manually**

- Create a thread in mini-chat
- Use "Pin to current note" in thread dropdown
- Verify chat-embed block appears inline in the note
- Type a message in the embed — verify it receives note context
- Click Detach — verify block is removed and thread returns to mini-chat

**Step 5: Commit**

```bash
git add pfc-app/components/notes/chat-embed-block.tsx pfc-app/components/notes/block-editor.tsx pfc-app/lib/store/slices/notes.ts
git commit -m "feat: add chat-embed block type for inline note chats"
```

---

## Task 10: Mini-Chat Drag-to-Embed

**Files:**
- Modify: `pfc-app/components/mini-chat.tsx` (add drag-to-embed interaction)

**Step 1: Add drag-to-embed to mini-chat**

The mini-chat already has pointer-event-based dragging. Extend it:

1. During drag, check if the cursor is over the notes block editor area (detect via `document.elementsFromPoint()` or a React ref on the block editor)
2. If hovering over block editor: show a visual drop zone indicator ("Drop to embed")
3. On pointer release over block editor:
   - Determine the `afterBlockId` (which block the cursor is nearest to)
   - Call `createChatEmbedBlock(activePageId, activeThreadId, purpose, afterBlockId)`
   - Close the mini-chat (or keep it open but switch to a different thread)
   - The chat-embed block appears inline at the drop position

4. Add a "Pin to current note" option in the thread tab context menu as an alternative to drag-and-drop

**Step 2: Add drop zone indicator to notes page**

Modify `pfc-app/app/notes/page.tsx`:

- Add a state `isReceivingDrop` that turns on when a mini-chat is being dragged over the block editor
- When active: show a pulsing blue border or highlight zone between blocks
- Position indicator: nearest gap between blocks based on cursor Y position

**Step 3: Test manually**

- Open mini-chat with a conversation
- Drag it toward the block editor area
- Verify drop zone appears
- Drop it — verify chat-embed block is created
- Verify the thread is marked as embedded
- Drag the embed out — verify it returns to mini-chat

**Step 4: Commit**

```bash
git add pfc-app/components/mini-chat.tsx pfc-app/app/notes/page.tsx
git commit -m "feat: add drag-to-embed interaction for mini-chat -> notes"
```

---

## Task 11: Research Hub — Page Layout & Library Sidebar

**Files:**
- Create: `pfc-app/app/research/page.tsx`
- Create: `pfc-app/app/research/layout.tsx` (SEO metadata)
- Create: `pfc-app/components/research/research-sidebar.tsx`
- Create: `pfc-app/components/research/paper-detail.tsx`

**Step 1: Create the route layout**

Create `pfc-app/app/research/layout.tsx` as a server component exporting Metadata (same pattern as other routes — see `app/(chat)/layout.tsx`):

```typescript
import type { Metadata } from 'next'
export const metadata: Metadata = {
  title: 'Research Hub — Brainiac',
  description: 'Discover, save, and organize research papers',
}
export default function ResearchLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
```

**Step 2: Create the Research Hub page**

Create `pfc-app/app/research/page.tsx`:

- Three-pane layout: sidebar (240px fixed) | center (flex-1) | graph (320px, collapsible)
- Uses the same `th()` theme helper as notes page for consistent styling
- Sidebar: `<ResearchSidebar />`
- Center: `<PaperDetail paperId={activePaperId} />`
- Right: `<CitationGraph paperId={activePaperId} />` (placeholder for Task 13)

**Step 3: Build ResearchSidebar**

Create `pfc-app/components/research/research-sidebar.tsx`:

- Search bar at top (debounced 300ms) — searches local `savedPapers` first, then Semantic Scholar
- "Import" button: paste DOI/URL modal
- Collections list: reads from `researchCollections` store
- "New Collection" button: creates via `createCollection()`
- Recent papers: last 20 from `savedPapers` sorted by `savedAt`
- Saved papers: all bookmarked
- Click paper → sets `activePaperId` in store
- Click collection → sets `activeCollectionId`, filters paper list

**Step 4: Build PaperDetail**

Create `pfc-app/components/research/paper-detail.tsx`:

- Shows full paper metadata when `activePaperId` is set
- Title, authors (comma-separated), year, venue, citation count
- Abstract (expandable if long)
- "Key Findings" section: if `keyFindings` is cached, show it. Otherwise, show "Generate" button that calls LLM and caches result.
- User notes: inline `<textarea>` that auto-saves via `updatePaperNotes()`
- Actions bar: Save to Collection (dropdown), Open PDF (if `openAccessPdfUrl`), Export BibTeX, Run Consensus, Pin Chat
- Related papers: fetch `getPaperReferences()` and `getPaperCitations()` from S2, show as clickable list

**Step 5: Commit**

```bash
git add pfc-app/app/research/ pfc-app/components/research/
git commit -m "feat: add Research Hub page with sidebar and paper detail"
```

---

## Task 12: Research Hub — Paper Import & Search

**Files:**
- Create: `pfc-app/components/research/paper-search.tsx`
- Create: `pfc-app/components/research/import-paper-modal.tsx`

**Step 1: Build PaperSearch component**

Inline search in the sidebar. On typing:
1. Filter local `savedPapers` by title/author match
2. After 300ms debounce, also search Semantic Scholar via `searchPapers(query, { limit: 10 })`
3. Show results in a dropdown: local results first (with "In Library" badge), then S2 results
4. Click S2 result → opens a confirmation with "Save to Library?" button
5. On save → calls `savePaper()` with S2 data mapped to `SavedPaper`

**Step 2: Build ImportPaperModal**

Modal with a text input for DOI or URL:
- Detect DOI pattern (`10.xxxx/xxxx`)
- Call `getPaperDetails('DOI:' + doi)` from semantic-scholar module
- Show preview of paper metadata
- "Save" button → `savePaper()`
- Handle errors (paper not found, invalid DOI)

**Step 3: Commit**

```bash
git add pfc-app/components/research/paper-search.tsx pfc-app/components/research/import-paper-modal.tsx
git commit -m "feat: add paper search and DOI import to Research Hub"
```

---

## Task 13: Research Hub — Citation Discovery Graph

**Files:**
- Create: `pfc-app/components/research/citation-graph.tsx`

**Step 1: Build CitationGraph component**

Reuse the D3 force-directed graph pattern from the existing concept atlas (`components/notes/note-canvas.tsx` or concept panel). Build:

- SVG-based force-directed graph using `d3-force`
- Center node = selected paper (gold)
- Fetch references via `getPaperReferences(paperId, { limit: 20 })`
- Fetch citations via `getPaperCitations(paperId, { limit: 20 })`
- References = blue nodes with directed edges pointing from center → reference
- Citations = green nodes with directed edges pointing from citation → center
- Papers in user's library = gold outline
- Click node → sets `activePaperId` (loads in center pane)
- Zoom/pan with `d3-zoom`
- Node label: first author + year (truncated)
- Tooltip on hover: full title

**Step 2: Integrate into research page**

Wire into the right pane of `research/page.tsx`. Collapsible with a toggle button.

**Step 3: Commit**

```bash
git add pfc-app/components/research/citation-graph.tsx pfc-app/app/research/page.tsx
git commit -m "feat: add citation discovery graph to Research Hub"
```

---

## Task 14: Consensus in Chat — UI Components

**Files:**
- Create: `pfc-app/components/chat/consensus-report.tsx`
- Create: `pfc-app/components/chat/consensus-pill.tsx`
- Modify: `pfc-app/components/chat/messages.tsx` (or the message renderer)

**Step 1: Create ConsensusReport component**

A special message card that renders a `ConsensusReport` object:

- Header: topic, overall score badge, papers analyzed count
- Claims list: grouped by level (strong → moderate → contested → insufficient)
- Each claim: text, ratio (e.g., "89%, 12/14 papers"), expandable detail showing supporting/contradicting papers with quotes
- "Save to Research Hub" button: calls `saveConsensusReport()` + `savePaper()` for each referenced paper
- "Expand" on claim: shows papers with their quotes, clickable paper titles that open in Research Hub

Styling: special border treatment, consensus-level color coding (green=strong, yellow=moderate, red=contested, gray=insufficient)

**Step 2: Create ConsensusPill**

A small pill button to place in the chat input area:

```
[🔬 Find Consensus]
```

- When clicked: prepends a consensus flag to the query
- The chat submission flow detects this flag and routes to `/api/consensus` instead of the normal chat route
- Auto-suggest variant: a chip that appears below AI responses to research questions: "🔬 Want consensus analysis?"

**Step 3: Integrate with message renderer**

Modify the message rendering in `messages.tsx` (or wherever messages are rendered):
- Detect messages with `type: 'consensus'` or a consensus report attached
- Render `<ConsensusReport>` instead of normal message bubble
- Also render the auto-suggest chip when the AI response contains research content (detect via keywords or a flag from the API)

**Step 4: Commit**

```bash
git add pfc-app/components/chat/consensus-report.tsx pfc-app/components/chat/consensus-pill.tsx pfc-app/components/chat/messages.tsx
git commit -m "feat: add consensus report UI and Find Consensus pill in chat"
```

---

## Task 15: Navigation — Add Research to Sidebar

**Files:**
- Modify: `pfc-app/components/app-shell.tsx` (or wherever the main nav sidebar lives)

**Step 1: Add Research Hub link**

Add a "Research" nav item to the main sidebar navigation. Use a beaker or book icon (from Lucide). Link to `/research`.

Check the existing nav structure — it likely has Chat, Notes, Settings, etc. Add Research after Notes in the list.

**Step 2: Commit**

```bash
git add pfc-app/components/app-shell.tsx
git commit -m "feat: add Research Hub to main navigation"
```

---

## Task 16: Integration Wiring — Cross-Feature Flows

**Files:**
- Modify: `pfc-app/components/research/paper-detail.tsx` (consensus badge, pin chat)
- Modify: `pfc-app/components/chat/consensus-report.tsx` (save to hub)
- Modify: `pfc-app/app/notes/page.tsx` (auto-open mini-chat for embedded threads)

**Step 1: Paper Detail → Consensus**

In `paper-detail.tsx`:
- "Run Consensus" button → navigates to chat and triggers consensus pipeline for the paper's topic
- If paper already has a `consensusReportId`, show the consensus summary inline as a badge/section

**Step 2: Consensus Report → Research Hub**

In `consensus-report.tsx`:
- "Save to Research Hub" → saves the report via `saveConsensusReport()`, and for each `paperId` in the report, fetches full paper details from S2 and saves via `savePaper()`

**Step 3: Notes → Auto-Open Embedded Chats**

In `notes/page.tsx`:
- When `activePageId` changes, check `getThreadsForPage(pageId)`
- If threads exist, auto-open mini-chat and switch to the first embedded thread

**Step 4: Commit**

```bash
git add pfc-app/components/research/paper-detail.tsx pfc-app/components/chat/consensus-report.tsx pfc-app/app/notes/page.tsx
git commit -m "feat: wire cross-feature integration flows"
```

---

## Task 17: Final Polish & Full Test Run

**Files:**
- All modified files

**Step 1: Run full test suite**

```bash
cd pfc-app && npm test
```

Fix any failures.

**Step 2: Run type check**

```bash
cd pfc-app && npx tsc --noEmit
```

Fix any type errors.

**Step 3: Run dev server and manual test**

```bash
cd pfc-app && npm run dev
```

Test each feature:
1. Writer Mode: toggle modes, cycle formats, verify instant visual change
2. Embedded Chat: drag mini-chat to note, verify context-aware responses, detach
3. Research Hub: search papers, save to collection, view citation graph
4. Consensus: trigger from chat, verify structured report, save to hub
5. Cross-flows: consensus → save to hub → open paper → pin chat → embed in note

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Research Workstation — embedded chats, writer mode, research hub, consensus engine"
```

---

## Execution Order Summary

| Task | What | Depends On | Parallelizable |
|------|------|------------|----------------|
| 1 | Database schema (5 new tables) | Nothing | Yes |
| 2 | Shared types file | Nothing | Yes |
| 3 | Research slice (collections, papers, consensus) | Task 2 | — |
| 4 | UI slice (purpose, embedding) | Task 2 | Yes (with 3) |
| 5 | Notes slice (writer mode state) | Task 2 | Yes (with 3, 4) |
| 6 | Consensus engine (pipeline) | Task 2 | Yes (with 3-5) |
| 7 | Consensus API route | Task 6 | — |
| 8 | Writer Mode UI | Task 5 | — |
| 9 | Chat-embed block | Tasks 4, 5 | — |
| 10 | Mini-chat drag-to-embed | Task 9 | — |
| 11 | Research Hub page + sidebar + detail | Task 3 | — |
| 12 | Paper search + import | Task 11 | — |
| 13 | Citation graph | Task 11 | Yes (with 12) |
| 14 | Consensus chat UI | Task 7 | — |
| 15 | Navigation update | Task 11 | Yes (with 12-14) |
| 16 | Cross-feature wiring | Tasks 10-14 | — |
| 17 | Final polish & tests | All | — |

**Parallel batches:**
- Batch 1: Tasks 1, 2 (schema + types)
- Batch 2: Tasks 3, 4, 5, 6 (all store extensions + engine)
- Batch 3: Tasks 7, 8, 9 (API + Writer UI + embed block)
- Batch 4: Tasks 10, 11 (drag interaction + hub page)
- Batch 5: Tasks 12, 13, 14, 15 (search, graph, consensus UI, nav)
- Batch 6: Tasks 16, 17 (wiring + polish)
