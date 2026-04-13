import Darwin
import Foundation
import os

#if canImport(epistemos_coreFFI)
import epistemos_coreFFI
#endif

nonisolated enum LocalInferenceSerialFallbackMode: String, Sendable, Equatable {
    case resident = "resident"
    case ssdStreaming = "ssd_streaming"
}

nonisolated struct LocalInferenceSerialSnapshot: Sendable, Equatable {
    let phase: String
    let fallbackMode: LocalInferenceSerialFallbackMode
    let shouldStreamExpertsFromSSD: Bool
    let turnBoundaryReadaheadAllowed: Bool
    let expertPrefetchAllowed: Bool
    let turnIndex: UInt64
    let availableMemoryBytes: UInt64
    let nonExpertResidentBytes: UInt64
}

nonisolated enum LocalInferenceSerialControllerError: LocalizedError, Equatable {
    case turnAlreadyOpen
    case noTurnOpen
    case gpuComputeActive
    case invalidTransition

    var errorDescription: String? {
        switch self {
        case .turnAlreadyOpen:
            "A serial inference turn is already active."
        case .noTurnOpen:
            "No serial inference turn is active."
        case .gpuComputeActive:
            "Disk reads are forbidden during active GPU compute."
        case .invalidTransition:
            "The requested serial inference transition is invalid."
        }
    }
}

nonisolated enum LocalInferenceMemoryPressureMonitor {
    static func availableMemoryBytes() -> UInt64 {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return 0
        }

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let reclaimablePages = UInt64(statistics.free_count)
            + UInt64(statistics.inactive_count)
            + UInt64(statistics.purgeable_count)
        return reclaimablePages * UInt64(pageSize)
    }
}

nonisolated final class LocalInferenceSerialController: @unchecked Sendable {
    static let defaultPressureThresholdBytes: UInt64 = 1_200_000_000
    static let defaultRecoveryThresholdBytes: UInt64 = 1_800_000_000
    static let defaultNonExpertResidentBytes: UInt64 = 3_000_000_000

    private let pressureThresholdBytes: UInt64
    private let recoveryThresholdBytes: UInt64
    private let nonExpertResidentBytes: UInt64

#if canImport(epistemos_coreFFI)
    private let bridge: SerialInferenceController
#else
    private enum FallbackPhase: String {
        case idle
        case turnBoundary = "turn_boundary"
        case betweenStages = "between_stages"
        case ssdRead = "ssd_read"
        case gpuCompute = "gpu_compute"
    }

    private var fallbackPhase: FallbackPhase = .idle
    private var fallbackTurnIndex: UInt64 = 0
    private var fallbackTurnOpen = false
    private var fallbackAvailableMemoryBytes: UInt64 = 0
#endif

    init(
        pressureThresholdBytes: UInt64 = LocalInferenceSerialController.defaultPressureThresholdBytes,
        recoveryThresholdBytes: UInt64 = LocalInferenceSerialController.defaultRecoveryThresholdBytes,
        nonExpertResidentBytes: UInt64 = LocalInferenceSerialController.defaultNonExpertResidentBytes
    ) {
        self.pressureThresholdBytes = max(pressureThresholdBytes, 1)
        self.recoveryThresholdBytes = max(recoveryThresholdBytes, self.pressureThresholdBytes)
        self.nonExpertResidentBytes = max(nonExpertResidentBytes, 1)
#if canImport(epistemos_coreFFI)
        self.bridge = SerialInferenceController(
            pressureThresholdBytes: self.pressureThresholdBytes,
            recoveryThresholdBytes: self.recoveryThresholdBytes,
            nonExpertResidentBytes: self.nonExpertResidentBytes
        )
#endif
    }

    func refreshAvailableMemory() -> LocalInferenceSerialSnapshot {
        let availableMemoryBytes = LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
#if canImport(epistemos_coreFFI)
        bridge.updateAvailableMemory(availableBytes: availableMemoryBytes)
#else
        fallbackAvailableMemoryBytes = availableMemoryBytes
#endif
        return snapshot()
    }

    func beginTurn() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.beginTurn()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard !fallbackTurnOpen, fallbackPhase == .idle else {
            throw LocalInferenceSerialControllerError.turnAlreadyOpen
        }
        fallbackTurnOpen = true
        fallbackTurnIndex += 1
        fallbackPhase = .turnBoundary
#endif
    }

    func endTurn() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.endTurn()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        guard fallbackPhase == .turnBoundary || fallbackPhase == .betweenStages else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
        fallbackTurnOpen = false
        fallbackPhase = .idle
