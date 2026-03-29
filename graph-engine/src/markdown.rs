// MARK: - Rust Markdown Parser (pulldown-cmark FFI bridge)
//
// Replaces the 7 regex passes in MarkdownTextStorage with a single
// pulldown-cmark parse. Returns an array of StyleSpan structs via FFI.
// Swift calls markdown_parse(), iterates spans, applies NSAttributedString
// attributes, then calls markdown_free_spans() to deallocate.
//
// Extensions beyond CommonMark:
// - [[wikilinks]] — custom post-parse pass
// - $inline math$ — custom post-parse pass (pulldown-cmark doesn't handle $)

use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
use std::ffi::CStr;
use std::os::raw::c_char;

/// Style kind enum — matches Swift-side StyleKind for attribute mapping.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StyleKind {
    Heading1 = 0,
    Heading2 = 1,
    Heading3 = 2,
    Heading4 = 3,
    Bold = 4,
    Italic = 5,
    Strikethrough = 6,
    InlineCode = 7,
    CodeBlock = 8,
    CodeFence = 9,
    BlockQuote = 10,
    UnorderedList = 11,
    OrderedList = 12,
    Checkbox = 13,
    CheckboxChecked = 14,
    Wikilink = 15,
    WikilinkBrackets = 16,
    MarkdownLink = 17,
    LinkSyntax = 18,
    InlineMath = 19,
    Table = 20,
    TableHeader = 21,
    HorizontalRule = 22,
    Callout = 23,
    BlockReference = 24,
    BlockReferenceBrackets = 25,
    DisplayMath = 26,
}

/// A styled range returned to Swift via FFI.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StyleSpan {
    pub start: u32,
    pub end: u32,
    pub style: u8,
    pub depth: u8,
    pub group: u8,
    pub _pad: u8,
}

/// Parse markdown text and return styled spans.
fn parse_markdown(text: &str) -> Vec<StyleSpan> {
    let mut spans = Vec::new();
    let opts = Options::ENABLE_TABLES | Options::ENABLE_STRIKETHROUGH | Options::ENABLE_TASKLISTS;

    let parser = Parser::new_ext(text, opts);

    // Stack tracks open tags with their byte offsets.
    let mut tag_stack: Vec<(Tag<'_>, usize)> = Vec::new();

    for (event, range) in parser.into_offset_iter() {
        match event {
            Event::Start(tag) => {
                tag_stack.push((tag, range.start));
            }
            Event::End(tag_end) => {
                if let Some((_tag, start)) = tag_stack.pop() {
                    let end = range.end;
                    match tag_end {
                        TagEnd::Heading(level) => {
                            let style = match level as i32 {
                                1 => StyleKind::Heading1,
                                2 => StyleKind::Heading2,
                                3 => StyleKind::Heading3,
                                _ => StyleKind::Heading4,
                            };
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: style as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::Emphasis => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::Italic as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::Strong => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::Bold as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::Strikethrough => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::Strikethrough as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::BlockQuote(_) => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::BlockQuote as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::List(true) => {
                            // Ordered list container — individual items handled below
                        }
                        TagEnd::List(false) => {
                            // Unordered list container
                        }
                        TagEnd::Link => {
                            // Full link span [text](url)
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::MarkdownLink as u8,
                                depth: 0,
                                group: 1, // text content
                                _pad: 0,
                            });
                        }
                        TagEnd::Table => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::Table as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        TagEnd::TableHead => {
                            spans.push(StyleSpan {
                                start: start as u32,
                                end: end as u32,
                                style: StyleKind::TableHeader as u8,
                                depth: 0,
                                group: 0,
                                _pad: 0,
                            });
                        }
                        _ => {}
                    }
                }
            }
            Event::Code(_) => {
                spans.push(StyleSpan {
                    start: range.start as u32,
                    end: range.end as u32,
                    style: StyleKind::InlineCode as u8,
                    depth: 0,
                    group: 0,
                    _pad: 0,
                });
            }
            Event::Rule => {
                spans.push(StyleSpan {
                    start: range.start as u32,
                    end: range.end as u32,
                    style: StyleKind::HorizontalRule as u8,
                    depth: 0,
                    group: 0,
                    _pad: 0,
                });
            }
            Event::TaskListMarker(checked) => {
                let style = if checked {
                    StyleKind::CheckboxChecked
                } else {
                    StyleKind::Checkbox
                };
                spans.push(StyleSpan {
                    start: range.start as u32,
                    end: range.end as u32,
                    style: style as u8,
                    depth: 0,
                    group: 0,
                    _pad: 0,
                });
            }
            _ => {}
        }
    }

    // Post-parse: extract [[wikilinks]]
    extract_wikilinks(text, &mut spans);

    // Post-parse: extract $$display math$$ (before inline to take priority)
    extract_display_math(text, &mut spans);

    // Post-parse: extract $inline math$
    extract_inline_math(text, &mut spans);

    // Post-parse: extract ((block references))
    extract_block_references(text, &mut spans);

    spans
}

/// Extract [[wikilink]] syntax (not part of CommonMark).
fn extract_wikilinks(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        if bytes[i] == b'['
            && bytes[i + 1] == b'['
            && let Some(close_offset) = text[i + 2..].find("]]")
        {
            let content_start = i + 2;
            let content_end = content_start + close_offset;
            let full_end = content_end + 2;

            // Opening brackets [[
            spans.push(StyleSpan {
                start: i as u32,
                end: content_start as u32,
                style: StyleKind::WikilinkBrackets as u8,
                depth: 0,
                group: 0,
                _pad: 0,
            });
            // Content
            spans.push(StyleSpan {
                start: content_start as u32,
                end: content_end as u32,
                style: StyleKind::Wikilink as u8,
                depth: 0,
                group: 1,
                _pad: 0,
            });
            // Closing brackets ]]
            spans.push(StyleSpan {
                start: content_end as u32,
                end: full_end as u32,
                style: StyleKind::WikilinkBrackets as u8,
                depth: 0,
                group: 2,
                _pad: 0,
            });
            i = full_end;
            continue;
        }
        i += 1;
    }
}

/// Extract $inline math$ syntax (not part of CommonMark).
/// Avoids $$ (display math) and escaped \$.
fn extract_inline_math(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'$'
            && (i + 1 < bytes.len() && bytes[i + 1] != b'$')
            && (i == 0 || bytes[i - 1] != b'\\')
        {
            // Find closing $
            if let Some(close_offset) = text[i + 1..].find('$') {
                let end = i + 1 + close_offset + 1;
                // Ensure closing $ is not $$
                if end < bytes.len() && bytes[end] == b'$' {
                    i = end + 1;
                    continue;
                }
                spans.push(StyleSpan {
                    start: i as u32,
                    end: end as u32,
                    style: StyleKind::InlineMath as u8,
                    depth: 0,
                    group: 0,
                    _pad: 0,
                });
                i = end;
                continue;
            }
        }
        i += 1;
    }
}

