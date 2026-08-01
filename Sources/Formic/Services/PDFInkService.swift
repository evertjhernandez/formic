import AppKit
import PDFKit

struct PDFInkService {
    private let lineWidth: CGFloat = 3

    func annotation(on page: PDFPage, points: [NSPoint]) -> PDFAnnotation? {
        guard !points.isEmpty else { return nil }

        let pageBounds = page.bounds(for: .cropBox)
        var clampedPoints = points.map { point in
            NSPoint(
                x: min(max(point.x, pageBounds.minX), pageBounds.maxX),
                y: min(max(point.y, pageBounds.minY), pageBounds.maxY)
            )
        }
        if clampedPoints.count == 1 {
            let point = clampedPoints[0]
            clampedPoints.append(
                NSPoint(
                    x: point.x < pageBounds.maxX ? point.x + 0.5 : point.x - 0.5,
                    y: point.y < pageBounds.maxY ? point.y + 0.5 : point.y - 0.5
                )
            )
        }

        let minimumX = clampedPoints.map(\.x).min() ?? clampedPoints[0].x
        let maximumX = clampedPoints.map(\.x).max() ?? clampedPoints[0].x
        let minimumY = clampedPoints.map(\.y).min() ?? clampedPoints[0].y
        let maximumY = clampedPoints.map(\.y).max() ?? clampedPoints[0].y
        let strokeBounds = NSRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
        let padding = lineWidth + 2
        var annotationBounds = strokeBounds.insetBy(dx: -padding, dy: -padding)
            .intersection(pageBounds)
        annotationBounds.size.width = max(annotationBounds.width, lineWidth)
        annotationBounds.size.height = max(annotationBounds.height, lineWidth)

        let path = NSBezierPath()
        path.move(to: localPoint(clampedPoints[0], inside: annotationBounds))
        for point in clampedPoints.dropFirst() {
            path.line(to: localPoint(point, inside: annotationBounds))
        }

        let annotation = PDFAnnotation(
            bounds: annotationBounds,
            forType: .ink,
            withProperties: nil
        )
        annotation.add(path)
        annotation.color = .systemRed

        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border

        let author = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        annotation.userName = author.isEmpty ? nil : author
        return annotation
    }

    private func localPoint(_ point: NSPoint, inside bounds: NSRect) -> NSPoint {
        NSPoint(x: point.x - bounds.minX, y: point.y - bounds.minY)
    }
}
