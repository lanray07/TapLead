import AppIntents
import Observation

@MainActor @Observable final class IntentRouter {
    static let shared=IntentRouter()
    var destination:String?
}
struct OpenCardIntent:AppIntent {
    static let title:LocalizedStringResource="Open my TapLead card"
    static let openAppWhenRun=true
    func perform() async throws -> some IntentResult {await MainActor.run{IntentRouter.shared.destination="card"};return .result()}
}
struct OpenQRIntent:AppIntent {
    static let title:LocalizedStringResource="Show my networking QR"
    static let openAppWhenRun=true
    func perform() async throws -> some IntentResult {await MainActor.run{IntentRouter.shared.destination="qr"};return .result()}
}
struct OpenFollowUpsIntent:AppIntent {
    static let title:LocalizedStringResource="Show today’s follow-ups"
    static let openAppWhenRun=true
    func perform() async throws -> some IntentResult {await MainActor.run{IntentRouter.shared.destination="followups"};return .result()}
}
struct TapLeadShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:OpenCardIntent(),phrases:["Open my card in \(.applicationName)"],shortTitle:"Open card",systemImageName:"person.crop.rectangle")
        AppShortcut(intent:OpenQRIntent(),phrases:["Show my QR in \(.applicationName)"],shortTitle:"Show QR",systemImageName:"qrcode")
        AppShortcut(intent:OpenFollowUpsIntent(),phrases:["Show follow-ups in \(.applicationName)"],shortTitle:"Follow-ups",systemImageName:"clock")
        AppShortcut(intent:AddNoteIntent(),phrases:["Add a note in \(.applicationName)"],shortTitle:"Add note",systemImageName:"mic")
    }
}
struct AddNoteIntent:AppIntent {
    static let title:LocalizedStringResource="Add a TapLead note"
    static let openAppWhenRun=true
    func perform() async throws -> some IntentResult {await MainActor.run{IntentRouter.shared.destination="voice"};return .result()}
}
