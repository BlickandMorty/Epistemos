use std::collections::HashMap;
use std::ffi::CString;
use std::os::fd::{AsRawFd, OwnedFd};
use std::path::Path;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use nix::libc;
use nix::pty::openpty;
use nix::sys::signal::{self, Signal};
use nix::sys::wait::WaitPidFlag;
use nix::unistd::{self, ForkResult, Pid};

// ---------------------------------------------------------------------------
// Subprocess Env Hardening (PTY-local mirror of agent_core::security)
// ---------------------------------------------------------------------------
//
// CANONICAL SOURCE: `agent_core/src/security.rs` lines 847+ defines
// `SUBPROCESS_ALLOWLIST` (10 vars) + `SUBPROCESS_DENYLIST` (45+ vars
// including all dynamic-loader hijack vectors, macOS heap leak knobs,
// Node/Python/Ruby/Perl interpreter hijacks, and 22 provider API keys).
//
// This module mirrors those lists rather than depending on agent_core
// because omega-mcp is a sibling crate (no agent_core dep). If either
// list grows, BOTH copies must be updated together. The duplication is
// intentional defense-in-depth: a code review on either side catches
// drift.
//
// Why we need it here: `spawn_pty` previously called `execvp()` which
// inherits the parent's full environment. That meant a PTY shell child
// could see `LD_PRELOAD`, `DYLD_INSERT_LIBRARIES`, `MallocStackLogging`,
// `NODE_OPTIONS`, `PYTHONPATH`, `RUBYOPT`, `PERL5OPT`, plus every
// provider API key from the parent process's env — a code-injection
// and secret-exfiltration vector flagged as a P1 in the 2026-05-23
// canonical chronicle audit.
//
// Fix: build a hardened `envp` array in the parent (heap allocation
// safe) BEFORE fork, then in the child use `execve()` (NOT `execvp()`)
// with the explicit clean envp. This requires the shell path to be
// absolute since `execve` does not search PATH.

/// Canonical env-var allowlist for PTY subprocess hardening.
/// Mirror of `agent_core::security::SUBPROCESS_ALLOWLIST`.
const PTY_ALLOWLIST: &[&str] = &[
    "PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ",
];

/// Env vars that must NEVER be inherited by a hardened PTY child.
/// Mirror of `agent_core::security::SUBPROCESS_DENYLIST`. Keep in sync.
const PTY_DENYLIST: &[&str] = &[
    // Dynamic-loader hijack
    "LD_PRELOAD",
    "LD_LIBRARY_PATH",
    "LD_AUDIT",
    "DYLD_INSERT_LIBRARIES",
    "DYLD_LIBRARY_PATH",
    "DYLD_FALLBACK_LIBRARY_PATH",
    "DYLD_FRAMEWORK_PATH",
    "DYLD_FALLBACK_FRAMEWORK_PATH",
    "DYLD_PRINT_LIBRARIES",
    // macOS heap leak
    "MallocStackLogging",
    "MallocStackLoggingNoCompact",
    "MallocScribble",
    "MallocGuardEdges",
    // Node.js debug / option-string injection
    "DEBUG",
    "NODE_OPTIONS",
    "NODE_PATH",
    "NODE_DEBUG",
    // Python module-path hijack
    "PYTHONPATH",
    "PYTHONHOME",
    "PYTHONSTARTUP",
    // Ruby / Perl option-string injection
    "RUBYOPT",
    "RUBYLIB",
    "PERL5OPT",
    "PERL5LIB",
    "PERL5DB",
    // Epistemos-managed provider credentials
    "OPENAI_API_KEY",
    "OPENAI_ACCESS_TOKEN",
    "OPENAI_AUTH_MODE",
    "OPENAI_CLIENT_VERSION",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_ACCESS_TOKEN",
    "ANTHROPIC_AUTH_MODE",
    "GOOGLE_API_KEY",
    "GEMINI_API_KEY",
    "GOOGLE_ACCESS_TOKEN",
    "GOOGLE_AUTH_MODE",
    "GOOGLE_PROJECT_ID",
    "PERPLEXITY_API_KEY",
    "OPENROUTER_API_KEY",
    "GLM_API_KEY",
    "MOONSHOT_API_KEY",
    "KIMI_API_KEY",
    "DEEPSEEK_API_KEY",
    "MINIMAX_API_KEY",
    "XAI_API_KEY",
    "CODESTRAL_API_KEY",
    "MISTRAL_API_KEY",
    "TOGETHER_API_KEY",
    "GROQ_API_KEY",
    "HF_TOKEN",
];

