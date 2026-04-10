//! Structured error classification with recovery hints.
//!
//! Inspired by Hermes Agent's 7-type error classification pipeline.
//! Each agent error is classified into a category with actionable recovery hints:
//! retry, compress context, rotate credentials, fallback model, or give up.

use std::time::Duration;

use crate::agent_loop::AgentError;

/// Semantic error category — determines recovery strategy.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCategory {
    /// Transient network/rate limit — retry with backoff.
    Retryable,
    /// Context too large — compress and retry.
    ContextOverflow,
    /// API key invalid or expired — rotate credential.
    CredentialFailure,
    /// Model overloaded (529, 503) — fallback to different model.
    ModelOverloaded,
    /// Tool execution failed — retry with different args or skip tool.
    ToolFailure,
    /// Human approval needed — pause and wait.
    PermissionDenied,
    /// Unrecoverable — report to user and stop.
    Unrecoverable,
}

/// Classified error with recovery hints.
#[derive(Debug, Clone)]
pub struct ClassifiedError {
    pub category: ErrorCategory,
    pub recovery_hint: String,
    pub should_retry: bool,
    pub retry_delay: Option<Duration>,
    pub should_compress: bool,
    pub should_fallback: bool,
    pub should_rotate_credential: bool,
}

/// Classify an AgentError into a category with recovery hints.
pub fn classify(error: &AgentError) -> ClassifiedError {
    match error {
        AgentError::HttpError(msg) => classify_http_message(msg),

        AgentError::ApiError { status, body } => classify_api_error(*status, body),

        AgentError::StreamError(msg) => {
            if msg.contains("timeout") || msg.contains("timed out") {
                ClassifiedError {
                    category: ErrorCategory::Retryable,
                    recovery_hint: "Stream timed out — retry with longer timeout".into(),
                    should_retry: true,
                    retry_delay: Some(Duration::from_secs(2)),
                    should_compress: false,
                    should_fallback: false,
                    should_rotate_credential: false,
                }
            } else {
                ClassifiedError {
                    category: ErrorCategory::Retryable,
                    recovery_hint: format!("Stream error: {msg} — retrying"),
                    should_retry: true,
                    retry_delay: Some(Duration::from_secs(1)),
                    should_compress: false,
                    should_fallback: false,
                    should_rotate_credential: false,
                }
            }
        }

        AgentError::Provider(msg) => {
            if msg.contains("overloaded") || msg.contains("capacity") {
                ClassifiedError {
                    category: ErrorCategory::ModelOverloaded,
                    recovery_hint: "Provider overloaded — falling back to alternative model".into(),
                    should_retry: false,
                    retry_delay: None,
                    should_compress: false,
                    should_fallback: true,
                    should_rotate_credential: false,
                }
            } else {
                ClassifiedError {
                    category: ErrorCategory::Retryable,
                    recovery_hint: format!("Provider error: {msg} — retrying"),
                    should_retry: true,
                    retry_delay: Some(Duration::from_secs(3)),
                    should_compress: false,
                    should_fallback: false,
                    should_rotate_credential: false,
                }
            }
        }

        AgentError::ToolError { tool, message } => ClassifiedError {
            category: ErrorCategory::ToolFailure,
            recovery_hint: format!("Tool '{tool}' failed: {message} — skipping this tool call"),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::Vault(msg) => ClassifiedError {
            category: ErrorCategory::ToolFailure,
            recovery_hint: format!("Vault error: {msg} — continuing without vault context"),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::PermissionDenied(tool) => ClassifiedError {
            category: ErrorCategory::PermissionDenied,
            recovery_hint: format!("Permission denied for tool '{tool}' — waiting for approval"),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::CompactionFailed => ClassifiedError {
            category: ErrorCategory::ContextOverflow,
            recovery_hint: "Context compaction failed — try dropping older messages".into(),
            should_retry: true,
            retry_delay: None,
            should_compress: true,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::MaxTurnsExceeded(turns) => ClassifiedError {
            category: ErrorCategory::Unrecoverable,
            recovery_hint: format!("Exceeded {turns} turn limit — task may be too complex"),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::Serialization(_) | AgentError::InvalidConfig(_) => ClassifiedError {
            category: ErrorCategory::Unrecoverable,
            recovery_hint: "Configuration or serialization error — cannot recover".into(),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },

        AgentError::Cancelled => ClassifiedError {
            category: ErrorCategory::Unrecoverable,
            recovery_hint: "Session cancelled by user".into(),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },
    }
}

fn classify_http_message(msg: &str) -> ClassifiedError {
    if msg.contains("401") || msg.contains("403") || msg.contains("invalid_api_key") {
        ClassifiedError {
            category: ErrorCategory::CredentialFailure,
            recovery_hint: "API key invalid or expired — rotate to next credential".into(),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: true,
        }
    } else if msg.contains("429") {
        ClassifiedError {
            category: ErrorCategory::Retryable,
            recovery_hint: "Rate limited — retrying after delay".into(),
            should_retry: true,
            retry_delay: Some(Duration::from_secs(5)),
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        }
    } else {
        ClassifiedError {
            category: ErrorCategory::Retryable,
            recovery_hint: format!("HTTP error: {msg} — retrying"),
            should_retry: true,
            retry_delay: Some(Duration::from_secs(2)),
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        }
    }
}

fn classify_api_error(status: u16, body: &str) -> ClassifiedError {
    match status {
        401 | 403 => ClassifiedError {
            category: ErrorCategory::CredentialFailure,
            recovery_hint: "Authentication failed — rotate API key".into(),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: true,
        },
        429 => ClassifiedError {
            category: ErrorCategory::Retryable,
            recovery_hint: "Rate limited — backing off".into(),
            should_retry: true,
            retry_delay: Some(Duration::from_secs(10)),
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },
        529 | 503 => ClassifiedError {
            category: ErrorCategory::ModelOverloaded,
            recovery_hint: "Model overloaded — falling back to alternative".into(),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: true,
            should_rotate_credential: false,
        },
        413 => ClassifiedError {
            category: ErrorCategory::ContextOverflow,
            recovery_hint: "Request too large — compressing context".into(),
            should_retry: true,
            retry_delay: None,
            should_compress: true,
            should_fallback: false,
            should_rotate_credential: false,
        },
        400 if body.contains("context_length") || body.contains("too many tokens") => {
            ClassifiedError {
                category: ErrorCategory::ContextOverflow,
                recovery_hint: "Context window exceeded — compressing".into(),
                should_retry: true,
                retry_delay: None,
                should_compress: true,
                should_fallback: false,
                should_rotate_credential: false,
            }
        }
        _ => ClassifiedError {
            category: ErrorCategory::Unrecoverable,
            recovery_hint: format!("API error {status}: {}", &body[..body.len().min(200)]),
            should_retry: false,
            retry_delay: None,
            should_compress: false,
            should_fallback: false,
            should_rotate_credential: false,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rate_limit_is_retryable() {
        let error = AgentError::ApiError {
            status: 429,
            body: "rate limited".into(),
        };
        let classified = classify(&error);
        assert_eq!(classified.category, ErrorCategory::Retryable);
        assert!(classified.should_retry);
    }

    #[test]
    fn auth_failure_rotates_credential() {
        let error = AgentError::ApiError {
            status: 401,
            body: "invalid key".into(),
        };
        let classified = classify(&error);
        assert_eq!(classified.category, ErrorCategory::CredentialFailure);
        assert!(classified.should_rotate_credential);
        assert!(!classified.should_retry);
    }

    #[test]
    fn overloaded_falls_back() {
        let error = AgentError::ApiError {
            status: 529,
            body: "overloaded".into(),
        };
        let classified = classify(&error);
        assert_eq!(classified.category, ErrorCategory::ModelOverloaded);
        assert!(classified.should_fallback);
    }

    #[test]
    fn context_overflow_compresses() {
        let error = AgentError::ApiError {
            status: 400,
            body: "too many tokens in context_length".into(),
        };
        let classified = classify(&error);
        assert_eq!(classified.category, ErrorCategory::ContextOverflow);
        assert!(classified.should_compress);
        assert!(classified.should_retry);
    }

    #[test]
    fn tool_error_is_tool_failure() {
        let error = AgentError::ToolError {
            tool: "bash".into(),
            message: "command not found".into(),
        };
        let classified = classify(&error);
        assert_eq!(classified.category, ErrorCategory::ToolFailure);
        assert!(!classified.should_retry);
    }

    #[test]
    fn cancelled_is_unrecoverable() {
        let classified = classify(&AgentError::Cancelled);
        assert_eq!(classified.category, ErrorCategory::Unrecoverable);
    }
}
