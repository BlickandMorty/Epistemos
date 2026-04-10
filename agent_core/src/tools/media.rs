//! Media Tools — Phase 6 Vision, Image Generation, and Text-to-Speech
//!
//! * `vision_analyze` — send an image (URL or local file) plus a question
//!   to a vision LLM (Claude / Gemini / GPT-4V) and return the analysis.
//! * `image_generate` — text-to-image via FAL.ai (flux pro / dev) with
//!   aspect-ratio control.
//! * `text_to_speech` — synthesise audio from text via the macOS `say`
//!   command. Pure Rust, no cloud, no FFI callback.
//!
//! All cloud-backed tools read API keys from environment variables at call
//! time so credentials never cross the tool schema boundary.

use std::path::PathBuf;
use std::time::Duration;

use async_trait::async_trait;
use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);
const MAX_IMAGE_BYTES: usize = 20 * 1024 * 1024; // 20MB cap for base64 encoding
const MAX_TTS_CHARS: usize = 8_000;

fn build_client() -> Result<Client, ToolError> {
    Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .user_agent("Epistemos/1.0 (Media)")
        .build()
        .map_err(|e| ToolError::ExecutionFailed(format!("http client init: {e}")))
}

// MARK: - vision_analyze

pub struct VisionAnalyzeHandler {
    client: Client,
}

impl VisionAnalyzeHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for VisionAnalyzeHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let image_url = input.get("image_url").and_then(Value::as_str);
        let image_path = input.get("image_path").and_then(Value::as_str);
        let question = input
            .get("question")
            .and_then(Value::as_str)
            .unwrap_or("Describe this image in detail.")
            .to_string();
        let provider = input
            .get("provider")
            .and_then(Value::as_str)
            .unwrap_or("claude");

        if image_url.is_none() && image_path.is_none() {
            return Err(ToolError::InvalidArguments(
                "provide either 'image_url' or 'image_path'".into(),
            ));
        }

        // Encode the image as base64 if a local path was given.
        let (data_url, media_type, source_label) = if let Some(path) = image_path {
            let resolved = resolve_path(path)?;
            let bytes = std::fs::read(&resolved).map_err(|e| {
                ToolError::ExecutionFailed(format!("read image '{}': {e}", resolved.display()))
            })?;
            if bytes.len() > MAX_IMAGE_BYTES {
                return Err(ToolError::ExecutionFailed(format!(
                    "image too large ({} bytes, cap {MAX_IMAGE_BYTES})",
                    bytes.len()
                )));
            }
            let mt = guess_media_type(&resolved);
            let encoded = B64.encode(&bytes);
            (
                format!("data:{mt};base64,{encoded}"),
                mt.to_string(),
                resolved.display().to_string(),
            )
        } else {
            let url = image_url.unwrap().to_string();
            let mt = guess_media_type(std::path::Path::new(&url));
            (url.clone(), mt.to_string(), url)
        };

        match provider.to_ascii_lowercase().as_str() {
            "claude" => claude_vision(&self.client, &data_url, &media_type, &question, &source_label).await,
            "openai" | "gpt-4v" => openai_vision(&self.client, &data_url, &question, &source_label).await,
            other => Err(ToolError::InvalidArguments(format!(
                "provider '{other}' invalid (expected claude|openai|gpt-4v)"
            ))),
        }
    }
}

fn resolve_path(path: &str) -> Result<PathBuf, ToolError> {
    if path.is_empty() {
        return Err(ToolError::InvalidArguments("empty path".into()));
    }
    let expanded = if let Some(rest) = path.strip_prefix("~/") {
        dirs::home_dir()
            .map(|h| h.join(rest))
            .unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    };
    Ok(expanded)
}

fn guess_media_type(path: &std::path::Path) -> &'static str {
    match path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_ascii_lowercase())
        .as_deref()
    {
        Some("png") => "image/png",
        Some("jpg") | Some("jpeg") => "image/jpeg",
        Some("gif") => "image/gif",
        Some("webp") => "image/webp",
        _ => "image/jpeg",
    }
}

