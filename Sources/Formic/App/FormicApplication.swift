import AppKit

@main
enum FormicApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.regular)
        MainMenu.install(settingsTarget: delegate)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
