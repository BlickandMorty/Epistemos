use std::borrow::Cow;

use memchr::memmem;
use orgize::Org;
use pulldown_cmark::{Options, Parser};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DocumentFormat {
    Markdown = 0,
    Org = 1,
}

impl DocumentFormat {
    pub const fn from_ffi(raw: u8) -> Option<Self> {
        match raw {
            0 => Some(Self::Markdown),
            1 => Some(Self::Org),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NormalizedBlock {
    pub page_id: String,
    pub block_id: String,
    pub parent_id: String,
    pub order_key: String,
    pub depth: u16,
    pub content: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NormalizedTask {
    pub page_id: String,
    pub block_id: String,
    pub marker: String,
    pub done: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NormalizedProperty {
    pub page_id: String,
    pub block_id: String,
    pub key: String,
    pub value: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NormalizedLink {
    pub page_id: String,
    pub block_id: String,
    pub target_id: String,
    pub ref_type: u8,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct NormalizedDocument {
    pub page_id: String,
    pub blocks: Vec<NormalizedBlock>,
    pub tasks: Vec<NormalizedTask>,
    pub properties: Vec<NormalizedProperty>,
    pub links: Vec<NormalizedLink>,
}

pub fn parse_document(page_id: &str, format: DocumentFormat, text: &str) -> NormalizedDocument {
    match format {
        DocumentFormat::Markdown => parse_markdown(page_id, text),
        DocumentFormat::Org => parse_org(page_id, text),
    }
}

fn parse_markdown(page_id: &str, text: &str) -> NormalizedDocument {
    let _parser = Parser::new_ext(text, Options::all());
    parse_lines(page_id, text.lines(), Syntax::Markdown)
}

fn parse_org(page_id: &str, text: &str) -> NormalizedDocument {
    let _org = Org::parse(text);
    parse_lines(page_id, text.lines(), Syntax::Org)
}

#[derive(Clone, Copy)]
enum Syntax {
    Markdown,
    Org,
}

fn parse_lines<'a>(
    page_id: &str,
    lines: impl Iterator<Item = &'a str>,
    syntax: Syntax,
) -> NormalizedDocument {
    let mut document = NormalizedDocument {
        page_id: page_id.to_string(),
        ..NormalizedDocument::default()
    };
    let mut parent_stack: Vec<(u16, String)> = Vec::new();
    let mut last_block_id: Option<String> = None;
    let mut in_org_property_drawer = false;

    for (index, raw_line) in lines.enumerate() {
        if matches!(syntax, Syntax::Org) {
            let trimmed = raw_line.trim();
            if in_org_property_drawer {
                if trimmed.eq_ignore_ascii_case(":END:") {
                    in_org_property_drawer = false;
                    continue;
                }

                if let (Some(block_id), Some((key, value))) = (
                    last_block_id.as_ref(),
                    parse_org_property_drawer_line(trimmed),
                ) {
                    document.properties.push(NormalizedProperty {
                        page_id: page_id.to_string(),
                        block_id: block_id.clone(),
                        key,
                        value,
                    });
                }
                continue;
            }

            if trimmed.eq_ignore_ascii_case(":PROPERTIES:") && last_block_id.is_some() {
                in_org_property_drawer = true;
                continue;
            }
        }

        if raw_line.trim().is_empty() {
            continue;
        }

        let (depth, content) = match syntax {
            Syntax::Markdown => parse_markdown_line(raw_line),
            Syntax::Org => parse_org_line(raw_line),
        };
        let block_id = format!("{page_id}::{index:08}");
        while let Some((stack_depth, _)) = parent_stack.last() {
            if *stack_depth >= depth {
                parent_stack.pop();
            } else {
                break;
            }
        }
        let parent_id = parent_stack
            .last()
            .map(|(_, block_id)| block_id.clone())
            .unwrap_or_default();
        let order_key = format!("{index:010}");
        let (task_marker, task_done, stripped_content) = parse_task_state(content);
        let stripped_content_ref = stripped_content.as_ref();
        let properties = parse_inline_properties(stripped_content_ref);
        let links = parse_links(page_id, &block_id, stripped_content_ref);

        document.blocks.push(NormalizedBlock {
            page_id: page_id.to_string(),
            block_id: block_id.clone(),
            parent_id: parent_id.clone(),
            order_key,
            depth,
            content: stripped_content.into_owned(),
        });

        if let Some(marker) = task_marker {
            document.tasks.push(NormalizedTask {
                page_id: page_id.to_string(),
                block_id: block_id.clone(),
                marker: marker.to_string(),
                done: task_done,
            });
        }

        for (key, value) in properties {
            document.properties.push(NormalizedProperty {
                page_id: page_id.to_string(),
                block_id: block_id.clone(),
                key,
                value,
            });
        }

        document.links.extend(links);
        parent_stack.push((depth, block_id));
        last_block_id = document.blocks.last().map(|block| block.block_id.clone());
    }

    document
}

fn parse_markdown_line(line: &str) -> (u16, &str) {
    let mut depth = 0u16;
    let mut cursor = 0usize;
    let bytes = line.as_bytes();
    while cursor < bytes.len() {
        match bytes[cursor] {
            b' ' => {
                cursor += 1;
                if cursor % 2 == 0 {
                    depth += 1;
                }
            }
            b'\t' => {
                cursor += 1;
                depth += 1;
            }
            _ => break,
        }
    }
    let trimmed = line[cursor..]
        .trim_start_matches("- ")
        .trim_start_matches("* ")
        .trim_start();
    (depth, trimmed)
}

fn parse_org_line(line: &str) -> (u16, &str) {
    let trimmed = line.trim_start();
    let stars = trimmed.bytes().take_while(|byte| *byte == b'*').count();
    if stars > 0 {
        let depth = stars.saturating_sub(1) as u16;
        let content = trimmed[stars..].trim_start();
        (depth, content)
    } else {
        (0, trimmed)
    }
}

fn parse_task_state(content: &str) -> (Option<&'static str>, bool, Cow<'_, str>) {
    let trimmed = content.trim_start();
    if let Some(rest) = trimmed.strip_prefix("[ ] ") {
        return (Some("TODO"), false, Cow::Borrowed(rest));
    }
    if let Some(rest) = trimmed.strip_prefix("[x] ") {
        return (Some("DONE"), true, Cow::Borrowed(rest));
    }
    if let Some(rest) = trimmed.strip_prefix("TODO ") {
        return (Some("TODO"), false, Cow::Borrowed(rest));
    }
    if let Some(rest) = trimmed.strip_prefix("DONE ") {
        return (Some("DONE"), true, Cow::Borrowed(rest));
    }
    (None, false, Cow::Borrowed(content))
}

fn parse_inline_properties(content: &str) -> Vec<(String, String)> {
    let mut properties = Vec::new();
    for token in content.split_whitespace() {
        if let Some((key, value)) = token.split_once('=') {
            if let Some(key) = key.strip_prefix('@') {
                if !key.is_empty() && !value.is_empty() {
                    properties.push((key.to_string(), value.to_string()));
                }
            }
        }
        if token.starts_with(':') && token.ends_with(':') {
            let trimmed = token.trim_matches(':');
            if let Some((key, value)) = trimmed.split_once(':') {
                if !key.is_empty() && !value.is_empty() {
                    properties.push((key.to_string(), value.to_string()));
                }
            }
        }
    }
    properties
}

fn parse_org_property_drawer_line(line: &str) -> Option<(String, String)> {
    let trimmed = line.trim();
    if !trimmed.starts_with(':') || trimmed.eq_ignore_ascii_case(":END:") {
        return None;
    }

    let after_prefix = trimmed.strip_prefix(':')?;
    let (key, rest) = after_prefix.split_once(':')?;
    let value = rest.trim();
    if key.is_empty() || value.is_empty() {
        return None;
    }
    Some((key.to_string(), value.to_string()))
}

fn parse_links(page_id: &str, block_id: &str, content: &str) -> Vec<NormalizedLink> {
    let mut links = Vec::new();
    let mut cursor = 0usize;
    while let Some(start) = memmem::find(&content.as_bytes()[cursor..], b"[[") {
        let start = cursor + start;
        let after_start = start + 2;
        let Some(end_offset) = memmem::find(&content.as_bytes()[after_start..], b"]]") else {
            break;
        };
        let end = after_start + end_offset;
        let target = content[after_start..end].trim();
        if !target.is_empty() {
            links.push(NormalizedLink {
                page_id: page_id.to_string(),
                block_id: block_id.to_string(),
                target_id: target.to_string(),
                ref_type: 0,
            });
        }
        cursor = end + 2;
    }
    links
}

#[cfg(test)]
mod tests {
    use super::{DocumentFormat, parse_document};

    #[test]
    fn markdown_normalizes_tasks_and_links() {
        let document = parse_document(
            "page-1",
            DocumentFormat::Markdown,
            "- [ ] ship [[roadmap]] @owner=jojo",
        );
        assert_eq!(document.blocks.len(), 1);
        assert_eq!(document.tasks.len(), 1);
        assert_eq!(document.links.len(), 1);
        assert_eq!(document.properties.len(), 1);
    }

    #[test]
    fn org_normalizes_headings() {
        let document = parse_document(
            "page-1",
            DocumentFormat::Org,
            "* TODO Root :owner:jojo:\n** Child [[note]]",
        );
        assert_eq!(document.blocks.len(), 2);
        assert_eq!(document.tasks.len(), 1);
        assert_eq!(document.links.len(), 1);
        assert_eq!(document.properties.len(), 1);
        assert_eq!(document.blocks[1].parent_id, document.blocks[0].block_id);
    }

    #[test]
    fn org_property_drawers_attach_to_previous_heading() {
        let document = parse_document(
            "page-1",
            DocumentFormat::Org,
            "* Root\n:PROPERTIES:\n:owner: jojo\n:status: active\n:END:\n** Child",
        );

        assert_eq!(document.blocks.len(), 2);
        assert_eq!(document.properties.len(), 2);
        assert!(document
            .properties
            .iter()
            .all(|property| property.block_id == document.blocks[0].block_id));
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_knowledge_core_parser_markdown_large_document() {
        use std::time::Instant;

        const LINE_COUNT: usize = 2_000;
        const ITERATIONS: usize = 100;

        let body = (0..LINE_COUNT)
            .map(|idx| format!("- [ ] Task {idx} [[link-{idx}]] @owner=jojo"))
            .collect::<Vec<_>>()
            .join("\n");

        let start = Instant::now();
        for _ in 0..ITERATIONS {
            let document = parse_document("page-bench", DocumentFormat::Markdown, &body);
            assert_eq!(document.blocks.len(), LINE_COUNT);
        }
        let elapsed = start.elapsed();
        let ns_per_parse = elapsed.as_nanos() as f64 / ITERATIONS as f64;
        let mb_per_sec =
            ((body.len() * ITERATIONS) as f64 / (1024.0 * 1024.0)) / elapsed.as_secs_f64();
        println!(
            "knowledge_core_parser_markdown ns_per_parse={} throughput_mb_s={:.2}",
            ns_per_parse.round() as u64,
            mb_per_sec
        );
    }
}
