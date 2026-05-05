use agent_core::hermes::function_call::{parse_tool_calls, StreamingToolCallDetector};
use agent_core::hermes::procedural_memory::{ProceduralMemoryStore, ProcedureOutcomeRecord};
use agent_core::hermes::prompt_format::{
    build_messages, build_system_prompt, HermesMessage, HermesMessageRole, HermesPromptInput,
    HermesToolDefinition, HermesToolResult,
};
use agent_core::hermes::self_evolution::propose_repeated_success_skill;
use agent_core::hermes::skills::{
    default_skills_dir, skill_manage_schema, skill_view_schema, skills_list_schema,
    skills_tool_schema, SkillManageHandler, SkillViewHandler, SkillsListHandler,
    SkillsRegistryStore, SkillsTool,
};
use serde_json::{json, Value};
use std::path::Path;
use tempfile::tempdir;

#[test]
fn prompt_format_preserves_hermes_function_call_contract() {
    let input = HermesPromptInput {
        tools: vec![HermesToolDefinition {
            name: "read_file".to_string(),
            description: "Read an exact path.".to_string(),
            parameters: json!({
                "type": "object",
                "required": ["path"],
                "properties": {
                    "path": { "type": "string" }
                }
            }),
        }],
        additional_instructions: Some("Prefer exact paths.".to_string()),
        knowledge_index: Some("KNOWLEDGE-FIRST".to_string()),
    };

    let prompt = build_system_prompt(&input);

    assert!(prompt.starts_with("KNOWLEDGE-FIRST\nYou are a function calling AI model."));
    let tools_json = prompt
        .split("<tools>\n")
        .nth(1)
        .and_then(|rest| rest.split("\n</tools>").next())
        .expect("prompt must include tools block");
    let tools: Value = serde_json::from_str(tools_json).expect("tools block must be JSON");
    assert_eq!(
        tools,
        json!([{
            "type": "function",
            "function": {
                "description": "Read an exact path.",
                "name": "read_file",
                "parameters": {
                    "type": "object",
                    "required": ["path"],
                    "properties": {
                        "path": { "type": "string" }
                    }
                }
            }
        }])
    );
    assert!(prompt.contains(
        "<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-dict>}\n</tool_call>"
    ));
    assert!(prompt
        .contains("Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."));
    assert!(prompt.contains("Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context."));
    assert!(prompt.ends_with("Prefer exact paths."));
}

#[test]
fn prompt_format_marks_empty_tool_turns_without_tool_calls() {
    let prompt = build_system_prompt(&HermesPromptInput {
        tools: Vec::new(),
        additional_instructions: None,
        knowledge_index: None,
    });

    assert!(prompt.contains(
        "No tools are available for this turn. Respond directly without emitting <tool_call> tags."
    ));
}

#[test]
fn prompt_messages_wrap_tool_results_after_history() {
    let messages = build_messages(
        "system",
        &[HermesMessage {
            role: HermesMessageRole::User,
            content: "Read it.".to_string(),
        }],
        &[HermesToolResult {
            tool_name: "read_file".to_string(),
            result_json: "{\"ok\":true}".to_string(),
            is_error: false,
        }],
    );

    assert_eq!(messages.len(), 3);
    assert_eq!(messages[0].role, HermesMessageRole::System);
    assert_eq!(messages[1].role, HermesMessageRole::User);
    assert_eq!(messages[2].role, HermesMessageRole::Tool);
    assert_eq!(
        messages[2].content,
        "<tool_response>\n{\"ok\":true}\n</tool_response>"
    );
}

#[test]
fn function_call_detector_emits_when_closing_tag_arrives() {
    let mut detector = StreamingToolCallDetector::new();

    assert!(detector.feed("<think>private</think>Hello ").is_none());
    let detection = detector
        .feed("<tool_call>{\"name\":\"read_file\",\"arguments\":{\"path\":\"docs/a.md\"}}</tool_call>")
        .expect("complete tool call should emit on closing tag");

    assert_eq!(detector.pending_text(), "Hello ");
    assert_eq!(detection.call.name, "read_file");
    assert_eq!(detection.call.arguments_json, "{\"path\":\"docs/a.md\"}");
    assert_eq!(
        detection.raw_content,
        "{\"name\":\"read_file\",\"arguments\":{\"path\":\"docs/a.md\"}}"
    );
}

