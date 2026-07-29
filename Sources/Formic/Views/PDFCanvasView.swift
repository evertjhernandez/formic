import PDFKit
import SwiftUI

struct PDFCanvasView: NSViewRepresentable {
    @ObservedObject var session: PDFDocumentSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = .formicCanvas
        pdfView.document = session.document

        context.coordinator.attach(to: pdfView)
        session.viewBridge.attach(pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== session.document {
            pdfView.document = session.document
            pdfView.autoScales = true
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

private extension NSColor {
    static let formicCanvas = NSColor(name: "FormicCanvas") { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        }

        return NSColor(calibratedRed: 0.83, green: 0.84, blue: 0.86, alpha: 1)
    }
}
