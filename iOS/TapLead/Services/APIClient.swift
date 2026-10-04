import Foundation
import Security
import TapLeadCore

enum ServiceError: LocalizedError {
    case message(String)
    case response(status:Int,message:String)
    var errorDescription:String?{switch self{case .message(let text):text;case .response(_,let message):message}}
}
enum Keychain {
    private static let service = "com.taplead.session"
    static func token() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func set(_ token: String?) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        guard let token else { return }
        var attributes = query
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw ServiceError.message(String(localized: "Could not securely save your session.")) }
    }
}
struct APIClient {
    private struct Failure:Decodable {var error:String}
    var base: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TapLeadAPIURL") as? String else { return nil }
        return Validation.webURL(raw)
    }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, contentType:String="application/json") async throws -> T {
        guard let base else { throw ServiceError.message(String(localized: "Connect a secure TapLead service to use this feature.")) }
        let pathParts = path.split(separator:"?",maxSplits:1,omittingEmptySubsequences:false)
        var components = URLComponents(url:base.appendingPathComponent(String(pathParts[0])),resolvingAgainstBaseURL:false)!
        if pathParts.count>1 { components.percentEncodedQuery=String(pathParts[1]) }
        var request = URLRequest(url:components.url!); request.httpMethod = method; request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token = Keychain.token() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.timeoutInterval = 35
        let (data,response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(response.statusCode) else {
            throw ServiceError.response(status:response.statusCode,message:(try? JSONDecoder().decode(Failure.self, from: data).error) ?? String(localized: "The request could not be completed."))
        }
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func send<T: Encodable, R: Decodable>(_ path: String, method: String, value: T) async throws -> R {
        try await request(path, method: method, body: JSONEncoder().encode(value))
    }
}
struct EmptyResponse: Decodable {}
struct AuthResponse: Decodable { var token: String; var userID: String }
struct PlanResponse:Decodable {var pro:Bool;var cardLimit:Int;var leadLimit:Int;var purchasesEnabled:Bool?;var products:[String]?}
struct AnalyticsResponse: Decodable {
    struct Event: Decodable, Identifiable {
        var kind: String; var source: String; var created: Double
        var id: String { "\(kind)-\(source)-\(created)" }
        var date: Date { Date(timeIntervalSince1970: created / 1000) }
    }
    var events: [Event]; var notice: String
}
struct AIResult: Decodable {
    struct Fact: Decodable { var field: String; var value: String; var evidence: String }
    var draft: String?; var facts: [Fact]; var suggestions: [String]
}
