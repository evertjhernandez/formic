import AppKit
import XCTest
@testable import Formic

@MainActor
final class AppDelegateTests: XCTestCase {
    func testApplicationOpensUntitledWorkspaceAtLaunch() {
        let delegate = AppDelegate()

        XCTAssertTrue(delegate.applicationShouldOpenUntitledFile(NSApplication.shared))
    }
}
