# Formic

Formic is a private, native macOS PDF workspace built with SwiftUI, AppKit, and PDFKit.

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

## Current scope

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the product scope and delivery roadmap, and [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) for the PDFKit validation gate.
