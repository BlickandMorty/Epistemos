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
    let opts = Options::ENABLE_TABLES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS;

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
        if bytes[i] == b'[' && bytes[i + 1] == b'['
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

/// Extract ((block-reference)) syntax — Logseq-style block transclusion.
/// Follows the exact same pattern as extract_wikilinks.
fn extract_block_references(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        if bytes[i] == b'(' && bytes[i + 1] == b'('
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
    let mut in_html_comment = false;

    for line in &lines {
        let trimmed = line.trim_start();
        let indent = line.len() - trimmed.len();

        // Code block state machine
        if in_code_block {
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: 0,
            });
            if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
                in_code_block = false;
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
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: 0,
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

        // Blockquote
        if trimmed.starts_with('>') {
            let depth = count_blockquote_depth(trimmed);
            spans.push(StructureSpan {
                para_type: ParaType::BlockQuote as u8,
                _pad: 0,
                metadata: depth as u16,
            });
            continue;
        }

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

fn detect_task_list(trimmed: &str, indent: usize) -> Option<(u8, u8)> {
    let rest = trimmed
        .strip_prefix("- ")
        .or_else(|| trimmed.strip_prefix("* "))
        .or_else(|| trimmed.strip_prefix("+ "))?;

    if rest == "[ ]" || rest.starts_with("[ ] ") {
        Some(((indent / 2) as u8, 0))
    } else if rest == "[x]"
        || rest.starts_with("[x] ")
        || rest == "[X]"
        || rest.starts_with("[X] ")
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
}

/// Free a spans array previously returned by `markdown_parse`.
///
/// # Safety
/// `spans` must be a pointer returned by `markdown_parse`, and `count` must
/// match the count returned with it.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_free_spans(spans: *mut StyleSpan, count: u32) {
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
        assert_eq!(&text[content[0].start as usize..content[0].end as usize], "My Page");
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
        assert_eq!(&text[content[0].start as usize..content[0].end as usize], "abc-123");
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
            markdown_parse_structure(
                text.as_ptr() as *const c_char,
                buffer.as_mut_ptr(),
                16,
            )
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
        let count = unsafe {
            markdown_parse_structure(std::ptr::null(), std::ptr::null_mut(), 0)
        };
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
            markdown_parse_structure(
                text.as_ptr() as *const c_char,
                buffer.as_mut_ptr(),
                2,
            )
        };

        assert_eq!(count, 2); // Capped at buffer size
        assert_eq!(buffer[0].para_type, ParaType::Heading as u8);
        assert_eq!(buffer[1].para_type, ParaType::Heading as u8);
    }
}
