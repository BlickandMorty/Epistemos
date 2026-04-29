//
//  EntityVaultsView.swift
//  Simulation Mode S6 — per-entity Vaults disclosure with the
//  inline `⊕ New vault…` create sheet.
//
//  Per DOCTRINE §3.4.4 v1.6: every Model / Agent / Sub-agent
//  gets a `Vaults` sub-disclosure listing its primary vault +
//  siblings + a New-vault affordance. Clicking a vault swaps
//  the displayed tree for THIS entity to that vault's contents
//  (re-rooting; the actual file-tree rendering of vault contents
//  is deferred to a later slice — S6 ships the vault list +
//  create flow).
//

import SwiftUI

public struct EntityVaultsView: View {
    let entity: CompanionFarmEntry
    let bridge: CompanionRegistryBridge

    @State private var vaults: [Vault] = []
    @State private var isCreating: Bool = false
    @State private var newVaultName: String = ""
    @State private var createError: String?
    @State private var selectedVaultId: String?

    public init(entity: CompanionFarmEntry, bridge: CompanionRegistryBridge) {
        self.entity = entity
        self.bridge = bridge
    }

    public var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vaults) { vault in
                    vaultRow(vault)
                }
                createRow
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("Vaults")
                    .font(KnowledgeBrickStyle.modelRowFont)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vaults.count)")
                    .font(KnowledgeBrickStyle.modelRowFont)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: KnowledgeBrickStyle.treeRowHeight)
        }
        .padding(.leading, KnowledgeBrickStyle.indentStep)
        .task { refresh() }
    }

    // MARK: - Vault row

    private func vaultRow(_ vault: Vault) -> some View {
        let isSelected = selectedVaultId == vault.id
        return HStack(spacing: 6) {
            Image(systemName: vault.isPrimary ? "house.fill" : "folder")
                .font(.system(size: 10))
                .foregroundStyle(vault.isPrimary ? .primary : .secondary)
            Text(vault.label)
                .font(KnowledgeBrickStyle.noteTitleFont)
                .foregroundStyle(.primary)
                .italic(vault.isPrimary)
            Spacer()
        }
        .frame(height: KnowledgeBrickStyle.treeRowHeight)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedVaultId = vault.id }
        .padding(.leading, KnowledgeBrickStyle.indentStep)
    }

    // MARK: - Create-vault row + sheet

    private var createRow: some View {
        Group {
            if isCreating {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                    TextField("New vault name", text: $newVaultName)
                        .textFieldStyle(.plain)
                        .font(KnowledgeBrickStyle.noteTitleFont)
                        .onSubmit { confirmCreate() }
                    Button("Cancel") { cancelCreate() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Create") { confirmCreate() }
                        .buttonStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .disabled(
                            newVaultName.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                }
                .frame(height: KnowledgeBrickStyle.treeRowHeight)
                .padding(.horizontal, 8)
                .padding(.leading, KnowledgeBrickStyle.indentStep)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("New vault…")
                        .font(KnowledgeBrickStyle.noteTitleFont)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: KnowledgeBrickStyle.treeRowHeight)
                .padding(.horizontal, 8)
                .padding(.leading, KnowledgeBrickStyle.indentStep)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(KnowledgeBrickStyle.disclosureAnimation) {
                        isCreating = true
                    }
                }
            }
            if let err = createError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.leading, KnowledgeBrickStyle.indentStep)
            }
        }
    }

    // MARK: - Actions

    private func cancelCreate() {
        withAnimation(KnowledgeBrickStyle.disclosureAnimation) {
            isCreating = false
            newVaultName = ""
            createError = nil
        }
    }

    private func confirmCreate() {
        let trimmed = newVaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            createError = "name required"
            return
        }
        do {
            _ = try bridge.createVault(for: entity.id, name: trimmed)
            withAnimation(KnowledgeBrickStyle.disclosureAnimation) {
                isCreating = false
                newVaultName = ""
                createError = nil
            }
            refresh()
        } catch {
            createError = error.localizedDescription
        }
    }

    private func refresh() {
        vaults = bridge.listVaults(for: entity.id)
    }
}
