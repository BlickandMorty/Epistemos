# Multimodal File Attachment — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire up end-to-end file attachment support — paperclip upload, path detection in queries, text extraction from documents, vision input for images, and attachment rendering in messages.

**Architecture:** Base64 over existing JSON API. Images go to LLM as vision content via Vercel AI SDK. Documents get text-extracted (pdf-parse, mammoth) and injected into prompt. Files persisted to local `uploads/` directory, metadata in SQLite. Two input paths: browser file picker + auto-detect file paths in query text.

**Tech Stack:** Next.js 16, Vercel AI SDK v6, pdf-parse, mammoth, SQLite/Drizzle ORM, Zustand

**Design doc:** `docs/plans/2025-02-13-multimodal-input-design.md`

---

### Task 1: Install Dependencies

**Files:**
- Modify: `pfc-app/package.json`

**Step 1: Install pdf-parse and mammoth**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npm install pdf-parse mammoth
```

**Step 2: Verify install**

```bash
node -e "require('pdf-parse'); require('mammoth'); console.log('OK')"
```
Expected: `OK`

**Step 3: Commit**

```bash
git add package.json package-lock.json
git commit -m "deps: add pdf-parse and mammoth for file attachment support"
```

---

### Task 2: Create File Processor Module

**Files:**
- Create: `pfc-app/lib/engine/file-processor.ts`
- Create: `pfc-app/tests/file-processor.test.ts`

**Step 1: Write the failing tests**

Create `pfc-app/tests/file-processor.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import { classifyFile, validateFile, extractTextContent } from '@/lib/engine/file-processor';

describe('classifyFile', () => {
  it('classifies png as image', () => {
    expect(classifyFile('image/png', '.png')).toBe('image');
  });
  it('classifies jpg as image', () => {
    expect(classifyFile('image/jpeg', '.jpg')).toBe('image');
  });
  it('classifies webp as image', () => {
    expect(classifyFile('image/webp', '.webp')).toBe('image');
  });
  it('classifies pdf as document', () => {
    expect(classifyFile('application/pdf', '.pdf')).toBe('document');
  });
  it('classifies docx as document', () => {
    expect(classifyFile('application/vnd.openxmlformats-officedocument.wordprocessingml.document', '.docx')).toBe('document');
  });
  it('classifies txt as text', () => {
    expect(classifyFile('text/plain', '.txt')).toBe('text');
  });
  it('classifies md as text', () => {
    expect(classifyFile('text/markdown', '.md')).toBe('text');
  });
  it('classifies csv as data', () => {
    expect(classifyFile('text/csv', '.csv')).toBe('data');
  });
  it('classifies json as data', () => {
    expect(classifyFile('application/json', '.json')).toBe('data');
  });
  it('falls back to other for unknown types', () => {
    expect(classifyFile('application/octet-stream', '.bin')).toBe('other');
  });
});

describe('validateFile', () => {
  it('accepts a file under 100MB', () => {
    const result = validateFile({ size: 50 * 1024 * 1024, name: 'test.pdf', mimeType: 'application/pdf' });
    expect(result.valid).toBe(true);
  });
  it('rejects a file over 100MB', () => {
    const result = validateFile({ size: 101 * 1024 * 1024, name: 'huge.pdf', mimeType: 'application/pdf' });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('100MB');
  });
  it('rejects unsupported file types', () => {
    const result = validateFile({ size: 1024, name: 'virus.exe', mimeType: 'application/x-msdownload' });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('supported');
  });
});

