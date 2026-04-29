//! Media Tools — Phase 6 Vision, Image Generation, and Text-to-Speech
//!
//! * `vision_analyze` — send an image (URL or local file) plus a question
//!   to a vision LLM (Claude / Gemini / GPT-4V) and return the analysis.
//! * `image_generate` — deferred from normal model-facing catalogs until a
//!   real local image lane is wired. The handler still exists for explicit
//!   manual use and requires a named `provider` (`"mlx"` or `"fal"`) so
//!   there is no silent routing or cloud escalation (PLAN_V2 §3.4).
//! * `text_to_speech` — synthesise audio from text via the macOS `say`
//!   command. Pure Rust, no cloud, no FFI callback.
//!
//! All cloud-backed tools read API keys from environment variables at call
//! time so credentials never cross the tool schema boundary.

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};
use crate::bridge::AgentEventDelegate;

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

crate::impl_tool_via_legacy_handler!(
    VisionAnalyzeHandler,
    name = "media.vision_analyze",
    input_schema = super::v2_catalog::media_vision_analyze::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

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
            "claude" => {
                claude_vision(
                    &self.client,
                    &data_url,
                    &media_type,
                    &question,
                    &source_label,
                )
                .await
            }
            "openai" | "gpt-4v" => {
                openai_vision(&self.client, &data_url, &question, &source_label).await
            }
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
    let image_block =
        if let Some(b64) = data_url.strip_prefix(&format!("data:{media_type};base64,")) {
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

// MARK: - image_generate (MLX-first; FAL is explicit remote opt-in)
//
// PLAN_V2 §5.1 places image generation in the MLX lane, and §16 requires
// a sidecar / sequential execution mode for the MLX image path. The
// handler dispatches on a **required** `provider` field — there is no
// default provider, and every caller MUST name its lane explicitly. This
// removes any form of silent routing (PLAN_V2 §3.4).
//
//   * `"mlx"` — route through `AgentEventDelegate::generate_image` so
//     the Swift-side MLX sidecar owns model loading and inference. When
//     the Swift sidecar is not yet configured (no Flux pipeline loaded),
//     the delegate returns an explicit error envelope and this handler
//     surfaces it as a tool error. This is an *honest runtime error* from
//     a real attempt to reach the sidecar — not a permanent stub.
//
//   * `"fal"` — explicit cloud opt-in. Hits `https://fal.run/fal-ai/flux/dev`
//     and requires `FAL_API_KEY`. Preserved unchanged for callers who
//     name this lane by name.
//
// The schema used to default to `"square"` aspect ratio and implicit FAL;
// `provider` is now required and unnamed calls are rejected. This is a
// deliberate, auditable behavior change required to make the code
// canonical with PLAN_V2 §5.1, §16, and §3.4 without shipping a stub path
// that could ever succeed by accident.

pub struct ImageGenerateHandler {
    client: Client,
    delegate: Option<Arc<dyn AgentEventDelegate>>,
}

crate::impl_tool_via_legacy_handler!(
    ImageGenerateHandler,
    name = "media.image_generate",
    input_schema = super::v2_catalog::media_image_generate::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

impl ImageGenerateHandler {
    /// Delegate-free constructor. Used by the pre-delegate registration
    /// pass and by pure-Rust unit tests. Without a delegate the MLX lane
    /// surfaces an explicit runtime error; the FAL lane still works with
    /// `FAL_API_KEY`.
    pub fn new() -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
            delegate: None,
        })
    }

    /// Delegate-aware constructor. Used by `register_delegate_tools` so
    /// the MLX lane can reach the Swift sidecar when it is wired.
    pub fn new_with_delegate(delegate: Arc<dyn AgentEventDelegate>) -> Result<Self, ToolError> {
        Ok(Self {
            client: build_client()?,
            delegate: Some(delegate),
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

        // Provider is required. No default: the caller MUST name the lane
        // explicitly so there is no silent routing (PLAN_V2 §3.4).
        let provider = input.get("provider").and_then(Value::as_str).ok_or_else(|| {
            ToolError::InvalidArguments(
                "missing 'provider' — image_generate requires an explicit \
                 lane. Pass `provider: \"mlx\"` for the Apple-native sidecar \
                 (PLAN_V2 §5.1 / §16) or `provider: \"fal\"` for the explicit \
                 cloud opt-in."
                    .into(),
            )
        })?;

        match provider.to_ascii_lowercase().as_str() {
            "mlx" => self.execute_mlx(prompt, aspect_ratio).await,
            "fal" => self.execute_fal(prompt, aspect_ratio).await,
            other => Err(ToolError::InvalidArguments(format!(
                "provider '{other}' invalid (expected mlx|fal)"
            ))),
        }
    }
}

impl ImageGenerateHandler {
    async fn execute_mlx(&self, prompt: &str, aspect_ratio: &str) -> Result<String, ToolError> {
        let Some(delegate) = self.delegate.clone() else {
            // No delegate — the Swift sidecar cannot be reached from this
            // handler instance. This is the honest "MLX not wired" state
            // and it must surface explicitly so callers can choose to
            // pass `provider: "fal"` instead. No silent escalation.
            return Err(ToolError::ExecutionFailed(
                "image_generate: MLX sidecar is unavailable in this context — \
                 pass `provider: \"fal\"` to use the explicit cloud path, or \
                 ensure the agent session was started with a delegate that \
                 implements `generate_image`"
                    .to_string(),
            ));
        };

        let prompt_owned = prompt.to_string();
        let aspect_owned = aspect_ratio.to_string();
        let result = tokio::task::spawn_blocking(move || {
            delegate.generate_image(prompt_owned, aspect_owned)
        })
        .await
        .map_err(|join_err| {
            ToolError::ExecutionFailed(format!(
                "image_generate: MLX delegate task failed: {join_err}"
            ))
        })?;

        // The delegate returns a JSON envelope. A success envelope carries
        // `image_url` or `image_path`; a failure envelope carries `error`.
        // Parse to detect error-path messages and surface them as tool
        // errors so the agent loop doesn't treat them as successes.
        let parsed: Value = serde_json::from_str(&result).map_err(|e| {
            ToolError::ExecutionFailed(format!(
                "image_generate: MLX delegate returned non-JSON: {e}: {result}"
            ))
        })?;
        if let Some(err_msg) = parsed.get("error").and_then(Value::as_str) {
            let hint = parsed
                .get("hint")
                .and_then(Value::as_str)
                .map(|h| format!(" — hint: {h}"))
                .unwrap_or_default();
            return Err(ToolError::ExecutionFailed(format!(
                "image_generate (mlx): {err_msg}{hint}"
            )));
        }
        // Inject canonical `provider` and `prompt` metadata if missing so
        // downstream consumers always see a consistent envelope.
        let mut envelope = parsed;
        if envelope.get("provider").is_none() {
            envelope["provider"] = json!("mlx");
        }
        if envelope.get("prompt").is_none() {
            envelope["prompt"] = json!(prompt);
        }
        if envelope.get("aspect_ratio").is_none() {
            envelope["aspect_ratio"] = json!(aspect_ratio);
        }
        Ok(envelope.to_string())
    }

    async fn execute_fal(&self, prompt: &str, aspect_ratio: &str) -> Result<String, ToolError> {
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
        description: "Generate an image from a text prompt. The `provider` \
             field is REQUIRED and has no default — every call must name \
             its lane explicitly (PLAN_V2 §3.4 no silent routing). Use \
             provider='mlx' for the Apple-native MLX sidecar lane (PLAN_V2 \
             §5.1 / §16); when the MLX Flux pipeline is not yet wired the \
             call will surface an explicit runtime error rather than \
             silently escalating to cloud. Use provider='fal' for the \
             explicit cloud opt-in (requires FAL_API_KEY). Aspect ratios: \
             landscape, portrait, square (defaults to square)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "prompt": { "type": "string" },
                "aspect_ratio": {
                    "type": "string",
                    "enum": ["landscape", "portrait", "square"],
                    "default": "square"
                },
                "provider": {
                    "type": "string",
                    "enum": ["mlx", "fal"],
                    "description": "mlx = Apple-native sidecar lane (PLAN_V2 §5.1 / §16); fal = explicit cloud opt-in. Required — no default."
                }
            },
            "required": ["prompt", "provider"]
        }),
    }
}

