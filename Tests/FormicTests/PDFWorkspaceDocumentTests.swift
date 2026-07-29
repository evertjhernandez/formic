import AppKit
import PDFKit
import XCTest
@testable import Formic

@MainActor
final class PDFWorkspaceDocumentTests: XCTestCase {
    func testSaveFromRibbonWritesAndReopensCurrentDocument() async throws {
        let source = try makePDFData()
        let workspaceDocument = PDFWorkspaceDocument()
        try workspaceDocument.read(from: source, ofType: "com.adobe.pdf")

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        workspaceDocument.fileURL = destination

        let saveCompleted = expectation(description: "Ribbon save completed")
        var saveError: Error?

        workspaceDocument.saveFromRibbon { error in
            saveError = error
            saveCompleted.fulfill()
        }

        await fulfillment(of: [saveCompleted], timeout: 3)
        XCTAssertNil(saveError)

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        XCTAssertEqual(reopened.pageCount, 1)

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
}
