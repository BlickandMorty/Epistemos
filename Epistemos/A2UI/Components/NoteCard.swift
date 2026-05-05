import SwiftUI

struct A2UINoteCard: View {
    let props: A2UINoteCardProps

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(props.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(props.retractionStatus.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(statusColor.opacity(0.12))
                    )
            }
            Text(props.body)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !props.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(props.evidence) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium))
                            Text(item.excerpt)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch props.retractionStatus {
        case .active:
            .green
        case .atRisk:
            .yellow
        case .retracted:
            .red
        case .unknown:
            .secondary
        }
    }
}
