//! Raw Thoughts V0 — per-run artifact emitter.
//!
//! Writes a per-run folder with:
//! - `manifest.json` (run id, prompt id, provider, model, started/ended, status)
//! - `events.jsonl` (one event per line: thinking_delta, signature_delta,
//!   text_delta, tool_use, tool_result, reasoning_summary, message_stop)
//! - `summary.md` (planner + execution summary, app-owned, optional)
//! - `links.json` (artifact + source + chat refs, optional)
//!
//! Behind `EPISTEMOS_RAW_THOUGHTS_V0` environment flag. Default OFF for V0;
//! the user opts in per-process. When the flag is unset (or anything other
//! than `"1"`), `RawThoughtsEmitter::new` returns a disabled instance whose
//! `record` / `finish` calls are cheap no-ops and which never touches the
//! filesystem.
//!
//! Folder layout:
//!   `<vault_root>/Raw Thoughts/<provider>/<YYYY-MM-DD>_<short-run-id>/`
//!     `manifest.json`
//!     `events.jsonl`
//!     `summary.md`   (only if `finish` is called with a summary body)
//!     `links.json`   (only if `write_links` is invoked, optional)
//!
//! Design:
//! - All writes are buffered through `BufWriter<File>` so the agent hot path
//!   is not blocked on disk I/O per event. Buffers are flushed on `finish`.
//! - Bytes from provider deltas (notably `signature` for Anthropic thinking
//!   blocks) are preserved verbatim — they ride through `serde_json` as
//!   `String` and are recoverable byte-for-byte when the JSONL line is
//!   re-parsed.
//! - The emitter takes no ownership of the agent loop's state; it is
//!   appended to via `record(...)` from the streaming handler and finalized
//!   exactly once on session completion / cancellation / error.

use std::fs;
use std::io::{self, BufWriter, Write};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use chrono::Local;
use serde::{Deserialize, Serialize};

/// Environment flag that opts a process into Raw Thoughts V0 emission.
const ENV_FLAG: &str = "EPISTEMOS_RAW_THOUGHTS_V0";

// ---------------------------------------------------------------------------
// Manifest + Status
// ---------------------------------------------------------------------------

/// Lifecycle status of a Raw Thoughts run. Mirrors the agent loop's
/// terminal outcomes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RawThoughtsStatus {
    Running,
    Completed,
    Errored,
    Cancelled,
}

impl RawThoughtsStatus {
    #[cfg(test)]
    fn as_str(&self) -> &'static str {
        match self {
            Self::Running => "running",
            Self::Completed => "completed",
            Self::Errored => "errored",
            Self::Cancelled => "cancelled",
        }
    }
}

/// Per-run manifest persisted as `manifest.json`. Timestamps are unix
/// milliseconds so consumers (Swift, scripts) do not need a chrono parser.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawThoughtsManifest {
    pub run_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prompt_id: Option<String>,
    pub provider: String,
    pub model: String,
    pub started_at: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<i64>,
    pub status: RawThoughtsStatus,
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// One JSONL event in `events.jsonl`. Variant tags use `snake_case` so the
/// `type` field survives a Swift round-trip without a custom decoder.
///
/// `SignatureDelta::signature` is opaque text that MUST round-trip
/// byte-for-byte (Anthropic uses it to authenticate thinking blocks across
/// tool turns; dropping or mutating it kills the agent per CLAUDE.md
/// "PRESERVE THINKING BLOCKS").
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum RawThoughtsEvent {
    ThinkingDelta {
        index: u32,
        text: String,
    },
    SignatureDelta {
        index: u32,
        signature: String,
    },
    TextDelta {
        index: u32,
        text: String,
    },
    ToolUse {
        id: String,
        name: String,
        input: serde_json::Value,
    },
    ToolResult {
        tool_use_id: String,
        output: String,
        is_error: bool,
    },
    ReasoningSummary {
        text: String,
    },
    MessageStop {
        stop_reason: String,
    },
}

// ---------------------------------------------------------------------------
// Emitter
// ---------------------------------------------------------------------------

