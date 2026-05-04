import Foundation
import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// MARK: - TernaryControlRoomModel
// ---------------------------------------------------------------------------

/// Observable model for the Ternary Control Room.
///
/// This is the **breakthrough UX** — a real-time view into the ternary
/// inference path. It supports backend selection, live metrics, implant
/// (steering delta) management, and a ghost-text live draft overlay.
@MainActor
public final class TernaryControlRoomModel: ObservableObject {
    /// Selected inference backend.
    @Published public var selectedBackend: String = "TernaryMetal" {
        didSet { config.backend = selectedBackend }
    }

    /// Enable freeform (non-deterministic) generation.
    @Published public var freeformEnabled: Bool = false {
        didSet { config.freeform = freeformEnabled }
    }

    /// Show live draft ghost text.
    @Published public var liveDraftEnabled: Bool = true {
        didSet { config.live_draft = liveDraftEnabled }
    }

    /// The prompt currently being edited.
    @Published public var prompt: String = ""

    /// The last returned metrics (nil before first run).
    @Published public var lastMetrics: TernaryMetrics?

    /// Active steering deltas (implant panel).
    @Published public var implants: [SteeringDelta] = []

    /// Is an inference run in flight?
    @Published public var isRunning = false

    /// Latest error from the Rust runtime.
    @Published public var lastError: String?

    /// Ghost text produced by live draft.
    @Published public var ghostText: String = ""

    private var config = TernaryRunConfig(
        backend: "TernaryMetal",
        max_tokens: 256,
        freeform: false,
        live_draft: true
    )

    /// Available backends for the selector.
    public let backends = ["DenseMlx", "BitnetReference", "TernaryMetal"]

    public init() {}

    // MARK: - Run

    /// Execute a ternary inference run via UniFFI.
    public func run(prompt: String) async {
        guard !prompt.isEmpty else {
            lastError = "Prompt cannot be empty."
            return
        }
        await MainActor.run { isRunning = true }
        defer { Task { @MainActor in isRunning = false } }

        do {
            let metrics = try await Task.detached(priority: .userInitiated) { [config] in
                helios_ffi.run_ternary_prompt(prompt: prompt, cfg: config)
            }.value

            await MainActor.run {
                self.lastMetrics = metrics
                self.lastError = nil
                // Simulate ghost text from a "live draft"
                if self.liveDraftEnabled {
                    self.ghostText = " [draft: \(String(format: "%.1f", metrics.decode_tok_s)) tok/s]"
                } else {
                    self.ghostText = ""
                }
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Implants

    /// Add a steering delta (implant) to the active set.
    public func addImplant(name: String, strength: Double) {
        let delta = SteeringDelta(id: UUID(), name: name, strength: strength, isActive: true)
        implants.append(delta)
    }

    /// Remove an implant by ID.
    public func removeImplant(id: UUID) {
        implants.removeAll { $0.id == id }
    }

    /// Rollback (deactivate) the last added implant.
    public func rollbackLastImplant() {
        guard let last = implants.last else { return }
        if let idx = implants.firstIndex(where: { $0.id == last.id }) {
            implants[idx].isActive = false
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - SteeringDelta
// ---------------------------------------------------------------------------

/// A single steering delta ("implant") applied to the inference path.
public struct SteeringDelta: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var strength: Double
    public var isActive: Bool
}

// ---------------------------------------------------------------------------
// MARK: - TernaryControlRoomView
// ---------------------------------------------------------------------------

public struct TernaryControlRoomView: View {
    @StateObject private var model = TernaryControlRoomModel()
    @State private var draftInput: String = ""

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            leftPanel
            Divider()
            rightPanel
        }
        .frame(minWidth: 720, minHeight: 420)
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            backendSelector
            Divider()
            promptEditor
            Divider()
            runControls
            if !model.ghostText.isEmpty {
                ghostTextOverlay
            }
        }
        .padding()
        .frame(minWidth: 380)
    }

    private var backendSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backend")
                .font(.headline)
            Picker("Backend", selection: $model.selectedBackend) {
                ForEach(model.backends, id: \.self) { b in
                    Text(b).tag(b)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                Toggle("Freeform", isOn: $model.freeformEnabled)
                Toggle("Live Draft", isOn: $model.liveDraftEnabled)
            }
            .font(.caption)
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Prompt")
                .font(.headline)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftInput)
                    .font(.body.monospaced())
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                if draftInput.isEmpty {
                    Text("Type a prompt …")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }
            }
        }
    }

    private var runControls: some View {
        HStack {
            Button(model.isRunning ? "Running …" : "Run (⌘↩)") {
                Task { await model.run(prompt: draftInput) }
            }
            .disabled(model.isRunning || draftInput.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)

            if model.isRunning {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Spacer()

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private var ghostTextOverlay: some View {
        Text(model.ghostText)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary.opacity(0.6))
            .padding(.horizontal, 4)
            .transition(.opacity)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            metricsPanel
            Divider()
            implantPanel
        }
        .padding()
        .frame(minWidth: 300)
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics")
                .font(.headline)
            if let m = model.lastMetrics {
                MetricRow(label: "Prompt", value: String(format: "%.1f ms", m.prompt_ms))
                MetricRow(label: "Decode", value: String(format: "%.1f tok/s", m.decode_tok_s))
                MetricRow(label: "Peak RAM", value: byteString(m.peak_bytes))
                MetricRow(label: "Deterministic", value: m.deterministic ? "Yes" : "No")
                MetricRow(label: "Active Tier", value: tierFromBackend(model.selectedBackend))
            } else {
                Text("No run yet")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private var implantPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Implants")
                    .font(.headline)
                Spacer()
                Button("Rollback") {
                    model.rollbackLastImplant()
                }
                .disabled(model.implants.isEmpty)
                .font(.caption)
            }

            ForEach(model.implants) { implant in
                HStack {
                    Image(systemName: implant.isActive ? "bolt.fill" : "bolt.slash")
                        .foregroundStyle(implant.isActive ? .yellow : .gray)
                    Text(implant.name)
                        .font(.body)
                    Spacer()
                    Text(String(format: "%.2f", implant.strength))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Button {
                        model.removeImplant(id: implant.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.implants.isEmpty {
                Text("No active steering deltas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Name", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("Add") {
                    model.addImplant(name: "New Delta", strength: 0.10)
                }
                .font(.caption)
                .disabled(true) // wired to real controls in production
            }
        }
    }

    // MARK: - Helpers

    private func byteString(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    private func tierFromBackend(_ backend: String) -> String {
        switch backend {
        case "DenseMlx":        return "L0 Exact Hot"
        case "BitnetReference": return "L1 Compressed"
        case "TernaryMetal":    return "L2 Shadow Sketch"
        default:                return "L? Unknown"
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - MetricRow
// ---------------------------------------------------------------------------

public struct MetricRow: View {
    let label: String
    let value: String

    public var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
            Spacer()
        }
    }
}
