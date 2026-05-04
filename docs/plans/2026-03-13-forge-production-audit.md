# Forge Production Audit

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Date: March 13, 2026
Scope: current uncommitted app state after the recent styling, editor, and chat changes

## What This Pass Verified

- Read the current repo audit docs, the external hardening/concurrency research notes, and the recent dirty-file surface area.
- Verified the new chat attachment path with a regression-first test cycle.
- Verified the command-palette markdown import path with a regression-first test cycle.
- Verified the shared note-image import/OCR path with a regression-first test cycle.
- Ran `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/NoteImageProcessorTests -only-testing:EpistemosTests/FileAttachmentBuilderTests -only-testing:EpistemosTests/VaultImportFileCopierTests test`.
- Ran `cargo test -q` in `graph-engine`.

Results:

- Swift targeted regression suites: 8 tests passed
- Rust engine suite: 2373 tests passed

## Fix Landed

### Chat attachment ingest no longer blocks on synchronous preview reads

Problem:

- The chat file picker built attachment previews inline on the open-panel callback path.
- Text and CSV attachments used `String(contentsOf:)` directly, which read full file contents on the main thread.
- Large attachments could stall the app during selection.

Fix:

- Added a bounded `FileAttachmentBuilder` utility behind the chat input path.
- Attachment building now runs off the main actor on utility priority.
- Preview reads are capped to `262_144` bytes.
- Oversized text attachments skip preview generation entirely.
- Small text previews still preserve the existing 2000-character truncation contract.
- Multi-file selection preserves the original selection order.

Proof:

- `EpistemosTests/FileAttachmentBuilderTests.swift` covers:
  - truncated previews for normal text files
  - no preview for oversized text files
  - CSV preview behavior

### Command palette markdown import no longer copies on the main actor

Problem:

- The landing command palette copied every selected markdown file inline after the open panel closed.
- Large imports could pin the main actor before vault sync even started.

Fix:

- Added `VaultImportFileCopier` behind the command-palette import action.
- File copies now run in a detached utility-priority task.
- UI updates and vault sync only hop back to `@MainActor` after the copy phase completes.
- Conflicting filenames are skipped instead of aborting the full import batch.

Proof:

- `EpistemosTests/VaultImportFileCopierTests.swift` covers:
  - successful copy into the vault destination
  - conflict handling without aborting the rest of the batch

### Note editor image insertion and OCR no longer decode on the main actor

Problem:

- Both `ClickableTextView` and `ProseTextView2` synchronously decoded selected images before insertion.
- OCR also built `CGImage` inputs inline on the editor path, which amplified hitches on large files.
- The same stall-prone logic was duplicated across both editor stacks.

Fix:

- Extracted a shared `NoteImageProcessor` used by both TextKit 1 and TextKit 2 editors.
- Image metadata, thumbnail creation, and OCR source decoding now run in detached user-initiated tasks.
- Large images are thumbnail-decoded to the editor width limit instead of always loading full-size display images.
- Text insertion now resumes on `@MainActor` only after the background work finishes.

Proof:

- `EpistemosTests/NoteImageProcessorTests.swift` covers:
  - large-image downscaling to the editor width cap
  - small-image passthrough sizing
  - invalid-file nil handling for both display-image loading and OCR extraction

## Current Delta Findings

These are still the highest-signal risks in the post-audit dirty worktree.

1. `Epistemos/Views/Landing/CommandPaletteOverlay.swift`
   The import path is now offloaded, but the file still has a broad dirty diff from adjacent user changes. It needs a follow-up read before any more edits land there.

2. `Epistemos/Views/Notes/ClickableTextView.swift`
   The shared image/OCR processor is in place, but the file still carries existing Swift 6 isolation warnings around Quick Look panel delegate wiring.

3. `Epistemos/Views/Notes/ProseTextView2.swift`
   The same image/OCR stall is fixed here, but the file still has existing isolation warnings unrelated to this pass.

4. `Epistemos/Views/MiniChat/MiniChatView.swift`
   MiniChat still performs repeated `page.loadBody()` disk reads inside request construction and vault search. It is not a correctness bug, but it remains a latency multiplier on larger notes.

5. Repo-wide warnings remain
   Current Xcode builds still emit existing concurrency/isolation warnings unrelated to this patch, especially ineffective `nonisolated(unsafe)` annotations and several stale test warnings.

## Next Queue

1. Collapse repeated `loadBody()` calls in MiniChat into one body snapshot per page per request.
2. Run a warning-focused cleanup pass for the current Swift 6 isolation warnings, starting with real source files before test-only cleanup.
3. Audit the remaining synchronous disk/image paths outside notes and chat export flows, especially save/export utilities that still use modal AppKit APIs.
4. Re-run a broader Swift regression slice after the next optimization wave so the hardening pass is not limited to targeted suites.

## State Block

- INDEX_VERSION: 2026-03-13.1
- FILE_MAP_SUMMARY:
  - Fixed: `Epistemos/Views/Chat/ChatInputBar.swift`
  - Fixed: `Epistemos/Views/Landing/CommandPaletteOverlay.swift`
  - Fixed: `Epistemos/Views/Notes/ClickableTextView.swift`
  - Fixed: `Epistemos/Views/Notes/ProseTextView2.swift`
  - Added tests: `EpistemosTests/FileAttachmentBuilderTests.swift`
  - Added tests: `EpistemosTests/VaultImportFileCopierTests.swift`
  - Added tests: `EpistemosTests/NoteImageProcessorTests.swift`
  - Updated project wiring: `Epistemos.xcodeproj/project.pbxproj`
- CRITICAL_FIXES:
  - moved chat attachment preview generation off the main thread
  - bounded preview reads to prevent large text files from hanging the UI
  - moved command-palette markdown import copies off the main thread
  - removed synchronous image decode/OCR setup from both note editor stacks
- OPEN_REENTRANCY_RISKS:
  - MiniChat still repeats note-body disk reads in a single request path
  - repo still has real Swift 6 isolation warnings that need source-level cleanup
- NEXT_READ_QUEUE:
  - `Epistemos/Views/MiniChat/MiniChatView.swift`
  - `Epistemos/Views/Notes/ClickableTextView.swift`
  - `Epistemos/Views/Notes/ProseTextView2.swift`
  - `Epistemos/Views/Chat/MessageBubble.swift`
