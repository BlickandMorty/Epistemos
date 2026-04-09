//! Error Classifier — Hermes-parity error taxonomy
//!
//! Reference: Hermes `agent/error_classifier.py`
//! Classifies API errors into actionable categories to drive retry, failover,
//! compression, and credential rotation decisions.

/// All known failure reasons, aligned with Hermes FailoverReason enum.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FailoverReason {
    /// Invalid or expired API key.
    Auth,
    /// Permanently revoked credentials (e.g., account banned).
    AuthPermanent,
    /// Billing exhaustion — credits/quota depleted (non-retryable).
    Billing,
    /// Per-minute/hour rate limit hit (retryable with backoff).
    RateLimit,
    /// Provider server is overloaded (503, "overloaded").
    Overloaded,
    /// Generic server error (500, 502).
    ServerError,
    /// Request or stream timed out.
    Timeout,
    /// Context window exceeded.
    ContextOverflow,
    /// Request body too large (413).
    PayloadTooLarge,
    /// Requested model does not exist.
    ModelNotFound,
    /// Malformed request (bad JSON, missing fields).
    FormatError,
    /// Anthropic thinking block signature became invalid.
    ThinkingSignature,
    /// Anthropic long-context tier gate (need higher usage tier).
    LongContextTier,
    /// Catch-all for unrecognized errors.
    Unknown,
}

impl FailoverReason {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Auth => "auth",
            Self::AuthPermanent => "auth_permanent",
            Self::Billing => "billing",
            Self::RateLimit => "rate_limit",
            Self::Overloaded => "overloaded",
            Self::ServerError => "server_error",
            Self::Timeout => "timeout",
            Self::ContextOverflow => "context_overflow",
            Self::PayloadTooLarge => "payload_too_large",
            Self::ModelNotFound => "model_not_found",
            Self::FormatError => "format_error",
            Self::ThinkingSignature => "thinking_signature",
            Self::LongContextTier => "long_context_tier",
            Self::Unknown => "unknown",
        }
    }
}

/// Classification result with actionable flags.
#[derive(Debug, Clone)]
pub struct ClassifiedError {
    pub reason: FailoverReason,
    pub status_code: Option<u16>,
    pub provider: String,
    pub message: String,
    /// Whether this error is worth retrying (with backoff).
    pub retryable: bool,
    /// Whether context compaction should be attempted before retry.
    pub should_compress: bool,
    /// Whether the current credential should be rotated out.
    pub should_rotate_credential: bool,
    /// Whether to try a different provider entirely.
    pub should_fallback: bool,
}

/// Billing-related patterns in error messages.
const BILLING_PATTERNS: &[&str] = &[
    "insufficient credits",
    "credits exhausted",
    "top up your credits",
    "account deactivated",
    "billing",
    "payment required",
    "quota exceeded",
    "spending limit",
];

/// Transient usage-limit signals (rate limit, not billing).
const USAGE_LIMIT_TRANSIENT: &[&str] = &[
    "try again",
    "retry",
    "resets at",
    "periodic",
    "window",
    "requests remaining",
    "rate limit",
    "too many requests",
];

/// Classify an API error into an actionable category.
///
/// The classification pipeline mirrors Hermes error_classifier.py:
/// 1. Provider-specific patterns (thinking_signature, long_context_tier)
/// 2. HTTP status code + message-aware refinement
/// 3. Message pattern matching
/// 4. Context overflow heuristics for large sessions
/// 5. Fallback: Unknown
pub fn classify_error(
    status_code: Option<u16>,
    error_message: &str,
    provider: &str,
    session_token_estimate: usize,
    session_message_count: usize,
) -> ClassifiedError {
    let msg_lower = error_message.to_lowercase();

    // 1. Provider-specific patterns
    if let Some(classified) = classify_provider_specific(&msg_lower, status_code, provider) {
        return classified;
    }

    // 2. HTTP status code classification
    if let Some(status) = status_code {
        return classify_by_status(status, &msg_lower, provider, session_token_estimate, session_message_count);
    }

    // 3. Transport/timeout heuristics
    if msg_lower.contains("timeout") || msg_lower.contains("timed out") || msg_lower.contains("deadline") {
        return make_classified(FailoverReason::Timeout, status_code, provider, error_message, true, false, false, true);
    }

    // 4. Server disconnect + large session → context_overflow heuristic
    if is_large_session(session_token_estimate, session_message_count, 0.6) {
        return make_classified(FailoverReason::ContextOverflow, status_code, provider, error_message, true, true, false, false);
    }

    // 5. Fallback
    make_classified(FailoverReason::Unknown, status_code, provider, error_message, false, false, false, true)
}

