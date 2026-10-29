import AppKit
import ApplicationServices
import PastlogCore

@MainActor
enum Paster {
    /// Puts a clip back on the general pasteboard, either with every original representation or as plain text.
    static func write(_ clip: Clip, store: ClipStore, plain: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if plain, let text = clip.plainText, !text.isEmpty {
            pasteboard.setString(text, forType: .string)
            return
        }
        let items: [NSPasteboardItem] = clip.items.map { rep in
            let item = NSPasteboardItem()
            for flavor in rep.flavors {
                if let data = store.data(for: flavor, in: clip) {
                    item.setData(data, forType: NSPasteboard.PasteboardType(flavor.type))
                }
            }
            return item
        }
        if !pasteboard.writeObjects(items), let text = clip.plainText {
            pasteboard.setString(text, forType: .string)
        }
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Simulates ⌘V in the frontmost app (requires Accessibility permission).
    static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
