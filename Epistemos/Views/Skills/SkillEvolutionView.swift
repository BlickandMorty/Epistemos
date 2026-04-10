import SwiftUI
import OSLog

// MARK: - Skill Evolution View

/// View for analyzing skill traces and approving/rejecting GEPA-proposed mutations.
struct SkillEvolutionView: View {
    @State private var service = SkillEvolutionService()
    @State private var selectedVault: VaultIdentity = .model("claude-opus-4")
    @State private var selectedSkill: String = ""
    @State private var showingDiff = false
    @State private var selectedProposal: SkillMutationProposal?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar: Skills list
            skillsList
        } detail: {
            // Detail: Selected skill analysis or proposals
            detailContent
        }
        .navigationTitle("Skill Evolution")
    }
    
    // MARK: - Sidebar
    
    private var skillsList: some View {
        List {
            Section("Pending Proposals") {
                if service.pendingProposals.isEmpty {
                    Label("No pending proposals", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.pendingProposals) { proposal in
                        Button {
                            selectedProposal = proposal
                            showingDiff = true
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading) {
                                    Text(proposal.skillName)
                                        .font(.headline)
                                    Text("v\(proposal.oldVersion) → v\(proposal.newVersion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            
            Section("Analysis") {
                Button {
                    Task {
                        await service.analyzeAllSkills(in: selectedVault)
                    }
                } label: {
                    Label("Analyze All Skills", systemImage: "magnifyingglass")
                }
                .disabled(service.isAnalyzing)
                
                if service.isAnalyzing {
                    ProgressView(service.progressMessage)
                        .progressViewStyle(.linear)
                }
            }
            
            Section("History") {
                if !service.approvedMutations.isEmpty {
                    Label("\(service.approvedMutations.count) approved", systemImage: "checkmark")
                        .foregroundStyle(.green)
                }
                if !service.rejectedMutations.isEmpty {
                    Label("\(service.rejectedMutations.count) rejected", systemImage: "xmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 250)
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        if let proposal = selectedProposal {
            proposalDetail(proposal)
        } else {
            emptyState
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Skill Evolution", systemImage: "arrow.up.forward")
        } description: {
            Text("Select a skill from the sidebar to view analysis and evolution proposals.")
        } actions: {
            Button("Auto-Propose Mutations") {
                Task {
                    let count = await service.autoProposeMutations(in: selectedVault)
                    Logger.evolution.info("Auto-proposed \(count) mutations")
                }
            }
            .disabled(service.isAnalyzing)
        }
    }
    
    private func proposalDetail(_ proposal: SkillMutationProposal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(proposal.skillName)
                            .font(.title)
                        Text("Version \(proposal.oldVersion) → \(proposal.newVersion)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    constraintBadges(for: proposal.constraintCheck)
                }
                
                Divider()
                
                // Rationale
                VStack(alignment: .leading, spacing: 8) {
                    Label("Rationale", systemImage: "lightbulb")
                        .font(.headline)
                    Text(proposal.rationale)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Diff view
                VStack(alignment: .leading, spacing: 8) {
                    Label("Changes", systemImage: "doc.text")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(proposal.diff)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Reject") {
                        Task {
                            service.rejectMutation(proposal)
                            selectedProposal = nil
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Spacer()
                    
                    Button("Approve & Apply") {
                        Task {
                            try? await service.approveMutation(proposal, in: selectedVault)
                            selectedProposal = nil
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!proposal.constraintCheck.allPassed)
                }
            }
            .padding()
        }
    }
    
    private func constraintBadges(for check: ConstraintCheck) -> some View {
        HStack(spacing: 8) {
            if check.sizeOk {
                Label("Size", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("Size", systemImage: "xmark")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if check.semanticPreserved {
                Label("Semantic", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("Semantic", systemImage: "xmark")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(6)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Logger Extension

extension Logger {
    fileprivate static let evolution = Logger(subsystem: "com.epistemos", category: "SkillEvolution")
}

// MARK: - Preview

#Preview {
    SkillEvolutionView()
}
