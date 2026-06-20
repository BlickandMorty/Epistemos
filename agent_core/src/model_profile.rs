//! ModelCapabilityProfile — the single, data-driven per-model profile (SS-AB).
//!
//! SS-Z found per-model config "badly scattered + partly outdated" across two
//! disconnected universes (the MLX `LocalTextModelID` ladders + the GGUF
//! `GemmaQATRuntimeCandidate` struct which carries ZERO inference config), with
//! "no single per-model profile anywhere" — the SS-W chat-template crash and the
//! hardcoded GGUF 4096 context window both fall straight out of that gap.
//!
//! This module is the MAS-safe (non-`pro-build`) floor: one resolver every lane
//! can read — GGUF (Pro subprocess) resolves its `--ctx-size` / stop tokens /
//! chat template from here instead of hardcoding them; the Swift picker reads the
//! `picker_use_case` copy. Pure data + resolution, no subprocess, no network →
//! `cargo test --lib` covers it. Per-model VALUES are sourced from SS-AB's
//! definitive table (ctx caps honor the 16 GB KV-cache budget).

/// The chat/prompt format a model speaks. Carries the per-model stop tokens
/// (SS-AB: "[Ollama] per-model stop tokens — MISSING today on GGUF") and the
/// llama.cpp builtin `--chat-template` name used to make the SS-W
/// `common_chat_templates_apply` crash structurally unreachable for the GGUF lane.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PromptDialect {
    /// `<|im_end|>`-terminated ChatML (Qwen, Hermes, LFM2, most OSS instruct).
    Chatml,
    /// Meta Llama 3 (`<|eot_id|>`).
    Llama3,
    /// Google Gemma (`<end_of_turn>`).
    Gemma,
    /// Mistral / Devstral (`</s>`).
    Mistral,
    /// Microsoft Phi (`<|end|>`).
    Phi,
    /// IBM Granite.
    Granite,
    /// Reasoning-only models with no chat/tool framing (VibeThinker, R1-Distill).
    None,
}

impl PromptDialect {
    /// The per-model stop strings llama-cli should halt on (beyond the model's
    /// own EOG token). Empty for reasoning-only models.
    pub fn stop_tokens(self) -> &'static [&'static str] {
        match self {
            PromptDialect::Chatml => &["<|im_end|>", "<|endoftext|>"],
            PromptDialect::Llama3 => &["<|eot_id|>", "<|end_of_text|>"],
            PromptDialect::Gemma => &["<end_of_turn>", "<eos>"],
            PromptDialect::Mistral => &["</s>"],
            PromptDialect::Phi => &["<|end|>", "<|endoftext|>"],
            PromptDialect::Granite => &["<|end_of_text|>"],
            PromptDialect::None => &[],
        }
    }

    /// The llama.cpp builtin `--chat-template` name for this dialect, or `None`
    /// for reasoning-only models (which use the embedded/plain template). Used by
    /// the GGUF lane to OVERRIDE a broken embedded template (SS-W).
    pub fn llama_cpp_template_name(self) -> Option<&'static str> {
        match self {
            PromptDialect::Chatml => Some("chatml"),
            PromptDialect::Llama3 => Some("llama3"),
            PromptDialect::Gemma => Some("gemma"),
            PromptDialect::Mistral => Some("mistral"),
            PromptDialect::Phi => Some("phi3"),
            PromptDialect::Granite => Some("granite"),
            PromptDialect::None => None,
        }
    }
}

/// Which runtime lane serves the model (SS-AB).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModelLane {
    /// MAS-safe in-process MLX (Apple Silicon).
    Mlx,
    /// Pro-only GGUF llama.cpp subprocess.
    Gguf,
    /// Experimental / research lane (honest, not advertised as production).
    Research,
    /// Remote cloud provider (Claude / OpenAI / Gemini / …) over its HTTP API.
    Cloud,
}

/// The capability tier the foundation lineup advertises (Fast / Think / Code).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CapabilityTier {
    Fast,
    Think,
    Code,
}

