import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@objc(PDFWorkspaceDocument)
final class PDFWorkspaceDocument: NSDocument {
    let session = PDFDocumentSession()
    nonisolated(unsafe) private var documentStorage: PDFDocument?
    nonisolated(unsafe) private var originalFileData: Data?
    private let exportService = PDFExportService()

    override init() {
        super.init()
        hasUndoManager = true
        session.configureEditing(undoManager: undoManager)
    }

    override class var autosavesInPlace: Bool {
        false
    }

    override func makeWindowControllers() {
        if let documentStorage {
            session.replaceDocument(documentStorage)
        }
        session.title = session.hasDocument ? displayName : "No PDF open"

        let rootView = WorkspaceRootView(
            session: session,
            saveDocument: { [weak self] in
                self?.saveFromRibbon()
            },
            saveDocumentCopy: { [weak self] in
                self?.saveCopyFromRibbon()
            },
            exportDocument: { [weak self] options in
                self?.export(options)
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = session.hasDocument ? displayName : "Formic"
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 1_240, height: 820))
        window.minSize = NSSize(width: 900, height: 620)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.center()

        addWindowController(NSWindowController(window: window))
    }

    func saveFromRibbon(
        requiresConfirmation: Bool = true,
        completionHandler: ((Error?) -> Void)? = nil
    ) {
        guard isDocumentEdited else {
            session.cancelSaving()
            completionHandler?(nil)
            return
        }

        guard let fileURL else {
            session.cancelSaving()
            saveAs(nil)
            return
        }

        guard requiresConfirmation else {
            performSave(to: fileURL, completionHandler: completionHandler)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes to \(displayName ?? "this PDF")?"
        alert.informativeText = "This replaces the PDF on disk. Use Save a Copy if you want to keep the current file unchanged."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        present(alert) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                self?.session.cancelSaving()
                return
            }
            self?.performSave(to: fileURL, completionHandler: completionHandler)
        }
    }

    private func performSave(
        to fileURL: URL,
        completionHandler: ((Error?) -> Void)?
    ) {
        session.beginSaving()

        save(
            to: fileURL,
            ofType: fileType ?? "com.adobe.pdf",
            for: .saveOperation
        ) { [weak self] error in
            if error == nil {
                if let self,
                   let fileURL = self.fileURL,
                   let savedData = try? Data(contentsOf: fileURL) {
                    self.originalFileData = savedData
                }
                self?.updateChangeCount(.changeCleared)
            }
            self?.session.finishSaving(with: error)

            if let error {
                self?.presentError(error)
            }

            completionHandler?(error)
        }
    }

    func saveCopyFromRibbon() {
        do {
            let artifact = PDFExportArtifact(
                suggestedFilename: suggestedCopyFilename,
                data: try currentPDFDataForExport()
            )
            presentSavePanel(
                for: artifact,
                contentType: .pdf,
                title: "Save a Copy",
                prompt: "Save Copy"
            )
        } catch {
            presentError(error)
        }
    }

    func showExportOptions() {
        session.showsExportSheet = true
    }

    func export(_ options: PDFExportOptions) {
        do {
            guard let documentStorage else {
                throw PDFWorkspaceError.unwritableDocument
            }

            let artifacts = try exportService.artifacts(
                for: options,
                document: documentStorage,
                sourcePDFData: currentPDFDataForExport(),
                baseFilename: displayName,
                currentPageIndex: session.currentPageIndex
            )

            if artifacts.count == 1, let artifact = artifacts.first {
                presentSavePanel(
                    for: artifact,
                    contentType: contentType(for: options.format),
                    title: "Export \(options.format.displayName)",
                    prompt: "Export"
                )
            } else {
                presentFolderPanel(for: artifacts)
            }
        } catch {
            presentError(error)
        }
    }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        session.setHasUnsavedChanges(isDocumentEdited)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFWorkspaceError.unreadableDocument
        }

        documentStorage = pdfDocument
        originalFileData = data
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = documentStorage?.dataRepresentation() else {
            throw PDFWorkspaceError.unwritableDocument
        }

        return data
    }

    private var suggestedCopyFilename: String {
        let stem = (displayName as NSString).deletingPathExtension
        return "\(stem)-copy.pdf"
    }

    private func currentPDFDataForExport() throws -> Data {
        if !isDocumentEdited, let originalFileData {
            return originalFileData
        }

        guard let data = documentStorage?.dataRepresentation() else {
            throw PDFWorkspaceError.unwritableDocument
        }
        return data
    }

    private func contentType(for format: PDFExportFormat) -> UTType {
        switch format {
        case .pdf:
            return .pdf
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .tiff:
            return .tiff
        case .plainText:
            return .plainText
        }
    }

    private func presentSavePanel(
        for artifact: PDFExportArtifact,
        contentType: UTType,
        title: String,
        prompt: String
    ) {
        let panel = NSSavePanel()
        panel.title = title
        panel.message = "The open PDF will remain unchanged."
        panel.prompt = prompt
        panel.nameFieldStringValue = artifact.suggestedFilename
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        present(panel) { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }

            do {
                try artifact.data.write(to: destination, options: .atomic)
            } catch {
                self?.presentError(error)
            }
        }
    }

    private func presentFolderPanel(for artifacts: [PDFExportArtifact]) {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.message = "Formic will create \(artifacts.count) numbered image files. The open PDF will remain unchanged."
        panel.prompt = "Export Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        present(panel) { [weak self] response in
            guard response == .OK, let directory = panel.url else { return }
            self?.write(artifacts, to: directory)
        }
    }

    private func write(_ artifacts: [PDFExportArtifact], to directory: URL) {
        let destinations = artifacts.map { directory.appendingPathComponent($0.suggestedFilename) }
        let collisionCount = destinations.filter { FileManager.default.fileExists(atPath: $0.path) }.count

        guard collisionCount > 0 else {
            write(artifacts, to: destinations)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = collisionCount == 1
            ? "Replace the existing export?"
            : "Replace \(collisionCount) existing exports?"
        alert.informativeText = "Only files with matching export names will be replaced. The open PDF will remain unchanged."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        present(alert) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.write(artifacts, to: destinations)
        }
    }

    private func write(_ artifacts: [PDFExportArtifact], to destinations: [URL]) {
        do {
            for (artifact, destination) in zip(artifacts, destinations) {
                try artifact.data.write(to: destination, options: .atomic)
            }
        } catch {
            presentError(error)
        }
    }

    private func present(_ panel: NSSavePanel, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = windowControllers.first?.window {
            panel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            completionHandler(panel.runModal())
        }
    }

    private func present(_ alert: NSAlert, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = windowControllers.first?.window {
            alert.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            completionHandler(alert.runModal())
        }
    }
}

enum PDFWorkspaceError: LocalizedError {
    case unreadableDocument
    case unwritableDocument

    var errorDescription: String? {
        switch self {
        case .unreadableDocument:
            return "Formic could not read this PDF. It may be damaged, encrypted, or unsupported."
        case .unwritableDocument:
            return "Formic could not create a safe PDF representation for saving."
        }
    }
}
