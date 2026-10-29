# Pastlog

A searchable clipboard history for macOS. Pastlog lives in the menu bar and keeps everything you copy, so you can find it and paste it again.

Requires macOS 14 or later on Apple silicon.

## Install

1. Download the latest `Pastlog-<version>.zip` from [Releases](https://github.com/sviera91/pastlog/releases), unzip it, and move `Pastlog.app` to `/Applications`.
2. The app isn't notarized by Apple, so macOS blocks the first launch. Right-click `Pastlog.app` → **Open** → **Open**. If macOS says the app is damaged, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Pastlog.app
   ```
3. To paste straight into other apps, allow Pastlog in **System Settings → Privacy & Security → Accessibility**. Without this, Pastlog copies the clip and you press `⌘V` yourself.

**Does it keep asking for access when Pastlog is already switched on?** That happens after an update. In the Accessibility list, select Pastlog, remove it with **−**, add it back with **+**, then relaunch Pastlog.

## Features

- Keeps 50 to 9,999 clips. Pinned clips are never removed.
- Saves text, rich text, links, images, files, and colors.
- Search, with filters for All, Pinned, Text, Links, Images, and Files.
- Pastes with or without formatting.
- Lets you pin, edit, and delete clips, and shows details for each clip.
- Can ignore apps you choose and passwords from password managers.
- Includes 11 themes and can match the system appearance.
- Doesn't save duplicates. Copying something again moves it to the top.

## Shortcuts

| Action | Shortcut |
|---|---|
| Open Pastlog | `⌃⌘V` |
| Open the quick menu at the cursor | `⌃⌥V` |
| Paste / paste as plain text | `↩` / `⇧↩` |
| Paste one of the first 10 clips | `⌘1`–`⌘9`, `⌘0` |
| Pin / edit / delete | `⇧⌘P` / `⌘E` / `⌘⌫` |
| Switch to the next filter | `⇥` |

To change the shortcuts, go to Preferences → Shortcuts.

## Privacy

History is stored only on your Mac, in `~/Library/Application Support/Pastlog`. Pastlog doesn't sync or upload anything.

## Build from source

You only need the Command Line Tools. Xcode isn't required.

```bash
./scripts/build.sh            # builds dist/Pastlog.app
./scripts/build.sh --install  # also installs it to /Applications and launches it
swift run --scratch-path ~/Library/Caches/Pastlog-build PastlogSelfTest
```

`build.sh` signs the app with the code-signing identity in `PASTLOG_SIGN_IDENTITY`, or with one named `Pastlog Local Signing`. If it finds neither, it signs ad hoc, and you'll need to grant Accessibility again after every rebuild.

## Contributing

Open a pull request against `main`. A code owner has to approve it. See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

[MIT](LICENSE). The fonts (VT323 and Space Mono) are under the SIL Open Font License; see `Resources/Fonts`.
