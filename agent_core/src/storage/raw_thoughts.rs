//! Raw Thoughts V0 — per-run artifact emitter.
//!
//! Writes a per-run folder with:
//! - `manifest.json` (run id, prompt id, provider, model, started/ended, status)
//! - `events.jsonl` (one event per line: thinking_delta, signature_delta,
//!   text_delta, tool_use, tool_result, reasoning_summary, message_stop)
//! - `summary.md` (planner + execution summary, app-owned, optional)
//! - `links.json` (artifact + source + chat refs, optional)
//! - `thoughts/<idx>.json` (Wave 3.1: derivative per-thought sidecar; written
//!   when a SignatureDelta seals a thinking sequence)
//! - `tools/<tool_use_id>.json` (Wave 3.1: derivative per-tool sidecar;
//!   written when a ToolResult pairs with the matching ToolUse)
//! - `final.json` (Wave 3.1: terminal aggregate written by `finish` —
//!   event counts, durations, sealed thought indexes, completed tool ids)
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
//!     `summary.md`            (only if `finish` is called with a summary body)
//!     `links.json`            (only if `write_links` is invoked, optional)
//!     `thoughts/<idx>.json`   (Wave 3.1, written incrementally on seal)
//!     `tools/<id>.json`       (Wave 3.1, written incrementally on pair)
//!     `final.json`            (Wave 3.1, written by `finish`)
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

use std::collections::HashMap;
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
// Wave 3.1 close-out sidecars
// ---------------------------------------------------------------------------

/// Per-thought sidecar — written to `thoughts/<idx>.json` when a thinking
/// sequence is sealed by a SignatureDelta on the same index. Captures the
/// fully-accumulated thinking text + opaque signature in one JSON object so
/// downstream consumers (UI, embeddings, audits) can read a single thought
/// without re-parsing the event stream.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawThoughtsThoughtSidecar {
    pub index: u32,
    pub thinking: String,
    pub signature: String,
    pub started_at: i64,
    pub sealed_at: i64,
}

/// Per-tool sidecar — written to `tools/<tool_use_id>.json` when a
/// ToolResult pairs with its earlier ToolUse. Aggregates the full tool
/// invocation in one file so a downstream consumer never has to scan
/// `events.jsonl` to reconstruct a single tool call.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawThoughtsToolSidecar {
    pub tool_use_id: String,
    pub name: String,
    pub input: serde_json::Value,
    pub output: String,
    pub is_error: bool,
    pub started_at: i64,
    pub completed_at: i64,
    pub duration_ms: i64,
}

/// Aggregate event counts for the run — populated incrementally in
/// `record(...)` and serialised into `final.json` by `finish(...)`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RawThoughtsEventCounts {
    pub thinking_delta: u64,
    pub signature_delta: u64,
    pub text_delta: u64,
    /// Sum of `text_delta.text.len()` (bytes, not graphemes — cheap to count).
    pub text_chars: u64,
    pub tool_use: u64,
    pub tool_result: u64,
    pub tool_errors: u64,
    pub reasoning_summary: u64,
    pub message_stop: u64,
}

/// Run-terminal sidecar — written to `final.json` by `finish(...)`. The
/// "TL;DR" of the run: aggregate counts, durations, sealed thought
/// indexes, completed tool ids, and the last `stop_reason` observed.
/// Idempotent rewrite — calling `finish` twice produces identical bytes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawThoughtsFinalSidecar {
    pub run_id: String,
    pub provider: String,
    pub model: String,
    pub started_at: i64,
    pub ended_at: i64,
    pub duration_ms: i64,
    pub status: RawThoughtsStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop_reason: Option<String>,
    pub event_counts: RawThoughtsEventCounts,
    pub thought_indexes: Vec<u32>,
    pub tool_use_ids: Vec<String>,
}

/// In-flight thought accumulator — owned by the emitter, indexed by
/// `index` from ThinkingDelta + SignatureDelta. Pre-allocates one entry on
/// the first ThinkingDelta and seals when SignatureDelta arrives.
#[derive(Debug, Clone)]
struct ThoughtAcc {
    thinking: String,
    started_at: i64,
}

/// In-flight tool accumulator — keyed by ToolUse.id, removed when the
/// matching ToolResult arrives. Holds onto the original input + start
/// time so the sidecar can record duration.
#[derive(Debug, Clone)]
struct ToolAcc {
    name: String,
    input: serde_json::Value,
    started_at: i64,
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

