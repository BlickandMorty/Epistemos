use std::time::Duration;

use agent_core::channel_relay::RelayOutboxAckRequest;
use agent_core::tools::communication::SendMessageHandler;
use agent_core::tools::registry::ToolHandler;
use reqwest::{Client, RequestBuilder};
use serde::Deserialize;
use serde_json::{json, Value};

const DEFAULT_RELAY_URL: &str = "http://127.0.0.1:8787";
const DEFAULT_INTERVAL_SECONDS: u64 = 5;
const DEFAULT_BATCH_SIZE: usize = 20;

#[derive(Debug, Clone, PartialEq, Eq)]
struct WorkerCliArgs {
    relay_url: String,
    channel_id: String,
    token: Option<String>,
    interval_seconds: u64,
    batch_size: usize,
    once: bool,
}

impl WorkerCliArgs {
    fn parse_from<I>(args: I) -> Result<Self, String>
    where
        I: IntoIterator<Item = String>,
    {
        let mut relay_url = std::env::var("EPISTEMOS_CHANNEL_RELAY_URL")
            .unwrap_or_else(|_| DEFAULT_RELAY_URL.to_string());
        let mut channel_id: Option<String> = None;
        let mut token = std::env::var("EPISTEMOS_CHANNEL_RELAY_TOKEN").ok();
        let mut interval_seconds = DEFAULT_INTERVAL_SECONDS;
        let mut batch_size = DEFAULT_BATCH_SIZE;
        let mut once = false;
        let mut iter = args.into_iter();

        while let Some(arg) = iter.next() {
            match arg.as_str() {
                "--relay" => {
                    relay_url = iter
                        .next()
                        .ok_or_else(|| "missing value after --relay".to_string())?;
                }
                "--channel" => {
                    channel_id = Some(
                        iter.next()
                            .ok_or_else(|| "missing value after --channel".to_string())?,
                    );
                }
                "--token" => {
                    token = Some(
                        iter.next()
                            .ok_or_else(|| "missing value after --token".to_string())?,
                    );
                }
                "--interval" => {
                    interval_seconds = iter
                        .next()
                        .ok_or_else(|| "missing value after --interval".to_string())?
                        .parse::<u64>()
                        .map_err(|_| "invalid value for --interval".to_string())?;
                }
                "--batch" => {
                    batch_size = iter
                        .next()
                        .ok_or_else(|| "missing value after --batch".to_string())?
                        .parse::<usize>()
                        .map_err(|_| "invalid value for --batch".to_string())?;
                }
                "--once" => {
                    once = true;
                }
                "--help" | "-h" => {
                    return Err(Self::usage());
                }
                other => {
                    return Err(format!("unknown argument '{other}'\n\n{}", Self::usage()));
                }
            }
        }

        let channel_id =
            channel_id.ok_or_else(|| format!("missing required --channel\n\n{}", Self::usage()))?;
        let channel_id = channel_id.trim().to_ascii_lowercase();
        if !is_supported_worker_channel(&channel_id) {
            return Err(format!(
                "unsupported channel '{channel_id}'\n\n{}",
                Self::usage()
            ));
        }
        if interval_seconds == 0 {
            return Err("invalid value for --interval (must be >= 1)".to_string());
        }
        if batch_size == 0 {
            return Err("invalid value for --batch (must be >= 1)".to_string());
        }

        Ok(Self {
            relay_url: relay_url.trim().trim_end_matches('/').to_string(),
            channel_id,
            token,
            interval_seconds,
            batch_size,
            once,
        })
    }

    fn usage() -> String {
        format!(
            "Usage: epistemos_channel_worker --channel <telegram|slack|discord|whatsapp|signal|email> \
[--relay <url>] [--token <bearer-token>] [--interval <seconds>] [--batch <count>] [--once]\n\
Defaults:\n\
  --relay {DEFAULT_RELAY_URL} (or $EPISTEMOS_CHANNEL_RELAY_URL)\n\
  --token $EPISTEMOS_CHANNEL_RELAY_TOKEN\n\
  --interval {DEFAULT_INTERVAL_SECONDS}\n\
  --batch {DEFAULT_BATCH_SIZE}"
        )
    }
}

#[derive(Debug, Clone, Deserialize)]
struct RelayOutboxEnvelope {
    messages: Vec<RelayOutboxMessage>,
}

