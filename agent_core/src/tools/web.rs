//! Web Tools — Phase 3 Search, Extract, and Crawl
//!
//! * `web_search` — query Tavily, Brave, or Perplexity and return normalised
//!   search results. Backend selected automatically from env vars.
//! * `web_extract` — fetch one or more URLs and return clean readable text.
//! * `web_crawl`  — BFS crawl from a seed URL with depth and host constraints.
//!
//! Browser automation now lives in `browser.rs`, where the `browser_*`
//! handlers wrap the `agent-browser` CLI while these tools stay focused on
//! fetch/search/crawl-style HTTP work.

use std::collections::{HashSet, VecDeque};
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};
use super::web_fetch::{html_to_text, secure_redirect_policy, validate_url};

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_EXTRACT_URLS: usize = 10;
const MAX_CRAWL_PAGES: usize = 50;
const MAX_CRAWL_DEPTH: u32 = 3;
const MAX_EXTRACT_CONTENT_CHARS: usize = 32_000;

// MARK: - Shared HTTP client

fn build_client() -> Result<Client, ToolError> {
    Client::builder()
        .timeout(DEFAULT_TIMEOUT)
        .user_agent("Epistemos/1.0 (Knowledge Assistant)")
        .redirect(secure_redirect_policy())
        .build()
        .map_err(|e| ToolError::ExecutionFailed(format!("http client init: {e}")))
}

// MARK: - web_search

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SearchBackend {
    Tavily,
    Brave,
    Perplexity,
}

impl SearchBackend {
    fn as_str(self) -> &'static str {
        match self {
            Self::Tavily => "tavily",
            Self::Brave => "brave",
            Self::Perplexity => "perplexity",
        }
    }
}

fn detect_backend(explicit: Option<&str>) -> Result<(SearchBackend, String), ToolError> {
    if let Some(name) = explicit {
        return match name.to_ascii_lowercase().as_str() {
            "tavily" => std::env::var("TAVILY_API_KEY")
                .map(|k| (SearchBackend::Tavily, k))
                .map_err(|_| {
                    ToolError::ExecutionFailed(
                        "backend='tavily' but TAVILY_API_KEY is not set".into(),
                    )
                }),
            "brave" => std::env::var("BRAVE_API_KEY")
                .map(|k| (SearchBackend::Brave, k))
                .map_err(|_| {
                    ToolError::ExecutionFailed(
                        "backend='brave' but BRAVE_API_KEY is not set".into(),
                    )
                }),
            "perplexity" => std::env::var("PERPLEXITY_API_KEY")
                .map(|k| (SearchBackend::Perplexity, k))
                .map_err(|_| {
                    ToolError::ExecutionFailed(
                        "backend='perplexity' but PERPLEXITY_API_KEY is not set".into(),
                    )
                }),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown backend '{other}' (expected: tavily|brave|perplexity)"
            ))),
        };
    }

    // Auto-detect: prefer Tavily → Brave → Perplexity based on available keys.
    if let Ok(key) = std::env::var("TAVILY_API_KEY") {
        return Ok((SearchBackend::Tavily, key));
    }
    if let Ok(key) = std::env::var("BRAVE_API_KEY") {
        return Ok((SearchBackend::Brave, key));
    }
    if let Ok(key) = std::env::var("PERPLEXITY_API_KEY") {
        return Ok((SearchBackend::Perplexity, key));
    }
    Err(ToolError::ExecutionFailed(
        "no search backend available — set TAVILY_API_KEY, BRAVE_API_KEY, or PERPLEXITY_API_KEY"
            .into(),
    ))
}

pub struct WebSearchHandler {
    client: Client,
}

impl WebSearchHandler {
    pub fn new() -> Result<Self, ToolError> {
        let _ = detect_backend(None)?;
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for WebSearchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(5)
            .clamp(1, 20) as usize;
        let backend_override = input.get("backend").and_then(Value::as_str);

        let (backend, api_key) = detect_backend(backend_override)?;

        let raw = match backend {
            SearchBackend::Tavily => tavily_search(&self.client, query, limit, &api_key).await?,
            SearchBackend::Brave => brave_search(&self.client, query, limit, &api_key).await?,
            SearchBackend::Perplexity => {
                perplexity_search(&self.client, query, limit, &api_key).await?
            }
        };

        Ok(json!({
            "query": query,
            "backend": backend.as_str(),
            "count": raw.len(),
            "results": raw,
        })
        .to_string())
    }
}

