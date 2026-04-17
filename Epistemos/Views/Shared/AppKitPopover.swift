import SwiftUI
import AppKit

struct AppKitPopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    var location: CGPoint?
    @ViewBuilder let popoverContent: () -> PopoverContent
    
    func body(content: Content) -> some View {
        content
            .background(
                AppKitPopoverAnchor(
                    isPresented: $isPresented,
                    location: location,
                    content: popoverContent
                )
            )
    }
}

struct AppKitPopoverAnchor<PopoverContent: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    var location: CGPoint?
    let content: () -> PopoverContent
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            if context.coordinator.popover == nil {
                let popover = NSPopover()
                popover.behavior = .transient
                popover.delegate = context.coordinator
                popover.animates = true

                let hostingController = NSHostingController(rootView: content())
                hostingController.sizingOptions = .intrinsicContentSize
                popover.contentViewController = hostingController

                Self.syncContentSize(
                    popover: popover,
                    hostingController: hostingController,
                    window: nsView.window
                )

                context.coordinator.popover = popover
                context.coordinator.hostingController = hostingController

                // Convert SwiftUI location (top-down) to NSView bounds (bottom-up usually, though SwiftUI hosts flip it sometimes. NSHostingView is flipped!)
                // SwiftUI taps are top-down. NSView bounds from SwiftUI are usually flipped if it's an NSHostingView.
                let y = nsView.isFlipped ? (location?.y ?? nsView.bounds.midY) : (nsView.bounds.height - (location?.y ?? nsView.bounds.midY))
                let rect = NSRect(
                    x: location?.x ?? nsView.bounds.midX,
                    y: y,
                    width: 1,
                    height: 1
                )

                popover.show(relativeTo: rect, of: nsView, preferredEdge: .minY)
            } else if let popover = context.coordinator.popover,
                      let hostingController = context.coordinator.hostingController as? NSHostingController<PopoverContent> {
                hostingController.rootView = content()
                // Re-measure on every update so the popover grows (or shrinks)
                // with the composer content instead of staying stuck at the
                // initial size. Matches the original dynamic-resizing landing
                // popover behavior the user called out as missing.
                Self.syncContentSize(
                    popover: popover,
                    hostingController: hostingController,
                    window: nsView.window
                )
            }
        } else {
            context.coordinator.popover?.performClose(nil)
            context.coordinator.popover = nil
            context.coordinator.hostingController = nil
        }
    }

    private static func syncContentSize(
        popover: NSPopover,
        hostingController: NSHostingController<PopoverContent>,
        window: NSWindow?
    ) {
        hostingController.view.layoutSubtreeIfNeeded()
        let intrinsic = hostingController.sizeThatFits(in: NSSize(
            width: 640,
            height: CGFloat.greatestFiniteMagnitude
        ))
        let maxWidth: CGFloat
        let maxHeight: CGFloat
        if let window {
            maxWidth = max(320, min(window.frame.width - 40, 640))
            maxHeight = max(240, min(window.frame.height - 80, 720))
        } else {
            maxWidth = 640
            maxHeight = 720
        }
        let newSize = NSSize(
            width: min(max(intrinsic.width, 360), maxWidth),
            height: min(max(intrinsic.height, 160), maxHeight)
        )
        if popover.contentSize != newSize {
            popover.contentSize = newSize
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, NSPopoverDelegate {
        var parent: AppKitPopoverAnchor
        var popover: NSPopover?
        var hostingController: AnyObject?

        init(parent: AppKitPopoverAnchor) {
            self.parent = parent
        }
        
        func popoverDidClose(_ notification: Notification) {
            // Dismiss binding when clicking outside
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
            popover = nil
            hostingController = nil
        }
    }
}

extension View {
    func appKitPopover<Content: View>(
        isPresented: Binding<Bool>,
        location: CGPoint? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(AppKitPopoverModifier(isPresented: isPresented, location: location, popoverContent: content))
    }
}
