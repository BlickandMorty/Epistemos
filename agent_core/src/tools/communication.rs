//! Communication Tool — Phase 6 `send_message`
//!
//! Multi-platform messaging via a shared `MessagePlatform` adapter trait.
//! Platforms implemented in v1:
//!
//! * `slack`    — incoming webhook POST
//! * `telegram` — Bot API sendMessage
//! * `discord`  — incoming webhook POST
//! * `webhook`  — generic JSON POST to any URL
//!
//! Email is intentionally *not* implemented here — users who want to send
//! mail should use the Phase 4 `apple_mail` tool instead (AppleScript via
//! Mail.app). That path keeps SMTP/IMAP credentials out of the Rust crate.
//!
//! All platforms require an explicit `platform` argument so there's no
//! accidental misrouting. Credentials are read from environment variables
//! at call time so the agent can opt-in per session.

use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_MESSAGE_LEN: usize = 4_096;

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
            return Err(ToolError::InvalidArguments("message cannot be empty".into()));
        }
        if message.len() > MAX_MESSAGE_LEN {
            return Err(ToolError::InvalidArguments(format!(
                "message exceeds {MAX_MESSAGE_LEN} char cap"
            )));
        }
        let target = input.get("target").and_then(Value::as_str);
        let webhook_override = input.get("webhook_url").and_then(Value::as_str);

        match platform.to_ascii_lowercase().as_str() {
            "slack" => send_slack(&self.client, &message, webhook_override).await,
            "telegram" => send_telegram(&self.client, &message, target).await,
            "discord" => send_discord(&self.client, &message, webhook_override).await,
            "webhook" => send_webhook(&self.client, &message, webhook_override).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown platform '{other}' (expected: slack|telegram|discord|webhook)"
            ))),
        }
    }
}

// MARK: - Platforms

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

async fn send_telegram(
    client: &Client,
    message: &str,
    target: Option<&str>,
) -> Result<String, ToolError> {
    let token = std::env::var("TELEGRAM_BOT_TOKEN").map_err(|_| {
        ToolError::ExecutionFailed("TELEGRAM_BOT_TOKEN not set".into())
    })?;
    let chat_id = target.map(String::from).unwrap_or_else(|| {
        std::env::var("TELEGRAM_CHAT_ID").unwrap_or_default()
    });
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

async fn send_webhook(
    client: &Client,
    message: &str,
    webhook_override: Option<&str>,
) -> Result<String, ToolError> {
    let webhook = webhook_override.ok_or_else(|| {
        ToolError::InvalidArguments(
            "platform='webhook' requires 'webhook_url' argument".into(),
        )
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

pub fn send_message_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "send_message".to_string(),
        description: "Send a message to Slack, Telegram, Discord, or an arbitrary webhook. \
             Credentials are read from environment variables (SLACK_WEBHOOK_URL, \
             TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID, DISCORD_WEBHOOK_URL) unless an override \
             is passed via 'webhook_url' or 'target'. Messages larger than 4,096 chars are \
             rejected. SENDING IS IRREVERSIBLE — the permission gate fires unless the \
             caller already pre-approved destructive actions."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "platform": {
                    "type": "string",
                    "enum": ["slack", "telegram", "discord", "webhook"]
                },
                "message": { "type": "string", "description": "Message body (max 4,096 chars)." },
                "target": { "type": "string", "description": "Telegram chat_id (overrides TELEGRAM_CHAT_ID)." },
                "webhook_url": { "type": "string", "description": "Explicit webhook URL for slack|discord|webhook." }
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
}