/// The single per-model capability profile (SS-AB). `'static` so the canonical
/// table is zero-allocation const data; the resolver returns owned copies.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ModelCapabilityProfile {
    pub id: &'static str,
    pub display_name: &'static str,
    /// Effective context window (SS-AB caps the 16 GB KV-cache budget — e.g.
    /// Qwen3's 256K is capped to ~32K). Replaces the GGUF hardcoded 4096.
    pub context_window: u32,
    pub max_output_tokens: u32,
    pub prompt_dialect: PromptDialect,
    pub lane: ModelLane,
    pub tier: CapabilityTier,
    /// SHORT use-case line shown on the model picker (≤ ~60 chars, SS-AB).
    pub picker_use_case: &'static str,
    /// Whether this is one of the advertised "best" models (all remain
    /// installable; advertised ones are surfaced prominently).
    pub advertised: bool,
}

impl ModelCapabilityProfile {
    /// The per-model stop tokens (delegated to the dialect).
    pub fn stop_tokens(&self) -> &'static [&'static str] {
        self.prompt_dialect.stop_tokens()
    }

    /// The llama.cpp builtin chat-template name for the GGUF lane (None for
    /// reasoning-only models).
    pub fn llama_cpp_template_name(&self) -> Option<&'static str> {
        self.prompt_dialect.llama_cpp_template_name()
    }

    /// The memory-safe RUNTIME context window for the GGUF (llama-cli) lane: the
    /// model's `context_window` capped to what the given unified-memory budget can
    /// hold as KV cache (SS-AB: "16 GB KV-cache budget"). Replaces the GGUF
    /// hardcoded 4096 (the SS-Z bug) with a per-model, budget-aware value —
    /// small-window models keep their window; large ones (Gemma 128K) are capped
    /// so they don't OOM a 16 GB Mac. Monotonic in the budget.
    pub fn gguf_runtime_ctx(&self, memory_budget_gb: f64) -> u32 {
        let cap: u32 = if memory_budget_gb <= 8.0 {
            4096
        } else if memory_budget_gb <= 16.0 {
            8192
        } else if memory_budget_gb <= 24.0 {
            16_384
        } else if memory_budget_gb <= 36.0 {
            32_768
        } else {
            65_536
        };
        self.context_window.min(cap)
    }
}

/// The canonical profile set (SS-AB's definitive table). Honest + real — no fake
/// descriptions. `profile_for` family-matches an id against these.
pub const CANON: &[ModelCapabilityProfile] = &[
    ModelCapabilityProfile {
        id: "gemma-4-e2b",
        display_name: "Gemma 4 E2B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Fastest on-device · everyday chat",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "gemma-4-e4b",
        display_name: "Gemma 4 E4B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Fast on-device · 128K context",
        advertised: true,
    },
    ModelCapabilityProfile {
        // The general `google/gemma-4-12B-it-qat-...` GGUF — the LARGEST model in
        // the Fast ladder (complexity routing escalates 2B → 4B → 12B). NOT the
        // coder; that is the separate `gemma-4-12b-coder` entry below.
        id: "gemma-4-12b-qat",
        display_name: "Gemma 4 12B QAT",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Gguf,
        tier: CapabilityTier::Fast,
        picker_use_case: "Largest Gemma · 128K, for harder asks",
        advertised: true,
    },
    ModelCapabilityProfile {
        // The community 12B coder fine-tune (`yuxinlu1/gemma-4-12B-coder-...`) — the
        // Code-tier foundation model. Same Gemma dialect/template as the general
        // 12B; distinct tier + picker copy.
        id: "gemma-4-12b-coder",
        display_name: "Gemma 4 12B Coder",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Gemma,
        lane: ModelLane::Gguf,
        tier: CapabilityTier::Code,
        picker_use_case: "Strongest local coder (Pro)",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "qwen3-4b",
        display_name: "Qwen3 4B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Best all-round · strong tools + reasoning",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "qwen3-1.7b",
        display_name: "Qwen3 1.7B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Quick all-round · low RAM",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "vibethinker-1.5b",
        display_name: "VibeThinker-1.5B",
        context_window: 32_768,
        max_output_tokens: 8192,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "Tiny math/logic reasoning",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "deepseek-r1-distill-1.5b",
        display_name: "DeepSeek-R1-Distill-1.5B",
        context_window: 32_768,
        max_output_tokens: 8192,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "General step-by-step reasoning",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "smollm3-3b",
        display_name: "SmolLM3-3B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "Open reasoning + tools, 128K",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "lfm2.5-1.2b",
        display_name: "LFM2.5-1.2B",
        context_window: 32_768,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Chatml,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Ultra-fast on-device tool-caller",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "phi-4-mini",
        display_name: "Phi-4-mini 3.8B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Phi,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Think,
        picker_use_case: "128K reasoning + function-calling",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "granite-4-nano-1b",
        display_name: "Granite 4 Nano 1B",
        context_window: 128_000,
        max_output_tokens: 4096,
        prompt_dialect: PromptDialect::Granite,
        lane: ModelLane::Mlx,
        tier: CapabilityTier::Fast,
        picker_use_case: "Enterprise-clean tool/RAG model",
        advertised: false,
    },
];

