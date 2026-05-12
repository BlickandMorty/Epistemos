//! Clarify Tool — Ask the User a Question Mid-Session
//!
//! When the agent reaches an ambiguous point it can call `clarify` to ask
//! the user a question and wait for a structured response. The Rust side
//! forwards the question JSON through `AgentEventDelegate::ask_user_question`;
//! the Swift UI renders it (sheet or popover) and returns the answer synchronously.
//!
//! Returned payload shape:
//! ```json
//! {
//!   "question": "...",
//!   "response": "user's answer",
//!   "choice_index": 2   // null if free-form or no choices provided
//! }
//! ```

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::{json, Value};

use crate::bridge::AgentEventDelegate;

use super::registry::{ToolError, ToolHandler};

const MAX_QUESTION_CHARS: usize = 4_000;
const MAX_CHOICES: usize = 4;
const MAX_CHOICE_CHARS: usize = 1_000;
const MAX_DELEGATE_RESPONSE_CHARS: usize = 64 * 1024;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn parse_delegate_json(response: String) -> Result<Value, ToolError> {
    if response.chars().count() > MAX_DELEGATE_RESPONSE_CHARS {
        return Err(ToolError::ExecutionFailed(format!(
            "clarify delegate response exceeded {MAX_DELEGATE_RESPONSE_CHARS} character cap"
        )));
    }
    serde_json::from_str(&response).map_err(|_| {
        ToolError::ExecutionFailed(
            "clarify delegate returned non-JSON payload; raw output redacted".into(),
        )
    })
}

pub struct ClarifyHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl ClarifyHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for ClarifyHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let question = input
            .get("question")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'question'".into()))?;
        ensure_char_cap("question", question, MAX_QUESTION_CHARS)?;

        let choices = match input.get("choices") {
            Some(Value::Array(arr)) => {
                if arr.len() > MAX_CHOICES {
                    return Err(ToolError::InvalidArguments(
                        "'choices' supports at most 4 options (plus implicit 'Other')".into(),
                    ));
                }
                let mut choices = Vec::with_capacity(arr.len());
                for (idx, value) in arr.iter().enumerate() {
                    let choice = value.as_str().ok_or_else(|| {
                        ToolError::InvalidArguments(format!("'choices[{idx}]' must be a string"))
                    })?;
                    ensure_char_cap(&format!("choices[{idx}]"), choice, MAX_CHOICE_CHARS)?;
                    choices.push(choice.to_string());
                }
                choices
            }
            Some(_) => {
                return Err(ToolError::InvalidArguments(
                    "'choices' must be an array when supplied".into(),
                ));
            }
            None => Vec::new(),
        };
        if choices.len() > MAX_CHOICES {
            return Err(ToolError::InvalidArguments(
                "'choices' supports at most 4 options (plus implicit 'Other')".into(),
            ));
        }

        let payload = json!({
            "question": question,
            "choices": choices,
        })
        .to_string();

        // Hand off to Swift via the delegate callback. The callback blocks
        // until the user answers, so we offload to a blocking task to avoid
        // starving the tokio executor if the Swift side takes time to render.
        let delegate = Arc::clone(&self.delegate);
        let payload_for_task = payload.clone();
        let response_json =
            tokio::task::spawn_blocking(move || delegate.ask_user_question(payload_for_task))
                .await
                .map_err(|e| ToolError::ExecutionFailed(format!("clarify join error: {e}")))?;

        let parsed = parse_delegate_json(response_json)?;

        Ok(json!({
            "question": question,
            "response": parsed.get("response").cloned().unwrap_or(Value::Null),
            "choice_index": parsed.get("choice_index").cloned().unwrap_or(Value::Null),
        })
        .to_string())
    }
}

