import UserNotifications
import Foundation
enum NotificationService {
    static func schedule(id:UUID,date:Date) async throws {
        guard date>Date() else{throw ServiceError.message(String(localized:"Choose a future follow-up date."))}
        let center=UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options:[.alert,.sound,.badge]) else{throw ServiceError.message(String(localized:"Notifications are disabled."))}
        let content=UNMutableNotificationContent();content.title=String(localized:"A connection is waiting");content.body=String(localized:"Open TapLead to see your follow-up.");content.sound = .default
        let components=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:date)
        let request=UNNotificationRequest(identifier:id.uuidString,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false))
        try await center.add(request)
    }
    static func cancel(_ id:UUID){UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:[id.uuidString]);UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:[id.uuidString])}
}
