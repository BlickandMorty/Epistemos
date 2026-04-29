//! Plan §12 verification command for Phase 4:
//! `cargo run --bin heal_eval -- --inject 50`
//!
//! Drives the synthetic 30-case heal-recovery eval (or the count
//! the user requests, repeated to fill) against the existing
//! HealLoop. Reports per-scenario outcome + overall recovery rates
//! against the §22.1.3 IterGen exit gate.
//!
//! Exit codes:
//! - 0: report generated, passes_phase_11_exit() == true
//! - 1: usage / IO error
//! - 2: report generated, exit gate not met (regression)

use std::env;
use std::process::ExitCode;

use agent_core::eval::heal_recovery::{run_heal_eval, synthetic_30_case_seed, HealFixture};

#[tokio::main]
async fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    let mut inject: Option<usize> = None;
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--inject" => {
                inject = match args.next().and_then(|s| s.parse::<usize>().ok()) {
                    Some(n) => Some(n),
                    None => {
                        eprintln!("--inject requires a positive integer");
                        return ExitCode::from(1);
                    }
                };
            }
            "--help" | "-h" => {
                println!(
                    "Usage: heal_eval [--inject N]\n\
                     \n\
                     Drives the heal-recovery eval against the synthetic 30-case seed,\n\
                     repeated as many times as needed to reach N total scenarios.\n\
                     N defaults to 30 (one full pass through the seed)."
                );
                return ExitCode::SUCCESS;
            }
            other => {
                eprintln!("unknown arg: {other}");
                return ExitCode::from(1);
            }
        }
    }

    let target = inject.unwrap_or(30);
    let seed = synthetic_30_case_seed();
    let fixtures: Vec<HealFixture> = (0..target)
        .map(|i| {
            let mut f = seed[i % seed.len()].clone();
            // Disambiguate ids when we wrap around so per-scenario
            // tracking stays unique in the report.
            if i >= seed.len() {
                f.id = format!("{}__rep{}", f.id, i / seed.len());
            }
            f
        })
        .collect();

    println!("Running heal_eval against {} synthetic scenarios...", fixtures.len());
    let report = run_heal_eval(&fixtures).await;
    let (pct_1, pct_3) = report.percentages();

    println!("---- Heal Recovery Report ----");
    println!("total: {}", report.total);
    println!(
        "recovered_within_1_backtrack: {} ({:.1}%)",
        report.recovered_within_1,
        pct_1 * 100.0
    );
    println!(
        "recovered_within_3_backtracks: {} ({:.1}%)",
        report.recovered_within_3,
        pct_3 * 100.0
    );
    println!("abandoned: {}", report.abandoned);
    println!("expectation_mismatches: {}", report.mismatches);
    println!();
    println!("Phase 11 exit gate (≥85% in 1, ≥97% in 3): {}",
        if report.passes_phase_11_exit() { "PASS" } else { "FAIL" });

    if report.passes_phase_11_exit() {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(2)
    }
}
