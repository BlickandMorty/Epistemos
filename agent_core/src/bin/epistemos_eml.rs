// HARDENING ENFORCEMENT: this CLI is the ops contract surface for
// the EML diagnostic read-out. A panic during `diagnostic` means
// `epistemos_eml` exits non-zero with uncaught-panic in stderr,
// which a CI consumer would interpret as a system failure — not a
// EML-substrate failure. Every error path returns a typed exit code
// instead. No unwrap/expect/panic in production paths.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! `epistemos_eml` — T7 §4.B ops/diagnostic CLI for the EML
//! Integration substrate.
//!
//! Mirror of the `epistemos_trace` pattern: tiny, no clap, no async,
//! no serde_yaml. Just std + the local agent_core crate. Prints the
//! `EmlEnergyDiagnostic` payload as JSON so an ops engineer can sanity-
//! check the substrate without launching the app.
//!
//! Doctrine reference:
//! - `docs/audits/EML_AUDIT_OF_AUDIT_2026_05_17.md` §5 forward-stage
//!   register item 4 ("CLI binary `epistemos_eml diagnostic` — prints
//!   the JSON-serialized live readout for ops use").
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` §3.4 (the
//!   underlying compute_live_readout surface).
//!
//! ## Usage
//!
//!   epistemos_eml diagnostic             Print the live readout (compact JSON).
//!   epistemos_eml diagnostic --pretty    Print indented JSON.
//!   epistemos_eml --version              Print version and exit.
//!   epistemos_eml --help                 Print this help and exit.
//!
//! ## Exit codes
//!
//!   0  — diagnostic computed and printed
//!   1  — usage error (missing arg, bad subcommand)
//!   2  — diagnostic computation failed (oracle / potential)
//!   3  — JSON serialization failed (should be unreachable; plumbed
//!        for completeness)

use std::process::ExitCode;

use agent_core::research::eml_integration::{compute_live_readout, DiagnosticError};

const USAGE: &str = "\
epistemos_eml — T7 §4.B EML Integration substrate ops CLI.

USAGE:
  epistemos_eml diagnostic [--pretty]   Compute and print the live readout JSON.
  epistemos_eml --version               Print version and exit.
  epistemos_eml --help                  Print this help and exit.

EXIT CODES:
  0  diagnostic OK + JSON printed to stdout
  1  usage error
  2  diagnostic compute failed (oracle / potential rejected)
  3  JSON serialization failed
";

fn main() -> ExitCode {
    let argv: Vec<String> = std::env::args().collect();
    if argv.len() < 2 {
        eprintln!("{}", USAGE);
        return ExitCode::from(1);
    }
    match argv[1].as_str() {
        "--help" | "-h" => {
            println!("{}", USAGE);
            ExitCode::from(0)
        }
        "--version" | "-V" => {
            println!("epistemos_eml {}", env!("CARGO_PKG_VERSION"));
            ExitCode::from(0)
        }
        "diagnostic" => run_diagnostic(&argv[2..]),
        other => {
            eprintln!("epistemos_eml: unknown subcommand '{}'\n", other);
            eprintln!("{}", USAGE);
            ExitCode::from(1)
        }
    }
}

fn run_diagnostic(args: &[String]) -> ExitCode {
    let mut pretty = false;
    for a in args {
        match a.as_str() {
            "--pretty" => pretty = true,
            other => {
                eprintln!("epistemos_eml diagnostic: unknown flag '{}'", other);
                return ExitCode::from(1);
            }
        }
    }
    let readout = match compute_live_readout() {
        Ok(r) => r,
        Err(DiagnosticError::OracleFailed) => {
            eprintln!("epistemos_eml: diagnostic compute failed: ULP smoke oracle failed");
            return ExitCode::from(2);
        }
        Err(DiagnosticError::PotentialFailed(inner)) => {
            eprintln!(
                "epistemos_eml: diagnostic compute failed: EML potential rejected: {:?}",
                inner
            );
            return ExitCode::from(2);
        }
    };
    let json = if pretty {
        serde_json::to_string_pretty(&readout)
    } else {
        serde_json::to_string(&readout)
    };
    match json {
        Ok(s) => {
            println!("{}", s);
            ExitCode::from(0)
        }
        Err(e) => {
            eprintln!("epistemos_eml: JSON serialization failed: {}", e);
            ExitCode::from(3)
        }
    }
}
