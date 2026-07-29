import AppKit
import PDFKit
import SwiftUI

@MainActor
@objc(PDFWorkspaceDocument)
final class PDFWorkspaceDocument: NSDocument {
    let session = PDFDocumentSession()
    nonisolated(unsafe) private var documentStorage: PDFDocument?

    override init() {
        super.init()
        hasUndoManager = true
    }

    override class var autosavesInPlace: Bool {
        true
    }

    override func makeWindowControllers() {
        if let documentStorage {
            session.replaceDocument(documentStorage)
        }
        session.title = displayName

        let rootView = WorkspaceRootView(
            session: session,
            saveDocument: { [weak self] in
                self?.saveFromRibbon()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = displayName
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 1_240, height: 820))
        window.minSize = NSSize(width: 900, height: 620)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.center()

        addWindowController(NSWindowController(window: window))
    }

    func saveFromRibbon(completionHandler: ((Error?) -> Void)? = nil) {
        session.beginSaving()

        guard let fileURL else {
            session.cancelSaving()
            saveAs(nil)
            return
        }

        save(
            to: fileURL,
            ofType: fileType ?? "com.adobe.pdf",
            for: .saveOperation
        ) { [weak self] error in
            self?.session.finishSaving(with: error)

            if let error {
                self?.presentError(error)
            }

            completionHandler?(error)
        }
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFWorkspaceError.unreadableDocument
        }

        documentStorage = pdfDocument
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = documentStorage?.dataRepresentation() else {
            throw PDFWorkspaceError.unwritableDocument
        }

        return data
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
