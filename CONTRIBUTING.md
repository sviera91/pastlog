# Contributing

## Build

You need the Xcode Command Line Tools. You don't need the full Xcode app.

```bash
./scripts/build.sh            # builds dist/Pastlog.app
./scripts/build.sh --install  # also installs it to /Applications and launches it
./scripts/build.sh --snapshots # renders every theme to dist/snapshots/
swift run --scratch-path ~/Library/Caches/Pastlog-build PastlogSelfTest
```

`build.sh` signs the app with the code-signing identity named in `PASTLOG_SIGN_IDENTITY`. If that isn't set, it looks for an identity called `Pastlog Local Signing`. If it finds neither, it signs ad hoc. An ad-hoc build loses its Accessibility permission every time you rebuild it.

History is stored in `~/Library/Application Support/Pastlog`.

SwiftUI's `@State` is a macro whose plugin ships only with Xcode, so the views use `@Local` (in `LocalState.swift`) instead.

## Pull requests

`main` is protected. Open a pull request, and a code owner has to approve it before it can be merged. Add your change to [CHANGELOG.md](CHANGELOG.md).

## Licenses

The code is under the MIT License. The fonts, VT323 and Space Mono, are under the SIL Open Font License (see `Resources/Fonts`).