/// Extract display math blocks: $$...$$ (possibly multi-line).
fn extract_display_math(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        if bytes[i] == b'$' && bytes[i + 1] == b'$' {
            let start = i;
            let mut j = i + 2;
            while j + 1 < bytes.len() {
                if bytes[j] == b'$' && bytes[j + 1] == b'$' {
                    let end = j + 2;
                    spans.push(StyleSpan {
                        start: start as u32,
                        end: end as u32,
                        style: StyleKind::DisplayMath as u8,
                        depth: 0,
                        group: 0,
                        _pad: 0,
                    });
                    i = end;
                    break;
                }
                j += 1;
            }
            if j + 1 >= bytes.len() {
                break; // no closing found
            }
        } else {
            i += 1;
        }
    }
}

/// Extract ((block-reference)) syntax — Logseq-style block transclusion.
/// Follows the exact same pattern as extract_wikilinks.
fn extract_block_references(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        if bytes[i] == b'('
            && bytes[i + 1] == b'('
            && let Some(close_offset) = text[i + 2..].find("))")
        {
            let content_start = i + 2;
            let content_end = content_start + close_offset;
            let full_end = content_end + 2;

            // Skip empty references (( ))
            let content = &text[content_start..content_end];
            if content.trim().is_empty() {
                i += 2;
                continue;
            }

            // Opening brackets ((
            spans.push(StyleSpan {
                start: i as u32,
                end: content_start as u32,
                style: StyleKind::BlockReferenceBrackets as u8,
                depth: 0,
                group: 0,
                _pad: 0,
            });
            // Content (block ID)
            spans.push(StyleSpan {
                start: content_start as u32,
                end: content_end as u32,
                style: StyleKind::BlockReference as u8,
                depth: 0,
                group: 1,
                _pad: 0,
            });
            // Closing brackets ))
            spans.push(StyleSpan {
                start: content_end as u32,
                end: full_end as u32,
                style: StyleKind::BlockReferenceBrackets as u8,
                depth: 0,
                group: 2,
                _pad: 0,
            });
            i = full_end;
            continue;
        }
        i += 1;
    }
}

// ── Structure Parser (Paragraph-Level Classification) ──────────────────────

/// Paragraph type for structural classification.
/// One span per line — array index is the line number.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ParaType {
    Body = 0,
    Heading = 1,
    OrderedList = 2,
    UnorderedList = 3,
    TaskList = 4,
    BlockQuote = 5,
    CodeBlock = 6,
    Table = 7,
    HorizontalRule = 8,
    HtmlComment = 9,
}

/// Structure span — 4 bytes per line. Array index is the line number.
/// Metadata packing: heading level (1-6), list depth (high byte), etc.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct StructureSpan {
    pub para_type: u8,
    pub _pad: u8,
    pub metadata: u16,
}

/// Classify each line in the document. Returns one span per line.
pub fn parse_structure(text: &str) -> Vec<StructureSpan> {
    if text.is_empty() {
        return Vec::new();
    }

    let lines: Vec<&str> = text.split('\n').collect();
    let mut spans = Vec::with_capacity(lines.len());
    let mut in_code_block = false;
    let mut code_block_lang: u8 = 0;
    let mut in_html_comment = false;
    let mut active_callout_type: u8 = 0;

    for line in &lines {
        let trimmed = line.trim_start();
        let indent = line.len() - trimmed.len();

        // Code block state machine
        if in_code_block {
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: code_block_lang as u16,
            });
            if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
                in_code_block = false;
                code_block_lang = 0;
            }
            continue;
        }

        // HTML comment state machine
        if in_html_comment {
            spans.push(StructureSpan {
                para_type: ParaType::HtmlComment as u8,
                _pad: 0,
                metadata: 0,
            });
            if trimmed.contains("-->") {
                in_html_comment = false;
            }
            continue;
        }

        // Empty line
        if trimmed.is_empty() {
            spans.push(StructureSpan {
                para_type: ParaType::Body as u8,
                _pad: 0,
                metadata: 0,
            });
            continue;
        }

        // Code fence opening
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_code_block = true;
            let lang_tag = trimmed[3..].trim();
            code_block_lang = language_id_from_str(lang_tag);
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: code_block_lang as u16,
            });
            continue;
        }

        // HTML comment
        if trimmed.starts_with("<!--") {
            if trimmed.contains("-->") {
                spans.push(StructureSpan {
                    para_type: ParaType::HtmlComment as u8,
                    _pad: 0,
                    metadata: 0,
                });
            } else {
                in_html_comment = true;
                spans.push(StructureSpan {
                    para_type: ParaType::HtmlComment as u8,
                    _pad: 0,
                    metadata: 0,
                });
            }
            continue;
        }

        // Heading
        if let Some(level) = detect_heading_level(trimmed) {
            spans.push(StructureSpan {
                para_type: ParaType::Heading as u8,
                _pad: 0,
                metadata: level as u16,
            });
            continue;
        }

        // Horizontal rule (must check before unordered list since --- overlaps)
        if is_horizontal_rule(trimmed) {
            spans.push(StructureSpan {
                para_type: ParaType::HorizontalRule as u8,
                _pad: 0,
                metadata: 0,
            });
            continue;
        }

        // Blockquote (plain or callout)
        if trimmed.starts_with('>') {
            let depth = count_blockquote_depth(trimmed);
            let callout = detect_callout_type(trimmed);
            if callout > 0 {
                active_callout_type = callout;
            }
            let metadata = (depth as u16) | ((active_callout_type as u16) << 8);
            spans.push(StructureSpan {
                para_type: ParaType::BlockQuote as u8,
                _pad: 0,
                metadata,
            });
            continue;
        }

        // Reset callout tracking on any non-blockquote line
        active_callout_type = 0;

        // Table (line starting with |)
        if trimmed.starts_with('|') {
            spans.push(StructureSpan {
                para_type: ParaType::Table as u8,
                _pad: 0,
                metadata: 0,
            });
            continue;
        }

        // Task list (must check before unordered list)
        if let Some((depth, checked)) = detect_task_list(trimmed, indent) {
            let meta = ((depth as u16) << 8) | (checked as u16);
            spans.push(StructureSpan {
                para_type: ParaType::TaskList as u8,
                _pad: 0,
                metadata: meta,
            });
            continue;
        }

        // Unordered list
        if let Some(depth) = detect_unordered_list(trimmed, indent) {
            spans.push(StructureSpan {
                para_type: ParaType::UnorderedList as u8,
                _pad: 0,
                metadata: depth as u16,
            });
            continue;
        }

        // Ordered list
        if let Some((depth, start_index)) = detect_ordered_list(trimmed, indent) {
            let meta = ((depth as u16) << 8) | (start_index.min(255) as u16);
            spans.push(StructureSpan {
                para_type: ParaType::OrderedList as u8,
                _pad: 0,
                metadata: meta,
            });
            continue;
        }

        // Default: body
        spans.push(StructureSpan {
            para_type: ParaType::Body as u8,
            _pad: 0,
            metadata: 0,
        });
    }

    spans
}

