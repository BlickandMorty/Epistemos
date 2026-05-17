use serde_json::{json, Value};

use super::{TriFusionDocument, TriFusionError};

impl TriFusionDocument {
    pub fn parse_markdown(input: &str) -> Result<Self, TriFusionError> {
        parse_markdown_document(input)
    }

    pub fn to_markdown(&self) -> Result<String, TriFusionError> {
        render_markdown_document(self.root())
    }
}

fn parse_markdown_document(input: &str) -> Result<TriFusionDocument, TriFusionError> {
    if input.contains('\r') {
        return Err(invalid_markdown(
            1,
            "canonical Markdown uses LF line endings only",
        ));
    }

    let lines: Vec<&str> = if input.is_empty() {
        Vec::new()
    } else {
        input.split('\n').collect()
    };
    let mut content = Vec::new();
    let mut index = 0;

    while index < lines.len() {
        let line = lines[index];
        if line.is_empty() {
            index += 1;
            continue;
        }

        if starts_unsupported_markdown_block(line) {
            return Err(invalid_markdown(
                index + 1,
                "Markdown block is outside the canonical subset",
            ));
        }

        if let Some((level, text)) = parse_heading_line(line) {
            content.push(json!({
                "type": "heading",
                "attrs": {
                    "level": level,
                },
                "content": [text_node(text)],
            }));
            index += 1;
            continue;
        }

        if let Some(raw_language) = line.strip_prefix("```") {
            let language = raw_language.trim();
            if language.contains('`') || language.split_whitespace().count() > 1 {
                return Err(invalid_markdown(
                    index + 1,
                    "code fence language must be one token",
                ));
            }

            let start_line = index + 1;
            index += 1;
            let mut code_lines = Vec::new();
            let mut closed = false;
            while index < lines.len() {
                if lines[index] == "```" {
                    closed = true;
                    index += 1;
                    break;
                }
                if lines[index].starts_with("```") {
                    return Err(invalid_markdown(
                        index + 1,
                        "closing code fence must be exactly ```",
                    ));
                }
                code_lines.push(lines[index]);
                index += 1;
            }
            if !closed {
                return Err(invalid_markdown(start_line, "unclosed code fence"));
            }

            let mut attrs = serde_json::Map::new();
            if !language.is_empty() {
                attrs.insert("language".to_string(), Value::String(language.to_string()));
            }
            content.push(json!({
                "type": "codeBlock",
                "attrs": attrs,
                "content": [text_node(code_lines.join("\n"))],
            }));
            continue;
        }

        if is_blockquote_line(line) {
            let mut quote_lines = Vec::new();
            while index < lines.len() && is_blockquote_line(lines[index]) {
                let body = &lines[index][1..];
                quote_lines.push(body.strip_prefix(' ').unwrap_or(body));
                index += 1;
            }
            content.push(json!({
                "type": "blockquote",
                "content": [paragraph_node(quote_lines.join("\n"))],
            }));
            continue;
        }

        if line.starts_with("- ") {
            let mut items = Vec::new();
            while index < lines.len() {
                let Some(item_text) = lines[index].strip_prefix("- ") else {
                    break;
                };
                items.push(json!({
                    "type": "listItem",
                    "content": [paragraph_node(item_text)],
                }));
                index += 1;
            }
            content.push(json!({
                "type": "bulletList",
                "content": items,
            }));
            continue;
        }

        let mut paragraph_lines = Vec::new();
        while index < lines.len()
            && !lines[index].is_empty()
            && !starts_markdown_block(lines[index])
        {
            paragraph_lines.push(lines[index]);
            index += 1;
        }
        content.push(paragraph_node(paragraph_lines.join("\n")));
    }

    TriFusionDocument::from_json_value(json!({
        "type": "doc",
        "content": content,
    }))
}

fn render_markdown_document(root: &Value) -> Result<String, TriFusionError> {
    let content = root
        .as_object()
        .and_then(|object| object.get("content"))
        .and_then(Value::as_array)
        .ok_or_else(|| unsupported("$", "document root must have array content"))?;

    let mut blocks = Vec::with_capacity(content.len());
    for (index, node) in content.iter().enumerate() {
        blocks.push(render_block(node, &format!("$.content[{index}]"))?);
    }
    Ok(blocks.join("\n\n"))
}

fn render_block(node: &Value, path: &str) -> Result<String, TriFusionError> {
    match node_type(node, path)? {
        "paragraph" => plain_text(node, path),
        "heading" => render_heading(node, path),
        "codeBlock" => render_code_block(node, path),
        "blockquote" => render_blockquote(node, path),
        "bulletList" => render_bullet_list(node, path),
        kind => Err(unsupported(
            path,
            &format!("node type {kind:?} has no canonical Markdown spelling yet"),
        )),
    }
}

fn render_heading(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let level = node
        .get("attrs")
        .and_then(Value::as_object)
        .and_then(|attrs| attrs.get("level"))
        .and_then(Value::as_u64)
        .ok_or_else(|| unsupported(path, "heading requires attrs.level"))?;
    if !(1..=6).contains(&level) {
        return Err(unsupported(path, "heading level must be between 1 and 6"));
    }
    let text = plain_text(node, path)?;
    if text.contains('\n') {
        return Err(unsupported(path, "heading text must not contain newlines"));
    }
    Ok(format!("{} {text}", "#".repeat(level as usize)))
}

