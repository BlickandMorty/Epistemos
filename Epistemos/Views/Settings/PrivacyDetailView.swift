import SwiftUI

struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy")
                    .font(.title2.weight(.semibold))

                Text("This shared page covers the local note application. Feature-specific privacy disclosures live with the feature that owns them.")
                    .foregroundStyle(.secondary)

                PrivacyCard(
                    title: "Stored locally",
                    items: [
                        "Notes, vault contents, attachments, preferences, embeddings, and search indexes.",
                        "Optional Kokoro read-aloud assets installed in the app container."
                    ]
                )

                PrivacyCard(
                    title: "Network and tracking",
                    items: [
                        "Epistemos does not send note content to an Epistemos service.",
                        "The app does not include advertising, analytics, or tracking identifiers."
                    ]
                )

                PrivacyCard(
                    title: "App Sandbox",
                    items: [
                        "File access is limited to files and folders you select.",
                        "Access to a selected vault is stored through a security-scoped bookmark."
                    ]
                )
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
    }
}

private struct PrivacyCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