#[test]
fn function_call_parser_accepts_parameters_alias() {
    let calls = parse_tool_calls(r#"{"name":"search_web","parameters":{"query":"hello"}}"#);

    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].name, "search_web");
    assert_eq!(calls[0].arguments_json, "{\"query\":\"hello\"}");
}

#[test]
fn function_call_detector_flushes_plaintext_prefix_at_stream_end() {
    let mut detector = StreamingToolCallDetector::new();

    assert!(detector.feed("Use x <").is_none());

    assert_eq!(detector.flush_on_stream_end(), "<");
    assert_eq!(detector.pending_text(), "Use x <");
}

#[test]
fn function_call_detector_drops_unclosed_hidden_reasoning() {
    let mut detector = StreamingToolCallDetector::new();

    assert!(detector.feed("<scratch_pad>secret plan").is_none());

    assert_eq!(detector.flush_on_stream_end(), "");
    assert_eq!(detector.pending_text(), "");
}

#[test]
fn bridge_exposes_hermes_prompt_and_tool_parse_entrypoints() {
    let prompt = agent_core::bridge::hermes_build_system_prompt(
        json!({
            "tools": [],
            "additional_instructions": "Answer directly.",
            "knowledge_index": null
        })
        .to_string(),
    )
    .expect("prompt bridge should decode canonical JSON input");

    assert!(prompt.contains("No tools are available for this turn."));
    assert!(prompt.ends_with("Answer directly."));

    let calls_json = agent_core::bridge::hermes_parse_tool_calls(
        "<tool_call>{\"name\":\"vault_read\",\"arguments\":{\"path\":\"A.md\"}}</tool_call>"
            .to_string(),
    )
    .expect("parser bridge should return JSON call list");
    let calls: serde_json::Value = serde_json::from_str(&calls_json).unwrap();

    assert_eq!(calls[0]["name"], "vault_read");
    assert_eq!(calls[0]["arguments_json"], "{\"path\":\"A.md\"}");
}

#[test]
fn bridge_exposes_hermes_skill_listing_and_procedure_memory() {
    let dir = tempdir().unwrap();
    let skills_dir = dir.path().join("skills").join("demo");
    std::fs::create_dir_all(&skills_dir).unwrap();
    std::fs::write(
        skills_dir.join("SKILL.md"),
        "---\nname: demo\ndescription: Demo skill\ntriggers: [demo]\n---\n# Demo\n",
    )
    .unwrap();

    let skills = agent_core::bridge::list_skills(dir.path().display().to_string())
        .expect("list_skills should read the profile skills directory");
    assert_eq!(skills.len(), 1);
    assert_eq!(skills[0].name, "demo");
    assert_eq!(skills[0].description, "Demo skill");

    let db = dir.path().join("procedures.sqlite");
    unsafe {
        std::env::set_var("EPISTEMOS_PROCEDURAL_MEMORY_DB", db.display().to_string());
    }
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    agent_core::bridge::write_procedure(agent_core::bridge::ProcedureFFI {
        skill_name: "demo".to_string(),
        invocation_context_hash: "ctx-a".to_string(),
        steps_taken: vec!["skills_list".to_string()],
        outcome_summary: "listed skills".to_string(),
        duration_ms: 8,
        error_mode: None,
        succeeded: true,
        occurred_at_unix_seconds: now,
        score: 0.0,
    })
    .expect("write_procedure should persist an outcome");

    let recalled = agent_core::bridge::recall_procedure("demo".to_string(), "ctx-a".to_string())
        .expect("recall_procedure should query procedural memory")
        .expect("matching procedure should be returned");
    unsafe {
        std::env::remove_var("EPISTEMOS_PROCEDURAL_MEMORY_DB");
    }

    assert_eq!(recalled.skill_name, "demo");
    assert_eq!(recalled.steps_taken, ["skills_list"]);
    assert!(recalled.score > 0.99);
}

