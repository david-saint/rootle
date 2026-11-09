import SwiftUI
#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

extension PlatformColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(rgb: UInt32) { self.init(PlatformColor(rgb: rgb)) }

    /// A colour that resolves differently in light and dark appearance.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
        #else
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(rgb: dark) : NSColor(rgb: light)
        })
        #endif
    }
}

/// Rootle's palette: juicy, sunlit colours. Coral for action, leaf green for success,
/// sunflower for rewards, lagoon for discovery — and a rainbow of sediment layers to dig through.
enum Palette {
    static let paper     = Color.dynamic(0xFFFCF6, 0x101412)
    static let card      = Color.dynamic(0xFFFFFF, 0x1A201D)
    static let sunk      = Color.dynamic(0xF5F1EA, 0x151A17)
    static let sidebar   = Color.dynamic(0xFFF7EA, 0x0C100E)
    static let ink       = Color.dynamic(0x1E1B18, 0xF6F3EC)
    static let inkSoft   = Color.dynamic(0x6B655F, 0xA2ADA7)
    static let line      = Color.dynamic(0xEAE4DA, 0x2A332F)

    static let ember      = Color.dynamic(0xFF5A36, 0xFF7152)
    static let emberShade = Color.dynamic(0xD63C1B, 0xC9472D)
    static let moss       = Color.dynamic(0x22B35A, 0x3FD178)
    static let mossShade  = Color.dynamic(0x178A43, 0x249C52)
    static let ochre      = Color.dynamic(0xFFBE1A, 0xFFC93D)
    static let ochreShade = Color.dynamic(0xE09400, 0xD69A0A)
    static let teal       = Color.dynamic(0x0FA3BC, 0x2CC4DB)
    static let tealShade  = Color.dynamic(0x0A7D91, 0x1A92A6)
    static let pink       = Color.dynamic(0xFF4F8B, 0xFF6FA3)
    static let blush      = Color(rgb: 0xFF9BB3)

    /// The bold word-of-the-day panel.
    static let hero       = Color.dynamic(0x0B7F92, 0x0A6E7F)
    static let heroShade  = Color.dynamic(0x075F6E, 0x054955)
    static let heroGold   = Color(rgb: 0xFFD84D)

    static let correctWash = Color.dynamic(0xDDF7E6, 0x123222)
    static let wrongWash   = Color.dynamic(0xFFE4DC, 0x3A1A16)
    static let tealWash    = Color.dynamic(0xDBF4F8, 0x0F2F37)

    /// A sediment layer on the dig site: its ground colour, a deeper tone for tunnels
    /// and locked stops, and a vivid accent for its title and current lesson.
    struct Layer {
        let fill: Color
        let deep: Color
        let accent: Color
        let accentShade: Color
    }

    private static func layer(_ f: (UInt32, UInt32), _ d: (UInt32, UInt32), _ a: (UInt32, UInt32), _ s: (UInt32, UInt32)) -> Layer {
        Layer(fill: .dynamic(f.0, f.1), deep: .dynamic(d.0, d.1), accent: .dynamic(a.0, a.1), accentShade: .dynamic(s.0, s.1))
    }

