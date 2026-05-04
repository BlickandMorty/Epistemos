// HARDENING ENFORCEMENT: this CLI is the open-standard contract surface.
// A panic during verify means `epistemos-trace` exits non-zero with
// uncaught-panic in stderr, which a CI consumer would interpret as a
// system failure — not a bundle failure. Every error path returns a
// typed exit code instead. No unwrap/expect/panic in production paths.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! `epistemos-trace` — Phase-1 / parallel-track CLI verifier for `.epbundle`
//! ReplayBundle artifacts.
//!
//! Doctrine reference: `docs/plan/04_PHASES.md` §"Parallel Track — Open
//! Provenance Standard" — "Standard skeleton" milestone calls for an
//! `epistemos-trace verify` CLI that reads a bundle, validates the
//! integrity hash chain, and exits 0 on success / non-zero on failure.
//! `04_PHASES.md` Phase-1 task 6 also names this binary as the consumer
//! that proves the agent's `ReplayBundle::build()` round-trip.
//!
//! The CLI is deliberately tiny — no `clap`, no async runtime, no
//! `serde_yaml`. Just std + the local agent_core crate. SARIF output
//! and conformance-suite integration land in Phase 2.
//!
//! ## Usage
//!
//!   epistemos-trace verify <path/to/bundle.epbundle>
//!   epistemos-trace --version
//!   epistemos-trace --help
//!
//! ## Exit codes
//!
//!   0  — bundle parsed AND integrity hash matches
//!   1  — usage error (missing arg, bad subcommand)
//!   2  — file not found / unreadable
//!   3  — JSON parse error (malformed bundle)
//!   4  — integrity hash mismatch (tampering detected)

use std::process::ExitCode;

use agent_core::provenance::ReplayBundle;

const USAGE: &str = "\
epistemos-trace — verifier for Epistemos .epbundle replay artifacts

USAGE:
  epistemos-trace verify <path>      Verify a bundle's integrity hash.
  epistemos-trace --version          Print version and exit.
  epistemos-trace --help             Print this help and exit.

EXIT CODES:
  0  bundle integrity verified
  1  usage error
  2  io error (file not found / unreadable)
  3  parse error (malformed bundle)
  4  integrity mismatch (tampering detected)
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let argv = args.iter().map(String::as_str).collect::<Vec<_>>();

    match argv.as_slice() {
        [_] => {
            eprintln!("{USAGE}");
            ExitCode::from(1)
        }
        [_, "--help" | "-h" | "help"] => {
            println!("{USAGE}");
            ExitCode::SUCCESS
        }
        [_, "--version" | "-V"] => {
            println!("epistemos-trace {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
        [_, "verify", path] => verify(path),
        _ => {
            eprintln!("error: unknown invocation\n\n{USAGE}");
            ExitCode::from(1)
        }
    }
}

fn verify(path: &str) -> ExitCode {
    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("error: cannot read `{path}`: {e}");
            return ExitCode::from(2);
        }
    };
    let bundle = match ReplayBundle::from_epbundle_bytes(&bytes) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("error: bundle parse failed: {e}");
            return ExitCode::from(3);
        }
    };
    match bundle.verify_integrity() {
        Ok(()) => {
            println!(
                "ok  bundle_id={} schema_version={} mutations={} claims={} evidence={}",
                bundle.bundle_id,
                bundle.schema_version,
                bundle.mutations.len(),
                bundle.ledger.claims.len(),
                bundle.ledger.evidence.len(),
            );
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("error: integrity verification failed: {e}");
            ExitCode::from(4)
        }
    }
}
