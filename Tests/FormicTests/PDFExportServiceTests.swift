import AppKit
import PDFKit
import XCTest
@testable import Formic

@MainActor
final class PDFExportServiceTests: XCTestCase {
    private let service = PDFExportService()

    func testPDFExportPreservesOriginalBytesExactly() throws {
        let document = makeDocument(pageCount: 2)
        let sourceData = try XCTUnwrap(document.dataRepresentation())

        let artifacts = try service.artifacts(
            for: PDFExportOptions(format: .pdf),
            document: document,
            sourcePDFData: sourceData,
            baseFilename: "Quarterly Report.pdf",
            currentPageIndex: 0
        )

        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].suggestedFilename, "Quarterly Report-copy.pdf")
        XCTAssertEqual(artifacts[0].data, sourceData)
    }

    func testTextExportUsesSelectedPageRange() throws {
        let document = makeDocument(pageCount: 3)
        let sourceData = try XCTUnwrap(document.dataRepresentation())
        let options = PDFExportOptions(
            format: .plainText,
            pageSelection: .range,
            rangeStart: 2,
            rangeEnd: 3
        )

        let artifacts = try service.artifacts(
            for: options,
            document: document,
            sourcePDFData: sourceData,
            baseFilename: "Notes.pdf",
            currentPageIndex: 0
        )
        let text = try XCTUnwrap(String(data: artifacts[0].data, encoding: .utf8))

        XCTAssertFalse(text.contains("Page 1"))
        XCTAssertTrue(text.contains("Page 2"))
        XCTAssertTrue(text.contains("Page 3"))
    }

    func testImageExportCreatesOneNumberedImagePerSelectedPage() throws {
        let document = makeDocument(pageCount: 3)
        let sourceData = try XCTUnwrap(document.dataRepresentation())
        let options = PDFExportOptions(
            format: .png,
            pageSelection: .range,
            rangeStart: 2,
            rangeEnd: 3,
            resolutionDPI: 72
        )

        let artifacts = try service.artifacts(
            for: options,
            document: document,
            sourcePDFData: sourceData,
            baseFilename: "Slides.pdf",
            currentPageIndex: 0
        )

        XCTAssertEqual(artifacts.map(\.suggestedFilename), [
            "Slides-page-02.png",
            "Slides-page-03.png"
        ])
        XCTAssertTrue(artifacts.allSatisfy { NSBitmapImageRep(data: $0.data) != nil })
        XCTAssertEqual(document.pageCount, 3)
        XCTAssertEqual(document.page(at: 0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), "Page 1")
    }

    func testJPEGAndTIFFExportsCreateReadableImages() throws {
        let document = makeDocument(pageCount: 1)
        let sourceData = try XCTUnwrap(document.dataRepresentation())

        for format in [PDFExportFormat.jpeg, .tiff] {
            let options = PDFExportOptions(
                format: format,
                pageSelection: .current,
                resolutionDPI: 72
            )
            let artifact = try XCTUnwrap(
                service.artifacts(
                    for: options,
                    document: document,
                    sourcePDFData: sourceData,
                    baseFilename: "Image Test.pdf",
                    currentPageIndex: 0
                ).first
            )

            XCTAssertTrue(artifact.suggestedFilename.hasSuffix(".\(format.fileExtension)"))
            XCTAssertNotNil(NSBitmapImageRep(data: artifact.data))
        }
    }

    func testInvalidPageRangeIsRejected() throws {
        let document = makeDocument(pageCount: 2)
        let sourceData = try XCTUnwrap(document.dataRepresentation())
        let options = PDFExportOptions(
            format: .plainText,
            pageSelection: .range,
            rangeStart: 2,
            rangeEnd: 4
        )

        XCTAssertThrowsError(
            try service.artifacts(
                for: options,
                document: document,
                sourcePDFData: sourceData,
                baseFilename: "Notes.pdf",
                currentPageIndex: 0
            )
        ) { error in
            guard case PDFExportError.invalidPageRange = error else {
                return XCTFail("Expected an invalid page range error, got \(error)")
            }
        }
    }

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()

        for index in 0..<pageCount {
            let bounds = NSRect(x: 0, y: 0, width: 300, height: 400)
            let view = ExportTestPageView(frame: bounds, text: "Page \(index + 1)")
            let data = view.dataWithPDF(inside: bounds)

            if let page = PDFDocument(data: data)?.page(at: 0) {
                document.insert(page, at: index)
            }
        }

        return document
    }
}

private final class ExportTestPageView: NSView {
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
        NSString(string: text).draw(at: NSPoint(x: 32, y: bounds.height - 48))
    }
}
