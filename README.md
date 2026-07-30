# Formic

Formic is a native macOS PDF workspace built with SwiftUI, AppKit, and PDFKit.

The current implementation can open PDFs in independent document windows, render and navigate pages, search text, create and edit text-markup and sticky-note annotations, reposition sticky notes with undo/redo, inspect document and annotation properties, and use explicit save, copy, export, and print workflows.

## Requirements

- macOS 14 or later
- Xcode command-line tools with Swift 5.10 or later

## Build and run

```bash
./script/build_and_run.sh
```

Build, launch, and verify that the app process is running:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
swift test
```

The built application is staged at `dist/Formic.app`.

## Create a DMG

Create an optimized development disk image:

```bash
./script/package_dmg.sh
```

The command creates `dist/Formic-0.1.0.dmg` with a drag-to-Applications layout,
plus `dist/Formic-0.1.0.dmg.sha256` for download verification. Override the app
version and monotonically increasing build number when preparing a new build:

```bash
FORMIC_VERSION=0.2.0 FORMIC_BUILD_NUMBER=2 ./script/package_dmg.sh
```

This DMG is intended for development and private testing. Its application is
ad-hoc signed to seal the bundle, but it is not Developer ID signed or notarized.
macOS can therefore show an unidentified-developer warning after the DMG is
downloaded. A public release should add Developer ID signing and notarization to
the same packaging workflow.

## Create a DMG in GitHub Actions

The `Build and Publish` workflow runs the test suite and creates a downloadable
DMG artifact on pushes to `main`, pull requests, version tags, and manual runs.
It uses GitHub's hosted `macos-latest` runner, so no self-managed Mac is required.

After the intended release commit is merged into `main`, create a semantic
version tag such as `v0.1.0` and push it:

```bash
git switch main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

The workflow uses the tag as the application version and the GitHub run number
as its build number. Tagged builds create a GitHub Release containing
`Formic-0.1.0.dmg` and its SHA-256 checksum. Non-tagged builds remain available
as workflow artifacts for 30 days.

The generated application is currently Apple Silicon-only, ad-hoc signed, and
not notarized. macOS may therefore require approval in Privacy & Security before
the first launch.

## License

Formic is available under the [MIT License](LICENSE).

## Current scope

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the product scope and delivery roadmap, and [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) for the PDFKit validation gate.
