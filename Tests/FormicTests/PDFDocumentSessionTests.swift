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
}
