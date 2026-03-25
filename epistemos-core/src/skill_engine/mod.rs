// Skill engine: classifies prompts to route to the appropriate adapter.
// Provides Rust-side prompt classification for adapter routing.
// Swift-side MoLoRARouter and AdapterRouter use this for automatic routing.

/// Classify a prompt into an adapter category.
/// Returns: "knowledge", "style", "tool", or "general".
pub fn classify_prompt(prompt: &str) -> String {
    let lower = prompt.to_lowercase();

    // Style cues: personal writing assistance
    let style_cues = [
        "help me write", "in my style", "rewrite this",
        "match my tone", "how would i say", "draft a",
        "writing style", "personal voice", "sound like me",
        "like i would write", "my voice",
    ];
    let style_hits = style_cues.iter().filter(|c| lower.contains(*c)).count();
    if style_hits >= 1 {
        return "style".to_string();
    }

    // Tool cues: API/code/function usage
    let tool_cues = [
        "how to use", "api", "function", "endpoint",
        "code", "command", "script", "import", "install",
        "configure", "setup", "debug", "compile", "error",
        "build", "deploy", "docker", "git ",
    ];
    let tool_hits = tool_cues.iter().filter(|c| lower.contains(*c)).count();
    if tool_hits >= 2 {
        return "tool".to_string();
    }

    // Knowledge cues: factual lookup from vault
    let knowledge_cues = [
        "what is", "according to my notes", "from my vault",
        "what did i write about", "my research on",
        "remind me about", "summarize my notes",
        "what do i know about", "explain",
        "tell me about", "describe",
    ];
    let knowledge_hits = knowledge_cues.iter().filter(|c| lower.contains(*c)).count();
    if knowledge_hits >= 1 {
        return "knowledge".to_string();
    }

    "general".to_string()
}

/// UniFFI-callable: classify a prompt for adapter routing.
pub fn route_prompt(prompt: &str) -> RoutingDecision {
    let category = classify_prompt(prompt);
    let confidence = match category.as_str() {
        "style" => 0.85,
        "tool" => 0.75,
        "knowledge" => 0.80,
        _ => 0.50,
    };
    RoutingDecision {
        adapter_type: category,
        confidence,
    }
}

/// UniFFI-exported routing decision.
#[derive(Debug, Clone)]
pub struct RoutingDecision {
    pub adapter_type: String,
    pub confidence: f64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_style() {
        assert_eq!(classify_prompt("Help me write an email in my style"), "style");
        assert_eq!(classify_prompt("Rewrite this paragraph"), "style");
    }

    #[test]
    fn test_classify_tool() {
        assert_eq!(classify_prompt("How to use the git command to deploy code"), "tool");
        assert_eq!(classify_prompt("Configure the Docker API endpoint"), "tool");
    }

    #[test]
    fn test_classify_knowledge() {
        assert_eq!(classify_prompt("What is quantum computing?"), "knowledge");
        assert_eq!(classify_prompt("Summarize my notes on machine learning"), "knowledge");
    }

    #[test]
    fn test_classify_general() {
        assert_eq!(classify_prompt("Hello, how are you?"), "general");
    }

    #[test]
    fn test_route_prompt() {
        let decision = route_prompt("Help me write a letter in my style");
        assert_eq!(decision.adapter_type, "style");
        assert!(decision.confidence > 0.5);
    }
}