#endif
    }

    func recordTurnBoundaryReadahead() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.recordTurnBoundaryReadahead()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        guard fallbackPhase == .turnBoundary else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
#endif
    }

    func beginSsdRead() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.beginSsdRead()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        if fallbackPhase == .gpuCompute {
            throw LocalInferenceSerialControllerError.gpuComputeActive
        }
        guard fallbackPhase == .turnBoundary || fallbackPhase == .betweenStages else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
        fallbackPhase = .ssdRead
#endif
    }

    func finishSsdRead() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.finishSsdRead()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        guard fallbackPhase == .ssdRead else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
        fallbackPhase = .betweenStages
#endif
    }

    func beginGpuCompute() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.beginGpuCompute()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        guard fallbackPhase == .turnBoundary || fallbackPhase == .betweenStages else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
        fallbackPhase = .gpuCompute
#endif
    }

    func finishGpuCompute() throws {
#if canImport(epistemos_coreFFI)
        do {
            try bridge.finishGpuCompute()
        } catch let error as SerialInferenceTransitionError {
            throw mapBridgeError(error)
        }
#else
        guard fallbackTurnOpen else {
            throw LocalInferenceSerialControllerError.noTurnOpen
        }
        guard fallbackPhase == .gpuCompute else {
            throw LocalInferenceSerialControllerError.invalidTransition
        }
        fallbackPhase = .betweenStages
#endif
    }

    func snapshot() -> LocalInferenceSerialSnapshot {
#if canImport(epistemos_coreFFI)
        let bridgeSnapshot = bridge.snapshot()
        return LocalInferenceSerialSnapshot(
            phase: bridgeSnapshot.phase,
            fallbackMode: mapBridgeFallbackMode(bridgeSnapshot.fallbackMode),
            shouldStreamExpertsFromSSD: bridgeSnapshot.shouldStreamExpertsFromSsd,
            turnBoundaryReadaheadAllowed: bridgeSnapshot.turnBoundaryReadaheadAllowed,
            expertPrefetchAllowed: bridgeSnapshot.expertPrefetchAllowed,
            turnIndex: bridgeSnapshot.turnIndex,
            availableMemoryBytes: bridgeSnapshot.availableMemoryBytes,
            nonExpertResidentBytes: bridgeSnapshot.nonExpertResidentBytes
        )
#else
        let fallbackMode: LocalInferenceSerialFallbackMode =
            fallbackAvailableMemoryBytes <= pressureThresholdBytes ? .ssdStreaming : .resident
        return LocalInferenceSerialSnapshot(
            phase: fallbackPhase.rawValue,
            fallbackMode: fallbackMode,
            shouldStreamExpertsFromSSD: fallbackMode == .ssdStreaming,
            turnBoundaryReadaheadAllowed: fallbackPhase == .turnBoundary,
            expertPrefetchAllowed: false,
            turnIndex: fallbackTurnIndex,
            availableMemoryBytes: fallbackAvailableMemoryBytes,
            nonExpertResidentBytes: nonExpertResidentBytes
        )
#endif
    }

    func adjustedCacheLimitBytes(suggestedBytes: Int) -> Int {
        let currentSnapshot = snapshot()
        guard currentSnapshot.shouldStreamExpertsFromSSD else {
            return suggestedBytes
        }
        let residentLimit = Int(min(currentSnapshot.nonExpertResidentBytes, UInt64(Int.max)))
        return min(suggestedBytes, residentLimit)
    }

#if canImport(epistemos_coreFFI)
    private func mapBridgeFallbackMode(_ mode: SerialFallbackMode) -> LocalInferenceSerialFallbackMode {
        switch mode {
        case .resident:
            .resident
        case .ssdStreaming:
            .ssdStreaming
        }
    }

    private func mapBridgeError(_ error: SerialInferenceTransitionError) -> LocalInferenceSerialControllerError {
        switch error {
        case .GpuComputeActive(message: _):
            .gpuComputeActive
        case .NoOpenTurn(message: _):
            .noTurnOpen
        case .TurnBoundaryOnly(message: _):
            .invalidTransition
        case .InvalidTransition(message: _):
            .invalidTransition
        }
    }
#endif
}