/// Per-run artifact emitter. Cheap to construct when disabled (the env
/// flag is read once at construction and the resulting instance is a
/// no-op).
///
/// All public methods take `&self` so the emitter can be wrapped in an
/// `Arc` and cloned into parallel tool executors without ceremony. The
/// internal manifest + event writer are each guarded by their own `Mutex`
/// so a record + finish race results in a deterministic flush rather than
/// a torn write.
pub struct RawThoughtsEmitter {
    enabled: bool,
    run_dir: Option<PathBuf>,
    events_writer: Option<Mutex<Option<BufWriter<fs::File>>>>,
    manifest: Mutex<RawThoughtsManifest>,
}

impl RawThoughtsEmitter {
    /// Returns `true` when the environment flag is set to `"1"`.
    pub fn enabled() -> bool {
        std::env::var(ENV_FLAG).as_deref() == Ok("1")
    }

    /// Build an emitter for a single run. When disabled the returned
    /// instance does no I/O; callers can safely invoke `record` / `finish`
    /// without conditional code on the hot path.
    ///
    /// `vault_root` is the user's vault directory. The run folder lives at
    /// `<vault_root>/Raw Thoughts/<sanitized provider>/<YYYY-MM-DD>_<short-run-id>/`.
    /// `provider` and `model` are taken straight from the agent loop; they
    /// are sanitized into a filesystem-safe slug for the folder name only,
    /// and stored verbatim inside the manifest JSON.
    pub fn new(
        vault_root: &Path,
        provider: &str,
        model: &str,
        run_id: &str,
        prompt_id: Option<&str>,
    ) -> Self {
        let started_at = unix_ms_now();
        let manifest = RawThoughtsManifest {
            run_id: run_id.to_string(),
            prompt_id: prompt_id.map(str::to_string),
            provider: provider.to_string(),
            model: model.to_string(),
            started_at,
            ended_at: None,
            status: RawThoughtsStatus::Running,
        };

        if !Self::enabled() {
            return Self {
                enabled: false,
                run_dir: None,
                events_writer: None,
                manifest: Mutex::new(manifest),
            };
        }

        match Self::build_run_dir(vault_root, provider, run_id) {
            Ok(dir) => match Self::open_events_file(&dir) {
                Ok(writer) => {
                    // Best-effort initial manifest write. If it fails we
                    // still keep the emitter open for events; `finish`
                    // will retry the manifest write.
                    let _ = write_manifest(&dir, &manifest);
                    Self {
                        enabled: true,
                        run_dir: Some(dir),
                        events_writer: Some(Mutex::new(Some(writer))),
                        manifest: Mutex::new(manifest),
                    }
                }
                Err(error) => {
                    tracing::warn!(
                        ?error,
                        "raw_thoughts: failed to open events.jsonl, disabling emitter"
                    );
                    Self {
                        enabled: false,
                        run_dir: None,
                        events_writer: None,
                        manifest: Mutex::new(manifest),
                    }
                }
            },
            Err(error) => {
                tracing::warn!(
                    ?error,
                    "raw_thoughts: failed to create run dir, disabling emitter"
                );
                Self {
                    enabled: false,
                    run_dir: None,
                    events_writer: None,
                    manifest: Mutex::new(manifest),
                }
            }
        }
    }

    /// Whether this emitter will actually write to disk.
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    /// Path of the run folder when enabled; `None` otherwise.
    pub fn run_dir(&self) -> Option<&Path> {
        self.run_dir.as_deref()
    }

    /// Append a single event to `events.jsonl`. No-op when disabled.
    /// Returns the underlying `io::Error` if the buffered write fails;
    /// callers in the agent loop should log and proceed (the agent must
    /// not abort on artifact-writer failure).
    pub fn record(&self, event: RawThoughtsEvent) -> io::Result<()> {
        if !self.enabled {
            return Ok(());
        }
        let Some(writer_lock) = &self.events_writer else {
            return Ok(());
        };
        let mut line = serde_json::to_string(&event)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        line.push('\n');
        let mut guard = writer_lock
            .lock()
            .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
        if let Some(writer) = guard.as_mut() {
            writer.write_all(line.as_bytes())?;
        }
        Ok(())
    }

