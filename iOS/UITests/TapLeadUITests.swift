import XCTest
final class TapLeadUITests:XCTestCase {
    func testDemoConnectionWorkflow(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();XCTAssertTrue(app.staticTexts["Demo · sample connections"].exists);app.tabBars.buttons["Connections"].tap();app.searchFields.firstMatch.tap();app.searchFields.firstMatch.typeText("Sarah");XCTAssertTrue(app.staticTexts["Sarah Chen"].exists)}
    func testUnpublishedQRDoesNotPretendToBeLive(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();app.buttons["Share my card"].tap();XCTAssertTrue(app.staticTexts["Publish your card to share a live QR"].waitForExistence(timeout:3))}
    func testScreenshotStates(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();for tab in ["Today","My card","Connections","Insights"]{app.tabBars.buttons[tab].tap();let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="TapLead-demo-\(tab)";attachment.lifetime = .keepAlways;add(attachment)}}
}
