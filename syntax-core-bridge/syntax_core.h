//
//  syntax_core.h
//  Epistemos — syntax-core C FFI bridge
//
//  Viewport-scoped incremental syntax highlighting via tree-sitter + ropey.
//  All structs are #[repr(C)] with compile-time size assertions on the Rust side.
//

#ifndef SYNTAX_CORE_H
#define SYNTAX_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Opaque handle — Rust-allocated, Swift holds, Rust frees
// ---------------------------------------------------------------------------

typedef struct SyntaxDocument SyntaxDocument;

// ---------------------------------------------------------------------------
// FFI data shapes (matching syntax-core/src/lib.rs exactly)
// ---------------------------------------------------------------------------

/// Document identity + generation snapshot (16 bytes).
typedef struct {
    uint64_t doc_id;
    uint64_t generation;
} SyntaxDocumentHandle;

/// Edit delta returned after each mutation (48 bytes).
typedef struct {
    uint64_t doc_id;
    uint64_t from_generation;
    uint64_t to_generation;
    uint64_t byte_offset;
    uint64_t old_len;
    uint64_t new_len;
} SyntaxEditDelta;

/// Viewport request for scoped token generation (24 bytes).
typedef struct {
    uint64_t doc_id;
    uint64_t generation;
    uint32_t utf16_start;
    uint32_t utf16_end;
} SyntaxViewportRequest;

/// One syntax token — 12 bytes flat. UTF-16 offsets are document-global.
typedef struct {
    uint32_t utf16_start;
    uint16_t utf16_len;
    uint16_t kind_id;
    uint8_t  flags;
    uint8_t  _pad[3];
} SyntaxTokenSpan;

/// Collapsible code region (24 bytes).
typedef struct {
    uint64_t byte_start;
    uint64_t byte_end;
    uint16_t kind_id;
    uint8_t  _pad[6];
} SyntaxFoldRange;

/// Warning/error marker (24 bytes).
typedef struct {
    uint64_t byte_start;
    uint64_t byte_end;
    uint8_t  severity;
    uint8_t  _pad[7];
} SyntaxDiagnosticRange;

/// Parse telemetry snapshot (32 bytes).
typedef struct {
    uint64_t doc_id;
    uint64_t generation;
    uint32_t node_count;
    uint32_t error_count;
    uint64_t parse_time_us;
} SyntaxSnapshotStats;

// ---------------------------------------------------------------------------
// Document lifecycle
// ---------------------------------------------------------------------------

/// Create a new syntax document for the given language and source text.
/// @param doc_id       Stable document identifier.
/// @param language     Null-terminated language name (e.g. "swift", "rust", "python").
/// @param source       UTF-8 source text (not necessarily null-terminated).
/// @param source_len   Length of source in bytes.
/// @return Heap-allocated document pointer, or NULL if the language is unknown.
SyntaxDocument* syntax_document_create(
    uint64_t doc_id,
    const char* language,
    const char* source,
    uint32_t source_len
);

/// Free a document previously created by syntax_document_create.
/// @param doc  Document pointer, or NULL (no-op).
void syntax_document_free(SyntaxDocument* doc);

// ---------------------------------------------------------------------------
// Document mutation
// ---------------------------------------------------------------------------

/// Apply an edit and trigger incremental reparse.
/// @param doc          Non-null document pointer.
/// @param byte_start   UTF-8 byte offset where the edit begins.
/// @param old_len      Number of bytes removed.
/// @param new_text     Replacement UTF-8 text.
/// @param new_text_len Length of new_text in bytes.
/// @return Edit delta describing the change. Zero delta on error.
SyntaxEditDelta syntax_document_edit(
    SyntaxDocument* doc,
    uint64_t byte_start,
    uint64_t old_len,
    const char* new_text,
    uint32_t new_text_len
);

// ---------------------------------------------------------------------------
// Document queries
// ---------------------------------------------------------------------------

/// Get the document's current handle (doc_id + generation).
SyntaxDocumentHandle syntax_document_handle(const SyntaxDocument* doc);

/// Get the document's current generation counter.
uint64_t syntax_document_generation(const SyntaxDocument* doc);

/// Get parse statistics for the current tree.
SyntaxSnapshotStats syntax_document_stats(const SyntaxDocument* doc);

// ---------------------------------------------------------------------------
// Viewport-scoped token generation
// ---------------------------------------------------------------------------

/// Produce syntax tokens for a byte range (typically the visible viewport).
///
/// Tokens are written into the caller-provided buffer. UTF-16 offsets
/// in the tokens are document-global (not relative to byte_start).
///
/// @param doc          Non-null document pointer.
/// @param language     Null-terminated language name (must match the document's language).
/// @param byte_start   Start of the visible byte range.
/// @param byte_end     End of the visible byte range.
/// @param out_buf      Pre-allocated buffer for output tokens.
/// @param max_tokens   Capacity of out_buf.
/// @return Number of tokens written. 0 on error or empty viewport.
uint32_t syntax_document_tokens_for_viewport(
    SyntaxDocument* doc,
    const char* language,
    uint64_t byte_start,
    uint64_t byte_end,
    SyntaxTokenSpan* out_buf,
    uint32_t max_tokens
);

/// Resolve a `kind_id` (assigned by the per-document `TokenRegistry`)
/// back into the original tree-sitter capture name (e.g. "comment",
/// "string", "function.def").
///
/// The capture name is written to `out_buf` as UTF-8 *without* a
/// null terminator. The caller MUST use the returned length, not
/// `strlen`.
///
/// @param doc          Non-null document pointer.
/// @param kind_id      Kind ID from a SyntaxTokenSpan.
/// @param out_buf      Pre-allocated buffer for the UTF-8 name bytes.
/// @param out_buf_cap  Capacity of out_buf in bytes.
/// @return Number of bytes written. 0 on error, missing registration,
///         or insufficient buffer (truncation is refused — silently
///         truncating UTF-8 would corrupt the Swift-side String).
///         `kind_id == 0` returns the literal name "unknown" (7 bytes).
uint32_t syntax_document_kind_name(
    const SyntaxDocument* doc,
    uint16_t kind_id,
    uint8_t* out_buf,
    uint32_t out_buf_cap
);

#ifdef __cplusplus
}
#endif

#endif /* SYNTAX_CORE_H */
