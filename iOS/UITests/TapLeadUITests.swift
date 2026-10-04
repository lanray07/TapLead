import XCTest
final class TapLeadUITests:XCTestCase {
    func testCornerLogoImportPersistsAndCanBeRemoved() {
        let app=XCUIApplication();app.launchArguments=["--demo"];app.launch()
        app.tabBars.buttons["My card"].tap();app.buttons["Edit card"].tap()
        app.segmentedControls.buttons["Logo"].tap()
        app.buttons["Choose logo"].tap()
        let photo=app.cells.firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout:20),app.debugDescription)
        photo.tap()
        XCTAssertTrue(app.staticTexts["Logo added"].waitForExistence(timeout:20),app.debugDescription)
        app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Image corner")).firstMatch.tap()
        app.buttons["Bottom right"].tap()
        app.buttons["Save"].tap()
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="TapLead-corner-logo";capture.lifetime = .keepAlways;add(capture)
        app.terminate();app.launchArguments=[];app.launch()
        app.tabBars.buttons["My card"].tap();app.buttons["Edit card"].tap()
        XCTAssertTrue(app.staticTexts["Logo added"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Bottom right")).firstMatch.exists)
        app.buttons["Remove image"].tap();XCTAssertFalse(app.staticTexts["Logo added"].exists)
        app.buttons["Save"].tap();app.buttons["Edit card"].tap()
        XCTAssertFalse(app.staticTexts["Logo added"].exists)
        app.segmentedControls.buttons["None"].tap()
        XCTAssertFalse(app.buttons["Choose logo"].exists)
    }
    func testDemoConnectionWorkflow(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();XCTAssertTrue(app.staticTexts["Demo · sample connections"].exists);app.tabBars.buttons["Connections"].tap();app.searchFields.firstMatch.tap();app.searchFields.firstMatch.typeText("Sarah");XCTAssertTrue(app.staticTexts["Sarah Chen"].exists)}
    func testUnpublishedQRDoesNotPretendToBeLive(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();app.buttons["Share my card"].tap();XCTAssertTrue(app.staticTexts["Publish your card to share a live QR"].waitForExistence(timeout:3))}
    func testScreenshotStates(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();for tab in ["Today","My card","Connections","Insights"]{app.tabBars.buttons[tab].tap();let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="TapLead-demo-\(tab)";attachment.lifetime = .keepAlways;add(attachment)}}
    func testSubscriptionReviewScreenshot(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();app.tabBars.buttons["Settings"].tap();app.buttons["TapLead Pro"].tap();XCTAssertTrue(app.staticTexts["Multiple card personas"].waitForExistence(timeout:5));let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="TapLead-Pro-review-current-configuration";attachment.lifetime = .keepAlways;add(attachment)}
}
