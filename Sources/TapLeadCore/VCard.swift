import Foundation

public enum VCard {
    public static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }
    // RFC 6350: fold at 75 octets without splitting a UTF-8 scalar.
    public static func fold(_ line: String) -> String {
        var result = "", count = 0
        for scalar in line.unicodeScalars {
            let text = String(scalar), size = text.utf8.count
            if count + size > 75 { result += "\r\n "; count = 1 }
            result += text; count += size
        }
        return result
    }
    public static func generate(_ card: Card) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:4.0", "FN:\(escape(card.name))", "ORG:\(escape(card.company))", "TITLE:\(escape(card.title))"]
        if card.isPublic("email"), !card.email.isEmpty { lines.append("EMAIL:\(escape(card.email))") }
        if card.isPublic("phone"), !card.phone.isEmpty { lines.append("TEL;VALUE=text:\(escape(card.phone))") }
        if card.isPublic("website"), Validation.webURL(card.website) != nil { lines.append("URL:\(escape(card.website))") }
        if card.isPublic("location"), !card.location.isEmpty { lines.append("ADR:;;;;\(escape(card.location));;") }
        lines.append("END:VCARD")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }
}