#[derive(Debug, Clone, Deserialize)]
struct RelayOutboxMessage {
    id: String,
    conversation_id: Option<String>,
    recipient_id: Option<String>,
    message: String,
    sender_identity: Option<String>,
    metadata: Option<Value>,
    #[serde(rename = "created_at")]
    _created_at: String,
}

fn build_send_payload(channel_id: &str, message: &RelayOutboxMessage) -> Result<Value, String> {
    let recipient = required_recipient(message, channel_id)?;
    let mut payload = json!({
        "platform": channel_id,
        "message": message.message,
    });

    match channel_id {
        "telegram" => {
            payload["target"] = json!(recipient);
        }
        "slack" | "discord" => {
            payload["webhook_url"] = json!(recipient);
        }
        "whatsapp" | "signal" => {
            payload["to"] = json!(recipient);
        }
        "email" => {
            payload["to"] = json!(recipient);
            payload["subject"] = json!(required_metadata(message, "subject", "email subject")?);
            if let Some(reply_to) = optional_metadata(message, "reply_to") {
                payload["reply_to"] = json!(reply_to);
            }
        }
        other => {
            return Err(format!("unsupported worker channel '{other}'"));
        }
    }

    Ok(payload)
}

#[cfg(test)]
fn success_ack_request(channel_id: &str, message: &RelayOutboxMessage) -> RelayOutboxAckRequest {
    success_ack_request_with_response(channel_id, message, None)
}

fn success_ack_request_with_response(
    channel_id: &str,
    message: &RelayOutboxMessage,
    response: Option<&Value>,
) -> RelayOutboxAckRequest {
    let title = default_ack_title(channel_id, message);
    let subtitle = default_ack_subtitle(message, title.as_deref());

    RelayOutboxAckRequest {
        success: true,
        message_id: response.and_then(response_message_id),
        conversation_id: message.conversation_id.clone(),
        sender_id: None,
        sender_display: message.sender_identity.clone(),
        unix: None,
        text: Some(message.message.clone()),
        title,
        subtitle,
        archived: Some(false),
        error: None,
    }
}

fn failure_ack_request(error: String) -> RelayOutboxAckRequest {
    RelayOutboxAckRequest {
        success: false,
        message_id: None,
        conversation_id: None,
        sender_id: None,
        sender_display: None,
        unix: None,
        text: None,
        title: None,
        subtitle: None,
        archived: None,
        error: Some(error),
    }
}

fn is_supported_worker_channel(channel_id: &str) -> bool {
    matches!(
        channel_id,
        "telegram" | "slack" | "discord" | "whatsapp" | "signal" | "email"
    )
}

fn trimmed(value: Option<&str>) -> Option<String> {
    value
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn optional_metadata(message: &RelayOutboxMessage, key: &str) -> Option<String> {
    message
        .metadata
        .as_ref()
        .and_then(|value| value.get(key))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn required_metadata(
    message: &RelayOutboxMessage,
    key: &str,
    description: &str,
) -> Result<String, String> {
    optional_metadata(message, key)
        .ok_or_else(|| format!("missing {description} in relay metadata for {}", message.id))
}

fn required_recipient(message: &RelayOutboxMessage, channel_id: &str) -> Result<String, String> {
    trimmed(message.recipient_id.as_deref()).ok_or_else(|| {
        format!(
            "missing recipient_id for relay outbox {} ({channel_id})",
            message.id
        )
    })
}

fn looks_like_webhook_target(value: &str) -> bool {
    let lowered = value.to_ascii_lowercase();
    lowered.starts_with("http://") || lowered.starts_with("https://")
}

fn default_ack_title(channel_id: &str, message: &RelayOutboxMessage) -> Option<String> {
    let display_target = optional_metadata(message, "display_target");
    let subject = optional_metadata(message, "subject");
    let recipient = trimmed(message.recipient_id.as_deref());
    let conversation = trimmed(message.conversation_id.as_deref());

    match channel_id {
        "email" => subject
            .or(display_target)
            .or(recipient)
            .or(conversation)
            .or_else(|| Some("Email".to_string())),
        "slack" | "discord" => display_target
            .or(conversation)
            .or_else(|| recipient.filter(|value| !looks_like_webhook_target(value)))
            .or_else(|| Some(channel_id.to_string())),
        _ => display_target
            .or(recipient)
            .or(conversation)
            .or_else(|| Some(channel_id.to_string())),
    }
}

fn default_ack_subtitle(message: &RelayOutboxMessage, title: Option<&str>) -> Option<String> {
    let title = title.unwrap_or_default();
    let recipient = trimmed(message.recipient_id.as_deref())?;
    if looks_like_webhook_target(&recipient) || recipient == title {
        return Some(String::new());
    }
    Some(recipient)
}

fn response_message_id(response: &Value) -> Option<String> {
    response
        .get("message_id")
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .or_else(|| {
            response
                .get("event_id")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned)
        })
        .or_else(|| {
            response
                .get("timestamp")
                .and_then(Value::as_i64)
                .map(|value| value.to_string())
        })
}

fn authorized(builder: RequestBuilder, token: Option<&str>) -> RequestBuilder {
    if let Some(token) = trimmed(token) {
        builder.bearer_auth(token)
    } else {
        builder
    }
}

fn relay_url(base: &str, suffix: &str) -> String {
    format!(
        "{}/{}",
        base.trim_end_matches('/'),
        suffix.trim_start_matches('/')
    )
}

async fn check_relay_health(client: &Client, cli: &WorkerCliArgs) -> Result<(), String> {
    let response = authorized(
        client.get(relay_url(&cli.relay_url, "healthz")),
        cli.token.as_deref(),
    )
    .send()
    .await
    .map_err(|e| format!("relay health request failed: {e}"))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("relay health failed with HTTP {status}: {body}"));
    }
    Ok(())
}

