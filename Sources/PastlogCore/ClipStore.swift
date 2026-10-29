import Combine
import CryptoKit
import Foundation

@MainActor
public final class ClipStore: ObservableObject {
    @Published public private(set) var clips: [Clip] = []

    public let directory: URL
    public var maxItems: Int { didSet { trim() } }

    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private var blobsURL: URL { directory.appendingPathComponent("blobs", isDirectory: true) }
    private var pendingSave: DispatchWorkItem?
    private let fm = FileManager.default

    public init(directory: URL, maxItems: Int = 500) {
        self.directory = directory
        self.maxItems = maxItems
        try? fm.createDirectory(at: blobsURL, withIntermediateDirectories: true)
    }

    // MARK: Persistence

    public func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Clip].self, from: data) {
            clips = Self.sorted(decoded)
        }
    }

    public func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(clips) else { return }
        try? data.write(to: indexURL, options: [.atomic, .completeFileProtection])
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    public func data(for flavor: ClipFlavor, in clip: Clip) -> Data? {
        try? Data(contentsOf: blobsURL.appendingPathComponent(clip.id.uuidString).appendingPathComponent(flavor.blob))
    }

    /// Data for the first flavor whose type is in `types` (in preference order).
    public func firstData(of clip: Clip, preferring types: [String]) -> Data? {
        for type in types {
            for item in clip.items {
                if let flavor = item.flavors.first(where: { $0.type == type }) {
                    return data(for: flavor, in: clip)
                }
            }
        }
        return nil
    }

    // MARK: Mutations

    public static func fingerprint(of capture: Capture) -> String {
        var hasher = SHA256()
        if !capture.filePaths.isEmpty {
            hasher.update(data: Data(("files:" + capture.filePaths.joined(separator: "\n")).utf8))
        } else if let text = capture.plainText, !text.isEmpty {
            hasher.update(data: Data(("text:" + text).utf8))
        } else {
            for item in capture.items {
                for flavor in item.sorted(by: { $0.type < $1.type }) {
                    hasher.update(data: Data(flavor.type.utf8))
                    hasher.update(data: flavor.data)
                }
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    public func add(_ capture: Capture, now: Date = Date()) -> Clip? {
        guard capture.totalBytes > 0 || capture.plainText?.isEmpty == false else { return nil }
        let fingerprint = Self.fingerprint(of: capture)

        if let index = clips.firstIndex(where: { $0.fingerprint == fingerprint }) {
            clips[index].lastCopied = now
            clips[index].copyCount += 1
            if let name = capture.sourceAppName { clips[index].sourceAppName = name }
            if let bid = capture.sourceBundleID { clips[index].sourceBundleID = bid }
            let clip = clips[index]
            clips = Self.sorted(clips)
            scheduleSave()
            return clip
        }

        let types = capture.allTypes
        let kind = PasteboardTypes.classify(types: types, plainText: capture.plainText)
        let id = UUID()
        let clipDir = blobsURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fm.createDirectory(at: clipDir, withIntermediateDirectories: true)

        var items: [ClipItem] = []
        for (i, rawItem) in capture.items.enumerated() {
            var flavors: [ClipFlavor] = []
            for (j, raw) in rawItem.enumerated() {
                let name = "\(i)-\(j).bin"
                do {
                    try raw.data.write(to: clipDir.appendingPathComponent(name), options: .atomic)
                    flavors.append(ClipFlavor(type: raw.type, blob: name, size: raw.data.count))
                } catch { continue }
            }
            if !flavors.isEmpty { items.append(ClipItem(flavors: flavors)) }
        }

        let clip = Clip(
            id: id, kind: kind,
            title: PasteboardTypes.title(kind: kind, plainText: capture.plainText, filePaths: capture.filePaths,
                                         imageWidth: capture.imageWidth, imageHeight: capture.imageHeight, types: types),
            plainText: capture.plainText, filePaths: capture.filePaths, items: items,
            sourceAppName: capture.sourceAppName, sourceBundleID: capture.sourceBundleID,
            created: now, lastCopied: now, copyCount: 1, pasteCount: 0, lastPasted: nil, pinned: false,
            byteSize: capture.totalBytes, fingerprint: fingerprint,
            imageWidth: capture.imageWidth, imageHeight: capture.imageHeight)
        clips.insert(clip, at: 0)
        clips = Self.sorted(clips)
        trim()
        scheduleSave()
        return clip
    }

    public func markPasted(_ id: UUID, moveToTop: Bool, now: Date = Date()) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].pasteCount += 1
        clips[i].lastPasted = now
        if moveToTop { clips[i].lastCopied = now }
        clips = Self.sorted(clips)
        scheduleSave()
    }

    public func togglePin(_ id: UUID) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].pinned.toggle()
        clips = Self.sorted(clips)
        trim()
        scheduleSave()
    }

    public func delete(_ id: UUID) {
        clips.removeAll { $0.id == id }
        removeBlobs(id)
        scheduleSave()
    }

    public func clear(keepPinned: Bool) {
        let removed = clips.filter { !keepPinned || !$0.pinned }
        clips = keepPinned ? clips.filter(\.pinned) : []
        removed.forEach { removeBlobs($0.id) }
        saveNow()
    }

    /// Replaces a clip's content with edited plain text.
    public func updateText(_ id: UUID, text: String) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        let old = clips[i]
        removeBlobs(id)
        let dir = blobsURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = Data(text.utf8)
        try? data.write(to: dir.appendingPathComponent("0-0.bin"), options: .atomic)
        let kind = PasteboardTypes.classify(types: [PasteboardTypes.plainText], plainText: text)
        var clip = old
        clip.kind = kind
        clip.plainText = text
        clip.filePaths = []
        clip.imageWidth = nil
        clip.imageHeight = nil
        clip.items = [ClipItem(flavors: [ClipFlavor(type: PasteboardTypes.plainText, blob: "0-0.bin", size: data.count)])]
        clip.byteSize = data.count
        clip.title = PasteboardTypes.title(kind: kind, plainText: text, filePaths: [], imageWidth: nil, imageHeight: nil, types: [])
        clip.fingerprint = Self.fingerprint(of: Capture(items: [[RawFlavor(type: PasteboardTypes.plainText, data: data)]], plainText: text))
        clips[i] = clip
        scheduleSave()
    }

    // MARK: Queries

    public func search(_ query: String, filter: ClipFilter = .all) -> [Clip] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        return clips.filter { clip in
            guard filter.matches(clip) else { return false }
            guard !terms.isEmpty else { return true }
            let haystack = [clip.title, clip.plainText ?? "", clip.fileNames.joined(separator: " "),
                            clip.sourceAppName ?? "", clip.kind.label].joined(separator: "\n").lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    // MARK: Helpers

    private func trim() {
        let limit = max(1, maxItems)
        var unpinned = clips.filter { !$0.pinned }
        guard unpinned.count > limit else { return }
        unpinned.sort { $0.lastCopied > $1.lastCopied }
        let drop = Set(unpinned[limit...].map(\.id))
        clips.removeAll { drop.contains($0.id) }
        drop.forEach(removeBlobs)
        scheduleSave()
    }

    private func removeBlobs(_ id: UUID) {
        try? fm.removeItem(at: blobsURL.appendingPathComponent(id.uuidString, isDirectory: true))
    }

    static func sorted(_ clips: [Clip]) -> [Clip] {
        clips.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.lastCopied > b.lastCopied
        }
    }
}
