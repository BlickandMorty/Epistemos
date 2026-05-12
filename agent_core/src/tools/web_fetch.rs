//! Web Fetch Tool — HTTP GET with HTML-to-text extraction
//!
//! Fetches a URL and extracts readable text content, stripping HTML tags,
//! scripts, styles, and navigation. Returns clean text for LLM consumption.
//!
//! Security: SSRF protection (blocks private IPs), URL validation,
//! response size limits, timeout enforcement.

use std::net::IpAddr;
use std::time::Duration;

use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const MAX_RESPONSE_BYTES: usize = 512 * 1024; // 512KB
const MAX_CONTENT_CHARS: usize = 32_000;
const MAX_URL_CHARS: usize = 4096;
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_REDIRECT_HOPS: usize = 5;

// MARK: - SSRF Protection

/// Returns true when the URL targets a private / internal address. Exposed
/// so the Phase 3 web tools can share the same blocklist without duplicating
/// the constants.
pub(crate) fn is_private_url(url: &str) -> bool {
    let Ok(parsed) = reqwest::Url::parse(url.trim()) else {
        return false;
    };
    let Some(host) = parsed.host_str() else {
        return false;
    };
    let lower = host.to_ascii_lowercase();
    if lower == "localhost"
        || lower.ends_with(".localhost")
        || lower == "metadata.google"
        || lower.ends_with(".metadata.google")
        || lower == "metadata.aws"
        || lower.ends_with(".metadata.aws")
    {
        return true;
    }
    host.trim_matches(['[', ']'])
        .parse::<IpAddr>()
        .is_ok_and(is_private_ip)
}

fn is_private_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => {
            ip.is_private() || ip.is_loopback() || ip.is_link_local() || ip.is_unspecified()
        }
        IpAddr::V6(ip) => {
            ip.is_loopback()
                || ip.is_unspecified()
                || ip.is_unique_local()
                || ip.is_unicast_link_local()
        }
    }
}

pub(crate) fn validate_url(url: &str) -> Result<(), String> {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return Err("URL is required.".to_string());
    }
    if trimmed.chars().count() > MAX_URL_CHARS {
        return Err(format!("URL is too long (max {MAX_URL_CHARS} chars)."));
    }
    if trimmed != url {
        return Err("URL cannot contain leading or trailing whitespace.".to_string());
    }
    let parsed = reqwest::Url::parse(trimmed)
        .map_err(|_| "URL must be a valid http:// or https:// URL.".to_string())?;
    if !matches!(parsed.scheme(), "http" | "https") {
        return Err("URL must start with http:// or https://".to_string());
    }
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err("URLs with embedded credentials are not allowed.".to_string());
    }
    if parsed.host_str().is_none() {
        return Err("URL must include a host.".to_string());
    }
    if is_private_url(trimmed) {
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

pub(crate) async fn read_response_text_limited(
    response: reqwest::Response,
    max_bytes: usize,
) -> Result<(String, usize), String> {
    let bytes = response
        .bytes()
        .await
        .map_err(|_| "read body failed".to_string())?;
    if bytes.len() > max_bytes {
        return Err(format!(
            "response too large: {} bytes (max {max_bytes})",
            bytes.len()
        ));
    }
    let len = bytes.len();
    Ok((String::from_utf8_lossy(&bytes).to_string(), len))
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

fn truncate_content(text: &str) -> String {
    if text.chars().count() <= MAX_CONTENT_CHARS {
        return text.to_string();
    }
    let sliced: String = text.chars().take(MAX_CONTENT_CHARS).collect();
    format!(
        "{sliced}...\n\n[Truncated: {} total chars]",
        text.chars().count()
    )
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
            Err(_) => return json!({"success": false, "error": "Request failed"}),
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

        let (body, bytes_len) = match read_response_text_limited(response, MAX_RESPONSE_BYTES).await
        {
            Ok(body) => body,
            Err(error) => return json!({"success": false, "error": error}),
        };

        // Extract text based on content type
        let text =
            if content_type.contains("text/html") || content_type.contains("application/xhtml") {
                html_to_text(&body)
            } else {
                body
            };

        // Truncate for LLM context budget without slicing through UTF-8.
        let truncated = truncate_content(&text);

        json!({
            "success": true,
            "url": url,
            "status": status,
            "content_type": content_type,
            "content": truncated,
            "bytes": bytes_len,
        })
    }
}

#[async_trait::async_trait]
impl ToolHandler for WebFetchTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let url = input
            .get("url")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'url'".into()))?;
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

    #[test]
    fn validate_url_rejects_private_ipv6_and_embedded_credentials() {
        assert!(validate_url("http://[::1]/admin").is_err());
        assert!(validate_url("http://[fc00::1]/admin").is_err());
        assert!(validate_url("https://user:pass@example.com/docs").is_err());
        assert!(validate_url(" https://example.com/docs").is_err());
    }

    #[test]
    fn is_private_url_detects_literal_and_local_hosts() {
        assert!(is_private_url("http://10.0.0.5/"));
        assert!(is_private_url("http://service.localhost/"));
        assert!(is_private_url("http://169.254.169.254/latest/meta-data"));
        assert!(!is_private_url("https://example.com/"));
    }

    #[tokio::test]
    async fn web_fetch_rejects_missing_or_non_string_url_as_arguments() {
        let tool = WebFetchTool::new();
        let missing = tool.execute(&json!({})).await.unwrap_err();
        assert!(format!("{missing}").contains("'url'"));

        let non_string = tool.execute(&json!({ "url": 42 })).await.unwrap_err();
        assert!(format!("{non_string}").contains("'url'"));
    }

    #[test]
    fn truncate_content_preserves_utf8_boundaries() {
        let text = "é".repeat(MAX_CONTENT_CHARS + 1);
        let truncated = truncate_content(&text);
        assert!(truncated.contains("[Truncated:"));
        assert!(truncated.starts_with('é'));
    }
}
