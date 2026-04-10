import SwiftUI

// MARK: - Conflict Card View

/// Surfaces contradictions between new and existing vault facts.
/// Shows old fact vs new fact with conflict type and resolution actions.
struct ConflictCardView: View {
    let contradiction: VaultContradiction
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Contradiction Detected")
                    .font(.headline)
                Spacer()
                Text(contradiction.conflictType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Existing fact
            VStack(alignment: .leading, spacing: 4) {
                Text("Existing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(contradiction.existingContent)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(contradiction.existingFilePath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Incoming fact
            VStack(alignment: .leading, spacing: 4) {
                Text("Incoming")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(contradiction.incomingFact)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Confidence
            HStack {
                Text("Confidence: \(Int(contradiction.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Resolution buttons
            HStack(spacing: 12) {
                Button("Keep Existing") {
                    onResolve(.keepExisting)
                }
                .buttonStyle(.bordered)

                Button("Accept New") {
                    onResolve(.acceptNew)
                }
                .buttonStyle(.borderedProminent)

                Button("Keep Both") {
                    onResolve(.keepBoth)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Types

enum ConflictResolution {
    case keepExisting
    case acceptNew
    case keepBoth
}

struct VaultContradiction: Identifiable {
    let id = UUID()
    let incomingFact: String
    let existingFilePath: String
    let existingSection: String
    let existingContent: String
    let conflictType: VaultConflictType
    let confidence: Double

    init(from ffi: ContradictionFFI) {
        self.incomingFact = ffi.incomingFact
        self.existingFilePath = ffi.existingFilePath
        self.existingSection = ffi.existingSection
        self.existingContent = ffi.existingContent
        self.conflictType = VaultConflictType(rawValue: ffi.conflictType) ?? .numeric
        self.confidence = ffi.confidence
    }
}

enum VaultConflictType: String {
    case numeric
    case boolean
    case antonym
    case semanticReversal = "semantic_reversal"

    var displayName: String {
        switch self {
        case .numeric: return "Numeric"
        case .boolean: return "Boolean"
        case .antonym: return "Antonym"
        case .semanticReversal: return "Semantic"
        }
    }
}