/// A conservative default for an id that matches no canonical family — honest
/// "unknown local model" config (a safe small context, ChatML, not advertised).
pub const DEFAULT_PROFILE: ModelCapabilityProfile = ModelCapabilityProfile {
    id: "unknown",
    display_name: "Local model",
    context_window: 8192,
    max_output_tokens: 4096,
    prompt_dialect: PromptDialect::Chatml,
    lane: ModelLane::Mlx,
    tier: CapabilityTier::Fast,
    picker_use_case: "Local model",
    advertised: false,
};

/// Cloud-provider capability profiles (SS-AB plan #2; owner 2026-06-20 "all model
/// profiles — local AND cloud — updated + hardened"). Context windows seeded from
/// the public LiteLLM capability table, bundled offline (MAS-safe — no network at
/// load). Keyed by the `CloudModelProvider` slug so the cloud lane resolves the
/// SAME single source as the local lanes. `prompt_dialect = None`: cloud models
/// speak their own API format, not the local llama-cli dialects (stop tokens /
/// chat-template names don't apply). Values are current as of 2026-06 — HARDENED
/// (no stale/fake ctx); update as providers change.
pub const CLOUD_CANON: &[ModelCapabilityProfile] = &[
    ModelCapabilityProfile {
        id: "anthropic",
        display_name: "Claude",
        context_window: 200_000,
        max_output_tokens: 64_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Think,
        picker_use_case: "Best reasoning + agentic tools (cloud)",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "openai",
        display_name: "ChatGPT",
        context_window: 272_000,
        max_output_tokens: 128_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Fast,
        picker_use_case: "Strong all-round cloud model",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "google",
        display_name: "Gemini",
        context_window: 1_048_576,
        max_output_tokens: 65_536,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Think,
        picker_use_case: "Huge context · multimodal (cloud)",
        advertised: true,
    },
    ModelCapabilityProfile {
        id: "deepseek",
        display_name: "DeepSeek",
        context_window: 128_000,
        max_output_tokens: 32_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Think,
        picker_use_case: "Strong reasoning + coding (cloud)",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "kimi",
        display_name: "Kimi",
        context_window: 256_000,
        max_output_tokens: 32_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Fast,
        picker_use_case: "Long-context cloud agent",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "zai",
        display_name: "Z.AI",
        context_window: 128_000,
        max_output_tokens: 32_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Code,
        picker_use_case: "Open cloud model · strong coding",
        advertised: false,
    },
    ModelCapabilityProfile {
        id: "minimax",
        display_name: "MiniMax",
        context_window: 1_000_000,
        max_output_tokens: 32_000,
        prompt_dialect: PromptDialect::None,
        lane: ModelLane::Cloud,
        tier: CapabilityTier::Fast,
        picker_use_case: "Ultra-long-context cloud model",
        advertised: false,
    },
];

