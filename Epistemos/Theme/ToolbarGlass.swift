import AppKit
import SwiftUI

// MARK: - Themed Glass Toolbar using NSTitlebarAccessoryViewController
// This is the proper API for adding views to the titlebar area.

struct GlassToolbarConfiguration {
    let theme: EpistemosTheme
    let tintOpacity: CGFloat
    
    init(theme: EpistemosTheme, tintOpacity: CGFloat = 0.30) {
        self.theme = theme
        self.tintOpacity = tintOpacity
    }
    
    var tintColor: NSColor {
        NSColor(theme.background).withAlphaComponent(tintOpacity)
    }
}

// MARK: - NSWindow Extension

@MainActor
extension NSWindow {
    
    func applyThemedGlassToolbar(configuration: GlassToolbarConfiguration, height: CGFloat = 52) {
        // Configure window
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        
        if !self.styleMask.contains(.fullSizeContentView) {
            self.styleMask.insert(.fullSizeContentView)
        }
        
        // Setup toolbar
        if self.toolbar == nil {
            self.toolbar = NSToolbar(identifier: "NoteEditor")
        }
        self.toolbarStyle = .unified
        
        // Use NSTitlebarAccessoryViewController for proper titlebar integration
        let accessoryVC = GlassToolbarAccessoryViewController()
        accessoryVC.configuration = configuration
        accessoryVC.layoutAttribute = .top
        
        // Remove existing accessory view controllers with same identifier
        for i in stride(from: self.titlebarAccessoryViewControllers.count - 1, through: 0, by: -1) {
            if self.titlebarAccessoryViewControllers[i].identifier?.rawValue == "GlassToolbar" {
                self.removeTitlebarAccessoryViewController(at: i)
            }
        }

        accessoryVC.identifier = NSUserInterfaceItemIdentifier("GlassToolbar")
        self.addTitlebarAccessoryViewController(accessoryVC)
        
        self.appearance = NSAppearance(named: configuration.theme.isDark ? .darkAqua : .aqua)
    }
    
    func updateGlassToolbarTheme(_ theme: EpistemosTheme) {
        guard let accessoryVC = self.titlebarAccessoryViewControllers
            .first(where: { $0.identifier?.rawValue == "GlassToolbar" }) as? GlassToolbarAccessoryViewController else {
            return
        }
        accessoryVC.configuration = GlassToolbarConfiguration(theme: theme)
        self.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
    }

    func removeGlassToolbarTheme() {
        for index in stride(from: titlebarAccessoryViewControllers.count - 1, through: 0, by: -1) {
            if titlebarAccessoryViewControllers[index].identifier?.rawValue == "GlassToolbar" {
                removeTitlebarAccessoryViewController(at: index)
            }
        }
    }
}

// MARK: - Titlebar Accessory View Controller

class GlassToolbarAccessoryViewController: NSTitlebarAccessoryViewController {
    var configuration: GlassToolbarConfiguration? {
        didSet {
            updateView()
        }
    }
    
    private var effectView: NSVisualEffectView?
    private var tintView: NSView?
    
    override func loadView() {
        // Create a container view
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 52))
        self.view = container
        
        // Add visual effect view for blur
        let blur = NSVisualEffectView()
        blur.material = .titlebar
        blur.blendingMode = .withinWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(blur)
        effectView = blur
        
        // Add tint view
        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.5).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tint)
        tintView = tint
        
        // Constrain to fill
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            tint.topAnchor.constraint(equalTo: container.topAnchor),
            tint.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    private func updateView() {
        guard let config = configuration else { return }
        tintView?.layer?.backgroundColor = config.tintColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.fullScreenMinHeight = 52
    }
}