#[tokio::test]
async fn bridge_invoke_skill_executes_path_bound_skill_steps() {
    let dir = tempdir().unwrap();
    let skills_dir = dir.path().join("skills").join("demo");
    std::fs::create_dir_all(&skills_dir).unwrap();
    std::fs::write(
        skills_dir.join("SKILL.md"),
        "---\nname: demo\ndescription: Demo skill\ntriggers: [demo]\nmetadata:\n  epistemos:\n    steps:\n      - tool: skill_view\n        arguments:\n          name: demo\n---\n# Demo\nUse this body as the executable skill instruction.\n",
    )
    .unwrap();

    let result = agent_core::bridge::invoke_skill(
        dir.path().display().to_string(),
        "demo".to_string(),
        "{\"request\":\"show demo\"}".to_string(),
    )
    .await
    .expect("invoke_skill should execute declared Hermes skill steps");

    assert!(result.succeeded, "invoke_skill error: {:?}", result.error);
    assert_eq!(result.skill_name, "demo");
    assert_eq!(result.steps_taken, ["skill_view"]);

    let output: serde_json::Value = serde_json::from_str(&result.output_json).unwrap();
    assert_eq!(output["skill_name"], "demo");
    assert_eq!(output["arguments"]["request"], "show demo");
    assert!(output["step_results"][0]["output"]["content"]
        .as_str()
        .unwrap()
        .contains("Use this body as the executable skill instruction."));
}

#[test]
fn hermes_skills_facade_owns_router_registry_and_tool_facade() {
    let router = agent_core::hermes::skills::SkillRouter::load(Path::new("/nonexistent"));
    assert_eq!(router.skill_count(), 0);

    let registry = SkillsRegistryStore::load(Path::new("/nonexistent"));
    assert!(registry.is_empty());

    let legacy_schema = skills_tool_schema();
    let list_schema = skills_list_schema();
    let view_schema = skill_view_schema();
    let manage_schema = skill_manage_schema();

    assert_eq!(legacy_schema.name, "skills");
    assert_eq!(list_schema.name, "skills_list");
    assert_eq!(view_schema.name, "skill_view");
    assert_eq!(manage_schema.name, "skill_manage");

    let skills_dir = default_skills_dir();
    let _legacy = SkillsTool::new(skills_dir);
    let _list = SkillsListHandler::new();
    let _view = SkillViewHandler::new();
    let _manage = SkillManageHandler::new();
}

#[test]
fn runtime_skill_call_sites_route_through_hermes_skills() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let bridge = std::fs::read_to_string(manifest_dir.join("src/bridge.rs")).unwrap();
    let registry = std::fs::read_to_string(manifest_dir.join("src/tools/registry.rs")).unwrap();
    let dispatcher = std::fs::read_to_string(manifest_dir.join("src/dispatcher.rs")).unwrap();
    let context_loader =
        std::fs::read_to_string(manifest_dir.join("src/context_loader.rs")).unwrap();

    for source in [&bridge, &registry, &dispatcher, &context_loader] {
        assert!(
            source.contains("crate::hermes::skills"),
            "B.1 runtime skill call sites must route through agent_core::hermes::skills"
        );
    }

    assert!(!bridge.contains("crate::skill_router::SkillRouter"));
    assert!(!bridge.contains("crate::storage::skills_registry"));
    assert!(!registry.contains("crate::tools::skills"));
    assert!(!dispatcher.contains("use crate::skill_router::SkillRouter;"));
    assert!(!dispatcher.contains("use crate::storage::skills_registry::SkillRegistryEntry;"));
    assert!(!context_loader.contains("use crate::skill_router::SkillRouter;"));
}

