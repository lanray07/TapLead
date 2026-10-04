import Foundation

public enum LeadStatus: String, Codable, CaseIterable, Sendable {
    case new = "New", followUp = "Follow Up", active = "Active", won = "Won", archived = "Archived"
}
public enum CardTheme: String, Codable, CaseIterable, Sendable {
    case minimal = "Minimal", executive = "Executive", creator = "Creator", bold = "Bold", dark = "Dark", elegant = "Elegant", sales = "Sales", consultant = "Consultant"
}
public struct SocialLink: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var service: String
    public var url: String
    public init(service: String, url: String) { self.service = service; self.url = url }
}
public struct Card: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var persona = "Professional"
    public var name = ""
    public var preferredName = ""
    public var title = ""
    public var company = ""
    public var headline = ""
    public var bio = ""
    public var email = ""
    public var phone = ""
    public var website = ""
    public var location = ""
    public var portfolio = ""
    public var booking = ""
    public var socials: [SocialLink] = []
    public var theme: CardTheme = .executive
    public var accent = "6654D9"
    public var publicFields = ["email", "phone", "website", "location", "portfolio", "booking", "socials"]
    public var sectionOrder = ["About", "Contact", "Links"]
    public var published = false
    public var analyticsEnabled = false
    public var photoData: Data?
    public var logoData: Data?
    public init() {}
    public func profileURL(base: URL, source: String = "direct") -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("p/\(id.uuidString.lowercased())"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "source", value: source)]
        return parts.url!
    }
    public func isPublic(_ key: String) -> Bool { publicFields.contains(key) }
}
public struct TimelineEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var date = Date()
    public var kind: String
    public var text: String
    public init(kind: String, text: String, date: Date = Date()) { self.kind = kind; self.text = text; self.date = date }
}
public struct Lead: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var name = ""
    public var email = ""
    public var phone = ""
    public var company = ""
    public var role = ""
    public var interest = ""
    public var message = ""
    public var context = ""
    public var source = "manual"
    public var cardID: UUID?
    public var metAt = Date()
    public var status: LeadStatus = .new
    public var notes = ""
    public var tags: [String] = []
    public var followUp: Date?
    public var timeline: [TimelineEntry] = []
    public var consent = false
    public init() {}
    public func matches(_ query: String) -> Bool {
        query.isEmpty || [name, email, company, notes, context, tags.joined(separator: " ")].joined(separator: " ").localizedCaseInsensitiveContains(query)
    }
}
public struct AppSnapshot: Codable, Sendable {
    public var cards: [Card] = []
    public var leads: [Lead] = []
    public var pendingLeadIDs: [UUID] = []
    public var deletedLeadIDs: [UUID] = []
    public var selectedCardID: UUID?
    public var demo = false
    public init() {}
}
public enum Validation {
    public static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
    public static func email(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}
