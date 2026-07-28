# Formic - macOS PDF Workspace Plan

## 1. Product direction

Formic v1 will be a fast, private, native macOS PDF workspace. It will focus on the tasks PDFKit handles reliably: viewing, searching, annotating, arranging pages, filling common forms, adding a visual signature, and exporting.

The first release will not claim to be a complete Acrobat or UPDF replacement. Existing PDF text reflow, secure redaction, certificate-backed digital signing, XFA form editing, and Office conversion are separate advanced features.

### Intended user promise

> Open, review, mark up, organize, fill, and sign PDFs locally on your Mac, without an account or cloud upload.

### Product principles

- Native Mac behavior over cross-platform uniformity.
- Local processing and privacy by default.
- Document safety over feature count.
- Every edit supports undo and survives save/reopen.
- Keyboard, pointer, menu, toolbar, and accessibility support are part of each feature.

## 2. Version 1 scope

### Included

- Open PDFs from Finder, Open Recent, drag-and-drop, and the system Open panel.
- Multiple document windows.
- Continuous and single-page viewing, zoom, fit modes, page navigation, and rotation-aware rendering.
- Thumbnail and outline sidebar.
- Text search with result navigation.
- Highlight, underline, strikeout, note, free-text, shape, stamp, and ink annotations.
- Annotation selection, movement, resizing, styling, deletion, and inspector controls.
- Insert, extract, reorder, rotate, duplicate, and delete pages.
- Merge and split documents.
- Fill common AcroForm text, checkbox, radio, and choice fields.
- Draw, save locally, and place a visual signature.
- Undo/redo, autosave recovery, Save, Save As, Save a Copy, export, and print.
- Encrypted-document opening and clear handling of edit restrictions.
- Light/dark mode, VoiceOver labels, keyboard navigation, and standard shortcuts.

### Explicitly deferred

- Editing and reflowing existing PDF text or images.
- Whiteout presented as true editing or redaction.
- Permanent secure redaction.
- Cryptographic/PAdES signing and signature validation.
- XFA and document-JavaScript compatibility.
- PDF-to-Word/Excel/PowerPoint conversion.
- Cloud sync, collaboration, accounts, and AI features.
- Windows application.

## 3. Technical architecture

### Platform stack

- Language: Swift.
- UI: SwiftUI, with AppKit where desktop behavior needs lower-level control.
- PDF engine: PDFKit (`PDFView`, `PDFDocument`, `PDFPage`, `PDFAnnotation`).
- Document lifecycle: `NSDocument` for windows, edited state, undo, autosave, versions, save/revert, and printing.
- PDF canvas bridge: `NSViewRepresentable` around `PDFView`.
- Drawing: AppKit pointer/trackpad input converted to PDFKit ink annotations. Do not make PencilKit a required macOS dependency.
- State: Observation for UI state; `UndoManager` and explicit edit commands for document mutations.
- Persistence: atomic document writes, retaining the original until the replacement succeeds.
- OCR after v1: Vision text recognition plus a separately implemented searchable-text layer.

### Window and UI model

- One independent window and document session per open PDF.
- Native sidebar with tabs for thumbnails and outline.
- Central PDF canvas.
- Optional contextual inspector on the right.
- Native toolbar for mode, annotation tools, search, sidebar, inspector, zoom, and share/export.
- Standard macOS menus and shortcuts; commands target the focused document window.
- Dedicated Settings window for general, viewing, annotation, and privacy preferences.

### Suggested source structure

```text
Formic/
  App/
    AppDelegate.swift
    FormicApplication.swift
  Documents/
    PDFWorkspaceDocument.swift
    PDFDocumentSession.swift
    DocumentSnapshot.swift
  Views/
    WorkspaceRootView.swift
    PDFCanvasView.swift
    SidebarView.swift
    ThumbnailListView.swift
    OutlineView.swift
    AnnotationInspectorView.swift
    SearchResultsView.swift
    SettingsView.swift
  Models/
    WorkspaceTool.swift
    DocumentSelection.swift
    AnnotationStyle.swift
  Commands/
    DocumentCommands.swift
    AnnotationCommands.swift
    PageCommands.swift
  Services/
    PDFWriteService.swift
    ThumbnailService.swift
    ExportService.swift
    SignatureStore.swift
  Support/
    PDFCoordinateConverter.swift
    ErrorPresentation.swift
  Tests/
    Unit/
    Integration/
    Fixtures/
```

`PDFWorkspaceDocument` owns the file lifecycle. `PDFDocumentSession` owns the active `PDFDocument`, selection, tools, and edit-command history. Views must not write directly to disk.

## 4. Delivery roadmap

The estimates below assume one experienced macOS developer and are planning ranges, not commitments.

### Milestone 0 - Compatibility spike (1-2 weeks)

- Create the Xcode document-app skeleton and build/run scripts.
- Wrap `PDFView` in SwiftUI and open multiple document windows.
- Assemble a test corpus of at least 50 PDFs: normal, scanned, encrypted, malformed, signed, form-heavy, mixed-size, rotated, and 500+ page documents.
- Test render, search, annotation save/reopen, page mutations, print, and export.
- Verify what PDFKit preserves when rewriting forms, outlines, metadata, encryption, and signatures.
- Record every unsupported or destructive case.

**Exit criterion:** PDFKit passes the core corpus with no unexplained document corruption. Otherwise, pause and evaluate a commercial engine before building the full UI.

### Milestone 1 - Viewer foundation (2 weeks)

