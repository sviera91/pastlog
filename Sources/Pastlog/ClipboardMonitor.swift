import AppKit
import PastlogCore

@MainActor
final class ClipboardMonitor {
    private let store: ClipStore
    private var timer: Timer?
    private(set) var lastChangeCount = NSPasteboard.general.changeCount

    init(store: ClipStore) { self.store = store }

    func start() {
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Call after Pastlog writes to the pasteboard so its own writes are not re-recorded.
    func ignoreCurrentChange() { lastChangeCount = NSPasteboard.general.changeCount }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard !Settings.paused else { return }
        if let capture = Self.capture(from: pasteboard) { store.add(capture) }
    }

    static func capture(from pasteboard: NSPasteboard) -> Capture? {
        guard let pbItems = pasteboard.pasteboardItems, !pbItems.isEmpty else { return nil }
        let allTypes = Set(pbItems.flatMap { $0.types.map(\.rawValue) })
        if Settings.skipSensitive && PasteboardTypes.isSensitive(types: allTypes) { return nil }

        let front = NSWorkspace.shared.frontmostApplication
        var bundleID = front?.bundleIdentifier
        var appName = front?.localizedName
        if let declared = pasteboard.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.source")),
           !declared.isEmpty {
            bundleID = declared
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: declared) {
                appName = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            }
        }
        let excluded = Set(Settings.excludedApps)
        if let bundleID, excluded.contains(bundleID) { return nil }
        if let frontID = front?.bundleIdentifier, excluded.contains(frontID) { return nil }

        var items: [[RawFlavor]] = pbItems.map { item in
            item.types.compactMap { type in item.data(forType: type).map { RawFlavor(type: type.rawValue, data: $0) } }
        }

        let cap = Settings.maxClipBytes
        if items.reduce(0, { $0 + $1.reduce(0) { $0 + $1.data.count } }) > cap {
            items = items.map { $0.filter { PasteboardTypes.essential.contains($0.type) } }
            if items.reduce(0, { $0 + $1.reduce(0) { $0 + $1.data.count } }) > cap {
                // Keep only one representation per item (prefer the smallest) before giving up.
                items = items.compactMap { flavors in flavors.min { $0.data.count < $1.data.count }.map { [$0] } }
                if items.reduce(0, { $0 + $1.reduce(0) { $0 + $1.data.count } }) > cap { return nil }
            }
        }
        items.removeAll { $0.isEmpty }
        guard !items.isEmpty else { return nil }

        let fileURLs = (pasteboard.readObjects(forClasses: [NSURL.self],
                                               options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        var plain = pasteboard.string(forType: .string)
        if !fileURLs.isEmpty { plain = fileURLs.map(\.path).joined(separator: "\n") }

        var width: Int?
        var height: Int?
        if fileURLs.isEmpty, !allTypes.isDisjoint(with: PasteboardTypes.imageTypes),
           let image = NSImage(pasteboard: pasteboard) {
            let rep = image.representations.first
            width = rep?.pixelsWide ?? Int(image.size.width)
            height = rep?.pixelsHigh ?? Int(image.size.height)
            if width == 0 { width = Int(image.size.width); height = Int(image.size.height) }
        }

        return Capture(items: items, plainText: plain, filePaths: fileURLs.map(\.path),
                       sourceAppName: appName, sourceBundleID: bundleID, imageWidth: width, imageHeight: height)
    }
}
