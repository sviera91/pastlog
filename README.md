# Pastlog

A menu-bar clipboard manager for macOS. It records everything you copy, makes it searchable, and includes a **City Pop · sviera91** theme based on [sviera91.github.io](https://sviera91.github.io).

Pastlog installs as its own app at `/Applications/Pastlog.app` (`io.github.sviera91.pastlog`).

## Features

| Feature | Pastlog |
|---|---|
| Large history (up to 9,999) | 50 – 9,999 clips. Pinned clips are never trimmed. |
| Text, links, images, files | Records every pasteboard flavor: rich text, images, files, colors, links, and more. |
| Instant search | Multi-word search across content, app, and type, plus filters (All / Pinned / Text / Links / Images / Files). |
| Paste formatted or plain | `↩` pastes formatted, `⇧↩` pastes plain text. You can also make plain the default. |
| Quick paste | `⌘1`–`⌘9`, `⌘0` |
| Pinning | `⇧⌘P` |
| Clip info | Shows source app, type, copied time, paste count, and size. |
| Edit / delete / clear | `⌘E` edits text. `⌘⌫` deletes. Clear History keeps pinned clips. |
| App exclusions | Privacy → Excluded apps |
| Skip sensitive data | Ignores password managers' concealed or transient clips (toggle). |
| Themes | 11 themes plus Match System, including City Pop · sviera91. |
| Menu bar or Dock | Menu-bar icon (right-click for the menu). The Dock icon is optional. |
| Quick menu at cursor | Separate shortcut. |
| Duplicates | A re-copied clip moves to the top instead of being duplicated. |

## Shortcuts

| Action | Default |
|---|---|
| Open Pastlog | `⌃⌘V` |
| Quick menu at cursor | `⌃⌥V` |
| Navigate / paste / plain | `↑↓`, `↩`, `⇧↩` |
| Cycle filter | `⇥` |
| Open link/file · Preferences · Close | `⌘O`, `⌘,`, `esc` |

You can change shortcuts in Preferences → Shortcuts.

## Install

1. Download `Pastlog-<version>.zip` from [Releases](https://github.com/sviera91/pastlog/releases), unzip it, and move `Pastlog.app` to `/Applications`.
2. The release is **not notarized by Apple**, so the first launch is blocked. Right-click `Pastlog.app` → **Open** → **Open**. If macOS says the app is damaged, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Pastlog.app
   ```
3. Grant Accessibility access when asked (see below).

## Auto-paste permission

To paste straight into the frontmost app, Pastlog needs **System Settings → Privacy & Security → Accessibility → Pastlog**. Without this permission, Pastlog copies the clip and you press `⌘V` yourself.

**Keeps asking even though it's switched on?** macOS ties the grant to the app's code signature. After an update or rebuild, the old entry can show as ON but no longer apply. Open Privacy & Security → Accessibility, select Pastlog, click **−**, add it again with **+**, then relaunch Pastlog.

When you build Pastlog yourself, `build.sh` signs it with a code-signing identity named `Pastlog Local Signing` if your keychain has one, or with `PASTLOG_SIGN_IDENTITY`. A stable identity keeps the grant across rebuilds. Without one, `build.sh` falls back to ad-hoc signing.

## Build & install

You only need the Command Line Tools (Xcode isn't required).

```bash
./scripts/build.sh               # build dist/Pastlog.app
./scripts/build.sh --install     # also install to /Applications and launch
./scripts/build.sh --snapshots   # render every theme to dist/snapshots/
swift run --scratch-path ~/Library/Caches/Pastlog-build PastlogSelfTest
```

History is stored locally in `~/Library/Application Support/Pastlog` and is never synced or uploaded.

> SwiftUI's `@State` is now a macro whose plugin ships only with Xcode, so the views use `@Local` (`LocalState.swift`) instead.

## Contributing

`main` is protected. Open a pull request. Every PR needs one approving review from a code owner (see `.github/CODEOWNERS`). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE).

## Credits

The fonts are VT323 and Space Mono, both under the SIL Open Font License (see `Resources/Fonts/OFL-*.txt`). The style was inspired by sviera91.github.io. The app icon artwork is `Resources/Icon/AppIcon-art.png`; `build.sh` clips it to the macOS icon shape.
