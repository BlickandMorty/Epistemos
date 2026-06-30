//! `web_extract_schema` — public handler for schema-targeted web extraction.
//!
//! The implementation is AppStoreSafe: bounded HTTP fetch, SSRF-safe redirects,
//! no browser automation, no subprocesses, and honest JSON Schema validation
//! output.

use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};
use super::web_extract_schema_support::{
    extract_schema_payload_from_html, optional_bool, parse_schema_fields, parse_target_schema,
    required_string, MAX_WEB_URL_CHARS,
};
use super::web_fetch::{read_response_text_limited, secure_redirect_policy, validate_url};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_WEB_RESPONSE_BYTES: usize = 512 * 1024;
const MAX_SCHEMA_FIELDS: usize = 32;

fn build_client() -> Result<Client, ToolError> {
    Client::builder()
        .timeout(DEFAULT_TIMEOUT)
        .user_agent("Epistemos/1.0 (Knowledge Assistant)")
        .redirect(secure_redirect_policy())
        .build()
        .map_err(|e| ToolError::ExecutionFailed(format!("http client init: {e}")))
}

fn describe_web_request_error(provider: &str, error: reqwest::Error) -> String {
    let reason = if error.is_timeout() {
        "timeout"
    } else if error.is_connect() {
        "connect"
    } else if error.is_request() {
        "request"
    } else if error.is_body() {
        "body"
    } else if error.is_decode() {
        "decode"
    } else {
        "request"
    };
    format!("{provider} request failed: {reason}")
}

pub struct WebExtractSchemaHandler {
    client: Client,
}

impl WebExtractSchemaHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for WebExtractSchemaHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let url = required_string(input, "url", MAX_WEB_URL_CHARS)?;
        validate_url(url).map_err(ToolError::InvalidArguments)?;
        let schema = parse_target_schema(input)?;
        let fields = parse_schema_fields(input, &schema)?;
        let include_content = optional_bool(input, "include_content", false)?;
        let fail_on_schema_error = optional_bool(input, "fail_on_schema_error", false)?;

        let html = fetch_schema_html(&self.client, url).await?;
        let payload =
            extract_schema_payload_from_html(url, &html, &schema, &fields, include_content)?;

        if fail_on_schema_error && !payload["schema_valid"].as_bool().unwrap_or(false) {
            let error = payload["validation_error"]
                .as_str()
                .unwrap_or("extracted object did not satisfy schema");
            return Err(ToolError::ExecutionFailed(format!(
                "schema validation failed: {error}"
            )));
        }

        Ok(payload.to_string())
    }
}

async fn fetch_schema_html(client: &Client, url: &str) -> Result<String, ToolError> {
    let response = client.get(url).send().await.map_err(|e| {
        ToolError::ExecutionFailed(describe_web_request_error("web_extract_schema", e))
    })?;
    if !response.status().is_success() {
        return Err(ToolError::ExecutionFailed(format!(
            "HTTP {}",
            response.status().as_u16()
        )));
    }
    read_response_text_limited(response, MAX_WEB_RESPONSE_BYTES)
        .await
        .map(|(body, _)| body)
        .map_err(ToolError::ExecutionFailed)
}

pub fn web_extract_schema_structured_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "web_extract_schema".to_string(),
        description: "Fetch one URL and extract a JSON object that targets the caller's JSON \
             Schema. Uses page title, meta tags, JSON-LD, readable text, and optional per-field \
             regex hints; returns evidence plus JSON Schema validation status."
            .to_string(),
        parameters: json!({
            "type": "object",
            "additionalProperties": false,
            "properties": {
                "url": { "type": "string", "description": "URL to fetch and extract." },
                "schema": {
                    "type": "object",
                    "description": "JSON Schema for the extracted object. Object properties become extraction targets."
                },
                "fields": {
                    "type": "array",
                    "description": "Optional extraction hints that override schema-property defaults.",
                    "maxItems": MAX_SCHEMA_FIELDS,
                    "items": {
                        "type": "object",
                        "additionalProperties": false,
                        "properties": {
                            "name": { "type": "string" },
                            "source": {
                                "type": "string",
                                "enum": ["auto", "title", "meta", "text", "json_ld"],
                                "default": "auto"
                            },
                            "key": {
                                "type": "string",
                                "description": "Meta key or JSON-LD key/path to read. Defaults to name."
                            },
                            "pattern": {
                                "type": "string",
                                "description": "Regex applied to the selected source; capture group 1 is returned when present."
                            },
                            "required": { "type": "boolean", "default": false }
                        },
                        "required": ["name"]
                    }
                },
                "include_content": {
                    "type": "boolean",
                    "default": false,
                    "description": "Include bounded readable page text in the response for debugging."
                },
                "fail_on_schema_error": {
                    "type": "boolean",
                    "default": false,
                    "description": "Return a tool error when the extracted object does not validate."
                }
            },
            "required": ["url", "schema"]
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    #[test]
    fn web_extract_schema_from_html_fills_schema_and_evidence() {
        let html = r#"
            <!doctype html>
            <html>
              <head>
                <title>Plan 3 Widget</title>
                <meta name="description" content="A schema extraction test widget">
                <script type="application/ld+json">
                  {
                    "@type": "Article",
                    "author": { "name": "Ada Lovelace" },
                    "datePublished": "2026-06-30"
                  }
                </script>
              </head>
              <body>
                <article>
                  <h1>Plan 3 Widget</h1>
                  <p>SKU: EPI-42</p>
                </article>
              </body>
            </html>
        "#;
        let schema = json!({
            "type": "object",
            "required": ["title", "description", "author", "sku"],
            "properties": {
                "title": { "type": "string" },
                "description": { "type": "string" },
                "author": { "type": "string" },
                "sku": { "type": "string" },
                "datePublished": { "type": "string" }
            }
        });
        let input = json!({
            "fields": [
                {
                    "name": "sku",
                    "source": "text",
                    "pattern": "SKU:\\s*([A-Z0-9-]+)"
                }
            ]
        });
        let fields = parse_schema_fields(&input, &schema).unwrap();
        let payload = extract_schema_payload_from_html(
            "https://example.com/widget",
            html,
            &schema,
            &fields,
            false,
        )
        .unwrap();

        assert_eq!(payload["schema_valid"], json!(true));
        assert_eq!(payload["extracted"]["title"], json!("Plan 3 Widget"));
        assert_eq!(
            payload["extracted"]["description"],
            json!("A schema extraction test widget")
        );
        assert_eq!(payload["extracted"]["author"], json!("Ada Lovelace"));
        assert_eq!(payload["extracted"]["sku"], json!("EPI-42"));
        assert_eq!(payload["extracted"]["datePublished"], json!("2026-06-30"));
        assert!(payload["evidence"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["field"] == "sku" && item["source"] == "pattern:text"));
    }

    #[tokio::test]
    #[ignore = "live network smoke for the real web.extract_schema handler"]
    async fn web_extract_schema_live_example_when_enabled() {
        let handler = WebExtractSchemaHandler::new().unwrap();
        let output = handler
            .execute(&json!({
                "url": "https://example.com",
                "schema": {
                    "type": "object",
                    "required": ["title"],
                    "properties": {
                        "title": { "type": "string" },
                        "description": { "type": "string" }
                    }
                }
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["schema_valid"], json!(true));
        assert!(parsed["extracted"]["title"]
            .as_str()
            .unwrap()
            .contains("Example Domain"));
    }
}
