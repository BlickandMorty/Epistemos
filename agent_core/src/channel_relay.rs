use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use axum::extract::{Path as AxumPath, Query, State};
use axum::http::{header, HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use chrono::Utc;
use rusqlite::{Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;

pub const DEFAULT_LISTEN_ADDR: &str = "127.0.0.1:8787";

#[derive(Clone)]
pub struct ChannelRelayStore {
    db_path: PathBuf,
    gate: Arc<Mutex<()>>,
}

impl ChannelRelayStore {
    pub fn new(db_path: PathBuf) -> Self {
        Self {
            db_path,
            gate: Arc::new(Mutex::new(())),
        }
    }

    pub fn from_env() -> Self {
        Self::new(default_db_path())
    }

    pub fn health(&self) -> Result<Value, String> {
        self.with_connection(|conn| {
            let thread_count: i64 = conn
                .query_row("SELECT COUNT(*) FROM channel_threads", [], |row| row.get(0))
                .map_err(|e| format!("count threads: {e}"))?;
            let message_count: i64 = conn
                .query_row("SELECT COUNT(*) FROM channel_messages", [], |row| {
                    row.get(0)
                })
                .map_err(|e| format!("count messages: {e}"))?;
            let outbox_count: i64 = conn
                .query_row(
                    "SELECT COUNT(*) FROM channel_outbox WHERE status = 'pending'",
                    [],
                    |row| row.get(0),
                )
                .map_err(|e| format!("count outbox: {e}"))?;
            Ok(json!({
                "ok": true,
                "db_path": self.db_path.display().to_string(),
                "threads": thread_count,
                "messages": message_count,
                "pending_outbox": outbox_count,
            }))
        })
    }

    pub fn ingest_inbound(
        &self,
        channel_id: &str,
        request: RelayInboundRequest,
    ) -> Result<Value, String> {
        self.with_connection(|conn| {
            let now = Utc::now().to_rfc3339();
            let unix = request.unix.unwrap_or_else(|| Utc::now().timestamp());
            let conversation_id = resolved_conversation_id(
                request.conversation_id.as_deref(),
                Some(request.sender_id.as_str()),
            );
            upsert_thread(
                conn,
                channel_id,
                &conversation_id,
                request
                    .title
                    .as_deref()
                    .unwrap_or_else(|| request.sender_display.as_deref().unwrap_or(request.sender_id.as_str())),
                request.subtitle.as_deref().unwrap_or(request.sender_id.as_str()),
                unix,
                request.archived.unwrap_or(false),
                &now,
            )?;

            if let Some(message_id) = request.message_id.as_deref() {
                let existing_id: Option<String> = conn
                    .query_row(
                        "SELECT id FROM channel_messages WHERE channel_id = ?1 AND message_id = ?2",
                        rusqlite::params![channel_id, message_id],
                        |row| row.get(0),
                    )
                    .optional()
                    .map_err(|e| format!("lookup inbound dedup: {e}"))?;
                if let Some(existing_id) = existing_id {
                    return Ok(json!({
                        "success": true,
                        "deduped": true,
                        "id": existing_id,
                        "conversation_id": conversation_id,
                    }));
                }
            }

            let id = Uuid::new_v4().to_string();
            let raw_json = request.raw_json.map(|value| value.to_string());
            conn.execute(
                "INSERT INTO channel_messages
                    (id, channel_id, conversation_id, message_id, sender_id, sender_display, recipient_id,
                     text, unix, from_me, unread, created_at, raw_json)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, NULL, ?7, ?8, 0, 1, ?9, ?10)",
                rusqlite::params![
                    id,
                    channel_id,
                    conversation_id,
                    request.message_id,
                    request.sender_id,
                    request.sender_display,
                    request.text,
                    unix,
                    now,
                    raw_json,
                ],
            )
            .map_err(|e| format!("insert inbound message: {e}"))?;

            Ok(json!({
                "success": true,
                "deduped": false,
                "id": id,
                "conversation_id": conversation_id,
                "unix": unix,
            }))
        })
    }

    pub fn fetch_unread(&self, channel_id: &str, limit: usize) -> Result<Value, String> {
        self.with_connection(|conn| {
            let now = Utc::now().to_rfc3339();
            let mut stmt = conn
                .prepare(
                    "SELECT id, conversation_id, message_id, sender_id, text, unix
                     FROM channel_messages
                     WHERE channel_id = ?1 AND from_me = 0 AND unread = 1
                     ORDER BY unix ASC
                     LIMIT ?2",
                )
                .map_err(|e| format!("prepare unread: {e}"))?;
            let rows = stmt
                .query_map(rusqlite::params![channel_id, limit as i64], |row| {
                    Ok(RelayMessage {
                        id: row.get("id")?,
                        conversation_id: row.get("conversation_id")?,
                        message_id: row.get("message_id")?,
                        sender_id: row.get("sender_id")?,
                        preview: row.get("text")?,
                        unix: row.get("unix")?,
                        is_from_me: false,
                    })
                })
                .map_err(|e| format!("query unread: {e}"))?;
            let mut messages = Vec::new();
            let mut ids = Vec::new();
            for row in rows {
                let message = row.map_err(|e| format!("read unread row: {e}"))?;
                ids.push(message.id.clone());
                messages.push(message);
            }
            for id in ids {
                conn.execute(
                    "UPDATE channel_messages SET unread = 0, read_at = ?1 WHERE id = ?2",
                    rusqlite::params![now, id],
                )
                .map_err(|e| format!("mark unread consumed: {e}"))?;
            }

            Ok(json!({
                "messages": messages.iter().map(RelayMessage::to_inbound_json).collect::<Vec<_>>(),
                "count": messages.len(),
            }))
        })
    }

    pub fn list_threads(&self, channel_id: &str, limit: usize) -> Result<Value, String> {
        self.with_connection(|conn| {
            let mut stmt = conn
                .prepare(
                    "SELECT conversation_id, title, subtitle, last_activity_unix, archived
                     FROM channel_threads
                     WHERE channel_id = ?1
                     ORDER BY last_activity_unix DESC
                     LIMIT ?2",
                )
                .map_err(|e| format!("prepare threads: {e}"))?;
            let rows = stmt
                .query_map(rusqlite::params![channel_id, limit as i64], |row| {
                    Ok(json!({
                        "conversation_id": row.get::<_, String>("conversation_id")?,
                        "title": row.get::<_, String>("title")?,
                        "subtitle": row.get::<_, String>("subtitle")?,
                        "last_activity_unix": row.get::<_, i64>("last_activity_unix")?,
                        "archived": row.get::<_, i64>("archived")? != 0,
                    }))
                })
                .map_err(|e| format!("query threads: {e}"))?;
            let mut threads = Vec::new();
            for row in rows {
                threads.push(row.map_err(|e| format!("read thread row: {e}"))?);
            }
            Ok(json!({ "threads": threads, "count": threads.len() }))
        })
    }

    pub fn recent_audit(&self, channel_id: &str, limit: usize) -> Result<Value, String> {
        self.with_connection(|conn| {
            let mut stmt = conn
                .prepare(
                    "SELECT id, conversation_id, message_id, sender_id, text, unix, from_me
                     FROM channel_messages
                     WHERE channel_id = ?1
                     ORDER BY unix DESC, created_at DESC
                     LIMIT ?2",
                )
                .map_err(|e| format!("prepare audit: {e}"))?;
            let rows = stmt
                .query_map(rusqlite::params![channel_id, limit as i64], |row| {
                    Ok(RelayMessage {
                        id: row.get("id")?,
                        conversation_id: row.get("conversation_id")?,
                        message_id: row.get("message_id")?,
                        sender_id: row.get("sender_id")?,
                        preview: row.get("text")?,
                        unix: row.get("unix")?,
                        is_from_me: row.get::<_, i64>("from_me")? != 0,
                    })
                })
                .map_err(|e| format!("query audit: {e}"))?;
            let mut messages = Vec::new();
            for row in rows {
                messages.push(row.map_err(|e| format!("read audit row: {e}"))?);
            }
            Ok(json!({
                "messages": messages.iter().map(RelayMessage::to_audit_json).collect::<Vec<_>>(),
                "count": messages.len(),
            }))
        })
    }

    pub fn enqueue_outbound(
        &self,
        channel_id: &str,
        request: RelayOutboundRequest,
    ) -> Result<Value, String> {
        self.with_connection(|conn| {
            let id = Uuid::new_v4().to_string();
            let now = Utc::now().to_rfc3339();
            let conversation_id = request
                .conversation_id
                .clone()
                .or_else(|| request.recipient_id.clone());
            let metadata_json = request.metadata.map(|value| value.to_string());
            conn.execute(
                "INSERT INTO channel_outbox
                    (id, channel_id, conversation_id, recipient_id, message, sender_identity, metadata_json, created_at, status)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 'pending')",
                rusqlite::params![
                    id,
                    channel_id,
                    conversation_id,
                    request.recipient_id,
                    request.message,
                    request.sender_identity,
                    metadata_json,
                    now,
                ],
            )
            .map_err(|e| format!("insert outbox: {e}"))?;
            Ok(json!({
                "success": true,
                "queued": true,
                "id": id,
            }))
        })
    }

    pub fn list_outbox(&self, channel_id: &str, limit: usize) -> Result<Value, String> {
        self.with_connection(|conn| {
            let mut stmt = conn
                .prepare(
                    "SELECT id, conversation_id, recipient_id, message, sender_identity, metadata_json, created_at
                     FROM channel_outbox
                     WHERE channel_id = ?1 AND status = 'pending'
                     ORDER BY created_at ASC
                     LIMIT ?2",
                )
                .map_err(|e| format!("prepare outbox: {e}"))?;
            let rows = stmt
                .query_map(rusqlite::params![channel_id, limit as i64], |row| {
                    Ok(json!({
                        "id": row.get::<_, String>("id")?,
                        "conversation_id": row.get::<_, Option<String>>("conversation_id")?,
                        "recipient_id": row.get::<_, Option<String>>("recipient_id")?,
                        "message": row.get::<_, String>("message")?,
                        "sender_identity": row.get::<_, Option<String>>("sender_identity")?,
                        "metadata": parse_json_column(row.get::<_, Option<String>>("metadata_json")?),
                        "created_at": row.get::<_, String>("created_at")?,
                    }))
                })
                .map_err(|e| format!("query outbox: {e}"))?;
            let mut messages = Vec::new();
            for row in rows {
                messages.push(row.map_err(|e| format!("read outbox row: {e}"))?);
            }
            Ok(json!({ "messages": messages, "count": messages.len() }))
        })
    }

    pub fn ack_outbox(
        &self,
        channel_id: &str,
        outbox_id: &str,
        request: RelayOutboxAckRequest,
    ) -> Result<Value, String> {
        self.with_connection(|conn| {
            let row: Option<(Option<String>, Option<String>, String, Option<String>, Option<String>)> = conn
                .query_row(
                    "SELECT conversation_id, recipient_id, message, sender_identity, metadata_json
                     FROM channel_outbox
                     WHERE channel_id = ?1 AND id = ?2",
                    rusqlite::params![channel_id, outbox_id],
                    |row| {
                        Ok((
                            row.get("conversation_id")?,
                            row.get("recipient_id")?,
                            row.get("message")?,
                            row.get("sender_identity")?,
                            row.get("metadata_json")?,
                        ))
                    },
                )
                .optional()
                .map_err(|e| format!("load outbox item: {e}"))?;
            let Some((stored_conversation_id, stored_recipient_id, stored_message, sender_identity, metadata_json)) = row else {
                return Err(format!("outbox item '{outbox_id}' not found"));
            };
            let metadata = parse_json_column(metadata_json);

            let now = Utc::now().to_rfc3339();
            if request.success {
                conn.execute(
                    "UPDATE channel_outbox
                     SET status = 'delivered',
                         delivered_message_id = ?1,
                         error = NULL,
                         processed_at = ?2
                     WHERE channel_id = ?3 AND id = ?4",
                    rusqlite::params![request.message_id, now, channel_id, outbox_id],
                )
                .map_err(|e| format!("mark outbox delivered: {e}"))?;

                let unix = request.unix.unwrap_or_else(|| Utc::now().timestamp());
                let conversation_id = resolved_conversation_id(
                    request
                        .conversation_id
                        .as_deref()
                        .or(stored_conversation_id.as_deref()),
                    stored_recipient_id.as_deref(),
                );
                let sender_id = request
                    .sender_id
                    .clone()
                    .or(sender_identity.clone())
                    .unwrap_or_else(|| "epistemos".to_string());
                let default_title = default_thread_title(
                    channel_id,
                    stored_recipient_id.as_deref(),
                    stored_conversation_id.as_deref(),
                    Some(&metadata),
                );
                let default_subtitle =
                    default_thread_subtitle(stored_recipient_id.as_deref(), &default_title);
                let title = request
                    .title
                    .clone()
                    .unwrap_or(default_title);
                let subtitle = request
                    .subtitle
                    .clone()
                    .unwrap_or(default_subtitle);
                upsert_thread(
                    conn,
                    channel_id,
                    &conversation_id,
                    &title,
                    &subtitle,
                    unix,
                    request.archived.unwrap_or(false),
                    &now,
                )?;
                let audit_id = Uuid::new_v4().to_string();
                let text = request.text.unwrap_or(stored_message);
                conn.execute(
                    "INSERT INTO channel_messages
                        (id, channel_id, conversation_id, message_id, sender_id, sender_display, recipient_id,
                         text, unix, from_me, unread, created_at, raw_json)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 1, 0, ?10, NULL)",
                    rusqlite::params![
                        audit_id,
                        channel_id,
                        conversation_id,
                        request.message_id,
                        sender_id,
                        request.sender_display,
                        stored_recipient_id,
                        text,
                        unix,
                        now,
                    ],
                )
                .map_err(|e| format!("insert outbound audit: {e}"))?;
            } else {
                conn.execute(
                    "UPDATE channel_outbox
                     SET status = 'failed',
                         error = ?1,
                         processed_at = ?2
                     WHERE channel_id = ?3 AND id = ?4",
                    rusqlite::params![
                        request.error.unwrap_or_else(|| "unknown relay delivery failure".to_string()),
                        now,
                        channel_id,
                        outbox_id,
                    ],
                )
                .map_err(|e| format!("mark outbox failed: {e}"))?;
            }

            Ok(json!({
                "success": true,
                "id": outbox_id,
                "status": if request.success { "delivered" } else { "failed" },
            }))
        })
    }

    fn with_connection<T>(
        &self,
        f: impl FnOnce(&Connection) -> Result<T, String>,
    ) -> Result<T, String> {
        let _guard = self
            .gate
            .lock()
            .map_err(|e| format!("relay db lock: {e}"))?;
        let conn = Connection::open(&self.db_path)
            .map_err(|e| format!("open relay db '{}': {e}", self.db_path.display()))?;
        init_schema(&conn).map_err(|e| format!("init relay schema: {e}"))?;
        f(&conn)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RelayInboundRequest {
    pub conversation_id: Option<String>,
    pub sender_id: String,
    pub sender_display: Option<String>,
    pub text: String,
    pub unix: Option<i64>,
    pub message_id: Option<String>,
    pub title: Option<String>,
    pub subtitle: Option<String>,
    pub archived: Option<bool>,
    pub raw_json: Option<Value>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RelayOutboundRequest {
    pub recipient_id: Option<String>,
    pub conversation_id: Option<String>,
    pub message: String,
    pub sender_identity: Option<String>,
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RelayOutboxAckRequest {
    pub success: bool,
    pub message_id: Option<String>,
    pub conversation_id: Option<String>,
    pub sender_id: Option<String>,
    pub sender_display: Option<String>,
    pub unix: Option<i64>,
    pub text: Option<String>,
    pub title: Option<String>,
    pub subtitle: Option<String>,
    pub archived: Option<bool>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct LimitQuery {
    limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
struct RelayMessage {
    id: String,
    conversation_id: String,
    message_id: Option<String>,
    sender_id: String,
    preview: String,
    unix: i64,
    is_from_me: bool,
}

impl RelayMessage {
    fn to_inbound_json(&self) -> Value {
        json!({
            "message_id": self.message_id,
            "conversation_id": self.conversation_id,
            "sender_id": self.sender_id,
            "text": self.preview,
            "unix": self.unix,
            "from_me": self.is_from_me,
        })
    }

    fn to_audit_json(&self) -> Value {
        self.to_inbound_json()
    }
}

#[derive(Clone)]
pub struct ChannelRelayAppState {
    pub store: ChannelRelayStore,
    pub bearer_token: Option<String>,
}

pub fn app_router(state: ChannelRelayAppState) -> Router {
    Router::new()
        .route("/healthz", get(get_health))
        .route("/v1/channels/:channel_id/inbound", post(post_inbound))
        .route("/v1/channels/:channel_id/messages/unread", get(get_unread))
        .route("/v1/channels/:channel_id/threads", get(get_threads))
        .route("/v1/channels/:channel_id/audit", get(get_audit))
        .route("/v1/channels/:channel_id/messages", post(post_messages))
        .route("/v1/channels/:channel_id/outbox", get(get_outbox))
        .route(
            "/v1/channels/:channel_id/outbox/:outbox_id/ack",
            post(post_outbox_ack),
        )
        .with_state(state)
}

pub async fn serve(listener: SocketAddr, state: ChannelRelayAppState) -> Result<(), String> {
    let tcp_listener = tokio::net::TcpListener::bind(listener)
        .await
        .map_err(|e| format!("bind relay listener: {e}"))?;
    axum::serve(tcp_listener, app_router(state))
        .await
        .map_err(|e| format!("serve relay: {e}"))
}

async fn get_health(State(state): State<ChannelRelayAppState>) -> Response {
    match state.store.health() {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::INTERNAL_SERVER_ERROR, error),
    }
}

async fn post_inbound(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Json(request): Json<RelayInboundRequest>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state.store.ingest_inbound(&channel_id, request) {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn get_unread(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Query(query): Query<LimitQuery>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state
        .store
        .fetch_unread(&channel_id, query.limit.unwrap_or(20).clamp(1, 200))
    {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn get_threads(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Query(query): Query<LimitQuery>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state
        .store
        .list_threads(&channel_id, query.limit.unwrap_or(20).clamp(1, 200))
    {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn get_audit(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Query(query): Query<LimitQuery>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state
        .store
        .recent_audit(&channel_id, query.limit.unwrap_or(20).clamp(1, 200))
    {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn post_messages(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Json(request): Json<RelayOutboundRequest>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state.store.enqueue_outbound(&channel_id, request) {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn get_outbox(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath(channel_id): AxumPath<String>,
    Query(query): Query<LimitQuery>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state
        .store
        .list_outbox(&channel_id, query.limit.unwrap_or(20).clamp(1, 200))
    {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

async fn post_outbox_ack(
    headers: HeaderMap,
    State(state): State<ChannelRelayAppState>,
    AxumPath((channel_id, outbox_id)): AxumPath<(String, String)>,
    Json(request): Json<RelayOutboxAckRequest>,
) -> Response {
    if let Err(response) = authorize(&state, &headers) {
        return response;
    }
    match state.store.ack_outbox(&channel_id, &outbox_id, request) {
        Ok(payload) => Json(payload).into_response(),
        Err(error) => relay_error(StatusCode::BAD_REQUEST, error),
    }
}

fn authorize(state: &ChannelRelayAppState, headers: &HeaderMap) -> Result<(), Response> {
    let Some(expected_token) = state.bearer_token.as_deref() else {
        return Ok(());
    };
    let Some(header_value) = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
    else {
        return Err(relay_error(
            StatusCode::UNAUTHORIZED,
            "missing bearer token".to_string(),
        ));
    };
    let provided = header_value.strip_prefix("Bearer ").unwrap_or_default();
    if provided == expected_token {
        Ok(())
    } else {
        Err(relay_error(
            StatusCode::UNAUTHORIZED,
            "invalid bearer token".to_string(),
        ))
    }
}

fn relay_error(status: StatusCode, error: String) -> Response {
    (status, Json(json!({ "success": false, "error": error }))).into_response()
}

fn default_db_path() -> PathBuf {
    if let Ok(path) = std::env::var("EPISTEMOS_CHANNEL_RELAY_DB") {
        return PathBuf::from(path);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    let _ = std::fs::create_dir_all(&base);
    base.push("channel_relay.db");
    base
}

fn parse_json_column(value: Option<String>) -> Value {
    value
        .and_then(|payload| serde_json::from_str::<Value>(&payload).ok())
        .unwrap_or(Value::Null)
}

fn metadata_string(metadata: Option<&Value>, key: &str) -> Option<String> {
    metadata
        .and_then(|value| value.get(key))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn looks_like_webhook_target(value: &str) -> bool {
    let lowered = value.to_ascii_lowercase();
    lowered.starts_with("http://") || lowered.starts_with("https://")
}

fn default_thread_title(
    channel_id: &str,
    recipient_id: Option<&str>,
    conversation_id: Option<&str>,
    metadata: Option<&Value>,
) -> String {
    let display_target = metadata_string(metadata, "display_target");
    let subject = metadata_string(metadata, "subject");
    let trimmed_recipient = recipient_id
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);
    let trimmed_conversation = conversation_id
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);

    match channel_id {
        "email" => subject
            .or(display_target)
            .or(trimmed_recipient)
            .or(trimmed_conversation)
            .unwrap_or_else(|| "Email".to_string()),
        "slack" | "discord" => display_target
            .or(trimmed_conversation)
            .or(trimmed_recipient.filter(|value| !looks_like_webhook_target(value)))
            .unwrap_or_else(|| channel_id.to_string()),
        _ => display_target
            .or(trimmed_recipient)
            .or(trimmed_conversation)
            .unwrap_or_else(|| channel_id.to_string()),
    }
}

fn default_thread_subtitle(recipient_id: Option<&str>, title: &str) -> String {
    recipient_id
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .filter(|value| !looks_like_webhook_target(value))
        .filter(|value| *value != title)
        .map(ToOwned::to_owned)
        .unwrap_or_default()
}

fn ensure_column_exists(
    conn: &Connection,
    table: &str,
    column: &str,
    column_type: &str,
) -> rusqlite::Result<()> {
    let pragma = format!("PRAGMA table_info({table})");
    let mut stmt = conn.prepare(&pragma)?;
    let mut rows = stmt.query([])?;
    while let Some(row) = rows.next()? {
        let existing: String = row.get(1)?;
        if existing == column {
            return Ok(());
        }
    }

    let alter = format!("ALTER TABLE {table} ADD COLUMN {column} {column_type}");
    conn.execute(&alter, [])?;
    Ok(())
}

fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS channel_threads (
            channel_id          TEXT NOT NULL,
            conversation_id     TEXT NOT NULL,
            title               TEXT NOT NULL,
            subtitle            TEXT NOT NULL DEFAULT '',
            last_activity_unix  INTEGER NOT NULL,
            archived            INTEGER NOT NULL DEFAULT 0,
            updated_at          TEXT NOT NULL,
            PRIMARY KEY (channel_id, conversation_id)
        );
        CREATE TABLE IF NOT EXISTS channel_messages (
            id                  TEXT PRIMARY KEY,
            channel_id          TEXT NOT NULL,
            conversation_id     TEXT NOT NULL,
            message_id          TEXT,
            sender_id           TEXT NOT NULL,
            sender_display      TEXT,
            recipient_id        TEXT,
            text                TEXT NOT NULL,
            unix                INTEGER NOT NULL,
            from_me             INTEGER NOT NULL DEFAULT 0,
            unread              INTEGER NOT NULL DEFAULT 0,
            created_at          TEXT NOT NULL,
            read_at             TEXT,
            raw_json            TEXT
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_channel_messages_provider_id
            ON channel_messages(channel_id, message_id)
            WHERE message_id IS NOT NULL;
        CREATE INDEX IF NOT EXISTS idx_channel_messages_unread
            ON channel_messages(channel_id, unread, from_me, unix);
        CREATE INDEX IF NOT EXISTS idx_channel_messages_audit
            ON channel_messages(channel_id, unix DESC, created_at DESC);
        CREATE TABLE IF NOT EXISTS channel_outbox (
            id                  TEXT PRIMARY KEY,
            channel_id          TEXT NOT NULL,
            conversation_id     TEXT,
            recipient_id        TEXT,
            message             TEXT NOT NULL,
            sender_identity     TEXT,
            metadata_json       TEXT,
            created_at          TEXT NOT NULL,
            status              TEXT NOT NULL,
            delivered_message_id TEXT,
            error               TEXT,
            processed_at        TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_channel_outbox_pending
            ON channel_outbox(channel_id, status, created_at);",
    )?;
    ensure_column_exists(conn, "channel_outbox", "metadata_json", "TEXT")?;
    Ok(())
}

fn upsert_thread(
    conn: &Connection,
    channel_id: &str,
    conversation_id: &str,
    title: &str,
    subtitle: &str,
    unix: i64,
    archived: bool,
    updated_at: &str,
) -> Result<(), String> {
    conn.execute(
        "INSERT INTO channel_threads
            (channel_id, conversation_id, title, subtitle, last_activity_unix, archived, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
         ON CONFLICT(channel_id, conversation_id) DO UPDATE SET
            title = excluded.title,
            subtitle = excluded.subtitle,
            last_activity_unix = excluded.last_activity_unix,
            archived = excluded.archived,
            updated_at = excluded.updated_at",
        rusqlite::params![
            channel_id,
            conversation_id,
            title,
            subtitle,
            unix,
            archived as i64,
            updated_at,
        ],
    )
    .map_err(|e| format!("upsert thread: {e}"))?;
    Ok(())
}

fn resolved_conversation_id(conversation_id: Option<&str>, fallback: Option<&str>) -> String {
    conversation_id
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .or_else(|| fallback.map(ToOwned::to_owned))
        .unwrap_or_else(|| "unknown-thread".to_string())
}

pub fn parse_listen_addr(value: &str) -> Result<SocketAddr, String> {
    value
        .parse::<SocketAddr>()
        .map_err(|e| format!("invalid relay listen addr '{value}': {e}"))
}

pub fn load_bearer_token(cli_token: Option<String>) -> Option<String> {
    cli_token
        .or_else(|| std::env::var("EPISTEMOS_CHANNEL_RELAY_TOKEN").ok())
        .map(|token| token.trim().to_string())
        .filter(|token| !token.is_empty())
}

pub fn build_state(db_path: Option<PathBuf>, bearer_token: Option<String>) -> ChannelRelayAppState {
    ChannelRelayAppState {
        store: ChannelRelayStore::new(db_path.unwrap_or_else(default_db_path)),
        bearer_token: load_bearer_token(bearer_token),
    }
}

pub fn resolve_db_path(override_path: Option<&str>) -> PathBuf {
    override_path
        .map(PathBuf::from)
        .unwrap_or_else(default_db_path)
}

pub fn ensure_db_parent(path: &Path) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("create relay db parent '{}': {e}", parent.display()))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::{to_bytes, Body};
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt;

    fn temp_store() -> (tempfile::TempDir, ChannelRelayStore) {
        let dir = tempfile::TempDir::new().unwrap();
        let db_path = dir.path().join("relay.db");
        (dir, ChannelRelayStore::new(db_path))
    }

    #[test]
    fn relay_store_ingests_unread_threads_and_audit() {
        let (_dir, store) = temp_store();
        store
            .ingest_inbound(
                "telegram",
                RelayInboundRequest {
                    conversation_id: Some("thread-1".to_string()),
                    sender_id: "alice".to_string(),
                    sender_display: Some("Alice".to_string()),
                    text: "hello".to_string(),
                    unix: Some(1_712_708_800),
                    message_id: Some("msg-1".to_string()),
                    title: Some("Alice".to_string()),
                    subtitle: Some("@alice".to_string()),
                    archived: Some(false),
                    raw_json: None,
                },
            )
            .unwrap();

        let unread = store.fetch_unread("telegram", 10).unwrap();
        let unread_messages = unread["messages"].as_array().unwrap();
        assert_eq!(unread_messages.len(), 1);
        assert_eq!(unread_messages[0]["sender_id"], json!("alice"));

        let second_unread = store.fetch_unread("telegram", 10).unwrap();
        assert_eq!(second_unread["count"], json!(0));

        let threads = store.list_threads("telegram", 10).unwrap();
        assert_eq!(
            threads["threads"].as_array().unwrap()[0]["title"],
            json!("Alice")
        );

        let audit = store.recent_audit("telegram", 10).unwrap();
        assert_eq!(audit["count"], json!(1));
    }

    #[test]
    fn relay_store_outbox_ack_creates_outgoing_audit() {
        let (_dir, store) = temp_store();
        let queued = store
            .enqueue_outbound(
                "signal",
                RelayOutboundRequest {
                    recipient_id: Some("+15551234567".to_string()),
                    conversation_id: Some("thread-2".to_string()),
                    message: "status update".to_string(),
                    sender_identity: Some("Epistemos HQ".to_string()),
                    metadata: None,
                },
            )
            .unwrap();
        let outbox_id = queued["id"].as_str().unwrap().to_string();
        store
            .ack_outbox(
                "signal",
                &outbox_id,
                RelayOutboxAckRequest {
                    success: true,
                    message_id: Some("upstream-1".to_string()),
                    conversation_id: Some("thread-2".to_string()),
                    sender_id: None,
                    sender_display: Some("Epistemos HQ".to_string()),
                    unix: Some(1_712_708_900),
                    text: None,
                    title: Some("Operator".to_string()),
                    subtitle: Some("+15551234567".to_string()),
                    archived: Some(false),
                    error: None,
                },
            )
            .unwrap();

        let audit = store.recent_audit("signal", 10).unwrap();
        let messages = audit["messages"].as_array().unwrap();
        assert_eq!(messages.len(), 1);
        assert_eq!(messages[0]["from_me"], json!(true));
        assert_eq!(messages[0]["message_id"], json!("upstream-1"));
    }

    #[test]
    fn relay_store_ack_uses_metadata_for_safe_thread_labels() {
        let (_dir, store) = temp_store();
        let queued = store
            .enqueue_outbound(
                "slack",
                RelayOutboundRequest {
                    recipient_id: Some(
                        "https://hooks.slack.com/services/T000/B000/secret".to_string(),
                    ),
                    conversation_id: Some("ops-alerts".to_string()),
                    message: "status update".to_string(),
                    sender_identity: Some("Epistemos HQ".to_string()),
                    metadata: Some(json!({
                        "display_target": "Ops Alerts"
                    })),
                },
            )
            .unwrap();
        let outbox_id = queued["id"].as_str().unwrap().to_string();

        store
            .ack_outbox(
                "slack",
                &outbox_id,
                RelayOutboxAckRequest {
                    success: true,
                    message_id: None,
                    conversation_id: Some("ops-alerts".to_string()),
                    sender_id: None,
                    sender_display: Some("Epistemos HQ".to_string()),
                    unix: Some(1_712_708_905),
                    text: None,
                    title: None,
                    subtitle: None,
                    archived: Some(false),
                    error: None,
                },
            )
            .unwrap();

        let threads = store.list_threads("slack", 10).unwrap();
        let rows = threads["threads"].as_array().unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["title"], json!("Ops Alerts"));
        assert_eq!(rows[0]["subtitle"], json!(""));
    }

    #[test]
    fn relay_store_preserves_outbox_metadata_for_worker_delivery() {
        let (_dir, store) = temp_store();
        store
            .enqueue_outbound(
                "email",
                RelayOutboundRequest {
                    recipient_id: Some("ops@example.com".to_string()),
                    conversation_id: Some("thread-email".to_string()),
                    message: "status update".to_string(),
                    sender_identity: Some("Epistemos HQ".to_string()),
                    metadata: Some(json!({
                        "subject": "Operator Digest",
                        "display_target": "Ops Mailbox"
                    })),
                },
            )
            .unwrap();

        let outbox = store.list_outbox("email", 10).unwrap();
        let messages = outbox["messages"].as_array().unwrap();
        assert_eq!(messages.len(), 1);
        assert_eq!(messages[0]["recipient_id"], json!("ops@example.com"));
        assert_eq!(messages[0]["metadata"]["subject"], json!("Operator Digest"));
        assert_eq!(
            messages[0]["metadata"]["display_target"],
            json!("Ops Mailbox")
        );
    }

    #[tokio::test]
    async fn relay_router_requires_bearer_token_when_configured() {
        let (_dir, store) = temp_store();
        let app = app_router(ChannelRelayAppState {
            store,
            bearer_token: Some("secret".to_string()),
        });

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/channels/telegram/messages/unread")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn relay_router_round_trips_inbound_and_unread() {
        let (_dir, store) = temp_store();
        let app = app_router(ChannelRelayAppState {
            store,
            bearer_token: None,
        });

        let ingest_response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/v1/channels/telegram/inbound")
                    .header(header::CONTENT_TYPE, "application/json")
                    .body(Body::from(
                        json!({
                            "conversation_id": "thread-1",
                            "sender_id": "alice",
                            "sender_display": "Alice",
                            "text": "hello from webhook",
                            "message_id": "msg-1",
                            "unix": 1712708800
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(ingest_response.status(), StatusCode::OK);

        let unread_response = app
            .oneshot(
                Request::builder()
                    .uri("/v1/channels/telegram/messages/unread?limit=5")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(unread_response.status(), StatusCode::OK);
        let body = to_bytes(unread_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["count"], json!(1));
        assert_eq!(json["messages"][0]["sender_id"], json!("alice"));
    }
}
