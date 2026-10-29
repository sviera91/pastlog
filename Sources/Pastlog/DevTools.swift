import AppKit
import PastlogCore
import SwiftUI

/// Developer modes used by scripts/build.sh: render the app icon and theme snapshots without the UI running.
@MainActor
enum DevTools {
    final class NoopActions: PanelActions {
        func paste(_ clip: Clip, plain: Bool) {}
        func copyOnly(_ clip: Clip) {}
        func togglePin(_ clip: Clip) {}
        func delete(_ clip: Clip) {}
        func beginEdit(_ clip: Clip) {}
        func saveEdit() {}
        func cancelEdit() {}
        func open(_ clip: Clip) {}
        func reveal(_ clip: Clip) {}
        func openPreferences() {}
    }

    static func renderIcon(to path: String, art: String? = nil) {
        let size: CGFloat = 1024
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 100, dy: 100)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
        if let art, let artwork = NSImage(contentsOfFile: art) {
            // Fit full-bleed artwork into the standard macOS icon grid (824 pt rounded square with margin).
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 24
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.set()
            NSColor.black.setFill()
            shape.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            NSGraphicsContext.current?.saveGraphicsState()
            shape.addClip()
            artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.current?.restoreGraphicsState()
            NSColor(srgbRed: 0, green: 0.9, blue: 1, alpha: 0.35).setStroke()
            shape.lineWidth = 4
            shape.stroke()
            image.unlockFocus()
            write(image, to: path)
            return
        }
        NSGradient(colors: [NSColor(srgbRed: 0.04, green: 0.04, blue: 0.10, alpha: 1),
                            NSColor(srgbRed: 0.10, green: 0.10, blue: 0.21, alpha: 1)])!.draw(in: shape, angle: -90)
        NSGraphicsContext.current?.saveGraphicsState()
        shape.addClip()
        NSColor.black.withAlphaComponent(0.18).setFill()
        var y = rect.minY
        while y < rect.maxY { NSRect(x: rect.minX, y: y, width: rect.width, height: 6).fill(); y += 14 }
        NSGradient(colors: [NSColor(srgbRed: 1, green: 0.43, blue: 0.78, alpha: 0.35), .clear])!
            .draw(in: NSBezierPath(ovalIn: NSRect(x: rect.maxX - 420, y: rect.maxY - 420, width: 640, height: 640)), relativeCenterPosition: .zero)
        NSGraphicsContext.current?.restoreGraphicsState()
        NSColor(srgbRed: 0, green: 0.9, blue: 1, alpha: 0.45).setStroke()
        shape.lineWidth = 8
        shape.stroke()

        let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .regular)
            .applying(.init(paletteColors: [NSColor(srgbRed: 0, green: 0.9, blue: 1, alpha: 1),
                                            NSColor(srgbRed: 1, green: 0.43, blue: 0.78, alpha: 1)]))
        if let symbol = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let s = symbol.size
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(srgbRed: 0, green: 0.9, blue: 1, alpha: 0.8)
            shadow.shadowBlurRadius = 40
            shadow.set()
            symbol.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2 - 10, width: s.width, height: s.height))
        }
        image.unlockFocus()
        write(image, to: path)
    }

    static func renderSnapshots(to directory: String, fonts: String?) {
        FontLoader.registerBundledFonts(extraDirectory: fonts.map { URL(fileURLWithPath: $0) })
        Settings.register()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pastlog-snapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ClipStore(directory: dir)
        let now = Date()
        func text(_ s: String, app: String, bid: String, ago: Double, types: [String] = []) {
            var flavors = [RawFlavor(type: PasteboardTypes.plainText, data: Data(s.utf8))]
            flavors += types.map { RawFlavor(type: $0, data: Data("x".utf8)) }
            store.add(Capture(items: [flavors], plainText: s, sourceAppName: app, sourceBundleID: bid), now: now.addingTimeInterval(-ago))
        }
        text("git commit -m \"feat: menu-bar clipboard history\"", app: "Terminal", bid: "com.apple.Terminal", ago: 40000)
        text("Quarterly planning notes — Q4 goals", app: "Microsoft Word", bid: "com.microsoft.Word", ago: 9000, types: ["public.rtf"])
        text("https://example.com", app: "Safari", bid: "com.apple.Safari", ago: 5400)
        if let png = NSImage(systemSymbolName: "photo.artframe", accessibilityDescription: nil)?.tiffRepresentation {
            store.add(Capture(items: [[RawFlavor(type: "public.tiff", data: png)]], sourceAppName: "Screenshot",
                              sourceBundleID: "com.apple.screenshot.launcher", imageWidth: 2560, imageHeight: 1440),
                      now: now.addingTimeInterval(-1800))
        }
        store.add(Capture(items: [[RawFlavor(type: PasteboardTypes.fileURL, data: Data("file:///Applications/Calculator.app".utf8))]],
                          plainText: "/Applications/Calculator.app", filePaths: ["/Applications/Calculator.app"],
                          sourceAppName: "Finder", sourceBundleID: "com.apple.finder"), now: now.addingTimeInterval(-600))
        text("Thanks for the recap — following up on the timeline.", app: "Slack", bid: "com.tinyspeck.slackmacgap", ago: 120)
        text("user@mac ~ $ whoami", app: "Notes", bid: "com.apple.Notes", ago: 20)
        if let pinned = store.clips.first(where: { $0.kind == .link }) { store.togglePin(pinned.id) }
        store.markPasted(store.clips[1].id, moveToTop: false)

        let model = PanelModel(store: store)
        let actions = NoopActions()
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for theme in Theme.all {
            UserDefaults.standard.set(theme.id, forKey: Settings.themeKey)
            let host = NSHostingView(rootView: PanelView(store: store, model: model, actions: actions))
            host.frame = NSRect(x: 0, y: 0, width: 460, height: 600)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("panel-\(theme.id).png"))
            }
        }
        UserDefaults.standard.removeObject(forKey: Settings.themeKey)
    }

    private static func write(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
