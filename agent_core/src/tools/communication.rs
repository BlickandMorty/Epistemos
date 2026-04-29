//! Communication Tool — Phase 6 `send_message`
//!
//! Multi-platform messaging via a shared adapter fan-out. Platforms:
//!
//! * `slack`    — incoming webhook POST
//! * `telegram` — Bot API sendMessage
//! * `discord`  — incoming webhook POST
//! * `webhook`  — generic JSON POST to any URL
//! * `matrix`   — Matrix client-server API room send
//! * `whatsapp` — WhatsApp Business Cloud API
//! * `signal`   — signal-cli REST API v2/send
//! * `email`    — SMTP via `lettre`
//!
//! All platforms require an explicit `platform` argument so there's no
//! accidental misrouting. Credentials are read from environment variables
//! at call time so the agent can opt-in per session; callers may override
//! key endpoint / target fields via the explicit params in the schema.
//!
//! **Sending is destructive and irreversible.** The tool is tagged
//! `RiskLevel::Destructive` in `registry.rs` so the permission gate fires
//! unless the caller already pre-approved destructive actions.

use std::time::Duration;

use async_trait::async_trait;
use lettre::message::{header::ContentType, Message as EmailMessage};
use lettre::transport::smtp::authentication::Credentials;
use lettre::{AsyncSmtpTransport, AsyncTransport, Tokio1Executor};
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_MESSAGE_LEN: usize = 4_096;
/// Email bodies (text-only, no attachments) can be longer than chat messages —
/// bump the cap for the email platform only.
const MAX_EMAIL_LEN: usize = 32_768;

fn build_client() -> Result<Client, ToolError> {
    Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .user_agent("Epistemos/1.0 (Agent Messenger)")
        .build()
        .map_err(|e| ToolError::ExecutionFailed(format!("http client init: {e}")))
}

// MARK: - Handler

pub struct SendMessageHandler {
    client: Client,
}

impl SendMessageHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

/// Phase 2G-4 native `Tool` impl. Pattern documented in `todo.rs`.
/// `small_model_safe: false` — sending is irreversible and visible to
/// others. The legacy registry tags this Destructive for the same reason.
#[async_trait]
impl super::Tool for SendMessageHandler {
    fn name(&self) -> &'static str { "communication.send_message" }
    fn input_schema(&self) -> &'static Value {
        super::v2_catalog::communication_send_message::input_schema()
    }
    fn output_schema(&self) -> &'static Value {
        super::legacy_adapter::generic_text_or_object_output_schema()
    }
    fn variants(&self) -> &[super::VariantId] { &[super::VariantId::A] }
    fn profile(&self) -> super::Profile { super::Profile::AppStoreSafe }
    fn small_model_safe(&self) -> bool { false }
    async fn invoke(
        &self,
        _ctx: &super::ToolCtx,
        variant: super::VariantId,
        input: serde_json::Value,
    ) -> super::ToolResult {
        let started = std::time::Instant::now();
        match <Self as ToolHandler>::execute(self, &input).await {
            Ok(s) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                let result = serde_json::from_str::<serde_json::Value>(&s)
                    .ok()
                    .filter(|v| v.is_object() || v.is_array())
                    .unwrap_or_else(|| serde_json::json!({"text": s}));
                super::ToolResult { meta: super::ToolMeta::ok(variant, elapsed_ms), result }
            }
            Err(e) => super::ToolResult::error(variant, e.to_string()),
        }
    }
}

