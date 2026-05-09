import SwiftUI

struct ModelVaultsModeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Model Vaults")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            ModelVaultsSidebarSection(presentation: .standalone)
                .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
    }
}
