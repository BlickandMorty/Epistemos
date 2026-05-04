# Port Research Workstation Features: pfc-app → brainiac-2.0

## Status: IN PROGRESS — Pick up from here

All 17 Research Workstation tasks were accidentally implemented in `pfc-app/` instead of `brainiac-2.0/`. This document describes exactly what needs to be ported and how.

## Source files (pfc-app/) to port

### 1. Shared Types
- **Source:** `pfc-app/lib/types/research-workstation.ts`
- **Target:** Add to `brainiac-2.0/lib/research/types.ts` (EXTEND existing file)
- **Types to add:** `EditorMode`, `WriterFormat`, `NotesSubMode`, `ConsensusLevel`, `ConsensusReport`, `ConsensusClaim`, `EvidenceItem`, `SavedPaper` (merge with existing `ResearchPaper`), `ResearchCollection`, `CONSENSUS_LEVELS`
- **Note:** brainiac-2.0 already has `ResearchPaper` — merge fields (add `bibtex`, `openAccessPdfUrl`, `consensusReportId`, `collectionIds` to existing type)

### 2. Store Slices

#### Research Slice Extension
- **Source:** `pfc-app/lib/store/slices/research.ts` (239 lines)
- **Target:** Extend `brainiac-2.0/lib/store/slices/research.ts` (existing, 231 lines)
- **Add to state:** `consensusReports`, `researchCollections`, `activeCollectionId`, `activePaperId`
- **Add actions:** `saveConsensusReport`, `savePaper`, `createCollection`, `setActiveCollection`, `setActivePaper`, `updatePaperNotes`, `addPaperToCollection`
- **Important:** Keep ALL existing research actions (addResearchPaper, removeResearchPaper, etc.)

#### Notes Slice Extension
- **Source:** `pfc-app/lib/store/slices/notes.ts` (additions for writer mode)
- **Target:** Extend `brainiac-2.0/lib/store/slices/notes.ts` (existing, 1890 lines)
- **Add to state:** `editorMode` (EditorMode), `writerFormat` (WriterFormat), `notesSubMode` per page
- **Add actions:** `setEditorMode`, `setWriterFormat`, `setNotesSubMode`
- **Note:** brainiac-2.0 notes slice already has AI typewriter, vaults, concepts — writer mode extends this

### 3. Consensus Engine
- **Source:** `pfc-app/lib/engine/research/consensus.ts` (223 lines)
- **Target:** Create `brainiac-2.0/lib/engine/research/consensus.ts` (NEW file)
- **Copy directly:** `scoreConsensus()`, `buildConsensusReport()`, `decomposeQuery()`, `extractEvidence()`, `runConsensusPipeline()`
- **Note:** brainiac-2.0 already has `lib/engine/research/` with semantic-scholar.ts, citation-search.ts, etc.

### 4. API Routes
- **Source:** `pfc-app/app/api/consensus/route.ts`
- **Target:** Create `brainiac-2.0/app/(shell)/(chat)/api/consensus/route.ts` (NEW)
- **Note:** Must follow brainiac-2.0's API pattern with `withRateLimit()` middleware and SSE writer from `lib/api-utils.ts`

### 5. Components (ALL need Tailwind CSS conversion)

pfc-app uses inline styles; brainiac-2.0 uses Tailwind + Shadcn UI.

#### Research Hub Components
| Source (pfc-app) | Target (brainiac-2.0) | Notes |
|---|---|---|
| `components/research/research-sidebar.tsx` (297 lines) | `components/research/research-sidebar.tsx` (NEW) | Convert inline styles → Tailwind |
| `components/research/paper-detail.tsx` (324 lines) | `components/research/paper-detail.tsx` (NEW) | Convert inline styles → Tailwind, use Shadcn Button/Card |
| `components/research/paper-search.tsx` (445 lines) | `components/research/paper-search.tsx` (NEW) | Use Shadcn Input, Dialog |
| `components/research/import-paper-modal.tsx` (396 lines) | `components/research/import-paper-modal.tsx` (NEW) | Use Shadcn Dialog |
| `components/research/citation-graph.tsx` (262 lines) | `components/research/citation-graph.tsx` (NEW) | SVG stays, wrapper → Tailwind |

