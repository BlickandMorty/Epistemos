import Foundation

extension AgentViewModel {
    private static let epistemosLastHostProjectFolderKey = "epistemos.agentclone.lastAppliedHostProjectFolder"

    func applyEpistemosHostContext(_ context: AgentCloneHostContext) {
        epistemosHostContextSummary = context.summary
        SessionStore.shared.applyEpistemosHostContext(context)

        guard let preferredFolder = context.preferredProjectFolder else { return }
        let resolvedFolder = Self.resolvedWorkingDirectory((preferredFolder as NSString).expandingTildeInPath)
        guard !resolvedFolder.isEmpty else { return }

        let defaults = UserDefaults.standard
        let lastHostFolder = defaults.string(forKey: Self.epistemosLastHostProjectFolderKey) ?? ""
        let currentFolder = projectFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeFolder = FileManager.default.homeDirectoryForCurrentUser.path

        let canAdoptHostFolder = currentFolder.isEmpty
            || currentFolder == resolvedFolder
            || currentFolder == lastHostFolder
            || currentFolder == homeFolder

        guard canAdoptHostFolder else { return }

        projectFolder = resolvedFolder
        defaults.set(resolvedFolder, forKey: Self.epistemosLastHostProjectFolderKey)
        RecentFoldersService.shared.addFolder(resolvedFolder)
    }
}
