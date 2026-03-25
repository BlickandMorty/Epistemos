import Foundation
import Metal
import os

// MARK: - Hardware Tier Manager

/// Detects Apple Silicon capabilities beyond memory: chip generation, GPU core count,
/// ANE availability, and computes the appropriate model tier for dual-brain routing.
///
/// Complements `LocalHardwareCapabilitySnapshot` (memory-only) with compute-tier awareness.
/// Used by `DualBrainRouter` to decide GPU vs ANE routing and model selection.
@MainActor @Observable
final class HardwareTierManager {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "HardwareTier")

    /// Detected hardware snapshot (computed once at init).
    let tier: HardwareTier

    /// Whether the Neural Engine is available for CoreML inference.
    let aneAvailable: Bool

    /// Whether Metal GPU compute is available.
    let metalGPUAvailable: Bool

    /// Estimated VRAM budget for simultaneous dual-model loading (bytes).
    let dualModelMemoryBudget: Int

    init() {
        let detected = Self.detectTier()
        self.tier = detected
        self.aneAvailable = Self.detectANE()
        self.metalGPUAvailable = Self.detectMetalGPU()
        self.dualModelMemoryBudget = Self.computeDualModelBudget(tier: detected)

        log.info("Hardware tier: \(detected.rawValue, privacy: .public), ANE: \(self.aneAvailable), Metal: \(self.metalGPUAvailable), dual budget: \(self.dualModelMemoryBudget / 1_000_000)MB")
    }

    /// For testing: inject a specific tier.
    init(tier: HardwareTier, aneAvailable: Bool = true, metalGPUAvailable: Bool = true) {
        self.tier = tier
        self.aneAvailable = aneAvailable
        self.metalGPUAvailable = metalGPUAvailable
        self.dualModelMemoryBudget = Self.computeDualModelBudget(tier: tier)
    }

    /// The recommended model configuration for this hardware.
    var recommendedConfig: DualBrainConfig {
        DualBrainConfig.recommended(for: tier, aneAvailable: aneAvailable)
    }

    /// Whether this hardware can run dual models simultaneously.
    var supportsDualModel: Bool {
        tier.memoryGB >= 16 && aneAvailable && metalGPUAvailable
    }

    // MARK: - Detection

    private static func detectTier() -> HardwareTier {
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Int((memoryBytes + 999_999_999) / 1_000_000_000)

        // Read chip identifier via sysctl
        let chipName = sysctlString("machdep.cpu.brand_string") ?? ""
        let cpuCores = ProcessInfo.processInfo.processorCount

        // Determine generation from chip name
        let generation = AppleSiliconGeneration.detect(from: chipName)

        // Classify based on memory + generation + core count
        switch (memoryGB, generation, cpuCores) {
        case (64..., _, _):
            return .ultra
        case (36..., _, _):
            return .max
        case (24..., _, _):
            return .pro32
        case (18..., _, _):
            return .pro18
        case (16..., _, _):
            return .base16
        case (12..., _, _):
            return .base12
        default:
            return .base8
        }
    }

    private static func detectANE() -> Bool {
        // All Apple Silicon Macs have ANE. Check by attempting to query the chip.
        let chipName = sysctlString("machdep.cpu.brand_string") ?? ""
        return chipName.contains("Apple")
    }

    private static func detectMetalGPU() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    private static func computeDualModelBudget(tier: HardwareTier) -> Int {
        // Reserve ~40% of total memory for OS + app + graph engine.
        // Remaining 60% split between Brain 1 (GPU) and Brain 2 (ANE).
        let totalBytes = tier.memoryGB * 1_000_000_000
        let available = Int(Double(totalBytes) * 0.60)
        return available
    }

    private static func sysctlString(_ name: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}

// MARK: - Hardware Tier Enum

