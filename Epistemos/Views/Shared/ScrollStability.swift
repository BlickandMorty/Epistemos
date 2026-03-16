import SwiftUI

struct ScrollAutoFollowState: Sendable, Equatable {
    private(set) var isFollowingBottom: Bool
    let attachThreshold: CGFloat
    let detachThreshold: CGFloat

    init(
        isFollowingBottom: Bool = true,
        attachThreshold: CGFloat = 32,
        detachThreshold: CGFloat = 96
    ) {
        self.isFollowingBottom = isFollowingBottom
        self.attachThreshold = min(attachThreshold, detachThreshold)
        self.detachThreshold = max(detachThreshold, attachThreshold)
    }

    mutating func update(distanceToBottom: CGFloat) {
        if distanceToBottom <= attachThreshold {
            isFollowingBottom = true
        } else if distanceToBottom >= detachThreshold {
            isFollowingBottom = false
        }
    }

    mutating func markProgrammaticScrollToBottom() {
        isFollowingBottom = true
    }
}

enum ScrollStability {
    static func distanceToBottom(for geometry: ScrollGeometry) -> CGFloat {
        let contentBottom = geometry.contentSize.height + geometry.contentInsets.bottom
        return max(contentBottom - geometry.visibleRect.maxY, 0)
    }

    static func updatedAutoFollowState(
        from state: ScrollAutoFollowState,
        distanceToBottom: CGFloat
    ) -> ScrollAutoFollowState {
        var next = state
        next.update(distanceToBottom: distanceToBottom)
        return next
    }
}

enum ChatScrollFollowPolicy {
    static let defaultAutoFollowState = ScrollAutoFollowState(
        attachThreshold: 24,
        detachThreshold: 72
    )

    static let streamingThrottle: Duration = .milliseconds(250)
}
