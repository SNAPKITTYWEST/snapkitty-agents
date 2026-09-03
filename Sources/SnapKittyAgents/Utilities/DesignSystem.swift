import SwiftUI

// Shared design tokens and button styles

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a,r,g,b) = (255, (int>>16)&0xFF, (int>>8)&0xFF, int&0xFF)
        case 8: (a,r,g,b) = ((int>>24)&0xFF, (int>>16)&0xFF, (int>>8)&0xFF, int&0xFF)
        default:(a,r,g,b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255,
                  opacity: Double(a)/255)
    }
}

struct SKButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? color.opacity(0.15) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.5)))
            .cornerRadius(3)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TabButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(isActive ? Color(hex: "#00ff88") : Color(hex: "#555"))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color(hex: "#00ff88").opacity(0.08) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isActive ? Color(hex: "#00ff88") : Color.clear)
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            )
    }
}
