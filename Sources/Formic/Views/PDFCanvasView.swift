import PDFKit
import SwiftUI

struct PDFCanvasView: NSViewRepresentable {
    @ObservedObject var session: PDFDocumentSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = AnnotationEditingPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = .formicCanvas
        pdfView.document = session.document
        pdfView.onAnnotationSelection = { [weak session] annotation in
            session?.selectAnnotation(annotation)
        }
        pdfView.onNotePlacement = { [weak session] page, point in
            session?.placeNote(on: page, at: point)
        }
        pdfView.onAnnotationMoveBegan = { [weak session] annotation, page in
            session?.beginMovingSelectedAnnotation(annotation, on: page)
        }
        pdfView.onAnnotationMoveChanged = { [weak session] bounds in
            session?.previewSelectedAnnotationMove(to: bounds)
        }
        pdfView.onAnnotationMoveEnded = { [weak session] in
            session?.finishMovingSelectedAnnotation()
        }
        pdfView.isPlacingNote = session.annotationTool == .note
        pdfView.selectedAnnotation = session.selectedPDFAnnotation
        pdfView.canMoveSelectedAnnotation = session.annotationSelection?.canMove == true

        context.coordinator.attach(to: pdfView)
        session.viewBridge.attach(pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== session.document {
            pdfView.document = session.document
            pdfView.autoScales = true
        }

        if let pdfView = pdfView as? AnnotationEditingPDFView {
            pdfView.isPlacingNote = session.annotationTool == .note
            pdfView.selectedAnnotation = session.selectedPDFAnnotation
            pdfView.canMoveSelectedAnnotation = session.annotationSelection?.canMove == true
        }
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.detach()
        coordinator.session.viewBridge.detach(pdfView)
    }

    final class Coordinator: NSObject {
        let session: PDFDocumentSession
        private weak var pdfView: PDFView?
        private var observers: [NSObjectProtocol] = []

        init(session: PDFDocumentSession) {
            self.session = session
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .PDFViewPageChanged,
                    object: pdfView,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    self.session.setCurrentPage(self.pdfView?.currentPage)
                }
            )

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .PDFViewSelectionChanged,
                    object: pdfView,
                    queue: .main
                ) { [weak self] _ in
                    self?.session.syncTextSelection()
                }
            )
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            pdfView = nil
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}

private final class AnnotationEditingPDFView: PDFView {
    var onAnnotationSelection: ((PDFAnnotation?) -> Void)?
    var onNotePlacement: ((PDFPage, NSPoint) -> Void)?
    var onAnnotationMoveBegan: ((PDFAnnotation, PDFPage) -> NSRect?)?
    var onAnnotationMoveChanged: ((NSRect) -> NSRect?)?
    var onAnnotationMoveEnded: (() -> Void)?
    var selectedAnnotation: PDFAnnotation? {
        didSet { refreshSelectionOverlay() }
    }
    var canMoveSelectedAnnotation = false {
        didSet {
            refreshSelectionOverlay()
            window?.invalidateCursorRects(for: self)
        }
    }
    var isPlacingNote = false {
        didSet {
            guard oldValue != isPlacingNote else { return }
            window?.invalidateCursorRects(for: self)
        }
    }

    private let selectionOverlay = AnnotationSelectionOverlayView()
    private var annotationDrag: AnnotationDrag?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installSelectionOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installSelectionOverlay()
    }

    override func layout() {
        super.layout()
        selectionOverlay.frame = bounds
        refreshSelectionOverlay()
    }

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            if !isPlacingNote {
                onAnnotationSelection?(nil)
                super.mouseDown(with: event)
            }
            return
        }
        let pagePoint = convert(viewPoint, to: page)

        if isPlacingNote {
            onNotePlacement?(page, pagePoint)
            return
        }

        let annotation = page.annotation(at: pagePoint)
        onAnnotationSelection?(annotation)

        if let annotation,
           let originalBounds = onAnnotationMoveBegan?(annotation, page) {
            annotationDrag = AnnotationDrag(
                page: page,
                originalBounds: originalBounds,
                startingPagePoint: pagePoint,
                startingViewPoint: viewPoint
            )
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var annotationDrag else {
            super.mouseDragged(with: event)
            return
        }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let viewDistance = hypot(
            viewPoint.x - annotationDrag.startingViewPoint.x,
            viewPoint.y - annotationDrag.startingViewPoint.y
        )
        guard annotationDrag.didMove || viewDistance >= 3 else { return }

        annotationDrag.didMove = true
        self.annotationDrag = annotationDrag

        let pagePoint = convert(viewPoint, to: annotationDrag.page)
        let proposedBounds = annotationDrag.originalBounds.offsetBy(
            dx: pagePoint.x - annotationDrag.startingPagePoint.x,
            dy: pagePoint.y - annotationDrag.startingPagePoint.y
        )
        if onAnnotationMoveChanged?(proposedBounds) != nil {
            refreshSelectionOverlay()
        }
        NSCursor.closedHand.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard annotationDrag != nil else {
            super.mouseUp(with: event)
            return
        }

        annotationDrag = nil
        onAnnotationMoveEnded?()
        refreshSelectionOverlay()
        window?.invalidateCursorRects(for: self)
        NSCursor.openHand.set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isPlacingNote {
            addCursorRect(bounds, cursor: .crosshair)
        } else if canMoveSelectedAnnotation,
                  !selectionOverlay.selectionRect.isEmpty {
            addCursorRect(selectionOverlay.selectionRect, cursor: .openHand)
        }
    }

    private func installSelectionOverlay() {
        selectionOverlay.frame = bounds
        selectionOverlay.autoresizingMask = [.width, .height]
        addSubview(selectionOverlay, positioned: .above, relativeTo: nil)
    }

    private func refreshSelectionOverlay() {
        guard let selectedAnnotation,
              let page = selectedAnnotation.page
        else {
            selectionOverlay.selectionRect = .zero
            return
        }

        selectionOverlay.selectionRect = convert(selectedAnnotation.bounds, from: page)
        selectionOverlay.showsResizeHandles = false
        window?.invalidateCursorRects(for: self)
    }
}

private struct AnnotationDrag {
    let page: PDFPage
    let originalBounds: NSRect
    let startingPagePoint: NSPoint
    let startingViewPoint: NSPoint
    var didMove = false
}

private final class AnnotationSelectionOverlayView: NSView {
    var selectionRect: NSRect = .zero {
        didSet { needsDisplay = true }
    }
    var showsResizeHandles = false {
        didSet { needsDisplay = true }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !selectionRect.isEmpty else { return }

        let accent = NSColor(calibratedRed: 0.96, green: 0.32, blue: 0.14, alpha: 1)
        let outline = NSBezierPath(roundedRect: selectionRect.insetBy(dx: -3, dy: -3), xRadius: 3, yRadius: 3)
        outline.lineWidth = 2
        accent.setStroke()
        outline.stroke()

        guard showsResizeHandles else { return }
        for point in handlePoints(for: selectionRect) {
            let handleRect = NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            accent.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
        }
    }

    private func handlePoints(for rect: NSRect) -> [NSPoint] {
        [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.maxY)
        ]
    }
}

private extension NSColor {
    static let formicCanvas = NSColor(name: "FormicCanvas") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        }

        return NSColor(calibratedRed: 0.83, green: 0.84, blue: 0.86, alpha: 1)
    }
}
