import Foundation

// Only aggregate counts are shared. Names, notes and contact details stay in the app.
struct WidgetCountSnapshot: Codable {
    let date: Date
    let recent: Int
    let due: Int
}
