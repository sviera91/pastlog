import Foundation

public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text, richText, link, image, file, color, other

    public var label: String {
        switch self {
        case .text: "Text"
        case .richText: "Rich Text"
        case .link: "Link"
        case .image: "Image"
        case .file: "File"
        case .color: "Color"
        case .other: "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        case .color: "paintpalette"
        case .other: "square.on.square"
        }
    }
}

/// One pasteboard representation (UTI + data) persisted as a blob on disk.
public struct ClipFlavor: Codable, Hashable, Sendable {
    public var type: String
    public var blob: String
    public var size: Int
}

/// One NSPasteboardItem worth of flavors (a multi-file copy has several items).
public struct ClipItem: Codable, Hashable, Sendable {
    public var flavors: [ClipFlavor]
}

public struct Clip: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: ClipKind
    public var title: String
    public var plainText: String?
    public var filePaths: [String]
    public var items: [ClipItem]
    public var sourceAppName: String?
    public var sourceBundleID: String?
    public var created: Date
    public var lastCopied: Date
    public var copyCount: Int
    public var pasteCount: Int
    public var lastPasted: Date?
    public var pinned: Bool
    public var byteSize: Int
    public var fingerprint: String
    public var imageWidth: Int?
    public var imageHeight: Int?

    public var fileNames: [String] { filePaths.map { ($0 as NSString).lastPathComponent } }
}

public struct RawFlavor: Sendable, Hashable {
    public var type: String
    public var data: Data
    public init(type: String, data: Data) { self.type = type; self.data = data }
}

/// Snapshot of the pasteboard taken by the monitor, before it is stored.
public struct Capture: Sendable {
    public var items: [[RawFlavor]]
    public var plainText: String?
    public var filePaths: [String]
    public var sourceAppName: String?
    public var sourceBundleID: String?
    public var imageWidth: Int?
    public var imageHeight: Int?

    public init(items: [[RawFlavor]], plainText: String? = nil, filePaths: [String] = [],
                sourceAppName: String? = nil, sourceBundleID: String? = nil,
                imageWidth: Int? = nil, imageHeight: Int? = nil) {
        self.items = items
        self.plainText = plainText
        self.filePaths = filePaths
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    public var allTypes: Set<String> { Set(items.flatMap { $0.map(\.type) }) }
    public var totalBytes: Int { items.reduce(0) { $0 + $1.reduce(0) { $0 + $1.data.count } } }
}

public enum ClipFilter: String, CaseIterable, Sendable {
    case all, pinned, text, links, images, files

    public var label: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .text: "Text"
        case .links: "Links"
        case .images: "Images"
        case .files: "Files"
        }
    }

    public func matches(_ clip: Clip) -> Bool {
        switch self {
        case .all: true
        case .pinned: clip.pinned
        case .text: clip.kind == .text || clip.kind == .richText
        case .links: clip.kind == .link
        case .images: clip.kind == .image
        case .files: clip.kind == .file
        }
    }
}