#[async_trait]
impl ToolHandler for SendMessageHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let platform = input
            .get("platform")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'platform'".into()))?;
        let message = input
            .get("message")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'message'".into()))?
            .to_string();
        if message.is_empty() {
            return Err(ToolError::InvalidArguments(
                "message cannot be empty".into(),
            ));
        }

        // Per-platform cap — email gets a larger budget than chat platforms.
        let effective_cap = if platform.eq_ignore_ascii_case("email") {
            MAX_EMAIL_LEN
        } else {
            MAX_MESSAGE_LEN
        };
        if message.len() > effective_cap {
            return Err(ToolError::InvalidArguments(format!(
                "message exceeds {effective_cap} char cap for platform '{platform}'"
            )));
        }

        let target = input.get("target").and_then(Value::as_str);
        let webhook_override = input.get("webhook_url").and_then(Value::as_str);

        match platform.to_ascii_lowercase().as_str() {
            "slack" => send_slack(&self.client, &message, webhook_override).await,
            "telegram" => send_telegram(&self.client, &message, target).await,
            "discord" => send_discord(&self.client, &message, webhook_override).await,
            "webhook" => send_webhook(&self.client, &message, webhook_override).await,
            "matrix" => send_matrix(&self.client, &message, target, input).await,
            "whatsapp" => send_whatsapp(&self.client, &message, target, input).await,
            "signal" => send_signal(&self.client, &message, target, input).await,
            "email" => send_email(&message, input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown platform '{other}' (expected: slack|telegram|discord|webhook|matrix|whatsapp|signal|email)"
            ))),
        }
    }
}

// MARK: - Platform: Slack