async fn fetch_outbox(
    client: &Client,
    cli: &WorkerCliArgs,
) -> Result<Vec<RelayOutboxMessage>, String> {
    let url = relay_url(
        &cli.relay_url,
        &format!(
            "v1/channels/{}/outbox?limit={}",
            cli.channel_id, cli.batch_size
        ),
    );
    let response = authorized(client.get(url), cli.token.as_deref())
        .send()
        .await
        .map_err(|e| format!("fetch outbox failed: {e}"))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!(
            "relay outbox fetch failed with HTTP {status}: {body}"
        ));
    }

    let envelope = response
        .json::<RelayOutboxEnvelope>()
        .await
        .map_err(|e| format!("decode relay outbox: {e}"))?;
    Ok(envelope.messages)
}

async fn post_ack(
    client: &Client,
    cli: &WorkerCliArgs,
    outbox_id: &str,
    ack: &RelayOutboxAckRequest,
) -> Result<(), String> {
    let url = relay_url(
        &cli.relay_url,
        &format!("v1/channels/{}/outbox/{outbox_id}/ack", cli.channel_id),
    );
    let response = authorized(client.post(url).json(ack), cli.token.as_deref())
        .send()
        .await
        .map_err(|e| format!("ack relay outbox {outbox_id}: {e}"))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!(
            "relay ack for {outbox_id} failed with HTTP {status}: {body}"
        ));
    }
    Ok(())
}

async fn process_outbox_batch(
    client: &Client,
    handler: &SendMessageHandler,
    cli: &WorkerCliArgs,
) -> Result<usize, String> {
    let messages = fetch_outbox(client, cli).await?;
    let mut handled = 0usize;

    for message in messages {
        let payload = match build_send_payload(&cli.channel_id, &message) {
            Ok(payload) => payload,
            Err(error) => {
                post_ack(client, cli, &message.id, &failure_ack_request(error)).await?;
                handled += 1;
                continue;
            }
        };

        match handler.execute(&payload).await {
            Ok(response_text) => {
                let response_json = serde_json::from_str::<Value>(&response_text).ok();
                let ack = success_ack_request_with_response(
                    &cli.channel_id,
                    &message,
                    response_json.as_ref(),
                );
                post_ack(client, cli, &message.id, &ack).await?;
            }
            Err(error) => {
                post_ack(
                    client,
                    cli,
                    &message.id,
                    &failure_ack_request(error.to_string()),
                )
                .await?;
            }
        }

        handled += 1;
    }

    Ok(handled)
}

async fn run_worker(cli: WorkerCliArgs) -> Result<(), String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(30))
        .user_agent("Epistemos/1.0 (Channel Worker)")
        .build()
        .map_err(|e| format!("worker client init: {e}"))?;
    let handler = SendMessageHandler::new().map_err(|e| e.to_string())?;

    check_relay_health(&client, &cli).await?;
    eprintln!(
        "Connected relay worker for '{}' via {} (interval {}s, batch {}, once={})",
        cli.channel_id, cli.relay_url, cli.interval_seconds, cli.batch_size, cli.once
    );

    loop {
        match process_outbox_batch(&client, &handler, &cli).await {
            Ok(handled) => {
                if handled > 0 {
                    eprintln!(
                        "processed {handled} relay message(s) for {}",
                        cli.channel_id
                    );
                }
            }
            Err(error) => {
                if cli.once {
                    return Err(error);
                }
                eprintln!("{error}");
            }
        }

        if cli.once {
            return Ok(());
        }

        tokio::time::sleep(Duration::from_secs(cli.interval_seconds)).await;
    }
}