async fn claude_vision(
    client: &Client,
    data_url: &str,
    media_type: &str,
    question: &str,
    source_label: &str,
) -> Result<String, ToolError> {
    let api_key = std::env::var("ANTHROPIC_API_KEY")
        .map_err(|_| ToolError::ExecutionFailed("ANTHROPIC_API_KEY not set".into()))?;

    // For data URLs we must pass base64 via the dedicated source type.
    let image_block = if let Some(b64) = data_url.strip_prefix(&format!("data:{media_type};base64,")) {
        json!({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": b64,
            }
        })
    } else {
        json!({
            "type": "image",
            "source": {
                "type": "url",
                "url": data_url,
            }
        })
    };

    let body = json!({
        "model": "claude-sonnet-4-6",
        "max_tokens": 1024,
        "messages": [{
            "role": "user",
            "content": [
                image_block,
                { "type": "text", "text": question },
            ]
        }],
    });

    let resp = client
        .post("https://api.anthropic.com/v1/messages")
        .header("x-api-key", api_key)
        .header("anthropic-version", "2023-06-01")
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("claude vision request: {e}")))?;
    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "claude vision HTTP {status}: {text}"
        )));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("claude vision parse: {e}")))?;

    // Concatenate every text content block in the response.
    let analysis = payload
        .get("content")
        .and_then(Value::as_array)
        .map(|blocks| {
            blocks
                .iter()
                .filter_map(|b| b.get("text").and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default();

    Ok(json!({
        "provider": "claude",
        "model": "claude-sonnet-4-6",
        "source": source_label,
        "question": question,
        "analysis": analysis,
    })
    .to_string())
}

async fn openai_vision(
    client: &Client,
    data_url: &str,
    question: &str,
    source_label: &str,
) -> Result<String, ToolError> {
    let api_key = std::env::var("OPENAI_API_KEY")
        .map_err(|_| ToolError::ExecutionFailed("OPENAI_API_KEY not set".into()))?;

    let body = json!({
        "model": "gpt-4o",
        "max_tokens": 1024,
        "messages": [{
            "role": "user",
            "content": [
                { "type": "text", "text": question },
                { "type": "image_url", "image_url": { "url": data_url } }
            ]
        }],
    });

    let resp = client
        .post("https://api.openai.com/v1/chat/completions")
        .bearer_auth(api_key)
        .json(&body)
        .send()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("openai vision request: {e}")))?;
    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ToolError::ExecutionFailed(format!(
            "openai vision HTTP {status}: {text}"
        )));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("openai vision parse: {e}")))?;
    let analysis = payload
        .get("choices")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("message"))
        .and_then(|m| m.get("content"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();

    Ok(json!({
        "provider": "openai",
        "model": "gpt-4o",
        "source": source_label,
        "question": question,
        "analysis": analysis,
    })
    .to_string())
}

pub fn vision_analyze_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "vision_analyze".to_string(),
        description: "Analyze an image (URL or local file) with a vision LLM. Supports \
             provider='claude' (default, uses ANTHROPIC_API_KEY) or 'openai' (uses \
             OPENAI_API_KEY with gpt-4o). Local files are base64-encoded in-process; 20MB cap."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "image_url": { "type": "string", "description": "Public URL to the image." },
                "image_path": { "type": "string", "description": "Local path (supports ~/)." },
                "question": { "type": "string", "description": "What to ask about the image.", "default": "Describe this image in detail." },
                "provider": { "type": "string", "enum": ["claude", "openai", "gpt-4v"], "default": "claude" }
            }
        }),
    }
}

// MARK: - image_generate

pub struct ImageGenerateHandler {
    client: Client,
}

impl ImageGenerateHandler {
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
        })
    }
}

#[async_trait]
impl ToolHandler for ImageGenerateHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let prompt = input
            .get("prompt")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'prompt'".into()))?;
        if prompt.is_empty() {
            return Err(ToolError::InvalidArguments("prompt cannot be empty".into()));
        }
        let aspect_ratio = input
            .get("aspect_ratio")
            .and_then(Value::as_str)
            .unwrap_or("square");
        if !matches!(aspect_ratio, "landscape" | "portrait" | "square") {
            return Err(ToolError::InvalidArguments(format!(
                "aspect_ratio '{aspect_ratio}' invalid (expected landscape|portrait|square)"
            )));
        }

        let api_key = std::env::var("FAL_API_KEY")
            .map_err(|_| ToolError::ExecutionFailed("FAL_API_KEY not set".into()))?;

        let image_size = match aspect_ratio {
            "landscape" => "landscape_16_9",
            "portrait" => "portrait_9_16",
            _ => "square_hd",
        };

        let body = json!({
            "prompt": prompt,
            "image_size": image_size,
            "num_images": 1,
        });

        let resp = self
            .client
            .post("https://fal.run/fal-ai/flux/dev")
            .header("Authorization", format!("Key {api_key}"))
            .json(&body)
            .send()
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("fal request: {e}")))?;
        let status = resp.status().as_u16();
        if !resp.status().is_success() {
            let text = resp.text().await.unwrap_or_default();
            return Err(ToolError::ExecutionFailed(format!(
                "fal HTTP {status}: {text}"
            )));
        }
        let payload: Value = resp
            .json()
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("fal parse: {e}")))?;

        let image_url = payload
            .get("images")
            .and_then(|i| i.get(0))
            .and_then(|img| img.get("url"))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();

        if image_url.is_empty() {
            return Err(ToolError::ExecutionFailed(format!(
                "fal returned no image url (payload: {payload})"
            )));
        }

        Ok(json!({
            "provider": "fal",
            "model": "flux/dev",
            "prompt": prompt,
            "aspect_ratio": aspect_ratio,
            "image_url": image_url,
        })
        .to_string())
    }
}

pub fn image_generate_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "image_generate".to_string(),
        description: "Generate an image from a text prompt via FAL.ai (Flux Dev model). \
             Requires FAL_API_KEY. Returns a URL to the hosted image. Aspect ratios: \
             landscape, portrait, square."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "prompt": { "type": "string" },
                "aspect_ratio": {
                    "type": "string",
                    "enum": ["landscape", "portrait", "square"],
                    "default": "square"
                }
            },
            "required": ["prompt"]
        }),
    }
}

