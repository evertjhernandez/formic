import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            guard NSDocumentController.shared.documents.isEmpty else { return }
            NSDocumentController.shared.openDocument(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
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

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveCurrentDocument(_:)):
            return currentPDFDocument?.isDocumentEdited == true
        case #selector(saveCurrentDocumentAsCopy(_:)), #selector(exportCurrentDocument(_:)):
            return currentPDFDocument != nil
        default:
            return true
        }
    }

    private var currentPDFDocument: PDFWorkspaceDocument? {
        NSDocumentController.shared.currentDocument as? PDFWorkspaceDocument
    }
}
