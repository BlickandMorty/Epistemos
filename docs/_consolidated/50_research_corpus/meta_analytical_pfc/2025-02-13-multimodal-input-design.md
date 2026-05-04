# Multimodal File Attachment — Design Document

**Date:** 2025-02-13
**Status:** Approved
**Scope:** Wire up file attachment support across the full stack (input → API → LLM → render)

## Summary

Add end-to-end file attachment support to PFC chat. Users can attach files via the paperclip button or by typing file paths in queries. Images go to the LLM as vision input; documents get text-extracted and injected into the prompt as context.

## Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Transport | Base64 over JSON | No API format change, simple client code, all providers accept base64 natively |
| Storage | Local filesystem (`uploads/`) | Matches existing local-first architecture (SQLite, no cloud, no accounts) |
| Text extraction | Extract and inject into prompt | LLM can reason over document content directly |
| File picker | Browser picker + path detection | Paperclip button for GUI, detect `/path/to/file` in queries for terminal-like usage |
| Max file size | 100MB per file | Node.js handles this; extracted text truncated to 30K chars for LLM context |

## Supported File Types

| Category | Extensions | Processing |
|----------|-----------|------------|
| Images | `.png`, `.jpg`, `.jpeg`, `.webp` | Base64 → LLM vision input via Vercel AI SDK |
| Text | `.txt`, `.md` | Read as UTF-8 → inject into prompt |
| Data | `.csv`, `.json` | Read as UTF-8, format as table/pretty-print → inject |
| Documents | `.pdf` | `pdf-parse` library → extract text → inject |
| Documents | `.docx` | `mammoth` library → extract text → inject |

## Data Flow

```
TWO INPUT PATHS:

  📎 Paperclip Button              💬 "analyze ~/paper.pdf"
       │                                    │
       ▼                                    ▼
  Browser FileReader              Path regex detection
  → base64 + metadata             in query text
       │                                    │
       ▼                                    ▼
  pendingAttachments[]            filePaths[] in request
  (existing store)                body
       │                                    │
       └──────────┬────────────────────────┘
                  ▼
           Chat API Route
                  │
        ┌─────────┴──────────┐
        ▼                    ▼
  base64 attachments    file paths
  (from browser)        (read from disk)
        │                    │
        ▼                    ▼
  Save to /uploads      Read directly
  dir on disk           from disk
        │                    │
        └─────────┬─────────┘
                  ▼
         Classify by type:
         ┌──────────┴──────────┐
         ▼                     ▼
    IMAGES                 DOCUMENTS
    (.png/.jpg/.webp)      (.pdf/.txt/.md/.csv/.json/.docx)
         │                     │
         ▼                     ▼
    base64 → LLM          Extract text →
    vision input           inject into prompt
         │                     │
         └─────────┬──────────┘
                   ▼
           Normal pipeline
           (10 stages → response)
                   │
                   ▼
           Message saved to DB
           with attachment metadata
```

## File Processing Pipeline

New module: `lib/engine/file-processor.ts`

- `classifyFile(mimeType, extension)` → `'image' | 'text' | 'data' | 'document'`
- `extractText(file)` → dispatches to appropriate extractor:
  - `.txt/.md` → `fs.readFileSync` as UTF-8
  - `.csv` → read UTF-8, format as markdown table
  - `.json` → read + `JSON.stringify(parsed, null, 2)`
  - `.pdf` → `pdf-parse` library
  - `.docx` → `mammoth` library
- `validateFile(file)` → size check (100MB), type check
- Extracted text truncated to 30,000 chars with notice

## Limits

| Limit | Value |
|-------|-------|
| Max file size | 100MB per file |
| Max files per message | 5 |
| Max extracted text to LLM | 30,000 chars (truncated with notice) |
| Max images to LLM vision | 4 per message (provider limit) |
| Next.js body size limit | 150MB (to accommodate base64 overhead) |
| Image auto-resize | If >20MB, resize before sending to provider |

## Frontend UI

### Attachment preview strip (new, in multimodal-input.tsx)

```
┌─────────────────────────────────────────────────┐
│ [textarea: "What does this paper argue?"]        │
├─────────────────────────────────────────────────┤
│ 📄 paper.pdf (2.3MB) ✕  🖼️ chart.png ✕         │  ← preview strip
├─────────────────────────────────────────────────┤
│ 📎  🔬  ⚡  [Send]                              │
└─────────────────────────────────────────────────┘
```

- Images: thumbnail preview (64x64)
- Documents: icon + filename + size
- Each has ✕ to remove (calls existing `removeAttachment()`)
- Loading spinner for large files during FileReader

### Path detection in query text

Regex: match absolute paths (`/path/to/file.ext`) and home-relative paths (`~/path/to/file.ext`)
Detected paths sent as `filePaths: string[]` in request body, resolved server-side.

### Message rendering (message.tsx)

When `message.attachments` exists:
- Images: inline thumbnail, clickable to view full size
- Documents: pill badge with file type icon + filename

## Database Change

```sql
ALTER TABLE message ADD COLUMN attachments TEXT;
-- JSON array: [{ id, name, type, uri, size, mimeType }]
-- uri points to uploads/ directory path
-- No file content stored in DB
```

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/engine/file-processor.ts` | Create | Classify, extract text, validate sizes |
| `components/multimodal-input.tsx` | Modify | Wire paperclip, add preview strip, path detection |
| `components/message.tsx` | Modify | Render attachment badges/thumbnails |
| `hooks/use-chat-stream.ts` | Modify | Pass attachments + filePaths in request body |
| `app/(chat)/api/chat/route.ts` | Modify | Accept attachments, process files, pass to LLM |
| `lib/engine/llm/generate.ts` | Modify | Pass images as vision content via Vercel AI SDK |
| `lib/db/schema.ts` | Modify | Add `attachments` column to message table |
| `lib/db/queries.ts` | Modify | Persist/retrieve attachment metadata |
| `lib/store/slices/message.ts` | Minor | Already has actions, just needs wiring |
| `package.json` | Modify | Add `pdf-parse`, `mammoth` |

## New Dependencies

| Package | Purpose | Size |
|---------|---------|------|
| `pdf-parse` | PDF text extraction | ~200KB |
| `mammoth` | DOCX → text | ~300KB |

## Simulation Mode Behavior

In simulation mode (no LLM), file attachments are acknowledged in the simulated response:
- "I see you've attached [filename]. In API/Local mode, I would analyze this [image/document]."
- Signals still generated heuristically as normal
- Text extraction still runs (useful for seeing what the LLM would receive)