    /// Light mode is a rainbow of pastel sediments; dark mode is a run of jewel tones.
    static let layers: [Layer] = [
        layer((0xFFE3D8, 0x3B1522), (0xF7B19A, 0x6E2A3E), (0xFF5A36, 0xFF7152), (0xD63C1B, 0xC9472D)), // coral
        layer((0xD5F2F6, 0x0C2C33), (0x93D8E2, 0x1B5662), (0x0FA3BC, 0x2CC4DB), (0x0A7D91, 0x1A92A6)), // lagoon
        layer((0xFFF0BD, 0x2A173E), (0xF4CE63, 0x502D72), (0xF5A300, 0xFFC93D), (0xC98300, 0xD69A0A)), // sunflower
        layer((0xFFDFEB, 0x0E2E24), (0xF6A6C3, 0x1D5646), (0xFF4F8B, 0xFF6FA3), (0xD62E6B, 0xD24A7E)), // pink
        layer((0xE2F5CF, 0x341426), (0xADDC80, 0x612848), (0x3AAE36, 0x5AD157), (0x288A25, 0x3A9E37)), // lime
        layer((0xFFE6C9, 0x0D2A36), (0xF8BE7E, 0x1B4C60), (0xFF8A1F, 0xFF9E45), (0xD06800, 0xD27A22)), // apricot
        layer((0xD2F2EB, 0x37121D), (0x8CD9C9, 0x65243C), (0x0EA88E, 0x2FD1B5), (0x0A8170, 0x1E9E88)), // jade
        layer((0xFAE0F6, 0x11301C), (0xE8A8DC, 0x24593A), (0xC93DB0, 0xE46BD0), (0x9E2A8A, 0xB04CA0)), // orchid
        layer((0xFFDEDA, 0x2B1640), (0xF7A59D, 0x543078), (0xF04438, 0xFF6A5E), (0xC42A20, 0xC9473D)), // poppy
        layer((0xD8F5E4, 0x0D2E2A), (0x92DDB4, 0x1C5B53), (0x16B06A, 0x3BD68C), (0x0F8A50, 0x25A06A)), // mint
    ]
    static func layer(_ i: Int) -> Layer { layers[((i % layers.count) + layers.count) % layers.count] }

    /// A neutral tone for placeholders and empty states.
    static let stratumShade = Color.dynamic(0xD8D1C6, 0x3A443F)
    static let bedrock = Color.dynamic(0xEDE8E0, 0x0A0D0C)

    /// A colour for each source language, used for chips, timeline dots and lexicon cards.
    static func language(_ name: String) -> Color {
        let n = name.lowercased()
        switch true {
        case n.contains("greek"):       return .dynamic(0x0E97B0, 0x35C6DD)
        case n.contains("latin"):       return .dynamic(0xF0472A, 0xFF7152)
        case n.contains("norse"):       return .dynamic(0x3D7FA6, 0x6FB4DB)
        case n.contains("french"),
             n.contains("anglo"):       return .dynamic(0xE83E80, 0xFF6FA3)
        case n.contains("arabic"):      return .dynamic(0xE09400, 0xFFC93D)
        case n.contains("persian"):     return .dynamic(0xC2410C, 0xFF8A4C)
        case n.contains("sanskrit"),
             n.contains("hindi"):       return .dynamic(0xF07A00, 0xFFA040)
        case n.contains("nahuatl"):     return .dynamic(0x0E9E80, 0x2FD1B5)
        case n.contains("dutch"):       return .dynamic(0xFF6B1A, 0xFF9455)
        case n.contains("japanese"),
             n.contains("chinese"),
             n.contains("hokkien"):     return .dynamic(0xD92D3A, 0xFF5E68)
        case n.contains("malay"),
             n.contains("tagalog"):     return .dynamic(0x5A9E1A, 0x8FD14F)
        case n.contains("czech"),
             n.contains("slavonic"),
             n.contains("russian"):     return .dynamic(0xA23CC9, 0xD07BF0)
        case n.contains("germanic"),
             n.contains("old english"),
             n.contains("middle english"): return .dynamic(0x1FA855, 0x3FD178)
        case n.contains("scots"),
             n.contains("gaelic"),
             n.contains("irish"),
             n.contains("welsh"):       return .dynamic(0x3F9142, 0x7BCB6C)
        case n.contains("italian"),
             n.contains("spanish"),
             n.contains("portuguese"):  return .dynamic(0xE0533A, 0xFF8466)
        case n.contains("german"):      return .dynamic(0x6B7F12, 0xB5CC4A)
        default:                        return .dynamic(0xB4621E, 0xE89A5A)
        }
    }
}

extension Font {
    /// New York — for words, headlines and anything "bookish".
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// SF Rounded — for interface chrome and game UI.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Small-caps style overline label.
struct Overline: View {
    let text: String
    var color: Color = Palette.inkSoft
    init(_ text: String, color: Color = Palette.inkSoft) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.ui(11.5, .heavy))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

struct LanguageDot: View {
    let language: String
    var size: CGFloat = 9
    var body: some View {
        Circle().fill(Palette.language(language)).frame(width: size, height: size)
    }
}

