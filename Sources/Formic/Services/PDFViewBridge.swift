import PDFKit

final class PDFViewBridge {
    private weak var pdfView: PDFView?

    func attach(_ pdfView: PDFView) {
        self.pdfView = pdfView
    }

    func detach(_ pdfView: PDFView) {
        guard self.pdfView === pdfView else { return }
        self.pdfView = nil
    }

    func go(to page: PDFPage) {
        pdfView?.go(to: page)
    }

    func go(to selection: PDFSelection) {
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.go(to: selection)
    }

    var currentTextSelection: PDFSelection? {
        guard let selection = pdfView?.currentSelection,
              let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }

        return selection
    }

    func clearSelection() {
        pdfView?.clearSelection()
    }

    func zoomIn() {
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
    }

    func zoomToFit() {
        guard let pdfView else { return }
        pdfView.autoScales = true
    }
}