fn detect_heading_level(trimmed: &str) -> Option<u8> {
    let bytes = trimmed.as_bytes();
    let mut count = 0u8;
    for &b in bytes {
        if b == b'#' {
            count += 1;
        } else if b == b' ' && count > 0 {
            return if count <= 6 { Some(count) } else { None };
        } else {
            return None;
        }
    }
    None
}

fn is_horizontal_rule(trimmed: &str) -> bool {
    if trimmed.len() < 3 {
        return false;
    }
    let first = trimmed.as_bytes()[0];
    if first != b'-' && first != b'*' && first != b'_' {
        return false;
    }
    trimmed.bytes().all(|b| b == first || b == b' ')
}

fn count_blockquote_depth(trimmed: &str) -> u8 {
    let mut depth = 0u8;
    for &b in trimmed.as_bytes() {
        if b == b'>' {
            depth = depth.saturating_add(1);
        } else if b == b' ' {
            continue;
        } else {
            break;
        }
    }
    depth
}

/// Detect callout type from a blockquote line: `> [!type]` or `> [!type] Title`.
/// Returns 0 for plain blockquote, 1-9 for callout types.
fn detect_callout_type(trimmed: &str) -> u8 {
    let inner = trimmed.trim_start_matches(['>', ' ']);
    if !inner.starts_with("[!") {
        return 0;
    }
    let after = &inner[2..];
    let end = match after.find(']') {
        Some(i) => i,
        None => return 0,
    };
    match after[..end].trim() {
        "note" | "info" => 1,
        "tip" | "hint" | "important" => 2,
        "warning" | "caution" | "attention" => 3,
        "success" | "check" | "done" => 4,
        "question" | "help" | "faq" => 5,
        "quote" | "cite" => 6,
        "danger" | "error" | "bug" | "fail" | "failure" => 7,
        "example" => 8,
        "abstract" | "summary" | "tldr" => 9,
        _ => 1, // unknown callout defaults to "note"
    }
}

fn detect_task_list(trimmed: &str, indent: usize) -> Option<(u8, u8)> {
    let rest = trimmed
        .strip_prefix("- ")
        .or_else(|| trimmed.strip_prefix("* "))
        .or_else(|| trimmed.strip_prefix("+ "))?;

    if rest == "[ ]" || rest.starts_with("[ ] ") {
        Some(((indent / 2) as u8, 0))
    } else if rest == "[x]" || rest.starts_with("[x] ") || rest == "[X]" || rest.starts_with("[X] ")
    {
        Some(((indent / 2) as u8, 1))
    } else {
        None
    }
}

fn detect_unordered_list(trimmed: &str, indent: usize) -> Option<u8> {
    let rest = trimmed
        .strip_prefix("- ")
        .or_else(|| trimmed.strip_prefix("* "))
        .or_else(|| trimmed.strip_prefix("+ "))?;

    // Exclude task list patterns (already handled above, but defensive)
    if rest.starts_with("[ ] ") || rest.starts_with("[x] ") || rest.starts_with("[X] ") {
        return None;
    }
    Some((indent / 2) as u8)
}

fn detect_ordered_list(trimmed: &str, indent: usize) -> Option<(u8, u32)> {
    let bytes = trimmed.as_bytes();
    let mut num_end = 0usize;
    for &b in bytes {
        if b.is_ascii_digit() {
            num_end += 1;
        } else {
            break;
        }
    }
    if num_end == 0 || num_end + 1 >= bytes.len() {
        return None;
    }
    if bytes[num_end] != b'.' && bytes[num_end] != b')' {
        return None;
    }
    if bytes[num_end + 1] != b' ' {
        return None;
    }
    let num: u32 = trimmed[..num_end].parse().ok()?;
    Some(((indent / 2) as u8, num))
}

// ── FFI ──────────────────────────────────────────────────────────────────

macro_rules! markdown_catch_unwind {
    ($name:expr, $body:block) => {{
        if std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)).is_err() {
            eprintln!("{}: panic caught", $name);
        }
    }};
}

macro_rules! markdown_catch_unwind_or {
    ($name:expr, $default:expr, $body:block) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(result) => result,
            Err(_) => {
                eprintln!("{}: panic caught", $name);
                $default
            }
        }
    }};
}

/// Parse markdown structure: one StructureSpan per line, written to pre-allocated buffer.
/// Returns the number of lines (spans written). Returns 0 on null/invalid input.
///
/// # Safety
/// `text` must be a valid null-terminated UTF-8 C string.
/// `out_spans` must point to a buffer of at least `max_spans` StructureSpan elements.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_parse_structure(
    text: *const c_char,
    out_spans: *mut StructureSpan,
    max_spans: u32,
) -> u32 {
    markdown_catch_unwind_or!("markdown_parse_structure", 0, {
        if text.is_null() || out_spans.is_null() || max_spans == 0 {
            return 0;
        }

        // SAFETY: text is a valid null-terminated C string per FFI contract.
        let c_str = unsafe { CStr::from_ptr(text) };
        let rust_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        };

        let spans = parse_structure(rust_str);
        let count = spans.len().min(max_spans as usize);

        // SAFETY: out_spans buffer has capacity for at least max_spans elements.
        unsafe {
            std::ptr::copy_nonoverlapping(spans.as_ptr(), out_spans, count);
        }

        count as u32
    })
}

/// Parse markdown text and return an array of StyleSpans.
/// Returns 0 on success, 1 on error (null pointer or invalid UTF-8).
///
/// # Safety
/// `text` must be a valid null-terminated UTF-8 C string.
/// `out_spans` and `out_count` must be valid pointers.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_parse(
    text: *const c_char,
    _text_len: u32,
    out_spans: *mut *mut StyleSpan,
    out_count: *mut u32,
) -> u8 {
    markdown_catch_unwind_or!("markdown_parse", 1, {
        if text.is_null() || out_spans.is_null() || out_count.is_null() {
            return 1;
        }

        let c_str = unsafe { CStr::from_ptr(text) };
        let rust_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return 1,
        };

        let spans = parse_markdown(rust_str);

        if spans.is_empty() {
            unsafe {
                *out_spans = std::ptr::null_mut();
                *out_count = 0;
            }
            return 0;
        }

        let count = spans.len();
        let layout = std::alloc::Layout::array::<StyleSpan>(count).unwrap();
        let ptr = unsafe { std::alloc::alloc(layout) as *mut StyleSpan };
        if ptr.is_null() {
            return 1;
        }

        unsafe {
            std::ptr::copy_nonoverlapping(spans.as_ptr(), ptr, count);
            *out_spans = ptr;
            *out_count = count as u32;
        }

        0
    })
}

