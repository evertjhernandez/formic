import AppKit
import PDFKit
import XCTest
@testable import Formic

@MainActor
final class PDFWorkspaceDocumentTests: XCTestCase {
    func testDocumentsRequireExplicitSave() {
        XCTAssertFalse(PDFWorkspaceDocument.autosavesInPlace)
    }

    func testSaveFromRibbonDoesNotRewriteUnchangedDocument() throws {
        let source = try makePDFData()
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: source, ofType: "com.adobe.pdf")

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination

        var completionCalled = false
        workspaceDocument.saveFromRibbon(requiresConfirmation: false) { error in
            XCTAssertNil(error)
            completionCalled = true
        }

        XCTAssertTrue(completionCalled)
        XCTAssertEqual(workspaceDocument.session.saveState, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testSaveFromRibbonWritesChangedDocument() async throws {
        let source = try makePDFData()
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: source, ofType: "com.adobe.pdf")

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination
        workspaceDocument.updateChangeCount(.changeDone)

        XCTAssertTrue(workspaceDocument.session.hasUnsavedChanges)

        let saveCompleted = expectation(description: "Ribbon save completed")
        var saveError: Error?

        workspaceDocument.saveFromRibbon(requiresConfirmation: false) { error in
            saveError = error
            saveCompleted.fulfill()
        }

        XCTAssertTrue(
            workspaceDocument.session.saveState == .saving
                || workspaceDocument.session.saveState == .saved
        )
        await fulfillment(of: [saveCompleted], timeout: 3)
        XCTAssertNil(saveError)
        XCTAssertEqual(workspaceDocument.session.saveState, .saved)
        XCTAssertFalse(workspaceDocument.session.hasUnsavedChanges)

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        XCTAssertEqual(reopened.pageCount, 1)

        try? FileManager.default.removeItem(at: destination)
    }

    func testTextMarkupMarksDocumentEditedAndSurvivesSaveReopen() async throws {
        let source = try makeSearchablePDFData(text: "Formic annotation persistence")
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: source, ofType: "com.adobe.pdf")
        workspaceDocument.makeWindowControllers()

        let document = try XCTUnwrap(workspaceDocument.session.document)
        let pdfView = PDFView()
        pdfView.document = document
        workspaceDocument.session.viewBridge.attach(pdfView)
        let selection = try XCTUnwrap(document.findString("annotation", withOptions: []).first)
        pdfView.setCurrentSelection(selection, animate: false)
        workspaceDocument.session.syncTextSelection()

        XCTAssertEqual(workspaceDocument.session.applyTextMarkup(.underline), 1)
        let changeRegistered = expectation(description: "Undoable annotation change registered")
        DispatchQueue.main.async {
            changeRegistered.fulfill()
        }
        await fulfillment(of: [changeRegistered], timeout: 1)
        XCTAssertTrue(workspaceDocument.isDocumentEdited)
        XCTAssertTrue(workspaceDocument.session.hasUnsavedChanges)

        workspaceDocument.session.undo()
        let undoRegistered = expectation(description: "Annotation undo registered")
        DispatchQueue.main.async {
            undoRegistered.fulfill()
        }
        await fulfillment(of: [undoRegistered], timeout: 1)
        XCTAssertFalse(workspaceDocument.isDocumentEdited)
        XCTAssertFalse(workspaceDocument.session.hasUnsavedChanges)

        workspaceDocument.session.redo()
        let redoRegistered = expectation(description: "Annotation redo registered")
        DispatchQueue.main.async {
            redoRegistered.fulfill()
        }
        await fulfillment(of: [redoRegistered], timeout: 1)
        XCTAssertTrue(workspaceDocument.isDocumentEdited)
        XCTAssertTrue(workspaceDocument.session.hasUnsavedChanges)

        let createdAnnotation = try XCTUnwrap(document.page(at: 0)?.annotations.first)
        workspaceDocument.session.selectAnnotation(createdAnnotation)
        workspaceDocument.session.setSelectedAnnotationColor(.systemGreen)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination
        let saveCompleted = expectation(description: "Annotated PDF saved")

        workspaceDocument.saveFromRibbon(requiresConfirmation: false) { error in
            XCTAssertNil(error)
            saveCompleted.fulfill()
        }
        await fulfillment(of: [saveCompleted], timeout: 3)

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        XCTAssertEqual(reopened.page(at: 0)?.annotations.count, 1)
        XCTAssertEqual(
            reopened.page(at: 0)?.annotations.first?.type,
            "Underline"
        )
        let reopenedAnnotation = try XCTUnwrap(reopened.page(at: 0)?.annotations.first)
        let reopenedColor = try XCTUnwrap(reopenedAnnotation.color.usingColorSpace(.deviceRGB))
        let expectedColor = try XCTUnwrap(NSColor.systemGreen.usingColorSpace(.deviceRGB))
        XCTAssertEqual(reopenedColor.redComponent, expectedColor.redComponent, accuracy: 0.01)
        XCTAssertEqual(reopenedColor.greenComponent, expectedColor.greenComponent, accuracy: 0.01)
        XCTAssertEqual(reopenedColor.blueComponent, expectedColor.blueComponent, accuracy: 0.01)
        XCTAssertFalse(workspaceDocument.isDocumentEdited)
        XCTAssertFalse(workspaceDocument.session.hasUnsavedChanges)

