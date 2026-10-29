import SwiftUI

struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool
    let background: Color
    let surface: Color
    let row: Color
    let selection: Color
    let text: Color
    let muted: Color
    let accent: Color
    let accent2: Color
    let border: Color
    var retro = false

    var titleFont: Font { retro ? .custom("VT323", size: 24) : .system(size: 13, weight: .semibold) }
    var bodyFont: Font { retro ? .custom("Space Mono", size: 12) : .system(size: 13) }
    var captionFont: Font { retro ? .custom("Space Mono", size: 10) : .system(size: 11) }
    var monoFont: Font { retro ? .custom("Space Mono", size: 10) : .system(size: 10, design: .monospaced) }
    var cornerRadius: CGFloat { retro ? 8 : 12 }
    var rowRadius: CGFloat { retro ? 4 : 8 }
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    static func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255, opacity: alpha)
    }

    /// Mirrors the palette, fonts, and terminal look of sviera91.github.io.
    static let cityPop = Theme(
        id: "citypop", name: "City Pop · sviera91", isDark: true,
        background: hex(0x0A0A1A), surface: hex(0x12122A), row: hex(0x1A1A35), selection: hex(0x00E5FF, 0.14),
        text: hex(0xE8E8FF), muted: hex(0x8888BB), accent: hex(0x00E5FF), accent2: hex(0xFF6EC7),
        border: hex(0x00E5FF, 0.15), retro: true)

    static let all: [Theme] = [
        cityPop,
        Theme(id: "dark", name: "Dark", isDark: true, background: hex(0x1C1C1E), surface: hex(0x2C2C2E), row: hex(0x262628),
              selection: hex(0x0A84FF, 0.85), text: hex(0xF2F2F7), muted: hex(0x98989F), accent: hex(0x0A84FF),
              accent2: hex(0xFF9F0A), border: hex(0xFFFFFF, 0.08)),
        Theme(id: "light", name: "Light", isDark: false, background: hex(0xF7F7F8), surface: hex(0xFFFFFF), row: hex(0xFFFFFF),
              selection: hex(0x007AFF, 0.85), text: hex(0x1C1C1E), muted: hex(0x6E6E73), accent: hex(0x007AFF),
              accent2: hex(0xFF9500), border: hex(0x000000, 0.08)),
        Theme(id: "lavender", name: "Lavender", isDark: false, background: hex(0xF3EFFA), surface: hex(0xFBF9FE), row: hex(0xFFFFFF),
              selection: hex(0x8E6CC9, 0.85), text: hex(0x2E2440), muted: hex(0x7D7091), accent: hex(0x8E6CC9),
              accent2: hex(0xD9779C), border: hex(0x8E6CC9, 0.18)),
        Theme(id: "graphite", name: "Graphite", isDark: true, background: hex(0x2B2D31), surface: hex(0x35373C), row: hex(0x313338),
              selection: hex(0x8A8D93, 0.55), text: hex(0xE6E6E6), muted: hex(0x9A9DA3), accent: hex(0xC8CBD0),
              accent2: hex(0xF0B232), border: hex(0xFFFFFF, 0.07)),
        Theme(id: "ocean", name: "Ocean", isDark: true, background: hex(0x0B2239), surface: hex(0x10304D), row: hex(0x0E2A44),
              selection: hex(0x3FB6D8, 0.45), text: hex(0xE3F4FB), muted: hex(0x86A9C0), accent: hex(0x3FB6D8),
              accent2: hex(0x7FE0C5), border: hex(0x3FB6D8, 0.18)),
        Theme(id: "mint", name: "Mint", isDark: true, background: hex(0x0F2A22), surface: hex(0x15382E), row: hex(0x123128),
              selection: hex(0x4FD1A5, 0.4), text: hex(0xE4F7EF), muted: hex(0x8DB8A8), accent: hex(0x4FD1A5),
              accent2: hex(0xF4D35E), border: hex(0x4FD1A5, 0.16)),
        Theme(id: "sunset", name: "Sunset", isDark: true, background: hex(0x2A1520), surface: hex(0x3A1D2B), row: hex(0x331926),
              selection: hex(0xFF8A5C, 0.45), text: hex(0xFFEDE5), muted: hex(0xC79A9F), accent: hex(0xFF8A5C),
              accent2: hex(0xFFC857), border: hex(0xFF8A5C, 0.18)),
        Theme(id: "rose", name: "Rose", isDark: false, background: hex(0xFDF0F3), surface: hex(0xFFF8FA), row: hex(0xFFFFFF),
              selection: hex(0xD6457A, 0.8), text: hex(0x3A1F2A), muted: hex(0x9A6B7C), accent: hex(0xD6457A),
              accent2: hex(0x8E6CC9), border: hex(0xD6457A, 0.15)),
        Theme(id: "sepia", name: "Sepia", isDark: false, background: hex(0xF4ECD8), surface: hex(0xFAF4E6), row: hex(0xFFFBF0),
              selection: hex(0x8B5E34, 0.75), text: hex(0x3B2A1A), muted: hex(0x8A7458), accent: hex(0x8B5E34),
              accent2: hex(0xB5523B), border: hex(0x8B5E34, 0.18)),
        Theme(id: "nord", name: "Nord", isDark: true, background: hex(0x2E3440), surface: hex(0x3B4252), row: hex(0x353C4A),
              selection: hex(0x88C0D0, 0.4), text: hex(0xECEFF4), muted: hex(0x9AA5B8), accent: hex(0x88C0D0),
              accent2: hex(0xEBCB8B), border: hex(0xFFFFFF, 0.07)),
    ]

    static let systemID = "system"

    static func resolve(_ id: String, scheme: ColorScheme) -> Theme {
        if id == systemID { return all.first { $0.id == (scheme == .dark ? "dark" : "light") }! }
        return all.first { $0.id == id } ?? cityPop
    }

    /// Text color on a selected row (solid selections need white text).
    var selectedText: Color { retro ? text : (id == "graphite" || id == "ocean" || id == "mint" || id == "sunset" || id == "nord" ? text : .white) }
}

/// Faint CRT scanlines like the site's `.scanlines` layer.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 2
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)), with: .color(.black.opacity(0.12)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}
