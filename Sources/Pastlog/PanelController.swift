import AppKit
import Carbon.HIToolbox
import PastlogCore
import SwiftUI

/// Borderless, non-activating panel: it takes keyboard focus for search without
/// stealing "frontmost app" status, so ⌘V lands back in the app you were using.
final class PastlogPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate, PanelActions {
    let store: ClipStore
    let monitor: ClipboardMonitor
    let model: PanelModel
    let panel = PastlogPanel()
    var statusButton: () -> NSStatusBarButton? = { nil }
    var showPreferences: () -> Void = {}

    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var lastHidden = Date.distantPast
    private var askedForAccessibility = false

    private static let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                    kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0]

    init(store: ClipStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
        self.model = PanelModel(store: store)
        super.init()
        panel.delegate = self
        let host = NSHostingView(rootView: PanelView(store: store, model: model, actions: self))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(_ position: PopupPosition) {
        if panel.isVisible { hide(); return }
        // A click on the menu bar icon first resigns the panel; don't immediately reopen it.
        if Date().timeIntervalSince(lastHidden) < 0.25 { return }
        show(position)
    }

    func show(_ position: PopupPosition) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
        model.reset()

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let width: CGFloat = 460
        // Dynamic max height: scales with the screen, capped for very tall displays.
        let height = min(max(visible.height * 0.62, 340), 640)
        var origin: NSPoint
        switch position {
        case .cursor:
            origin = NSPoint(x: mouse.x - 24, y: mouse.y - height + 12)
        case .center:
            origin = NSPoint(x: visible.midX - width / 2, y: visible.midY - height / 2 + visible.height * 0.08)
        case .menuBar:
            if let button = statusButton(), let window = button.window {
                let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
                origin = NSPoint(x: frame.midX - width / 2, y: frame.minY - height - 6)
            } else {
                origin = NSPoint(x: visible.midX - width / 2, y: visible.maxY - height - 8)
            }
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - height - 8)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        model.focusToken += 1
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeKeyMonitor()
        model.editingID = nil
        lastHidden = Date()
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    // MARK: Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let code = Int(event.keyCode)

        if model.editingID != nil {
            if code == kVK_Escape { cancelEdit(); return true }
            if (code == kVK_Return || code == kVK_ANSI_KeypadEnter) && flags.contains(.command) { saveEdit(); return true }
            return false
        }

        switch code {
        case kVK_Escape:
            if model.query.isEmpty { hide() } else { model.query = "" }
            return true
        case kVK_DownArrow:
            model.move(1); return true
        case kVK_UpArrow:
            model.move(-1); return true
        case kVK_PageDown:
            model.move(8); return true
        case kVK_PageUp:
            model.move(-8); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let clip = model.selectedClip { paste(clip, plain: flags.contains(.shift) != Settings.plainByDefault) }
            return true
        case kVK_Tab:
            model.cycleFilter(backwards: flags.contains(.shift)); return true
        default:
            break
        }

        if flags.contains(.command), let digit = Self.digitKeys.firstIndex(of: code) {
            let results = model.results
            if results.indices.contains(digit) {
                paste(results[digit], plain: flags.contains(.shift) != Settings.plainByDefault)
            }
            return true
        }
        if flags == [.command, .shift] && code == kVK_ANSI_P {
            if let clip = model.selectedClip { togglePin(clip) }
            return true
        }
        if flags == .command {
            switch code {
            case kVK_Delete, kVK_ForwardDelete:
                if let clip = model.selectedClip { delete(clip) }
                return true
            case kVK_ANSI_E:
                if let clip = model.selectedClip { beginEdit(clip) }
                return true
            case kVK_ANSI_O:
                if let clip = model.selectedClip { open(clip) }
                return true
            case kVK_ANSI_Comma:
                openPreferences(); return true
            case kVK_ANSI_F:
                model.focusToken += 1; return true
            default:
                break
            }
        }
        return false
    }

    // MARK: PanelActions

    func paste(_ clip: Clip, plain: Bool) {
        Paster.write(clip, store: store, plain: plain)
        monitor.ignoreCurrentChange()
        store.markPasted(clip.id, moveToTop: Settings.moveToTop)
        hide()
        guard Settings.autoPaste else { return }
        guard Paster.hasAccessibility else {
            if !askedForAccessibility {
                askedForAccessibility = true
                Paster.requestAccessibility()
            }
            return
        }
        var delay = 0.06
        if NSApp.isActive, let previousApp {
            previousApp.activate()
            delay = 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Paster.sendPasteKeystroke() }
    }

    func copyOnly(_ clip: Clip) {
        Paster.write(clip, store: store, plain: false)
        monitor.ignoreCurrentChange()
        hide()
    }

    func togglePin(_ clip: Clip) {
        store.togglePin(clip.id)
        if let index = model.results.firstIndex(where: { $0.id == clip.id }) { model.selection = index }
    }

    func delete(_ clip: Clip) {
        store.delete(clip.id)
        model.selection = min(model.selection, max(0, model.results.count - 1))
    }

    func beginEdit(_ clip: Clip) {
        guard clip.plainText != nil, clip.kind != .file else { NSSound.beep(); return }
        model.editText = clip.plainText ?? ""
        model.editingID = clip.id
    }

    func saveEdit() {
        if let id = model.editingID { store.updateText(id, text: model.editText) }
        model.editingID = nil
        model.focusToken += 1
    }

    func cancelEdit() {
        model.editingID = nil
        model.focusToken += 1
    }

    func open(_ clip: Clip) {
        if clip.kind == .file, let path = clip.filePaths.first {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else if let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: text) {
            NSWorkspace.shared.open(url)
        }
        hide()
    }

    func reveal(_ clip: Clip) {
        NSWorkspace.shared.activateFileViewerSelecting(clip.filePaths.map { URL(fileURLWithPath: $0) })
        hide()
    }

    func openPreferences() {
        hide()
        showPreferences()
    }
}
