use std::time::Duration;

#[derive(Debug, Clone, PartialEq)]
pub enum ErrorAction {
    Fail,
    Retry { after: Duration },
    RetryAfter(Duration),
}

pub fn classify_http_error(status: u16, retry_after_header: Option<&str>) -> ErrorAction {
    match status {
        400 | 401 | 403 | 404 | 422 => ErrorAction::Fail,
        429 => {
            if let Some(after) = retry_after_header.and_then(parse_retry_after) {
                ErrorAction::RetryAfter(after)
            } else {
                ErrorAction::Retry {
                    after: Duration::from_secs(5),
                }
            }
        }
        529 => ErrorAction::Retry {
            after: Duration::from_secs(10),
        },
        500 | 502 | 503 => ErrorAction::Retry {
            after: Duration::from_secs(2),
        },
        s if s >= 500 => ErrorAction::Retry {
            after: Duration::from_secs(3),
        },
        _ => ErrorAction::Fail,
    }
}

fn parse_retry_after(value: &str) -> Option<Duration> {
    value.trim().parse::<u64>().ok().map(Duration::from_secs)
}

#[derive(Debug, Clone)]
pub struct RetryConfig {
    pub max_retries: u32,
    pub base_delay: Duration,
    pub max_delay: Duration,
    pub jitter: f64,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_retries: 3,
            base_delay: Duration::from_secs(1),
            max_delay: Duration::from_secs(60),
            jitter: 0.25,
        }
    }
}

impl RetryConfig {
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        let exp_delay = self.base_delay.as_secs_f64() * (2.0_f64).powi(attempt as i32);
        let capped = exp_delay.min(self.max_delay.as_secs_f64());
        let jitter_range = capped * self.jitter;
        let jittered = capped + jitter_range * (2.0 * rand_f64() - 1.0);
        Duration::from_secs_f64(jittered.max(0.1))
    }
}

pub async fn with_retry<F, Fut, T, E>(
    config: &RetryConfig,
    cancel: &tokio_util::sync::CancellationToken,
    mut operation: F,
) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: HttpStatusError + std::fmt::Display,
{
    let mut last_error: Option<E> = None;

    for attempt in 0..=config.max_retries {
        if cancel.is_cancelled() {
            if let Some(error) = last_error {
                return Err(error);
            }
        }

        match operation().await {
            Ok(result) => return Ok(result),
            Err(error) => {
                let status = error.http_status().unwrap_or(0);
                let action = classify_http_error(status, error.retry_after_header().as_deref());

                match action {
                    ErrorAction::Fail => return Err(error),
                    ErrorAction::Retry { after } | ErrorAction::RetryAfter(after) => {
                        if attempt >= config.max_retries {
                            return Err(error);
                        }

                        let delay = match action {
                            ErrorAction::RetryAfter(delay) => delay,
                            _ => config.delay_for_attempt(attempt).max(after),
                        };

                        tokio::select! {
                            _ = tokio::time::sleep(delay) => {}
                            _ = cancel.cancelled() => return Err(error),
                        }

                        last_error = Some(error);
                    }
                }
            }
        }
    }

    Err(last_error.expect("retry loop should set last_error"))
}

pub trait HttpStatusError {
    fn http_status(&self) -> Option<u16>;
    fn retry_after_header(&self) -> Option<String>;
}

fn rand_f64() -> f64 {
    use std::time::SystemTime;

    let seed = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    let x = seed.wrapping_mul(1103515245).wrapping_add(12345);
    (x as f64) / (u32::MAX as f64)
}
