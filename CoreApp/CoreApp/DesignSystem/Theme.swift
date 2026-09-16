import SwiftUI

/// Design tokens extracted from the Figma file "core." (fileKey Si72DJLpEzyusUqSZJzgbC),
/// from its brand/style-guide slide (hex values below match it exactly):
///   Asphalt #1E1E1E · Violet flower #5900FF · Orange #F92C00 · Mice #948C8C
enum Theme {
    static let background = Color(hex: 0x1E1E1E)
    static let purple = Color(hex: 0x5900FF)
    static let orange = Color(hex: 0xF92C00)
    static let muted = Color(hex: 0x948C8C)

    /// Translucent card fill used for list rows / chips over the dark background.
    static let cardFill = Color(hex: 0x3C3838).opacity(0.2)
    /// Slightly darker translucent fill used for larger panels (search bar, membership rows).
    static let panelFill = Color(hex: 0x1E1E1E).opacity(0.35)
    static let hairline = Color.white.opacity(0.15)
    static let placeholder = Color(hex: 0xD9D9D9)

    static let pillRadius: CGFloat = 45
    static let cardRadius: CGFloat = 30

    enum Metrics {
        static let screenPadding: CGFloat = 17
    }

    /// The Figma file specifies the custom display face "Francy" for body/headings and
    /// "Doto" (a dot-matrix variable face) for big stat numbers. Neither ships with iOS,
    /// so this falls back to the closest system faces; drop the real .ttf/.otf files into
    /// the Xcode project and register them in Info.plist to restore exact typography.
    enum Typeface {
        static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static func stat(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black, design: .monospaced)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