    /// Optional: persist a `links.json` payload. Best-effort; ignored when
    /// disabled. The caller controls the schema (artifact refs, source
    /// refs, chat refs) — this function only writes the JSON value.
    pub fn write_links(&self, links: &serde_json::Value) -> io::Result<()> {
        if !self.enabled {
            return Ok(());
        }
        let Some(dir) = &self.run_dir else {
            return Ok(());
        };
        let body = serde_json::to_string_pretty(links)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        fs::write(dir.join("links.json"), body)
    }

    /// Finalize the run: flush the events buffer, update the manifest with
    /// the terminal status + `ended_at`, and (when provided) write the
    /// summary markdown. Idempotent — calling `finish` more than once
    /// only rewrites the manifest with the latest status.
    /// No-op when disabled.
    pub fn finish(
        &self,
        status: RawThoughtsStatus,
        summary_md: Option<&str>,
    ) -> io::Result<()> {
        let snapshot = {
            let mut guard = self
                .manifest
                .lock()
                .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
            guard.status = status;
            guard.ended_at = Some(unix_ms_now());
            guard.clone()
        };

        if !self.enabled {
            return Ok(());
        }

        // Flush + close the events writer so the file handle is released
        // before the manifest is rewritten (defensive on Windows; harmless
        // on macOS).
        if let Some(writer_lock) = &self.events_writer {
            if let Ok(mut guard) = writer_lock.lock() {
                if let Some(mut writer) = guard.take() {
                    writer.flush()?;
                }
            }
        }

        let Some(dir) = self.run_dir.as_ref() else {
            return Ok(());
        };

        write_manifest(dir, &snapshot)?;

        if let Some(body) = summary_md {
            fs::write(dir.join("summary.md"), body)?;
        }

        Ok(())
    }

    fn build_run_dir(vault_root: &Path, provider: &str, run_id: &str) -> io::Result<PathBuf> {
        let provider_slug = sanitize_path_component(provider);
        let date = Local::now().format("%Y-%m-%d");
        let short_id = short_run_id(run_id);
        let folder_name = format!("{date}_{short_id}");

        let dir = vault_root
            .join("Raw Thoughts")
            .join(provider_slug)
            .join(folder_name);
        fs::create_dir_all(&dir)?;
        Ok(dir)
    }

    fn open_events_file(dir: &Path) -> io::Result<BufWriter<fs::File>> {
        let file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(dir.join("events.jsonl"))?;
        Ok(BufWriter::new(file))
    }
}