#[test]
fn procedural_memory_records_and_recalls_skill_outcomes() {
    let dir = tempdir().unwrap();
    let store = ProceduralMemoryStore::open(dir.path().join("procedures.sqlite")).unwrap();

    store
        .record_outcome(&ProcedureOutcomeRecord {
            skill_name: "vault-summarize".to_string(),
            invocation_context_hash: "note:alpha topic:rust".to_string(),
            steps_taken: vec!["vault_read".to_string(), "summarize".to_string()],
            outcome_summary: "Produced a focused Rust summary.".to_string(),
            duration_ms: 42,
            error_mode: None,
            succeeded: true,
            occurred_at_unix_seconds: 1_776_000_000,
        })
        .unwrap();

    let recalled = store
        .recall("vault-summarize", "note:alpha topic:rust", 3, 1_776_000_100)
        .unwrap();

    assert_eq!(recalled.len(), 1);
    assert_eq!(recalled[0].record.skill_name, "vault-summarize");
    assert_eq!(recalled[0].record.steps_taken, ["vault_read", "summarize"]);
    assert!(recalled[0].score > 0.99);
}

#[test]
fn procedural_memory_ranks_context_match_and_decay() {
    let dir = tempdir().unwrap();
    let store = ProceduralMemoryStore::open(dir.path().join("procedures.sqlite")).unwrap();

    store
        .record_outcome(&ProcedureOutcomeRecord {
            skill_name: "research".to_string(),
            invocation_context_hash: "paper transformer citation".to_string(),
            steps_taken: vec!["web_fetch".to_string()],
            outcome_summary: "Old exact match.".to_string(),
            duration_ms: 10,
            error_mode: None,
            succeeded: true,
            occurred_at_unix_seconds: 1_700_000_000,
        })
        .unwrap();
    store
        .record_outcome(&ProcedureOutcomeRecord {
            skill_name: "research".to_string(),
            invocation_context_hash: "paper transformer citation".to_string(),
            steps_taken: vec!["memory".to_string(), "web_fetch".to_string()],
            outcome_summary: "Recent exact match.".to_string(),
            duration_ms: 12,
            error_mode: None,
            succeeded: true,
            occurred_at_unix_seconds: 1_776_000_000,
        })
        .unwrap();

    let recalled = store
        .recall("research", "paper transformer citation", 2, 1_776_000_100)
        .unwrap();

    assert_eq!(recalled.len(), 2);
    assert_eq!(recalled[0].record.outcome_summary, "Recent exact match.");
    assert!(recalled[0].score > recalled[1].score);
}

#[test]
fn self_evolution_proposes_skill_from_repeated_successful_sequence() {
    let records = vec![
        procedure_record("research", ["vault_read", "web_fetch"], true, 10),
        procedure_record("research", ["vault_read", "web_fetch"], true, 20),
        procedure_record("research", ["vault_read", "web_fetch"], true, 30),
    ];

    let candidate = propose_repeated_success_skill(&records, 3)
        .expect("three successful repeated sequences should propose a skill");

    assert_eq!(candidate.proposal.name, "learned-vault-read-web-fetch");
    assert_eq!(candidate.steps_taken, ["vault_read", "web_fetch"]);
    assert_eq!(candidate.repetitions, 3);
    assert!(candidate
        .proposal
        .rationale
        .contains("3 successful repetitions"));
}

#[test]
fn self_evolution_ignores_failed_or_under_repeated_sequences() {
    let records = vec![
        procedure_record("research", ["vault_read", "web_fetch"], true, 10),
        procedure_record("research", ["vault_read", "web_fetch"], false, 20),
        procedure_record("research", ["memory", "web_fetch"], true, 30),
    ];

    assert!(propose_repeated_success_skill(&records, 2).is_none());
}

fn procedure_record<const N: usize>(
    skill_name: &str,
    steps: [&str; N],
    succeeded: bool,
    occurred_at_unix_seconds: i64,
) -> ProcedureOutcomeRecord {
    ProcedureOutcomeRecord {
        skill_name: skill_name.to_string(),
        invocation_context_hash: format!("{skill_name}:{occurred_at_unix_seconds}"),
        steps_taken: steps.into_iter().map(str::to_string).collect(),
        outcome_summary: "ok".to_string(),
        duration_ms: 1,
        error_mode: None,
        succeeded,
        occurred_at_unix_seconds,
    }
}