describe('extractTextContent', () => {
  it('extracts text from plain text content', async () => {
    const result = await extractTextContent(
      Buffer.from('Hello, world!'),
      'text/plain',
      '.txt'
    );
    expect(result).toBe('Hello, world!');
  });
  it('extracts and formats JSON content', async () => {
    const json = JSON.stringify({ key: 'value' });
    const result = await extractTextContent(Buffer.from(json), 'application/json', '.json');
    expect(result).toContain('"key"');
    expect(result).toContain('"value"');
  });
  it('truncates text longer than 30000 chars', async () => {
    const longText = 'x'.repeat(50000);
    const result = await extractTextContent(Buffer.from(longText), 'text/plain', '.txt');
    expect(result.length).toBeLessThanOrEqual(30200); // 30K + truncation notice
    expect(result).toContain('truncated');
  });
  it('returns null for image files', async () => {
    const result = await extractTextContent(Buffer.from('fake-image'), 'image/png', '.png');
    expect(result).toBeNull();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npx vitest run tests/file-processor.test.ts
```
Expected: FAIL — module not found

**Step 3: Write the implementation**

Create `pfc-app/lib/engine/file-processor.ts`:

```typescript
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { extname, resolve } from 'path';
import { homedir } from 'os';

// ═══════════════════════════════════════════════════════════════════
// ██ FILE PROCESSOR — Classify, Validate, and Extract Text
// ═══════════════════════════════════════════════════════════════════

const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB
const MAX_TEXT_LENGTH = 30_000;

const IMAGE_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.webp']);
const TEXT_EXTENSIONS = new Set(['.txt', '.md']);
const DATA_EXTENSIONS = new Set(['.csv', '.json']);
const DOCUMENT_EXTENSIONS = new Set(['.pdf', '.docx', '.doc']);

const SUPPORTED_EXTENSIONS = new Set([
  ...IMAGE_EXTENSIONS,
  ...TEXT_EXTENSIONS,
  ...DATA_EXTENSIONS,
  ...DOCUMENT_EXTENSIONS,
]);

export type FileCategory = 'image' | 'text' | 'data' | 'document' | 'other';

/** Classify a file by its MIME type and extension */
export function classifyFile(mimeType: string, ext: string): FileCategory {
  const lowerExt = ext.toLowerCase();
  if (IMAGE_EXTENSIONS.has(lowerExt) || mimeType.startsWith('image/')) return 'image';
  if (TEXT_EXTENSIONS.has(lowerExt) || mimeType === 'text/plain' || mimeType === 'text/markdown') return 'text';
  if (DATA_EXTENSIONS.has(lowerExt) || mimeType === 'text/csv' || mimeType === 'application/json') return 'data';
  if (DOCUMENT_EXTENSIONS.has(lowerExt) || mimeType === 'application/pdf' || mimeType.includes('wordprocessingml')) return 'document';
  return 'other';
}

/** Validate file size and type */
export function validateFile(file: { size: number; name: string; mimeType: string }): { valid: boolean; error?: string } {
  if (file.size > MAX_FILE_SIZE) {
    return { valid: false, error: `File exceeds 100MB limit (${(file.size / 1024 / 1024).toFixed(1)}MB)` };
  }
  const ext = extname(file.name).toLowerCase();
  if (!SUPPORTED_EXTENSIONS.has(ext)) {
    return { valid: false, error: `File type ${ext} is not supported. Supported: ${[...SUPPORTED_EXTENSIONS].join(', ')}` };
  }
  return { valid: true };
}

/** Truncate text with notice if it exceeds the limit */
function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + `\n\n[...truncated, showing first ${maxLength.toLocaleString()} of ${text.length.toLocaleString()} chars]`;
}

/**
 * Extract text content from a file buffer.
 * Returns null for images (they go to vision API instead).
 */
export async function extractTextContent(
  buffer: Buffer,
  mimeType: string,
  ext: string,
): Promise<string | null> {
  const category = classifyFile(mimeType, ext);

  if (category === 'image') return null;

  if (category === 'text') {
    return truncateText(buffer.toString('utf-8'), MAX_TEXT_LENGTH);
  }

  if (category === 'data') {
    const raw = buffer.toString('utf-8');
    if (ext === '.json') {
      try {
        const parsed = JSON.parse(raw);
        return truncateText(JSON.stringify(parsed, null, 2), MAX_TEXT_LENGTH);
      } catch {
        return truncateText(raw, MAX_TEXT_LENGTH);
      }
    }
    // CSV — return as-is (already tabular)
    return truncateText(raw, MAX_TEXT_LENGTH);
  }

  if (category === 'document') {
    if (ext === '.pdf') {
      const pdfParse = (await import('pdf-parse')).default;
      const result = await pdfParse(buffer);
      return truncateText(result.text, MAX_TEXT_LENGTH);
    }
    if (ext === '.docx' || ext === '.doc') {
      const mammoth = await import('mammoth');
      const result = await mammoth.extractRawText({ buffer });
      return truncateText(result.value, MAX_TEXT_LENGTH);
    }
  }

  return truncateText(buffer.toString('utf-8'), MAX_TEXT_LENGTH);
}

/**
 * Resolve a file path from user query (handles ~ and relative paths).
 * Returns null if the file doesn't exist.
 */
export function resolveFilePath(rawPath: string): string | null {
  const expanded = rawPath.startsWith('~')
    ? rawPath.replace('~', homedir())
    : resolve(rawPath);
  return existsSync(expanded) ? expanded : null;
}

/**
 * Detect file paths in a query string.
 * Matches absolute paths (/...) and home-relative paths (~/ ...).
 */
export function detectFilePaths(query: string): string[] {
  const regex = /(?:\/[\w./-]+\.\w{2,5}|~\/[\w./-]+\.\w{2,5})/g;
  const matches = query.match(regex) || [];
  return matches.filter((p) => {
    const ext = extname(p).toLowerCase();
    return SUPPORTED_EXTENSIONS.has(ext);
  });
}

/**
 * Read a file from disk and return its buffer + metadata.
 */
export async function readFileFromDisk(filePath: string): Promise<{
  buffer: Buffer;
  name: string;
  size: number;
  mimeType: string;
  ext: string;
} | null> {
  const resolved = resolveFilePath(filePath);
  if (!resolved) return null;

  const buffer = await readFile(resolved);
  const ext = extname(resolved).toLowerCase();
  const name = resolved.split('/').pop() || 'unknown';

  const mimeMap: Record<string, string> = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.pdf': 'application/pdf',
    '.txt': 'text/plain',
    '.md': 'text/markdown',
    '.csv': 'text/csv',
    '.json': 'application/json',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.doc': 'application/msword',
  };

  return {
    buffer,
    name,
    size: buffer.length,
    mimeType: mimeMap[ext] || 'application/octet-stream',
    ext,
  };
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run tests/file-processor.test.ts
```
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/engine/file-processor.ts tests/file-processor.test.ts
git commit -m "feat: add file processor module with classify, validate, and extract"
```

---

### Task 3: Add Database Schema Column for Attachments

**Files:**
- Modify: `pfc-app/lib/db/schema.ts` (line ~39, before `createdAt`)
- Modify: `pfc-app/lib/db/queries.ts` (lines ~89-130, saveMessage function)

**Step 1: Add `attachments` column to schema**

In `pfc-app/lib/db/schema.ts`, add after the `mode` column (line ~38):

```typescript
  attachments: text('attachments'), // JSON array of FileAttachment metadata
```

**Step 2: Update saveMessage to accept and persist attachments**

In `pfc-app/lib/db/queries.ts`, update the `saveMessage` function parameter interface to include:

```typescript
  attachments?: string; // JSON stringified FileAttachment[]
```

And in the insert call, add:

```typescript
  attachments: params.attachments ?? null,
```

**Step 3: Run the app to ensure DB migration works**

SQLite with Drizzle — check how the app handles schema changes. If using `push`, running `npm run dev` should auto-migrate. If not, may need `npx drizzle-kit push`.

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npm run build
```
Expected: BUILD SUCCESS

**Step 4: Commit**

```bash
git add lib/db/schema.ts lib/db/queries.ts
git commit -m "feat: add attachments column to message table"
```

---

### Task 4: Wire Paperclip Button to Store

**Files:**
- Modify: `pfc-app/components/multimodal-input.tsx` (lines 583-599)

**Step 1: Replace the TODO handler**

Replace the `input.onchange` handler (lines 591-593) with:

```typescript
input.onchange = () => {
  const files = input.files;
  if (!files || files.length === 0) { cleanup(); return; }

  Array.from(files).forEach((file) => {
    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result as string;
      const ext = file.name.split('.').pop()?.toLowerCase() || '';
      const isImage = ['png', 'jpg', 'jpeg', 'webp'].includes(ext);
      store.addAttachment({
        id: `att-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        name: file.name,
        type: isImage ? 'image' : ext === 'pdf' ? 'pdf' : ext === 'csv' ? 'csv' : ext === 'txt' || ext === 'md' ? 'text' : 'other',
        uri: base64,
        size: file.size,
        mimeType: file.type,
        preview: isImage ? base64 : undefined,
      });
    };
    reader.readAsDataURL(file);
  });
  cleanup();
};
```

Note: Ensure `store` is accessible — check how other components access the Zustand store. Likely via `usePFCStore()` hook at the top of the component.

**Step 2: Verify the button works**

```bash
npm run dev
```
Open browser, click paperclip, select a file. Check React DevTools or console that `pendingAttachments` in the store gets populated.

**Step 3: Commit**

```bash
git add components/multimodal-input.tsx
git commit -m "feat: wire paperclip button to attachment store"
```

---

### Task 5: Add Attachment Preview Strip

**Files:**
- Modify: `pfc-app/components/multimodal-input.tsx`

**Step 1: Add preview strip between textarea and button row**

Add a new section between the textarea div and the button row. Read `pendingAttachments` from the store and render:

- For images: 48x48 thumbnail from the base64 `preview` field
- For documents: file type icon + filename + size in human-readable format
- Each has an ✕ button that calls `store.removeAttachment(id)`
- Only render the strip when `pendingAttachments.length > 0`

Style: a horizontal flex row with `gap: 0.5rem`, scrollable if many files, matching the existing dark/light theme variables.

**Step 2: Test visually**

```bash
npm run dev
```
Attach files, verify previews appear, verify ✕ removes them.

**Step 3: Commit**

```bash
git add components/multimodal-input.tsx
git commit -m "feat: add attachment preview strip to chat input"
```

---

### Task 6: Add Path Detection and Pass Attachments in Request

**Files:**
- Modify: `pfc-app/hooks/use-chat-stream.ts` (lines 56, 179-189)

**Step 1: Import and use detectFilePaths**

At the top of `use-chat-stream.ts`, the hook will need to read `pendingAttachments` from the store.

**Step 2: Modify sendQuery to include attachments and file paths**

In the fetch body (lines 179-189), add two new fields:

```typescript
...(store.pendingAttachments.length > 0 && {
  attachments: store.pendingAttachments.map((a) => ({
    id: a.id,
    name: a.name,
    type: a.type,
    uri: a.uri, // base64 data URL
    size: a.size,
    mimeType: a.mimeType,
  })),
}),
...(filePaths.length > 0 && { filePaths }),
```

Before the fetch call, detect file paths:

```typescript
// Detect file paths in query text
const filePathRegex = /(?:\/[\w./-]+\.\w{2,5}|~\/[\w./-]+\.\w{2,5})/g;
const filePaths = (query.match(filePathRegex) || []).filter((p) => {
  const ext = p.split('.').pop()?.toLowerCase() || '';
  return ['png','jpg','jpeg','webp','pdf','txt','md','csv','json','docx','doc'].includes(ext);
});
```

**Step 3: Clear attachments after send**

After the fetch call succeeds, call `store.clearAttachments()`.

**Step 4: Verify**

```bash
npm run build
```
Expected: BUILD SUCCESS

**Step 5: Commit**

```bash
git add hooks/use-chat-stream.ts
git commit -m "feat: pass attachments and file paths in chat request"
```

---

### Task 7: Process Attachments in API Route

**Files:**
- Modify: `pfc-app/app/(chat)/api/chat/route.ts` (lines 23-33, 98, 197-206)

**Step 1: Update ChatRequestBody interface**

Add to the interface (line ~33):

```typescript
  attachments?: unknown; // Array of { id, name, type, uri, size, mimeType }
  filePaths?: unknown;   // Array of file path strings detected in query
```

**Step 2: Increase body size limit**

Change line 98 from `10 * 1024 * 1024` to `150 * 1024 * 1024` (150MB).

**Step 3: Process attachments before pipeline**

After body parsing and before the pipeline call, add processing logic:

```typescript
import {
  classifyFile,
  validateFile,
  extractTextContent,
  readFileFromDisk,
} from '@/lib/engine/file-processor';
import { writeFile, mkdir } from 'fs/promises';
import { join, extname } from 'path';

// Process uploaded attachments (base64) + file paths
const processedAttachments: ProcessedAttachment[] = [];

// 1. Process base64 attachments from browser upload
if (Array.isArray(body.attachments)) {
  for (const att of body.attachments) {
    // Decode base64 data URL
    const base64Data = att.uri.split(',')[1];
    const buffer = Buffer.from(base64Data, 'base64');
    const ext = extname(att.name).toLowerCase();
    const category = classifyFile(att.mimeType, ext);

    // Save to uploads directory
    const uploadsDir = join(process.cwd(), 'uploads');
    await mkdir(uploadsDir, { recursive: true });
    const savedPath = join(uploadsDir, `${att.id}${ext}`);
    await writeFile(savedPath, buffer);

    const extractedText = await extractTextContent(buffer, att.mimeType, ext);

    processedAttachments.push({
      id: att.id,
      name: att.name,
      category,
      mimeType: att.mimeType,
      size: att.size,
      savedPath,
      base64: category === 'image' ? att.uri : undefined,
      extractedText,
    });
  }
}

// 2. Process file paths detected in query
if (Array.isArray(body.filePaths)) {
  for (const rawPath of body.filePaths) {
    const fileData = await readFileFromDisk(rawPath);
    if (!fileData) continue;
    const category = classifyFile(fileData.mimeType, fileData.ext);
    const extractedText = await extractTextContent(fileData.buffer, fileData.mimeType, fileData.ext);

    processedAttachments.push({
      id: `path-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      name: fileData.name,
      category,
      mimeType: fileData.mimeType,
      size: fileData.size,
      savedPath: rawPath,
      base64: category === 'image' ? `data:${fileData.mimeType};base64,${fileData.buffer.toString('base64')}` : undefined,
      extractedText,
    });
  }
}
```

**Step 4: Augment the query with extracted text**

Before passing to the pipeline, prepend extracted text to the query:

```typescript
let augmentedQuery = capturedQuery;
const textAttachments = processedAttachments.filter((a) => a.extractedText);
if (textAttachments.length > 0) {
  const attachmentContext = textAttachments
    .map((a) => `--- Attached file: ${a.name} ---\n${a.extractedText}\n--- End of ${a.name} ---`)
    .join('\n\n');
  augmentedQuery = `${attachmentContext}\n\n${capturedQuery}`;
}
```

**Step 5: Pass images to the pipeline context**

Collect image attachments separately:

```typescript
const imageAttachments = processedAttachments.filter((a) => a.category === 'image' && a.base64);
```

These will be passed through to the LLM generate functions (wired in Task 8).

**Step 6: Save attachment metadata with message**

When saving the user message to DB, include:

```typescript
attachments: processedAttachments.length > 0
  ? JSON.stringify(processedAttachments.map((a) => ({
      id: a.id,
      name: a.name,
      type: a.category,
      uri: a.savedPath,
      size: a.size,
      mimeType: a.mimeType,
    })))
  : undefined,
```

**Step 7: Verify**

```bash
npm run build
```
Expected: BUILD SUCCESS

**Step 8: Commit**

```bash
git add "app/(chat)/api/chat/route.ts"
git commit -m "feat: process file attachments in chat API route"
```

---

### Task 8: Pass Images to LLM via Vercel AI SDK Vision

**Files:**
- Modify: `pfc-app/lib/engine/llm/generate.ts` (lines 70-83)

**Step 1: Update llmStreamRawAnalysis to accept images**

Add an `images` parameter:

```typescript
export async function* llmStreamRawAnalysis(
  model: LanguageModel,
  qa: QueryAnalysis,
  signals: Partial<SignalUpdate>,
  steeringDirectives?: string,
  images?: Array<{ mimeType: string; base64: string }>,  // NEW
): AsyncGenerator<LLMStreamChunk>
```

**Step 2: Modify the streamText call to use multimodal content**

Replace the simple `prompt: prompt.user` with a `messages` array when images are present:

```typescript
const hasImages = images && images.length > 0;

const result = streamText({
  model,
  system: prompt.system,
  ...(hasImages
    ? {
        messages: [
          {
            role: 'user' as const,
            content: [
              ...images.map((img) => ({
                type: 'image' as const,
                image: img.base64.split(',')[1] || img.base64, // strip data URL prefix
                mimeType: img.mimeType,
              })),
              { type: 'text' as const, text: prompt.user },
            ],
          },
        ],
      }
    : { prompt: prompt.user }),
  maxOutputTokens: 2048,
  temperature: 0.7,
});
```

**Step 3: Update all callers to pass images through**

Trace back from `llmStreamRawAnalysis` to `runPipeline` and ensure the `images` parameter is threaded through. The pipeline runner needs to accept and forward the image data.

**Step 4: Verify**

```bash
npm run build
```
Expected: BUILD SUCCESS

**Step 5: Commit**

```bash
git add lib/engine/llm/generate.ts
git commit -m "feat: pass images to LLM via Vercel AI SDK vision content"
```

---

### Task 9: Render Attachments in Messages

**Files:**
- Modify: `pfc-app/components/message.tsx` (lines ~275-323 for user messages)

**Step 1: Add attachment rendering to user messages**

In the user message bubble section (around line 275-323), after the text content, check for `message.attachments` and render:

- **Images**: `<img>` tag with `object-fit: cover`, 64x64 thumbnail, rounded corners. Wrap in a clickable element that expands to full size (or opens in new tab).
- **Documents**: A small pill/badge showing file type icon + filename. Style: `display: inline-flex`, `gap: 4px`, `padding: 2px 8px`, `border-radius: 999px`, `background: rgba(...)`, `font-size: 0.75rem`.

Read the `attachments` field from the message. If it's a string (from DB), parse it: `JSON.parse(message.attachments)`. If it's already an array, use directly.

**Step 2: Test visually**

```bash
npm run dev
```
Send a message with an attachment, verify it renders in the message bubble.

**Step 3: Commit**

```bash
git add components/message.tsx
git commit -m "feat: render file attachment badges and image thumbnails in messages"
```

---

### Task 10: Add uploads/ to .gitignore and Create Directory

**Files:**
- Modify: `pfc-app/.gitignore` (or root `.gitignore`)

**Step 1: Add uploads directory to gitignore**

```
# User file uploads
uploads/
```

**Step 2: Ensure uploads dir is created on first use**

Already handled in Task 7 with `mkdir(uploadsDir, { recursive: true })`.

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add uploads/ to gitignore"
```

---

### Task 11: Simulation Mode Acknowledgment

**Files:**
- Modify: `pfc-app/lib/engine/simulate.ts` (wherever simulation text is generated)

**Step 1: Update simulation text generation**

When attachments are present in simulation mode, include acknowledgment in the simulated response:

```typescript
if (attachments && attachments.length > 0) {
  const fileList = attachments.map((a) => a.name).join(', ');
  // Prepend to simulated response
  simulatedText = `[Attached files: ${fileList}]\n\n${simulatedText}`;
}
```

**Step 2: Verify in simulation mode**

```bash
npm run dev
```
Attach a file, send query, verify simulation mode mentions the attachment.

**Step 3: Commit**

```bash
git add lib/engine/simulate.ts
git commit -m "feat: acknowledge attachments in simulation mode responses"
```

---

### Task 12: End-to-End Test and Final Build

**Step 1: Run all tests**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npx vitest run
```
Expected: ALL PASS

**Step 2: Production build**

```bash
npm run build
```
Expected: BUILD SUCCESS with zero errors

**Step 3: Manual e2e test**

1. Start dev server: `npm run dev`
2. Test paperclip: attach a PNG image → send → verify image thumbnail in message
3. Test paperclip: attach a PDF → send → verify document badge + LLM receives text
4. Test path detection: type "analyze ~/Desktop/test.txt" → send → verify file content in response
5. Test multiple files: attach 2 images + 1 PDF → send → verify all rendered
6. Test file size: attempt to attach something >100MB → verify rejection
7. Test simulation mode: switch to simulation, attach file → verify acknowledgment

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete multimodal file attachment support

End-to-end file attachment with:
- Paperclip upload (base64 over JSON)
- File path detection in query text
- Image vision input via Vercel AI SDK
- PDF/DOCX/TXT/CSV/JSON text extraction
- Attachment preview strip in input
- Attachment badges in messages
- 100MB file limit, 5 files per message
- Local filesystem storage in uploads/"
```

---

## Task Dependency Graph

```
Task 1 (deps)
    │
    ▼
Task 2 (file processor) ──────────┐
    │                              │
    ▼                              ▼
Task 3 (DB schema)          Task 4 (wire paperclip)
    │                              │
    │                              ▼
    │                        Task 5 (preview strip)
    │                              │
    ▼                              ▼
Task 7 (API route) ◄──── Task 6 (hook + path detection)
    │
    ▼
Task 8 (LLM vision)
    │
    ├──→ Task 9 (message rendering)
    ├──→ Task 10 (gitignore)
    └──→ Task 11 (simulation mode)
            │
            ▼
      Task 12 (e2e test)
```

**Parallelizable:** Tasks 4+5 can run in parallel with Task 3. Tasks 9, 10, 11 can run in parallel after Task 8.
