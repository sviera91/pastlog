import AppKit
import ImageIO
import PastlogCore
import SwiftUI

@MainActor
protocol PanelActions: AnyObject {
    func paste(_ clip: Clip, plain: Bool)
    func copyOnly(_ clip: Clip)
    func togglePin(_ clip: Clip)
    func delete(_ clip: Clip)
    func beginEdit(_ clip: Clip)
    func saveEdit()
    func cancelEdit()
    func open(_ clip: Clip)
    func reveal(_ clip: Clip)
    func openPreferences()
}

@MainActor
final class PanelModel: ObservableObject {
    @Published var query = "" { didSet { if query != oldValue { selection = 0 } } }
    @Published var filter: ClipFilter = .all { didSet { selection = 0 } }
    @Published var selection = 0
    @Published var hoveredID: UUID?
    @Published var editingID: UUID?
    @Published var editText = ""
    @Published var focusToken = 0

    let store: ClipStore

    init(store: ClipStore) { self.store = store }

    var results: [Clip] { store.search(query, filter: filter) }

    var selectedClip: Clip? {
        let results = results
        return results.indices.contains(selection) ? results[selection] : nil
    }

    func reset() {
        query = ""
        filter = .all
        selection = 0
        hoveredID = nil
        editingID = nil
        editText = ""
    }

    func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = min(max(0, selection + delta), count - 1)
        hoveredID = nil
    }

    func cycleFilter(backwards: Bool) {
        let all = ClipFilter.allCases
        let i = all.firstIndex(of: filter) ?? 0
        filter = all[(i + (backwards ? all.count - 1 : 1)) % all.count]
    }
}

@MainActor
enum Thumbnails {
    private static let cache = NSCache<NSString, NSImage>()
    private static let imageTypes = ["public.png", "public.jpeg", "public.tiff", "public.heic", "com.compuserve.gif",
                                     "org.webmproject.webp", "com.adobe.pdf"]

    static func image(for clip: Clip, store: ClipStore) -> NSImage? {
        let key = clip.id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        var result: NSImage?
        switch clip.kind {
        case .image:
            if let data = store.firstData(of: clip, preferring: imageTypes),
               let source = CGImageSourceCreateWithData(data as CFData, nil) {
                result = thumbnail(source)
            }
        case .file:
            if let path = clip.filePaths.first, FileManager.default.fileExists(atPath: path) {
                if let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                   CGImageSourceGetCount(source) > 0, let thumb = thumbnail(source) {
                    result = thumb
                } else {
                    result = NSWorkspace.shared.icon(forFile: path)
                }
            }
        default:
            break
        }
        if let result { cache.setObject(result, forKey: key) }
        return result
    }

    private static func thumbnail(_ source: CGImageSource) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 160,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    static func appIcon(bundleID: String?) -> NSImage? {
        guard let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

enum ClipFormat {
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func ago(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 10 { return "just now" }
        return relative.localizedString(for: date, relativeTo: Date())
    }

    static func details(_ clip: Clip) -> String {
        var parts: [String] = []
        parts.append(clip.sourceAppName ?? "Unknown app")
        parts.append(clip.kind.label)
        parts.append("copied \(ago(clip.lastCopied))")
        if clip.copyCount > 1 { parts.append("copied \(clip.copyCount)×") }
        parts.append(clip.pasteCount == 1 ? "pasted once" : "pasted \(clip.pasteCount)×")
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(clip.byteSize), countStyle: .file))
        return parts.joined(separator: " · ")
    }
}
