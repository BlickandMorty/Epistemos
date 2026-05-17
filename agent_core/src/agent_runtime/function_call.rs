use serde::{Deserialize, Serialize};
use serde_json::Value;

const EXACT_TOOL_OPEN_TAG: &str = "<tool_call>";
const MALFORMED_TOOL_OPEN_TAG: &str = "<tool_call<";
const TOOL_CLOSE_TAG: &str = "</tool_call>";
const PHI_TOOL_OPEN_TAG: &str = "<|tool_call|>";
const PHI_TOOL_CLOSE_TAG: &str = "<|/tool_call|>";
const MISTRAL_TOOL_CALLS_MARKER: &str = "[TOOL_CALLS]";
const DEEPSEEK_TOOL_SEP: &str = "<｜tool▁sep｜>";
const HIDDEN_TAG_PAIRS: [(&str, &str); 2] =
    [("<scratch_pad>", "</scratch_pad>"), ("<think>", "</think>")];

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimeToolCall {
    pub name: String,
    pub arguments_json: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolCallDetection {
    pub call: RuntimeToolCall,
    pub raw_content: String,
}

#[derive(Clone, Debug, Default)]
pub struct StreamingToolCallDetector {
    buffer: String,
    pending_text: String,
}

impl StreamingToolCallDetector {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn pending_text(&self) -> &str {
        &self.pending_text
    }

    pub fn feed(&mut self, chunk: &str) -> Option<ToolCallDetection> {
        if chunk.is_empty() {
            return None;
        }
        self.buffer.push_str(chunk);

        while !self.buffer.is_empty() {
            if self.consume_leading_hidden_range() {
                continue;
            }

            if let Some(detection) = self.consume_leading_tool_call() {
                return Some(detection);
            }

            if let Some(next_tag_index) = next_interesting_tag_index(&self.buffer) {
                if next_tag_index > 0 {
                    self.pending_text.push_str(&self.buffer[..next_tag_index]);
                    self.buffer.drain(..next_tag_index);
                    continue;
                }
                break;
            }

            let partial_length = trailing_partial_prefix_length(&self.buffer);
            let flush_count = self.buffer.len().saturating_sub(partial_length);
            if flush_count == 0 {
                break;
            }
            self.pending_text.push_str(&self.buffer[..flush_count]);
            self.buffer.drain(..flush_count);
        }

        None
    }

    pub fn reset(&mut self) {
        self.buffer.clear();
        self.pending_text.clear();
    }

    pub fn flush_on_stream_end(&mut self) -> String {
        if self.buffer.is_empty() {
            return String::new();
        }

        if HIDDEN_TAG_PAIRS
            .iter()
            .any(|(open, _)| self.buffer.starts_with(open))
            || self.buffer.starts_with(EXACT_TOOL_OPEN_TAG)
            || self.buffer.starts_with(MALFORMED_TOOL_OPEN_TAG)
        {
            self.buffer.clear();
            return String::new();
        }

        let flushed = std::mem::take(&mut self.buffer);
        self.pending_text.push_str(&flushed);
        flushed
    }

    fn consume_leading_hidden_range(&mut self) -> bool {
        for (open, close) in HIDDEN_TAG_PAIRS {
            if !self.buffer.starts_with(open) {
                continue;
            }
            if let Some(close_start) = self.buffer.find(close) {
                let end = close_start + close.len();
                self.buffer.drain(..end);
                return true;
            }
        }
        false
    }

    fn consume_leading_tool_call(&mut self) -> Option<ToolCallDetection> {
        let body_start_offset = if self.buffer.starts_with(EXACT_TOOL_OPEN_TAG) {
            EXACT_TOOL_OPEN_TAG.len()
        } else if self.buffer.starts_with(MALFORMED_TOOL_OPEN_TAG) {
            EXACT_TOOL_OPEN_TAG.trim_end_matches('>').len()
        } else {
            return None;
        };

        let close_start = self.buffer.find(TOOL_CLOSE_TAG)?;
        if body_start_offset > close_start {
            let end = close_start + TOOL_CLOSE_TAG.len();
            self.buffer.drain(..end);
            return None;
        }

        let raw_content = self.buffer[body_start_offset..close_start]
            .trim()
            .to_string();
        let end = close_start + TOOL_CLOSE_TAG.len();
        self.buffer.drain(..end);

        parse_tool_calls(&raw_content)
            .into_iter()
            .next()
            .map(|call| ToolCallDetection { call, raw_content })
    }
}

pub fn parse_tool_calls(text: &str) -> Vec<RuntimeToolCall> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }

    if let Some(calls) = parse_json_calls(trimmed) {
        return calls;
    }

    let mut calls = parse_tagged_blocks(text, EXACT_TOOL_OPEN_TAG, TOOL_CLOSE_TAG);
    calls.extend(parse_tagged_blocks(
        text,
        PHI_TOOL_OPEN_TAG,
        PHI_TOOL_CLOSE_TAG,
    ));
    calls.extend(parse_mistral_tool_calls(text));
    calls.extend(parse_deepseek_tool_calls(text));
    calls.extend(parse_markdown_json_blocks(text));

    if calls.is_empty() {
        calls.extend(parse_embedded_json_fragments(text));
    }
    calls
}