// MARK: - text_to_speech (macOS `say` subprocess)

pub struct TextToSpeechHandler;

#[async_trait]
impl ToolHandler for TextToSpeechHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let text = input
            .get("text")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'text'".into()))?
            .to_string();
        if text.is_empty() {
            return Err(ToolError::InvalidArguments("text cannot be empty".into()));
        }
        if text.len() > MAX_TTS_CHARS {
            return Err(ToolError::InvalidArguments(format!(
                "text exceeds {MAX_TTS_CHARS} char cap"
            )));
        }
        let voice = input.get("voice").and_then(Value::as_str);
        let rate = input.get("rate").and_then(Value::as_u64);
        let output_path = input.get("output_path").and_then(Value::as_str);

        let mut cmd = tokio::process::Command::new("say");
        if let Some(v) = voice {
            cmd.arg("-v").arg(v);
        }
        if let Some(r) = rate {
            cmd.arg("-r").arg(r.to_string());
        }
        if let Some(path) = output_path {
            let resolved = resolve_path(path)?;
            cmd.arg("-o").arg(&resolved);
        }
        cmd.arg(&text);

        let output = tokio::time::timeout(REQUEST_TIMEOUT, cmd.output())
            .await
            .map_err(|_| ToolError::ExecutionFailed("say timed out after 60s".into()))?
            .map_err(|e| ToolError::ExecutionFailed(format!("say spawn failed: {e}")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
            return Err(ToolError::ExecutionFailed(format!(
                "say failed: {stderr}"
            )));
        }

        Ok(json!({
            "success": true,
            "provider": "macos_say",
            "text_chars": text.len(),
            "voice": voice,
            "rate": rate,
            "output_path": output_path,
        })
        .to_string())
    }
}

pub fn text_to_speech_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "text_to_speech".to_string(),
        description: "Speak text aloud via the macOS `say` command, or render to an audio file. \
             Optional voice (e.g., 'Samantha', 'Alex', 'Ava'), rate (words per minute), and \
             output_path. When no output_path is set the audio plays immediately. No cloud, \
             no FFI — pure subprocess. 8,000 char cap."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "text": { "type": "string" },
                "voice": { "type": "string", "description": "macOS voice name." },
                "rate": { "type": "integer", "description": "Words per minute (default ~175)." },
                "output_path": { "type": "string", "description": "Optional audio file path. Omit to play live." }
            },
            "required": ["text"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn media_type_inference_matches_extension() {
        assert_eq!(
            guess_media_type(std::path::Path::new("foo.png")),
            "image/png"
        );
        assert_eq!(
            guess_media_type(std::path::Path::new("foo.JPG")),
            "image/jpeg"
        );
        assert_eq!(
            guess_media_type(std::path::Path::new("foo.webp")),
            "image/webp"
        );
        // Default to jpeg for unknown/no extension.
        assert_eq!(
            guess_media_type(std::path::Path::new("noext")),
            "image/jpeg"
        );
    }

    #[tokio::test]
    async fn vision_analyze_requires_url_or_path() {
        let handler = VisionAnalyzeHandler::new().unwrap();
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("image_url"));
    }

    #[tokio::test]
    async fn vision_analyze_rejects_missing_file() {
        let handler = VisionAnalyzeHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "image_path": "/tmp/definitely-not-here-xyz123.png",
                "question": "what is this?"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("read image"));
    }

    #[tokio::test]
    async fn vision_analyze_rejects_unknown_provider() {
        let handler = VisionAnalyzeHandler::new().unwrap();
        // Use a public image URL so we get past the load step and hit the
        // provider dispatch.
        let err = handler
            .execute(&json!({
                "image_url": "https://example.com/image.jpg",
                "provider": "psychic"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("provider"));
    }

    #[tokio::test]
    async fn image_generate_rejects_empty_prompt() {
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "prompt": "" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("empty"));
    }

    #[tokio::test]
    async fn image_generate_rejects_unknown_aspect_ratio() {
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "prompt": "a cat",
                "aspect_ratio": "panoramic"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("aspect_ratio"));
    }

    #[tokio::test]
    async fn image_generate_requires_api_key() {
        let saved = std::env::var("FAL_API_KEY").ok();
        std::env::remove_var("FAL_API_KEY");
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "prompt": "a cat", "aspect_ratio": "square" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("FAL_API_KEY"));
        if let Some(v) = saved {
            std::env::set_var("FAL_API_KEY", v);
        }
    }

    #[tokio::test]
    async fn text_to_speech_rejects_empty_text() {
        let handler = TextToSpeechHandler;
        let err = handler.execute(&json!({ "text": "" })).await.unwrap_err();
        assert!(format!("{err}").contains("empty"));
    }

    #[tokio::test]
    async fn text_to_speech_rejects_oversized_text() {
        let handler = TextToSpeechHandler;
        let huge = "x".repeat(MAX_TTS_CHARS + 1);
        let err = handler
            .execute(&json!({ "text": huge }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("char cap"));
    }
}
