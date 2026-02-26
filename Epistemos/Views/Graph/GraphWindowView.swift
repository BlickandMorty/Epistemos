import SwiftUI

struct GraphWindowView: View {
    var body: some View {
        MetalGraphView()
            .frame(minWidth: 600, minHeight: 400)
    }
}