fn parse_json_calls(text: &str) -> Option<Vec<RuntimeToolCall>> {
    let value = serde_json::from_str::<Value>(text).ok()?;
    let calls = calls_from_value(&value);
    (!calls.is_empty()).then_some(calls)
}

fn parse_tagged_blocks(text: &str, open_tag: &str, close_tag: &str) -> Vec<RuntimeToolCall> {
    let mut calls = Vec::new();
    let mut cursor = 0;
    while let Some(open_relative) = text[cursor..].find(open_tag) {
        let open = cursor + open_relative + open_tag.len();
        let Some(close_relative) = text[open..].find(close_tag) else {
            break;
        };
        let close = open + close_relative;
        calls.extend(parse_tool_calls(&text[open..close]));
        cursor = close + close_tag.len();
    }
    calls
}

fn parse_mistral_tool_calls(text: &str) -> Vec<RuntimeToolCall> {
    let Some(marker_start) = text.find(MISTRAL_TOOL_CALLS_MARKER) else {
        return Vec::new();
    };
    let start = marker_start + MISTRAL_TOOL_CALLS_MARKER.len();
    parse_embedded_json_fragments(&text[start..])
}

fn parse_deepseek_tool_calls(text: &str) -> Vec<RuntimeToolCall> {
    let Some(separator_start) = text.find(DEEPSEEK_TOOL_SEP) else {
        return Vec::new();
    };
    let after_separator = &text[separator_start + DEEPSEEK_TOOL_SEP.len()..];
    let name = after_separator
        .lines()
        .next()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let Some(name) = name else {
        return parse_markdown_json_blocks(after_separator);
    };

    let parsed_calls = parse_markdown_json_blocks(after_separator);
    if !parsed_calls.is_empty() {
        return parsed_calls;
    }

    first_markdown_json_body(after_separator)
        .and_then(|body| serde_json::from_str::<Value>(body.trim()).ok())
        .map(|arguments| RuntimeToolCall {
            name: name.to_string(),
            arguments_json: serde_json::to_string(&arguments).unwrap_or_else(|_| "{}".to_string()),
        })
        .into_iter()
        .collect()
}

fn parse_markdown_json_blocks(text: &str) -> Vec<RuntimeToolCall> {
    let mut calls = Vec::new();
    let mut cursor = 0;

    while let Some(fence_relative) = text[cursor..].find("```") {
        let fence_start = cursor + fence_relative;
        let body_start = match text[fence_start + 3..].find('\n') {
            Some(newline_relative) => fence_start + 3 + newline_relative + 1,
            None => fence_start + 3,
        };
        let Some(close_relative) = text[body_start..].find("```") else {
            break;
        };
        let close = body_start + close_relative;
        calls.extend(parse_tool_calls(text[body_start..close].trim()));
        cursor = close + 3;
    }

    calls
}

fn first_markdown_json_body(text: &str) -> Option<&str> {
    let fence_start = text.find("```")?;
    let body_start = match text[fence_start + 3..].find('\n') {
        Some(newline_relative) => fence_start + 3 + newline_relative + 1,
        None => fence_start + 3,
    };
    let close_relative = text[body_start..].find("```")?;
    Some(&text[body_start..body_start + close_relative])
}

fn parse_embedded_json_fragments(text: &str) -> Vec<RuntimeToolCall> {
    let characters = text.char_indices().collect::<Vec<_>>();
    let mut calls = Vec::new();
    let mut index = 0;

    while index < characters.len() {
        let (_, character) = characters[index];
        if character != '{' && character != '[' {
            index += 1;
            continue;
        }

        let Some(end_index) = matching_json_end(&characters, index) else {
            index += 1;
            continue;
        };
        let start_byte = characters[index].0;
        let end_byte = characters
            .get(end_index + 1)
            .map(|(byte, _)| *byte)
            .unwrap_or_else(|| text.len());
        if let Some(parsed) = parse_json_calls(text[start_byte..end_byte].trim()) {
            calls.extend(parsed);
        }
        index = end_index + 1;
    }

    calls
}

