import SwiftUI

// MARK: - Platinum Theme (Mac OS 9 Style)
// A beautiful classic Mac OS 9 Platinum aesthetic with light and dark variants

enum PlatinumTheme {
    struct Palette {
        let background: Color
        let surface: Color
        let windowFrame: Color
        let highlight: Color
        let shadowLight: Color
        let shadowDark: Color
        let border: Color
        let text: Color
        let textMuted: Color
        let accent: Color
        let selection: Color
    }

    // MARK: - Light Mode Colors (Classic Platinum)
    enum Light {
        static let background = Color(hex: 0xDEDEDE)
        static let surface = Color(hex: 0xDDDDDD)
        static let windowFrame = Color(hex: 0xCECECE)
        static let highlight = Color.white
        static let shadowLight = Color(hex: 0x9C9C9C)
        static let shadowDark = Color(hex: 0x555555)
        static let border = Color.black
        static let text = Color.black
        static let textMuted = Color(hex: 0x555555)
        static let accent = Color(hex: 0x000080)  // Classic Mac blue
        static let selection = Color(hex: 0x000080)
    }
    
    // MARK: - Dark Mode Colors (Midnight Platinum)
    enum Dark {
        static let background = Color(hex: 0x1E1E24)  // Deep blue-gray
        static let surface = Color(hex: 0x252530)      // Slightly lighter
        static let windowFrame = Color(hex: 0x2A2A38)
        static let highlight = Color(hex: 0x3A3A48)    // Soft highlight
        static let shadowLight = Color(hex: 0x151520)
        static let shadowDark = Color(hex: 0x0A0A10)
        static let border = Color(hex: 0x404050)
        static let text = Color(hex: 0xE8E8F0)         // Soft white
        static let textMuted = Color(hex: 0x9090A0)
        static let accent = Color(hex: 0x7B68EE)       // Beautiful medium slate blue
        static let selection = Color(hex: 0x6B5DD6)    // Slightly darker accent
    }
    
    // MARK: - Typography
    enum Font {
        static func system(size: CGFloat) -> SwiftUI.Font {
            return .system(size: size, weight: .medium, design: .default)
        }
        
        static let title = system(size: 13)
        static let body = system(size: 12)
        static let small = system(size: 10)
    }
    
    // MARK: - Dimensions
    enum Metrics {
        static let borderWidth: CGFloat = 1
        static let bevelWidth: CGFloat = 2
        static let cornerRadius: CGFloat = 0  // Sharp corners for retro feel
        static let titleBarHeight: CGFloat = 20
        static let buttonHeight: CGFloat = 20
        static let padding: CGFloat = 8
    }

    static func palette(isDark: Bool) -> Palette {
        if isDark {
            return Palette(
                background: Dark.background,
                surface: Dark.surface,
                windowFrame: Dark.windowFrame,
                highlight: Dark.highlight,
                shadowLight: Dark.shadowLight,
                shadowDark: Dark.shadowDark,
                border: Dark.border,
                text: Dark.text,
                textMuted: Dark.textMuted,
                accent: Dark.accent,
                selection: Dark.selection
            )
        }

        return Palette(
            background: Light.background,
            surface: Light.surface,
            windowFrame: Light.windowFrame,
            highlight: Light.highlight,
            shadowLight: Light.shadowLight,
            shadowDark: Light.shadowDark,
            border: Light.border,
            text: Light.text,
            textMuted: Light.textMuted,
            accent: Light.accent,
            selection: Light.selection
        )
    }
}

// MARK: - Bevel Effects

struct PlatinumBevel: View {
    let isPressed: Bool
    let isDark: Bool
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let colors = PlatinumTheme.palette(isDark: isDark)
            
            ZStack {
                // Outer border
                Rectangle()
                    .stroke(isDark ? colors.border : Color.black, lineWidth: 1)
                
                if !isPressed {
                    // Raised effect - highlight on top-left
                    Path { p in
                        p.move(to: CGPoint(x: 1, y: h - 1))
                        p.addLine(to: CGPoint(x: 1, y: 1))
                        p.addLine(to: CGPoint(x: w - 1, y: 1))
                    }
                    .stroke(colors.highlight, lineWidth: 1)
                    
                    // Shadow on bottom-right
                    Path { p in
                        p.move(to: CGPoint(x: w - 1, y: 1))
                        p.addLine(to: CGPoint(x: w - 1, y: h - 1))
                        p.addLine(to: CGPoint(x: 1, y: h - 1))
                    }
                    .stroke(colors.shadowLight, lineWidth: 1)
                } else {
                    // Pressed effect - inverted
                    Path { p in
                        p.move(to: CGPoint(x: 1, y: h - 1))
                        p.addLine(to: CGPoint(x: 1, y: 1))
                        p.addLine(to: CGPoint(x: w - 1, y: 1))
                    }
                    .stroke(colors.shadowLight, lineWidth: 1)
                    
                    Path { p in
                        p.move(to: CGPoint(x: w - 1, y: 1))
                        p.addLine(to: CGPoint(x: w - 1, y: h - 1))
                        p.addLine(to: CGPoint(x: 1, y: h - 1))
                    }
                    .stroke(colors.highlight, lineWidth: 1)
                }
            }
        }
    }
}

struct PlatinumInset: View {
    let isDark: Bool
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let colors = PlatinumTheme.palette(isDark: isDark)
            