impl Drop for RawThoughtsEmitter {
    fn drop(&mut self) {
        // Best-effort flush so a forgotten `finish()` (e.g. panic path)
        // still gets the events to disk. Status remains whatever it was
        // at last update.
        if !self.enabled {
            return;
        }
        if let Some(writer_lock) = self.events_writer.as_ref() {
            if let Ok(mut guard) = writer_lock.lock() {
                if let Some(mut writer) = guard.take() {
                    let _ = writer.flush();
                }
            }
        }
        if let Some(dir) = self.run_dir.as_ref() {
            if let Ok(manifest) = self.manifest.lock() {
                let _ = write_manifest(dir, &manifest);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn unix_ms_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|delta| delta.as_millis() as i64)
        .unwrap_or(0)
}

fn write_manifest(dir: &Path, manifest: &RawThoughtsManifest) -> io::Result<()> {
    let body = serde_json::to_string_pretty(manifest)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
    fs::write(dir.join("manifest.json"), body)
}

/// Replace path separators and other unsafe characters with underscores so
/// the provider name can become a folder name without escaping the run
/// root.
fn sanitize_path_component(raw: &str) -> String {
    let cleaned: String = raw
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if cleaned.is_empty() {
        "unknown".to_string()
    } else {
        cleaned
    }
}

fn short_run_id(run_id: &str) -> String {
    let trimmed: String = run_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
        .collect();
    let take = trimmed.len().min(12);
    if take == 0 {
        "run".to_string()
    } else {
        trimmed[..take].to_string()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex as StdMutex, MutexGuard, OnceLock};
    use tempfile::TempDir;

    /// Serialize tests that toggle the EPISTEMOS_RAW_THOUGHTS_V0 env flag.
    /// Cargo runs tests in parallel; without this lock one test could
    /// disable the flag while another is constructing an enabled emitter.
    fn env_lock() -> MutexGuard<'static, ()> {
        static LOCK: OnceLock<StdMutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| StdMutex::new(()))
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    fn enable_flag() {
        std::env::set_var(ENV_FLAG, "1");
    }

    fn disable_flag() {
        std::env::remove_var(ENV_FLAG);
    }

    #[test]
    fn manifest_written_with_correct_fields() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_abcdef123456",
            Some("prompt_xyz"),
        );
        assert!(emitter.is_enabled(), "flag set should enable emitter");
        let dir = emitter
            .run_dir()
            .expect("enabled emitter must have run dir")
            .to_path_buf();
        assert!(dir.starts_with(tmp.path().join("Raw Thoughts").join("anthropic")));
        assert!(dir.join("manifest.json").exists());

        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();
        let body = fs::read_to_string(dir.join("manifest.json")).unwrap();
        let manifest: RawThoughtsManifest = serde_json::from_str(&body).unwrap();
        assert_eq!(manifest.run_id, "run_abcdef123456");
        assert_eq!(manifest.prompt_id.as_deref(), Some("prompt_xyz"));
        assert_eq!(manifest.provider, "anthropic");
        assert_eq!(manifest.model, "claude-opus-4-7");
        assert!(matches!(manifest.status, RawThoughtsStatus::Completed));
        assert!(manifest.started_at > 0);
        assert!(manifest.ended_at.unwrap_or(0) >= manifest.started_at);
        disable_flag();
    }

    #[test]
    fn events_jsonl_one_line_per_event() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_lines",
            None,
        );

        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: "step 1".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::TextDelta {
                index: 0,
                text: "answer".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::MessageStop {
                stop_reason: "end_turn".to_string(),
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let body = fs::read_to_string(dir.join("events.jsonl")).unwrap();
        let lines: Vec<&str> = body.lines().collect();
        assert_eq!(lines.len(), 3);
        for line in lines {
            let parsed: RawThoughtsEvent = serde_json::from_str(line).unwrap();
            assert!(matches!(
                parsed,
                RawThoughtsEvent::ThinkingDelta { .. }
                    | RawThoughtsEvent::TextDelta { .. }
                    | RawThoughtsEvent::MessageStop { .. }
            ));
        }
        disable_flag();
    }

    #[test]
    fn thinking_and_signature_bytes_round_trip() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        // Signatures are opaque base64-ish blobs from Anthropic; bytes
        // must survive verbatim or the next tool turn fails.
        let signature = "AbCdEf+/==xY9z\n\t with spaces and unicode \u{2603}\u{1F600}";
        let thinking = "I should call the tool because <reason>\nwith newline";

        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_bytes",
            None,
        );
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: thinking.to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::SignatureDelta {
                index: 0,
                signature: signature.to_string(),
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let body = fs::read_to_string(dir.join("events.jsonl")).unwrap();
        let mut lines = body.lines();

        let thinking_event: RawThoughtsEvent =
            serde_json::from_str(lines.next().unwrap()).unwrap();
        match thinking_event {
            RawThoughtsEvent::ThinkingDelta { text, .. } => {
                assert_eq!(text.as_bytes(), thinking.as_bytes());
            }
            other => panic!("expected ThinkingDelta, got {other:?}"),
        }

        let signature_event: RawThoughtsEvent =
            serde_json::from_str(lines.next().unwrap()).unwrap();
        match signature_event {
            RawThoughtsEvent::SignatureDelta {
                signature: sig, ..
            } => {
                assert_eq!(sig.as_bytes(), signature.as_bytes());
            }
            other => panic!("expected SignatureDelta, got {other:?}"),
        }
        disable_flag();
    }

    #[test]
    fn tool_use_and_result_serde_round_trip() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_tools",
            None,
        );

        let input = serde_json::json!({
            "query": "find the note about kant",
            "limit": 5,
            "nested": { "filter": ["a", "b"] }
        });
        emitter
            .record(RawThoughtsEvent::ToolUse {
                id: "tc_001".to_string(),
                name: "vault_search".to_string(),
                input: input.clone(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolResult {
                tool_use_id: "tc_001".to_string(),
                output: "found 3 notes".to_string(),
                is_error: false,
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let body = fs::read_to_string(dir.join("events.jsonl")).unwrap();
        let mut lines = body.lines();

        let use_event: RawThoughtsEvent = serde_json::from_str(lines.next().unwrap()).unwrap();
        match use_event {
            RawThoughtsEvent::ToolUse {
                id,
                name,
                input: parsed,
            } => {
                assert_eq!(id, "tc_001");
                assert_eq!(name, "vault_search");
                assert_eq!(parsed, input);
            }
            other => panic!("expected ToolUse, got {other:?}"),
        }

        let result_event: RawThoughtsEvent = serde_json::from_str(lines.next().unwrap()).unwrap();
        match result_event {
            RawThoughtsEvent::ToolResult {
                tool_use_id,
                output,
                is_error,
            } => {
                assert_eq!(tool_use_id, "tc_001");
                assert_eq!(output, "found 3 notes");
                assert!(!is_error);
            }
            other => panic!("expected ToolResult, got {other:?}"),
        }
        disable_flag();
    }

    #[test]
    fn disabled_flag_creates_no_folder() {
        let _guard = env_lock();
        disable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_off",
            None,
        );
        assert!(!emitter.is_enabled());
        assert!(emitter.run_dir().is_none());

        // record/finish must not panic and must not create files.
        emitter
            .record(RawThoughtsEvent::TextDelta {
                index: 0,
                text: "ignored".to_string(),
            })
            .unwrap();
        emitter
            .finish(RawThoughtsStatus::Completed, Some("# summary"))
            .unwrap();

        let raw_thoughts_dir = tmp.path().join("Raw Thoughts");
        assert!(
            !raw_thoughts_dir.exists(),
            "disabled emitter must never create the run root"
        );
    }

    #[test]
    fn finish_updates_status_ended_at_and_writes_summary() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_done",
            None,
        );
        let dir = emitter.run_dir().unwrap().to_path_buf();

        // Confirm the initial manifest is "running" with no ended_at.
        let initial_body = fs::read_to_string(dir.join("manifest.json")).unwrap();
        let initial: RawThoughtsManifest = serde_json::from_str(&initial_body).unwrap();
        assert!(matches!(initial.status, RawThoughtsStatus::Running));
        assert!(initial.ended_at.is_none());

        let summary = "# Run summary\n\nDid the thing.\n";
        emitter
            .finish(RawThoughtsStatus::Errored, Some(summary))
            .unwrap();

        let final_body = fs::read_to_string(dir.join("manifest.json")).unwrap();
        let final_manifest: RawThoughtsManifest = serde_json::from_str(&final_body).unwrap();
        assert!(matches!(
            final_manifest.status,
            RawThoughtsStatus::Errored
        ));
        assert!(final_manifest.ended_at.is_some());

        let summary_body = fs::read_to_string(dir.join("summary.md")).unwrap();
        assert_eq!(summary_body, summary);
        disable_flag();
    }

    #[test]
    fn status_serializes_snake_case() {
        // Sanity: keep the on-disk wire format snake_case so Swift can
        // decode it without a custom strategy.
        assert_eq!(RawThoughtsStatus::Running.as_str(), "running");
        assert_eq!(RawThoughtsStatus::Completed.as_str(), "completed");
        assert_eq!(RawThoughtsStatus::Errored.as_str(), "errored");
        assert_eq!(RawThoughtsStatus::Cancelled.as_str(), "cancelled");
        let json = serde_json::to_string(&RawThoughtsStatus::Cancelled).unwrap();
        assert_eq!(json, "\"cancelled\"");
    }
}
