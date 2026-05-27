#!/usr/bin/env swift

import CryptoKit
import Foundation
import Metal

enum ArtifactError: Error, CustomStringConvertible {
    case noMetalDevice
    case noCommandQueue
    case noBuffer(String)
    case noCommandBuffer
    case noCommandEncoder
    case noFunction(String)
    case noPipeline(String)
    case commandFailed(String)
    case missingRepoFile(String)
    case jsonEncoding

    var description: String {
        switch self {
        case .noMetalDevice:
            return "No default Metal device is available"
        case .noCommandQueue:
            return "Unable to create Metal command queue"
        case let .noBuffer(label):
            return "Unable to create Metal buffer: \(label)"
        case .noCommandBuffer:
            return "Unable to create Metal command buffer"
        case .noCommandEncoder:
            return "Unable to create Metal command encoder"
        case let .noFunction(name):
            return "Metal function not found: \(name)"
        case let .noPipeline(detail):
            return "Unable to create Metal pipeline: \(detail)"
        case let .commandFailed(detail):
            return "Metal command failed: \(detail)"
        case let .missingRepoFile(path):
            return "Missing required repo file: \(path)"
        case .jsonEncoding:
            return "Unable to encode artifact JSON"
        }
    }
}

struct Harness {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
}

struct RunResult {
    let artifact: [String: Any]
    let overallPass: Bool
    let outputPath: String
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = repoRoot.appendingPathComponent("artifacts/falsifiers/ulp_oracle")
let outputResultPath = outputDirectory.appendingPathComponent("result.json").path
let outputFailurePath = outputDirectory.appendingPathComponent("metal_failure_result.json").path
let commandString = "swift Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift --write-artifact"

func shell(_ launchPath: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "unknown"
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\n", with: " ")
        ?? "unknown"
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

func prefixedSHA256(_ data: Data) -> String {
    "sha256:\(sha256Hex(data))"
}

func canonicalDigest(measurements: [String: Any], passPerAxis: [String: Bool]) throws -> String {
    let payload: [String: Any] = [
        "measurements": measurements,
        "pass_per_axis": passPerAxis,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return prefixedSHA256(data)
}

func timestampUTC() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date())
}

func fp16Bits(_ value: Float16) -> UInt16 {
    var mutable = value
    return withUnsafeBytes(of: &mutable) { raw in
        raw.load(as: UInt16.self)
    }
}

func orderedFp16Bits(_ bits: UInt16) -> Int32 {
    if bits & 0x8000 == 0 {
        return Int32(bits)
    }
    return Int32(0x8000) - Int32(bits)
}

func fp16ULPDistance(actualBits: UInt16, expected: Float16) -> Int {
    let expectedBits = fp16Bits(expected)
    return abs(Int(orderedFp16Bits(actualBits) - orderedFp16Bits(expectedBits)))
}

func makeHarness() throws -> Harness {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw ArtifactError.noMetalDevice
    }
    guard let queue = device.makeCommandQueue() else {
        throw ArtifactError.noCommandQueue
    }

    let shaderPath = "Epistemos/Shaders/morph_eval_reduced.metal"
    let shaderURL = repoRoot.appendingPathComponent(shaderPath)
    guard FileManager.default.fileExists(atPath: shaderURL.path) else {
        throw ArtifactError.missingRepoFile(shaderPath)
    }

    let source = try String(contentsOf: shaderURL, encoding: .utf8)
    let options = MTLCompileOptions()
    if #available(macOS 15.0, *) {
        options.mathMode = .safe
    } else {
        options.fastMathEnabled = false
    }
    let library = try device.makeLibrary(source: source, options: options)
    guard let function = library.makeFunction(name: "morphOracleFp16") else {
        throw ArtifactError.noFunction("morphOracleFp16")
    }
    do {
        let pipeline = try device.makeComputePipelineState(function: function)
        return Harness(device: device, queue: queue, pipeline: pipeline)
    } catch {
        throw ArtifactError.noPipeline(error.localizedDescription)
    }
}

func makeBuffer<T>(_ values: [T], device: MTLDevice, label: String) throws -> MTLBuffer {
    try values.withUnsafeBufferPointer { pointer in
        guard let baseAddress = pointer.baseAddress else {
            throw ArtifactError.noBuffer(label)
        }
        guard let buffer = device.makeBuffer(
            bytes: baseAddress,
            length: values.count * MemoryLayout<T>.stride,
            options: .storageModeShared
        ) else {
            throw ArtifactError.noBuffer(label)
        }
        buffer.label = label
        return buffer
    }
}

