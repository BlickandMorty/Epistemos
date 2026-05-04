import SwiftUI

struct AdapterUnwrapView: View {
    let adapterName: String
    let applyDuration: Duration
    @State private var completed = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Adapter unwrap: \(adapterName)")
            ProgressView(value: completed ? 1.0 : 0.35)
            Text(completed ? "Applied" : "Applying; animation must not finish ahead of work")
                .font(.caption)
        }
        .task {
            try? await Task.sleep(for: applyDuration)
            completed = true
        }
    }
}
