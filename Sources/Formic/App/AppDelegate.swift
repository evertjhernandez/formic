import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let firstPath = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        let url = URL(fileURLWithPath: firstPath)
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            sender.reply(toOpenOrPrint: error == nil ? .success : .failure)
        }
    }

    @objc
    func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Formic Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 480, height: 300))
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func saveCurrentDocument(_ sender: Any?) {
        currentPDFDocument?.saveFromRibbon()
    }

    @objc
    func saveCurrentDocumentAsCopy(_ sender: Any?) {
        currentPDFDocument?.saveCopyFromRibbon()
    }

    @objc
    func exportCurrentDocument(_ sender: Any?) {
        currentPDFDocument?.showExportOptions()
    }

    @objc
    func highlightSelection(_ sender: Any?) {
        currentPDFDocument?.session.applyTextMarkup(.highlight)
    }

    @objc
    func underlineSelection(_ sender: Any?) {
        currentPDFDocument?.session.applyTextMarkup(.underline)
    }

    @objc
    func strikeOutSelection(_ sender: Any?) {
        currentPDFDocument?.session.applyTextMarkup(.strikeOut)
    }

    @objc
    func activateNoteTool(_ sender: Any?) {
        currentPDFDocument?.session.activateNoteTool()
    }

    @objc
    func activateFreeTextTool(_ sender: Any?) {
        currentPDFDocument?.session.activateFreeTextTool()
    }

    @objc
    func deleteSelectedAnnotation(_ sender: Any?) {
        currentPDFDocument?.session.deleteSelectedAnnotation()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveCurrentDocument(_:)):
            return currentPDFDocument?.isDocumentEdited == true
        case #selector(saveCurrentDocumentAsCopy(_:)), #selector(exportCurrentDocument(_:)):
            return currentPDFDocument?.session.hasDocument == true
        case #selector(highlightSelection(_:)),
             #selector(underlineSelection(_:)),
             #selector(strikeOutSelection(_:)):
            return currentPDFDocument?.session.canApplyTextMarkup == true
        case #selector(activateNoteTool(_:)), #selector(activateFreeTextTool(_:)):
            return currentPDFDocument?.session.allowsCommenting == true
        case #selector(deleteSelectedAnnotation(_:)):
            return currentPDFDocument?.session.annotationSelection?.canDelete == true
        default:
            return true
        }
    }

    private var currentPDFDocument: PDFWorkspaceDocument? {
        NSDocumentController.shared.currentDocument as? PDFWorkspaceDocument
    }
}
