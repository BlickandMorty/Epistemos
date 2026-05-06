//! Web Fetch Tool — HTTP GET with HTML-to-text extraction
//!
//! Fetches a URL and extracts readable text content, stripping HTML tags,
//! scripts, styles, and navigation. Returns clean text for LLM consumption.
//!
//! Security: SSRF protection (blocks private IPs), URL validation,
//! response size limits, timeout enforcement.

use std::time::Duration;

use reqwest::Client;
use serde_json::{json, Value};

use super::registry::ToolHandler;

const MAX_RESPONSE_BYTES: usize = 512 * 1024; // 512KB
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_REDIRECT_HOPS: usize = 5;

// MARK: - SSRF Protection

/// Returns true when the URL targets a private / internal address. Exposed
/// so the Phase 3 web tools can share the same blocklist without duplicating
/// the constants.
pub(crate) fn is_private_url(url: &str) -> bool {
    let lower = url.to_lowercase();
    // Block private/internal IPs and localhost
    let blocked = [
        "://localhost",
        "://127.",
        "://0.",
        "://10.",
        "://172.16.",
        "://172.17.",
        "://172.18.",
        "://172.19.",
        "://172.20.",
        "://172.21.",
        "://172.22.",
        "://172.23.",
        "://172.24.",
        "://172.25.",
        "://172.26.",
        "://172.27.",
        "://172.28.",
        "://172.29.",
        "://172.30.",
        "://172.31.",
        "://192.168.",
        "://[::1]",
        "://169.254.",
        "://metadata.google",
        "://metadata.aws",
    ];
    blocked.iter().any(|b| lower.contains(b))
}

pub(crate) fn validate_url(url: &str) -> Result<(), String> {
    if url.is_empty() {
        return Err("URL is required.".to_string());
    }
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err("URL must start with http:// or https://".to_string());
    }
    if is_private_url(url) {
        return Err("Access to private/internal URLs is blocked (SSRF protection).".to_string());
    }
    Ok(())
}

pub(crate) fn validate_redirect_target(url: &str) -> Result<(), String> {
    validate_url(url)
}

pub(crate) fn secure_redirect_policy() -> reqwest::redirect::Policy {
    reqwest::redirect::Policy::custom(|attempt| {
        if attempt.previous().len() > MAX_REDIRECT_HOPS {
            attempt.error(format!("too many redirects (>{MAX_REDIRECT_HOPS})"))
        } else if let Err(reason) = validate_redirect_target(attempt.url().as_str()) {
            attempt.error(reason)
        } else {
            attempt.follow()
        }
    })
}

// MARK: - HTML to Text

/// Strips HTML tags and extracts readable text.
/// Removes script, style, nav, header, footer elements entirely.
pub(crate) fn html_to_text(html: &str) -> String {
    let mut result = String::with_capacity(html.len() / 3);
    let mut in_tag = false;
    let mut in_skip_element = false;
    let mut skip_depth: usize = 0;
    let mut tag_name = String::new();
    let mut collecting_tag_name = false;

    let skip_elements = [
        "script", "style", "nav", "header", "footer", "noscript", "svg",
    ];

    for ch in html.chars() {
        if ch == '<' {
            in_tag = true;
            tag_name.clear();
            collecting_tag_name = true;
            continue;
        }

        if ch == '>' {
            in_tag = false;
            collecting_tag_name = false;

            let tag_lower = tag_name.to_lowercase();
            let is_closing = tag_lower.starts_with('/');
            let clean_tag = tag_lower
                .trim_start_matches('/')
                .split_whitespace()
                .next()
                .unwrap_or("");

            if skip_elements.contains(&clean_tag) {
                if is_closing {
                    skip_depth = skip_depth.saturating_sub(1);
                    if skip_depth == 0 {
                        in_skip_element = false;
                    }
                } else if !tag_lower.ends_with('/') {
                    in_skip_element = true;
                    skip_depth += 1;
                }
            }

            // Add whitespace for block elements
            if matches!(
                clean_tag,
                "p" | "div"
                    | "br"
                    | "h1"
                    | "h2"
                    | "h3"
                    | "h4"
                    | "h5"
                    | "h6"
                    | "li"
                    | "tr"
                    | "td"
                    | "th"
                    | "blockquote"
                    | "pre"
                    | "section"
                    | "article"
            ) && !result.ends_with('\n')
            {
                result.push('\n');
            }

            continue;
        }

        if in_tag {
            if collecting_tag_name {
                if ch.is_whitespace() {
                    collecting_tag_name = false;
                } else {
                    tag_name.push(ch);
                }
            }
            continue;
        }

        if in_skip_element {
            continue;
        }

        // Decode common HTML entities
        result.push(ch);
    }

    // Decode entities
    let decoded = result
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ");

    // Collapse whitespace
    let mut clean = String::with_capacity(decoded.len());
    let mut last_was_newline = false;
    let mut last_was_space = false;

    for ch in decoded.chars() {
        if ch == '\n' {
            if !last_was_newline {
                clean.push('\n');
                last_was_newline = true;
            }
            last_was_space = false;
        } else if ch.is_whitespace() {
            if !last_was_space && !last_was_newline {
                clean.push(' ');
                last_was_space = true;
            }
        } else {
            clean.push(ch);
            last_was_newline = false;
            last_was_space = false;
        }
    }

    clean.trim().to_string()
}

