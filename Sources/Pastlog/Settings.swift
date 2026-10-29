import AppKit
import Carbon.HIToolbox
import ServiceManagement

extension Notification.Name {
    static let pastlogShortcutsChanged = Notification.Name("PastlogShortcutsChanged")
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let openDefault = Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | cmdKey), display: "⌃⌘V")
    static let quickDefault = Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | optionKey), display: "⌃⌥V")

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.subtracting(.shift).isEmpty else { return nil }
        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }
        keyCode = UInt32(event.keyCode)
        carbonModifiers = carbon
        display = symbols + Shortcut.keyName(event)
    }

    private static func keyName(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1...kVK_F20: return "F\(event.keyCode)"
        default: return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}

enum PopupPosition: String, CaseIterable {
    case cursor, center, menuBar
    var label: String {
        switch self {
        case .cursor: "Next to cursor"
        case .center: "Center of screen"
        case .menuBar: "Under menu bar icon"
        }
    }
}

enum Settings {
    static let maxItemsKey = "maxItems"
    static let maxClipMBKey = "maxClipMB"
    static let autoPasteKey = "autoPaste"
    static let plainByDefaultKey = "plainByDefault"
    static let moveToTopKey = "moveToTop"
    static let skipSensitiveKey = "skipSensitive"
    static let excludedAppsKey = "excludedApps"
    static let pausedKey = "paused"
    static let showInDockKey = "showInDock"
    static let themeKey = "theme"
    static let popupPositionKey = "popupPosition"
    static let openShortcutKey = "openShortcut"
    static let quickShortcutKey = "quickShortcut"
    static let didOnboardKey = "didOnboard"

    static var d: UserDefaults { .standard }

    static func register() {
        d.register(defaults: [
            maxItemsKey: 1000,
            maxClipMBKey: 50,
            autoPasteKey: true,
            plainByDefaultKey: false,
            moveToTopKey: true,
            skipSensitiveKey: true,
            excludedAppsKey: [String](),
            pausedKey: false,
            showInDockKey: false,
            themeKey: "citypop",
            popupPositionKey: PopupPosition.cursor.rawValue,
        ])
    }

    static var maxItems: Int { min(9999, max(10, d.integer(forKey: maxItemsKey))) }
    static var maxClipBytes: Int { max(1, d.integer(forKey: maxClipMBKey)) * 1_048_576 }
    static var autoPaste: Bool { d.bool(forKey: autoPasteKey) }
    static var plainByDefault: Bool { d.bool(forKey: plainByDefaultKey) }
    static var moveToTop: Bool { d.bool(forKey: moveToTopKey) }
    static var skipSensitive: Bool { d.bool(forKey: skipSensitiveKey) }
    static var paused: Bool {
        get { d.bool(forKey: pausedKey) }
        set { d.set(newValue, forKey: pausedKey) }
    }
    static var showInDock: Bool { d.bool(forKey: showInDockKey) }
    static var popupPosition: PopupPosition { PopupPosition(rawValue: d.string(forKey: popupPositionKey) ?? "") ?? .cursor }

    static var excludedApps: [String] {
        get { d.stringArray(forKey: excludedAppsKey) ?? [] }
        set { d.set(newValue, forKey: excludedAppsKey) }
    }

    static func shortcut(_ key: String, fallback: Shortcut) -> Shortcut? {
        guard let data = d.data(forKey: key) else { return d.bool(forKey: key + ".cleared") ? nil : fallback }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    static func setShortcut(_ shortcut: Shortcut?, for key: String) {
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            d.set(data, forKey: key)
            d.set(false, forKey: key + ".cleared")
        } else {
            d.removeObject(forKey: key)
            d.set(true, forKey: key + ".cleared")
        }
        NotificationCenter.default.post(name: .pastlogShortcutsChanged, object: nil)
    }

    static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pastlog", isDirectory: true)
    }

    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Pastlog: launch at login change failed: \(error)")
            }
        }
    }
}