fn classify_provider_specific(msg: &str, status: Option<u16>, provider: &str) -> Option<ClassifiedError> {
    // Anthropic: thinking block signature invalid
    if status == Some(400) && msg.contains("signature") && msg.contains("thinking") {
        return Some(make_classified(
            FailoverReason::ThinkingSignature, status, provider,
            "Thinking block signature invalid — retry without cache",
            true, false, false, false,
        ));
    }

    // Anthropic: long-context tier gate
    if status == Some(429) && msg.contains("extra usage") && msg.contains("long context") {
        return Some(make_classified(
            FailoverReason::LongContextTier, status, provider,
            "Long-context tier gate — compress context before retry",
            true, true, false, false,
        ));
    }

    None
}

fn classify_by_status(
    status: u16,
    msg: &str,
    provider: &str,
    token_est: usize,
    msg_count: usize,
) -> ClassifiedError {
    match status {
        401 => make_classified(FailoverReason::Auth, Some(status), provider, msg, false, false, true, true),
        403 => {
            if msg.contains("banned") || msg.contains("suspended") || msg.contains("terminated") {
                make_classified(FailoverReason::AuthPermanent, Some(status), provider, msg, false, false, true, true)
            } else {
                make_classified(FailoverReason::Auth, Some(status), provider, msg, false, false, true, true)
            }
        }
        402 => classify_402(msg, provider),
        429 => make_classified(FailoverReason::RateLimit, Some(status), provider, msg, true, false, false, false),
        413 => make_classified(FailoverReason::PayloadTooLarge, Some(status), provider, msg, true, true, false, false),
        400 => {
            if msg.contains("context") || msg.contains("token") || msg.contains("too long") {
                make_classified(FailoverReason::ContextOverflow, Some(status), provider, msg, true, true, false, false)
            } else if msg.contains("model") && (msg.contains("not found") || msg.contains("does not exist")) {
                make_classified(FailoverReason::ModelNotFound, Some(status), provider, msg, false, false, false, true)
            } else if is_large_session(token_est, msg_count, 0.5) {
                // Generic 400 + large session → likely context overflow
                make_classified(FailoverReason::ContextOverflow, Some(status), provider, msg, true, true, false, false)
            } else {
                make_classified(FailoverReason::FormatError, Some(status), provider, msg, false, false, false, false)
            }
        }
        404 => {
            if msg.contains("model") {
                make_classified(FailoverReason::ModelNotFound, Some(status), provider, msg, false, false, false, true)
            } else {
                make_classified(FailoverReason::FormatError, Some(status), provider, msg, false, false, false, false)
            }
        }
        500 | 502 => make_classified(FailoverReason::ServerError, Some(status), provider, msg, true, false, false, true),
        503 => make_classified(FailoverReason::Overloaded, Some(status), provider, msg, true, false, false, true),
        _ => make_classified(FailoverReason::Unknown, Some(status), provider, msg, false, false, false, true),
    }
}

/// Disambiguate 402: genuine billing exhaustion vs transient usage limit.
fn classify_402(msg: &str, provider: &str) -> ClassifiedError {
    let has_billing = BILLING_PATTERNS.iter().any(|p| msg.contains(p));
    let has_transient = USAGE_LIMIT_TRANSIENT.iter().any(|p| msg.contains(p));

    if has_billing && !has_transient {
        make_classified(FailoverReason::Billing, Some(402), provider, msg, false, false, true, true)
    } else if has_transient {
        make_classified(FailoverReason::RateLimit, Some(402), provider, msg, true, false, false, false)
    } else {
        make_classified(FailoverReason::Billing, Some(402), provider, msg, false, false, true, true)
    }
}

fn is_large_session(token_est: usize, msg_count: usize, context_ratio: f64) -> bool {
    let threshold = (200_000.0 * context_ratio) as usize;
    token_est > threshold || msg_count > 200 || token_est > 80_000
}