        workspaceDocument.close()
        try? FileManager.default.removeItem(at: destination)
    }

    func testNoteContentAndAuthorSurviveSaveReopen() async throws {
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: makePDFData(), ofType: "com.adobe.pdf")
        workspaceDocument.makeWindowControllers()

        let document = try XCTUnwrap(workspaceDocument.session.document)
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertTrue(workspaceDocument.session.allowsCommenting)
        workspaceDocument.session.activateNoteTool()
        XCTAssertEqual(workspaceDocument.session.annotationTool, .note)
        workspaceDocument.session.placeNote(on: page, at: NSPoint(x: 180, y: 560))
        XCTAssertNotNil(page.annotations.first(where: { $0.type == "Text" }))
        workspaceDocument.session.updateSelectedNote(
            contents: "Review this section before publishing.\nConfirm the final wording.",
            author: "Formic Reviewer"
        )

        let changeRegistered = expectation(description: "Undoable note changes registered")
        DispatchQueue.main.async {
            changeRegistered.fulfill()
        }
        await fulfillment(of: [changeRegistered], timeout: 1)

        XCTAssertTrue(workspaceDocument.isDocumentEdited)
        XCTAssertTrue(workspaceDocument.session.hasUnsavedChanges)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination
        let saveCompleted = expectation(description: "PDF with note saved")

        workspaceDocument.saveFromRibbon(requiresConfirmation: false) { error in
            XCTAssertNil(error)
            saveCompleted.fulfill()
        }
        await fulfillment(of: [saveCompleted], timeout: 3)

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        let note = try XCTUnwrap(
            reopened.page(at: 0)?.annotations.first(where: { $0.type == "Text" })
        )
        XCTAssertEqual(note.type, "Text")
        XCTAssertEqual(note.iconType, .note)
        XCTAssertEqual(
            note.contents,
            "Review this section before publishing.\nConfirm the final wording."
        )
        XCTAssertEqual(note.userName, "Formic Reviewer")
        XCTAssertEqual(note.bounds.origin.x, 168, accuracy: 0.1)
        XCTAssertEqual(note.bounds.origin.y, 548, accuracy: 0.1)
        XCTAssertFalse(workspaceDocument.isDocumentEdited)
        XCTAssertFalse(workspaceDocument.session.hasUnsavedChanges)

        workspaceDocument.close()
        try? FileManager.default.removeItem(at: destination)
    }

    func testMovedNotePositionSurvivesSaveReopen() async throws {
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: makePDFData(), ofType: "com.adobe.pdf")
        workspaceDocument.makeWindowControllers()

        let document = try XCTUnwrap(workspaceDocument.session.document)
        let page = try XCTUnwrap(document.page(at: 0))
        let note = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 24, height: 24),
            forType: .text,
            withProperties: nil
        )
        page.addAnnotation(note)
        workspaceDocument.session.selectAnnotation(note)

        XCTAssertNotNil(
            workspaceDocument.session.beginMovingSelectedAnnotation(note, on: page)
        )
        let movedBounds = try XCTUnwrap(
            workspaceDocument.session.previewSelectedAnnotationMove(
                to: NSRect(x: 240, y: 420, width: 24, height: 24)
            )
        )
        workspaceDocument.session.finishMovingSelectedAnnotation()
        XCTAssertTrue(workspaceDocument.isDocumentEdited)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination
        let saveCompleted = expectation(description: "PDF with moved note saved")

        workspaceDocument.saveFromRibbon(requiresConfirmation: false) { error in
            XCTAssertNil(error)
            saveCompleted.fulfill()
        }
        await fulfillment(of: [saveCompleted], timeout: 3)

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        let reopenedNote = try XCTUnwrap(
            reopened.page(at: 0)?.annotations.first(where: { $0.type == "Text" })
        )
        XCTAssertEqual(reopenedNote.bounds.origin.x, movedBounds.origin.x, accuracy: 0.1)
        XCTAssertEqual(reopenedNote.bounds.origin.y, movedBounds.origin.y, accuracy: 0.1)

        workspaceDocument.close()
        try? FileManager.default.removeItem(at: destination)
    }

    private func makePDFData() throws -> Data {
        let image = NSImage(size: NSSize(width: 612, height: 792))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()

        let document = PDFDocument()
        let page = try XCTUnwrap(PDFPage(image: image))
        document.insert(page, at: 0)
        return try XCTUnwrap(document.dataRepresentation())
    }

    private func makeSearchablePDFData(text: String) throws -> Data {
        let bounds = NSRect(x: 0, y: 0, width: 612, height: 792)
        let view = WorkspaceTestPageView(frame: bounds, text: text)
        return view.dataWithPDF(inside: bounds)
    }
}

private final class WorkspaceTestPageView: NSView {
    private let text: String

    init(frame frameRect: NSRect, text: String) {
        self.text = text
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        NSColor.black.setFill()
        NSString(string: text).draw(
            at: NSPoint(x: 72, y: bounds.height - 72),
            withAttributes: [.font: NSFont.systemFont(ofSize: 18)]
        )
    }
}
