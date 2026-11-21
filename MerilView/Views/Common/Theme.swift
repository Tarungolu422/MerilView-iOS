import SwiftUI

/// MerilView medical dark theme design system.
public struct MerilTheme {
    public static let background = Color(hex: "#0B0F17")
    public static let surface = Color(hex: "#131B2A")
    public static let surfaceHover = Color(hex: "#1E293B")
    public static let border = Color(hex: "#1F293D")
    public static let borderActive = Color(hex: "#38BDF8")
    
    // Accents
    public static let accent = Color(hex: "#00E5FF")
    public static let primary = Color(hex: "#38BDF8")
    public static let success = Color(hex: "#10B981")
    public static let warning = Color(hex: "#F59E0B")
    public static let danger = Color(hex: "#EF4444")
    
    // Typography
    public static let textPrimary = Color(hex: "#F8FAFC")
    public static let textSecondary = Color(hex: "#94A3B8")
    public static let textMuted = Color(hex: "#64748B")
    
    // Modality Colors
    public static func modalityColor(_ modality: String) -> Color {
        let m = modality.uppercased()
        if m.contains("CT") { return Color(hex: "#38BDF8") } // Cyan/Blue
        if m.contains("MR") { return Color(hex: "#A78BFA") } // Purple
        if m.contains("CR") || m.contains("DX") { return Color(hex: "#34D399") } // Green
        if m.contains("US") { return Color(hex: "#FBBF24") } // Amber
        return Color(hex: "#94A3B8") // Gray
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
