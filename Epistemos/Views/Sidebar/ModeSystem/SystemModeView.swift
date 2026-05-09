import SwiftUI

struct SystemModeView: View {
    private let sections: [(title: String, systemImage: String)] = [
        ("System Prompts", "text.badge.star"),
        ("Chat Transcripts", "bubble.left.and.bubble.right"),
        ("Doc Chat Exports", "doc.text"),
        ("Agent Logs", "terminal"),
        ("Skill Outputs", "wand.and.stars"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("System")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(sections, id: \.title) { section in
                    DisclosureGroup {
                        Text("No items loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                            .padding(.vertical, 4)
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.callout.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
