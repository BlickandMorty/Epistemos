import Foundation
import os
import Vision

// MARK: - Screen2AX Fusion Service

/// Unified perception pipeline: AX-first with Vision framework fallback.
///
/// Based on R4/R5 research results (2026-03-24):
/// - R5: 91% of macOS apps have FULL AX metadata (>20 interactive elements)
/// - R4: OmniParser EasyOCR is too slow (20s). Apple Vision OCR is fast (<200ms)
/// - R4: YOLO element detection is 260ms — viable for fallback
///
/// Pipeline:
/// 1. Try native AX tree (omega-ax walkAxTreeJson) — covers ~90% of apps
/// 2. If sparse (<10 interactive elements), enrich with Apple Vision OCR
/// 3. Full Screen2AX VLM only on explicit user request (async, slow path)
@MainActor @Observable
final class Screen2AXFusion {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "Screen2AXFusion")

    private let screenCapture: ScreenCaptureService

    /// Threshold for triggering Vision OCR enrichment.
    /// Based on R5 audit: real apps have 100-900+ interactive elements.
    /// Set to 10 to avoid false triggers on minimized/backgrounded apps.
    let sparseThreshold: Int = 10

    /// Last perception result.
    private(set) var lastPerception: PerceptionResult?

    init(screenCapture: ScreenCaptureService) {
        self.screenCapture = screenCapture
    }

    /// Full perception pipeline for a target app.
    /// Returns a unified AX tree (native or enriched with OCR).
    func perceive(appName: String) async -> PerceptionResult {
        let start = ContinuousClock.now

        // Step 1: Native AX tree
        guard let pid = pidForAppName(appName) else {
            let result = PerceptionResult(
                axTreeJson: "{}",
                interactiveCount: 0,
                method: .failed,
                latencyMs: 0,
                ocrTexts: []
            )
            lastPerception = result
            return result
        }

        let axJson = walkAxTreeJson(pid: Int64(pid))
        let interactiveCount = countInteractiveElements(axJson)

        // Step 2: Check if AX tree is rich enough
        if interactiveCount >= sparseThreshold {
            let elapsed = start.duration(to: ContinuousClock.now).milliseconds
            let result = PerceptionResult(
                axTreeJson: axJson,
                interactiveCount: interactiveCount,
                method: .nativeAX,
                latencyMs: elapsed,
                ocrTexts: []
            )
            lastPerception = result
            log.info("Perception: native AX, \(interactiveCount) interactive, \(elapsed)ms")
            return result
        }

        // Step 3: Sparse AX tree — enrich with Apple Vision OCR
        log.info("Sparse AX (\(interactiveCount) interactive), enriching with Vision OCR")

        let bundleID = bundleIDForPID(pid)
        let ocrTexts = await captureAndOCR(bundleID: bundleID)

        // Merge OCR results into AX JSON
        let enrichedJson = mergeOCRIntoAXTree(axJson: axJson, ocrTexts: ocrTexts)

        let elapsed = start.duration(to: ContinuousClock.now).milliseconds
        let result = PerceptionResult(
            axTreeJson: enrichedJson,
            interactiveCount: interactiveCount + ocrTexts.count,
            method: .axPlusVisionOCR,
            latencyMs: elapsed,
            ocrTexts: ocrTexts
        )
        lastPerception = result
        log.info("Perception: AX+VisionOCR, \(result.interactiveCount) elements, \(elapsed)ms")
        return result
    }

    /// Quick AX-only perception (no fallback). Used for verify loops.
    func perceiveQuick(pid: Int32) -> PerceptionResult {
        let start = ContinuousClock.now
        let axJson = walkAxTreeJson(pid: Int64(pid))
        let count = countInteractiveElements(axJson)
        let elapsed = start.duration(to: ContinuousClock.now).milliseconds
        return PerceptionResult(
            axTreeJson: axJson,
            interactiveCount: count,
            method: .nativeAX,
            latencyMs: elapsed,
            ocrTexts: []
        )
    }

    // MARK: - Apple Vision OCR

    /// Capture a screenshot and run Apple Vision text recognition.
    /// Much faster than EasyOCR (~50-200ms vs 20+ seconds from R4 results).
    private func captureAndOCR(bundleID: String?) async -> [OCRTextRegion] {
        // Capture screenshot
        let image: CGImage?
        if let bundleID {
            image = try? await screenCapture.captureApp(bundleID: bundleID)
        } else {
            image = try? await screenCapture.captureFrontmostWindow()
        }

        guard let cgImage = image else {
            log.warning("Screenshot capture failed for OCR")
            return []
        }

        // Run Vision text recognition
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let regions: [OCRTextRegion] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first,
                          candidate.confidence > 0.5 else {
                        return nil
                    }

                    let box = obs.boundingBox
                    return OCRTextRegion(
                        text: candidate.string,
                        confidence: Double(candidate.confidence),
                        // Vision coordinates: origin bottom-left, normalized 0-1
                        // Convert to screen coordinates (origin top-left, pixels)
                        normalizedBounds: NormalizedRect(
                            x: box.origin.x,
                            y: 1.0 - box.origin.y - box.height,
                            width: box.width,
                            height: box.height
                        )
                    )
                }
                continuation.resume(returning: regions)
            }

            request.recognitionLevel = .fast // Use fast for <100ms target
            request.usesLanguageCorrection = false // Skip for speed

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                self.log.warning("Vision OCR failed: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Merging

    /// Inject OCR text regions as synthetic AX elements into the tree JSON.
    private func mergeOCRIntoAXTree(axJson: String, ocrTexts: [OCRTextRegion]) -> String {
        guard !ocrTexts.isEmpty,
              var data = axJson.data(using: .utf8),
              var tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var elements = tree["elements"] as? [[String: Any]] else {
            return axJson
        }

        // Add OCR regions as synthetic AXStaticText elements
        for region in ocrTexts {
            let synthetic: [String: Any] = [
                "role": "AXStaticText",
                "title": region.text,
                "description": "OCR-detected text",
                "value": region.text,
                "is_interactive": false,
                "is_synthetic": true,
                "confidence": region.confidence,
                "position_x": region.normalizedBounds.x,
                "position_y": region.normalizedBounds.y,
                "size_width": region.normalizedBounds.width,
                "size_height": region.normalizedBounds.height,
            ]
            elements.append(synthetic)
        }

        tree["elements"] = elements
        tree["ocr_enriched"] = true
        tree["ocr_count"] = ocrTexts.count

        guard let enrichedData = try? JSONSerialization.data(withJSONObject: tree),
              let enrichedJson = String(data: enrichedData, encoding: .utf8) else {
            return axJson
        }
        return enrichedJson
    }

    // MARK: - Helpers

    private func countInteractiveElements(_ json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = tree["elements"] as? [[String: Any]] else {
            return 0
        }
        return elements.filter { $0["is_interactive"] as? Bool == true }.count
    }

    private func pidForAppName(_ name: String) -> Int32? {
        let apps = NSWorkspace.shared.runningApplications
        let lowerName = name.lowercased()
        // Exact match first
        if let app = apps.first(where: { $0.localizedName?.lowercased() == lowerName }) {
            return app.processIdentifier
        }
        // Partial match fallback
        return apps.first(where: { $0.localizedName?.lowercased().contains(lowerName) == true })?.processIdentifier
    }

    private func bundleIDForPID(_ pid: Int32) -> String? {
        NSWorkspace.shared.runningApplications
            .first { $0.processIdentifier == pid }?
            .bundleIdentifier
    }
}

// MARK: - Types

struct PerceptionResult: Sendable {
    let axTreeJson: String
    let interactiveCount: Int
    let method: PerceptionMethod
    let latencyMs: Double
    let ocrTexts: [OCRTextRegion]
}

enum PerceptionMethod: String, Sendable {
    case nativeAX = "NativeAX"
    case axPlusVisionOCR = "AX+VisionOCR"
    case screen2AXVLM = "Screen2AX-VLM"
    case failed = "Failed"
}

struct OCRTextRegion: Sendable {
    let text: String
    let confidence: Double
    let normalizedBounds: NormalizedRect
}

struct NormalizedRect: Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Duration Extension

private extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000.0 + Double(attoseconds) / 1_000_000_000_000_000.0
    }
}