async fn send_slack(
    client: &Client,
    message: &str,
    webhook_override: Option<&str>,
) -> Result<String, ToolError> {
    let webhook = match webhook_override {
        Some(url) => url.to_string(),
        None => std::env::var("SLACK_WEBHOOK_URL").map_err(|_| {
            ToolError::ExecutionFailed(
                "SLACK_WEBHOOK_URL not set and no webhook_url provided".into(),
            )
        })?,
    };
    validate_outbound_url(&webhook)?;

    let body = json!({ "text": message });
    let resp = client
        .post(&webhook)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("slack request: {e}")))?;

    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "slack HTTP {status}: {text}"
        )));
    }
    Ok(json!({
        "success": true,
        "platform": "slack",
        "status": status,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Telegram

async fn send_telegram(
    client: &Client,
    message: &str,
    target: Option<&str>,
) -> Result<String, ToolError> {
    let token = std::env::var("TELEGRAM_BOT_TOKEN")
        .map_err(|_| ToolError::ExecutionFailed("TELEGRAM_BOT_TOKEN not set".into()))?;
    let chat_id = target
        .map(String::from)
        .unwrap_or_else(|| std::env::var("TELEGRAM_CHAT_ID").unwrap_or_default());
    if chat_id.is_empty() {
        return Err(ToolError::InvalidArguments(
            "telegram needs 'target' (chat_id) or TELEGRAM_CHAT_ID env var".into(),
        ));
    }

    let url = format!("https://api.telegram.org/bot{token}/sendMessage");
    let body = json!({
        "chat_id": chat_id,
        "text": message,
        "parse_mode": "Markdown",
    });
    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("telegram request: {e}")))?;
    let status = resp.status().as_u16();
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("telegram parse: {e}")))?;
    if !payload.get("ok").and_then(Value::as_bool).unwrap_or(false) {
        return Err(ToolError::ExecutionFailed(format!(
            "telegram sendMessage failed (status {status}): {payload}"
        )));
    }
    Ok(json!({
        "success": true,
        "platform": "telegram",
        "chat_id": chat_id,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Discord

async fn send_discord(
    client: &Client,
    message: &str,
    webhook_override: Option<&str>,
) -> Result<String, ToolError> {
    let webhook = match webhook_override {
        Some(url) => url.to_string(),
        None => std::env::var("DISCORD_WEBHOOK_URL").map_err(|_| {
            ToolError::ExecutionFailed(
                "DISCORD_WEBHOOK_URL not set and no webhook_url provided".into(),
            )
        })?,
    };
    validate_outbound_url(&webhook)?;

    let body = json!({ "content": message });
    let resp = client
        .post(&webhook)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("discord request: {e}")))?;
    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "discord HTTP {status}: {text}"
        )));
    }
    Ok(json!({
        "success": true,
        "platform": "discord",
        "status": status,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Generic webhook

async fn send_webhook(
    client: &Client,
    message: &str,
    webhook_override: Option<&str>,
) -> Result<String, ToolError> {
    let webhook = webhook_override.ok_or_else(|| {
        ToolError::InvalidArguments("platform='webhook' requires 'webhook_url' argument".into())
    })?;
    validate_outbound_url(webhook)?;

    let body = json!({ "text": message });
    let resp = client
        .post(webhook)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("webhook request: {e}")))?;
    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "webhook HTTP {status}: {text}"
        )));
    }
    Ok(json!({
        "success": true,
        "platform": "webhook",
        "status": status,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Matrix
//
// Matrix client-server API PUT /_matrix/client/v3/rooms/{roomId}/send/m.room.message/{txnId}
// https://spec.matrix.org/v1.8/client-server-api/#put_matrixclientv3roomsroomidsendeventtypetxnid
//
// Required env:
//   MATRIX_HOMESERVER         e.g. "https://matrix.org"
//   MATRIX_ACCESS_TOKEN       bearer token
// Target (room id) can come from: input.target, input.room_id, or env MATRIX_ROOM_ID.

async fn send_matrix(
    client: &Client,
    message: &str,
    target: Option<&str>,
    input: &Value,
) -> Result<String, ToolError> {
    let homeserver = std::env::var("MATRIX_HOMESERVER")
        .map_err(|_| ToolError::ExecutionFailed("MATRIX_HOMESERVER not set".into()))?;
    let access_token = std::env::var("MATRIX_ACCESS_TOKEN")
        .map_err(|_| ToolError::ExecutionFailed("MATRIX_ACCESS_TOKEN not set".into()))?;

    let room_id_owned = input
        .get("room_id")
        .and_then(Value::as_str)
        .map(String::from)
        .or_else(|| target.map(String::from))
        .or_else(|| std::env::var("MATRIX_ROOM_ID").ok())
        .ok_or_else(|| {
            ToolError::InvalidArguments("matrix needs 'room_id' / 'target' / MATRIX_ROOM_ID".into())
        })?;

    validate_outbound_url(&homeserver)?;

    let txn_id = format!("epistemos-{}", uuid::Uuid::new_v4());
    // Matrix room IDs must be URL-encoded before substitution into the path.
    let room_enc = url_encode(&room_id_owned);
    let url = format!(
        "{}/_matrix/client/v3/rooms/{}/send/m.room.message/{}",
        homeserver.trim_end_matches('/'),
        room_enc,
        txn_id
    );

    let body = json!({
        "msgtype": "m.text",
        "body": message,
    });

    let resp = client
        .put(&url)
        .bearer_auth(&access_token)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("matrix request: {e}")))?;

    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "matrix HTTP {status}: {text}"
        )));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("matrix parse: {e}")))?;
    let event_id = payload
        .get("event_id")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    Ok(json!({
        "success": true,
        "platform": "matrix",
        "room_id": room_id_owned,
        "event_id": event_id,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: WhatsApp (Cloud API)
//
// POST https://graph.facebook.com/{api_version}/{phone_number_id}/messages
// https://developers.facebook.com/docs/whatsapp/cloud-api/guides/send-messages/
//
// Required env:
//   WHATSAPP_ACCESS_TOKEN       Meta Graph API bearer token
//   WHATSAPP_PHONE_NUMBER_ID    numeric phone number ID
// Optional env:
//   WHATSAPP_API_VERSION        defaults to "v20.0"
// Target (recipient phone) comes from input.target or input.to.

async fn send_whatsapp(
    client: &Client,
    message: &str,
    target: Option<&str>,
    input: &Value,
) -> Result<String, ToolError> {
    let access_token = std::env::var("WHATSAPP_ACCESS_TOKEN")
        .map_err(|_| ToolError::ExecutionFailed("WHATSAPP_ACCESS_TOKEN not set".into()))?;
    let phone_number_id = std::env::var("WHATSAPP_PHONE_NUMBER_ID")
        .map_err(|_| ToolError::ExecutionFailed("WHATSAPP_PHONE_NUMBER_ID not set".into()))?;
    let api_version = std::env::var("WHATSAPP_API_VERSION").unwrap_or_else(|_| "v20.0".to_string());

    let recipient = input
        .get("to")
        .and_then(Value::as_str)
        .map(String::from)
        .or_else(|| target.map(String::from))
        .ok_or_else(|| {
            ToolError::InvalidArguments(
                "whatsapp needs 'to' or 'target' (E.164 phone like +15551234567)".into(),
            )
        })?;

    let url = format!(
        "https://graph.facebook.com/{}/{}/messages",
        api_version, phone_number_id
    );
    let body = json!({
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": recipient,
        "type": "text",
        "text": { "preview_url": false, "body": message },
    });

    let resp = client
        .post(&url)
        .bearer_auth(&access_token)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("whatsapp request: {e}")))?;

    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "whatsapp HTTP {status}: {text}"
        )));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("whatsapp parse: {e}")))?;
    let message_id = payload
        .get("messages")
        .and_then(Value::as_array)
        .and_then(|a| a.first())
        .and_then(|m| m.get("id"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    Ok(json!({
        "success": true,
        "platform": "whatsapp",
        "to": recipient,
        "message_id": message_id,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Signal (signal-cli REST)
//
// POST {base_url}/v2/send
// https://github.com/bbernhard/signal-cli-rest-api (de-facto local REST front end)
//
// Required env:
//   SIGNAL_CLI_BASE_URL         e.g. "http://127.0.0.1:8080"  (locally hosted only!)
//   SIGNAL_ACCOUNT              your registered Signal number (E.164)
// Target (recipient) via input.to / input.target (array or single E.164 number).
//
// NOTE: signal-cli-rest-api is intended for LOCAL deployment, so we allow
// private-IP URLs for this platform only. We still reject non-http schemes.

async fn send_signal(
    client: &Client,
    message: &str,
    target: Option<&str>,
    input: &Value,
) -> Result<String, ToolError> {
    let base_url = std::env::var("SIGNAL_CLI_BASE_URL")
        .map_err(|_| ToolError::ExecutionFailed("SIGNAL_CLI_BASE_URL not set".into()))?;
    if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
        return Err(ToolError::ExecutionFailed(format!(
            "SIGNAL_CLI_BASE_URL must be http(s): {base_url}"
        )));
    }
    let account = std::env::var("SIGNAL_ACCOUNT")
        .map_err(|_| ToolError::ExecutionFailed("SIGNAL_ACCOUNT not set".into()))?;

    // Accept either a single recipient or a comma-separated list.
    let recipients: Vec<String> = if let Some(to_arr) = input.get("to").and_then(Value::as_array) {
        to_arr
            .iter()
            .filter_map(|v| v.as_str().map(String::from))
            .collect()
    } else if let Some(s) = input.get("to").and_then(Value::as_str) {
        s.split(',').map(|p| p.trim().to_string()).collect()
    } else if let Some(t) = target {
        t.split(',').map(|p| p.trim().to_string()).collect()
    } else {
        return Err(ToolError::InvalidArguments(
            "signal needs 'to' / 'target' (E.164 number or array of numbers)".into(),
        ));
    };

    if recipients.is_empty() {
        return Err(ToolError::InvalidArguments(
            "signal 'to' must contain at least one recipient".into(),
        ));
    }

    let url = format!("{}/v2/send", base_url.trim_end_matches('/'));
    let body = json!({
        "number": account,
        "recipients": recipients,
        "message": message,
    });

    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("signal request: {e}")))?;
    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "signal HTTP {status}: {text}"
        )));
    }
    // Newer signal-cli-rest-api returns { "timestamp": ... }
    let payload: Value = resp.json().await.unwrap_or_else(|_| json!({}));
    Ok(json!({
        "success": true,
        "platform": "signal",
        "recipients": recipients,
        "timestamp": payload.get("timestamp"),
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Platform: Email (SMTP via lettre)
//
// Required env:
//   SMTP_HOST               e.g. "smtp.gmail.com"
//   SMTP_USERNAME           login
//   SMTP_PASSWORD           app password / token (NEVER raw account pw!)
//   SMTP_FROM               From: address
// Optional env:
//   SMTP_PORT               default 465 (implicit TLS) or 587 (STARTTLS)
// Input fields:
//   to          recipient address (or input.target)
//   subject     subject line (required)
//   reply_to    optional

async fn send_email(message: &str, input: &Value) -> Result<String, ToolError> {
    let host = std::env::var("SMTP_HOST")
        .map_err(|_| ToolError::ExecutionFailed("SMTP_HOST not set".into()))?;
    let username = std::env::var("SMTP_USERNAME")
        .map_err(|_| ToolError::ExecutionFailed("SMTP_USERNAME not set".into()))?;
    let password = std::env::var("SMTP_PASSWORD")
        .map_err(|_| ToolError::ExecutionFailed("SMTP_PASSWORD not set".into()))?;
    let from = std::env::var("SMTP_FROM")
        .map_err(|_| ToolError::ExecutionFailed("SMTP_FROM not set".into()))?;
    let port: u16 = std::env::var("SMTP_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(465);

    let to = input
        .get("to")
        .and_then(Value::as_str)
        .or_else(|| input.get("target").and_then(Value::as_str))
        .ok_or_else(|| ToolError::InvalidArguments("email needs 'to'".into()))?;
    let subject = input
        .get("subject")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("email needs 'subject'".into()))?;
    let reply_to = input.get("reply_to").and_then(Value::as_str);

    let mut builder = EmailMessage::builder()
        .from(
            from.parse()
                .map_err(|e| ToolError::InvalidArguments(format!("invalid SMTP_FROM: {e}")))?,
        )
        .to(to
            .parse()
            .map_err(|e| ToolError::InvalidArguments(format!("invalid 'to': {e}")))?)
        .subject(subject)
        .header(ContentType::TEXT_PLAIN);
    if let Some(rt) = reply_to {
        builder = builder.reply_to(
            rt.parse()
                .map_err(|e| ToolError::InvalidArguments(format!("invalid reply_to: {e}")))?,
        );
    }
    let email = builder
        .body(message.to_string())
        .map_err(|e| ToolError::ExecutionFailed(format!("email build: {e}")))?;

    let creds = Credentials::new(username, password);

    // Port 465 = implicit TLS; 587 = STARTTLS.
    let transport: AsyncSmtpTransport<Tokio1Executor> = if port == 587 {
        AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&host)
            .map_err(|e| ToolError::ExecutionFailed(format!("smtp starttls: {e}")))?
            .credentials(creds)
            .port(port)
            .build()
    } else {
        AsyncSmtpTransport::<Tokio1Executor>::relay(&host)
            .map_err(|e| ToolError::ExecutionFailed(format!("smtp relay: {e}")))?
            .credentials(creds)
            .port(port)
            .build()
    };

    let response = transport
        .send(email)
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("smtp send: {e}")))?;

    Ok(json!({
        "success": true,
        "platform": "email",
        "to": to,
        "subject": subject,
        "chars_sent": message.len(),
        "smtp_response_code": response.code().to_string(),
    })
    .to_string())
}

