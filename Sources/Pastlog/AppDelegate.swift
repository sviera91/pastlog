import AppKit
import CoreText
import PastlogCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: ClipStore!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var statusItem: NSStatusItem!
    private var preferencesWindow: NSWindow?
    private var lastDockSetting: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.register()
        FontLoader.registerBundledFonts()

        store = ClipStore(directory: Settings.dataDirectory, maxItems: Settings.maxItems)
        store.load()
        monitor = ClipboardMonitor(store: store)
        monitor.start()

        panel = PanelController(store: store, monitor: monitor)
        panel.showPreferences = { [weak self] in self?.showPreferences() }
        panel.statusButton = { [weak self] in self?.statusItem.button }

        setUpStatusItem()
        registerHotKeys()
        applySettings()

        NotificationCenter.default.addObserver(forName: .pastlogShortcutsChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.registerHotKeys() }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applySettings() }
        }

        if !UserDefaults.standard.bool(forKey: Settings.didOnboardKey) {
            UserDefaults.standard.set(true, forKey: Settings.didOnboardKey)
            showPreferences()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { store.saveNow() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show(.center)
        return false
    }

    // MARK: Settings

    private func applySettings() {
        if store.maxItems != Settings.maxItems { store.maxItems = Settings.maxItems }
        let dock = Settings.showInDock
        if dock != lastDockSetting {
            lastDockSetting = dock
            NSApp.setActivationPolicy(dock ? .regular : .accessory)
        }
        updateStatusIcon()
    }

    private func registerHotKeys() {
        HotKeyCenter.shared.register(id: 1, shortcut: Settings.shortcut(Settings.openShortcutKey, fallback: .openDefault)) { [weak self] in
            self?.panel.toggle(Settings.popupPosition)
        }
        HotKeyCenter.shared.register(id: 2, shortcut: Settings.shortcut(Settings.quickShortcutKey, fallback: .quickDefault)) { [weak self] in
            self?.panel.toggle(.cursor)
        }
    }

    // MARK: Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Pastlog — clipboard history"
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        let name = Settings.paused ? "pause.circle" : "list.clipboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Pastlog")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            panel.toggle(.menuBar)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Pastlog", action: #selector(openPanel), keyEquivalent: "")
        if let s = Settings.shortcut(Settings.openShortcutKey, fallback: .openDefault) { open.title += "   \(s.display)" }
        menu.addItem(open)
        let pause = NSMenuItem(title: "Pause Recording", action: #selector(togglePause), keyEquivalent: "")
        pause.state = Settings.paused ? .on : .off
        menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Clear History…", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pastlog", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.target == nil && $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() { panel.show(.menuBar) }
    @objc private func togglePause() { Settings.paused.toggle() }
    @objc private func openPreferences() { showPreferences() }

    @objc private func clearHistory() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All unpinned clips will be deleted. Pinned clips are kept."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.clear(keepPinned: true) }
    }

    func showPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(store: store)))
            window.title = "Pastlog Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        NSApp.activate()
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
}

enum FontLoader {
    static func registerBundledFonts(extraDirectory: URL? = nil) {
        var dirs: [URL] = []
        if let resources = Bundle.main.resourceURL { dirs.append(resources.appendingPathComponent("Fonts")) }
        if let extraDirectory { dirs.append(extraDirectory) }
        for dir in dirs {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension.lowercased() == "ttf" {
                CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
            }
        }
    }
}
