# Contributing

## Build

You need the Xcode Command Line Tools. You don't need the full Xcode app.

```bash
./scripts/build.sh            # builds dist/Pastlog.app
./scripts/build.sh --install  # also installs it to /Applications and launches it
./scripts/build.sh --snapshots # renders every theme to dist/snapshots/
swift run --scratch-path ~/Library/Caches/Pastlog-build PastlogSelfTest
./scripts/build.sh --universal # builds for Apple silicon and Intel (needs the full Xcode app)
python3 scripts/readme-images.py # rebuilds the README and website images in docs/ (needs Pillow and --snapshots first)
```

`build.sh` signs the app with the code-signing identity named in `PASTLOG_SIGN_IDENTITY`. If that isn't set, it looks for an identity called `Pastlog Local Signing`. If it finds neither, it signs ad hoc. An ad-hoc build loses its Accessibility permission every time you rebuild it.

History is stored in `~/Library/Application Support/Pastlog`.

SwiftUI's `@State` is a macro whose plugin ships only with Xcode, so the views use `@Local` (in `LocalState.swift`) instead.

## Website

The website at [sviera91.github.io/pastlog](https://sviera91.github.io/pastlog/) is the static site in `docs/`. GitHub Pages publishes it from the `main` branch's `docs/` folder (**Settings → Pages**). There's no build step: edit `docs/index.html` and merge. If you change the page's text, update the FAQ answers in its JSON-LD block too, and bump `lastmod` in `docs/sitemap.xml`.

## Releasing

Releases are signed with a Developer ID certificate and notarized by Apple, so they open on any Mac without a security warning. Pushing a version tag does everything:

1. Move the `Unreleased` section in [CHANGELOG.md](CHANGELOG.md) to the new version number and date, and merge it.
2. Tag the merge commit and push the tag:
   ```bash
   git tag v1.1.0 && git push origin v1.1.0
   ```
3. The **Release** workflow builds a universal app, notarizes it, and drafts a GitHub release with `Pastlog.dmg` and `Pastlog.zip` attached. Check the draft, then click **Publish release**. The website's download button always points at the latest published `Pastlog.dmg`.

### One-time setup

You need a paid [Apple Developer Program](https://developer.apple.com/programs/) membership.

1. **Developer ID certificate.** In Xcode, open **Settings → Accounts → Manage Certificates**, click **+**, and choose **Developer ID Application**. Then in Keychain Access, find **Developer ID Application: *your name***, right-click it, choose **Export**, and save it as a `.p12` file with a password.
2. **Notary API key.** In [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api), create a team key with the **Developer** role. Download the `.p8` file (you can only download it once) and note the key ID and the issuer ID.
3. **Repository secrets.** In **Settings → Secrets and variables → Actions**, add:

   | Secret | Value |
   | --- | --- |
   | `DEVELOPER_ID_P12` | output of `base64 -i DeveloperID.p12` |
   | `DEVELOPER_ID_P12_PASSWORD` | the `.p12` password |
   | `NOTARY_API_KEY` | output of `base64 -i AuthKey_XXXXXXXXXX.p8` |
   | `NOTARY_API_KEY_ID` | the key ID |
   | `NOTARY_API_ISSUER` | the issuer ID |

### Releasing from your own Mac

With the Developer ID certificate in your keychain, save your notary credentials once, then run the release script:

```bash
xcrun notarytool store-credentials pastlog --key AuthKey_XXXXXXXXXX.p8 --key-id KEY_ID --issuer ISSUER_ID
PASTLOG_NOTARY_PROFILE=pastlog PASTLOG_VERSION=1.1.0 ./scripts/release.sh
```

The notarized `Pastlog.dmg` and `Pastlog.zip` end up in `dist/`. Upload both to the GitHub release with those exact names, because the website links to `releases/latest/download/Pastlog.dmg`.

## Pull requests

`main` is protected. Open a pull request, and a code owner has to approve it before it can be merged. Add your change to [CHANGELOG.md](CHANGELOG.md).

## Licenses

The code is under the MIT License. The fonts, VT323 and Space Mono, are under the SIL Open Font License (see `Resources/Fonts`).