func makeZeroedBuffer<T>(
    type: T.Type,
    count: Int,
    device: MTLDevice,
    label: String
) throws -> MTLBuffer {
    guard let buffer = device.makeBuffer(
        length: count * MemoryLayout<T>.stride,
        options: .storageModeShared
    ) else {
        throw ArtifactError.noBuffer(label)
    }
    memset(buffer.contents(), 0, count * MemoryLayout<T>.stride)
    buffer.label = label
    return buffer
}

func makeUInt32Buffer(_ value: UInt32, device: MTLDevice, label: String) throws -> MTLBuffer {
    var mutable = value
    guard let buffer = device.makeBuffer(
        bytes: &mutable,
        length: MemoryLayout<UInt32>.stride,
        options: .storageModeShared
    ) else {
        throw ArtifactError.noBuffer(label)
    }
    buffer.label = label
    return buffer
}

func dispatchOracle(
    harness: Harness,
    xBuffer: MTLBuffer,
    yBuffer: MTLBuffer,
    expOut: MTLBuffer,
    lnOut: MTLBuffer,
    emlOut: MTLBuffer,
    countBuffer: MTLBuffer,
    count: Int
) throws -> Double {
    guard let commandBuffer = harness.queue.makeCommandBuffer() else {
        throw ArtifactError.noCommandBuffer
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw ArtifactError.noCommandEncoder
    }

    encoder.setComputePipelineState(harness.pipeline)
    encoder.setBuffer(xBuffer, offset: 0, index: 0)
    encoder.setBuffer(yBuffer, offset: 0, index: 1)
    encoder.setBuffer(expOut, offset: 0, index: 2)
    encoder.setBuffer(lnOut, offset: 0, index: 3)
    encoder.setBuffer(emlOut, offset: 0, index: 4)
    encoder.setBuffer(countBuffer, offset: 0, index: 5)
    let width = max(1, min(harness.pipeline.maxTotalThreadsPerThreadgroup, 256))
    encoder.dispatchThreads(
        MTLSize(width: count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
    encoder.endEncoding()

    let start = DispatchTime.now().uptimeNanoseconds
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    let end = DispatchTime.now().uptimeNanoseconds
    if let error = commandBuffer.error {
        throw ArtifactError.commandFailed(error.localizedDescription)
    }
    return Double(end - start) / 1_000_000_000.0
}

func appendFloatBytes(_ values: [Float], to hasher: inout SHA256) {
    values.withUnsafeBufferPointer { pointer in
        if let baseAddress = pointer.baseAddress {
            hasher.update(data: Data(bytes: baseAddress, count: values.count * MemoryLayout<Float>.stride))
        }
    }
}

func makeOracleInputs() -> (x: [Float], y: [Float], fingerprint: String) {
    let logCount = 412_000
    let stressCount = 2_048
    let minValue = Foundation.log(0.5)
    let maxValue = Foundation.log(2.0)
    let span = maxValue - minValue

    var x: [Float] = []
    var y: [Float] = []
    x.reserveCapacity(logCount + stressCount)
    y.reserveCapacity(logCount + stressCount)

    for index in 0..<logCount {
        let base = Double(index) / Double(max(1, logCount - 1))
        let jitterSeed = (UInt64(index) &* 0x9E37_79B9_7F4A_7C15) &+ 0xD1B5_4A32_D192_ED03
        let jitter = Double(jitterSeed & 0xffff) / Double(0xffff) / Double(logCount)
        let u = min(1.0, max(0.0, base + jitter))
        let reverse = 1.0 - u
        x.append(Float(Foundation.exp(minValue + span * u)))
        y.append(Float(Foundation.exp(minValue + span * reverse)))
    }

    let stressValues: [Float] = [
        0.5,
        Float(Float16(0.5).nextUp),
        0.75,
        Float(Float16(1.0).nextDown),
        1.0,
        Float(Float16(1.0).nextUp),
        1.25,
        1.5,
        Float(Float16(2.0).nextDown),
        2.0,
    ]

    for index in 0..<stressCount {
        let a = stressValues[index % stressValues.count]
        let b = stressValues[(index * 7 + 3) % stressValues.count]
        x.append(a)
        y.append(b)
    }

    var hasher = SHA256()
    appendFloatBytes(x, to: &hasher)
    appendFloatBytes(y, to: &hasher)
    let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    return (x, y, digest)
}

func readUInt16Buffer(_ buffer: MTLBuffer, count: Int) -> [UInt16] {
    let pointer = buffer.contents().bindMemory(to: UInt16.self, capacity: count)
    return Array(UnsafeBufferPointer(start: pointer, count: count))
}

func runOracle() throws -> RunResult {
    let harness = try makeHarness()
    let inputs = makeOracleInputs()
    let count = inputs.x.count
    let evaluationsTotal = count * 3

    let xBuffer = try makeBuffer(inputs.x, device: harness.device, label: "fulp-metal.x")
    let yBuffer = try makeBuffer(inputs.y, device: harness.device, label: "fulp-metal.y")
    let expOut = try makeZeroedBuffer(type: UInt16.self, count: count, device: harness.device, label: "fulp-metal.expOut")
    let lnOut = try makeZeroedBuffer(type: UInt16.self, count: count, device: harness.device, label: "fulp-metal.lnOut")
    let emlOut = try makeZeroedBuffer(type: UInt16.self, count: count, device: harness.device, label: "fulp-metal.emlOut")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "fulp-metal.count")

    let harnessStart = Date()
    let metalSeconds = try dispatchOracle(
        harness: harness,
        xBuffer: xBuffer,
        yBuffer: yBuffer,
        expOut: expOut,
        lnOut: lnOut,
        emlOut: emlOut,
        countBuffer: countBuffer,
        count: count
    )

    let expBits = readUInt16Buffer(expOut, count: count)
    let lnBits = readUInt16Buffer(lnOut, count: count)
    let emlBits = readUInt16Buffer(emlOut, count: count)

    var maxExp = 0
    var maxLn = 0
    var maxEml = 0
    var invalidOutputs = 0

    for index in 0..<count {
        let x = Double(inputs.x[index])
        let y = Double(inputs.y[index])
        let expectedExp = Float16(Foundation.exp(x))
        let expectedLn = Float16(Foundation.log(y))
        let expectedEml = Float16(Foundation.exp(x) - Foundation.log(y))
        let expDistance = fp16ULPDistance(actualBits: expBits[index], expected: expectedExp)
        let lnDistance = fp16ULPDistance(actualBits: lnBits[index], expected: expectedLn)
        let emlDistance = fp16ULPDistance(actualBits: emlBits[index], expected: expectedEml)
        maxExp = max(maxExp, expDistance)
        maxLn = max(maxLn, lnDistance)
        maxEml = max(maxEml, emlDistance)
        if expBits[index].isNaNOrInfHalfBits || lnBits[index].isNaNOrInfHalfBits || emlBits[index].isNaNOrInfHalfBits {
            invalidOutputs += 1
        }
    }

    let harnessSeconds = Date().timeIntervalSince(harnessStart)
    let passPerAxis: [String: Bool] = [
        "evaluations_total": evaluationsTotal >= 1_242_144,
        "points_total": count >= 414_048,
        "max_ulp_exp": maxExp <= 2,
        "max_ulp_ln": maxLn <= 2,
        "max_ulp_eml": maxEml <= 2,
        "metal_wall_clock_seconds": metalSeconds <= 90.0,
        "invalid_outputs": invalidOutputs == 0,
    ]
    let overallPass = passPerAxis.values.allSatisfy { $0 }

    let measurements: [String: Any] = [
        "evaluations_total": ["value": evaluationsTotal, "unit": "count"],
        "points_total": ["value": count, "unit": "count"],
        "max_ulp_exp": ["value": maxExp, "unit": "ulp_fp16"],
        "max_ulp_ln": ["value": maxLn, "unit": "ulp_fp16"],
        "max_ulp_eml": ["value": maxEml, "unit": "ulp_fp16"],
        "metal_wall_clock_seconds": ["value": metalSeconds, "unit": "seconds"],
        "harness_wall_clock_seconds": ["value": harnessSeconds, "unit": "seconds"],
        "invalid_outputs": ["value": invalidOutputs, "unit": "count"],
        "grid_fingerprint": ["value": "sha256:\(inputs.fingerprint)", "unit": "sha256_hex"],
    ]
    let thresholds: [String: Any] = [
        "evaluations_total": ["operator": ">=", "value": 1_242_144, "unit": "count"],
        "points_total": ["operator": ">=", "value": 414_048, "unit": "count"],
        "max_ulp_exp": ["operator": "<=", "value": 2, "unit": "ulp_fp16"],
        "max_ulp_ln": ["operator": "<=", "value": 2, "unit": "ulp_fp16"],
        "max_ulp_eml": ["operator": "<=", "value": 2, "unit": "ulp_fp16"],
        "metal_wall_clock_seconds": ["operator": "<=", "value": 90, "unit": "seconds"],
        "invalid_outputs": ["operator": "==", "value": 0, "unit": "count"],
    ]

    let artifactKind = overallPass ? "primary_witness" : "failure_report"
    let fallbackTier = overallPass ? "Primary" : "Fail"
    let outputPath = overallPass ? outputResultPath : outputFailurePath
    let commit = shell("/usr/bin/git", ["rev-parse", "HEAD"])
    let swiftVersion = shell("/usr/bin/swift", ["--version"])
    let xcodeVersion = shell("/usr/bin/xcodebuild", ["-version"])
    let osBuild = shell("/usr/bin/sw_vers", ["-buildVersion"])
    let resultDigest = try canonicalDigest(measurements: measurements, passPerAxis: passPerAxis)

    let anomalies: [[String: String]] = overallPass ? [] : [[
        "kind": "metal_oracle_failure",
        "detail": "morphOracleFp16 failed at least one full F-ULP axis; keep AnswerPacket/Metal schema claims caveated and inspect metal_failure_result.json.",
    ]]

    let artifact: [String: Any] = [
        "falsifier_id": "F-ULP-Oracle",
        "schema_version": "2026-05-18.2",
        "artifact_kind": artifactKind,
        "hardware_pin": [
            "machine": "M2 Pro 14-inch 2023",
            "cpu": "12-core CPU",
            "gpu": "19-core GPU",
            "unified_memory_gb": 16,
            "memory_bandwidth_gb_s": 200,
        ],
        "command": commandString,
        "command_digest": prefixedSHA256(Data(commandString.utf8)),
        "runner_environment": [
            "cwd": "repo_root",
            "shell": "zsh",
            "env_policy": "script_owned",
            "locale": "C",
            "timezone": "UTC",
            "os_build": "Darwin \(osBuild)",
            "toolchain_identity": [
                "xcodebuild": xcodeVersion,
                "swift": swiftVersion,
                "rustc": "not_used",
                "python": "not_used",
            ],
            "thermal_state_start": "unknown",
            "thermal_state_end": "unknown",
            "power_source": "unknown",
        ],
        "commit_sha": commit,
        "fixture_id": "fulp_metal_morph_oracle_412k_log_2k_stress_v1",
        "timestamp_utc": timestampUTC(),
        "result_digest": resultDigest,
        "measurements": measurements,
        "acceptance_thresholds": thresholds,
        "pass_per_axis": passPerAxis,
        "overall_pass": overallPass,
        "fallback_tier": fallbackTier,
        "anomalies": anomalies,
        "notes": "Metal morphOracleFp16 full hardware witness generated from Epistemos/Shaders/morph_eval_reduced.metal with safe math mode in the harness; compares exp/ln/eml half outputs against Foundation fp64-rounded-to-fp16 reference over 412,000 log-sampled points + 2,048 stress points. PageGather and ControllerKernelPack primary hardware artifacts remain pending.",
    ]

    return RunResult(artifact: artifact, overallPass: overallPass, outputPath: outputPath)
}

extension UInt16 {
    var isNaNOrInfHalfBits: Bool {
        (self & 0x7c00) == 0x7c00
    }
}

func writeArtifact(_ artifact: [String: Any], to path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: artifact, options: [.prettyPrinted, .sortedKeys])
    guard var text = String(data: data, encoding: .utf8) else {
        throw ArtifactError.jsonEncoding
    }
    text.append("\n")
    try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
    )
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}

do {
    let shouldWrite = CommandLine.arguments.contains("--write-artifact")
    let result = try runOracle()
    let data = try JSONSerialization.data(withJSONObject: result.artifact, options: [.prettyPrinted, .sortedKeys])
    let summary = String(data: data, encoding: .utf8) ?? "{}"
    if shouldWrite {
        try writeArtifact(result.artifact, to: result.outputPath)
        print("wrote \(result.outputPath)")
    } else {
        print(summary)
    }
    if !result.overallPass {
        exit(2)
    }
} catch {
    fputs("fulp-metal-oracle-artifact failed: \(error)\n", stderr)
    exit(1)
}
