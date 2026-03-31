import SwiftUI

// MARK: - Hex Viewer for Corrupted Notes

struct HexViewerView: View {
    let fileURL: URL
    let onAcceptRepair: (String) -> Void

    @State private var rawBytes: Data = Data()
    @State private var repairedText = ""
    @State private var corruptionType = "none"
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let loadError {
                ContentUnavailableView {
                    Label("Load Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                }
            } else {
                HSplitView {
                    hexDumpPane
                    repairedTextPane
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear(perform: loadFile)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.badge.gearshape")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("Note Recovery")
                    .font(.title3.bold())
                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if corruptionType != "none" {
                Label(corruptionLabel, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Accept Repair") {
                onAcceptRepair(repairedText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(repairedText.isEmpty || corruptionType == "none")
        }
        .padding()
    }

    private var corruptionLabel: String {
        switch corruptionType {
        case "null_bytes": "Null bytes detected"
        case "bom_marker": "BOM marker detected"
        case "invalid_utf8": "Invalid UTF-8 encoding"
        case "truncated_multibyte": "Truncated multibyte sequence"
        default: "Unknown corruption"
        }
    }

    // MARK: - Hex Dump Pane

    private var hexDumpPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Raw Bytes")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView([.vertical, .horizontal]) {
                Text(hexDumpString)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .frame(minWidth: 350)
    }

    private var hexDumpString: String {
        var lines: [String] = []
        let bytes = Array(rawBytes)
        let rowSize = 16

        for offset in stride(from: 0, to: bytes.count, by: rowSize) {
            let end = min(offset + rowSize, bytes.count)
            let row = bytes[offset..<end]

            // Offset
            let offsetStr = String(format: "%08X", offset)

            // Hex values
            let hexParts = row.map { String(format: "%02X", $0) }
            var hexStr = hexParts.joined(separator: " ")
            if row.count < rowSize {
                hexStr += String(repeating: "   ", count: rowSize - row.count)
            }

            // ASCII sidebar
            let asciiStr = row.map { byte -> Character in
                (0x20...0x7E).contains(byte) ? Character(UnicodeScalar(byte)) : "."
            }

            lines.append("\(offsetStr)  \(hexStr)  \(String(asciiStr))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Repaired Text Pane

    private var repairedTextPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Repaired Text")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                Text(repairedText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 300)
    }

    // MARK: - Loading

    private func loadFile() {
        do {
            rawBytes = try Data(contentsOf: fileURL)

            // Use Rust FFI for detection and repair
            let bytes = Array(rawBytes)
            corruptionType = bytes.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return "none" }
                let resultPtr = recovery_detect(baseAddress, UInt64(buffer.count))
                defer { recovery_free_string(resultPtr) }
                guard let resultPtr else { return "none" }
                return String(cString: resultPtr)
            }

            repairedText = bytes.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return "" }
                let resultPtr = recovery_repair(baseAddress, UInt64(buffer.count))
                defer { recovery_free_string(resultPtr) }
                guard let resultPtr else { return "" }
                return String(cString: resultPtr)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
