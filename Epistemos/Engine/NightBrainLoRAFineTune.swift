import Foundation

// DATA + FINETUNE substrate, part (4) NIGHT BRAIN (owner 2026-06-18): the idle
// brain should run native LoRA fine-tuning during idle windows — "visible,
// logged, owner-controllable, NOT per-keystroke." This is the controllable GATE
// + the honest DECISION logic for WHEN an idle native fine-tune may run. Pure,
// MLX-independent, unit-tested. The NightBrainService Job that actually invokes
// NativeLoRATrainer is the follow-on (it needs an on-device run to prove
// training); this slice makes the trigger honest + owner-controllable first.

/// Visible, honest flag status for the Night Brain native LoRA fine-tune (mirrors
/// the other gate-status surfaces — DeepResearchGateStatus etc.). OFF by default.
nonisolated enum NightBrainLoRAGateStatus {
    static let flagName = "EPISTEMOS_NIGHTBRAIN_LORA_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "Night Brain LoRA fine-tune: ON (Pro)",
                detail: "During idle windows on AC power, Night Brain may run a NATIVE LoRA fine-tune (MLXLLM.LoRATrain) when enough new vault data has accumulated — not per-keystroke. Pro-only; every run is logged in the Night Brain record."
            )
        }
        return Status(
            isActive: false,
            headline: "Night Brain LoRA fine-tune: off (opt-in)",
            detail: "Set \(flagName)=1 to let Night Brain run native idle LoRA fine-tunes (Pro). Off by default → no automatic training."
        )
    }
}

/// The honest, owner-controllable decision for whether an idle native LoRA
/// fine-tune may run THIS idle window. Deliberately conservative (flag + Pro +
/// idle + AC + a real data delta + a cadence cap) so training never surprises the
/// owner or runs on a trivial change. Pure → unit-tested; the reasons are
/// surfaced in the Night Brain log so "why it didn't train" is always honest.
enum NightBrainLoRAFineTuneDecision {
    enum Outcome: Equatable {
        case run
        case skip(reason: String)
    }

    struct Inputs: Sendable {
        var enabled: Bool                 // EPISTEMOS_NIGHTBRAIN_LORA_V0
        var isPro: Bool                   // native training is Pro-only
        var isIdle: Bool                  // an idle maintenance window
        var onACPower: Bool               // training is heavy — AC only
        var newExampleCount: Int          // new vault examples since last fine-tune
        var minNewExamples: Int           // don't train on a trivial delta
        var daysSinceLastFineTune: Int?   // nil = never fine-tuned
        var minDaysBetween: Int           // cadence cap

        init(
            enabled: Bool, isPro: Bool, isIdle: Bool, onACPower: Bool,
            newExampleCount: Int, minNewExamples: Int = 50,
            daysSinceLastFineTune: Int? = nil, minDaysBetween: Int = 7
        ) {
            self.enabled = enabled
            self.isPro = isPro
            self.isIdle = isIdle
            self.onACPower = onACPower
            self.newExampleCount = newExampleCount
            self.minNewExamples = minNewExamples
            self.daysSinceLastFineTune = daysSinceLastFineTune
            self.minDaysBetween = minDaysBetween
        }
    }

    /// Evaluate the gates in a fixed, honest order; the first failing gate is the
    /// surfaced reason. All gates must pass to `.run`.
    static func evaluate(_ i: Inputs) -> Outcome {
        if !i.enabled {
            return .skip(reason: "Night Brain LoRA fine-tune is off (set \(NightBrainLoRAGateStatus.flagName)=1).")
        }
        if !i.isPro {
            return .skip(reason: "Native LoRA fine-tune is a Pro feature.")
        }
        if !i.isIdle {
            return .skip(reason: "Not in an idle maintenance window.")
        }
        if !i.onACPower {
            return .skip(reason: "Waiting for AC power — training is heavy.")
        }
        if i.newExampleCount < max(1, i.minNewExamples) {
            return .skip(reason: "Only \(i.newExampleCount) new vault examples (need \(max(1, i.minNewExamples))).")
        }
        if let days = i.daysSinceLastFineTune, days < max(0, i.minDaysBetween) {
            return .skip(reason: "Last fine-tune was \(days)d ago (min \(max(0, i.minDaysBetween))d between runs).")
        }
        return .run
    }
}