/// Free a spans array previously returned by `markdown_parse`.
///
/// # Safety
/// `spans` must be a pointer returned by `markdown_parse`, and `count` must
/// match the count returned with it.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_free_spans(spans: *mut StyleSpan, count: u32) {
    markdown_catch_unwind!("markdown_free_spans", {
        if spans.is_null() || count == 0 {
            return;
        }
        let layout = match std::alloc::Layout::array::<StyleSpan>(count as usize) {
            Ok(l) => l,
            Err(_) => return,
        };
        unsafe {
            std::alloc::dealloc(spans as *mut u8, layout);
        }
    });
}

// ── Code Tokenization (FFI contract for Swift code block rendering) ──────

/// Token classification for syntax-highlighted code spans.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TokenType {
    Keyword = 0,
    String = 1,
    Number = 2,
    Comment = 3,
    Function = 4,
    Type = 5,
    Operator = 6,
    Punctuation = 7,
    Variable = 8,
    Property = 9,
    Constant = 10,
    Tag = 11,
    Attribute = 12,
    Plain = 255,
}

/// A single code token span — 12 bytes, C-compatible.
/// Array of these is passed across FFI to Swift for code block rendering.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct CodeToken {
    pub start: u32,
    pub end: u32,
    pub token_type: u8,
    pub _pad: [u8; 3],
}

/// Map a language name (from fenced code block info string) to a compact ID.
/// Case-insensitive. Returns 0 for unknown languages.
pub fn language_id_from_str(lang: &str) -> u8 {
    match lang.to_ascii_lowercase().as_str() {
        "swift" => 1,
        "rust" | "rs" => 2,
        "python" | "py" => 3,
        "javascript" | "js" | "jsx" => 4,
        "typescript" | "ts" | "tsx" => 5,
        "json" => 6,
        "html" | "htm" => 7,
        "css" | "scss" | "less" => 8,
        "bash" | "sh" | "shell" | "zsh" => 9,
        "go" | "golang" => 10,
        "c" | "h" => 11,
        "cpp" | "c++" | "cc" | "cxx" | "hpp" => 12,
        _ => 0,
    }
}

/// Parse a fenced code block and write syntax tokens into a caller-owned buffer.
/// Returns the number of tokens written. 0 on unsupported language, null input, or error.
///
/// # Safety
/// - `code` must point to valid UTF-8 of `code_len` bytes (NOT null-terminated).
/// - `language` must be a valid null-terminated C string, or null.
/// - `out_tokens` must point to a buffer of at least `max_tokens` CodeToken elements.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_parse_code_tokens(
    code: *const c_char,
    code_len: u32,
    language: *const c_char,
    out_tokens: *mut CodeToken,
    max_tokens: u32,
) -> u32 {
    markdown_catch_unwind_or!("markdown_parse_code_tokens", 0, {
        if code.is_null() || out_tokens.is_null() || max_tokens == 0 || code_len == 0 {
            return 0;
        }

        // SAFETY: language is a valid null-terminated C string per FFI contract, or null.
        let lang_str = if language.is_null() {
            return 0;
        } else {
            match unsafe { CStr::from_ptr(language) }.to_str() {
                Ok(s) => s,
                Err(_) => return 0,
            }
        };

        // SAFETY: code points to valid UTF-8 of code_len bytes per FFI contract.
        let code_slice =
            unsafe { std::slice::from_raw_parts(code as *const u8, code_len as usize) };
        let code_str = match std::str::from_utf8(code_slice) {
            Ok(s) => s,
            Err(_) => return 0,
        };

        let tokens = crate::code_highlight::tokenize(lang_str, code_str);
        let count = tokens.len().min(max_tokens as usize);

        // SAFETY: out_tokens buffer has capacity for at least max_tokens elements.
        unsafe {
            std::ptr::copy_nonoverlapping(tokens.as_ptr(), out_tokens, count);
        }

        count as u32
    })
}

// ── Non-Destructive Fold State ───────────────────────────────────────────

use parking_lot::Mutex as ParkingMutex;
use std::collections::HashSet;

/// Global fold state — set of folded heading line indices.
static FOLD_STATE: std::sync::LazyLock<ParkingMutex<HashSet<u32>>> =
    std::sync::LazyLock::new(|| ParkingMutex::new(HashSet::new()));

pub fn set_fold(line_index: u32, folded: bool) {
    let mut state = FOLD_STATE.lock();
    if folded {
        state.insert(line_index);
    } else {
        state.remove(&line_index);
    }
}

pub fn is_folded(line_index: u32) -> bool {
    FOLD_STATE.lock().contains(&line_index)
}

pub fn clear_all_folds() {
    FOLD_STATE.lock().clear();
}

/// Given a heading line index and structure spans, return the range of lines
/// that would be hidden when folding. Returns (start_inclusive, end_exclusive).
/// Returns None if the line is not a heading.
pub fn fold_range_for_heading(heading_line: u32, spans: &[StructureSpan]) -> Option<(u32, u32)> {
    let idx = heading_line as usize;
    if idx >= spans.len() || spans[idx].para_type != ParaType::Heading as u8 {
        return None;
    }
    let heading_level = spans[idx].metadata & 0xFF;
    let start = heading_line + 1;
    let mut end = spans.len() as u32;

    for (i, span) in spans.iter().enumerate().skip(start as usize) {
        if span.para_type == ParaType::Heading as u8 {
            let level = span.metadata & 0xFF;
            if level <= heading_level {
                end = i as u32;
                break;
            }
        }
    }

    if start >= end {
        None
    } else {
        Some((start, end))
    }
}

// ── Fold FFI ─────────────────────────────────────────────────────────────

#[unsafe(no_mangle)]
/// # Safety
///
/// This FFI entry point is called from foreign code and assumes the shared fold
/// registry is initialized in this process. The caller must provide a valid line
/// index for the current markdown document state.
pub unsafe extern "C" fn markdown_set_fold(line_index: u32, folded: bool) {
    markdown_catch_unwind!("markdown_set_fold", {
        set_fold(line_index, folded);
    });
}

#[unsafe(no_mangle)]
/// # Safety
///
/// This FFI entry point is called from foreign code and assumes the shared fold
/// registry is initialized in this process. The caller must provide a valid line
/// index for the current markdown document state.
pub unsafe extern "C" fn markdown_is_folded(line_index: u32) -> bool {
    markdown_catch_unwind_or!("markdown_is_folded", false, { is_folded(line_index) })
}

#[unsafe(no_mangle)]
/// # Safety
///
/// This FFI entry point is called from foreign code and assumes the shared fold
/// registry is initialized in this process.
pub unsafe extern "C" fn markdown_clear_all_folds() {
    markdown_catch_unwind!("markdown_clear_all_folds", {
        clear_all_folds();
    });
}

