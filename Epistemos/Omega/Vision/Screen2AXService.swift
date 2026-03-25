import Foundation
import AppKit

// MARK: - Screen2AX Service

/// Fallback perception pipeline: when the native AX tree is sparse,
/// sends a screenshot to a VLM to reconstruct UI element positions.
///
/// This uses the existing MLX inference pipeline (via OmegaInferenceBridge)
/// to analyze screenshots and produce synthetic AX tree data.
///
/// Reference: Screen2AX achieves 77% F1 in tree reconstruction.
@MainActor
final class Screen2AXService {
    private let captureService = ScreenCaptureService()

    /// Analyze the frontmost window when AX tree is sparse.
    /// Returns a JSON-encoded synthetic AX tree.
    func reconstructFromScreen() async -> String {
        guard let image = await captureService.captureFrontmostWindow() else {
            return "{\"elements\":[],\"error\":\"Failed to capture screen\"}"
        }

        // For now, return a placeholder response indicating the screenshot was captured.
        // Full VLM integration requires a vision-capable model loaded via MLX.
        // This will be connected when a suitable lightweight VLM is available.
        let width = image.width
        let height = image.height

        return """
        {
            "source": "screen2ax",
            "image_size": {"width": \(width), "height": \(height)},
            "elements": [],
            "note": "VLM analysis pending — requires vision-capable MLX model"
        }
        """
    }

    /// Check if Screen2AX fallback should be triggered based on AX tree sparsity.
    /// R5 audit (2026-03-24): 91% of macOS apps have >20 interactive elements.
    /// Threshold raised from 5 → 10 to avoid false triggers on minimized apps.
    func shouldTriggerFallback(interactiveElementCount: Int) -> Bool {
        interactiveElementCount < 10
    }
}