fn matching_json_end(characters: &[(usize, char)], start_index: usize) -> Option<usize> {
    let mut stack = vec![characters[start_index].1];
    let mut in_string = false;
    let mut escaped = false;
    let mut index = start_index + 1;

    while index < characters.len() {
        let character = characters[index].1;
        if in_string {
            if escaped {
                escaped = false;
            } else if character == '\\' {
                escaped = true;
            } else if character == '"' {
                in_string = false;
            }
            index += 1;
            continue;
        }

        match character {
            '"' => in_string = true,
            '{' | '[' => stack.push(character),
            '}' => {
                if stack.pop() != Some('{') {
                    return None;
                }
                if stack.is_empty() {
                    return Some(index);
                }
            }
            ']' => {
                if stack.pop() != Some('[') {
                    return None;
                }
                if stack.is_empty() {
                    return Some(index);
                }
            }
            _ => {}
        }
        index += 1;
    }

    None
}

fn calls_from_value(value: &Value) -> Vec<RuntimeToolCall> {
    match value {
        Value::Array(values) => values.iter().flat_map(calls_from_value).collect(),
        Value::Object(map) => {
            let Some(name) = map
                .get("name")
                .or_else(|| map.get("function"))
                .or_else(|| map.get("toolName"))
                .or_else(|| map.get("tool"))
                .and_then(Value::as_str)
            else {
                return Vec::new();
            };
            let arguments = map
                .get("arguments")
                .or_else(|| map.get("parameters"))
                .or_else(|| map.get("args"))
                .cloned()
                .unwrap_or_else(|| Value::Object(Default::default()));
            let arguments_json =
                serde_json::to_string(&arguments).unwrap_or_else(|_| "{}".to_string());
            vec![RuntimeToolCall {
                name: name.to_string(),
                arguments_json,
            }]
        }
        _ => Vec::new(),
    }
}

fn next_interesting_tag_index(text: &str) -> Option<usize> {
    [
        EXACT_TOOL_OPEN_TAG,
        MALFORMED_TOOL_OPEN_TAG,
        "<scratch_pad>",
        "<think>",
    ]
    .iter()
    .filter_map(|marker| text.find(marker))
    .min()
}

fn trailing_partial_prefix_length(text: &str) -> usize {
    if text.is_empty() {
        return 0;
    }

    let candidates = prefix_candidates();
    let max_len = candidates
        .iter()
        .map(|candidate| candidate.len())
        .max()
        .unwrap_or(0);
    let upper = text.len().min(max_len.saturating_sub(1));

    for length in (1..=upper).rev() {
        if !text.is_char_boundary(text.len() - length) {
            continue;
        }
        let suffix = &text[text.len() - length..];
        if candidates
            .iter()
            .any(|candidate| candidate.starts_with(suffix))
        {
            return length;
        }
    }

    0
}

fn prefix_candidates() -> [&'static str; 7] {
    [
        EXACT_TOOL_OPEN_TAG,
        MALFORMED_TOOL_OPEN_TAG,
        TOOL_CLOSE_TAG,
        "<scratch_pad>",
        "</scratch_pad>",
        "<think>",
        "</think>",
    ]
}

#[cfg(test)]
mod tests {
    use super::parse_tool_calls;

    #[test]
    fn parses_qwen_xml_tool_call() {
        let calls = parse_tool_calls(
            r#"<tool_call>
{"name":"vault.read","arguments":{"path":"A.md"}}
</tool_call>"#,
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "vault.read");
        assert_eq!(calls[0].arguments_json, r#"{"path":"A.md"}"#);
    }

    #[test]
    fn parses_hermes_json_tool_call() {
        let calls = parse_tool_calls(r#"{"name":"file.write","arguments":{"path":"tmp/a.txt"}}"#);

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "file.write");
        assert_eq!(calls[0].arguments_json, r#"{"path":"tmp/a.txt"}"#);
    }

    #[test]
    fn parses_mistral_tool_calls_marker() {
        let calls = parse_tool_calls(
            r#"[TOOL_CALLS] [{"name":"vault.search","arguments":{"query":"agent"}}]"#,
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "vault.search");
        assert_eq!(calls[0].arguments_json, r#"{"query":"agent"}"#);
    }

    #[test]
    fn parses_phi_tool_call_block() {
        let calls = parse_tool_calls(
            r#"<|tool_call|>{"name":"file.read","parameters":{"path":"tmp/a.txt"}}<|/tool_call|>"#,
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "file.read");
        assert_eq!(calls[0].arguments_json, r#"{"path":"tmp/a.txt"}"#);
    }

    #[test]
    fn parses_deepseek_tool_separator_with_arguments_body() {
        let calls = parse_tool_calls(
            "prefix <｜tool▁sep｜>vault.write\n```json\n{\"path\":\"A.md\",\"content\":\"hello\"}\n```",
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "vault.write");
        assert_eq!(
            calls[0].arguments_json,
            r#"{"path":"A.md","content":"hello"}"#
        );
    }

    #[test]
    fn parses_llama_style_function_parameters() {
        let calls = parse_tool_calls(
            r#"assistant prose {"function":"web.search","parameters":{"query":"local agents"}}"#,
        );

        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "web.search");
        assert_eq!(calls[0].arguments_json, r#"{"query":"local agents"}"#);
    }
}