#[tokio::main]
async fn main() {
    let cli = match WorkerCliArgs::parse_from(std::env::args().skip(1)) {
        Ok(cli) => cli,
        Err(message) => {
            let exit_code = if message.starts_with("Usage:") { 0 } else { 1 };
            if exit_code == 0 {
                println!("{message}");
            } else {
                eprintln!("{message}");
            }
            std::process::exit(exit_code);
        }
    };

    if let Err(error) = run_worker(cli).await {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cli_requires_channel() {
        let error = WorkerCliArgs::parse_from(Vec::<String>::new()).unwrap_err();
        assert!(error.contains("--channel"));
    }

    #[test]
    fn cli_parses_explicit_overrides() {
        let cli = WorkerCliArgs::parse_from(vec![
            "--channel".to_string(),
            "telegram".to_string(),
            "--relay".to_string(),
            "https://relay.example.com".to_string(),
            "--token".to_string(),
            "secret".to_string(),
            "--interval".to_string(),
            "9".to_string(),
            "--batch".to_string(),
            "33".to_string(),
            "--once".to_string(),
        ])
        .unwrap();

        assert_eq!(cli.channel_id, "telegram");
        assert_eq!(cli.relay_url, "https://relay.example.com");
        assert_eq!(cli.token.as_deref(), Some("secret"));
        assert_eq!(cli.interval_seconds, 9);
        assert_eq!(cli.batch_size, 33);
        assert!(cli.once);
    }

    #[test]
    fn build_send_payload_preserves_email_subject() {
        let payload = build_send_payload(
            "email",
            &RelayOutboxMessage {
                id: "outbox-1".to_string(),
                conversation_id: Some("thread-email".to_string()),
                recipient_id: Some("ops@example.com".to_string()),
                message: "status update".to_string(),
                sender_identity: Some("Epistemos HQ".to_string()),
                metadata: Some(json!({
                    "subject": "Operator Digest"
                })),
                _created_at: "2026-04-11T00:00:00Z".to_string(),
            },
        )
        .unwrap();

        assert_eq!(payload["platform"], json!("email"));
        assert_eq!(payload["to"], json!("ops@example.com"));
        assert_eq!(payload["subject"], json!("Operator Digest"));
    }

    #[test]
    fn build_send_payload_uses_webhook_for_slack() {
        let payload = build_send_payload(
            "slack",
            &RelayOutboxMessage {
                id: "outbox-2".to_string(),
                conversation_id: Some("thread-slack".to_string()),
                recipient_id: Some("https://hooks.slack.com/services/T/B/C".to_string()),
                message: "status update".to_string(),
                sender_identity: None,
                metadata: Some(json!({
                    "display_target": "Ops Alerts"
                })),
                _created_at: "2026-04-11T00:00:00Z".to_string(),
            },
        )
        .unwrap();

        assert_eq!(payload["platform"], json!("slack"));
        assert_eq!(
            payload["webhook_url"],
            json!("https://hooks.slack.com/services/T/B/C")
        );
    }

    #[test]
    fn success_ack_request_uses_safe_display_target() {
        let ack = success_ack_request(
            "slack",
            &RelayOutboxMessage {
                id: "outbox-3".to_string(),
                conversation_id: Some("ops-alerts".to_string()),
                recipient_id: Some("https://hooks.slack.com/services/T/B/C".to_string()),
                message: "status update".to_string(),
                sender_identity: Some("Epistemos HQ".to_string()),
                metadata: Some(json!({
                    "display_target": "Ops Alerts"
                })),
                _created_at: "2026-04-11T00:00:00Z".to_string(),
            },
        );

        assert!(ack.success);
        assert_eq!(ack.title.as_deref(), Some("Ops Alerts"));
        assert_eq!(ack.subtitle.as_deref(), Some(""));
        assert_eq!(ack.sender_display.as_deref(), Some("Epistemos HQ"));
    }
}