fn render_code_block(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let language = node
        .get("attrs")
        .and_then(Value::as_object)
        .and_then(|attrs| attrs.get("language"))
        .and_then(Value::as_str)
        .unwrap_or("");
    if language.contains('`') || language.split_whitespace().count() > 1 {
        return Err(unsupported(path, "code block language must be one token"));
    }

    let text = plain_text(node, path)?;
    if text.contains("```") {
        return Err(unsupported(path, "code block text contains a fence"));
    }

    if text.is_empty() {
        Ok(format!("```{language}\n```"))
    } else {
        Ok(format!("```{language}\n{text}\n```"))
    }
}

fn render_blockquote(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let children = node_children(node, path)?;
    if children.len() != 1 || node_type(&children[0], &format!("{path}.content[0]"))? != "paragraph"
    {
        return Err(unsupported(
            path,
            "blockquote Markdown projection supports one paragraph child",
        ));
    }

    let text = plain_text(&children[0], &format!("{path}.content[0]"))?;
    Ok(text
        .split('\n')
        .map(|line| {
            if line.is_empty() {
                ">".to_string()
            } else {
                format!("> {line}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n"))
}

fn render_bullet_list(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let children = node_children(node, path)?;
    let mut rendered = Vec::with_capacity(children.len());
    for (index, item) in children.iter().enumerate() {
        let item_path = format!("{path}.content[{index}]");
        if node_type(item, &item_path)? != "listItem" {
            return Err(unsupported(
                &item_path,
                "bullet list children must be listItem",
            ));
        }
        let item_children = node_children(item, &item_path)?;
        if item_children.len() != 1
            || node_type(&item_children[0], &format!("{item_path}.content[0]"))? != "paragraph"
        {
            return Err(unsupported(
                &item_path,
                "list item Markdown projection supports one paragraph child",
            ));
        }

        let text = plain_text(&item_children[0], &format!("{item_path}.content[0]"))?;
        if text.contains('\n') {
            return Err(unsupported(
                &item_path,
                "list item text must not contain newlines",
            ));
        }
        rendered.push(format!("- {text}"));
    }
    Ok(rendered.join("\n"))
}

fn plain_text(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let children = node_children(node, path)?;
    let mut out = String::new();
    for (index, child) in children.iter().enumerate() {
        let child_path = format!("{path}.content[{index}]");
        if node_type(child, &child_path)? != "text" {
            return Err(unsupported(
                &child_path,
                "Markdown projection supports text inline nodes only",
            ));
        }
        if let Some(marks) = child.get("marks") {
            match marks.as_array() {
                Some(values) if values.is_empty() => {}
                Some(_) => {
                    return Err(unsupported(
                        &child_path,
                        "marked inline text is not in the canonical subset yet",
                    ));
                }
                None => {
                    return Err(unsupported(&child_path, "marks must be an array"));
                }
            }
        }
        let text = child
            .get("text")
            .and_then(Value::as_str)
            .ok_or_else(|| unsupported(&child_path, "text node must carry text"))?;
        if text.contains('\r') {
            return Err(unsupported(
                &child_path,
                "Markdown projection uses LF line endings only",
            ));
        }
        out.push_str(text);
    }
    Ok(out)
}

fn node_children<'a>(node: &'a Value, path: &str) -> Result<Vec<&'a Value>, TriFusionError> {
    node.get("content")
        .and_then(Value::as_array)
        .map(|values| values.iter().collect())
        .ok_or_else(|| unsupported(path, "node must have array content"))
}

fn node_type<'a>(node: &'a Value, path: &str) -> Result<&'a str, TriFusionError> {
    node.get("type")
        .and_then(Value::as_str)
        .ok_or_else(|| unsupported(path, "node must carry string type"))
}

fn starts_markdown_block(line: &str) -> bool {
    parse_heading_line(line).is_some()
        || line.starts_with("```")
        || line.starts_with("- ")
        || is_blockquote_line(line)
        || starts_unsupported_markdown_block(line)
}

fn starts_unsupported_markdown_block(line: &str) -> bool {
    line.starts_with('|') || looks_like_ordered_list_item(line)
}

fn looks_like_ordered_list_item(line: &str) -> bool {
    let Some((number, rest)) = line.split_once(". ") else {
        return false;
    };
    !number.is_empty() && number.bytes().all(|byte| byte.is_ascii_digit()) && !rest.is_empty()
}

fn parse_heading_line(line: &str) -> Option<(usize, &str)> {
    let bytes = line.as_bytes();
    let mut level = 0;
    while level < bytes.len() && bytes[level] == b'#' {
        level += 1;
    }
    if !(1..=6).contains(&level) || bytes.get(level) != Some(&b' ') {
        return None;
    }
    let text = &line[level + 1..];
    if text.is_empty() {
        None
    } else {
        Some((level, text))
    }
}

fn is_blockquote_line(line: &str) -> bool {
    line == ">" || line.starts_with("> ")
}

fn paragraph_node(text: impl Into<String>) -> Value {
    json!({
        "type": "paragraph",
        "content": [text_node(text)],
    })
}

fn text_node(text: impl Into<String>) -> Value {
    json!({
        "type": "text",
        "text": text.into(),
    })
}

fn invalid_markdown(line: usize, message: impl Into<String>) -> TriFusionError {
    TriFusionError::InvalidMarkdown {
        line,
        message: message.into(),
    }
}

fn unsupported(path: &str, message: &str) -> TriFusionError {
    TriFusionError::UnsupportedMarkdownProjection {
        path: path.to_string(),
        message: message.to_string(),
    }
}
