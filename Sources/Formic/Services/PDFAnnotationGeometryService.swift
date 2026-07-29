import AppKit

struct PDFAnnotationGeometryService {
    func clampedBounds(_ bounds: NSRect, inside pageBounds: NSRect) -> NSRect {
        let maximumX = max(pageBounds.minX, pageBounds.maxX - bounds.width)
        let maximumY = max(pageBounds.minY, pageBounds.maxY - bounds.height)

        return NSRect(
            x: min(max(bounds.minX, pageBounds.minX), maximumX),
            y: min(max(bounds.minY, pageBounds.minY), maximumY),
            width: bounds.width,
            height: bounds.height
        )
    }
}
