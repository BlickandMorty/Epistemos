import SwiftUI

// Preview to test Platinum light and dark modes side by side
struct PlatinumPreview: View {
    var body: some View {
        HStack(spacing: 20) {
            // Light mode
            VStack {
                Text("Platinum Light")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: 0xDEDEDE))
                    .frame(width: 150, height: 100)
                    .overlay(
                        Text("Background")
                            .foregroundColor(.black)
                    )
                
                Circle()
                    .fill(Color(hex: 0x000080))
                    .frame(width: 40, height: 40)
                    .overlay(Text("Accent").font(.caption).foregroundColor(.white))
            }
            
            // Dark mode
            VStack {
                Text("Platinum Dark")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: 0x1E1E24))
                    .frame(width: 150, height: 100)
                    .overlay(
                        Text("Background")
                            .foregroundColor(Color(hex: 0xE8E8F0))
                    )
                
                Circle()
                    .fill(Color(hex: 0x7B68EE))
                    .frame(width: 40, height: 40)
                    .overlay(Text("Accent").font(.caption).foregroundColor(.white))
            }
        }
        .padding()
    }
}

#Preview("Platinum Colors") {
    PlatinumPreview()
}
