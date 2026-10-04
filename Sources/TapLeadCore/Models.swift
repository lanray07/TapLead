import Foundation

public enum LeadStatus: String, Codable, CaseIterable, Sendable {
    case new = "New", followUp = "Follow Up", active = "Active", won = "Won", archived = "Archived"
}
public enum CardTheme: String, Codable, CaseIterable, Sendable {
    case minimal = "Minimal", executive = "Executive", creator = "Creator", bold = "Bold", dark = "Dark", elegant = "Elegant", sales = "Sales", consultant = "Consultant"
}
public enum NetworkingMode: String, Codable, CaseIterable, Sendable {
    case networking = "Networking", sales = "Sales", recruiting = "Recruiting", event = "Event"
}
public enum CardTypography: String, Codable, CaseIterable, Sendable {
    case standard = "Standard", rounded = "Rounded", serif = "Serif", monospaced = "Monospaced"
}
public enum CardAction: String, Codable, CaseIterable, Sendable {
    case saveContact = "Save contact", website = "Website", portfolio = "Portfolio", booking = "Book a meeting", cv = "View CV"
    public var field: String? {
        switch self { case .saveContact: nil; case .website: "website"; case .portfolio: "portfolio"; case .booking: "booking"; case .cv: "cv" }
    }
}
public enum CardImageKind: String, Codable, CaseIterable, Sendable {
    case none = "None", photo = "Photo", logo = "Logo"
}
public enum CardImageCorner: String, Codable, CaseIterable, Sendable {
    case topLeft = "Top left", topRight = "Top right", bottomLeft = "Bottom left", bottomRight = "Bottom right"
    public var isTop: Bool { self == .topLeft || self == .topRight }
    public var isLeading: Bool { self == .topLeft || self == .bottomLeft }
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
    // Optional storage preserves decoding of cards created before image placement existed.
    public var cornerImageKind: CardImageKind?
    public var cornerImagePosition: CardImageCorner?
    public var customBackground: String?
    public var typography: CardTypography?
    public var primaryAction: CardAction?
    public var primaryActionLabel: String?
    public var networkingMode: NetworkingMode?
    public var cv: String?
    public var mode: NetworkingMode { networkingMode ?? .networking }
    public var action: CardAction {
        if let primaryAction {return primaryAction}
        switch mode {
        case .networking:return .saveContact
        case .sales:return .booking
        case .recruiting:return isPublic("cv") && Validation.webURL(cv ?? "") != nil ? .cv : .portfolio
        case .event:return .website
        }
    }
    public func actionURL(base: URL, source: String = "direct") -> URL? {
        let profile = profileURL(base: base, source: source)
        guard let field = action.field else { return profile }
        let value = field == "cv" ? (cv ?? "") : field == "booking" ? booking : field == "portfolio" ? portfolio : website
        guard isPublic(field), Validation.webURL(value) != nil else { return nil }
        return URL(string: value)
    }
    public var imageKind: CardImageKind {
        get { cornerImageKind ?? (photoData == nil && logoData != nil ? .logo : .photo) }
        set { cornerImageKind = newValue }
    }
    public var imageCorner: CardImageCorner {
        get { cornerImagePosition ?? .topRight }
        set { cornerImagePosition = newValue }
    }
    public init() {}
    public func profileURL(base: URL, source: String = "direct") -> URL {
        let queryProfile=base.path.hasSuffix("/card/") || base.path.hasSuffix("/card")
        var parts = URLComponents(url: queryProfile ? base : base.appendingPathComponent("p/\(id.uuidString.lowercased())"), resolvingAgainstBaseURL: false)!
        parts.queryItems = (queryProfile ? [URLQueryItem(name:"id",value:id.uuidString.lowercased())] : []) + [URLQueryItem(name: "source", value: source)]
        return parts.url!
    }
    public func isPublic(_ key: String) -> Bool { publicFields.contains(key) }
}
public struct TimelineEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var date = Date()
    public var kind: String
    public var text: String
    public var displayName:String {
        ["met":"Connection made","received":"Details received","voice":"Voice note added","status":"Status changed","follow_up_scheduled":"Follow-up scheduled","follow_up_completed":"Follow-up completed","follow_up_drafted":"Draft saved","smart_notes":"Smart Notes saved"][kind] ?? kind
    }
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
    public var unpublishedCardEdits: [UUID]?
    public var selectedCardID: UUID?
    public var demo = false
    public init() {}
}
public enum CardSync {
    public static func merge(remote: [Card], local: [Card], editedIDs: [UUID]) -> [Card] {
        var result=local
        for card in remote {
            if let index=result.firstIndex(where:{$0.id==card.id}) {
                guard !editedIDs.contains(card.id) else {continue}
                var merged=card
                merged.photoData=card.photoData ?? result[index].photoData;merged.logoData=card.logoData ?? result[index].logoData
                merged.cornerImageKind=card.cornerImageKind ?? result[index].cornerImageKind;merged.cornerImagePosition=card.cornerImagePosition ?? result[index].cornerImagePosition
                result[index]=merged
            } else {result.append(card)}
        }
        let remoteIDs=Set(remote.map(\.id))
        for index in result.indices where result[index].published && !remoteIDs.contains(result[index].id) && !editedIDs.contains(result[index].id) {
            result[index].published=false
        }
        return result
    }
}
public enum Validation {
    public static func groundedFact(value:String,evidence:String,notes:String)->Bool {
        !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && !evidence.isEmpty && evidence.count <= 2000 && value.count <= 2000 && notes.contains(evidence) && evidence.contains(value)
    }
    public static func hexColour(_ value: String) -> Bool { value.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil }
    public static func prefersDarkText(on hex: String) -> Bool {
        guard let value = UInt32(hex, radix: 16) else { return false }
        func linear(_ byte: UInt32) -> Double { let c = Double(byte) / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear((value >> 16) & 255) + 0.7152 * linear((value >> 8) & 255) + 0.0722 * linear(value & 255)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05)
    }
    public static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
    public static func email(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

public struct ConnectionCounts: Codable, Equatable, Sendable {
    public var recent: Int
    public var due: Int
    public init(leads: [Lead], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        recent = leads.filter { $0.metAt >= weekStart && $0.metAt <= now }.count
        due = leads.filter {
            $0.status != .won && $0.status != .archived && ($0.followUp.map { $0 < tomorrow } ?? false)
        }.count
    }
}
