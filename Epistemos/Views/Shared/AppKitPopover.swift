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
                
                // Allow it to overhang the window
                popover.animates = true
                
                let hostingController = NSHostingController(rootView: content())
                hostingController.sizingOptions = .intrinsicContentSize
                popover.contentViewController = hostingController

                // Clamp popover size to fit within the window to prevent overflow
                if let window = nsView.window {
                    let maxWidth = min(window.frame.width - 40, 600)
                    let maxHeight = min(window.frame.height - 80, 500)
                    let intrinsic = hostingController.view.fittingSize
                    popover.contentSize = NSSize(
                        width: min(intrinsic.width, maxWidth),
                        height: min(intrinsic.height, maxHeight)
                    )
                }
                
                context.coordinator.popover = popover
                
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
            } else {
                (context.coordinator.popover?.contentViewController as? NSHostingController<PopoverContent>)?.rootView = content()
            }
        } else {
            context.coordinator.popover?.performClose(nil)
            context.coordinator.popover = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, NSPopoverDelegate {
        var parent: AppKitPopoverAnchor
        var popover: NSPopover?
        
        init(parent: AppKitPopoverAnchor) {
            self.parent = parent
        }
        
        func popoverDidClose(_ notification: Notification) {
            // Dismiss binding when clicking outside
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
            popover = nil
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