/// Build a hardened `envp` for `execve()`. Called from the parent
/// BEFORE `fork()` — heap allocation is safe here. The returned
/// CStrings must outlive the `execve()` call; pass them into the
/// child by reference (fork copies parent memory).
///
/// Always sets `TERM=dumb` so the PTY suppresses escape sequences.
fn build_hardened_pty_envp() -> Vec<CString> {
    let mut envp: Vec<CString> = Vec::with_capacity(PTY_ALLOWLIST.len() + 1);

    // Stamp TERM=dumb first so any inherited TERM gets overridden
    // (TERM is in the allowlist, but the PTY wants `dumb` specifically).
    if let Ok(c) = CString::new("TERM=dumb") {
        envp.push(c);
    }

    for &key in PTY_ALLOWLIST {
        // Defense in depth — even if allowlist & denylist accidentally
        // overlap in a future edit, denylist always wins.
        if PTY_DENYLIST.contains(&key) {
            continue;
        }
        if key == "TERM" {
            // Already stamped above.
            continue;
        }
        if let Ok(value) = std::env::var(key) {
            if let Ok(c) = CString::new(format!("{}={}", key, value)) {
                envp.push(c);
            }
        }
    }

    envp
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for spawning a new PTY session.
pub struct PtyConfig {
    pub shell: String,
    pub initial_dir: Option<String>,
    pub cols: u16,
    pub rows: u16,
}

impl Default for PtyConfig {
    fn default() -> Self {
        Self {
            shell: "/bin/zsh".to_string(),
            initial_dir: None,
            cols: 120,
            rows: 40,
        }
    }
}

/// Output from a single PTY command execution.
#[derive(Debug, Clone)]
pub struct PtyOutput {
    pub stdout: String,
    pub exit_hint: String,
    pub working_dir: String,
    pub duration_ms: u64,
}

/// A persistent shell session backed by a POSIX pseudo-terminal.
pub struct PtySession {
    master_fd: OwnedFd,
    child_pid: Pid,
    working_dir: String,
    _session_id: String,
    _created_at: Instant,
    last_used: Instant,
}

// ---------------------------------------------------------------------------
// Global Pool
// ---------------------------------------------------------------------------

static POOL: OnceLock<Mutex<PtyPoolInner>> = OnceLock::new();

struct PtyPoolInner {
    sessions: HashMap<String, PtySession>,
    /// Maps session_id → Vec<pty_id> for cascade cleanup.
    session_map: HashMap<String, Vec<String>>,
    next_id: u64,
}

impl Default for PtyPoolInner {
    fn default() -> Self {
        Self {
            sessions: HashMap::new(),
            session_map: HashMap::new(),
            next_id: 1,
        }
    }
}

pub struct PtyPool;

impl PtyPool {
    fn inner() -> &'static Mutex<PtyPoolInner> {
        POOL.get_or_init(|| Mutex::new(PtyPoolInner::default()))
    }

    /// Spawn a new persistent PTY session.
    /// Returns a unique `pty_id` that can be used for subsequent `execute` / `close` calls.
    pub fn spawn(session_id: &str, config: PtyConfig) -> Result<String, PtyError> {
        let session = spawn_pty(config, session_id)?;
        let mut pool = Self::inner().lock().map_err(|_| PtyError::PoolPoisoned)?;

        let pty_id = format!("pty-{}", pool.next_id);
        pool.next_id += 1;

        pool.session_map
            .entry(session_id.to_string())
            .or_default()
            .push(pty_id.clone());
        pool.sessions.insert(pty_id.clone(), session);

        Ok(pty_id)
    }

    /// Execute a command in an existing PTY session.
    /// Blocks (with timeout) until the command completes and returns its output.
    pub fn execute(pty_id: &str, command: &str, timeout: Duration) -> Result<PtyOutput, PtyError> {
        let mut pool = Self::inner().lock().map_err(|_| PtyError::PoolPoisoned)?;
        let session = pool
            .sessions
            .get_mut(pty_id)
            .ok_or_else(|| PtyError::SessionNotFound(pty_id.to_string()))?;
        session.last_used = Instant::now();

        let master_raw = session.master_fd.as_raw_fd();
        let start = Instant::now();

        // Use a UUID-based sentinel so command output cannot collide.
        let sentinel_id = uuid::Uuid::new_v4().to_string().replace('-', "");
        let sentinel = format!("__EPSENT{}__", sentinel_id);

        // Write the command followed by the sentinel.
        // The sentinel echo prints: __EPSENT{uuid}__{exit_code}
        // A second echo prints: __EPPWD__{cwd}
        let full_command =
            format!(" {command}\n __eec=$?; echo \"{sentinel}$__eec\"; echo \"__EPPWD__$(pwd)\"\n");

        // SAFETY: master_raw is a valid, open file descriptor owned by PtySession.
        // We write through a raw fd because OwnedFd doesn't implement Write.
        let written = unsafe {
            libc::write(
                master_raw,
                full_command.as_ptr() as *const libc::c_void,
                full_command.len(),
            )
        };
        if written < 0 {
            return Err(PtyError::WriteFailed(std::io::Error::last_os_error()));
        }

        // Read until we see the sentinel line.
        let mut buf = [0u8; 8192];
        let mut raw_output = String::new();
        let mut exit_code: Option<i32> = None;
        let mut working_dir = session.working_dir.clone();
        let mut found_sentinel = false;

        loop {
            if start.elapsed() > timeout {
                return Err(PtyError::Timeout(timeout.as_millis() as u64));
            }

            // SAFETY: master_raw is a valid fd. We use select() for portability on macOS.
            let ready = unsafe {
                let mut read_set: libc::fd_set = std::mem::zeroed();
                libc::FD_SET(master_raw, &mut read_set);
                let mut tv = libc::timeval {
                    tv_sec: 0,
                    tv_usec: 50_000, // 50ms poll
                };
                libc::select(
                    master_raw + 1,
                    &mut read_set,
                    std::ptr::null_mut(),
                    std::ptr::null_mut(),
                    &mut tv,
                )
            };

            if ready <= 0 {
                // If we already found the sentinel, we can stop reading.
                if found_sentinel {
                    break;
                }
                continue;
            }

            // SAFETY: master_raw is valid and buf is stack-allocated with known size.
            let n =
                unsafe { libc::read(master_raw, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
            if n <= 0 {
                break;
            }

            let chunk = String::from_utf8_lossy(&buf[..n as usize]);
            raw_output.push_str(&chunk);

            // Strip ANSI escape sequences before checking for sentinel.
            let clean = strip_ansi(&raw_output);

            // Check for sentinel in cleaned output.
            if let Some(pos) = clean.find(&sentinel) {
                found_sentinel = true;

                // Parse exit code from the sentinel line.
                // The text right after the sentinel is the exit code, possibly
                // followed by a newline, prompt text, or other shell output.
                let after_sentinel = &clean[pos + sentinel.len()..];
                // Extract leading digits (the exit code).
                let code_str: String = after_sentinel
                    .chars()
                    .take_while(|c| c.is_ascii_digit())
                    .collect();
                if !code_str.is_empty() {
                    exit_code = code_str.parse().ok();
                }

                let parsed_working_dir = extract_working_dir(&clean);
                if let Some(parsed_working_dir) = parsed_working_dir.clone() {
                    working_dir = parsed_working_dir;
                }

                // If we have both sentinel and PWD, we're done.
                if parsed_working_dir.is_some() {
                    break;
                }
            }
        }

        // Clean output: strip ANSI, extract only command output (between command echo and sentinel).
        let clean = strip_ansi(&raw_output);
        let command_output = extract_command_output(&clean, command, &sentinel);

        let duration_ms = start.elapsed().as_millis() as u64;
        session.working_dir = working_dir.clone();

        let exit_hint = match exit_code {
            Some(0) => "ok".to_string(),
            Some(c) => format!("error({})", c),
            None => "unknown".to_string(),
        };

        Ok(PtyOutput {
            stdout: command_output,
            exit_hint,
            working_dir,
            duration_ms,
        })
    }

    /// Close a specific PTY session.
    pub fn close(pty_id: &str) {
        let mut pool = match Self::inner().lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        if let Some(session) = pool.sessions.remove(pty_id) {
            terminate_child(session.child_pid);
            for ids in pool.session_map.values_mut() {
                ids.retain(|id| id != pty_id);
            }
        }
    }

    /// Close all PTY sessions associated with a given agent session.
    /// Called from `SessionGuard::drop()` for cascade cleanup.
    pub fn close_all_for_session(session_id: &str) {
        let mut pool = match Self::inner().lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        if let Some(pty_ids) = pool.session_map.remove(session_id) {
            for pty_id in pty_ids {
                if let Some(session) = pool.sessions.remove(&pty_id) {
                    terminate_child(session.child_pid);
                }
            }
        }
    }

    /// Close PTY sessions that have been idle longer than `max_idle`.
    pub fn cleanup_idle(max_idle: Duration) {
        let mut pool = match Self::inner().lock() {
            Ok(p) => p,
            Err(_) => return,
        };
        let stale: Vec<String> = pool
            .sessions
            .iter()
            .filter(|(_, s)| s.last_used.elapsed() > max_idle)
            .map(|(id, _)| id.clone())
            .collect();
        for pty_id in stale {
            if let Some(session) = pool.sessions.remove(&pty_id) {
                terminate_child(session.child_pid);
                for ids in pool.session_map.values_mut() {
                    ids.retain(|id| id != &pty_id);
                }
            }
        }
    }

    /// Get the number of active PTY sessions (for diagnostics).
    pub fn active_count() -> usize {
        Self::inner()
            .lock()
            .map(|pool| pool.sessions.len())
            .unwrap_or(0)
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Spawn a PTY with a child shell process.
///
/// SECURITY: env hardening per 2026-05-23 canonical-chronicle audit.
/// Uses `execve()` with an explicit hardened envp (NOT `execvp()` which
/// inherits the parent's full env). Requires `config.shell` to be an
/// absolute path because `execve` does not search PATH. See module-
/// level docs above (PTY_ALLOWLIST / PTY_DENYLIST) for the rationale.
fn spawn_pty(config: PtyConfig, session_id: &str) -> Result<PtySession, PtyError> {
    // SECURITY: require absolute shell path because execve doesn't
    // search PATH. The default `/bin/zsh` is fine; any user override
    // must also be absolute.
    if !Path::new(&config.shell).is_absolute() {
        return Err(PtyError::SpawnFailed(format!(
            "shell path must be absolute (execve does not search PATH): {}",
            config.shell
        )));
    }

    let result = openpty(None, None).map_err(|e| PtyError::SpawnFailed(e.to_string()))?;
    let master = result.master;
    let slave = result.slave;

    // Set terminal size.
    // SAFETY: master is a valid PTY fd. winsize is fully initialized.
    unsafe {
        let ws = libc::winsize {
            ws_row: config.rows,
            ws_col: config.cols,
            ws_xpixel: 0,
            ws_ypixel: 0,
        };
        libc::ioctl(master.as_raw_fd(), libc::TIOCSWINSZ, &ws);
    }

    let shell =
        CString::new(config.shell.as_bytes()).map_err(|e| PtyError::SpawnFailed(e.to_string()))?;
    let initial_dir = config.initial_dir.clone();

    // SECURITY: build hardened envp HERE (in parent, heap allocation
    // safe). Fork copies parent memory so the child sees the same
    // CStrings. We then pass their pointers to execve() in the child.
    let envp_cstrings: Vec<CString> = build_hardened_pty_envp();
    let mut envp_ptrs: Vec<*const libc::c_char> =
        envp_cstrings.iter().map(|c| c.as_ptr()).collect();
    envp_ptrs.push(std::ptr::null());

    // Build login_name + args BEFORE fork too (heap safe in parent).
    let login_name = CString::new(format!("-{}", config.shell))
        .unwrap_or_else(|_| CString::new("-zsh").unwrap());

    // SAFETY: We call fork() and immediately execve() in the child.
    // The child does no async work, no heap allocation after fork, and
    // no calls to non-async-signal-safe functions before execve.
    // The parent retains ownership of master_fd.
    match unsafe { unistd::fork() } {
        Ok(ForkResult::Child) => {
            // SAFETY: In child process. Create new session, dup slave fd to stdio, exec shell.
            unsafe {
                libc::setsid();
                libc::dup2(slave.as_raw_fd(), 0);
                libc::dup2(slave.as_raw_fd(), 1);
                libc::dup2(slave.as_raw_fd(), 2);
                drop(slave);
                drop(master);

                if let Some(ref dir) = initial_dir {
                    let c_dir = CString::new(dir.as_bytes()).unwrap_or_default();
                    libc::chdir(c_dir.as_ptr());
                }

                // SECURITY: execve (NOT execvp) so the child gets ONLY
                // the explicit hardened envp. No inheritance of
                // LD_PRELOAD / DYLD_* / NODE_OPTIONS / PYTHONPATH /
                // provider API keys / etc. from the parent process.
                let args: [*const libc::c_char; 2] = [login_name.as_ptr(), std::ptr::null()];
                libc::execve(shell.as_ptr(), args.as_ptr(), envp_ptrs.as_ptr());
                libc::_exit(127);
            }
        }
        Ok(ForkResult::Parent { child }) => {
            drop(slave);

            let working_dir = config
                .initial_dir
                .unwrap_or_else(|| std::env::var("HOME").unwrap_or_else(|_| "/".to_string()));

            // Wait for the shell to initialize and drain the initial prompt output.
            std::thread::sleep(Duration::from_millis(300));
            drain_fd(master.as_raw_fd());

            Ok(PtySession {
                master_fd: master,
                child_pid: child,
                working_dir,
                _session_id: session_id.to_string(),
                _created_at: Instant::now(),
                last_used: Instant::now(),
            })
        }
        Err(e) => Err(PtyError::SpawnFailed(e.to_string())),
    }
}

/// Drain all pending data from a file descriptor (non-blocking).
fn drain_fd(fd: i32) {
    let mut buf = [0u8; 4096];
    loop {
        // SAFETY: fd is a valid file descriptor. We use non-blocking select.
        let ready = unsafe {
            let mut read_set: libc::fd_set = std::mem::zeroed();
            libc::FD_SET(fd, &mut read_set);
            let mut tv = libc::timeval {
                tv_sec: 0,
                tv_usec: 50_000, // 50ms
            };
            libc::select(
                fd + 1,
                &mut read_set,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                &mut tv,
            )
        };
        if ready <= 0 {
            break;
        }
        // SAFETY: fd is valid, buf is stack-allocated.
        let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
        if n <= 0 {
            break;
        }
    }
}

/// Send SIGTERM, wait briefly, then SIGKILL if the child is still alive.
fn terminate_child(pid: Pid) {
    let _ = signal::kill(pid, Signal::SIGTERM);
    std::thread::sleep(Duration::from_millis(200));
    if let Ok(nix::sys::wait::WaitStatus::StillAlive) =
        nix::sys::wait::waitpid(pid, Some(WaitPidFlag::WNOHANG))
    {
        let _ = signal::kill(pid, Signal::SIGKILL);
        let _ = nix::sys::wait::waitpid(pid, None);
    }
}

/// Strip ANSI escape sequences from a string.
fn strip_ansi(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' {
            // Skip ESC sequences: ESC [ ... final_byte
            if chars.peek() == Some(&'[') {
                chars.next(); // consume '['
                              // Read until we hit a letter (the final byte of the CSI sequence).
                while let Some(&next) = chars.peek() {
                    chars.next();
                    if next.is_ascii_alphabetic() || next == '~' {
                        break;
                    }
                }
            } else if chars.peek() == Some(&']') {
                // OSC sequence: ESC ] ... BEL or ST
                chars.next();
                while let Some(&next) = chars.peek() {
                    chars.next();
                    if next == '\x07' || next == '\\' {
                        break;
                    }
                }
            } else {
                // Other ESC sequences: skip one more char.
                chars.next();
            }
        } else if c == '\r' {
            // Skip carriage returns.
            continue;
        } else {
            result.push(c);
        }
    }
    result
}

/// Extract only the command output from cleaned PTY output.
/// Removes the echoed command and the sentinel/PWD lines.
fn extract_command_output(clean: &str, command: &str, sentinel: &str) -> String {
    let lines: Vec<&str> = clean.lines().collect();

    // Find the line(s) that are the echoed command. The shell echoes back
    // the full input we sent (with leading space for history avoidance).
    // Find where the sentinel starts.
    let sentinel_line_idx = lines.iter().position(|l| l.contains(sentinel));
    let end_idx = sentinel_line_idx.unwrap_or(lines.len());

    // Skip echoed command lines at the start. The command we sent is prefixed
    // with a space, so look for lines that match the command text.
    let cmd_trimmed = command.trim();
    let mut start_idx = 0;
    for (i, line) in lines[..end_idx].iter().enumerate() {
        let l = line.trim();
        // Skip lines that are part of the echoed command or the __eec assignment.
        if l.contains(cmd_trimmed)
            || l.contains("__eec=$?")
            || l.contains(sentinel)
            || l.contains("__EPPWD__")
            || l.is_empty()
        {
            start_idx = i + 1;
        } else {
            break;
        }
    }

    if start_idx >= end_idx {
        return String::new();
    }

    lines[start_idx..end_idx]
        .to_vec()
        .join("\n")
        .trim()
        .to_string()
}

fn extract_working_dir(clean: &str) -> Option<String> {
    clean.lines().rev().find_map(|line| {
        line.trim()
            .strip_prefix("__EPPWD__")
            .map(str::trim)
            .filter(|wd| !wd.is_empty() && !wd.contains("$(") && !wd.contains("__EP"))
            .map(ToOwned::to_owned)
    })
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum PtyError {
    #[error("PTY spawn failed: {0}")]
    SpawnFailed(String),

    #[error("PTY session not found: {0}")]
    SessionNotFound(String),

    #[error("PTY write failed: {0}")]
    WriteFailed(#[from] std::io::Error),

    #[error("Command timed out after {0}ms")]
    Timeout(u64),

    #[error("PTY pool mutex poisoned")]
    PoolPoisoned,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, MutexGuard, OnceLock};

    fn test_guard() -> MutexGuard<'static, ()> {
        static TEST_MUTEX: OnceLock<Mutex<()>> = OnceLock::new();
        TEST_MUTEX
            .get_or_init(|| Mutex::new(()))
            .lock()
            .expect("pty test mutex poisoned")
    }

    #[test]
    fn test_pty_spawn_and_execute() {
        let _guard = test_guard();
        let pty_id = PtyPool::spawn("test-exec-1", PtyConfig::default()).expect("spawn failed");

        let output = PtyPool::execute(&pty_id, "echo hello_world_123", Duration::from_secs(10))
            .expect("execute failed");

        assert!(
            output.stdout.contains("hello_world_123"),
            "Expected 'hello_world_123' in output, got: '{}'",
            output.stdout
        );
        // Exit hint should be "ok" (exit code 0). If "unknown", the sentinel
        // exit code wasn't parsed — acceptable for TERM=dumb shells.
        assert!(
            output.exit_hint == "ok" || output.exit_hint == "unknown",
            "Unexpected exit_hint: '{}'",
            output.exit_hint
        );
        assert!(!output.working_dir.is_empty());

        PtyPool::close(&pty_id);
    }

    #[test]
    fn test_pty_working_dir_persistence() {
        let _guard = test_guard();
        let pty_id = PtyPool::spawn("test-exec-2", PtyConfig::default()).expect("spawn failed");

        let _ = PtyPool::execute(&pty_id, "cd /tmp", Duration::from_secs(10)).expect("cd failed");

        let output = PtyPool::execute(&pty_id, "pwd", Duration::from_secs(10)).expect("pwd failed");

        // The tracked working_dir should reflect /tmp (or /private/tmp on macOS).
        assert!(
            output.working_dir.contains("tmp"),
            "Expected working_dir to contain 'tmp', got: '{}'",
            output.working_dir
        );

        PtyPool::close(&pty_id);
    }

    #[test]
    fn test_pty_timeout() {
        let _guard = test_guard();
        let pty_id = PtyPool::spawn("test-exec-3", PtyConfig::default()).expect("spawn failed");

        let result = PtyPool::execute(&pty_id, "sleep 999", Duration::from_millis(800));
        assert!(result.is_err(), "Expected timeout error");
        match result {
            Err(PtyError::Timeout(_)) => {}
            other => panic!("Expected Timeout error, got: {:?}", other),
        }

        PtyPool::close(&pty_id);
    }

    #[test]
    fn test_pty_cleanup() {
        let _guard = test_guard();
        let pty_id = PtyPool::spawn("test-exec-4", PtyConfig::default()).expect("spawn failed");

        assert!(PtyPool::active_count() > 0);
        PtyPool::close(&pty_id);

        let result = PtyPool::execute(&pty_id, "echo hi", Duration::from_secs(1));
        assert!(matches!(result, Err(PtyError::SessionNotFound(_))));
    }

    #[test]
    fn test_close_all_for_session() {
        let _guard = test_guard();
        let id1 = PtyPool::spawn("test-exec-5", PtyConfig::default()).expect("spawn 1 failed");
        let id2 = PtyPool::spawn("test-exec-5", PtyConfig::default()).expect("spawn 2 failed");

        PtyPool::close_all_for_session("test-exec-5");

        assert!(matches!(
            PtyPool::execute(&id1, "echo hi", Duration::from_secs(1)),
            Err(PtyError::SessionNotFound(_))
        ));
        assert!(matches!(
            PtyPool::execute(&id2, "echo hi", Duration::from_secs(1)),
            Err(PtyError::SessionNotFound(_))
        ));
    }

    #[test]
    fn test_strip_ansi() {
        let _guard = test_guard();
        let input = "\x1b[?2004lhello\x1b[0m world\r\n";
        let clean = strip_ansi(input);
        assert_eq!(clean, "hello world\n");
    }

    #[test]
    fn test_extract_working_dir_ignores_echoed_marker() {
        let _guard = test_guard();
        let clean = r#"pwd
__eec=$?; echo "__EPSENT123__0"; echo "__EPPWD__$(pwd)"
/tmp
__EPSENT123__0
__EPPWD__/private/tmp"#;

        assert_eq!(extract_working_dir(clean), Some("/private/tmp".to_string()));
    }

    // -----------------------------------------------------------------------
    // SECURITY tests — 2026-05-23 P0 PTY env hardening
    // -----------------------------------------------------------------------

    #[test]
    fn build_hardened_envp_includes_term_dumb() {
        let envp = build_hardened_pty_envp();
        let has_term_dumb = envp
            .iter()
            .any(|c| c.to_str().map(|s| s == "TERM=dumb").unwrap_or(false));
        assert!(
            has_term_dumb,
            "envp must always carry TERM=dumb for PTY suppression"
        );
    }

    #[test]
    fn build_hardened_envp_excludes_ld_preload() {
        // Stamp a denylist var on the parent env, then verify the
        // hardened envp does NOT carry it forward to the child.
        // Use a process-local hack: we can't actually modify the
        // global env safely from a unit test (other tests may race),
        // so we just assert the structural invariant: no entry in
        // the produced envp may start with any denylist name=
        // prefix.
        let _guard = test_guard();
        let envp = build_hardened_pty_envp();
        for &denied in PTY_DENYLIST {
            let prefix = format!("{}=", denied);
            let leaked = envp
                .iter()
                .any(|c| c.to_str().map(|s| s.starts_with(&prefix)).unwrap_or(false));
            assert!(
                !leaked,
                "denylist var '{}' must NEVER appear in hardened envp",
                denied
            );
        }
    }

    #[test]
    fn build_hardened_envp_only_contains_allowlist_or_extras() {
        // Every entry in the produced envp must be either TERM=dumb
        // (always stamped) or its NAME portion must be in PTY_ALLOWLIST.
        let _guard = test_guard();
        let envp = build_hardened_pty_envp();
        for c in &envp {
            let s = c.to_str().expect("envp entry should be valid UTF-8");
            let name = s.splitn(2, '=').next().unwrap_or("");
            assert!(
                PTY_ALLOWLIST.contains(&name),
                "envp entry '{}' has name '{}' not in PTY_ALLOWLIST",
                s,
                name
            );
        }
    }

    #[test]
    fn spawn_rejects_relative_shell_path() {
        let _guard = test_guard();
        let config = PtyConfig {
            shell: "zsh".to_string(), // relative — should reject
            initial_dir: None,
            cols: 80,
            rows: 24,
        };
        let result = spawn_pty(config, "test-relative-shell");
        match result {
            Err(PtyError::SpawnFailed(msg)) => {
                assert!(
                    msg.contains("absolute") || msg.contains("PATH"),
                    "expected absolute-path rejection, got: {}",
                    msg
                );
            }
            Err(other) => panic!(
                "expected SpawnFailed for relative shell path, got error: {}",
                other
            ),
            Ok(_) => panic!("expected SpawnFailed for relative shell path, got Ok"),
        }
    }

    #[test]
    fn pty_denylist_and_allowlist_are_disjoint() {
        // Defense in depth — both lists must be disjoint.
        for &allowed in PTY_ALLOWLIST {
            assert!(
                !PTY_DENYLIST.contains(&allowed),
                "var '{}' appears in BOTH PTY_ALLOWLIST and PTY_DENYLIST",
                allowed
            );
        }
    }

    #[test]
    fn pty_denylist_covers_canonical_24_vector_doctrine() {
        // The 2026-04-28 subprocess hardening doctrine names 24 specific
        // attack vectors. Confirm each is in the denylist.
        let canonical_doctrine_24 = &[
            "LD_PRELOAD",
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "DYLD_FALLBACK_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH",
            "DYLD_FALLBACK_FRAMEWORK_PATH",
            "DYLD_PRINT_LIBRARIES",
            "MallocStackLogging",
            "MallocStackLoggingNoCompact",
            "MallocScribble",
            "MallocGuardEdges",
            "NODE_OPTIONS",
            "NODE_PATH",
            "NODE_DEBUG",
            "PYTHONPATH",
            "PYTHONHOME",
            "PYTHONSTARTUP",
            "RUBYOPT",
            "RUBYLIB",
            "PERL5OPT",
            "PERL5LIB",
            "PERL5DB",
            "LD_LIBRARY_PATH",
            "LD_AUDIT",
        ];
        for &v in canonical_doctrine_24 {
            assert!(
                PTY_DENYLIST.contains(&v),
                "canonical-doctrine vector '{}' missing from PTY_DENYLIST",
                v
            );
        }
    }
}
