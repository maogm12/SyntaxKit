import XCTest
import SyntaxKit
@testable import SyntaxKitIOSDemo

@MainActor
final class SyntaxKitIOSDemoTests: XCTestCase {
    func testDemoModelInitialization() async throws {
        let model = DemoModel()
        XCTAssertEqual(model.grammarName, "JSON")
        XCTAssertEqual(model.themeName, "Sample Dark")
    }
}