/// Honest generic cloud default for an unknown provider (no panic, no fake).
pub const CLOUD_DEFAULT_PROFILE: ModelCapabilityProfile = ModelCapabilityProfile {
    id: "cloud",
    display_name: "Cloud model",
    context_window: 128_000,
    max_output_tokens: 16_384,
    prompt_dialect: PromptDialect::None,
    lane: ModelLane::Cloud,
    tier: CapabilityTier::Fast,
    picker_use_case: "Cloud model",
    advertised: false,
};

/// Resolve a model id/path/slug to its capability profile by family (best-effort
/// substring match, order-sensitive so e.g. a DeepSeek-R1-Distill-Qwen id maps to
/// the reasoning profile, not Qwen). Returns [`DEFAULT_PROFILE`] for unknowns —
/// NEVER a panic, NEVER an empty/fake profile (no-fake).
pub fn profile_for(model_id: &str) -> ModelCapabilityProfile {
    let id = model_id.to_lowercase();
    // Reasoning-only families first (their ids often also contain a base-model
    // name like "qwen" — match the reasoning identity, not the base).
    if id.contains("vibethinker") {
        return *find("vibethinker-1.5b");
    }
    if id.contains("deepseek") && (id.contains("distill") || id.contains("r1")) {
        return *find("deepseek-r1-distill-1.5b");
    }
    if id.contains("gemma") {
        // The community 12B coder fine-tune (id carries "coder") is the Code tier;
        // the general it-qat 12B is the largest model in the Fast ladder. Check
        // "coder" FIRST — the coder id also contains "12b", so the general-12B arm
        // below would otherwise mislabel it (and vice versa, mislabel the general
        // 12B as the coder, which was the bug).
        if id.contains("coder") {
            return *find("gemma-4-12b-coder");
        }
        // 12B/27B general vs the small E2B/E4B models.
        if id.contains("12b") || id.contains("27b") {
            return *find("gemma-4-12b-qat");
        }
        if id.contains("e4b") || id.contains("4b") {
            return *find("gemma-4-e4b");
        }
        return *find("gemma-4-e2b");
    }
    if id.contains("qwen") || id.contains("qwopus") {
        if id.contains("1.7b") || id.contains("1_7b") || id.contains("1.5b") {
            return *find("qwen3-1.7b");
        }
        return *find("qwen3-4b");
    }
    if id.contains("smollm3") || id.contains("smollm-3") {
        return *find("smollm3-3b");
    }
    if id.contains("lfm") || id.contains("liquid") {
        return *find("lfm2.5-1.2b");
    }
    if id.contains("phi") {
        return *find("phi-4-mini");
    }
    if id.contains("granite") {
        return *find("granite-4-nano-1b");
    }
    DEFAULT_PROFILE
}

/// Look up a canonical profile by exact id (used internally by [`profile_for`]).
/// Returns a reference into [`CANON`]; falls back to [`DEFAULT_PROFILE`].
fn find(id: &str) -> &'static ModelCapabilityProfile {
    CANON.iter().find(|p| p.id == id).unwrap_or(&DEFAULT_PROFILE)
}

/// Resolve a cloud provider slug (the `CloudModelProvider` raw value — "anthropic",
/// "openai", "google", "zai", "kimi", "minimax", "deepseek" — or a common alias) to
/// its capability profile from [`CLOUD_CANON`]. Falls back to [`CLOUD_DEFAULT_PROFILE`]
/// for an unknown provider — never a panic, never fake.
pub fn cloud_profile(provider: &str) -> ModelCapabilityProfile {
    let key = match provider.to_lowercase().as_str() {
        "claude" => "anthropic",
        "chatgpt" | "gpt" => "openai",
        "gemini" => "google",
        "glm" => "zai",
        "moonshot" => "kimi",
        other => return CLOUD_CANON
            .iter()
            .find(|c| c.id == other)
            .copied()
            .unwrap_or(CLOUD_DEFAULT_PROFILE),
    };
    CLOUD_CANON
        .iter()
        .find(|c| c.id == key)
        .copied()
        .unwrap_or(CLOUD_DEFAULT_PROFILE)
}

