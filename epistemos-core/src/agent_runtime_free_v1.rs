use serde::{Deserialize, Serialize};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentEvent {
    pub sequence: u64,
    pub phase: String,
    pub payload: String,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentTurnResult {
    pub session_id: String,
    pub stop_reason: String,
    pub assistant_text: String,
    pub turn_count: u32,
    pub emitted_event_count: u32,
    pub transcript_path: String,
}

pub struct AgentSession {
    session_id: String,
    transcript_path: PathBuf,
    events: Mutex<Vec<AgentEvent>>,
}

impl AgentSession {
    pub fn new(session_id: String, transcript_root: String) -> Self {
        let safe_session_id = sanitize_session_id(&session_id);
        let root = if transcript_root.is_empty() {
            std::env::temp_dir()
        } else {
            PathBuf::from(transcript_root)
        };
        let session_dir = root.join(&safe_session_id);
        let _ = fs::create_dir_all(&session_dir);
        Self {
            session_id: safe_session_id,
            transcript_path: session_dir.join("transcript.jsonl"),
            events: Mutex::new(Vec::new()),
        }
    }

    pub fn run_scaffold_turn(&self, user_message: String) -> AgentTurnResult {
        self.record_unavailable_turn(user_message)
    }

    pub fn set_provider_api_key(&self, _provider: String, _api_key: String) -> bool {
        false
    }

    pub fn run_live_routed_turn(&self, user_message: String) -> AgentTurnResult {
        self.record_unavailable_turn(user_message)
    }

    pub fn run_live_provider_turn(&self, user_message: String, _provider: String) -> AgentTurnResult {
        self.record_unavailable_turn(user_message)
    }

    pub fn drain_events(&self) -> Vec<AgentEvent> {
        self.events.lock().map(|events| events.clone()).unwrap_or_default()
    }

    pub fn transcript_path(&self) -> String {
        self.transcript_path.display().to_string()
    }

    pub fn transcript_jsonl(&self) -> String {
        fs::read_to_string(&self.transcript_path).unwrap_or_default()
    }

    pub fn runtime_blueprint_json(&self) -> String {
        "{\"edition\":\"free_v1\",\"available\":false}".to_string()
    }

    pub fn route_objective_json(&self, _objective: String) -> String {
        "{\"edition\":\"free_v1\",\"available\":false}".to_string()
    }

    fn record_unavailable_turn(&self, user_message: String) -> AgentTurnResult {
        let text = if user_message.trim().is_empty() {
            "This feature is unavailable in this edition.".to_string()
        } else {
            "This feature is unavailable in this edition.".to_string()
        };
        let result = AgentTurnResult {
            session_id: self.session_id.clone(),
            stop_reason: "unavailable".to_string(),
            assistant_text: text,
            turn_count: 0,
            emitted_event_count: 0,
            transcript_path: self.transcript_path(),
        };
        self.append_transcript(&result);
        result
    }

    fn append_transcript(&self, result: &AgentTurnResult) {
        if let Some(parent) = self.transcript_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(mut file) = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.transcript_path)
        {
            if let Ok(line) = serde_json::to_string(result) {
                let _ = writeln!(file, "{line}");
            }
        }
    }
}

fn sanitize_session_id(value: &str) -> String {
    let sanitized: String = value
        .chars()
        .map(|character| match character {
            'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' => character,
            _ => '_',
        })
        .collect();
    if sanitized.is_empty() {
        "free_v1".to_string()
    } else {
        sanitized
    }
}
