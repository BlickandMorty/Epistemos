import SwiftUI

/// Coding preferences — opt-in features for agentic coding workflows.
struct CodingPreferencesView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coding Preferences")
                    .font(AgentSkin.pixel(15))
                Text("Opt-in features for autonomous coding workflows.")
                    .font(AgentSkin.mono(11))
                    .foregroundStyle(.secondary)
            }
            .padding()

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Verify").font(AgentSkin.pixel(12))
                    Text("After build succeeds, launch app and test via accessibility")
                        .font(AgentSkin.mono(10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.autoVerifyEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Visual Tests").font(AgentSkin.pixel(12))
                    Text("LLM can define click/verify UI assertions")
                        .font(AgentSkin.mono(10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.visualTestsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto PR").font(AgentSkin.pixel(12))
                    Text("Create branch, commit, push, open GitHub PR")
                        .font(AgentSkin.mono(10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.autoPREnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Templates").font(AgentSkin.pixel(12))
                    Text("Scaffold new Xcode projects from prompts")
                        .font(AgentSkin.mono(10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.autoScaffoldEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
        }
        .padding(.bottom, 15)
        .frame(width: 320)
    }

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack { content() }
                .padding(.vertical, 8)
                .padding(.horizontal)
        }
    }
}
