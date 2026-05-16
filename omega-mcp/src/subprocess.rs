//! Hardened subprocess construction for omega-mcp Pro-only wrappers.

use std::process::Command;

const SUBPROCESS_ALLOWLIST: &[&str] = &[
    "PATH",
    "HOME",
    "USER",
    "LOGNAME",
    "LANG",
    "LC_ALL",
    "LC_CTYPE",
    "LC_MESSAGES",
    "TERM",
    "SHELL",
    "TMPDIR",
    "__CF_USER_TEXT_ENCODING",
];

const SUBPROCESS_DENYLIST: &[&str] = &[
    "OPENAI_API_KEY",
    "OPENAI_ACCESS_TOKEN",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_ACCESS_TOKEN",
    "GOOGLE_API_KEY",
    "GOOGLE_ACCESS_TOKEN",
    "GEMINI_API_KEY",
    "PERPLEXITY_API_KEY",
    "OPENROUTER_API_KEY",
    "MOONSHOT_API_KEY",
    "CODESTRAL_API_KEY",
    "MISTRAL_API_KEY",
    "XAI_API_KEY",
    "TOGETHER_API_KEY",
    "HF_TOKEN",
];

pub(crate) fn hardened_command(program: &str) -> Command {
    let mut command = Command::new(program);
    command.env_clear();
    for &key in SUBPROCESS_ALLOWLIST {
        if SUBPROCESS_DENYLIST.contains(&key) {
            continue;
        }
        if let Ok(value) = std::env::var(key) {
            command.env(key, value);
        }
    }
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }
    command
}