pub fn clarify_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "clarify".to_string(),
        description: "Ask the user a clarifying question and wait for their response. \
             Supply up to 4 multiple-choice options via 'choices' or leave the array \
             empty for a free-form answer. Returns the user's response and the selected \
             choice index (if any)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "question": { "type": "string", "description": "The question to show the user." },
                "choices": {
                    "type": "array",
                    "description": "Optional multiple-choice options (max 4).",
                    "items": { "type": "string" }
                }
            },
            "required": ["question"]
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// In-memory delegate that captures the last question and returns a
    /// scripted response. Lets us unit-test the clarify handler without any
    /// Swift bridge.
    struct ScriptedDelegate {
        last_question: Mutex<Option<String>>,
        scripted_response: String,
    }

    impl ScriptedDelegate {
        fn new(response: &str) -> Self {
            Self {
                last_question: Mutex::new(None),
                scripted_response: response.to_string(),
            }
        }
    }

    impl AgentEventDelegate for ScriptedDelegate {
        fn on_thinking_delta(&self, _: String) {}
        fn on_text_delta(&self, _: String) {}
        fn on_tool_input_delta(&self, _: u32, _: String) {}
        fn on_tool_started(&self, _: String, _: String, _: String) {}
        fn on_tool_completed(&self, _: String, _: String, _: bool) {}
        fn on_subagent_spawned(&self, _: String, _: String) {}
        fn on_permission_required(&self, _: String, _: String, _: String, _: String) {}
        fn on_context_compacting(&self, _: u32) {}
        fn on_context_compacted(&self, _: u32) {}
        fn on_turn_started(&self, _: u32, _: u32) {}
        fn on_complete(&self, _: String, _: u32, _: u32) {}
        fn on_error(&self, _: String) {}
        fn execute_computer_action(&self, _: String) -> String {
            "{}".to_string()
        }
        fn wait_for_permission(&self, _: String) -> bool {
            true
        }
        fn ask_user_question(&self, question_json: String) -> String {
            *self.last_question.lock().unwrap() = Some(question_json);
            self.scripted_response.clone()
        }
        fn perceive_app(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn interact_with_app(&self, _: String) -> String {
            "{}".to_string()
        }
        fn start_screen_watch(&self, _: String) -> String {
            "{}".to_string()
        }
        fn manage_ssm_state(&self, _: String) -> String {
            "{}".to_string()
        }
        fn generate_constrained(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn generate_image(&self, _: String, _: String) -> String {
            "{\"error\":\"image_generate stub\"}".to_string()
        }
        fn trigger_nightbrain_job(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn get_partner_context(&self, _: String, _: u32) -> String {
            "{}".to_string()
        }
    }

    #[tokio::test]
    async fn clarify_forwards_question_and_returns_response() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(ScriptedDelegate::new(
            r#"{"response":"option A","choice_index":0}"#,
        ));
        let handler = ClarifyHandler::new(delegate);

        let result = handler
            .execute(&json!({
                "question": "Which one?",
                "choices": ["A", "B"]
            }))
            .await
            .unwrap();

        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["response"], json!("option A"));
        assert_eq!(parsed["choice_index"], json!(0));
        assert_eq!(parsed["question"], json!("Which one?"));
    }

    #[tokio::test]
    async fn clarify_rejects_too_many_choices() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(ScriptedDelegate::new("{\"response\":\"x\"}"));
        let handler = ClarifyHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "question": "Pick one",
                "choices": ["a", "b", "c", "d", "e"]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("at most 4"));
    }

    #[tokio::test]
    async fn clarify_rejects_oversized_question() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(ScriptedDelegate::new("{\"response\":\"x\"}"));
        let handler = ClarifyHandler::new(delegate);
        let question = "q".repeat(MAX_QUESTION_CHARS + 1);
        let err = handler
            .execute(&json!({ "question": question }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("question exceeds"));
    }

    #[tokio::test]
    async fn clarify_rejects_non_string_choice() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(ScriptedDelegate::new("{\"response\":\"x\"}"));
        let handler = ClarifyHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "question": "Pick one",
                "choices": ["a", 2]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("choices[1]"));
    }

    #[tokio::test]
    async fn clarify_rejects_oversized_choice() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(ScriptedDelegate::new("{\"response\":\"x\"}"));
        let handler = ClarifyHandler::new(delegate);
        let choice = "c".repeat(MAX_CHOICE_CHARS + 1);
        let err = handler
            .execute(&json!({
                "question": "Pick one",
                "choices": [choice]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("choices[0] exceeds"));
    }

    #[tokio::test]
    async fn clarify_errors_on_non_json_delegate_response() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(ScriptedDelegate::new("not json sk-secret-token"));
        let handler = ClarifyHandler::new(delegate);
        let err = handler
            .execute(&json!({ "question": "?" }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("sk-secret-token"));
    }

    #[tokio::test]
    async fn clarify_rejects_oversized_delegate_response() {
        let raw = "r".repeat(MAX_DELEGATE_RESPONSE_CHARS + 1);
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(ScriptedDelegate::new(&raw));
        let handler = ClarifyHandler::new(delegate);
        let err = handler
            .execute(&json!({ "question": "?" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("delegate response exceeded"));
    }
}
