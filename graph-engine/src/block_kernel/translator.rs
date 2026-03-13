use crate::block_kernel::block_tree::BlockTree;
use crate::block_kernel::op::{BlockId, Op};

/// A text edit as reported by NSTextStorage.
#[repr(C)]
pub struct TextEdit {
    pub utf16_offset: u32,
    pub old_length: u32, // Number of UTF-16 code units replaced
    pub new_text_ptr: *const u8,
    pub new_text_len: u32, // Byte length of replacement (UTF-8)
}

/// Translate a text edit into block ops.
/// Returns a Vec of ops to apply to the block tree.
pub fn translate_edit(
    tree: &BlockTree,
    edit_offset: u32,
    old_length: u32,
    new_text: &str,
) -> Vec<Op> {
    let blocks = tree.walk();
    if blocks.is_empty() {
        // Empty tree — create first block
        return vec![Op::InsertBlock {
            block_id: BlockId::new(),
            parent_id: None,
            position: 0,
            content: new_text.to_string(),
            depth: 0,
        }];
    }

    // Build a map of block → (start_utf16, end_utf16) in the projected document.
    // This reconstructs where each block sits in the flat text.
    let mut block_ranges: Vec<(BlockId, u32, u32)> = Vec::with_capacity(blocks.len());
    let mut cursor: u32 = 0;

    for (i, block) in blocks.iter().enumerate() {
        if i > 0 {
            cursor += 1; // newline separator
        }
        let indent = block.depth as u32 * 2; // 2 spaces per depth
        let marker = if block.depth > 0 { 2 } else { 0 }; // "- "
        let prefix_len = indent + marker;
        let content_start = cursor + prefix_len;
        let content_len = block.content.encode_utf16().count() as u32;
        let content_end = content_start + content_len;

        block_ranges.push((block.id, content_start, content_end));
        cursor = content_end;
    }

    let edit_end = edit_offset + old_length;

    // Find which block(s) the edit touches
    let mut affected: Vec<usize> = Vec::new();
    for (i, &(_, start, end)) in block_ranges.iter().enumerate() {
        // Edit overlaps this block's content range
        if edit_offset < end && edit_end > start {
            affected.push(i);
        }
    }

    // Case 1: Edit within a single block (most common)
    if affected.len() == 1 {
        let idx = affected[0];
        let (block_id, start, _) = block_ranges[idx];
        let block = blocks[idx];

        // Compute local offset within block content
        let local_offset = edit_offset.saturating_sub(start) as usize;
        let local_end = (edit_end.saturating_sub(start) as usize).min(block.content.len());

        let mut new_content = block.content.clone();
        // Replace using char indices (content is UTF-8, edit offsets are UTF-16)
        let char_start = utf16_to_byte_offset(&block.content, local_offset);
        let char_end = utf16_to_byte_offset(&block.content, local_end);
        new_content.replace_range(char_start..char_end, new_text);

        // Check if the new content contains a newline (block split by Enter)
        if new_content.contains('\n') {
            let parts: Vec<&str> = new_content.splitn(2, '\n').collect();
            let new_block_id = BlockId::new();
            return vec![
                Op::UpdateBlock {
                    block_id,
                    content: parts[0].to_string(),
                },
                Op::InsertBlock {
                    block_id: new_block_id,
                    parent_id: block.parent_id,
                    position: block.order + 1,
                    content: parts[1].to_string(),
                    depth: block.depth,
                },
            ];
        }

        return vec![Op::UpdateBlock {
            block_id,
            content: new_content,
        }];
    }

    // Case 2: Edit spans multiple blocks (selection delete, paste over blocks)
    if affected.len() > 1 {
        let first_idx = affected[0];
        let last_idx = *affected.last().unwrap();
        let (first_id, first_start, _) = block_ranges[first_idx];
        let (_, _, _last_end) = block_ranges[last_idx];
        let first_block = blocks[first_idx];

        // Keep the beginning of the first block + new_text + end of last block
        let local_start = edit_offset.saturating_sub(first_start) as usize;
        let last_block = blocks[last_idx];
        let local_end = (edit_end.saturating_sub(block_ranges[last_idx].1) as usize)
            .min(last_block.content.encode_utf16().count());

        let byte_start = utf16_to_byte_offset(&first_block.content, local_start);
        let byte_end = utf16_to_byte_offset(&last_block.content, local_end);

        let mut merged = first_block.content[..byte_start].to_string();
        merged.push_str(new_text);
        if byte_end < last_block.content.len() {
            merged.push_str(&last_block.content[byte_end..]);
        }

        let mut ops = vec![Op::UpdateBlock {
            block_id: first_id,
            content: merged,
        }];

        // Delete the intermediate and last blocks
        for &idx in &affected[1..] {
            ops.push(Op::DeleteBlock {
                block_id: block_ranges[idx].0,
            });
        }

        return ops;
    }

    // Case 3: Edit is between blocks (e.g., at a newline boundary)
    // Insert a new block
    vec![Op::InsertBlock {
        block_id: BlockId::new(),
        parent_id: None,
        position: edit_offset,
        content: new_text.to_string(),
        depth: 0,
    }]
}

/// Convert UTF-16 offset to byte offset in a UTF-8 string.
fn utf16_to_byte_offset(s: &str, utf16_offset: usize) -> usize {
    let mut utf16_count = 0;
    for (byte_idx, ch) in s.char_indices() {
        if utf16_count >= utf16_offset {
            return byte_idx;
        }
        utf16_count += ch.len_utf16();
    }
    s.len() // Past the end
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::block_tree::BlockTree;
    use crate::block_kernel::op::{BlockId, Op};

    fn make_tree(blocks: &[&str]) -> (BlockTree, Vec<BlockId>) {
        let mut tree = BlockTree::new();
        let mut ids = Vec::new();
        for (i, content) in blocks.iter().enumerate() {
            let id = BlockId::new();
            ids.push(id);
            tree.apply(&Op::InsertBlock {
                block_id: id,
                parent_id: None,
                position: i as u32,
                content: content.to_string(),
                depth: 0,
            });
        }
        (tree, ids)
    }

    #[test]
    fn single_block_update() {
        let (tree, ids) = make_tree(&["Hello World"]);
        // Replace "World" (offset 6, length 5) with "Rust"
        let ops = translate_edit(&tree, 6, 5, "Rust");
        assert_eq!(ops.len(), 1);
        match &ops[0] {
            Op::UpdateBlock { block_id, content } => {
                assert_eq!(*block_id, ids[0]);
                assert_eq!(content, "Hello Rust");
            }
            _ => panic!("Expected UpdateBlock"),
        }
    }

    #[test]
    fn enter_key_splits_block() {
        let (tree, _ids) = make_tree(&["Hello World"]);
        // Insert newline at offset 5: "Hello\nWorld"
        let ops = translate_edit(&tree, 5, 0, "\n");
        assert_eq!(ops.len(), 2);
        match &ops[0] {
            Op::UpdateBlock { content, .. } => assert_eq!(content, "Hello"),
            _ => panic!("Expected UpdateBlock"),
        }
        match &ops[1] {
            Op::InsertBlock { content, .. } => assert_eq!(content, " World"),
            _ => panic!("Expected InsertBlock"),
        }
    }

    #[test]
    fn empty_tree_creates_block() {
        let tree = BlockTree::new();
        let ops = translate_edit(&tree, 0, 0, "First block");
        assert_eq!(ops.len(), 1);
        match &ops[0] {
            Op::InsertBlock { content, .. } => assert_eq!(content, "First block"),
            _ => panic!("Expected InsertBlock"),
        }
    }
}