async fn tavily_search(
    client: &Client,
    query: &str,
    limit: usize,
    api_key: &str,
) -> Result<Vec<Value>, ToolError> {
    let body = json!({
        "api_key": api_key,
        "query": query,
        "max_results": limit,
        "search_depth": "basic",
        "include_answer": false,
    });
    let resp = client
        .post("https://api.tavily.com/search")
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("tavily request: {e}")))?;
    if !resp.status().is_success() {
        let status = resp.status().as_u16();
        return Err(ToolError::ExecutionFailed(format!("tavily HTTP {status}")));
    }
    let body: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("tavily parse: {e}")))?;
    let hits = body
        .get("results")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    Ok(hits
        .into_iter()
        .enumerate()
        .take(limit)
        .map(|(i, r)| {
            json!({
                "url": r.get("url").and_then(Value::as_str).unwrap_or(""),
                "title": r.get("title").and_then(Value::as_str).unwrap_or(""),
                "description": r.get("content").and_then(Value::as_str).unwrap_or(""),
                "position": i + 1,
            })
        })
        .collect())
}

async fn brave_search(
    client: &Client,
    query: &str,
    limit: usize,
    api_key: &str,
) -> Result<Vec<Value>, ToolError> {
    let resp = client
        .get("https://api.search.brave.com/res/v1/web/search")
        .header("X-Subscription-Token", api_key)
        .header("Accept", "application/json")
        .query(&[("q", query), ("count", &limit.to_string())])
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("brave request: {e}")))?;
    if !resp.status().is_success() {
        let status = resp.status().as_u16();
        return Err(ToolError::ExecutionFailed(format!("brave HTTP {status}")));
    }
    let body: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("brave parse: {e}")))?;
    let hits = body
        .get("web")
        .and_then(|w| w.get("results"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    Ok(hits
        .into_iter()
        .enumerate()
        .take(limit)
        .map(|(i, r)| {
            json!({
                "url": r.get("url").and_then(Value::as_str).unwrap_or(""),
                "title": r.get("title").and_then(Value::as_str).unwrap_or(""),
                "description": r.get("description").and_then(Value::as_str).unwrap_or(""),
                "position": i + 1,
            })
        })
        .collect())
}

async fn perplexity_search(
    client: &Client,
    query: &str,
    limit: usize,
    api_key: &str,
) -> Result<Vec<Value>, ToolError> {
    // Perplexity doesn't have a plain search endpoint — we use the chat
    // completions endpoint with the sonar-small model and ask it to return
    // JSON-ish structured citations. This is a best-effort wrapper; the
    // response shape is less predictable than Tavily/Brave.
    let body = json!({
        "model": "sonar",
        "messages": [
            { "role": "system", "content": "You are a web search assistant. Return citations for the user's query as a JSON array under the key 'results' with fields url, title, description." },
            { "role": "user", "content": query }
        ],
        "max_tokens": 512,
    });
    let resp = client
        .post("https://api.perplexity.ai/chat/completions")
        .bearer_auth(api_key)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("perplexity request: {e}")))?;
    if !resp.status().is_success() {
        let status = resp.status().as_u16();
        return Err(ToolError::ExecutionFailed(format!(
            "perplexity HTTP {status}"
        )));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("perplexity parse: {e}")))?;

    // Perplexity returns citations under `citations` (an array of URLs) in
    // addition to the chat content. Merge both into a uniform result list.
    let citations = payload
        .get("citations")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let mut results: Vec<Value> = citations
        .iter()
        .enumerate()
        .take(limit)
        .map(|(i, cite)| {
            let url = cite.as_str().unwrap_or_default().to_string();
            json!({
                "url": url,
                "title": "",
                "description": "",
                "position": i + 1,
            })
        })
        .collect();
    // Try to parse a JSON-formatted chat content for extra metadata.
    if let Some(content) = payload
        .get("choices")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("message"))
        .and_then(|m| m.get("content"))
        .and_then(Value::as_str)
    {
        if let Ok(parsed) = serde_json::from_str::<Value>(content) {
            if let Some(arr) = parsed.get("results").and_then(Value::as_array) {
                for (i, item) in arr.iter().take(limit).enumerate() {
                    if let Some(existing) = results.get_mut(i) {
                        if let Some(title) = item.get("title").and_then(Value::as_str) {
                            existing["title"] = json!(title);
                        }
                        if let Some(desc) = item.get("description").and_then(Value::as_str) {
                            existing["description"] = json!(desc);
                        }
                    }
                }
            }
        }
    }
    Ok(results)
}

