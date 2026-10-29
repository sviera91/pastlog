import AppKit
import PastlogCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var model: PanelModel
    let actions: PanelActions
    @AppStorage(Settings.themeKey) private var themeID = "citypop"
    @AppStorage(Settings.pausedKey) private var paused = false
    @AppStorage(Settings.plainByDefaultKey) private var plainByDefault = false
    @Environment(\.colorScheme) private var systemScheme
    @FocusState private var searchFocused: Bool

    private var theme: Theme { Theme.resolve(themeID, scheme: systemScheme) }

    var body: some View {
        let results = model.results
        ZStack {
            theme.background
            if theme.retro {
                RadialGradient(colors: [theme.accent2.opacity(0.10), .clear], center: .topTrailing, startRadius: 10, endRadius: 320)
                RadialGradient(colors: [theme.accent.opacity(0.08), .clear], center: .bottomLeading, startRadius: 10, endRadius: 340)
            }
            VStack(spacing: 0) {
                header
                searchField.padding(.horizontal, 12).padding(.bottom, 8)
                filterBar.padding(.horizontal, 12).padding(.bottom, 8)
                Rectangle().fill(theme.border).frame(height: 1)
                content(results)
                Rectangle().fill(theme.border).frame(height: 1)
                footer(results)
            }
            if theme.retro { Scanlines() }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(theme.retro ? theme.accent.opacity(0.35) : theme.border, lineWidth: 1)
        )
        .environment(\.colorScheme, theme.colorScheme)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            if theme.retro {
                Text(">").font(theme.titleFont).foregroundStyle(theme.accent2)
                Text("past.log").font(theme.titleFont).foregroundStyle(theme.accent)
                    .shadow(color: theme.accent.opacity(0.7), radius: 6)
                TimelineView(.periodic(from: .now, by: 0.6)) { context in
                    Text("_").font(theme.titleFont).foregroundStyle(theme.accent)
                        .opacity(Int(context.date.timeIntervalSince1970 / 0.6) % 2 == 0 ? 1 : 0)
                }
            } else {
                Image(systemName: "list.clipboard.fill").foregroundStyle(theme.accent)
                Text("Pastlog").font(theme.titleFont).foregroundStyle(theme.text)
            }
            Spacer()
            if paused {
                Label("Paused", systemImage: "pause.circle.fill").labelStyle(.titleAndIcon)
                    .font(theme.captionFont).foregroundStyle(theme.accent2)
            }
            Text(theme.retro ? "\(store.clips.count) entries" : "\(store.clips.count) clips")
                .font(theme.monoFont).foregroundStyle(theme.muted)
            Button { actions.openPreferences() } label: {
                Image(systemName: "gearshape").foregroundStyle(theme.muted)
            }
            .buttonStyle(.plain)
            .help("Preferences (⌘,)")
        }
        .padding(.horizontal, 14)
        .padding(.top, theme.retro ? 8 : 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            if theme.retro {
                Text("$ grep").font(theme.monoFont).foregroundStyle(theme.accent2)
            } else {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
            }
            TextField("", text: $model.query, prompt: Text(theme.retro ? "search everything you've copied…" : "Search clips")
                .foregroundStyle(theme.muted))
                .textFieldStyle(.plain)
                .font(theme.bodyFont)
                .foregroundStyle(theme.text)
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: theme.rowRadius + 2).fill(theme.surface))
        .overlay(RoundedRectangle(cornerRadius: theme.rowRadius + 2)
            .strokeBorder(searchFocused && theme.retro ? theme.accent.opacity(0.6) : theme.border))
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases, id: \.self) { filter in
                let selected = model.filter == filter
                Button { model.filter = filter } label: {
                    Text(theme.retro ? "./" + filter.label.lowercased() : filter.label)
                        .font(theme.captionFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(selected ? (theme.retro ? theme.accent : theme.selectedText) : theme.muted)
                        .background(Capsule().fill(selected ? (theme.retro ? theme.accent.opacity(0.12) : theme.accent) : .clear))
                        .overlay(Capsule().strokeBorder(selected && theme.retro ? theme.accent.opacity(0.6) : theme.border))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ results: [Clip]) -> some View {
        if let editingID = model.editingID, store.clips.contains(where: { $0.id == editingID }) {
            editor
        } else if results.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: store.clips.isEmpty ? "list.clipboard" : "magnifyingglass")
                    .font(.system(size: 28)).foregroundStyle(theme.muted)
                Text(store.clips.isEmpty ? (theme.retro ? "$ past.log is empty — copy something" : "Nothing copied yet")
                                         : (theme.retro ? "grep: no matches" : "No matching clips"))
                    .font(theme.bodyFont).foregroundStyle(theme.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, clip in
                            row(clip, index: index)
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.automatic)
                .onChange(of: model.selection) {
                    let current = model.results
                    if current.indices.contains(model.selection) {
                        proxy.scrollTo(current[model.selection].id)
                    }
                }
            }
        }
    }

    private func row(_ clip: Clip, index: Int) -> some View {
        ClipRow(clip: clip, index: index, selected: index == model.selection, theme: theme,
                thumbnail: Thumbnails.image(for: clip, store: store))
            .id(clip.id)
            .contentShape(Rectangle())
            .onTapGesture {
                actions.paste(clip, plain: NSEvent.modifierFlags.contains(.shift) != plainByDefault)
            }
            .onHover { inside in
                if inside { model.hoveredID = clip.id; model.selection = index }
            }
            .help(ClipFormat.details(clip))
            .contextMenu {
                Button("Paste") { actions.paste(clip, plain: false) }
                if clip.plainText != nil { Button("Paste as Plain Text") { actions.paste(clip, plain: true) } }
                Button("Copy to Clipboard") { actions.copyOnly(clip) }
                Divider()
                Button(clip.pinned ? "Unpin" : "Pin to Top") { actions.togglePin(clip) }
                if clip.plainText != nil && clip.kind != .file { Button("Edit…") { actions.beginEdit(clip) } }
                if clip.kind == .link || clip.kind == .file { Button("Open") { actions.open(clip) } }
                if clip.kind == .file { Button("Reveal in Finder") { actions.reveal(clip) } }
                Divider()
                Button("Delete", role: .destructive) { actions.delete(clip) }
            }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.retro ? "$ vim clip.txt" : "Edit clip").font(theme.captionFont).foregroundStyle(theme.muted)
            TextEditor(text: $model.editText)
                .font(theme.bodyFont)
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: theme.rowRadius).fill(theme.surface))
                .overlay(RoundedRectangle(cornerRadius: theme.rowRadius).strokeBorder(theme.border))
            HStack {
                Text("⌘↩ save · esc cancel").font(theme.monoFont).foregroundStyle(theme.muted)
                Spacer()
                Button("Cancel") { actions.cancelEdit() }
                Button("Save") { actions.saveEdit() }.buttonStyle(.borderedProminent).tint(theme.accent)
            }
        }
        .padding(12)
    }

    // MARK: Footer

    private func footer(_ results: [Clip]) -> some View {
        let focus = model.hoveredID.flatMap { id in results.first { $0.id == id } } ?? model.selectedClip
        return VStack(alignment: .leading, spacing: 4) {
            if let focus {
                HStack(spacing: 6) {
                    if let icon = Thumbnails.appIcon(bundleID: focus.sourceBundleID) {
                        Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                    }
                    Text(ClipFormat.details(focus)).lineLimit(1).truncationMode(.middle)
                }
                .font(theme.captionFont).foregroundStyle(theme.retro ? theme.accent.opacity(0.85) : theme.muted)
            }
            Text(model.editingID == nil
                 ? "↩ paste  ⇧↩ plain  ⌘1–0 quick  ⇧⌘P pin  ⌘E edit  ⌘⌫ delete  ⇥ filter"
                 : "Editing — ⌘↩ save, esc cancel")
                .font(theme.monoFont).foregroundStyle(theme.muted.opacity(0.8)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.surface.opacity(theme.retro ? 0.6 : 0.5))
    }
}

