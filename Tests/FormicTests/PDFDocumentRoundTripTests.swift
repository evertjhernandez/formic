import AppKit
import PDFKit
import XCTest

final class PDFDocumentRoundTripTests: XCTestCase {
    func testSearchableTextSurvivesRoundTrip() throws {
        let source = makeDocument(pageSpecifications: [
            .init(size: NSSize(width: 612, height: 792), text: "Formic compatibility sample")
        ])

        let reopened = try roundTrip(source)

        XCTAssertEqual(reopened.pageCount, 1)
        XCTAssertEqual(
            reopened.findString("compatibility", withOptions: [.caseInsensitive]).count,
            1
        )
    }

    func testTextAnnotationSurvivesRoundTrip() throws {
        let source = makeDocument(pageSpecifications: [.standard(text: "Annotated page")])
        let page = try XCTUnwrap(source.page(at: 0))
        let annotation = PDFAnnotation(
            bounds: NSRect(x: 72, y: 620, width: 28, height: 28),
            forType: .text,
            withProperties: nil
        )
        annotation.contents = "Compatibility note"
        annotation.userName = "Formic Tests"
        page.addAnnotation(annotation)

        let reopened = try roundTrip(source)
        let reopenedPage = try XCTUnwrap(reopened.page(at: 0))
        let reopenedAnnotation = try XCTUnwrap(
            reopenedPage.annotations.first(where: { $0.contents == "Compatibility note" })
        )

        XCTAssertEqual(reopenedAnnotation.type, annotation.type)
        XCTAssertEqual(reopenedAnnotation.contents, "Compatibility note")
        XCTAssertEqual(reopenedAnnotation.userName, "Formic Tests")
        XCTAssertFalse(reopenedAnnotation.bounds.isEmpty)
        XCTAssertTrue(reopenedPage.bounds(for: .cropBox).intersects(reopenedAnnotation.bounds))
    }

    func testPageReorderDuplicateRotationAndDeleteSurviveRoundTrip() throws {
        let source = makeDocument(pageSpecifications: [
            .standard(text: "First page"),
            .init(size: NSSize(width: 792, height: 612), text: "Second page"),
            .standard(text: "Third page")
        ])
        let firstPage = try XCTUnwrap(source.page(at: 0))
        let secondPage = try XCTUnwrap(source.page(at: 1))

        source.removePage(at: 0)
        source.insert(firstPage, at: 1)
        secondPage.rotation = 90
        source.insert(try duplicate(firstPage), at: 2)
        source.removePage(at: 3)

        let reopened = try roundTrip(source)

        XCTAssertEqual(reopened.pageCount, 3)
        XCTAssertEqual(reopened.page(at: 0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), "Second page")
        XCTAssertEqual(reopened.page(at: 0)?.rotation, 90)
        XCTAssertEqual(reopened.page(at: 0)?.bounds(for: .mediaBox).size, NSSize(width: 792, height: 612))
        XCTAssertEqual(reopened.page(at: 1)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), "First page")
        XCTAssertEqual(reopened.page(at: 2)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), "First page")
    }

    func testInvalidDataIsRejected() {
        XCTAssertNil(PDFDocument(data: Data("not a pdf".utf8)))
    }

    private func roundTrip(
        _ document: PDFDocument,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> PDFDocument {
        let data = try XCTUnwrap(document.dataRepresentation(), file: file, line: line)
        return try XCTUnwrap(PDFDocument(data: data), file: file, line: line)
    }

    private func duplicate(
        _ page: PDFPage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> PDFPage {
        let data = try XCTUnwrap(page.dataRepresentation, file: file, line: line)
        return try XCTUnwrap(PDFDocument(data: data)?.page(at: 0), file: file, line: line)
    }

    private func makeDocument(pageSpecifications: [PageSpecification]) -> PDFDocument {
        let document = PDFDocument()

        for (index, specification) in pageSpecifications.enumerated() {
            let bounds = NSRect(origin: .zero, size: specification.size)
            let view = PDFTestPageView(frame: bounds, text: specification.text)
            let pageData = view.dataWithPDF(inside: bounds)

            guard let page = PDFDocument(data: pageData)?.page(at: 0) else {
                XCTFail("Could not create generated PDF page")
                continue
            }

            document.insert(page, at: index)
        }

        return document
    }
}

private final class PDFTestPageView: NSView {
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

private struct PageSpecification {
    let size: NSSize
    let text: String

    static func standard(text: String) -> Self {
        .init(size: NSSize(width: 612, height: 792), text: text)
    }
}
