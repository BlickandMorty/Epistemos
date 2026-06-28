import SwiftUI

struct CommandPaletteCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Command Palette") {
                CommandRegistrations.registerEpdocCommands()
                CommandRegistry.shared.showCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}
