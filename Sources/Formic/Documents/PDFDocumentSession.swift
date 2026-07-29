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
    @Published private(set) var saveState: DocumentSaveState = .idle
    @Published private(set) var hasUnsavedChanges = false
    @Published var showsExportSheet = false
    @Published private(set) var hasTextSelection = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var annotationSelection: AnnotationSelection?
    @Published private(set) var annotationTool: AnnotationTool = .selection

    let viewBridge = PDFViewBridge()
    private let markupService = PDFTextMarkupService()
    private let noteService = PDFNoteService()
    private let geometryService = PDFAnnotationGeometryService()
    private var saveStateResetWorkItem: DispatchWorkItem?
    private weak var undoManager: UndoManager?
    private var onDocumentChange: ((NSDocument.ChangeType) -> Void)?
    private var undoObservers: [NSObjectProtocol] = []
    private weak var selectedAnnotation: PDFAnnotation?
    private weak var selectedAnnotationPage: PDFPage?
    private var annotationMove: AnnotationMove?

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

    var allowsCommenting: Bool {
        document?.allowsCommenting ?? false
    }

    var canApplyTextMarkup: Bool {
        hasTextSelection && allowsCommenting
    }

    var hasSelectedAnnotation: Bool {
        annotationSelection != nil
    }

    var selectedPDFAnnotation: PDFAnnotation? {
        selectedAnnotation
    }

    func replaceDocument(_ document: PDFDocument) {
        saveStateResetWorkItem?.cancel()
        selectedAnnotation?.isHighlighted = false
        selectedAnnotation = nil
        selectedAnnotationPage = nil
        annotationMove = nil
        annotationSelection = nil
        annotationTool = .selection
        self.document = document
        currentPageIndex = 0
        searchQuery = ""
        searchResults = []
        selectedSearchResultIndex = nil
        saveState = .idle
        hasUnsavedChanges = false
        showsExportSheet = false
        hasTextSelection = false
        refreshUndoAvailability()
    }

    func configureEditing(
        undoManager: UndoManager?,
        onDocumentChange: ((NSDocument.ChangeType) -> Void)? = nil
    ) {
        removeUndoObservers()
        self.undoManager = undoManager
        self.onDocumentChange = onDocumentChange

        guard let undoManager else {
            refreshUndoAvailability()
            return
        }

        undoManager.groupsByEvent = false

        let notifications: [Notification.Name] = [
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
            .NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerCheckpoint
        ]
        undoObservers = notifications.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: undoManager,
                queue: .main
            ) { [weak self] _ in
                self?.refreshUndoAvailability()
            }
        }
        refreshUndoAvailability()
    }

    func setHasUnsavedChanges(_ hasUnsavedChanges: Bool) {
        self.hasUnsavedChanges = hasUnsavedChanges
    }

    func syncTextSelection() {
        hasTextSelection = viewBridge.currentTextSelection != nil
        if hasTextSelection {
            annotationTool = .selection
            selectAnnotation(nil)
        }
    }

    func selectAnnotation(_ annotation: PDFAnnotation?) {
        guard selectedAnnotation !== annotation else { return }

        selectedAnnotation?.isHighlighted = false
        selectedAnnotation = annotation
        selectedAnnotationPage = annotation?.page
        annotation?.isHighlighted = true

        if annotation != nil {
            annotationTool = .selection
            viewBridge.clearSelection()
            hasTextSelection = false
        }

        refreshAnnotationSelection()
        viewBridge.refresh()
    }

    @discardableResult
    func applyTextMarkup(_ style: TextMarkupStyle) -> Int {
        guard allowsCommenting,
              let selection = viewBridge.currentTextSelection
        else {
            syncTextSelection()
            return 0
        }

        let records = markupService.records(for: selection, style: style)
        guard !records.isEmpty else { return 0 }

        setMarkup(records, isAdded: true, actionName: style.actionName)
        viewBridge.clearSelection()
        hasTextSelection = false
        selectAnnotation(records.first?.annotation)
        return records.count
    }

    func activateNoteTool() {
        guard allowsCommenting else { return }
        annotationTool = .note
        selectAnnotation(nil)
        viewBridge.clearSelection()
        hasTextSelection = false
    }

    func toggleNoteTool() {
        if annotationTool == .note {
            annotationTool = .selection
        } else {
            activateNoteTool()
        }
    }

    func placeNote(on page: PDFPage, at point: NSPoint) {
        guard annotationTool == .note,
              allowsCommenting,
              let document,
              document.index(for: page) != NSNotFound
        else { return }

        annotationTool = .selection
        let annotation = noteService.annotation(on: page, at: point)
        setAnnotation(
            annotation,
            on: page,
            isPresent: true,
            actionName: "Add Note"
        )
    }

    func setSelectedAnnotationColor(_ color: NSColor) {
        guard let annotation = selectedAnnotation,
              let page = selectedAnnotationPage,
              annotationSelection?.canEditAppearance == true
        else { return }

        let updatedColor = color.withAlphaComponent(annotation.color.alphaComponent)
        guard !updatedColor.withAlphaComponent(1).isEqual(annotation.color.withAlphaComponent(1)) else { return }
        setAnnotationColor(
            updatedColor,
            for: annotation,
            on: page,
            actionName: "Change Annotation Color"
        )
    }

    func updateSelectedNote(contents: String, author: String) {
        guard let annotation = selectedAnnotation,
              let page = selectedAnnotationPage,
              annotationSelection?.canEditText == true
        else { return }

        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedAuthor = trimmedAuthor.isEmpty ? nil : trimmedAuthor
        let updatedContents = contents.isEmpty ? nil : contents

        guard annotation.contents != updatedContents || annotation.userName != updatedAuthor else { return }
        setAnnotationText(
            contents: updatedContents,
            author: updatedAuthor,
            for: annotation,
            on: page
        )
    }

    func beginMovingSelectedAnnotation(
        _ annotation: PDFAnnotation,
        on page: PDFPage
    ) -> NSRect? {
        guard annotation === selectedAnnotation,
              page === selectedAnnotationPage,
              annotationSelection?.canMove == true,
              page.annotations.contains(where: { $0 === annotation })
        else { return nil }

        let bounds = annotation.bounds
        annotationMove = AnnotationMove(
            annotation: annotation,
            page: page,
            originalBounds: bounds
        )
        return bounds
    }

    @discardableResult
    func previewSelectedAnnotationMove(to proposedBounds: NSRect) -> NSRect? {
        guard let annotationMove else { return nil }

        let pageBounds = annotationMove.page.bounds(for: .cropBox)
        let updatedBounds = geometryService.clampedBounds(proposedBounds, inside: pageBounds)
        annotationMove.annotation.bounds = updatedBounds
        refreshAnnotationSelection()
        viewBridge.refresh()
        return updatedBounds
    }

    func finishMovingSelectedAnnotation() {
        guard let annotationMove else { return }
        self.annotationMove = nil

        let updatedBounds = annotationMove.annotation.bounds
        guard updatedBounds != annotationMove.originalBounds else { return }

        annotationMove.annotation.modificationDate = Date()
        registerUndo(actionName: "Move Annotation") { session in
            session.setAnnotationBounds(
                annotationMove.originalBounds,
                for: annotationMove.annotation,
                on: annotationMove.page,
                actionName: "Move Annotation"
            )
        }
        publishDocumentChange()
        refreshAnnotationSelection()
        viewBridge.refresh()
    }

    func deleteSelectedAnnotation() {
        guard let annotation = selectedAnnotation,
              let page = selectedAnnotationPage,
              annotationSelection?.canDelete == true
        else { return }

        setAnnotation(
            annotation,
            on: page,
            isPresent: false,
            actionName: "Delete Annotation"
        )
    }

    func undo() {
        guard undoManager?.canUndo == true else { return }
        undoManager?.undo()
        refreshUndoAvailability()
    }

    func redo() {
        guard undoManager?.canRedo == true else { return }
        undoManager?.redo()
        refreshUndoAvailability()
    }

    func beginSaving() {
        saveStateResetWorkItem?.cancel()
        saveState = .saving
    }

    func finishSaving(with error: Error?) {
        saveState = error == nil ? .saved : .failed

        let resetWorkItem = DispatchWorkItem { [weak self] in
            self?.saveState = .idle
        }
        saveStateResetWorkItem = resetWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: resetWorkItem)
    }

    func cancelSaving() {
        saveStateResetWorkItem?.cancel()
        saveState = .idle
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

    private func setMarkup(
        _ records: [PDFMarkupRecord],
        isAdded: Bool,
        actionName: String
    ) {
        for record in records {
            if isAdded {
                record.page.addAnnotation(record.annotation)
            } else {
                record.page.removeAnnotation(record.annotation)
            }
        }

        if let undoManager {
            let createsUndoGroup = !undoManager.isUndoing && !undoManager.isRedoing
            if createsUndoGroup {
                undoManager.beginUndoGrouping()
            }
            undoManager.registerUndo(withTarget: self) { session in
                session.setMarkup(records, isAdded: !isAdded, actionName: actionName)
            }
            undoManager.setActionName(actionName)
            if createsUndoGroup {
                undoManager.endUndoGrouping()
            }
        }

        let changeType: NSDocument.ChangeType
        if undoManager?.isUndoing == true {
            changeType = .changeUndone
        } else if undoManager?.isRedoing == true {
            changeType = .changeRedone
        } else {
            changeType = .changeDone
        }
        onDocumentChange?(changeType)
        refreshUndoAvailability()

        if !isAdded, records.contains(where: { $0.annotation === selectedAnnotation }) {
            selectAnnotation(nil)
        }

        DispatchQueue.main.async { [weak self] in
            self?.refreshUndoAvailability()
        }
    }

    private func setAnnotationColor(
        _ color: NSColor,
        for annotation: PDFAnnotation,
        on page: PDFPage,
        actionName: String
    ) {
        let previousColor = annotation.color
        annotation.color = color
        annotation.modificationDate = Date()

        registerUndo(actionName: actionName) { session in
            session.setAnnotationColor(
                previousColor,
                for: annotation,
                on: page,
                actionName: actionName
            )
        }

        publishDocumentChange()
        if annotation === selectedAnnotation {
            refreshAnnotationSelection()
        }
        viewBridge.refresh()
    }

    private func setAnnotationText(
        contents: String?,
        author: String?,
        for annotation: PDFAnnotation,
        on page: PDFPage
    ) {
        let previousContents = annotation.contents
        let previousAuthor = annotation.userName
        annotation.contents = contents
        annotation.userName = author
        annotation.modificationDate = Date()

        registerUndo(actionName: "Edit Note") { session in
            session.setAnnotationText(
                contents: previousContents,
                author: previousAuthor,
                for: annotation,
                on: page
            )
        }

        publishDocumentChange()
        if annotation === selectedAnnotation {
            refreshAnnotationSelection()
        }
        viewBridge.refresh()
    }

    private func setAnnotationBounds(
        _ bounds: NSRect,
        for annotation: PDFAnnotation,
        on page: PDFPage,
        actionName: String
    ) {
        let previousBounds = annotation.bounds
        annotation.bounds = geometryService.clampedBounds(
            bounds,
            inside: page.bounds(for: .cropBox)
        )
        annotation.modificationDate = Date()

        registerUndo(actionName: actionName) { session in
            session.setAnnotationBounds(
                previousBounds,
                for: annotation,
                on: page,
                actionName: actionName
            )
        }

        publishDocumentChange()
        if annotation === selectedAnnotation {
            refreshAnnotationSelection()
        }
        viewBridge.refresh()
    }

    private func setAnnotation(
        _ annotation: PDFAnnotation,
        on page: PDFPage,
        isPresent: Bool,
        actionName: String
    ) {
        if isPresent {
            page.addAnnotation(annotation)
            selectAnnotation(annotation)
        } else {
            if annotation === selectedAnnotation {
                selectAnnotation(nil)
            }
            page.removeAnnotation(annotation)
        }

        registerUndo(actionName: actionName) { session in
            session.setAnnotation(
                annotation,
                on: page,
                isPresent: !isPresent,
                actionName: actionName
            )
        }
        publishDocumentChange()
        viewBridge.refresh()
    }

    private func registerUndo(
        actionName: String,
        operation: @escaping (PDFDocumentSession) -> Void
    ) {
        guard let undoManager else { return }
        let createsUndoGroup = !undoManager.isUndoing && !undoManager.isRedoing
        if createsUndoGroup {
            undoManager.beginUndoGrouping()
        }
        undoManager.registerUndo(withTarget: self, handler: operation)
        undoManager.setActionName(actionName)
        if createsUndoGroup {
            undoManager.endUndoGrouping()
        }
    }

    private func publishDocumentChange() {
        let changeType: NSDocument.ChangeType
        if undoManager?.isUndoing == true {
            changeType = .changeUndone
        } else if undoManager?.isRedoing == true {
            changeType = .changeRedone
        } else {
            changeType = .changeDone
        }

        onDocumentChange?(changeType)
        refreshUndoAvailability()
        DispatchQueue.main.async { [weak self] in
            self?.refreshUndoAvailability()
        }
    }

    private func refreshAnnotationSelection() {
        guard let annotation = selectedAnnotation,
              let page = selectedAnnotationPage,
              let document,
              page.annotations.contains(where: { $0 === annotation })
        else {
            selectedAnnotation = nil
            selectedAnnotationPage = nil
            annotationSelection = nil
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else {
            annotation.isHighlighted = false
            selectedAnnotation = nil
            selectedAnnotationPage = nil
            annotationSelection = nil
            return
        }

        annotationSelection = AnnotationSelection(
            annotation: annotation,
            pageNumber: pageIndex + 1,
            allowsCommenting: allowsCommenting
        )
    }

    private func refreshUndoAvailability() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }

    private func removeUndoObservers() {
        undoObservers.forEach(NotificationCenter.default.removeObserver)
        undoObservers.removeAll()
    }

    deinit {
        removeUndoObservers()
    }
}

private struct AnnotationMove {
    let annotation: PDFAnnotation
    let page: PDFPage
    let originalBounds: NSRect
}
