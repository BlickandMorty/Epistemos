import Foundation
import AVFoundation
import OSLog

@MainActor @Observable
final class AudioRecorder {
    var isRecording = false
    var isMicrophoneAuthorized = false
    var currentRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private let log = Logger(subsystem: "com.epistemos", category: "AudioRecorder")

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        isMicrophoneAuthorized = (status == .authorized)
    }

    func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        self.isMicrophoneAuthorized = granted
        return granted
    }

    func startRecording() throws {
        guard isMicrophoneAuthorized else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted."])
        }

        let tempDir = FileManager.default.temporaryDirectory
        let audioFilename = tempDir.appendingPathComponent("capture_\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)

        guard recorder.prepareToRecord() else {
            log.error("prepareToRecord() failed for \(audioFilename.path)")
            throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare audio recording."])
        }

        guard recorder.record() else {
            recorder.stop()
            log.error("record() returned false for \(audioFilename.path)")
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio recording hardware."])
        }

        audioRecorder = recorder
        isRecording = true
        currentRecordingURL = audioFilename
        log.info("Started recording at \(audioFilename.path)")
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        log.info("Stopped recording")
        return currentRecordingURL
    }
}
