import AppKit
import PDFKit

struct PDFFreeTextService {
    private let geometryService = PDFAnnotationGeometryService()

    func annotation(on page: PDFPage, at point: NSPoint) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .cropBox)
        let size = NSSize(
            width: min(180, pageBounds.width),
            height: min(52, pageBounds.height)
        )
        let proposedBounds = NSRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        let annotation = PDFAnnotation(
            bounds: geometryService.clampedBounds(proposedBounds, inside: pageBounds),
            forType: .freeText,
            withProperties: nil
        )
        annotation.contents = "Text"
        annotation.font = .systemFont(ofSize: 16)
        annotation.fontColor = .black
        annotation.color = .clear

        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border

        let author = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        annotation.userName = author.isEmpty ? nil : author
        return annotation
    }
}