- Implement document open/save lifecycle and error presentation.
- Build the sidebar, PDF canvas, toolbar, inspector shell, and Settings scene.
- Add thumbnails, outlines, zoom, page navigation, display modes, search, and printing.
- Add menus, shortcuts, window restoration, Open Recent, and drag-and-drop.
- Add basic performance instrumentation for open time, thumbnail generation, search, and memory.

**Exit criterion:** A user can comfortably read and search all supported test documents, including large files.

### Milestone 2 - Annotation workflow (2-3 weeks)

- Add markup, notes, free text, shapes, stamps, and ink.
- Add selection handles, movement, resizing, colors, line width, opacity, and author metadata.
- Route every mutation through edit commands and `UndoManager`.
- Save and reopen annotations across Preview, Formic, and at least one independent PDF viewer.

**Exit criterion:** Every annotation type round-trips correctly and every mutation supports undo/redo.

### Milestone 3 - Page organization (2 weeks)

- Add thumbnail drag reorder and multi-page selection.
- Add insert, duplicate, rotate, delete, extract, merge, and split.
- Add confirmation or easy undo for destructive actions.
- Preserve mixed page dimensions, crop boxes, rotation, annotations, and outlines where possible.

**Exit criterion:** Page operations pass automated save/reopen tests without losing page content or annotations.

### Milestone 4 - Forms, signatures, and export (2 weeks)

- Detect and fill common AcroForm widgets.
- Add local visual-signature creation and placement.
- Add PDF/image export and a clearly labeled flatten-copy operation.
- Ensure flattening creates a new file and never silently overwrites the editable original.
- Explain unsupported XFA, JavaScript, or cryptographic signature cases rather than failing silently.

**Exit criterion:** Supported forms and visual signatures render consistently after save/reopen and in other viewers.

### Milestone 5 - Release hardening (2-3 weeks)

- Complete App Sandbox and user-selected read/write file access.
- Add autosave recovery, atomic replacement, Save a Copy, and external-file-change handling.
- Complete VoiceOver, keyboard-only use, contrast, reduced motion, and localization readiness.
- Run corruption, crash recovery, memory, large-document, and repeated save-cycle tests.
- Add privacy policy, onboarding, help, diagnostics export, signing, notarization, and distribution packaging.

**Exit criterion:** No known data-loss issue, no critical accessibility blocker, and the release corpus passes on all supported macOS versions.

### Milestone 6 - OCR expansion after v1 (3-5 weeks)

- Add background OCR with progress, cancellation, language controls, and confidence handling.
- Convert page and Vision coordinates reliably.
- Embed an invisible searchable text layer while preserving original page images.
- Validate copy/paste, search, print, file size, and alignment in multiple viewers.

**Exit criterion:** OCR output is searchable and selectable without visibly changing the scanned document.

## 5. Quality gates

Every milestone must include:

- Unit tests for coordinate transforms, page ranges, selection, and edit commands.
- Integration tests that save, close, reopen, and verify the document.
- Cross-viewer checks using Preview and at least one non-Apple viewer.
- Manual testing with mouse, trackpad, keyboard, VoiceOver, light mode, and dark mode.
- Memory and responsiveness checks on large and image-heavy PDFs.
- Validation that cancelled or failed saves leave the original untouched.

Release-blocking failures include document corruption, silent content loss, edits that cannot be undone, false claims of redaction or digital signing, and unsupported files being overwritten.

## 6. Principal risks and mitigations

| Risk | Mitigation |
| --- | --- |
| PDFKit rewrites or drops uncommon PDF features | Run the compatibility spike first; preserve originals and offer Save a Copy. |
| Scope grows toward a full Acrobat clone | Keep advanced content editing, OCR, conversion, collaboration, and Windows outside v1. |
| Whiteout is mistaken for secure redaction | Do not ship it as redaction; use a dedicated PDF engine before offering permanent removal. |
| Visual signature is mistaken for a digital signature | Label it clearly and defer certificate-backed signing to a separate project. |
| Large PDFs cause slow thumbnails or high memory | Generate thumbnails lazily, cache with limits, cancel offscreen work, and profile from Milestone 1. |
| Save/undo architecture is added too late | Establish `NSDocument`, edit commands, `UndoManager`, and atomic writes before feature work. |
| Sandboxed file access breaks reopen workflows | Test Open, drag/drop, recent documents, security-scoped access, and external changes during the foundation milestone. |
| Future Windows build duplicates too much work | Share specifications and test fixtures now; reconsider a cross-platform commercial engine before Windows work. |

## 7. Commercial SDK decision gate

Evaluate Apryse, Foxit, and Nutrient only if the compatibility spike fails or the product later requires true content editing, secure redaction, advanced forms, certified signatures, PDF/A, or cross-platform document logic.

Use the same test corpus for each SDK. Score document fidelity, editing capability, offline operation, Swift integration, UI freedom, Windows portability, accessibility, binary size, support quality, and total licensing cost. Do not choose an SDK from a feature checklist alone.

## 8. First implementation sprint

1. Confirm the application name, bundle identifier, minimum supported macOS version, and App Store versus direct distribution intent.
2. Create the document-based Xcode project and multi-file source structure.
3. Add the build/run environment and a minimal automated test target.
4. Implement `PDFWorkspaceDocument`, the `PDFView` bridge, and a basic document window.
5. Assemble and classify the compatibility corpus.
6. Run the Milestone 0 matrix and write the PDFKit go/no-go report.

No polished annotation UI should be built before this sprint establishes that opening, editing, saving, and reopening representative customer documents is safe.