pub fn web_search_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "web_search".to_string(),
        description: "Search the web via Tavily, Brave, or Perplexity. Backend is selected from \
             environment variables (TAVILY_API_KEY / BRAVE_API_KEY / PERPLEXITY_API_KEY) or \
             via the 'backend' parameter. Returns normalised {url, title, description, position} \
             results."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "query": { "type": "string", "description": "Search query." },
                "limit": { "type": "integer", "default": 5, "minimum": 1, "maximum": 20 },
                "backend": {
                    "type": "string",
                    "enum": ["tavily", "brave", "perplexity"],
                    "description": "Optional explicit backend override."
                }
            },
            "required": ["query"]
        }),
    }
}

// MARK: - web_extract

pub struct WebExtractHandler {
    client: Client,
}

impl WebExtractHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for WebExtractHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let urls: Vec<String> = if let Some(single) = input.get("url").and_then(Value::as_str) {
            vec![single.to_string()]
        } else if let Some(arr) = input.get("urls").and_then(Value::as_array) {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        } else {
            return Err(ToolError::InvalidArguments(
                "provide 'url' (string) or 'urls' (array)".into(),
            ));
        };

        if urls.is_empty() {
            return Err(ToolError::InvalidArguments("no URLs provided".into()));
        }
        if urls.len() > MAX_EXTRACT_URLS {
            return Err(ToolError::InvalidArguments(format!(
                "at most {MAX_EXTRACT_URLS} URLs per call"
            )));
        }

        // Validate all URLs up front so one bad URL doesn't silently waste
        // bandwidth on the others.
        for url in &urls {
            validate_url(url).map_err(ToolError::ExecutionFailed)?;
        }

        // Fetch in parallel with futures::future::join_all.
        let futures = urls
            .iter()
            .map(|url| fetch_and_extract(&self.client, url.clone()));
        let results = futures::future::join_all(futures).await;

        let values: Vec<Value> = urls
            .iter()
            .zip(results)
            .map(|(url, res)| match res {
                Ok((title, content)) => json!({
                    "url": url,
                    "success": true,
                    "title": title,
                    "content": content,
                }),
                Err(err) => json!({
                    "url": url,
                    "success": false,
                    "error": err,
                }),
            })
            .collect();

        Ok(json!({
            "count": values.len(),
            "results": values,
        })
        .to_string())
    }
}

async fn fetch_and_extract(client: &Client, url: String) -> Result<(String, String), String> {
    let response = client
        .get(&url)
        .send()
        .await
        .map_err(|e| format!("fetch failed: {e}"))?;
    if !response.status().is_success() {
        return Err(format!("HTTP {}", response.status().as_u16()));
    }
    let body = response
        .text()
        .await
        .map_err(|e| format!("read body: {e}"))?;

    // Try to grab the <title> tag before stripping HTML.
    let title = extract_title(&body);

    // Extract the main content region: prefer <article>, then <main>, then
    // fall back to the full body. This avoids navigation chrome and footers.
    let main_region = extract_main_region(&body);
    let text = html_to_text(main_region.as_deref().unwrap_or(&body));

    let truncated = if text.chars().count() > MAX_EXTRACT_CONTENT_CHARS {
        let sliced: String = text.chars().take(MAX_EXTRACT_CONTENT_CHARS).collect();
        format!("{sliced}\n\n... [truncated]")
    } else {
        text
    };

    Ok((title, truncated))
}

/// Grab the text inside the first `<title>…</title>` tag.
fn extract_title(html: &str) -> String {
    let lower = html.to_ascii_lowercase();
    let Some(open) = lower.find("<title") else {
        return String::new();
    };
    let Some(open_close) = lower[open..].find('>') else {
        return String::new();
    };
    let start = open + open_close + 1;
    let Some(end_rel) = lower[start..].find("</title>") else {
        return String::new();
    };
    html[start..start + end_rel].trim().to_string()
}

