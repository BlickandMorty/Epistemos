import Foundation

// MARK: - Types

struct AudioSegment: Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let speaker: String?
}

struct TranscribedAudio: Sendable, Identifiable {
    let id: UUID
    let sourceURL: URL
    let fullText: String
    let segments: [AudioSegment]
    let wordsPerMinute: Double
    let hesitationFrequency: Double  // hesitations per 100 words
    let speakerCount: Int
}

// MARK: - AudioTranscriber

/// Transcribes audio files using mlx-whisper (primary) or whisper.cpp (fallback).
/// Captures paralinguistic cues (hesitations, pacing) for stylometric DNA
/// as required by the research paper.
actor AudioTranscriber {

    enum TranscriberBackend: Sendable {
        case mlxWhisper
        case whisperCpp
        case unavailable
    }

    private let pythonPath: String

    init(pythonPath: String = "/usr/bin/python3") {
        self.pythonPath = pythonPath
    }

    // MARK: - Public

    func transcribe(audioURL: URL) async throws -> TranscribedAudio {
        let backend = await detectBackend()

        guard backend != .unavailable else {
            throw AudioTranscriberError.noBackendAvailable
        }

        let jsonOutput: Data
        switch backend {
        case .mlxWhisper:
            jsonOutput = try await runMLXWhisper(audioURL: audioURL)
        case .whisperCpp:
            jsonOutput = try await runWhisperCpp(audioURL: audioURL)
        case .unavailable:
            throw AudioTranscriberError.noBackendAvailable
        }

        return try parseWhisperOutput(jsonData: jsonOutput, sourceURL: audioURL)
    }

    func detectBackend() async -> TranscriberBackend {
        // Check mlx-whisper via Python import
        if let _ = try? await runProcess(
            executable: pythonPath,
            arguments: ["-c", "import mlx_whisper; print('OK')"]
        ) {
            return .mlxWhisper
        }

        // Check whisper.cpp
        if let _ = try? await runProcess(
            executable: "/usr/bin/which",
            arguments: ["whisper"]
        ) {
            return .whisperCpp
        }

        return .unavailable
    }

    // MARK: - MLX Whisper

    private func runMLXWhisper(audioURL: URL) async throws -> Data {
        let script = """
        import json, sys
        import mlx_whisper

        result = mlx_whisper.transcribe(
            sys.argv[1],
            path_or_hf_repo="mlx-community/whisper-large-v3-turbo",
            word_timestamps=True
        )
        print(json.dumps(result))
        """

        let tempScript = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf_whisper_\(UUID().uuidString).py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempScript) }

        let output = try await runProcess(
            executable: pythonPath,
            arguments: [tempScript.path, audioURL.path]
        )

        guard let data = output.data(using: .utf8) else {
            throw AudioTranscriberError.invalidOutput
        }
        return data
    }

    // MARK: - Whisper.cpp Fallback

    private func runWhisperCpp(audioURL: URL) async throws -> Data {
        let output = try await runProcess(
            executable: "/usr/local/bin/whisper",
            arguments: ["-f", audioURL.path, "-oj", "-l", "auto"]
        )
        guard let data = output.data(using: .utf8) else {
            throw AudioTranscriberError.invalidOutput
        }
        return data
    }

    // MARK: - JSON Parsing

    private func parseWhisperOutput(jsonData: Data, sourceURL: URL) throws -> TranscribedAudio {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AudioTranscriberError.invalidOutput
        }

        let fullText = json["text"] as? String ?? ""
        var segments: [AudioSegment] = []
        var totalDuration: TimeInterval = 0

        if let rawSegments = json["segments"] as? [[String: Any]] {
            for seg in rawSegments {
                let start = seg["start"] as? Double ?? 0
                let end = seg["end"] as? Double ?? 0
                let text = seg["text"] as? String ?? ""
                let speaker = seg["speaker"] as? String

                segments.append(AudioSegment(
                    startTime: start,
                    endTime: end,
                    text: text,
                    speaker: speaker
                ))
                if end > totalDuration { totalDuration = end }
            }
        }

        // Compute paralinguistic metrics
        let words = fullText.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let wordCount = words.count

        let wordsPerMinute: Double
        if totalDuration > 0 {
            wordsPerMinute = Double(wordCount) / (totalDuration / 60.0)
        } else {
            wordsPerMinute = 0
        }

        // Count hesitation markers for stylometric DNA
        let hesitationPatterns = ["uh", "um", "erm", "hmm", "hm", "er", "ah"]
        let hesitationCount = words.filter { word in
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return hesitationPatterns.contains(lower)
        }.count

        let hesitationFrequency: Double
        if wordCount > 0 {
            hesitationFrequency = Double(hesitationCount) / Double(wordCount) * 100.0
        } else {
            hesitationFrequency = 0
        }

        let uniqueSpeakers = Set(segments.compactMap(\.speaker))

        return TranscribedAudio(
            id: UUID(),
            sourceURL: sourceURL,
            fullText: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments,
            wordsPerMinute: wordsPerMinute,
            hesitationFrequency: hesitationFrequency,
            speakerCount: max(uniqueSpeakers.count, 1)
        )
    }

    // MARK: - Process Execution

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { proc in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AudioTranscriberError.processFailed(errorMsg))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum AudioTranscriberError: Error, LocalizedError {
    case noBackendAvailable
    case invalidOutput
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "Neither mlx-whisper nor whisper.cpp found. Audio transcription unavailable."
        case .invalidOutput:
            return "Failed to parse whisper output as JSON."
        case .processFailed(let msg):
            return "Transcription process failed: \(msg)"
        }
    }
}
