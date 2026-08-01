import AppKit
import PDFKit

struct PDFShapeService {
    private let geometryService = PDFAnnotationGeometryService()

    func annotation(
        style: ShapeAnnotationStyle,
        on page: PDFPage,
        at point: NSPoint
    ) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .cropBox)
        let size = NSSize(
            width: min(140, pageBounds.width),
            height: min(90, pageBounds.height)
        )
        let proposedBounds = NSRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        let annotation = PDFAnnotation(
            bounds: geometryService.clampedBounds(proposedBounds, inside: pageBounds),
            forType: style.annotationSubtype,
            withProperties: nil
        )
        annotation.color = .systemRed
        annotation.interiorColor = .clear

        let border = PDFBorder()
        border.lineWidth = 2
        annotation.border = border

        let author = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        annotation.userName = author.isEmpty ? nil : author
        return annotation
    }
}