/// Slice out the inner HTML of the first `<article>` or `<main>` element,
/// or return None if neither is present.
fn extract_main_region(html: &str) -> Option<String> {
    for tag in ["article", "main"] {
        let lower = html.to_ascii_lowercase();
        let open_tag = format!("<{tag}");
        let close_tag = format!("</{tag}>");
        if let Some(start_tag) = lower.find(&open_tag) {
            if let Some(gt) = lower[start_tag..].find('>') {
                let inner_start = start_tag + gt + 1;
                if let Some(end) = lower[inner_start..].find(&close_tag) {
                    return Some(html[inner_start..inner_start + end].to_string());
                }
            }
        }
    }
    None
}

pub fn web_extract_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "web_extract".to_string(),
        description: "Fetch one or more URLs and return clean readable text. Extracts the \
             `<article>` or `<main>` region when present, otherwise the full body. \
             HTML is stripped of scripts, styles, navigation, headers, and footers. \
             Accepts either 'url' (single string) or 'urls' (array, max 10)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": { "type": "string", "description": "Single URL to extract." },
                "urls": {
                    "type": "array",
                    "description": "Multiple URLs to fetch in parallel (max 10).",
                    "items": { "type": "string" }
                }
            }
        }),
    }
}

// MARK: - web_crawl

pub struct WebCrawlHandler {
    client: Client,
}

impl WebCrawlHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for WebCrawlHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let seed = input
            .get("url")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'url'".into()))?;
        validate_url(seed).map_err(ToolError::ExecutionFailed)?;
        let max_pages = input
            .get("max_pages")
            .and_then(Value::as_u64)
            .unwrap_or(10)
            .clamp(1, MAX_CRAWL_PAGES as u64) as usize;
        let max_depth = input
            .get("max_depth")
            .and_then(Value::as_u64)
            .unwrap_or(2)
            .clamp(1, MAX_CRAWL_DEPTH as u64) as u32;
        let same_host_only = input
            .get("same_host_only")
            .and_then(Value::as_bool)
            .unwrap_or(true);

        let seed_host = extract_host(seed).unwrap_or_default();

        let mut queue: VecDeque<(String, u32)> = VecDeque::new();
        queue.push_back((seed.to_string(), 0));

        let mut visited: HashSet<String> = HashSet::new();
        visited.insert(seed.to_string());

        let mut pages: Vec<Value> = Vec::new();

        while let Some((url, depth)) = queue.pop_front() {
            if pages.len() >= max_pages {
                break;
            }
            let fetch_result = self.client.get(&url).send().await;
            let body = match fetch_result {
                Ok(resp) if resp.status().is_success() => resp.text().await.unwrap_or_default(),
                Ok(resp) => {
                    pages.push(json!({
                        "url": url,
                        "depth": depth,
                        "success": false,
                        "error": format!("HTTP {}", resp.status().as_u16()),
                    }));
                    continue;
                }
                Err(e) => {
                    pages.push(json!({
                        "url": url,
                        "depth": depth,
                        "success": false,
                        "error": format!("fetch: {e}"),
                    }));
                    continue;
                }
            };

            let title = extract_title(&body);
            let main = extract_main_region(&body);
            let text = html_to_text(main.as_deref().unwrap_or(&body));
            let truncated = if text.chars().count() > 4_000 {
                let sliced: String = text.chars().take(4_000).collect();
                format!("{sliced}\n... [truncated]")
            } else {
                text
            };

            pages.push(json!({
                "url": url,
                "depth": depth,
                "success": true,
                "title": title,
                "snippet": truncated,
            }));

            if depth + 1 > max_depth {
                continue;
            }

            for link in extract_links(&body, &url) {
                if visited.contains(&link) {
                    continue;
                }
                if same_host_only {
                    let host = extract_host(&link).unwrap_or_default();
                    if host != seed_host {
                        continue;
                    }
                }
                if is_crate_web_private(&link) {
                    continue;
                }
                visited.insert(link.clone());
                queue.push_back((link, depth + 1));
                if visited.len() >= max_pages * 4 {
                    // Don't let the queue explode — cap discovery at 4x the
                    // max_pages budget.
                    break;
                }
            }
        }

        Ok(json!({
            "seed": seed,
            "visited": visited.len(),
            "crawled": pages.len(),
            "pages": pages,
        })
        .to_string())
    }
}