// MARK: - Helpers

fn validate_outbound_url(url: &str) -> Result<(), ToolError> {
    if !url.starts_with("https://") && !url.starts_with("http://") {
        return Err(ToolError::ExecutionFailed(format!(
            "invalid webhook URL (must be http/https): {url}"
        )));
    }
    if super::web_fetch::is_private_url(url) {
        return Err(ToolError::ExecutionFailed(format!(
            "webhook URL blocked (SSRF protection): {url}"
        )));
    }
    Ok(())
}

/// Minimal percent-encoding for Matrix room IDs and path segments.
/// Matrix room IDs look like `!abc123:example.org` — the `!`, `:`, and any
/// unicode must be percent-encoded. This is a tiny local helper so we don't
/// pull in the full `percent-encoding` crate just for this.
fn url_encode(input: &str) -> String {
    let mut out = String::with_capacity(input.len() * 3);
    for byte in input.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*byte as char);
            }
            _ => {
                out.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    out
}

pub fn send_message_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "send_message".to_string(),
        description: "Send a message to one of eight platforms: slack, telegram, discord, \
             webhook, matrix, whatsapp, signal, or email. Credentials are read from env vars \
             per platform (see tool docs). Messages > 4096 chars are rejected for chat \
             platforms; email allows up to 32,768. SENDING IS IRREVERSIBLE — the permission \
             gate fires unless the caller already pre-approved destructive actions."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "platform": {
                    "type": "string",
                    "enum": ["slack","telegram","discord","webhook","matrix","whatsapp","signal","email"]
                },
                "message": { "type": "string", "description": "Message body (max 4,096 chars; 32,768 for email)." },
                "target": { "type": "string", "description": "Generic recipient field (telegram chat_id, matrix room_id, whatsapp/signal phone, email address)." },
                "webhook_url": { "type": "string", "description": "Explicit webhook URL for slack|discord|webhook." },
                "room_id": { "type": "string", "description": "Matrix room ID override." },
                "to": { "description": "Explicit recipient (string or array) for whatsapp/signal/email." },
                "subject": { "type": "string", "description": "Email subject line (required for email)." },
                "reply_to": { "type": "string", "description": "Optional Reply-To address for email." }
            },
            "required": ["platform", "message"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn send_message_rejects_unknown_platform() {
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "fax",
                "message": "hi"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown platform"));
    }

    #[tokio::test]
    async fn send_message_rejects_empty_message() {
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "slack",
                "message": ""
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("empty"));
    }

    #[tokio::test]
    async fn send_message_rejects_oversized_message() {
        let handler = SendMessageHandler::new().unwrap();
        let huge = "x".repeat(MAX_MESSAGE_LEN + 1);
        let err = handler
            .execute(&json!({
                "platform": "slack",
                "message": huge
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("char cap"));
    }

    #[tokio::test]
    async fn email_allows_larger_payload() {
        // Just above the chat cap, well under the email cap. The test is
        // order-agnostic relative to other email tests that poke SMTP_* env
        // vars — we only care that the oversized message is NOT what
        // triggers the failure (i.e. the email platform accepted the body).
        let big = "e".repeat(MAX_MESSAGE_LEN + 1000);
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "email",
                "message": big,
                "to": "a@b.com",
                "subject": "test"
            }))
            .await
            .unwrap_err();
        // The oversized-message rejection would say "char cap"; any other
        // error (missing SMTP_*, invalid address, SMTP connect failure) is
        // fine — it proves the email path accepted the larger body.
        let err_text = format!("{err}");
        assert!(
            !err_text.contains("char cap"),
            "email should accept payloads larger than MAX_MESSAGE_LEN, got: {err_text}"
        );
    }

    #[tokio::test]
    async fn webhook_platform_requires_url() {
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "webhook",
                "message": "hi"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("webhook_url"));
    }

    #[tokio::test]
    async fn webhook_url_validation_rejects_private_ip() {
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "webhook",
                "message": "hi",
                "webhook_url": "http://127.0.0.1/evil"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("SSRF"));
    }

    #[tokio::test]
    async fn webhook_url_validation_rejects_non_http_scheme() {
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "webhook",
                "message": "hi",
                "webhook_url": "ftp://example.com"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("http"));
    }

    #[tokio::test]
    async fn slack_without_env_errors() {
        let saved = std::env::var("SLACK_WEBHOOK_URL").ok();
        std::env::remove_var("SLACK_WEBHOOK_URL");

        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "slack",
                "message": "hi"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("SLACK_WEBHOOK_URL"));

        if let Some(v) = saved {
            std::env::set_var("SLACK_WEBHOOK_URL", v);
        }
    }

    #[tokio::test]
    async fn telegram_without_token_errors() {
        let saved = std::env::var("TELEGRAM_BOT_TOKEN").ok();
        std::env::remove_var("TELEGRAM_BOT_TOKEN");

        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "telegram",
                "message": "hi",
                "target": "12345"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("TELEGRAM_BOT_TOKEN"));

        if let Some(v) = saved {
            std::env::set_var("TELEGRAM_BOT_TOKEN", v);
        }
    }

    #[tokio::test]
    async fn matrix_without_env_errors() {
        let saved_hs = std::env::var("MATRIX_HOMESERVER").ok();
        let saved_at = std::env::var("MATRIX_ACCESS_TOKEN").ok();
        std::env::remove_var("MATRIX_HOMESERVER");
        std::env::remove_var("MATRIX_ACCESS_TOKEN");

        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(
                &json!({ "platform": "matrix", "message": "hi", "target": "!abc:example.org" }),
            )
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("MATRIX_HOMESERVER"));

        if let Some(v) = saved_hs {
            std::env::set_var("MATRIX_HOMESERVER", v);
        }
        if let Some(v) = saved_at {
            std::env::set_var("MATRIX_ACCESS_TOKEN", v);
        }
    }

    #[tokio::test]
    async fn whatsapp_without_env_errors() {
        let saved_at = std::env::var("WHATSAPP_ACCESS_TOKEN").ok();
        let saved_id = std::env::var("WHATSAPP_PHONE_NUMBER_ID").ok();
        std::env::remove_var("WHATSAPP_ACCESS_TOKEN");
        std::env::remove_var("WHATSAPP_PHONE_NUMBER_ID");

        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "platform": "whatsapp", "message": "hi", "to": "+15551234567" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("WHATSAPP_ACCESS_TOKEN"));

        if let Some(v) = saved_at {
            std::env::set_var("WHATSAPP_ACCESS_TOKEN", v);
        }
        if let Some(v) = saved_id {
            std::env::set_var("WHATSAPP_PHONE_NUMBER_ID", v);
        }
    }

    #[tokio::test]
    async fn signal_without_env_errors() {
        let saved_url = std::env::var("SIGNAL_CLI_BASE_URL").ok();
        let saved_acct = std::env::var("SIGNAL_ACCOUNT").ok();
        std::env::remove_var("SIGNAL_CLI_BASE_URL");
        std::env::remove_var("SIGNAL_ACCOUNT");

        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "platform": "signal", "message": "hi", "to": "+15551234567" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("SIGNAL_CLI_BASE_URL"));

        if let Some(v) = saved_url {
            std::env::set_var("SIGNAL_CLI_BASE_URL", v);
        }
        if let Some(v) = saved_acct {
            std::env::set_var("SIGNAL_ACCOUNT", v);
        }
    }

    #[tokio::test]
    async fn email_requires_subject() {
        std::env::set_var("SMTP_HOST", "smtp.example.com");
        std::env::set_var("SMTP_USERNAME", "user");
        std::env::set_var("SMTP_PASSWORD", "pw");
        std::env::set_var("SMTP_FROM", "a@b.com");
        let handler = SendMessageHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "platform": "email",
                "message": "hi",
                "to": "a@b.com"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("subject"));
        std::env::remove_var("SMTP_HOST");
        std::env::remove_var("SMTP_USERNAME");
        std::env::remove_var("SMTP_PASSWORD");
        std::env::remove_var("SMTP_FROM");
    }

    #[test]
    fn url_encode_handles_matrix_room_ids() {
        assert_eq!(url_encode("!abc123:example.org"), "%21abc123%3Aexample.org");
        assert_eq!(url_encode("simple"), "simple");
    }
}
