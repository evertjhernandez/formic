import XCTest
@testable import Formic

final class PDFAnnotationGeometryServiceTests: XCTestCase {
    func testClampedBoundsPreserveSizeAtEveryPageEdge() {
        let service = PDFAnnotationGeometryService()
        let pageBounds = NSRect(x: 20, y: 30, width: 300, height: 400)
        let annotationSize = NSSize(width: 40, height: 50)

        let belowMinimum = service.clampedBounds(
            NSRect(origin: NSPoint(x: -500, y: -500), size: annotationSize),
            inside: pageBounds
        )
        XCTAssertEqual(belowMinimum.origin, pageBounds.origin)
        XCTAssertEqual(belowMinimum.size, annotationSize)

        let aboveMaximum = service.clampedBounds(
            NSRect(origin: NSPoint(x: 800, y: 900), size: annotationSize),
            inside: pageBounds
        )
        XCTAssertEqual(aboveMaximum.maxX, pageBounds.maxX)
        XCTAssertEqual(aboveMaximum.maxY, pageBounds.maxY)
        XCTAssertEqual(aboveMaximum.size, annotationSize)
    }
}