struct ClipRow: View {
    let clip: Clip
    let index: Int
    let selected: Bool
    let theme: Theme
    let thumbnail: NSImage?

    var body: some View {
        let fg = selected ? theme.selectedText : theme.text
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(theme.surface)
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: clip.kind.symbol)
                        .foregroundStyle(theme.retro ? (clip.kind == .link ? theme.accent2 : theme.accent) : theme.accent)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.border))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title.isEmpty ? " " : clip.title)
                    .font(theme.bodyFont)
                    .foregroundStyle(fg)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(clip.kind.label)
                    if let app = clip.sourceAppName { Text("· \(app)") }
                    Text("· \(ClipFormat.ago(clip.lastCopied))")
                }
                .font(theme.captionFont)
                .foregroundStyle(selected && !theme.retro ? fg.opacity(0.75) : theme.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            if clip.pinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(selected && !theme.retro ? fg : theme.accent2)
            }
            if index < 10 {
                Text("⌘\((index + 1) % 10)")
                    .font(theme.monoFont)
                    .foregroundStyle(selected && !theme.retro ? fg.opacity(0.8) : theme.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: theme.rowRadius)
                .fill(selected ? theme.selection : (theme.retro ? theme.row.opacity(0.45) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.rowRadius)
                .strokeBorder(selected && theme.retro ? theme.accent.opacity(0.7) : .clear)
        )
        .shadow(color: selected && theme.retro ? theme.accent.opacity(0.35) : .clear, radius: 6)
    }
}
