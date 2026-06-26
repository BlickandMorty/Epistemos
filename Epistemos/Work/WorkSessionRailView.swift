import SwiftUI

// Mini-session ontology — increment 4: the native SESSION RAIL (authority plan §"Mini Session Model For Work").
// A compact list of the active MAIN session + its MINI children, with focus / new-mini / detach / reattach /
// promote / close actions, bound to the verified `WorkSessionStore`. This is the NATIVE session chrome for
// Epistemos Work: the native transcript renders in `WorkEngineSurfaceView`, while this view owns identity/routing.
// The surface populates MAIN recents from live OpenGUI `sessions.list`; MINI lineage remains Epistemos-owned.
//
// Look-bearing → visual proof OWED (owner runs ⌘4 once wired into `WorkWebSurfaceView`, or Xcode #Preview below).
struct WorkSessionRailView: View {
    let store: WorkSessionStore
    var theme: EpistemosTheme = .nativeDefault
    /// The caller creates the actual WorkSession + engine session for a new mini under `parent`. OPTIONAL: the
    /// "+ New mini" affordance only appears when a caller actually wires this — no no-op control.
    var onNewMini: ((WorkSession) -> Void)? = nil
    /// The caller opens/closes a real floating mini window. Hidden when nil so Work never exposes no-op detach chrome.
    var onDetach: ((WorkSession) -> Void)?
    var onReattach: ((WorkSession) -> Void)?

    private var accent: Color { theme.resolved.accent.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(store.mainSessions) { main in
                mainRow(main)
                ForEach(store.children(of: main.id)) { mini in
                    miniRow(mini)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mainRow(_ session: WorkSession) -> some View {
        row(title: session.title ?? "Work", symbol: "square.split.2x1",
            isActive: store.activeSessionID == session.id, indent: 0)
            .onTapGesture { store.focus(id: session.id) }
            .overlay(alignment: .trailing) {
                if let onNewMini {
                    Button { onNewMini(session) } label: {
                        Image(systemName: "plus.circle").font(.system(size: 11))
                    }
                        .buttonStyle(.plain)
                        .frame(width: 18, height: 18)
                        .help("New mini session")
                        .padding(.trailing, 8)
                }
            }
    }

    private func miniRow(_ session: WorkSession) -> some View {
        row(title: session.title ?? "Mini",
            symbol: session.presentation == .detached ? "rectangle.on.rectangle" : "bubble.left",
            isActive: store.activeSessionID == session.id, indent: 1)
            .onTapGesture { store.focus(id: session.id) }
            .contextMenu {
                if session.presentation == .attached, let onDetach {
                    Button("Detach") {
                        store.setPresentation(id: session.id, .detached)
                        onDetach(session.presented(as: .detached))
                    }
                } else if session.presentation == .detached, let onReattach {
                    Button("Reattach") {
                        store.setPresentation(id: session.id, .attached)
                        onReattach(session.presented(as: .attached))
                    }
                }
                Button("Promote to tab") { store.promote(id: session.id) }
                Button("Close", role: .destructive) { store.remove(id: session.id) }
            }
    }

    private func row(title: String, symbol: String, isActive: Bool, indent: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? accent : theme.mutedForeground)
                .frame(width: 14, height: 14)
            Text(title)
                .font(WorkPixelFont.body(12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .padding(.leading, indent * 16)
        .background(isActive ? accent.opacity(0.15) : Color.clear)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
    }
}

#Preview {
    let store = WorkSessionStore()
    let main = WorkSession.main(id: "m1", workspaceID: "ws", title: "Main Work")
    store.upsert(main)
    store.upsert(WorkSession.mini(id: "c1", parent: main, title: "Refactor"))
    store.upsert(WorkSession.mini(id: "c2", parent: main, presentation: .detached, title: "Tests"))
    return WorkSessionRailView(store: store).frame(width: 240, height: 220)
}
