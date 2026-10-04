import XCTest
@testable import TapLeadCore

final class CoreTests: XCTestCase {
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
