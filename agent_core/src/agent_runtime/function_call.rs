use serde::{Deserialize, Serialize};
use serde_json::Value;

const EXACT_TOOL_OPEN_TAG: &str = "<tool_call>";
const MALFORMED_TOOL_OPEN_TAG: &str = "<tool_call<";
const TOOL_CLOSE_TAG: &str = "</tool_call>";
const HIDDEN_TAG_PAIRS: [(&str, &str); 2] =
    [("<scratch_pad>", "</scratch_pad>"), ("<think>", "</think>")];

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HermesToolCall {
    pub name: String,
    pub arguments_json: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolCallDetection {
    pub call: HermesToolCall,
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

pub fn parse_tool_calls(text: &str) -> Vec<HermesToolCall> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }

    if let Ok(value) = serde_json::from_str::<Value>(trimmed) {
        return calls_from_value(&value);
    }

    let mut calls = Vec::new();
    let mut cursor = 0;
    while let Some(open_relative) = text[cursor..].find(EXACT_TOOL_OPEN_TAG) {
        let open = cursor + open_relative + EXACT_TOOL_OPEN_TAG.len();
        let Some(close_relative) = text[open..].find(TOOL_CLOSE_TAG) else {
            break;
        };
        let close = open + close_relative;
        calls.extend(parse_tool_calls(&text[open..close]));
        cursor = close + TOOL_CLOSE_TAG.len();
    }
    calls
}

fn calls_from_value(value: &Value) -> Vec<HermesToolCall> {
    match value {
        Value::Array(values) => values.iter().flat_map(calls_from_value).collect(),
        Value::Object(map) => {
            let Some(name) = map.get("name").and_then(Value::as_str) else {
                return Vec::new();
            };
            let arguments = map
                .get("arguments")
                .or_else(|| map.get("parameters"))
                .cloned()
                .unwrap_or_else(|| Value::Object(Default::default()));
            let arguments_json =
                serde_json::to_string(&arguments).unwrap_or_else(|_| "{}".to_string());
            vec![HermesToolCall {
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
