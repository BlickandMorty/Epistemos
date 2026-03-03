import SwiftUI

// MARK: - BlockPropertySheet
// Simple form for editing block properties (@key=value pairs).
// Presented from the context menu "Set Property..." action.

struct BlockPropertySheet: View {
    @State private var entries: [PropertyEntry]
    @State private var newKey = ""
    @State private var newValue = ""

    let onSave: ([(String, PropertyValue)]) -> Void
    let onCancel: () -> Void

    init(
        existing: [(String, PropertyValue)],
        onSave: @escaping ([(String, PropertyValue)]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _entries = State(initialValue: existing.map {
            PropertyEntry(key: $0.0, valueText: Self.displayValue($0.1))
        })
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Block Properties")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            List {
                ForEach($entries) { $entry in
                    HStack(spacing: 8) {
                        TextField("key", text: $entry.key)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 120)
                        TextField("value", text: $entry.valueText)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack(spacing: 8) {
                    TextField("key", text: $newKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                    TextField("value", text: $newValue)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard !newKey.isEmpty else { return }
                        entries.append(PropertyEntry(
                            key: newKey,
                            valueText: newValue.isEmpty ? "true" : newValue
                        ))
                        newKey = ""
                        newValue = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.borderless)
                    .disabled(newKey.isEmpty)
                }
            }
            .listStyle(.plain)

            Divider()

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let result = entries
                        .filter { !$0.key.isEmpty }
                        .map { ($0.key, BlockPropertyParser.parseValue($0.valueText)) }
                    onSave(result)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 360, height: 300)
    }

    private static func displayValue(_ value: PropertyValue) -> String {
        switch value {
        case .string(let s): s
        case .float(let f): String(f)
        case .int(let i): String(i)
        case .bool(let b): b ? "true" : "false"
        }
    }
}

// MARK: - PropertyEntry

private struct PropertyEntry: Identifiable {
    let id = UUID()
    var key: String
    var valueText: String
}
