import XCTest
final class TapLeadUITests:XCTestCase {
    func testSavedConnectionOffersImmediateActions() {
        let app=XCUIApplication();app.launchArguments=["--demo"];app.launch()
        app.tabBars.buttons["Connections"].tap();app.buttons["Add connection"].tap()
        let name=app.textFields["Name"];XCTAssertTrue(name.waitForExistence(timeout:5));name.tap();name.typeText("Nova Test")
        let consent=app.switches["They agreed to share these details"]
        for _ in 0..<5 {if consent.isHittable{break};app.swipeUp()}
        XCTAssertTrue(consent.isHittable,app.debugDescription);consent.tap();app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["A good start. What next?"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Send introduction"].exists)
        XCTAssertTrue(app.buttons["Book follow-up"].exists)
        XCTAssertTrue(app.buttons["Add reminder"].exists)
        XCTAssertTrue(app.buttons["Add voice note"].exists)
        XCTAssertTrue(app.buttons["Share portfolio"].exists)
        XCTAssertTrue(app.buttons["Share booking link"].exists)
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="TapLead-next-actions";capture.lifetime = .keepAlways;add(capture)
        app.buttons["Send introduction"].tap()
        XCTAssertTrue(app.textViews["Introduction draft"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Share draft"].exists)
    }
    func testPremiumCardSampleScreenshots() {
        for theme in ["Minimal","Creator","Bold","Dark","Elegant","Sales","Consultant"] {
            let app=XCUIApplication()
            app.launchArguments=["--demo","--sample-theme",theme];app.launch()
            app.tabBars.buttons["My card"].tap()
            XCTAssertTrue(app.staticTexts["Demo · sample connections"].waitForExistence(timeout:5))
            let capture=XCTAttachment(screenshot:app.screenshot())
            capture.name="TapLead-premium-\(theme.lowercased())";capture.lifetime = .keepAlways;add(capture)
            app.terminate()
        }
    }
    func testCornerLogoImportPersistsAndCanBeRemoved() {
        let app=XCUIApplication();app.launchArguments=["--demo"];app.launch()
        app.tabBars.buttons["My card"].tap();app.buttons["Edit card"].tap()
        app.segmentedControls.buttons["Logo"].tap()
        app.buttons["Choose logo"].tap()
        let photo=app.scrollViews["photosView_content_scroll_view"].images.matching(identifier:"PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout:20),app.debugDescription)
        // PhotosUI exposes the remote thumbnail but reports no accessibility hit point.
        photo.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        XCTAssertTrue(app.staticTexts["Logo added"].waitForExistence(timeout:20),app.debugDescription)
        app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Image corner")).firstMatch.tap()
        app.buttons["Bottom right"].tap()
        app.buttons["Save"].tap()
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="TapLead-corner-logo";capture.lifetime = .keepAlways;add(capture)
        app.terminate();app.launchArguments=[];app.launch()
        app.tabBars.buttons["My card"].tap();app.buttons["Edit card"].tap()
        XCTAssertTrue(app.staticTexts["Logo added"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Bottom right")).firstMatch.exists)
        // Bring the row above the floating bottom toolbar before tapping it.
        app.swipeUp()
        app.buttons["Remove image"].tap()
        XCTAssertTrue(app.staticTexts["Logo added"].waitForNonExistence(timeout:5),app.debugDescription)
        app.buttons["Save"].tap();app.buttons["Edit card"].tap()
        XCTAssertFalse(app.staticTexts["Logo added"].exists)
        app.segmentedControls.buttons["None"].tap()
        XCTAssertFalse(app.buttons["Choose logo"].exists)
    }
    func testDemoConnectionWorkflow(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();XCTAssertTrue(app.staticTexts["Demo · sample connections"].exists);app.tabBars.buttons["Connections"].tap();let search=app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();if !app.keyboards.firstMatch.waitForExistence(timeout:3){search.tap()};XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5));search.typeText("Sarah");XCTAssertTrue(app.staticTexts["Sarah Chen"].exists)}
    func testUnpublishedQRDoesNotPretendToBeLive(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();app.buttons["Share my card"].tap();XCTAssertTrue(app.staticTexts["Publish your card to share a live QR"].waitForExistence(timeout:3))}
    func testScreenshotStates(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();for tab in ["Today","My card","Connections","Insights"]{app.tabBars.buttons[tab].tap();let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="TapLead-demo-\(tab)";attachment.lifetime = .keepAlways;add(attachment)}}
    func testSubscriptionReviewScreenshot(){let app=XCUIApplication();app.launchArguments=["--demo"];app.launch();app.tabBars.buttons["Settings"].tap();app.buttons["TapLead Pro"].tap();XCTAssertTrue(app.staticTexts["Multiple card personas"].waitForExistence(timeout:5));let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name="TapLead-Pro-review-current-configuration";attachment.lifetime = .keepAlways;add(attachment)}
}