    // Wave 3.1 close-out state. All Mutex-guarded so &self methods can
    // be invoked from concurrent tool executors.
    thoughts_in_flight: Mutex<HashMap<u32, ThoughtAcc>>,
    tools_in_flight: Mutex<HashMap<String, ToolAcc>>,
    counts: Mutex<RawThoughtsEventCounts>,
    last_stop_reason: Mutex<Option<String>>,
    sealed_thoughts: Mutex<Vec<u32>>,
    completed_tools: Mutex<Vec<String>>,
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
            return Self::disabled(manifest);
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
                        thoughts_in_flight: Mutex::new(HashMap::new()),
                        tools_in_flight: Mutex::new(HashMap::new()),
                        counts: Mutex::new(RawThoughtsEventCounts::default()),
                        last_stop_reason: Mutex::new(None),
                        sealed_thoughts: Mutex::new(Vec::new()),
                        completed_tools: Mutex::new(Vec::new()),
                    }
                }
                Err(error) => {
                    tracing::warn!(
                        ?error,
                        "raw_thoughts: failed to open events.jsonl, disabling emitter"
                    );
                    Self::disabled(manifest)
                }
            },
            Err(error) => {
                tracing::warn!(
                    ?error,
                    "raw_thoughts: failed to create run dir, disabling emitter"
                );
                Self::disabled(manifest)
            }
        }
    }

    /// Disabled emitter — pre-allocates the close-out maps as empty so
    /// `&self` methods don't have to branch on enabled before locking.
    fn disabled(manifest: RawThoughtsManifest) -> Self {
        Self {
            enabled: false,
            run_dir: None,
            events_writer: None,
            manifest: Mutex::new(manifest),
            thoughts_in_flight: Mutex::new(HashMap::new()),
            tools_in_flight: Mutex::new(HashMap::new()),
            counts: Mutex::new(RawThoughtsEventCounts::default()),
            last_stop_reason: Mutex::new(None),
            sealed_thoughts: Mutex::new(Vec::new()),
            completed_tools: Mutex::new(Vec::new()),
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

    /// Append a single event to `events.jsonl` AND update Wave 3.1
    /// derivative state (counts + in-flight thought/tool accumulators +
    /// sidecar emission on seal/pair). No-op when disabled.
    /// Returns the underlying `io::Error` if the buffered write fails;
    /// callers in the agent loop should log and proceed (the agent must
    /// not abort on artifact-writer failure).
    ///
    /// Wave 3.1 ordering: events.jsonl write happens FIRST so a panic in
    /// derivative-state code never loses the raw event. Derivative state
    /// is best-effort — sidecar write failures log and continue.
    pub fn record(&self, event: RawThoughtsEvent) -> io::Result<()> {
        if !self.enabled {
            return Ok(());
        }

        // 1. Append to events.jsonl (raw, unconditional).
        if let Some(writer_lock) = &self.events_writer {
            let mut line = serde_json::to_string(&event)
                .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
            line.push('\n');
            let mut guard = writer_lock
                .lock()
                .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
            if let Some(writer) = guard.as_mut() {
                writer.write_all(line.as_bytes())?;
            }
        }

        // 2. Update Wave 3.1 derivative state. Each branch is independent
        //    so a failure in one does not mask the others.
        if let Err(error) = self.update_close_out_state(&event) {
            tracing::warn!(?error, "raw_thoughts: close-out state update failed");
        }

        Ok(())
    }

    /// Wave 3.1: drive the in-flight accumulators + counts + incremental
    /// sidecar writes for one event. Pure derivative bookkeeping — never
    /// touches `events.jsonl`. Errors here are logged by the caller; we
    /// never propagate them above `record()`.
    fn update_close_out_state(&self, event: &RawThoughtsEvent) -> io::Result<()> {
        let now = unix_ms_now();
        match event {
            RawThoughtsEvent::ThinkingDelta { index, text } => {
                self.bump_count(|c| c.thinking_delta += 1);
                let mut map = self
                    .thoughts_in_flight
                    .lock()
                    .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
                let acc = map.entry(*index).or_insert_with(|| ThoughtAcc {
                    thinking: String::new(),
                    started_at: now,
                });
                acc.thinking.push_str(text);
            }
            RawThoughtsEvent::SignatureDelta { index, signature } => {
                self.bump_count(|c| c.signature_delta += 1);
                let acc = {
                    let mut map = self
                        .thoughts_in_flight
                        .lock()
                        .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
                    map.remove(index)
                };
                let started_at = acc.as_ref().map(|a| a.started_at).unwrap_or(now);
                let thinking = acc.map(|a| a.thinking).unwrap_or_default();
                if let Some(dir) = &self.run_dir {
                    let sidecar = RawThoughtsThoughtSidecar {
                        index: *index,
                        thinking,
                        signature: signature.clone(),
                        started_at,
                        sealed_at: now,
                    };
                    write_thought_sidecar(dir, &sidecar)?;
                    if let Ok(mut sealed) = self.sealed_thoughts.lock() {
                        sealed.push(*index);
                    }
                }
            }
            RawThoughtsEvent::TextDelta { text, .. } => {
                self.bump_count(|c| {
                    c.text_delta += 1;
                    c.text_chars += text.len() as u64;
                });
            }
            RawThoughtsEvent::ToolUse { id, name, input } => {
                self.bump_count(|c| c.tool_use += 1);
                let mut map = self
                    .tools_in_flight
                    .lock()
                    .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
                map.insert(
                    id.clone(),
                    ToolAcc {
                        name: name.clone(),
                        input: input.clone(),
                        started_at: now,
                    },
                );
            }
            RawThoughtsEvent::ToolResult {
                tool_use_id,
                output,
                is_error,
            } => {
                self.bump_count(|c| {
                    c.tool_result += 1;
                    if *is_error {
                        c.tool_errors += 1;
                    }
                });
                let acc = {
                    let mut map = self
                        .tools_in_flight
                        .lock()
                        .map_err(|error| io::Error::new(io::ErrorKind::Other, error.to_string()))?;
                    map.remove(tool_use_id)
                };
                if let Some(dir) = &self.run_dir {
                    let (name, input, started_at) = acc
                        .map(|a| (a.name, a.input, a.started_at))
                        .unwrap_or_else(|| {
                            // ToolResult without a matching ToolUse — record
                            // a sidecar with empty name/input so the on-disk
                            // record is complete, but the duration is zero.
                            (String::new(), serde_json::Value::Null, now)
                        });
                    let sidecar = RawThoughtsToolSidecar {
                        tool_use_id: tool_use_id.clone(),
                        name,
                        input,
                        output: output.clone(),
                        is_error: *is_error,
                        started_at,
                        completed_at: now,
                        duration_ms: now.saturating_sub(started_at),
                    };
                    write_tool_sidecar(dir, &sidecar)?;
                    if let Ok(mut completed) = self.completed_tools.lock() {
                        completed.push(tool_use_id.clone());
                    }
                }
            }
            RawThoughtsEvent::ReasoningSummary { .. } => {
                self.bump_count(|c| c.reasoning_summary += 1);
            }
            RawThoughtsEvent::MessageStop { stop_reason } => {
                self.bump_count(|c| c.message_stop += 1);
                if let Ok(mut last) = self.last_stop_reason.lock() {
                    *last = Some(stop_reason.clone());
                }
            }
        }
        Ok(())
    }

    fn bump_count<F: FnOnce(&mut RawThoughtsEventCounts)>(&self, f: F) {
        if let Ok(mut counts) = self.counts.lock() {
            f(&mut counts);
        }
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

        // Wave 3.1: write final.json sidecar with aggregate counts +
        // sealed thought indexes + completed tool ids. Best-effort —
        // a failure here is logged but does not propagate, matching
        // the same forgiveness applied to summary.md and links.json.
        if let Err(error) = self.write_final_sidecar(dir, &snapshot) {
            tracing::warn!(?error, "raw_thoughts: failed to write final.json");
        }

        Ok(())
    }

    /// Wave 3.1: build + serialise the `final.json` aggregate. Pulls
    /// the snapshot of every internal accumulator so the sidecar is a
    /// consistent point-in-time view of the run at finish-time.
    fn write_final_sidecar(
        &self,
        dir: &Path,
        manifest: &RawThoughtsManifest,
    ) -> io::Result<()> {
        let counts = self
            .counts
            .lock()
            .map(|c| c.clone())
            .unwrap_or_default();
        let stop_reason = self
            .last_stop_reason
            .lock()
            .ok()
            .and_then(|guard| guard.clone());
        let mut thought_indexes = self
            .sealed_thoughts
            .lock()
            .map(|s| s.clone())
            .unwrap_or_default();
        thought_indexes.sort_unstable();
        let mut tool_use_ids = self
            .completed_tools
            .lock()
            .map(|c| c.clone())
            .unwrap_or_default();
        tool_use_ids.sort_unstable();

        let ended_at = manifest.ended_at.unwrap_or_else(unix_ms_now);
        let duration_ms = ended_at.saturating_sub(manifest.started_at);

        let sidecar = RawThoughtsFinalSidecar {
            run_id: manifest.run_id.clone(),
            provider: manifest.provider.clone(),
            model: manifest.model.clone(),
            started_at: manifest.started_at,
            ended_at,
            duration_ms,
            status: manifest.status,
            stop_reason,
            event_counts: counts,
            thought_indexes,
            tool_use_ids,
        };

        let body = serde_json::to_string_pretty(&sidecar)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        fs::write(dir.join("final.json"), body)
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

/// Wave 3.1: write `thoughts/<idx>.json`. Creates the `thoughts/`
/// subfolder lazily — disabled or empty-thought runs never see it.
fn write_thought_sidecar(dir: &Path, sidecar: &RawThoughtsThoughtSidecar) -> io::Result<()> {
    let folder = dir.join("thoughts");
    fs::create_dir_all(&folder)?;
    let body = serde_json::to_string_pretty(sidecar)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
    fs::write(folder.join(format!("{}.json", sidecar.index)), body)
}

/// Wave 3.1: write `tools/<tool_use_id>.json`. The id is sanitised so a
/// pathological provider can't escape the run dir; in practice tool ids
/// from Anthropic / OpenAI are already filesystem-safe ASCII.
fn write_tool_sidecar(dir: &Path, sidecar: &RawThoughtsToolSidecar) -> io::Result<()> {
    let folder = dir.join("tools");
    fs::create_dir_all(&folder)?;
    let safe_id = sanitize_path_component(&sidecar.tool_use_id);
    let body = serde_json::to_string_pretty(sidecar)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
    fs::write(folder.join(format!("{safe_id}.json")), body)
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

    // -----------------------------------------------------------------
    // Wave 3.1 close-out tests
    // -----------------------------------------------------------------

    #[test]
    fn thoughts_sidecar_written_on_signature_seal() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_thought_seal",
            None,
        );
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: "Let me think... ".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: "the answer is 42.".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::SignatureDelta {
                index: 0,
                signature: "sig_abc123".to_string(),
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let sidecar_path = dir.join("thoughts").join("0.json");
        assert!(
            sidecar_path.exists(),
            "thoughts/0.json must be written when SignatureDelta seals index 0"
        );
        let body = fs::read_to_string(&sidecar_path).unwrap();
        let sidecar: RawThoughtsThoughtSidecar = serde_json::from_str(&body).unwrap();
        assert_eq!(sidecar.index, 0);
        assert_eq!(sidecar.thinking, "Let me think... the answer is 42.");
        assert_eq!(sidecar.signature, "sig_abc123");
        assert!(sidecar.sealed_at >= sidecar.started_at);
        disable_flag();
    }

    #[test]
    fn tools_sidecar_written_on_result_pair() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_tool_pair",
            None,
        );
        let input = serde_json::json!({"query": "kant", "limit": 3});
        emitter
            .record(RawThoughtsEvent::ToolUse {
                id: "tc_abc".to_string(),
                name: "vault_search".to_string(),
                input: input.clone(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolResult {
                tool_use_id: "tc_abc".to_string(),
                output: "found 2 notes".to_string(),
                is_error: false,
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let sidecar_path = dir.join("tools").join("tc_abc.json");
        assert!(
            sidecar_path.exists(),
            "tools/tc_abc.json must be written when ToolResult pairs with ToolUse"
        );
        let body = fs::read_to_string(&sidecar_path).unwrap();
        let sidecar: RawThoughtsToolSidecar = serde_json::from_str(&body).unwrap();
        assert_eq!(sidecar.tool_use_id, "tc_abc");
        assert_eq!(sidecar.name, "vault_search");
        assert_eq!(sidecar.input, input);
        assert_eq!(sidecar.output, "found 2 notes");
        assert!(!sidecar.is_error);
        assert!(sidecar.duration_ms >= 0);
        disable_flag();
    }

    #[test]
    fn final_json_aggregates_counts_and_indexes() {
        let _guard = env_lock();
        enable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_final_agg",
            Some("prompt_1"),
        );
        // Two sealed thoughts, one completed tool, one tool-error,
        // some text, one stop_reason.
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: "thought zero".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::SignatureDelta {
                index: 0,
                signature: "s0".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 1,
                text: "thought one".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::SignatureDelta {
                index: 1,
                signature: "s1".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolUse {
                id: "tc_ok".to_string(),
                name: "ok_tool".to_string(),
                input: serde_json::json!({}),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolResult {
                tool_use_id: "tc_ok".to_string(),
                output: "ok".to_string(),
                is_error: false,
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolUse {
                id: "tc_bad".to_string(),
                name: "bad_tool".to_string(),
                input: serde_json::json!({}),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolResult {
                tool_use_id: "tc_bad".to_string(),
                output: "err".to_string(),
                is_error: true,
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::TextDelta {
                index: 0,
                text: "12345".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::MessageStop {
                stop_reason: "end_turn".to_string(),
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        let dir = emitter.run_dir().unwrap();
        let body = fs::read_to_string(dir.join("final.json")).unwrap();
        let sidecar: RawThoughtsFinalSidecar = serde_json::from_str(&body).unwrap();

        assert_eq!(sidecar.run_id, "run_final_agg");
        assert_eq!(sidecar.provider, "anthropic");
        assert_eq!(sidecar.model, "claude-opus-4-7");
        assert!(matches!(sidecar.status, RawThoughtsStatus::Completed));
        assert_eq!(sidecar.stop_reason.as_deref(), Some("end_turn"));

        assert_eq!(sidecar.event_counts.thinking_delta, 2);
        assert_eq!(sidecar.event_counts.signature_delta, 2);
        assert_eq!(sidecar.event_counts.tool_use, 2);
        assert_eq!(sidecar.event_counts.tool_result, 2);
        assert_eq!(sidecar.event_counts.tool_errors, 1);
        assert_eq!(sidecar.event_counts.text_delta, 1);
        assert_eq!(sidecar.event_counts.text_chars, 5);
        assert_eq!(sidecar.event_counts.message_stop, 1);

        assert_eq!(sidecar.thought_indexes, vec![0, 1]);
        assert_eq!(sidecar.tool_use_ids, vec!["tc_bad".to_string(), "tc_ok".to_string()]);

        assert!(sidecar.duration_ms >= 0);
        assert!(sidecar.ended_at >= sidecar.started_at);

        // Confirm the per-item sidecars also landed.
        assert!(dir.join("thoughts").join("0.json").exists());
        assert!(dir.join("thoughts").join("1.json").exists());
        assert!(dir.join("tools").join("tc_ok.json").exists());
        assert!(dir.join("tools").join("tc_bad.json").exists());

        disable_flag();
    }

    #[test]
    fn close_out_state_disabled_emitter_is_inert() {
        let _guard = env_lock();
        disable_flag();
        let tmp = TempDir::new().unwrap();
        let emitter = RawThoughtsEmitter::new(
            tmp.path(),
            "anthropic",
            "claude-opus-4-7",
            "run_disabled_close_out",
            None,
        );
        // Drive a full cycle through every event type.
        emitter
            .record(RawThoughtsEvent::ThinkingDelta {
                index: 0,
                text: "x".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::SignatureDelta {
                index: 0,
                signature: "y".to_string(),
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolUse {
                id: "z".to_string(),
                name: "n".to_string(),
                input: serde_json::Value::Null,
            })
            .unwrap();
        emitter
            .record(RawThoughtsEvent::ToolResult {
                tool_use_id: "z".to_string(),
                output: "o".to_string(),
                is_error: false,
            })
            .unwrap();
        emitter.finish(RawThoughtsStatus::Completed, None).unwrap();

        // No folder, no sidecars — disabled emitter never touches disk.
        let raw_thoughts_dir = tmp.path().join("Raw Thoughts");
        assert!(
            !raw_thoughts_dir.exists(),
            "disabled emitter must not create the run root even with close-out events"
        );
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
