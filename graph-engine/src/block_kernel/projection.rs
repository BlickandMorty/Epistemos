use crate::block_kernel::block_tree::BlockTree;
use crate::block_kernel::op::BlockId;

/// Project a block tree back to markdown text.
/// Walks blocks in document order, indenting by depth.
pub fn project(tree: &BlockTree) -> String {
    let mut result = String::with_capacity(4096);
    let blocks = tree.walk();

    for (i, block) in blocks.iter().enumerate() {
        if i > 0 {
            result.push('\n');
        }
        // Indent: 2 spaces per depth level
        for _ in 0..block.depth {
            result.push_str("  ");
        }
        // List marker for indented blocks
        if block.depth > 0 {
            result.push_str("- ");
        }
        result.push_str(&block.content);
    }

    result
}

/// Parse markdown into a sequence of InsertBlock ops.
/// Uses the same logic as BlockParser.swift but in Rust.
/// This is the Rust-native entry point for initial population.
pub fn parse_to_ops(markdown: &str) -> Vec<crate::block_kernel::op::Op> {
    let mut ops = Vec::new();
    if markdown.is_empty() {
        return ops;
    }

    let lines: Vec<&str> = markdown.split('\n').collect();
    let mut order: u32 = 0;
    let mut i = 0;

    // Stack of (depth, BlockId) for parent tracking
    let mut depth_stack: Vec<(u16, BlockId)> = Vec::new();

    while i < lines.len() {
        let line = lines[i];

        // Skip blank lines
        if line.trim().is_empty() {
            i += 1;
            continue;
        }

        // Measure indent (each 2 spaces or tab = +1 depth)
        let (depth, stripped) = measure_indent(line);

        // Strip list marker
        let content = strip_list_marker(stripped);

        // Fenced code block: consume until closing fence
        if content.starts_with("```") {
            let mut fence_content = String::from(line);
            i += 1;
            while i < lines.len() {
                fence_content.push('\n');
                fence_content.push_str(lines[i]);
                if lines[i].trim().starts_with("```") {
                    i += 1;
                    break;
                }
                i += 1;
            }
            let block_id = BlockId::new();
            ops.push(crate::block_kernel::op::Op::InsertBlock {
                block_id,
                parent_id: None,
                position: order,
                content: fence_content,
                depth: 0,
            });
            order += 1;
            continue;
        }

        // Find parent: pop stack to find closest ancestor at depth - 1
        while let Some((d, _)) = depth_stack.last() {
            if *d >= depth {
                depth_stack.pop();
            } else {
                break;
            }
        }
        let parent_id = if depth > 0 {
            depth_stack.last().map(|(_, id)| *id)
        } else {
            None
        };

        let block_id = BlockId::new();
        ops.push(crate::block_kernel::op::Op::InsertBlock {
            block_id,
            parent_id,
            position: order,
            content: content.to_string(),
            depth,
        });
        depth_stack.push((depth, block_id));
        order += 1;
        i += 1;
    }

    ops
}

fn measure_indent(line: &str) -> (u16, &str) {
    let mut depth: u16 = 0;
    let mut spaces = 0;
    let bytes = line.as_bytes();
    let mut pos = 0;

    while pos < bytes.len() {
        match bytes[pos] {
            b'\t' => { depth += 1; spaces = 0; }
            b' ' => {
                spaces += 1;
                if spaces == 2 { depth += 1; spaces = 0; }
            }
            _ => break,
        }
        pos += 1;
    }

    (depth, &line[pos..])
}

fn strip_list_marker(s: &str) -> &str {
    if let Some(rest) = s.strip_prefix("- ") { return rest; }
    if let Some(rest) = s.strip_prefix("* ") { return rest; }

    // Ordered: "1. ", "2. ", etc.
    let bytes = s.as_bytes();
    let mut i = 0;
    while i < bytes.len() && bytes[i].is_ascii_digit() {
        i += 1;
    }
    if i > 0 && i + 1 < bytes.len() && bytes[i] == b'.' && bytes[i + 1] == b' ' {
        return &s[i + 2..];
    }

    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::block_tree::BlockTree;

    fn roundtrip(md: &str) -> String {
        let ops = parse_to_ops(md);
        let mut tree = BlockTree::new();
        for op in &ops {
            tree.apply(op);
        }
        project(&tree)
    }

    #[test]
    fn roundtrip_simple_paragraphs() {
        let md = "Hello\n\nWorld";
        assert_eq!(roundtrip(md), "Hello\nWorld");
        // Note: blank lines between paragraphs are lost (blocks are content-only).
        // This is acceptable — the projection produces minimal markdown.
    }

    #[test]
    fn roundtrip_nested_list() {
        let md = "Top level\n  - Child\n    - Grandchild";
        let result = roundtrip(md);
        assert!(result.contains("Top level"));
        assert!(result.contains("Child"));
        assert!(result.contains("Grandchild"));
    }

    #[test]
    fn roundtrip_heading() {
        let md = "# Title\n\nSome text";
        let result = roundtrip(md);
        assert!(result.contains("# Title"));
        assert!(result.contains("Some text"));
    }

    #[test]
    fn empty_markdown() {
        assert_eq!(roundtrip(""), "");
    }
}
