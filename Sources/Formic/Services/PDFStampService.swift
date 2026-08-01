import AppKit
import CoreText
import PDFKit

struct PDFStampService {
    private let geometryService = PDFAnnotationGeometryService()

    func annotation(
        style: StampAnnotationStyle,
        on page: PDFPage,
        at point: NSPoint
    ) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .cropBox)
        let size = NSSize(
            width: min(180, pageBounds.width),
            height: min(54, pageBounds.height)
        )
        let proposedBounds = NSRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        let annotation = FormicStampAnnotation(
            bounds: geometryService.clampedBounds(proposedBounds, inside: pageBounds),
            forType: .stamp,
            withProperties: nil
        )
        annotation.stampName = style.stampName
        annotation.color = style.color

        let author = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        annotation.userName = author.isEmpty ? nil : author
        return annotation
    }
}

/// PDFKit's stamp subtype stores the stamp name but does not synthesize a useful
/// appearance stream for newly created annotations. Drawing the appearance here
/// keeps new stamps legible in the canvas and gives PDFKit artwork to persist.
private final class FormicStampAnnotation: PDFAnnotation {
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        let stampColor = color.withAlphaComponent(max(color.alphaComponent, 0.85))
        let outerBounds = bounds.insetBy(dx: 2, dy: 2)
        let innerBounds = outerBounds.insetBy(dx: 5, dy: 5)

        context.setStrokeColor(stampColor.cgColor)
        context.setLineJoin(.round)
        context.setLineWidth(3)
        context.addPath(
            CGPath(
                roundedRect: outerBounds,
                cornerWidth: 7,
                cornerHeight: 7,
                transform: nil
            )
        )
        context.strokePath()

        context.setLineWidth(1)
        context.addPath(
            CGPath(
                roundedRect: innerBounds,
                cornerWidth: 4,
                cornerHeight: 4,
                transform: nil
            )
        )
        context.strokePath()

        let label = normalizedStampName.uppercased()
        let availableWidth = max(innerBounds.width - 14, 1)
        let estimatedCharacterWidth = max(CGFloat(label.count) * 0.62, 1)
        let fontSize = min(22, max(10, availableWidth / estimatedCharacterWidth))
        let attributedLabel = NSAttributedString(
            string: label,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: stampColor
            ]
        )
        let line = CTLineCreateWithAttributedString(attributedLabel)
        let lineBounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        context.textPosition = CGPoint(
            x: innerBounds.midX - lineBounds.width / 2 - lineBounds.minX,
            y: innerBounds.midY - lineBounds.height / 2 - lineBounds.minY
        )
        CTLineDraw(line, context)
    }

    private var normalizedStampName: String {
        let storedName = stampName ?? "Stamp"
        return storedName.hasPrefix("/") ? String(storedName.dropFirst()) : storedName
    }
}
