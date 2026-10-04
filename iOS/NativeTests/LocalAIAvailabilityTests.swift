import XCTest
@testable import TapLead

final class LocalAIAvailabilityTests:XCTestCase {
    func testUnavailableModelFailsWithoutSendingNotes() async throws {
        // The hosted simulator has no Apple Intelligence model. A real model needs
        // separate device evaluation; never report generated sample output as verified.
        guard !LocalAIService.available else {throw XCTSkip("Available model requires the device evaluation suite")}
        do {
            _ = try await LocalAIService.generate(kind:"smart_notes",notes:"Private note",name:"Alex",tone:"Professional",channel:"Email")
            XCTFail("An unavailable model must not pretend to generate notes")
        } catch {XCTAssertTrue(error.localizedDescription.contains("On-device AI"))}
    }
}
