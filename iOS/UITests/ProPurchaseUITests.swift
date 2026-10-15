import XCTest
import StoreKitTest

final class ProPurchaseUITests:XCTestCase {
    func testFreshGuestSeesPlansAndCanSignInFromPaywall() throws {
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"TapLead",withExtension:"storekit"))
        let session=try SKTestSession(contentsOf:url)
        session.disableDialogs=true
        session.clearTransactions()
        defer{session.resetToDefaultState()}
        let app=XCUIApplication()
        app.launchArguments=["--demo"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["TapLead Pro"].tap()
        let monthly=app.buttons["com.taplead.pro.monthly"]
        let annual=app.buttons["com.taplead.pro.yearly"]
        for _ in 0..<10 {
            if monthly.isHittable {break}
            app.swipeUp()
        }
        XCTAssertTrue(monthly.waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(annual.exists,app.debugDescription)
        XCTAssertTrue(monthly.label.contains("4.99"),monthly.label)
        XCTAssertTrue(annual.label.contains("39.99"),annual.label)
        XCTAssertFalse(app.staticTexts["Pro purchases are not yet available. Release configuration and sandbox verification are required."].exists)
        let screenshot=XCTAttachment(screenshot:app.screenshot())
        screenshot.name="Pro-plans-visible-before-sign-in-local-StoreKit"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        monthly.tap()
        XCTAssertTrue(app.navigationBars["Welcome to TapLead"].waitForExistence(timeout:5),app.debugDescription)
        XCTAssertTrue(app.staticTexts["Your connections, wherever you go."].exists)
    }
}
