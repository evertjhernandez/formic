import AppKit

@MainActor
enum MainMenu {
    static func install(settingsTarget: AnyObject) {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        addApplicationMenu(to: mainMenu, settingsTarget: settingsTarget)
        addFileMenu(to: mainMenu)
        addEditMenu(to: mainMenu)
        addWindowMenu(to: mainMenu)
        addHelpMenu(to: mainMenu)
    }

    private static func addApplicationMenu(to mainMenu: NSMenu, settingsTarget: AnyObject) {
        let item = NSMenuItem()
        mainMenu.addItem(item)

        let menu = NSMenu()
        item.submenu = menu
        menu.addItem(withTitle: "About Formic", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        let settings = menu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        settings.target = settingsTarget

        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Formic", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        let hideOthers = menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Formic", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private static func addFileMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem()
        mainMenu.addItem(item)

        let menu = NSMenu(title: "File")
        item.submenu = menu

        let open = menu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        open.target = NSDocumentController.shared

        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")

        let saveAs = menu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(.separator())
        menu.addItem(withTitle: "Print…", action: #selector(NSDocument.printDocument(_:)), keyEquivalent: "p")
    }

    private static func addEditMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem()
        mainMenu.addItem(item)

        let menu = NSMenu(title: "Edit")
        item.submenu = menu
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")

        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    }

    private static func addWindowMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem()
        mainMenu.addItem(item)

        let menu = NSMenu(title: "Window")
        item.submenu = menu
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = menu
    }

    private static func addHelpMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem()
        mainMenu.addItem(item)

        let menu = NSMenu(title: "Help")
        item.submenu = menu
        NSApp.helpMenu = menu
    }
}
