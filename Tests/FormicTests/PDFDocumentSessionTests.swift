import PDFKit
import XCTest
@testable import Formic

@MainActor
final class PDFDocumentSessionTests: XCTestCase {
    func testReplacingDocumentResetsNavigationAndSearch() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 3)

        session.replaceDocument(document)
        session.goToPage(at: 2)
        session.searchQuery = "example"
        session.replaceDocument(makeDocument(pageCount: 1))

        XCTAssertEqual(session.pageCount, 1)
        XCTAssertEqual(session.currentPageIndex, 0)
        XCTAssertEqual(session.searchQuery, "")
        XCTAssertTrue(session.searchResults.isEmpty)
    }

    func testPageNavigationClampsToDocumentBounds() {
        let session = PDFDocumentSession()
        session.replaceDocument(makeDocument(pageCount: 3))

        session.goToPage(at: 99)
        XCTAssertEqual(session.currentPageIndex, 2)

        session.goToPage(at: -10)
        XCTAssertEqual(session.currentPageIndex, 0)
    }

    func testCurrentPageLabelUsesOneBasedPageNumber() {
        let session = PDFDocumentSession()
        session.replaceDocument(makeDocument(pageCount: 2))
        session.goToPage(at: 1)

        XCTAssertEqual(session.currentPageLabel, "Page 2 of 2")
    }

    func testSaveStateReportsSuccessAndFailure() {
        let session = PDFDocumentSession()

        session.beginSaving()
        XCTAssertEqual(session.saveState, .saving)

        session.finishSaving(with: nil)
        XCTAssertEqual(session.saveState, .saved)

        session.beginSaving()
        session.finishSaving(with: PDFWorkspaceError.unwritableDocument)
        XCTAssertEqual(session.saveState, .failed)
    }

    func testApplyingTextMarkupSupportsUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeSearchableDocument(text: "Select this text for markup")
        let pdfView = PDFView()
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        pdfView.document = document
        session.viewBridge.attach(pdfView)

        let selection = try XCTUnwrap(document.findString("this text", withOptions: []).first)
        pdfView.setCurrentSelection(selection, animate: false)
        session.syncTextSelection()

        XCTAssertTrue(session.canApplyTextMarkup)
        XCTAssertEqual(session.applyTextMarkup(.highlight), 1)
        XCTAssertEqual(document.page(at: 0)?.annotations.count, 1)
        XCTAssertEqual(document.page(at: 0)?.annotations.first?.type, "Highlight")
        XCTAssertEqual(changes.last, .changeDone)
        XCTAssertTrue(session.canUndo)
        XCTAssertFalse(session.hasTextSelection)

        session.undo()

        XCTAssertEqual(document.page(at: 0)?.annotations.count, 0)
        XCTAssertEqual(changes.last, .changeUndone)
        XCTAssertTrue(session.canRedo)

        session.redo()

        XCTAssertEqual(document.page(at: 0)?.annotations.count, 1)
        XCTAssertEqual(changes.last, .changeRedone)
    }

    func testEveryTextMarkupStyleCreatesItsPDFAnnotationSubtype() throws {
        for style in TextMarkupStyle.allCases {
            let session = PDFDocumentSession()
            let document = makeSearchableDocument(text: "Formic markup")
            let pdfView = PDFView()

            session.replaceDocument(document)
            session.configureEditing(undoManager: UndoManager()) { _ in }
            pdfView.document = document
            session.viewBridge.attach(pdfView)

            let selection = try XCTUnwrap(document.findString("markup", withOptions: []).first)
            pdfView.setCurrentSelection(selection, animate: false)
            session.syncTextSelection()
            session.applyTextMarkup(style)

            XCTAssertEqual(
                document.page(at: 0)?.annotations.first?.type,
                String(style.annotationSubtype.rawValue.dropFirst())
            )
        }
    }

    func testSelectingAnnotationPublishesInspectorProperties() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 2)
        let page = try XCTUnwrap(document.page(at: 1))
        let annotation = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 120, height: 20),
            forType: .highlight,
            withProperties: nil
        )
        annotation.color = NSColor.systemGreen.withAlphaComponent(0.5)
        annotation.userName = "Formic Tester"
        page.addAnnotation(annotation)

        session.replaceDocument(document)
        session.selectAnnotation(annotation)

        let selection = try XCTUnwrap(session.annotationSelection)
        XCTAssertEqual(selection.typeName, "Highlight")
        XCTAssertEqual(selection.pageNumber, 2)
        XCTAssertEqual(selection.author, "Formic Tester")
        XCTAssertTrue(selection.canEditAppearance)
        XCTAssertFalse(selection.canMove)
        XCTAssertTrue(selection.canDelete)

        session.selectAnnotation(nil)
        XCTAssertNil(session.annotationSelection)
    }

    func testPlacingNoteCreatesSelectedUndoableAnnotation() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        session.activateNoteTool()

        XCTAssertEqual(session.annotationTool, .note)
        session.placeNote(on: page, at: NSPoint(x: pageBounds.midX, y: pageBounds.midY))

        let note = try XCTUnwrap(page.annotations.first(where: { $0.type == "Text" }))
        XCTAssertEqual(note.type, "Text")
        XCTAssertEqual(note.iconType, .note)
        XCTAssertTrue(pageBounds.contains(note.bounds))
        XCTAssertEqual(session.annotationTool, .selection)
        XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isNote)
        XCTAssertEqual(changes.last, .changeDone)

        session.undo()
        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)

        session.redo()
        XCTAssertEqual(page.annotations.filter { $0.type == "Text" }.count, 1)
        XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isNote)

        session.undo()
        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)
    }

    func testNotePlacementClampsIconInsidePageBounds() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)

        session.replaceDocument(document)
        session.configureEditing(undoManager: UndoManager()) { _ in }
        session.activateNoteTool()
        session.placeNote(
            on: page,
            at: NSPoint(x: pageBounds.minX - 500, y: pageBounds.maxY + 500)
        )

        let noteBounds = try XCTUnwrap(page.annotations.first(where: { $0.type == "Text" })).bounds
        XCTAssertGreaterThanOrEqual(noteBounds.minX, pageBounds.minX)
        XCTAssertGreaterThanOrEqual(noteBounds.minY, pageBounds.minY)
        XCTAssertLessThanOrEqual(noteBounds.maxX, pageBounds.maxX)
        XCTAssertLessThanOrEqual(noteBounds.maxY, pageBounds.maxY)
    }

    func testPlacingFreeTextCreatesSelectedUndoableAnnotation() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        session.activateFreeTextTool()

        XCTAssertEqual(session.annotationTool, .freeText)
        session.placeFreeText(on: page, at: NSPoint(x: pageBounds.midX, y: pageBounds.midY))

        let textBox = try XCTUnwrap(page.annotations.first(where: { $0.type == "FreeText" }))
        let selection = try XCTUnwrap(session.annotationSelection)
        XCTAssertEqual(textBox.contents, "Text")
        XCTAssertEqual(textBox.font?.pointSize, 16)
        XCTAssertTrue(pageBounds.contains(textBox.bounds))
        XCTAssertEqual(session.annotationTool, .selection)
        XCTAssertTrue(selection.isFreeText)
        XCTAssertTrue(selection.isTextAnnotation)
        XCTAssertTrue(selection.canEditText)
        XCTAssertTrue(selection.canMove)
        XCTAssertEqual(changes.last, .changeDone)

        session.undo()
        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)

        session.redo()
        XCTAssertEqual(page.annotations.filter { $0.type == "FreeText" }.count, 1)
        XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isFreeText)
    }

    func testEditingFreeTextAndFontColorSupportsUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let textBox = PDFAnnotation(
            bounds: NSRect(x: 72, y: 620, width: 180, height: 52),
            forType: .freeText,
            withProperties: nil
        )
        textBox.contents = "Original text"
        textBox.userName = "Original Author"
        textBox.fontColor = .black
        textBox.color = .clear
        page.addAnnotation(textBox)
        let undoManager = UndoManager()

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { _ in }
        session.selectAnnotation(textBox)
        session.updateSelectedAnnotationText(
            contents: "Updated text box",
            author: "Updated Author"
        )
        session.setSelectedAnnotationColor(.systemBlue)

        XCTAssertEqual(textBox.contents, "Updated text box")
        XCTAssertEqual(textBox.userName, "Updated Author")
        assertRGB(try XCTUnwrap(textBox.fontColor), matches: .systemBlue)
        XCTAssertEqual(textBox.color.alphaComponent, 0, accuracy: 0.01)

        session.undo()
        assertRGB(try XCTUnwrap(textBox.fontColor), matches: .black)

        session.undo()
        XCTAssertEqual(textBox.contents, "Original text")
        XCTAssertEqual(textBox.userName, "Original Author")

        session.redo()
        session.redo()
        XCTAssertEqual(textBox.contents, "Updated text box")
        assertRGB(try XCTUnwrap(textBox.fontColor), matches: .systemBlue)
    }

    func testEveryShapeStyleCreatesSelectedUndoableAnnotation() throws {
        for style in ShapeAnnotationStyle.allCases {
            let session = PDFDocumentSession()
            let document = makeDocument(pageCount: 1)
            let page = try XCTUnwrap(document.page(at: 0))
            let pageBounds = page.bounds(for: .cropBox)
            let undoManager = UndoManager()

            session.replaceDocument(document)
            session.configureEditing(undoManager: undoManager) { _ in }
            session.activateShapeTool(style)
            session.placeShape(
                style,
                on: page,
                at: NSPoint(x: pageBounds.midX, y: pageBounds.midY)
            )

            let expectedType = String(style.annotationSubtype.rawValue.dropFirst())
            let shape = try XCTUnwrap(page.annotations.first)
            let selection = try XCTUnwrap(session.annotationSelection)
            XCTAssertEqual(shape.type, expectedType)
            XCTAssertEqual(try XCTUnwrap(shape.border).lineWidth, 2)
            XCTAssertEqual(try XCTUnwrap(shape.interiorColor).alphaComponent, 0, accuracy: 0.01)
            XCTAssertTrue(pageBounds.contains(shape.bounds))
            XCTAssertTrue(selection.isShape)
            XCTAssertTrue(selection.canMove)
            XCTAssertTrue(selection.canDelete)
            XCTAssertEqual(session.annotationTool, .selection)

            session.undo()
            XCTAssertTrue(page.annotations.isEmpty)
            XCTAssertNil(session.annotationSelection)

            session.redo()
            XCTAssertEqual(page.annotations.first?.type, expectedType)
            XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isShape)
        }
    }

    func testMovingSelectedShapeClampsToPageAndSupportsUndo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)
        let undoManager = UndoManager()

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { _ in }
        session.activateShapeTool(.rectangle)
        session.placeShape(.rectangle, on: page, at: NSPoint(x: 160, y: 640))

        let shape = try XCTUnwrap(page.annotations.first)
        let originalBounds = shape.bounds
        XCTAssertNotNil(session.beginMovingSelectedAnnotation(shape, on: page))
        let movedBounds = try XCTUnwrap(
            session.previewSelectedAnnotationMove(
                to: originalBounds.offsetBy(dx: 2_000, dy: 2_000)
            )
        )
        session.finishMovingSelectedAnnotation()

        XCTAssertEqual(movedBounds.maxX, pageBounds.maxX, accuracy: 0.1)
        XCTAssertEqual(movedBounds.maxY, pageBounds.maxY, accuracy: 0.1)

        session.undo()
        XCTAssertEqual(shape.bounds, originalBounds)
        session.redo()
        XCTAssertEqual(shape.bounds, movedBounds)
    }

    func testEveryStampStyleCreatesSelectedUndoableAnnotation() throws {
        for style in StampAnnotationStyle.allCases {
            let session = PDFDocumentSession()
            let document = makeDocument(pageCount: 1)
            let page = try XCTUnwrap(document.page(at: 0))
            let pageBounds = page.bounds(for: .cropBox)
            let undoManager = UndoManager()

            session.replaceDocument(document)
            session.configureEditing(undoManager: undoManager) { _ in }
            session.activateStampTool(style)
            session.placeStamp(
                style,
                on: page,
                at: NSPoint(x: pageBounds.midX, y: pageBounds.midY)
            )

            let stamp = try XCTUnwrap(page.annotations.first)
            let selection = try XCTUnwrap(session.annotationSelection)
            XCTAssertEqual(stamp.type, "Stamp")
            XCTAssertEqual(stamp.stampName, style.stampName)
            XCTAssertTrue(pageBounds.contains(stamp.bounds))
            XCTAssertEqual(selection.typeName, "\(style.displayName) stamp")
            XCTAssertTrue(selection.isStamp)
            XCTAssertTrue(selection.canMove)
            XCTAssertTrue(selection.canDelete)
            XCTAssertEqual(session.annotationTool, .selection)

            session.undo()
            XCTAssertTrue(page.annotations.isEmpty)
            XCTAssertNil(session.annotationSelection)

            session.redo()
            XCTAssertEqual(page.annotations.first?.stampName, style.stampName)
            XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isStamp)
        }
    }

    func testFreehandDrawingCreatesSelectedMovableUndoableInkAnnotation() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)
        let undoManager = UndoManager()
        let points = [
            NSPoint(x: 120, y: 620),
            NSPoint(x: 155, y: 650),
            NSPoint(x: 200, y: 610),
            NSPoint(x: 245, y: 640)
        ]

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { _ in }
        session.activateInkTool()
        session.placeInk(on: page, points: points)

        let ink = try XCTUnwrap(page.annotations.first)
        let selection = try XCTUnwrap(session.annotationSelection)
        XCTAssertEqual(ink.type, "Ink")
        XCTAssertEqual(ink.paths?.count, 1)
        XCTAssertEqual(ink.border?.lineWidth, 3)
        XCTAssertTrue(pageBounds.contains(ink.bounds))
        XCTAssertEqual(selection.typeName, "Drawing")
        XCTAssertTrue(selection.isInk)
        XCTAssertTrue(selection.canMove)
        XCTAssertTrue(selection.canDelete)
        XCTAssertEqual(session.annotationTool, .selection)

        session.undo()
        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)

        session.redo()
        XCTAssertEqual(page.annotations.first?.type, "Ink")
        XCTAssertTrue(try XCTUnwrap(session.annotationSelection).isInk)
    }

    func testEditingSelectedNoteSupportsUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let note = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 24, height: 24),
            forType: .text,
            withProperties: nil
        )
        note.contents = "Original note"
        note.userName = "Original Author"
        page.addAnnotation(note)
        let undoManager = UndoManager()

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { _ in }
        session.selectAnnotation(note)
        let updatedContents = "Updated note\nSecond line"
        session.updateSelectedAnnotationText(contents: updatedContents, author: "Updated Author")

        XCTAssertEqual(note.contents, updatedContents)
        XCTAssertEqual(note.userName, "Updated Author")
        XCTAssertEqual(session.annotationSelection?.contents, updatedContents)
        XCTAssertEqual(session.annotationSelection?.author, "Updated Author")

        session.undo()
        XCTAssertEqual(note.contents, "Original note")
        XCTAssertEqual(note.userName, "Original Author")

        session.redo()
        XCTAssertEqual(note.contents, updatedContents)
        XCTAssertEqual(note.userName, "Updated Author")
    }

    func testMovingSelectedNoteClampsToPageAndSupportsUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageBounds = page.bounds(for: .cropBox)
        let originalBounds = NSRect(x: 72, y: 640, width: 24, height: 24)
        let note = PDFAnnotation(
            bounds: originalBounds,
            forType: .text,
            withProperties: nil
        )
        page.addAnnotation(note)
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        session.selectAnnotation(note)

        XCTAssertTrue(try XCTUnwrap(session.annotationSelection).canMove)
        XCTAssertEqual(
            session.beginMovingSelectedAnnotation(note, on: page),
            originalBounds
        )

        let movedBounds = try XCTUnwrap(
            session.previewSelectedAnnotationMove(
                to: originalBounds.offsetBy(dx: 2_000, dy: 2_000)
            )
        )
        XCTAssertEqual(movedBounds.maxX, pageBounds.maxX, accuracy: 0.1)
        XCTAssertEqual(movedBounds.maxY, pageBounds.maxY, accuracy: 0.1)
        XCTAssertTrue(changes.isEmpty)

        session.finishMovingSelectedAnnotation()

        XCTAssertEqual(changes.last, .changeDone)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertEqual(note.bounds, originalBounds)
        XCTAssertEqual(changes.last, .changeUndone)
        XCTAssertTrue(session.canRedo)

        session.redo()
        XCTAssertEqual(note.bounds, movedBounds)
        XCTAssertEqual(changes.last, .changeRedone)
    }

    func testFinishingUnchangedNoteMoveDoesNotCreateDocumentEdit() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let note = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 24, height: 24),
            forType: .text,
            withProperties: nil
        )
        page.addAnnotation(note)
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        session.selectAnnotation(note)
        XCTAssertNotNil(session.beginMovingSelectedAnnotation(note, on: page))
        session.finishMovingSelectedAnnotation()

        XCTAssertTrue(changes.isEmpty)
        XCTAssertFalse(session.canUndo)
    }

    func testAnnotationColorChangesSupportUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let annotation = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 120, height: 20),
            forType: .highlight,
            withProperties: nil
        )
        annotation.color = NSColor.systemYellow.withAlphaComponent(0.5)
        page.addAnnotation(annotation)
        let undoManager = UndoManager()
        var changes: [NSDocument.ChangeType] = []

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { changes.append($0) }
        session.selectAnnotation(annotation)
        session.setSelectedAnnotationColor(.systemBlue)

        assertRGB(annotation.color, matches: .systemBlue)
        XCTAssertEqual(annotation.color.alphaComponent, 0.5, accuracy: 0.01)
        XCTAssertEqual(changes.last, .changeDone)

        session.undo()
        assertRGB(annotation.color, matches: .systemYellow)

        session.redo()
        assertRGB(annotation.color, matches: .systemBlue)
        XCTAssertEqual(changes.last, .changeRedone)
    }

    func testDeletingSelectedAnnotationSupportsUndoAndRedo() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let annotation = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 120, height: 20),
            forType: .underline,
            withProperties: nil
        )
        page.addAnnotation(annotation)
        let undoManager = UndoManager()

        session.replaceDocument(document)
        session.configureEditing(undoManager: undoManager) { _ in }
        session.selectAnnotation(annotation)
        session.deleteSelectedAnnotation()

        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertEqual(page.annotations.count, 1)
        XCTAssertNotNil(session.annotationSelection)
        XCTAssertTrue(session.canRedo)

        session.redo()
        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertNil(session.annotationSelection)
    }

    func testLinkAnnotationCannotBeDeletedFromAnnotationInspector() throws {
        let session = PDFDocumentSession()
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        let annotation = PDFAnnotation(
            bounds: NSRect(x: 72, y: 640, width: 120, height: 20),
            forType: .link,
            withProperties: nil
        )
        page.addAnnotation(annotation)

        session.replaceDocument(document)
        session.configureEditing(undoManager: UndoManager()) { _ in }
        session.selectAnnotation(annotation)

        XCTAssertFalse(try XCTUnwrap(session.annotationSelection).canDelete)
        session.deleteSelectedAnnotation()
        XCTAssertEqual(page.annotations.count, 1)
    }

    private func assertRGB(
        _ actual: NSColor,
        matches expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actualRGB = actual.usingColorSpace(.deviceRGB),
              let expectedRGB = expected.usingColorSpace(.deviceRGB)
        else {
            XCTFail("Expected RGB-compatible colors", file: file, line: line)
            return
        }

        XCTAssertEqual(actualRGB.redComponent, expectedRGB.redComponent, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualRGB.greenComponent, expectedRGB.greenComponent, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actualRGB.blueComponent, expectedRGB.blueComponent, accuracy: 0.01, file: file, line: line)
    }

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()

        for index in 0..<pageCount {
            let image = NSImage(size: NSSize(width: 612, height: 792))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            NSColor.black.setFill()
            NSString(string: "Page \(index + 1)").draw(at: NSPoint(x: 72, y: 720))
            image.unlockFocus()

            if let page = PDFPage(image: image) {
                document.insert(page, at: index)
            }
        }

        return document
    }

    private func makeSearchableDocument(text: String) -> PDFDocument {
        let bounds = NSRect(x: 0, y: 0, width: 612, height: 792)
        let view = SessionTestPageView(frame: bounds, text: text)
        return PDFDocument(data: view.dataWithPDF(inside: bounds)) ?? PDFDocument()
    }
}

private final class SessionTestPageView: NSView {
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
