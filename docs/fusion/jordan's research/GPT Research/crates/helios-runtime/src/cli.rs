//! Hermes agent CLI and multi-CLI command router.
//!
//! This is MAS-safe by default: `/run` never launches a process in Core. Pro/Research
//! return a structured routing intent that a notarized direct-distribution helper can
//! handle after explicit user approval.

use crate::hermes::{HermesBoundary, ProviderKind};

/// Capability envelope selected by the build/profile.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CapabilityEnvelope {
    Core,
    Pro,
    Research,
}

/// Parsed CLI command.
#[derive(Clone, Debug, PartialEq)]
pub enum CliCommand {
    Help { topic: String },
    Calc { expression: String },
    Ask { prompt: String },
    Run { command: String },
    Unknown { raw: String },
}

/// CLI execution error.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CliError {
    Empty,
    CoreCannotRunShell,
    CalcUnsupported,
}

/// Agent CLI front door.
#[derive(Clone, Debug, PartialEq)]
pub struct AgentCli {
    pub envelope: CapabilityEnvelope,
    pub hermes: HermesBoundary,
}

impl AgentCli {
    #[must_use]
    pub fn new(envelope: CapabilityEnvelope) -> Self {
        Self { envelope, hermes: HermesBoundary::default() }
    }

    #[must_use]
    pub fn parse(input: &str) -> CliCommand {
        let trimmed = input.trim();
        if let Some(rest) = trimmed.strip_prefix("/help") {
            return CliCommand::Help { topic: rest.trim().to_string() };
        }
        if let Some(rest) = trimmed.strip_prefix("/calc") {
            return CliCommand::Calc { expression: rest.trim().to_string() };
        }
        if let Some(rest) = trimmed.strip_prefix("/ask") {
            return CliCommand::Ask { prompt: rest.trim().to_string() };
        }
        if let Some(rest) = trimmed.strip_prefix("/run") {
            return CliCommand::Run { command: rest.trim().to_string() };
        }
        CliCommand::Unknown { raw: trimmed.to_string() }
    }

    pub fn execute(&self, input: &str) -> Result<String, CliError> {
        match Self::parse(input) {
            CliCommand::Help { topic } => Ok(self.help(&topic)),
            CliCommand::Calc { expression } => eval_calc(&expression).map(|v| format!("{v:.12}")),
            CliCommand::Ask { prompt } => Ok(format!("provider={:?}; provenance=pending; prompt={prompt}", self.hermes.active_provider())),
            CliCommand::Run { command } => match self.envelope {
                CapabilityEnvelope::Core => Err(CliError::CoreCannotRunShell),
                CapabilityEnvelope::Pro | CapabilityEnvelope::Research => Ok(format!("route=cli_passthrough; approved=false; command={command}")),
            },
            CliCommand::Unknown { raw } if raw.is_empty() => Err(CliError::Empty),
            CliCommand::Unknown { raw } => Ok(format!("unknown command: {raw}")),
        }
    }

    pub fn set_provider(&mut self, provider: ProviderKind) {
        self.hermes.set_provider(provider);
    }

    fn help(&self, topic: &str) -> String {
        let tier = if topic.is_empty() { "core" } else { topic };
        format!("{tier}: /help core, /calc 2*pi, /ask <prompt>, /run <cmd> [Pro only]")
    }
}

fn eval_calc(expression: &str) -> Result<f64, CliError> {
    let normalized = expression.replace(' ', "").replace("pi", &std::f64::consts::PI.to_string());
    if normalized.is_empty() {
        return Err(CliError::CalcUnsupported);
    }
    // Small deterministic expression evaluator for demo parity: +, -, *, /, no parentheses.
    let mut terms = Vec::new();
    let mut ops = Vec::new();
    let mut start = 0;
    for (idx, ch) in normalized.char_indices() {
        if idx > 0 && (ch == '+' || ch == '-') {
            terms.push(&normalized[start..idx]);
            ops.push(ch);
            start = idx + 1;
        }
    }
    terms.push(&normalized[start..]);
    let mut values = Vec::new();
    for term in terms {
        values.push(eval_mul_div(term)?);
    }
    let mut acc = values[0];
    for (op, value) in ops.into_iter().zip(values.into_iter().skip(1)) {
        if op == '+' { acc += value; } else { acc -= value; }
    }
    Ok(acc)
}

fn eval_mul_div(term: &str) -> Result<f64, CliError> {
    let mut acc = None::<f64>;
    let mut current = String::new();
    let mut op = '*';
    for ch in term.chars().chain(std::iter::once('*')) {
        if ch == '*' || ch == '/' {
            let value = current.parse::<f64>().map_err(|_| CliError::CalcUnsupported)?;
            acc = Some(match (acc, op) {
                (None, _) => value,
                (Some(a), '*') => a * value,
                (Some(a), '/') => a / value,
                (Some(a), _) => a,
            });
            current.clear();
            op = ch;
        } else {
            current.push(ch);
        }
    }
    acc.ok_or(CliError::CalcUnsupported)
}

#[cfg(test)]
mod tests {
    use super::{AgentCli, CapabilityEnvelope, CliError};
    use crate::hermes::ProviderKind;

    #[test]
    fn help_core_lists_parity_slate() {
        let cli = AgentCli::new(CapabilityEnvelope::Core);
        let help = cli.execute("/help core").unwrap();
        assert!(help.contains("/calc 2*pi"));
    }

    #[test]
    fn calc_pi_matches_demo_bar() {
        let cli = AgentCli::new(CapabilityEnvelope::Core);
        let out = cli.execute("/calc 2*pi").unwrap();
        assert!(out.starts_with("6.283185"));
    }

    #[test]
    fn core_run_is_blocked() {
        let cli = AgentCli::new(CapabilityEnvelope::Core);
        assert_eq!(cli.execute("/run echo hello"), Err(CliError::CoreCannotRunShell));
    }

    #[test]
    fn provider_switch_affects_ask() {
        let mut cli = AgentCli::new(CapabilityEnvelope::Pro);
        cli.set_provider(ProviderKind::Anthropic);
        assert!(cli.execute("/ask why is X important").unwrap().contains("Anthropic"));
    }
}