#### Chat Components
| Source (pfc-app) | Target (brainiac-2.0) | Notes |
|---|---|---|
| `components/chat/consensus-report.tsx` (227 lines) | `components/chat/consensus-report.tsx` (NEW) | Convert to Tailwind |
| `components/chat/consensus-pill.tsx` (35 lines) | `components/chat/consensus-pill.tsx` (NEW) | Convert to Tailwind |

#### Notes Components
| Source (pfc-app) | Target (brainiac-2.0) | Notes |
|---|---|---|
| `components/notes/writer-editor.tsx` | `components/notes/writer-editor.tsx` (NEW) | Integrate with existing block editor |
| `components/notes/chat-embed-block.tsx` | `components/notes/chat-embed-block.tsx` (NEW) | Use mini-chat pattern from brainiac-2.0 |

### 6. Pages

#### Research Hub Page
- **Source:** `pfc-app/app/research/page.tsx`
- **Target:** Either extend `brainiac-2.0/app/(shell)/library/page.tsx` OR create `brainiac-2.0/app/(shell)/research-hub/page.tsx`
- **Decision:** Library page already exists — consider merging Research Hub into it, or add as sibling route

#### Notes Page Updates
- **Source:** `pfc-app/app/notes/page.tsx` (writer mode toggle, embedded chat)
- **Target:** Modify `brainiac-2.0/app/(shell)/notes/page.tsx`
- **Add:** Writer mode toggle, embedded chat auto-open

### 7. Navigation Updates
- **Source:** `pfc-app/` nav additions
- **Target:** `brainiac-2.0/components/layout/top-nav.tsx`
- **Add:** Research Hub link (if new route), consensus indicator

### 8. Integration Wiring
- Chat → "Run Consensus" button that triggers consensus pipeline
- Paper detail → "Run Consensus" link
- Notes → Writer mode toggle + embedded chat blocks
- Consensus report → "Save to Research Hub" → saves papers + report to store
- Message auto-extraction → detect papers in AI responses → add to research library

## Key Architecture Differences

| Aspect | pfc-app | brainiac-2.0 |
|---|---|---|
| Styling | Inline styles | Tailwind CSS + Shadcn UI |
| UI Components | Custom | Shadcn/Radix (Button, Card, Dialog, etc.) |
| Theme | `useIsDark()` hook | `next-themes` with 6 themes |
| Store | Zustand flat | Zustand with 13 slices + events |
| Types | `lib/types/` | Distributed across `lib/research/types.ts`, `lib/notes/types.ts`, `lib/engine/types.ts` |
| Research | New from scratch | Already has ResearchPaper, Citation, ResearchBook, semantic-scholar.ts |
| Notes | Basic | Full SiYuan block editor with vaults, concepts, undo/redo, AI typewriter |
| API Utils | Manual SSE | `lib/api-utils.ts` SSE writer + `api-middleware.ts` rate limiting |
| Database | Drizzle SQLite (separate) | Drizzle SQLite integrated with vault sync |

## Store Wiring (use-pfc-store.ts)

After extending slices, update `brainiac-2.0/lib/store/use-pfc-store.ts`:
- Import new state/action types from extended research slice
- Export new types if needed
- NO new slice needed — consensus/research-hub extend existing research slice

## Testing

- Copy and adapt tests from `pfc-app/tests/` to `brainiac-2.0/tests/`
- Consensus engine tests (pure function tests for `scoreConsensus`, `buildConsensusReport`)
- Store slice tests for new actions
- Run `npx vitest` in brainiac-2.0/

## Git Status

- pfc-app has 20+ commits with Research Workstation features (on main)
- brainiac-2.0 is untouched — all porting is additive
- Reference source files in pfc-app for exact logic, then convert styling to Tailwind
