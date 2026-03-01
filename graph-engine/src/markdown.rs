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
        if bytes[i] == b'[' && bytes[i + 1] == b'[' {
            if let Some(close_offset) = text[i + 2..].find("]]") {
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
        if bytes[i] == b'(' && bytes[i + 1] == b'(' {
            if let Some(close_offset) = text[i + 2..].find("))") {
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
        }
        i += 1;
    }
}

// ── FFI ──────────────────────────────────────────────────────────────────

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
}
