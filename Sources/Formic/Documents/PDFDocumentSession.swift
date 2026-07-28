import AppKit
import PDFKit

final class PDFDocumentSession: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published var title = "Untitled PDF"
    @Published private(set) var currentPageIndex = 0
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [PDFSelection] = []
    @Published private(set) var selectedSearchResultIndex: Int?
    @Published var sidebarMode: SidebarMode = .thumbnails

    let viewBridge = PDFViewBridge()

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    var currentPageLabel: String {
        guard pageCount > 0 else { return "No pages" }
        return "Page \(currentPageIndex + 1) of \(pageCount)"
    }

    var isEncrypted: Bool {
        document?.isEncrypted ?? false
    }

    var allowsCopying: Bool {
        document?.allowsCopying ?? false
    }

    var allowsPrinting: Bool {
        document?.allowsPrinting ?? false
    }

    func replaceDocument(_ document: PDFDocument) {
        self.document = document
        currentPageIndex = 0
        searchQuery = ""
        searchResults = []
        selectedSearchResultIndex = nil
    }

    func setCurrentPage(_ page: PDFPage?) {
        guard let document, let page else { return }
        let index = document.index(for: page)
        guard index != NSNotFound, index != currentPageIndex else { return }
        currentPageIndex = index
    }

    func goToPage(at index: Int) {
        guard let document, document.pageCount > 0 else { return }
        let safeIndex = min(max(index, 0), document.pageCount - 1)
        currentPageIndex = safeIndex

        if let page = document.page(at: safeIndex) {
            viewBridge.go(to: page)
        }
    }

    func performSearch() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !trimmedQuery.isEmpty else {
            searchResults = []
            selectedSearchResultIndex = nil
            return
        }

        searchResults = document.findString(trimmedQuery, withOptions: [.caseInsensitive])
        selectedSearchResultIndex = searchResults.isEmpty ? nil : 0
        showSelectedSearchResult()
    }

    func showNextSearchResult() {
        guard !searchResults.isEmpty else { return }
        selectedSearchResultIndex = ((selectedSearchResultIndex ?? -1) + 1) % searchResults.count
        showSelectedSearchResult()
    }

    func showPreviousSearchResult() {
        guard !searchResults.isEmpty else { return }
        let current = selectedSearchResultIndex ?? 0
        selectedSearchResultIndex = (current - 1 + searchResults.count) % searchResults.count
        showSelectedSearchResult()
    }

    func zoomIn() {
        viewBridge.zoomIn()
    }

    func zoomOut() {
        viewBridge.zoomOut()
    }

    func zoomToFit() {
        viewBridge.zoomToFit()
    }

    private func showSelectedSearchResult() {
        guard let selectedSearchResultIndex,
              searchResults.indices.contains(selectedSearchResultIndex)
        else { return }

        viewBridge.go(to: searchResults[selectedSearchResultIndex])
    }
}