/// Resolve the SHORT picker use-case line for ANY model id — local lane first
/// (family substring via [`profile_for`]), then the cloud lane (provider brand
/// substring → [`cloud_profile`]). Returns `""` only when neither lane recognizes
/// the id, so the Swift picker keeps its generic tier tagline. This is the ONE
/// source the picker FFI (`model_picker_use_case`) reads for both local AND cloud
/// copy (SS-AB; owner 2026-06-20 "all model profiles — local and cloud").
///
/// Local is tried FIRST so a local reasoning/HF-org id (e.g.
/// `deepseek-r1-distill-qwen`, `google/gemma-4-12b`) keeps its on-device copy
/// instead of being mistaken for the `deepseek`/`google` cloud provider. `BRANDS`
/// mirrors the [`CLOUD_CANON`] ids + [`cloud_profile`] aliases — keep it in sync
/// when a cloud provider is added.
pub fn picker_use_case_for(model_id: &str) -> &'static str {
    let local = profile_for(model_id);
    if local.id != "unknown" {
        return local.picker_use_case;
    }
    let id = model_id.to_lowercase();
    const BRANDS: &[&str] = &[
        "anthropic", "claude",
        "openai", "chatgpt", "gpt",
        "google", "gemini",
        "deepseek",
        "kimi", "moonshot",
        "zai", "glm",
        "minimax",
    ];
    for brand in BRANDS {
        if id.contains(brand) {
            let cloud = cloud_profile(brand);
            if cloud.id != CLOUD_DEFAULT_PROFILE.id {
                return cloud.picker_use_case;
            }
        }
    }
    ""
}