// MARK: - Web Fetch Tool

pub struct WebFetchTool {
    client: Client,
}

impl Default for WebFetchTool {
    fn default() -> Self {
        Self::new()
    }
}

impl WebFetchTool {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(REQUEST_TIMEOUT)
            .user_agent("Epistemos/1.0 (Knowledge Assistant)")
            .redirect(secure_redirect_policy())
            .build()
            .expect("failed to build HTTP client");

        Self { client }
    }

    async fn fetch_url(&self, url: &str) -> Value {
        if let Err(e) = validate_url(url) {
            return json!({"success": false, "error": e});
        }

        let response = match self.client.get(url).send().await {
            Ok(r) => r,
            Err(e) => return json!({"success": false, "error": format!("Request failed: {e}")}),
        };

        let status = response.status().as_u16();
        if !response.status().is_success() {
            return json!({
                "success": false,
                "error": format!("HTTP {status}"),
                "status": status,
            });
        }

        let content_type = response
            .headers()
            .get("content-type")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
            .to_string();

        // Read body with size limit
        let bytes = match response.bytes().await {
            Ok(b) => b,
            Err(e) => {
                return json!({"success": false, "error": format!("Failed to read body: {e}")})
            }
        };

        if bytes.len() > MAX_RESPONSE_BYTES {
            return json!({
                "success": false,
                "error": format!("Response too large: {} bytes (max {})", bytes.len(), MAX_RESPONSE_BYTES),
            });
        }

        let body = String::from_utf8_lossy(&bytes);

        // Extract text based on content type
        let text =
            if content_type.contains("text/html") || content_type.contains("application/xhtml") {
                html_to_text(&body)
            } else {
                body.to_string()
            };

        // Truncate for LLM context budget
        let truncated = if text.len() > 32_000 {
            format!(
                "{}...\n\n[Truncated: {} total chars]",
                &text[..32_000],
                text.len()
            )
        } else {
            text
        };

        json!({
            "success": true,
            "url": url,
            "status": status,
            "content_type": content_type,
            "content": truncated,
            "bytes": bytes.len(),
        })
    }
}

#[async_trait::async_trait]
impl ToolHandler for WebFetchTool {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let url = input["url"].as_str().unwrap_or("");
        let result = self.fetch_url(url).await;
        Ok(serde_json::to_string(&result).unwrap_or_default())
    }
}

pub fn web_fetch_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "web_fetch".to_string(),
        description: "Fetch a web page and extract its text content. HTML is converted to clean readable text (scripts, styles, navigation stripped). Use for reading articles, documentation, or any web content.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "The URL to fetch (must be http:// or https://)."
                }
            },
            "required": ["url"],
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_redirect_target_reuses_ssrf_guard() {
        assert!(validate_redirect_target("https://example.com/docs").is_ok());
        assert!(validate_redirect_target("http://127.0.0.1/admin").is_err());
        assert!(validate_redirect_target("http://metadata.google/internal").is_err());
    }
}