/// Get the fold range for a heading. Returns false if not a heading.
/// On success, writes start and end (exclusive) line indices to out pointers.
///
/// # Safety
/// `text` must be valid null-terminated UTF-8. out_start/out_end must be valid pointers.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_fold_range(
    text: *const c_char,
    heading_line: u32,
    out_start: *mut u32,
    out_end: *mut u32,
) -> bool {
    markdown_catch_unwind_or!("markdown_fold_range", false, {
        if text.is_null() || out_start.is_null() || out_end.is_null() {
            return false;
        }
        // SAFETY: text is a valid null-terminated UTF-8 string per contract.
        let rust_str = match unsafe { CStr::from_ptr(text) }.to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };

        let spans = parse_structure(rust_str);
        match fold_range_for_heading(heading_line, &spans) {
            Some((start, end)) => {
                // SAFETY: out_start/out_end are valid pointers per contract.
                unsafe {
                    *out_start = start;
                    *out_end = end;
                }
                true
            }
            None => false,
        }
    })
}

// ── Tests ────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(text: &str) -> Vec<StyleSpan> {
        parse_markdown(text)
    }

    fn has_style(spans: &[StyleSpan], kind: StyleKind) -> bool {
        spans.iter().any(|s| s.style == kind as u8)
    }

    fn spans_of_kind(spans: &[StyleSpan], kind: StyleKind) -> Vec<&StyleSpan> {
        spans.iter().filter(|s| s.style == kind as u8).collect()
    }

    #[test]
    fn bold_emphasis() {
        let spans = parse("**bold text**");
        assert!(has_style(&spans, StyleKind::Bold));
        let bold = spans_of_kind(&spans, StyleKind::Bold);
        assert_eq!(bold.len(), 1);
        assert_eq!(bold[0].start, 0);
        assert_eq!(bold[0].end, 13);
    }

    #[test]
    fn italic_emphasis() {
        let spans = parse("*italic text*");
        assert!(has_style(&spans, StyleKind::Italic));
    }

    #[test]
    fn strikethrough() {
        let spans = parse("~~deleted~~");
        assert!(has_style(&spans, StyleKind::Strikethrough));
    }

    #[test]
    fn inline_code() {
        let spans = parse("use `foo()` here");
        assert!(has_style(&spans, StyleKind::InlineCode));
        let code = spans_of_kind(&spans, StyleKind::InlineCode);
        assert_eq!(code.len(), 1);
    }

    #[test]
    fn nested_bold_italic() {
        let spans = parse("**bold _and italic_**");
        assert!(has_style(&spans, StyleKind::Bold));
        assert!(has_style(&spans, StyleKind::Italic));
    }

    #[test]
    fn wikilinks() {
        let spans = parse("see [[My Page]] for details");
        assert!(has_style(&spans, StyleKind::Wikilink));
        assert!(has_style(&spans, StyleKind::WikilinkBrackets));
        let brackets = spans_of_kind(&spans, StyleKind::WikilinkBrackets);
        assert_eq!(brackets.len(), 2); // [[ and ]]
        let content = spans_of_kind(&spans, StyleKind::Wikilink);
        assert_eq!(content.len(), 1);
        // Verify content span covers "My Page"
        let text = "see [[My Page]] for details";
        assert_eq!(
            &text[content[0].start as usize..content[0].end as usize],
            "My Page"
        );
    }

    #[test]
    fn inline_math() {
        let spans = parse("the formula $E=mc^2$ is famous");
        assert!(has_style(&spans, StyleKind::InlineMath));
        let math = spans_of_kind(&spans, StyleKind::InlineMath);
        assert_eq!(math.len(), 1);
    }

    #[test]
    fn inline_math_ignores_double_dollar() {
        let spans = parse("display math $$x^2$$ is different");
        // $$ should not be parsed as inline math
        let math = spans_of_kind(&spans, StyleKind::InlineMath);
        assert_eq!(math.len(), 0);
        // But display math should pick it up
        let display = spans_of_kind(&spans, StyleKind::DisplayMath);
        assert_eq!(display.len(), 1);
    }

    #[test]
    fn extract_display_math_multiline() {
        let text = "before\n$$\nx^2 + y^2 = z^2\n$$\nafter";
        let spans = parse(text);
        let display: Vec<_> = spans_of_kind(&spans, StyleKind::DisplayMath);
        assert_eq!(display.len(), 1);
        let captured = &text[display[0].start as usize..display[0].end as usize];
        assert!(captured.starts_with("$$"));
        assert!(captured.ends_with("$$"));
    }

    #[test]
    fn display_math_inline_math_coexist() {
        let text = "The formula $x^2$ is inline but $$y^2$$ is display";
        let spans = parse(text);
        let inline = spans_of_kind(&spans, StyleKind::InlineMath);
        let display = spans_of_kind(&spans, StyleKind::DisplayMath);
        assert_eq!(inline.len(), 1);
        assert_eq!(display.len(), 1);
    }

    #[test]
    fn markdown_link() {
        let spans = parse("[click here](https://example.com)");
        assert!(has_style(&spans, StyleKind::MarkdownLink));
    }

    #[test]
    fn horizontal_rule() {
        let spans = parse("---\n");
        assert!(has_style(&spans, StyleKind::HorizontalRule));
    }

    #[test]
    fn task_list() {
        let spans = parse("- [ ] todo\n- [x] done\n");
        assert!(has_style(&spans, StyleKind::Checkbox));
        assert!(has_style(&spans, StyleKind::CheckboxChecked));
    }

    #[test]
    fn heading_levels() {
        let spans = parse("# H1\n## H2\n### H3\n#### H4\n");
        assert!(has_style(&spans, StyleKind::Heading1));
        assert!(has_style(&spans, StyleKind::Heading2));
        assert!(has_style(&spans, StyleKind::Heading3));
        assert!(has_style(&spans, StyleKind::Heading4));
    }

    #[test]
    fn table_detection() {
        let spans = parse("| A | B |\n|---|---|\n| 1 | 2 |\n");
        assert!(has_style(&spans, StyleKind::Table));
        assert!(has_style(&spans, StyleKind::TableHeader));
    }

    #[test]
    fn empty_text_returns_no_spans() {
        let spans = parse("");
        assert!(spans.is_empty());
    }

    #[test]
    fn plain_text_returns_no_spans() {
        let spans = parse("Hello world, no formatting here.");
        assert!(spans.is_empty());
    }

    #[test]
    fn ffi_roundtrip() {
        let text = b"**bold** and *italic*\0";
        let mut spans_ptr: *mut StyleSpan = std::ptr::null_mut();
        let mut count: u32 = 0;

        let result = unsafe {
            markdown_parse(
                text.as_ptr() as *const c_char,
                text.len() as u32 - 1,
                &mut spans_ptr,
                &mut count,
            )
        };

        assert_eq!(result, 0);
        assert!(count >= 2);
        assert!(!spans_ptr.is_null());

        unsafe { markdown_free_spans(spans_ptr, count) };
    }

    #[test]
    fn block_references() {
        let spans = parse("see ((abc-123)) for details");
        assert!(has_style(&spans, StyleKind::BlockReference));
        assert!(has_style(&spans, StyleKind::BlockReferenceBrackets));
        let brackets = spans_of_kind(&spans, StyleKind::BlockReferenceBrackets);
        assert_eq!(brackets.len(), 2); // (( and ))
        let content = spans_of_kind(&spans, StyleKind::BlockReference);
        assert_eq!(content.len(), 1);
        let text = "see ((abc-123)) for details";
        assert_eq!(
            &text[content[0].start as usize..content[0].end as usize],
            "abc-123"
        );
    }

    #[test]
    fn block_reference_empty_ignored() {
        let spans = parse("see (( )) here");
        assert!(!has_style(&spans, StyleKind::BlockReference));
    }

    #[test]
    fn block_reference_multiple() {
        let spans = parse("((id1)) and ((id2))");
        let content = spans_of_kind(&spans, StyleKind::BlockReference);
        assert_eq!(content.len(), 2);
    }

    #[test]
    fn block_reference_not_confused_with_parens() {
        let spans = parse("(single paren) and (another)");
        assert!(!has_style(&spans, StyleKind::BlockReference));
    }

    #[test]
    fn ffi_null_safety() {
        let result = unsafe {
            markdown_parse(
                std::ptr::null(),
                0,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
            )
        };
        assert_eq!(result, 1);
    }

    // ── Structure Parser Tests ──────────────────────────────────────────

    fn structure(text: &str) -> Vec<StructureSpan> {
        parse_structure(text)
    }

    #[test]
    fn structure_empty() {
        assert!(structure("").is_empty());
    }

    #[test]
    fn structure_heading_levels() {
        let spans = structure("# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6");
        assert_eq!(spans.len(), 6);
        for (i, span) in spans.iter().enumerate() {
            assert_eq!(span.para_type, ParaType::Heading as u8);
            assert_eq!(span.metadata, (i + 1) as u16);
        }
    }

    #[test]
    fn structure_body_text() {
        let spans = structure("Hello world\nSecond line");
        assert_eq!(spans.len(), 2);
        assert_eq!(spans[0].para_type, ParaType::Body as u8);
        assert_eq!(spans[1].para_type, ParaType::Body as u8);
    }

    #[test]
    fn structure_unordered_list() {
        let spans = structure("- item one\n* item two\n+ item three");
        assert_eq!(spans.len(), 3);
        for span in &spans {
            assert_eq!(span.para_type, ParaType::UnorderedList as u8);
            assert_eq!(span.metadata, 0); // depth 0
        }
    }

    #[test]
    fn structure_ordered_list() {
        let spans = structure("1. first\n2. second\n3. third");
        assert_eq!(spans.len(), 3);
        for (i, span) in spans.iter().enumerate() {
            assert_eq!(span.para_type, ParaType::OrderedList as u8);
            assert_eq!(span.metadata & 0xFF, (i + 1) as u16); // start index
        }
    }

    #[test]
    fn structure_task_list() {
        let spans = structure("- [ ] todo\n- [x] done");
        assert_eq!(spans.len(), 2);
        assert_eq!(spans[0].para_type, ParaType::TaskList as u8);
        assert_eq!(spans[0].metadata & 1, 0); // unchecked
        assert_eq!(spans[1].para_type, ParaType::TaskList as u8);
        assert_eq!(spans[1].metadata & 1, 1); // checked
    }

    #[test]
    fn structure_code_block() {
        let spans = structure("text\n```python\nx = 1\ny = 2\n```\nmore text");
        assert_eq!(spans.len(), 6);
        assert_eq!(spans[0].para_type, ParaType::Body as u8);
        assert_eq!(spans[1].para_type, ParaType::CodeBlock as u8); // fence
        assert_eq!(spans[2].para_type, ParaType::CodeBlock as u8); // x = 1
        assert_eq!(spans[3].para_type, ParaType::CodeBlock as u8); // y = 2
        assert_eq!(spans[4].para_type, ParaType::CodeBlock as u8); // close fence
        assert_eq!(spans[5].para_type, ParaType::Body as u8);
    }

    #[test]
    fn structure_unclosed_code_block() {
        let spans = structure("```\ncode\nmore code");
        assert_eq!(spans.len(), 3);
        for span in &spans {
            assert_eq!(span.para_type, ParaType::CodeBlock as u8);
        }
    }

    #[test]
    fn structure_blockquote() {
        let spans = structure("> level 1\n>> level 2\n> > also level 2");
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
        assert_eq!(spans[0].metadata, 1);
        assert_eq!(spans[1].para_type, ParaType::BlockQuote as u8);
        assert_eq!(spans[1].metadata, 2);
        assert_eq!(spans[2].para_type, ParaType::BlockQuote as u8);
        assert_eq!(spans[2].metadata, 2);
    }

    #[test]
    fn structure_table() {
        let spans = structure("| A | B |\n|---|---|\n| 1 | 2 |");
        assert_eq!(spans.len(), 3);
        for span in &spans {
            assert_eq!(span.para_type, ParaType::Table as u8);
        }
    }

    #[test]
    fn structure_horizontal_rule() {
        let spans = structure("---\n***\n___");
        assert_eq!(spans.len(), 3);
        for span in &spans {
            assert_eq!(span.para_type, ParaType::HorizontalRule as u8);
        }
    }

    #[test]
    fn structure_html_comment_single_line() {
        let spans = structure("<!-- comment -->");
        assert_eq!(spans.len(), 1);
        assert_eq!(spans[0].para_type, ParaType::HtmlComment as u8);
    }

    #[test]
    fn structure_html_comment_multiline() {
        let spans = structure("<!-- start\nmiddle\nend -->");
        assert_eq!(spans.len(), 3);
        for span in &spans {
            assert_eq!(span.para_type, ParaType::HtmlComment as u8);
        }
    }

    #[test]
    fn structure_mixed_content() {
        let text = "# Title\n\nSome body.\n\n- list item\n\n> quote\n\n---";
        let spans = structure(text);
        assert_eq!(spans[0].para_type, ParaType::Heading as u8);
        assert_eq!(spans[1].para_type, ParaType::Body as u8); // empty
        assert_eq!(spans[2].para_type, ParaType::Body as u8);
        assert_eq!(spans[3].para_type, ParaType::Body as u8); // empty
        assert_eq!(spans[4].para_type, ParaType::UnorderedList as u8);
        assert_eq!(spans[5].para_type, ParaType::Body as u8); // empty
        assert_eq!(spans[6].para_type, ParaType::BlockQuote as u8);
        assert_eq!(spans[7].para_type, ParaType::Body as u8); // empty
        assert_eq!(spans[8].para_type, ParaType::HorizontalRule as u8);
    }

    #[test]
    fn structure_indented_list() {
        let spans = structure("- level 0\n  - level 1\n    - level 2");
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].metadata, 0);
        assert_eq!(spans[1].metadata, 1);
        assert_eq!(spans[2].metadata, 2);
    }

    #[test]
    fn structure_ffi_roundtrip() {
        let text = b"# Heading\nBody text\n```\ncode\n```\0";
        let mut buffer = [StructureSpan {
            para_type: 255,
            _pad: 0,
            metadata: 0,
        }; 16];

        let count = unsafe {
            markdown_parse_structure(text.as_ptr() as *const c_char, buffer.as_mut_ptr(), 16)
        };

        assert_eq!(count, 5);
        assert_eq!(buffer[0].para_type, ParaType::Heading as u8);
        assert_eq!(buffer[1].para_type, ParaType::Body as u8);
        assert_eq!(buffer[2].para_type, ParaType::CodeBlock as u8);
        assert_eq!(buffer[3].para_type, ParaType::CodeBlock as u8);
        assert_eq!(buffer[4].para_type, ParaType::CodeBlock as u8);
    }

    #[test]
    fn structure_ffi_null_safety() {
        let count = unsafe { markdown_parse_structure(std::ptr::null(), std::ptr::null_mut(), 0) };
        assert_eq!(count, 0);
    }

    #[test]
    fn structure_ffi_buffer_cap() {
        let text = b"# H1\n## H2\n### H3\n#### H4\0";
        let mut buffer = [StructureSpan {
            para_type: 255,
            _pad: 0,
            metadata: 0,
        }; 2]; // Only room for 2 spans

        let count = unsafe {
            markdown_parse_structure(text.as_ptr() as *const c_char, buffer.as_mut_ptr(), 2)
        };

        assert_eq!(count, 2); // Capped at buffer size
        assert_eq!(buffer[0].para_type, ParaType::Heading as u8);
        assert_eq!(buffer[1].para_type, ParaType::Heading as u8);
    }

    // ── Callout Detection Tests ──────────────────────────────────────────

    #[test]
    fn structure_callout_note() {
        let spans = structure("> [!note] Important\n> Body line\n> More body");
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
        assert_eq!(spans[0].metadata & 0xFF, 1); // depth
        assert_eq!((spans[0].metadata >> 8) & 0xFF, 1); // callout type: note
        assert_eq!((spans[1].metadata >> 8) & 0xFF, 1); // continuation inherits
        assert_eq!((spans[2].metadata >> 8) & 0xFF, 1);
    }

    #[test]
    fn structure_callout_warning() {
        let spans = structure("> [!warning]\n> Be careful");
        assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
        assert_eq!((spans[0].metadata >> 8) & 0xFF, 3); // warning
    }

    #[test]
    fn structure_callout_plain_blockquote() {
        let spans = structure("> Just a quote\n> Second line");
        assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
        assert_eq!((spans[0].metadata >> 8) & 0xFF, 0); // no callout type
    }

    #[test]
    fn structure_callout_danger() {
        let spans = structure("> [!danger] Watch out\n> Details here\nPlain text");
        assert_eq!((spans[0].metadata >> 8) & 0xFF, 7); // danger
        assert_eq!((spans[1].metadata >> 8) & 0xFF, 7); // continuation inherits
        assert_eq!(spans[2].para_type, ParaType::Body as u8); // non-quote resets
    }

    // ── CodeToken / TokenType / language_id tests ─────────────────────────

    #[test]
    fn code_token_struct_size() {
        assert_eq!(std::mem::size_of::<CodeToken>(), 12);
        assert_eq!(std::mem::align_of::<CodeToken>(), 4); // u32 alignment
    }

    #[test]
    fn language_id_round_trip() {
        // Exact matches
        assert_eq!(language_id_from_str("swift"), 1);
        assert_eq!(language_id_from_str("rust"), 2);
        assert_eq!(language_id_from_str("rs"), 2);
        assert_eq!(language_id_from_str("python"), 3);
        assert_eq!(language_id_from_str("py"), 3);
        assert_eq!(language_id_from_str("javascript"), 4);
        assert_eq!(language_id_from_str("js"), 4);
        assert_eq!(language_id_from_str("jsx"), 4);
        assert_eq!(language_id_from_str("typescript"), 5);
        assert_eq!(language_id_from_str("ts"), 5);
        assert_eq!(language_id_from_str("tsx"), 5);
        assert_eq!(language_id_from_str("json"), 6);
        assert_eq!(language_id_from_str("html"), 7);
        assert_eq!(language_id_from_str("htm"), 7);
        assert_eq!(language_id_from_str("css"), 8);
        assert_eq!(language_id_from_str("scss"), 8);
        assert_eq!(language_id_from_str("less"), 8);
        assert_eq!(language_id_from_str("bash"), 9);
        assert_eq!(language_id_from_str("sh"), 9);
        assert_eq!(language_id_from_str("shell"), 9);
        assert_eq!(language_id_from_str("zsh"), 9);
        assert_eq!(language_id_from_str("go"), 10);
        assert_eq!(language_id_from_str("golang"), 10);
        assert_eq!(language_id_from_str("c"), 11);
        assert_eq!(language_id_from_str("h"), 11);
        assert_eq!(language_id_from_str("cpp"), 12);
        assert_eq!(language_id_from_str("c++"), 12);
        assert_eq!(language_id_from_str("cc"), 12);
        assert_eq!(language_id_from_str("cxx"), 12);
        assert_eq!(language_id_from_str("hpp"), 12);

        // Case insensitive
        assert_eq!(language_id_from_str("Swift"), 1);
        assert_eq!(language_id_from_str("RUST"), 2);
        assert_eq!(language_id_from_str("Python"), 3);
        assert_eq!(language_id_from_str("JavaScript"), 4);
        assert_eq!(language_id_from_str("TypeScript"), 5);
        assert_eq!(language_id_from_str("JSON"), 6);
        assert_eq!(language_id_from_str("HTML"), 7);

        // Unknown
        assert_eq!(language_id_from_str(""), 0);
        assert_eq!(language_id_from_str("brainfuck"), 0);
        assert_eq!(language_id_from_str("unknown"), 0);
    }

    #[test]
    fn structure_parser_captures_language() {
        let text = "```swift\nlet x = 1\n```";
        let spans = parse_structure(text);
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].para_type, ParaType::CodeBlock as u8);
        assert_eq!(spans[1].para_type, ParaType::CodeBlock as u8);
        assert_eq!(spans[2].para_type, ParaType::CodeBlock as u8);
        // metadata low byte = language_id for swift (1)
        assert_eq!(spans[0].metadata & 0xFF, 1);
        assert_eq!(spans[1].metadata & 0xFF, 1);
        assert_eq!(spans[2].metadata & 0xFF, 1);
    }

    #[test]
    fn structure_parser_unknown_language() {
        let text = "```\nplain code\n```";
        let spans = parse_structure(text);
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].metadata & 0xFF, 0);
        assert_eq!(spans[1].metadata & 0xFF, 0);
    }

    #[test]
    fn structure_parser_rust_language() {
        let text = "```rust\nfn main() {}\n```";
        let spans = parse_structure(text);
        assert_eq!(spans[1].metadata & 0xFF, 2);
    }

    // ── FFI code token round-trip tests ─────────────────────────────────

    #[test]
    fn ffi_code_tokens_round_trip() {
        let code = "let x = 42\n";
        let lang = "swift\0";
        let mut buffer = vec![
            CodeToken {
                start: 0,
                end: 0,
                token_type: 0,
                _pad: [0; 3]
            };
            256
        ];

        // SAFETY: test buffer is properly sized, code is valid UTF-8, lang is null-terminated.
        let count = unsafe {
            markdown_parse_code_tokens(
                code.as_ptr() as *const c_char,
                code.len() as u32,
                lang.as_ptr() as *const c_char,
                buffer.as_mut_ptr(),
                256,
            )
        };

        assert!(count > 0, "Expected tokens from Swift code");
        buffer.truncate(count as usize);
        let keyword = buffer
            .iter()
            .find(|t| t.token_type == TokenType::Keyword as u8);
        assert!(keyword.is_some(), "Expected keyword token via FFI");
    }

    #[test]
    fn ffi_code_tokens_null_language() {
        let code = "let x = 42\n";
        let mut buffer = vec![
            CodeToken {
                start: 0,
                end: 0,
                token_type: 0,
                _pad: [0; 3]
            };
            256
        ];

        // SAFETY: null language should return 0 safely.
        let count = unsafe {
            markdown_parse_code_tokens(
                code.as_ptr() as *const c_char,
                code.len() as u32,
                std::ptr::null(),
                buffer.as_mut_ptr(),
                256,
            )
        };

        assert_eq!(count, 0, "Null language should return 0 tokens");
    }

    #[test]
    fn ffi_code_tokens_null_code() {
        let lang = "swift\0";
        let mut buffer = vec![
            CodeToken {
                start: 0,
                end: 0,
                token_type: 0,
                _pad: [0; 3]
            };
            256
        ];

        // SAFETY: null code pointer should return 0 safely.
        let count = unsafe {
            markdown_parse_code_tokens(
                std::ptr::null(),
                0,
                lang.as_ptr() as *const c_char,
                buffer.as_mut_ptr(),
                256,
            )
        };

        assert_eq!(count, 0, "Null code should return 0 tokens");
    }

    #[test]
    fn ffi_code_tokens_buffer_overflow_protection() {
        let code = "fn main() { let a = 1; let b = 2; let c = 3; }";
        let lang = "rust\0";
        // Tiny buffer — should truncate, not overflow
        let mut buffer = vec![
            CodeToken {
                start: 0,
                end: 0,
                token_type: 0,
                _pad: [0; 3]
            };
            2
        ];

        // SAFETY: buffer of size 2, max_tokens=2.
        let count = unsafe {
            markdown_parse_code_tokens(
                code.as_ptr() as *const c_char,
                code.len() as u32,
                lang.as_ptr() as *const c_char,
                buffer.as_mut_ptr(),
                2,
            )
        };

        assert!(count <= 2, "Should not exceed max_tokens");
    }

    // ── Fold State Tests ─────────────────────────────────────────────────

    /// Serializes tests that mutate the process-global FOLD_STATE.
    static FOLD_STATE_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[test]
    fn fold_state_set_and_query() {
        let _guard = FOLD_STATE_TEST_LOCK.lock().unwrap();
        clear_all_folds();
        set_fold(2, true);
        assert!(is_folded(2));
        assert!(!is_folded(0));
        assert!(!is_folded(5));
        set_fold(2, false);
        assert!(!is_folded(2));
    }

    #[test]
    fn fold_range_for_heading_basic() {
        // # Title (H1) → fold includes ## Section (H2 is deeper) and More text
        // Standard behavior: fold until same-or-higher level heading
        let text = "# Title\nBody 1\nBody 2\n## Section\nMore text";
        let spans = parse_structure(text);
        let (start, end) = fold_range_for_heading(0, &spans).unwrap();
        assert_eq!(start, 1);
        assert_eq!(end, 5); // to end of document (no peer H1 to stop at)
    }

    #[test]
    fn fold_range_at_end_of_document() {
        let text = "## Section\nLine 1\nLine 2";
        let spans = parse_structure(text);
        let (start, end) = fold_range_for_heading(0, &spans).unwrap();
        assert_eq!(start, 1);
        assert_eq!(end, 3); // to end of document
    }

    #[test]
    fn fold_range_non_heading_returns_none() {
        let text = "Just body text";
        let spans = parse_structure(text);
        assert!(fold_range_for_heading(0, &spans).is_none());
    }

    #[test]
    fn fold_range_nested_headings() {
        let text = "# H1\n## H2\nBody\n### H3\nDeep\n# Another H1";
        let spans = parse_structure(text);
        // Folding H1 hides everything until the next H1
        let (s, e) = fold_range_for_heading(0, &spans).unwrap();
        assert_eq!(s, 1);
        assert_eq!(e, 5); // stops at "# Another H1"
        // Folding H2 hides lines 2-4 (Body, ### H3, Deep) — H3 is deeper, included
        let (s2, e2) = fold_range_for_heading(1, &spans).unwrap();
        assert_eq!(s2, 2);
        assert_eq!(e2, 5); // stops at "# Another H1" (level 1 <= 2)
    }

    #[test]
    fn fold_range_same_level_stop() {
        // Two H2s — folding the first should stop at the second
        let text = "## First\nBody\n## Second\nMore";
        let spans = parse_structure(text);
        let (s, e) = fold_range_for_heading(0, &spans).unwrap();
        assert_eq!(s, 1);
        assert_eq!(e, 2); // stops at ## Second (level 2 <= 2)
    }

    #[test]
    fn fold_range_includes_deeper_subheadings() {
        // H1 fold includes all deeper headings
        let text = "# First\n## Sub";
        let spans = parse_structure(text);
        let (s, e) = fold_range_for_heading(0, &spans).unwrap();
        assert_eq!(s, 1);
        assert_eq!(e, 2); // includes ## Sub (level 2 > 1, not a stop)
    }

    #[test]
    fn fold_ffi_round_trip() {
        let _guard = FOLD_STATE_TEST_LOCK.lock().unwrap();
        // SAFETY: FFI functions with valid arguments.
        unsafe { markdown_clear_all_folds() };
        unsafe { markdown_set_fold(5, true) };
        assert!(unsafe { markdown_is_folded(5) });
        assert!(!unsafe { markdown_is_folded(0) });
        unsafe { markdown_set_fold(5, false) };
        assert!(!unsafe { markdown_is_folded(5) });
    }

    #[test]
    fn fold_range_ffi_round_trip() {
        let text = "## Title\nBody 1\nBody 2\0";
        let mut start: u32 = 0;
        let mut end: u32 = 0;
        // SAFETY: text is null-terminated, pointers are valid.
        let ok =
            unsafe { markdown_fold_range(text.as_ptr() as *const c_char, 0, &mut start, &mut end) };
        assert!(ok);
        assert_eq!(start, 1);
        assert_eq!(end, 3); // to end of document

        // Non-heading line returns false
        let not_ok =
            unsafe { markdown_fold_range(text.as_ptr() as *const c_char, 1, &mut start, &mut end) };
        assert!(!not_ok);
    }
}
