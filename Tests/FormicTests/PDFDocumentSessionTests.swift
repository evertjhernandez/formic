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