/// The advertised "best" models, in canonical order (for the picker's
/// advertise-stack).
pub fn advertised() -> impl Iterator<Item = &'static ModelCapabilityProfile> {
    CANON.iter().filter(|p| p.advertised)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_canon_profile_is_honest_and_complete() {
        for p in CANON {
            assert!(!p.id.is_empty());
            assert!(!p.display_name.is_empty());
            // No fake/empty picker copy; honest + within the ~60-char picker budget.
            assert!(!p.picker_use_case.is_empty(), "empty picker copy for {}", p.id);
            assert!(
                p.picker_use_case.chars().count() <= 60,
                "picker copy too long for {}: {:?}",
                p.id,
                p.picker_use_case
            );
            // A real context window — NEVER the hardcoded-4096 GGUF bug.
            assert!(p.context_window >= 8192, "ctx too small for {}", p.id);
            assert!(p.max_output_tokens > 0);
        }
    }

    #[test]
    fn gguf_models_resolve_a_chat_template_so_ss_w_is_unreachable() {
        // Every dialect-bearing model exposes a llama.cpp builtin template name,
        // so the GGUF lane can always override a broken embedded template (SS-W).
        let gemma = profile_for("gemma-4-12b-qat-gguf");
        assert_eq!(gemma.llama_cpp_template_name(), Some("gemma"));
        assert!(gemma.stop_tokens().contains(&"<end_of_turn>"));

        let qwen = profile_for("Qwen3-4B-MLX");
        assert_eq!(qwen.llama_cpp_template_name(), Some("chatml"));
        assert!(qwen.stop_tokens().contains(&"<|im_end|>"));
    }

    #[test]
    fn deepseek_r1_distill_qwen_resolves_to_reasoning_not_qwen() {
        // The id contains "qwen" but it is a DeepSeek-R1 reasoning model — the
        // reasoning identity must win (mirrors the SS-W/logo deepseek-before-qwen
        // ordering bug class).
        let p = profile_for("DeepSeek-R1-Distill-Qwen-1.5B");
        assert_eq!(p.tier, CapabilityTier::Think);
        assert_eq!(p.prompt_dialect, PromptDialect::None);
        assert!(p.stop_tokens().is_empty());
    }

    #[test]
    fn context_windows_honor_the_16gb_budget() {
        // Qwen capped to ~32K (not its native 256K) for the KV-cache budget;
        // Gemma keeps its 128K.
        assert_eq!(profile_for("qwen3-4b").context_window, 32_768);
        assert_eq!(profile_for("gemma-4-e2b-it").context_window, 128_000);
    }

    #[test]
    fn unknown_model_gets_an_honest_default_never_a_panic() {
        let p = profile_for("some-brand-new-model-v9");
        assert_eq!(p.id, "unknown");
        assert!(!p.advertised);
        assert!(p.context_window >= 8192);
    }

    #[test]
    fn advertised_set_is_the_best_models() {
        let names: Vec<_> = advertised().map(|p| p.display_name).collect();
        assert!(names.contains(&"Gemma 4 E2B"));
        assert!(names.contains(&"Qwen3 4B"));
        assert!(names.contains(&"VibeThinker-1.5B"));
        // A non-advertised one is excluded.
        assert!(!names.contains(&"Granite 4 Nano 1B"));
    }

    #[test]
    fn gguf_runtime_ctx_is_per_model_and_budget_capped_never_4096_on_16gb() {
        let gemma = profile_for("gemma-4-12b-qat"); // a 128K-window model
        // 16 GB ship target: capped to 8192 — NOT the dangerous 128K, and a real
        // improvement over the hardcoded-4096 SS-Z bug.
        assert_eq!(gemma.gguf_runtime_ctx(16.0), 8192);
        // A bigger machine lifts the cap; a small one stays conservative.
        assert_eq!(gemma.gguf_runtime_ctx(36.0), 32_768);
        assert_eq!(gemma.gguf_runtime_ctx(8.0), 4096);
        // Monotonic in the budget.
        assert!(gemma.gguf_runtime_ctx(24.0) >= gemma.gguf_runtime_ctx(16.0));
        // Every advertised model beats the old hardcoded 4096 on a 16 GB Mac.
        for p in advertised() {
            assert!(p.gguf_runtime_ctx(16.0) > 4096, "{} still <=4096", p.id);
        }
    }

    #[test]
    fn cloud_profiles_are_current_and_hardened() {
        // Owner 2026-06-20: every cloud model gets a CURRENT + HARDENED profile —
        // real (large) context, honest copy, the cloud lane, and NO local dialect
        // machinery (cloud speaks its own API format).
        assert!(!CLOUD_CANON.is_empty());
        for c in CLOUD_CANON {
            assert_eq!(c.lane, ModelLane::Cloud, "{} not Cloud lane", c.id);
            assert!(c.context_window >= 100_000, "{} ctx too small/stale", c.id);
            assert!(c.max_output_tokens > 0, "{} no output budget", c.id);
            assert!(!c.picker_use_case.is_empty(), "{} empty picker copy", c.id);
            assert!(
                c.picker_use_case.chars().count() <= 60,
                "{} picker copy too long",
                c.id
            );
            // Cloud uses its own API format — no llama-cli stop tokens / template.
            assert!(c.stop_tokens().is_empty(), "{} should have no local stops", c.id);
            assert!(c.llama_cpp_template_name().is_none(), "{} no local template", c.id);
        }
    }

    #[test]
    fn cloud_profile_resolves_every_provider_and_aliases() {
        assert_eq!(cloud_profile("anthropic").display_name, "Claude");
        assert_eq!(cloud_profile("claude").display_name, "Claude"); // alias
        assert_eq!(cloud_profile("openai").display_name, "ChatGPT");
        assert_eq!(cloud_profile("gpt").display_name, "ChatGPT"); // alias
        assert_eq!(cloud_profile("google").display_name, "Gemini");
        assert_eq!(cloud_profile("gemini").display_name, "Gemini"); // alias
        assert_eq!(cloud_profile("deepseek").context_window, 128_000);
        // Gemini's huge context window is current (1M+).
        assert!(cloud_profile("google").context_window >= 1_000_000);
        // Claude's extended output budget is real, not the old 8K.
        assert!(cloud_profile("anthropic").max_output_tokens >= 32_000);
        // Unknown provider → honest cloud default, never a panic.
        assert_eq!(cloud_profile("brand-new-cloud-v9").id, "cloud");
    }

    #[test]
    fn picker_use_case_for_resolves_local_then_cloud() {
        // Local lane wins first: a canonical on-device family returns its copy.
        assert_eq!(
            picker_use_case_for("gemma-4-12b-qat"),
            find("gemma-4-12b-qat").picker_use_case
        );
        assert!(!picker_use_case_for("qwen3-4b").is_empty());
        // A local reasoning id is NOT mistaken for the `deepseek` cloud provider.
        assert_eq!(
            picker_use_case_for("deepseek-r1-distill-qwen-1.5b"),
            find("deepseek-r1-distill-1.5b").picker_use_case
        );
        // Cloud lane: a bare provider slug resolves to its cloud copy...
        assert_eq!(
            picker_use_case_for("anthropic"),
            cloud_profile("anthropic").picker_use_case
        );
        // ...and a FULL cloud model id resolves by provider-brand substring.
        assert_eq!(
            picker_use_case_for("claude-opus-4-8"),
            cloud_profile("anthropic").picker_use_case
        );
        assert_eq!(picker_use_case_for("gpt-5.2"), cloud_profile("openai").picker_use_case);
        assert_eq!(
            picker_use_case_for("gemini-2.5-pro"),
            cloud_profile("google").picker_use_case
        );
        assert_eq!(picker_use_case_for("glm-4.6"), cloud_profile("zai").picker_use_case);
        assert_eq!(picker_use_case_for("kimi-k2"), cloud_profile("kimi").picker_use_case);
        // A local HF-org-prefixed gemma keeps its LOCAL copy (not the google cloud).
        assert_eq!(
            picker_use_case_for("google/gemma-4-12b-qat"),
            find("gemma-4-12b-qat").picker_use_case
        );
        // Neither lane recognizes it → empty (picker keeps its generic tier tagline).
        assert_eq!(picker_use_case_for("totally-made-up-zzz"), "");
    }

    #[test]
    fn gemma_12b_general_and_coder_resolve_to_distinct_tiers() {
        // The foundation lineup ships TWO 12B Gemmas: the general it-qat 12B (the
        // largest Fast-ladder model) and the community coder fine-tune (Code tier).
        // Both ids contain "gemma" + "12b", so they used to collapse onto ONE
        // coder-labeled profile — the general 12B was mislabeled "Strongest local
        // coder". They must now resolve to distinct tiers + copy (real ids from
        // LocalModelInfrastructure).
        let general = profile_for("google/gemma-4-12B-it-qat-q4_0-gguf");
        assert_eq!(general.tier, CapabilityTier::Fast);
        assert!(!general.picker_use_case.to_lowercase().contains("coder"));

        let coder = profile_for("yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF");
        assert_eq!(coder.tier, CapabilityTier::Code);
        assert_eq!(coder.picker_use_case, "Strongest local coder (Pro)");
        // The coder is still a Gemma-dialect model — template + stops unchanged.
        assert_eq!(coder.llama_cpp_template_name(), Some("gemma"));
        assert!(coder.stop_tokens().contains(&"<end_of_turn>"));
    }

    #[test]
    fn canon_profiles_are_unique_and_hardened() {
        // Owner 2026-06-20 "all profiles updated + hardened": every local CANON
        // entry has a UNIQUE id, honest non-empty picker copy (≤60 chars), a real
        // context window, and an output budget. Guards against a model added
        // without a profile (or a duplicate id silently shadowing one).
        let mut seen = std::collections::BTreeSet::new();
        for p in CANON {
            assert!(seen.insert(p.id), "duplicate CANON id: {}", p.id);
            assert!(!p.picker_use_case.is_empty(), "{} empty picker copy", p.id);
            assert!(
                p.picker_use_case.chars().count() <= 60,
                "{} picker copy too long",
                p.id
            );
            assert!(p.context_window >= 8192, "{} ctx too small/stale", p.id);
            assert!(p.max_output_tokens > 0, "{} no output budget", p.id);
        }
    }
}
