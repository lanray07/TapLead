import XCTest
@testable import TapLeadCore

final class CoreTests: XCTestCase {
    func testFactsRejectInventedValuesAndEvidence() {
        let note="Met at the conference. Asked for the portfolio."
        XCTAssertTrue(Validation.groundedFact(value:"Asked for the portfolio",evidence:"Asked for the portfolio.",notes:note))
        XCTAssertFalse(Validation.groundedFact(value:"Booked a meeting",evidence:"Asked for the portfolio.",notes:note))
        XCTAssertFalse(Validation.groundedFact(value:"Tomorrow",evidence:"Tomorrow",notes:note))
        XCTAssertFalse(Validation.groundedFact(value:"",evidence:"Asked for the portfolio.",notes:note))
    }
    func testLegacyCardAndSnapshotKeepNewSettingsOptional() throws {
        let card=try JSONDecoder().decode(Card.self,from:JSONEncoder().encode(Card()))
        XCTAssertEqual(card.mode,.networking);XCTAssertEqual(card.action,.saveContact);XCTAssertNil(card.customBackground)
        XCTAssertNil(try JSONDecoder().decode(AppSnapshot.self,from:JSONEncoder().encode(AppSnapshot())).unpublishedCardEdits)
    }
    func testRemoteCardRefreshPreservesUnpublishedEditsAndLocalMedia() {
        var local=Card();local.name="Local draft";local.photoData=Data([1]);local.imageCorner = .bottomRight;local.published=true
        var remote=local;remote.name="Updated on second device";remote.photoData=nil
        XCTAssertEqual(CardSync.merge(remote:[remote],local:[local],editedIDs:[local.id])[0].name,"Local draft")
        let merged=CardSync.merge(remote:[remote],local:[local],editedIDs:[])[0]
        XCTAssertEqual(merged.name,remote.name);XCTAssertEqual(merged.photoData,local.photoData);XCTAssertEqual(merged.imageCorner,.bottomRight)
        XCTAssertFalse(CardSync.merge(remote:[],local:[local],editedIDs:[])[0].published)
        XCTAssertTrue(CardSync.merge(remote:[],local:[local],editedIDs:[local.id])[0].published)
    }
    func testCustomActionRespectsPublicVisibilityAndColourContrast() {
        var card=Card();card.primaryAction = .booking;card.booking="https://example.com/book";card.publicFields=[]
        XCTAssertNil(card.actionURL(base:URL(string:"https://cards.example.com")!))
        card.publicFields=["booking"]
        XCTAssertEqual(card.actionURL(base:URL(string:"https://cards.example.com")!)?.absoluteString,card.booking)
        XCTAssertTrue(Validation.prefersDarkText(on:"FFFFFF"));XCTAssertFalse(Validation.prefersDarkText(on:"000000"))
        XCTAssertFalse(Validation.hexColour("red;display:none"))
    }
    func testConnectionCountsUseCalendarDaysAndExcludeClosedFollowUps() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let now = ISO8601DateFormatter().date(from: "2026-10-24T22:00:00Z")!
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        var overdue = Lead(); overdue.metAt = now; overdue.followUp = today.addingTimeInterval(-60)
        var tonight = Lead(); tonight.metAt = now; tonight.followUp = tomorrow.addingTimeInterval(-1)
        var nextDay = Lead(); nextDay.metAt = now; nextDay.followUp = tomorrow
        var won = overdue; won.status = .won
        var archived = overdue; archived.status = .archived
        var old = Lead(); old.metAt = calendar.date(byAdding: .day, value: -7, to: today)!
        var future = Lead(); future.metAt = now.addingTimeInterval(60)
        let counts = ConnectionCounts(leads: [overdue, tonight, nextDay, won, archived, old, future], now: now, calendar: calendar)
        XCTAssertEqual(counts.recent, 5)
        XCTAssertEqual(counts.due, 2)
    }
    func testLegacyCardsDecodeWithoutImagePlacementFields() throws {
        var legacy = Card(); legacy.logoData = Data([1, 2, 3])
        let decoded = try JSONDecoder().decode(Card.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.imageKind, .logo)
        XCTAssertEqual(decoded.imageCorner, .topRight)
        legacy.photoData = Data([4, 5])
        let withPhoto = try JSONDecoder().decode(Card.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(withPhoto.imageKind, .photo)
    }
    func testSingleImageChoiceAndCornerSurvivePersistence() throws {
        var card = Card(); card.photoData = Data([1, 2]); card.logoData = Data([3, 4])
        card.imageKind = .logo; card.imageCorner = .bottomRight
        var snapshot = AppSnapshot(); snapshot.cards = [card]
        let restored = try JSONDecoder().decode(AppSnapshot.self, from: JSONEncoder().encode(snapshot)).cards[0]
        XCTAssertEqual(restored.imageKind, .logo)
        XCTAssertEqual(restored.imageCorner, .bottomRight)
        XCTAssertEqual(restored.logoData, card.logoData)
        var hidden = restored; hidden.imageKind = .none
        XCTAssertEqual(try JSONDecoder().decode(Card.self, from: JSONEncoder().encode(hidden)).imageKind, .none)
    }
    func testVCardExcludesPrivateFieldsAndEscapesInjection() {
        var card = Card(); card.name = "Alex; Smith\r\nEMAIL:injected@example.com"; card.email = "private@example.com"; card.publicFields = []
        let result = VCard.generate(card)
        XCTAssertFalse(result.contains("private@example.com"))
        XCTAssertTrue(result.contains("Alex\\; Smith\\nEMAIL:"))
        XCTAssertFalse(result.contains("\r\nEMAIL:"))
    }
    func testUTF8FoldingRoundTrips() {
        let line = "FN:" + String(repeating: "佐藤😀", count: 40)
        let folded = VCard.fold(line)
        XCTAssertEqual(folded.replacingOccurrences(of: "\r\n ", with: ""), line)
        XCTAssertTrue(folded.components(separatedBy: "\r\n").allSatisfy { $0.utf8.count <= 75 })
    }
    func testLinksRejectUnsafeSchemes() {
        XCTAssertNil(Validation.webURL("javascript:alert(1)"))
        XCTAssertNil(Validation.webURL("https://user:secret@example.com"))
        XCTAssertNotNil(Validation.webURL("https://example.com/portfolio"))
    }
    func testSearchAndPersistence() throws {
        var lead = Lead(); lead.name = "Sarah Chen"; lead.tags = ["Conference"]; lead.status = .followUp
        XCTAssertTrue(lead.matches("sarah")); XCTAssertTrue(lead.matches("conference")); XCTAssertFalse(lead.matches("James"))
        var state = AppSnapshot(); state.leads = [lead]; state.pendingLeadIDs = [lead.id]
        let decoded = try JSONDecoder().decode(AppSnapshot.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.leads, state.leads); XCTAssertEqual(decoded.pendingLeadIDs, [lead.id])
    }
    func testSourceLinksPreserveStableIdentity() {
        let card = Card(), base = URL(string: "https://cards.example.com")!
        XCTAssertEqual(card.profileURL(base: base, source: "nfc").path, card.profileURL(base: base, source: "qr").path)
        XCTAssertTrue(card.profileURL(base: base, source: "nfc").absoluteString.hasSuffix("source=nfc"))
    }
}