fn is_crate_web_private(url: &str) -> bool {
    super::web_fetch::is_private_url(url)
}

fn extract_host(url: &str) -> Option<String> {
    let without_scheme = url.split_once("://").map(|(_, rest)| rest).unwrap_or(url);
    let host = without_scheme
        .split('/')
        .next()
        .unwrap_or("")
        .split('?')
        .next()
        .unwrap_or("")
        .to_ascii_lowercase();
    if host.is_empty() {
        None
    } else {
        Some(host)
    }
}

fn extract_links(html: &str, base_url: &str) -> Vec<String> {
    // Simple regex-free scan for <a href="..."> attributes.
    let mut out = Vec::new();
    let lower = html.to_ascii_lowercase();
    let bytes = html.as_bytes();
    let mut idx = 0;
    while let Some(found) = lower[idx..].find("href=") {
        let pos = idx + found + 5;
        if pos >= bytes.len() {
            break;
        }
        let delim = bytes[pos] as char;
        let (start, end_delim) = if delim == '"' || delim == '\'' {
            (pos + 1, delim)
        } else {
            // Unquoted attribute — rare but handle it.
            (pos, ' ')
        };
        let rest = &html[start..];
        let end_rel = rest.find([end_delim, '>', '\n']).unwrap_or(rest.len());
        let raw = rest[..end_rel].trim();
        if !raw.is_empty() {
            if let Some(resolved) = resolve_link(raw, base_url) {
                out.push(resolved);
            }
        }
        idx = start + end_rel;
    }
    out
}

fn resolve_link(href: &str, base: &str) -> Option<String> {
    let trimmed = href.trim();
    if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("javascript:") {
        return None;
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        return Some(trimmed.to_string());
    }
    // Build an origin from the base URL and join.
    let scheme_split = base.split_once("://")?;
    let scheme = scheme_split.0;
    let rest = scheme_split.1;
    let host_end = rest.find('/').unwrap_or(rest.len());
    let host = &rest[..host_end];
    if let Some(rooted) = trimmed.strip_prefix('/') {
        return Some(format!("{scheme}://{host}/{rooted}"));
    }
    // Relative path: drop to the base's directory.
    let path = &rest[host_end..];
    let parent = path.rsplit_once('/').map(|(p, _)| p).unwrap_or("");
    Some(format!("{scheme}://{host}{parent}/{trimmed}"))
}

