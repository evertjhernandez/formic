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

## Current scope

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the product scope and delivery roadmap, and [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md) for the PDFKit validation gate.
