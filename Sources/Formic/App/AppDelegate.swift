import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
}