pub fn web_crawl_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "web_crawl".to_string(),
        description: "Breadth-first crawl from a seed URL. Follows same-host links by default, \
             configurable max_depth (1-3) and max_pages (1-50). Returns clean text snippets for \
             each page. Use 'same_host_only': false to allow cross-host links."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": { "type": "string", "description": "Seed URL to start crawling." },
                "max_pages": { "type": "integer", "default": 10, "minimum": 1, "maximum": 50 },
                "max_depth": { "type": "integer", "default": 2, "minimum": 1, "maximum": 3 },
                "same_host_only": { "type": "boolean", "default": true }
            },
            "required": ["url"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn extract_title_grabs_tag_contents() {
        let html = "<!DOCTYPE html><html><head><title>Hello World</title></head></html>";
        assert_eq!(extract_title(html), "Hello World");
    }

    #[test]
    fn extract_title_handles_missing_title() {
        assert_eq!(extract_title("<html></html>"), "");
    }

    #[test]
    fn extract_main_region_prefers_article() {
        let html = "<html><body><article>content here</article></body></html>";
        assert_eq!(extract_main_region(html), Some("content here".to_string()));
    }

    #[test]
    fn extract_main_region_falls_back_to_main() {
        let html = "<html><body><main>main content</main></body></html>";
        assert_eq!(extract_main_region(html), Some("main content".to_string()));
    }

    #[test]
    fn extract_main_region_returns_none_when_absent() {
        let html = "<html><body><div>plain div</div></body></html>";
        assert_eq!(extract_main_region(html), None);
    }

    #[test]
    fn extract_links_parses_href_attributes() {
        let html = r#"<html><body><a href="/about">About</a><a href='https://example.com'>ex</a></body></html>"#;
        let links = extract_links(html, "https://foo.com");
        assert!(links.contains(&"https://foo.com/about".to_string()));
        assert!(links.contains(&"https://example.com".to_string()));
    }

    #[test]
    fn extract_links_skips_fragments_and_js() {
        let html = r##"<a href="#top">Top</a><a href="javascript:void(0)">js</a>"##;
        let links = extract_links(html, "https://foo.com");
        assert!(links.is_empty());
    }

    #[test]
    fn resolve_link_handles_absolute_relative_and_rooted() {
        let base = "https://foo.com/docs/page.html";
        assert_eq!(
            resolve_link("https://other.com/a", base),
            Some("https://other.com/a".to_string())
        );
        assert_eq!(
            resolve_link("/rooted", base),
            Some("https://foo.com/rooted".to_string())
        );
        assert_eq!(
            resolve_link("sibling.html", base),
            Some("https://foo.com/docs/sibling.html".to_string())
        );
    }

    #[test]
    fn extract_host_parses_scheme_and_host() {
        assert_eq!(
            extract_host("https://foo.com/bar"),
            Some("foo.com".to_string())
        );
        assert_eq!(
            extract_host("http://example.org:8080/path"),
            Some("example.org:8080".to_string())
        );
    }

    #[test]
    fn detect_backend_errors_without_env() {
        // Temporarily clear env vars so the auto-detection path errors cleanly.
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        let saved_brave = std::env::var("BRAVE_API_KEY").ok();
        let saved_pplx = std::env::var("PERPLEXITY_API_KEY").ok();
        std::env::remove_var("TAVILY_API_KEY");
        std::env::remove_var("BRAVE_API_KEY");
        std::env::remove_var("PERPLEXITY_API_KEY");

        let result = detect_backend(None);
        assert!(result.is_err());

        if let Some(v) = saved_tavily {
            std::env::set_var("TAVILY_API_KEY", v);
        }
        if let Some(v) = saved_brave {
            std::env::set_var("BRAVE_API_KEY", v);
        }
        if let Some(v) = saved_pplx {
            std::env::set_var("PERPLEXITY_API_KEY", v);
        }
    }

    #[tokio::test]
    async fn web_search_fails_without_backend() {
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        let saved_brave = std::env::var("BRAVE_API_KEY").ok();
        let saved_pplx = std::env::var("PERPLEXITY_API_KEY").ok();
        std::env::remove_var("TAVILY_API_KEY");
        std::env::remove_var("BRAVE_API_KEY");
        std::env::remove_var("PERPLEXITY_API_KEY");

        let err = match WebSearchHandler::new() {
            Ok(_) => {
                panic!("expected WebSearchHandler::new() to fail without a configured backend")
            }
            Err(error) => error,
        };
        assert!(format!("{err}").contains("no search backend"));

        if let Some(v) = saved_tavily {
            std::env::set_var("TAVILY_API_KEY", v);
        }
        if let Some(v) = saved_brave {
            std::env::set_var("BRAVE_API_KEY", v);
        }
        if let Some(v) = saved_pplx {
            std::env::set_var("PERPLEXITY_API_KEY", v);
        }
    }

    #[tokio::test]
    async fn web_extract_rejects_too_many_urls() {
        let handler = WebExtractHandler::new().unwrap();
        let urls: Vec<_> = (0..15)
            .map(|i| format!("https://example.com/{i}"))
            .collect();
        let err = handler.execute(&json!({ "urls": urls })).await.unwrap_err();
        assert!(format!("{err}").contains("at most"));
    }

    #[tokio::test]
    async fn web_extract_rejects_private_urls() {
        let handler = WebExtractHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "url": "http://127.0.0.1/" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("private"));
    }

    #[tokio::test]
    async fn web_crawl_rejects_private_seed() {
        let handler = WebCrawlHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "url": "http://localhost/" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("private"));
    }

    #[tokio::test]
    async fn web_crawl_rejects_missing_url() {
        let handler = WebCrawlHandler::new().unwrap();
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("'url'"));
    }
}