fn make_classified(
    reason: FailoverReason,
    status_code: Option<u16>,
    provider: &str,
    message: &str,
    retryable: bool,
    should_compress: bool,
    should_rotate_credential: bool,
    should_fallback: bool,
) -> ClassifiedError {
    ClassifiedError {
        reason,
        status_code,
        provider: provider.to_string(),
        message: message.to_string(),
        retryable,
        should_compress,
        should_rotate_credential,
        should_fallback,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_401_as_auth() {
        let result = classify_error(Some(401), "invalid api key", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::Auth);
        assert!(result.should_rotate_credential);
        assert!(!result.retryable);
    }

    #[test]
    fn classifies_429_as_rate_limit() {
        let result = classify_error(Some(429), "too many requests", "openai", 0, 0);
        assert_eq!(result.reason, FailoverReason::RateLimit);
        assert!(result.retryable);
    }

    #[test]
    fn classifies_billing_402() {
        let result = classify_error(Some(402), "insufficient credits", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::Billing);
        assert!(result.should_rotate_credential);
        assert!(!result.retryable);
    }

    #[test]
    fn classifies_transient_402_as_rate_limit() {
        let result = classify_error(Some(402), "rate limit exceeded, try again in 60s", "openai", 0, 0);
        assert_eq!(result.reason, FailoverReason::RateLimit);
        assert!(result.retryable);
    }

    #[test]
    fn classifies_thinking_signature() {
        let result = classify_error(Some(400), "invalid signature for thinking block", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::ThinkingSignature);
        assert!(result.retryable);
        assert!(!result.should_compress);
    }

    #[test]
    fn classifies_long_context_tier() {
        let result = classify_error(Some(429), "extra usage tier required for long context", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::LongContextTier);
        assert!(result.retryable);
        assert!(result.should_compress);
    }

    #[test]
    fn classifies_context_overflow_explicit() {
        let result = classify_error(Some(400), "context length exceeded maximum token limit", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::ContextOverflow);
        assert!(result.should_compress);
    }

    #[test]
    fn classifies_generic_400_large_session_as_context_overflow() {
        let result = classify_error(Some(400), "bad request", "claude", 100_000, 100);
        assert_eq!(result.reason, FailoverReason::ContextOverflow);
    }

    #[test]
    fn classifies_503_as_overloaded() {
        let result = classify_error(Some(503), "service unavailable", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::Overloaded);
        assert!(result.retryable);
    }

    #[test]
    fn classifies_timeout() {
        let result = classify_error(None, "request timed out after 30s", "openai", 0, 0);
        assert_eq!(result.reason, FailoverReason::Timeout);
        assert!(result.retryable);
    }

    #[test]
    fn classifies_model_not_found() {
        let result = classify_error(Some(404), "model gpt-5 not found", "openai", 0, 0);
        assert_eq!(result.reason, FailoverReason::ModelNotFound);
        assert!(result.should_fallback);
    }

    #[test]
    fn classifies_auth_permanent() {
        let result = classify_error(Some(403), "account suspended", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::AuthPermanent);
        assert!(result.should_rotate_credential);
    }

    #[test]
    fn classifies_payload_too_large() {
        let result = classify_error(Some(413), "request entity too large", "claude", 0, 0);
        assert_eq!(result.reason, FailoverReason::PayloadTooLarge);
        assert!(result.should_compress);
    }

    #[test]
    fn failover_reason_as_str_roundtrip() {
        let reasons = [
            FailoverReason::Auth, FailoverReason::AuthPermanent,
            FailoverReason::Billing, FailoverReason::RateLimit,
            FailoverReason::Overloaded, FailoverReason::ServerError,
            FailoverReason::Timeout, FailoverReason::ContextOverflow,
            FailoverReason::PayloadTooLarge, FailoverReason::ModelNotFound,
            FailoverReason::FormatError, FailoverReason::ThinkingSignature,
            FailoverReason::LongContextTier, FailoverReason::Unknown,
        ];
        for r in &reasons {
            assert!(!r.as_str().is_empty());
        }
        assert_eq!(reasons.len(), 14);
    }
}
