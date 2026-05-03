use agent_core::tools::registry::ToolHandler;
use agent_core::tools::todo::TodoHandler;
use serde_json::{json, Value};
use std::sync::{Mutex, MutexGuard, OnceLock};

fn lock_tests() -> MutexGuard<'static, ()> {
    static GATE: OnceLock<Mutex<()>> = OnceLock::new();
    GATE.get_or_init(|| Mutex::new(()))
        .lock()
        .unwrap_or_else(|poison| poison.into_inner())
}

async fn reset_store(handler: &TodoHandler) {
    handler
        .execute(&json!({ "action": "clear" }))
        .await
        .unwrap();
}

#[tokio::test]
async fn hermes_todo_add_done_clear_actions_share_native_store() {
    let _gate = lock_tests();
    let handler = TodoHandler;
    reset_store(&handler).await;

    let added = handler
        .execute(&json!({
            "action": "add",
            "id": "hermes-task",
            "content": "Map Hermes slash command",
        }))
        .await
        .unwrap();
    let added: Value = serde_json::from_str(&added).unwrap();
    assert_eq!(added["summary"]["pending"], json!(1));

    let completed = handler
        .execute(&json!({
            "action": "done",
            "id": "hermes-task",
        }))
        .await
        .unwrap();
    let completed: Value = serde_json::from_str(&completed).unwrap();
    assert_eq!(completed["summary"]["completed"], json!(1));

    let cleared = handler
        .execute(&json!({ "action": "clear" }))
        .await
        .unwrap();
    let cleared: Value = serde_json::from_str(&cleared).unwrap();
    assert_eq!(cleared["summary"]["total"], json!(0));
}
