import AppKit
import PDFKit

struct PDFNoteService {
    func annotation(on page: PDFPage, at point: NSPoint) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .cropBox)
        let iconSize = NSSize(
            width: min(24, pageBounds.width),
            height: min(24, pageBounds.height)
        )
        let maximumX = pageBounds.maxX - iconSize.width
        let maximumY = pageBounds.maxY - iconSize.height
        let origin = NSPoint(
            x: min(max(point.x - iconSize.width / 2, pageBounds.minX), maximumX),
            y: min(max(point.y - iconSize.height / 2, pageBounds.minY), maximumY)
        )

        let annotation = PDFAnnotation(
            bounds: NSRect(origin: origin, size: iconSize),
            forType: .text,
            withProperties: nil
        )
        annotation.iconType = .note
        annotation.color = .systemYellow

        let author = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        annotation.userName = author.isEmpty ? nil : author
        return annotation
    }
}