// MARK: - text_to_speech (macOS `say` subprocess)

pub struct TextToSpeechHandler;

crate::impl_tool_via_legacy_handler!(
    TextToSpeechHandler,
    name = "media.text_to_speech",
    input_schema = super::v2_catalog::media_text_to_speech::input_schema,
    profile = super::Profile::ProOnly,
    small_model_safe = false,
);

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
            return Err(ToolError::ExecutionFailed(format!("say failed: {stderr}")));
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
        let err = handler.execute(&json!({ "prompt": "" })).await.unwrap_err();
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
    async fn image_generate_requires_explicit_provider() {
        // PLAN_V2 §3.4: no silent routing. Every image_generate call must
        // name its lane explicitly. A missing provider is an invalid-
        // argument error, not a default-to-anything surprise. This test
        // pins the "no default" invariant — the Rust tool will never
        // decide the lane on the caller's behalf.
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "prompt": "a cat", "aspect_ratio": "square" }))
            .await
            .unwrap_err();
        let msg = format!("{err}");
        assert!(msg.contains("missing 'provider'"));
        assert!(msg.contains("provider: \"mlx\""));
        assert!(msg.contains("provider: \"fal\""));
    }

    #[tokio::test]
    async fn image_generate_mlx_without_delegate_surfaces_honest_runtime_error() {
        // When the caller names `mlx` explicitly but no delegate is
        // attached (e.g. pure-Rust test context, or Swift sidecar not yet
        // started), the handler attempts the MLX path and surfaces a
        // truthful runtime error pointing the caller at the explicit
        // FAL opt-in. This is NOT a permanent stub — when the Swift
        // sidecar IS attached, the same code path routes to
        // `delegate.generate_image` and returns whatever envelope the
        // sidecar produces. The failure below is contingent on missing
        // runtime state, not on a hardcoded flag.
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "prompt": "a cat",
                "aspect_ratio": "square",
                "provider": "mlx"
            }))
            .await
            .unwrap_err();
        let msg = format!("{err}");
        assert!(msg.contains("MLX sidecar is unavailable"));
        assert!(msg.contains("provider: \"fal\""));
    }

    #[tokio::test]
    async fn image_generate_rejects_unknown_provider() {
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "prompt": "a cat",
                "provider": "stable-diffusion"
            }))
            .await
            .unwrap_err();
        let msg = format!("{err}");
        assert!(msg.contains("provider"));
        assert!(msg.contains("mlx|fal"));
    }

    #[tokio::test]
    async fn image_generate_explicit_fal_requires_api_key() {
        // FAL is an explicit opt-in. When the user passes `provider: "fal"`
        // but there is no API key, the handler fails explicitly with the
        // FAL_API_KEY message — no silent fallback to MLX, no escalation.
        let saved = std::env::var("FAL_API_KEY").ok();
        std::env::remove_var("FAL_API_KEY");
        let handler = ImageGenerateHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "prompt": "a cat",
                "aspect_ratio": "square",
                "provider": "fal"
            }))
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
        let err = handler.execute(&json!({ "text": huge })).await.unwrap_err();
        assert!(format!("{err}").contains("char cap"));
    }
}
