import AppKit
import PastlogCore
import SwiftUI
import UniformTypeIdentifiers

struct ShortcutRecorder: View {
    let key: String
    let fallback: Shortcut
    @Local private var shortcut: Shortcut?
    @Local private var recording = false
    @Local private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(recording ? "Type shortcut…" : (shortcut?.display ?? "None")) {
                recording ? stop() : start()
            }
            .frame(minWidth: 120)
            Button { save(nil) } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Clear shortcut")
            Button("Default") { save(fallback) }.controlSize(.small)
        }
        .onAppear { shortcut = Settings.shortcut(key, fallback: fallback) }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            if let new = Shortcut(event: event) { save(new); stop() } else { NSSound.beep() }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func save(_ value: Shortcut?) {
        shortcut = value
        Settings.setShortcut(value, for: key)
    }
}

struct PreferencesView: View {
    @ObservedObject var store: ClipStore

    var body: some View {
        TabView {
            GeneralPane().tabItem { Label("General", systemImage: "gearshape") }
            ShortcutsPane().tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AppearancePane().tabItem { Label("Appearance", systemImage: "paintpalette") }
            PrivacyPane(store: store).tabItem { Label("Privacy", systemImage: "hand.raised") }
            AboutPane(store: store).tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 470)
    }
}

private struct GeneralPane: View {
    @AppStorage(Settings.maxItemsKey) private var maxItems = 1000
    @AppStorage(Settings.maxClipMBKey) private var maxClipMB = 50
    @AppStorage(Settings.autoPasteKey) private var autoPaste = true
    @AppStorage(Settings.plainByDefaultKey) private var plainByDefault = false
    @AppStorage(Settings.moveToTopKey) private var moveToTop = true
    @AppStorage(Settings.showInDockKey) private var showInDock = false
    @AppStorage(Settings.popupPositionKey) private var position = PopupPosition.cursor.rawValue
    @Local private var launchAtLogin = Settings.launchAtLogin
    @Local private var trusted = Paster.hasAccessibility

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Pastlog at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { Settings.launchAtLogin = launchAtLogin }
                Toggle("Show in Dock (menu bar icon always shown)", isOn: $showInDock)
            }
            Section("History") {
                Picker("Remember up to", selection: $maxItems) {
                    ForEach([50, 100, 250, 500, 1000, 2500, 5000, 9999], id: \.self) { Text("\($0) clips").tag($0) }
                }
                Picker("Largest single clip", selection: $maxClipMB) {
                    ForEach([10, 25, 50, 100, 250], id: \.self) { Text("\($0) MB").tag($0) }
                }
                Text("Pinned clips never count toward the limit and are never removed automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Pasting") {
                Picker("Open popup", selection: $position) {
                    ForEach(PopupPosition.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                }
                Toggle("Paste directly into the active app", isOn: $autoPaste)
                Toggle("Paste as plain text by default (⇧ inverts)", isOn: $plainByDefault)
                Toggle("Move a clip to the top after pasting it", isOn: $moveToTop)
                HStack {
                    Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Accessibility access granted — direct paste works."
                                 : "Direct paste needs Accessibility access. Without it, clips are copied and you press ⌘V. If Pastlog is already switched on in System Settings, remove it with −, add it again, then relaunch (updates can invalidate an old grant).")
                        .font(.caption)
                    Spacer()
                    if !trusted {
                        Button("Grant Access…") { Paster.requestAccessibility(); Paster.openAccessibilitySettings() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in trusted = Paster.hasAccessibility }
    }
}

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section("Global shortcuts") {
                LabeledContent("Open Pastlog") { ShortcutRecorder(key: Settings.openShortcutKey, fallback: .openDefault) }
                LabeledContent("Quick menu at cursor") { ShortcutRecorder(key: Settings.quickShortcutKey, fallback: .quickDefault) }
            }
            Section("Inside the popup") {
                ForEach([
                    ("Type", "Search everything"), ("↑ ↓", "Move selection"), ("↩", "Paste with original formatting"),
                    ("⇧↩", "Paste as plain text"), ("⌘1 … ⌘9, ⌘0", "Paste clip 1–10 (add ⇧ for plain text)"),
                    ("⇧⌘P", "Pin / unpin"), ("⌘E", "Edit clip text"), ("⌘⌫", "Delete clip"), ("⌘O", "Open link or file"),
                    ("⇥ / ⇧⇥", "Switch filter"), ("⌘,", "Preferences"), ("esc", "Clear search / close"),
                ], id: \.0) { key, action in
                    LabeledContent(action) { Text(key).font(.system(.body, design: .monospaced)) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearancePane: View {
    @AppStorage(Settings.themeKey) private var themeID = "citypop"

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                swatch(id: Theme.systemID, name: "Match System", theme: Theme.all.first { $0.id == "dark" }!, half: Theme.all.first { $0.id == "light" })
                ForEach(Theme.all) { theme in swatch(id: theme.id, name: theme.name, theme: theme, half: nil) }
            }
            .padding(16)
            Text("City Pop · sviera91 mirrors sviera91.github.io: deep-night navy, neon cyan and pink, VT323 and Space Mono type, and CRT scanlines.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 12)
        }
    }

    private func swatch(id: String, name: String, theme: Theme, half: Theme?) -> some View {
        Button { themeID = id } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        theme.background
                        if let half { half.background }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.retro ? "> past.log_" : "Pastlog").font(theme.retro ? .custom("VT323", size: 16) : .system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        RoundedRectangle(cornerRadius: 3).fill(theme.selection).frame(height: 12)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(theme.retro ? theme.accent.opacity(0.7) : .clear))
                        RoundedRectangle(cornerRadius: 3).fill(theme.muted.opacity(0.35)).frame(width: 80, height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(theme.accent2.opacity(0.7)).frame(width: 50, height: 6)
                    }
                    .padding(8)
                    if theme.retro { Scanlines() }
                }
                .frame(height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(themeID == id ? Color.accentColor : .gray.opacity(0.3),
                                                                         lineWidth: themeID == id ? 3 : 1))
                Text(name).font(.callout)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PrivacyPane: View {
    @ObservedObject var store: ClipStore
    @AppStorage(Settings.skipSensitiveKey) private var skipSensitive = true
    @AppStorage(Settings.pausedKey) private var paused = false
    @Local private var excluded = Settings.excludedApps
    @Local private var selection: String?
    @Local private var confirmClear = false

    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Pause recording", isOn: $paused)
                Toggle("Skip items marked as passwords or temporary", isOn: $skipSensitive)
                Text("Password managers (1Password, Bitwarden, KeePassXC, Apple Passwords…) mark secrets as concealed or transient. Pastlog skips those when this is on. Markers aren't foolproof, so add apps below to be certain.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Never record from these apps") {
                List(selection: $selection) {
                    ForEach(excluded, id: \.self) { bundleID in
                        HStack {
                            if let icon = Thumbnails.appIcon(bundleID: bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                            }
                            Text(appName(bundleID))
                            Spacer()
                            Text(bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(bundleID)
                    }
                }
                .frame(minHeight: 90)
                HStack {
                    Button("Add App…", action: addApp)
                    Menu("Add Running App") {
                        ForEach(runningApps(), id: \.0) { id, name in
                            Button(name) { add(id) }
                        }
                    }
                    .fixedSize()
                    Button("Remove") {
                        if let selection { excluded.removeAll { $0 == selection }; Settings.excludedApps = excluded }
                    }
                    .disabled(selection == nil)
                }
            }
            Section("History") {
                Button("Clear History (keeps pinned clips)…") { confirmClear = true }
                    .confirmationDialog("Clear all unpinned clips?", isPresented: $confirmClear) {
                        Button("Clear History", role: .destructive) { store.clear(keepPinned: true) }
                    }
            }
        }
        .formStyle(.grouped)
    }

    private func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func runningApps() -> [(String, String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in app.bundleIdentifier.map { ($0, app.localizedName ?? $0) } }
            .filter { !excluded.contains($0.0) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func add(_ bundleID: String) {
        guard !excluded.contains(bundleID) else { return }
        excluded.append(bundleID)
        Settings.excludedApps = excluded
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { if let id = Bundle(url: url)?.bundleIdentifier { add(id) } }
    }
}

private struct AboutPane: View {
    @ObservedObject var store: ClipStore

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Pastlog").font(.custom("VT323", size: 34))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("A clipboard history for everything you copy — text, rich text, links, images, files.\nCity Pop theme inspired by sviera91.github.io.")
                .multilineTextAlignment(.center).font(.callout)
            Text("\(store.clips.count) clips stored locally · never synced")
                .font(.caption).foregroundStyle(.secondary)
            Button("Show Data Folder") { NSWorkspace.shared.open(Settings.dataDirectory) }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