/// Classifies Mac hardware into tiers that determine model selection and routing.
enum HardwareTier: String, Sendable, CaseIterable {
    case base8    = "base-8GB"     // M1/M2 Air 8GB — single small model only
    case base12   = "base-12GB"    // M2/M3 Air 12GB
    case base16   = "base-16GB"    // M2/M3/M4 Pro 16GB
    case pro18    = "pro-18GB"     // M2 Pro 18GB (target baseline)
    case pro32    = "pro-32GB"     // M2/M3/M4 Pro 32GB
    case max      = "max-36GB+"    // M2/M3/M4 Max 36-48GB
    case ultra    = "ultra-64GB+"  // M1/M2 Ultra 64GB+

    var memoryGB: Int {
        switch self {
        case .base8: 8
        case .base12: 12
        case .base16: 16
        case .pro18: 18
        case .pro32: 32
        case .max: 36
        case .ultra: 64
        }
    }

    /// Maximum model size (4-bit quantized) for Brain 1 (reasoning, GPU).
    var maxBrain1ParamsB: Double {
        switch self {
        case .base8: 0.8
        case .base12: 2.0
        case .base16: 4.0
        case .pro18: 4.0
        case .pro32: 9.0
        case .max: 27.0
        case .ultra: 35.0
        }
    }

    /// Maximum model size (4-bit quantized) for Brain 2 (device agent, ANE).
    /// Only applicable when dual-model is supported.
    var maxBrain2ParamsB: Double {
        switch self {
        case .base8: 0       // No dual model
        case .base12: 0      // No dual model
        case .base16: 1.0    // Tight — Nano only
        case .pro18: 1.0     // Nano on ANE
        case .pro32: 3.0     // Base on ANE
        case .max: 3.0       // Base on ANE
        case .ultra: 8.0     // Pro on ANE
        }
    }
}

// MARK: - Apple Silicon Generation

enum AppleSiliconGeneration: String, Sendable {
    case m1 = "M1"
    case m2 = "M2"
    case m3 = "M3"
    case m4 = "M4"
    case unknown = "Unknown"

    static func detect(from brandString: String) -> AppleSiliconGeneration {
        if brandString.contains("M4") { return .m4 }
        if brandString.contains("M3") { return .m3 }
        if brandString.contains("M2") { return .m2 }
        if brandString.contains("M1") { return .m1 }
        return .unknown
    }
}

// MARK: - Dual Brain Configuration

/// Recommended model configuration for a given hardware tier.
struct DualBrainConfig: Sendable {
    /// Brain 1: Reasoning model on Metal GPU.
    let brain1ModelID: String
    /// Brain 2: Device action model. Empty string if dual-model not supported.
    let brain2ModelID: String
    /// Whether Brain 2 should target ANE via CoreML (vs shared GPU).
    let brain2UsesANE: Bool
    /// Whether both brains can be loaded simultaneously.
    let simultaneousLoading: Bool

    static func recommended(for tier: HardwareTier, aneAvailable: Bool) -> DualBrainConfig {
        switch tier {
        case .base8:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                brain2ModelID: "",
                brain2UsesANE: false,
                simultaneousLoading: false
            )
        case .base12:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit",
                brain2ModelID: "",
                brain2UsesANE: false,
                simultaneousLoading: false
            )
        case .base16, .pro18:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit",
                brain2ModelID: aneAvailable ? "epistemos-nano-1b" : "",
                brain2UsesANE: aneAvailable,
                simultaneousLoading: aneAvailable
            )
        case .pro32:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
                brain2ModelID: aneAvailable ? "epistemos-base-3b" : "epistemos-nano-1b",
                brain2UsesANE: aneAvailable,
                simultaneousLoading: true
            )
        case .max:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit",
                brain2ModelID: aneAvailable ? "epistemos-base-3b" : "epistemos-nano-1b",
                brain2UsesANE: aneAvailable,
                simultaneousLoading: true
            )
        case .ultra:
            return DualBrainConfig(
                brain1ModelID: "mlx-community/Qwen2.5-Coder-32B-Instruct-4bit",
                brain2ModelID: aneAvailable ? "epistemos-pro-8b" : "epistemos-base-3b",
                brain2UsesANE: aneAvailable,
                simultaneousLoading: true
            )
        }
    }
}