            ZStack {
                // Outer border
                Rectangle()
                    .stroke(isDark ? colors.border : Color.black, lineWidth: 1)
                
                // Inset shadow on top-left
                Path { p in
                    p.move(to: CGPoint(x: 1, y: h - 1))
                    p.addLine(to: CGPoint(x: 1, y: 1))
                    p.addLine(to: CGPoint(x: w - 1, y: 1))
                }
                .stroke(colors.shadowLight, lineWidth: 1)
                
                // Highlight on bottom-right
                Path { p in
                    p.move(to: CGPoint(x: w - 1, y: 1))
                    p.addLine(to: CGPoint(x: w - 1, y: h - 1))
                    p.addLine(to: CGPoint(x: 1, y: h - 1))
                }
                .stroke(colors.highlight, lineWidth: 1)
            }
        }
    }
}

// MARK: - Platinum Button Style

struct PlatinumButtonStyle: ButtonStyle {
    let isDefault: Bool
    let isDark: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let colors = PlatinumTheme.palette(isDark: isDark)
        
        configuration.label
            .font(PlatinumTheme.Font.body)
            .foregroundColor(configuration.isPressed ? colors.highlight : colors.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    configuration.isPressed ? colors.shadowLight : colors.surface
                    PlatinumBevel(isPressed: configuration.isPressed, isDark: isDark)
                    
                    // Default button indicator
                    if isDefault && !configuration.isPressed {
                        Rectangle()
                            .stroke(colors.text.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .padding(3)
                    }
                }
            )
    }
}

// MARK: - Platinum Window

struct PlatinumWindow<Content: View>: View {
    let title: String
    let isActive: Bool
    let isDark: Bool
    let content: Content
    
    init(
        title: String,
        isActive: Bool = true,
        isDark: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isActive = isActive
        self.isDark = isDark
        self.content = content()
    }
    
    var body: some View {
        let colors = PlatinumTheme.palette(isDark: isDark)
        
        VStack(spacing: 0) {
            // Title bar
            PlatinumTitleBar(title: title, isActive: isActive, isDark: isDark)
            
            // Content
            ZStack {
                colors.background
                PlatinumInset(isDark: isDark)
                
                content
                    .padding(2)
            }
        }
        .overlay(
            Rectangle()
                .stroke(colors.border, lineWidth: 1)
        )
    }
}

struct PlatinumTitleBar: View {
    let title: String
    let isActive: Bool
    let isDark: Bool
    
    var body: some View {
        let colors = PlatinumTheme.palette(isDark: isDark)
        
        HStack(spacing: 4) {
            // Close box
            PlatinumCloseBox(isDark: isDark)
            
            Spacer()
            
            // Title
            Text(title)
                .font(PlatinumTheme.Font.title)
                .foregroundColor(colors.text)
            
            Spacer()
            
            // Balance
            Color.clear
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background {
            if isActive {
                PlatinumStripes(isDark: isDark)
            }
        }
        .background(colors.windowFrame)
    }
}

struct PlatinumStripes: View {
    let isDark: Bool
    
    var body: some View {
        Canvas { context, size in
            let stripeHeight: CGFloat = 2
            let numStripes = Int(size.height / stripeHeight)
            let stripeColor = isDark ? Color(hex: 0x505060) : Color(hex: 0x737373)
            
            for i in 0..<numStripes {
                let y = CGFloat(i) * stripeHeight
                
                // White/bright stripe
                let brightRect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(brightRect), with: .color(isDark ? Color(hex: 0x404050) : Color.white))
                
                // Dark stripe
                let darkRect = CGRect(x: 0, y: y + 1, width: size.width, height: 1)
                context.fill(Path(darkRect), with: .color(stripeColor))
            }
        }
    }
}

struct PlatinumCloseBox: View {
    let isDark: Bool
    
    var body: some View {
        let colors = PlatinumTheme.palette(isDark: isDark)
        
        ZStack {
            Rectangle()
                .fill(colors.surface)
            
            PlatinumBevel(isPressed: false, isDark: isDark)
            
            // X mark
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(colors.text)
        }
        .frame(width: 12, height: 12)
    }
}

// MARK: - View Extensions

extension View {
    func platinumWindow(title: String, isActive: Bool = true, isDark: Bool = false) -> some View {
        PlatinumWindow(title: title, isActive: isActive, isDark: isDark) {
            self
        }
    }
}

// MARK: - Preview

#Preview("Platinum Light") {
    VStack(spacing: 20) {
        PlatinumWindow(title: "Untitled", isActive: true, isDark: false) {
            VStack(spacing: 12) {
                Text("Hello, Platinum!")
                    .font(PlatinumTheme.Font.body)
                
                Button("OK") {}
                    .buttonStyle(PlatinumButtonStyle(isDefault: true, isDark: false))
                
                Button("Cancel") {}
                    .buttonStyle(PlatinumButtonStyle(isDefault: false, isDark: false))
            }
            .padding()
            .frame(width: 200, height: 120)
        }
        .frame(width: 220)
    }
    .padding()
    .background(Color.gray)
}

#Preview("Platinum Dark") {
    VStack(spacing: 20) {
        PlatinumWindow(title: "Untitled", isActive: true, isDark: true) {
            VStack(spacing: 12) {
                Text("Hello, Platinum Dark!")
                    .font(PlatinumTheme.Font.body)
                
                Button("OK") {}
                    .buttonStyle(PlatinumButtonStyle(isDefault: true, isDark: true))
                
                Button("Cancel") {}
                    .buttonStyle(PlatinumButtonStyle(isDefault: false, isDark: true))
            }
            .padding()
            .frame(width: 200, height: 120)
        }
        .frame(width: 220)
    }
    .padding()
    .background(Color.black)
}
