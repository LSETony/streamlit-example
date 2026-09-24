import Foundation
import UserNotifications

/// Local reminders — a trainer session starting soon, an event you joined,
/// a subscription about to renew. All scheduled on-device via
/// UNUserNotificationCenter, no server or APNs needed (this project has no
/// push backend, and remote push needs a paid Apple Developer Program
/// membership for APNs anyway — see AuthService's Sign in with Apple
/// comment for the same constraint). Every schedule call is keyed by a
/// stable identifier derived from the thing it's about, so re-booking or
/// re-joining just replaces the old reminder instead of stacking dupes.
enum NotificationService {
    /// Call once, e.g. right before the first time a reminder would be
    /// scheduled — repeat calls after the member has already answered are
    /// harmless no-ops.
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func scheduleSessionReminder(id: UUID, title: String, trainerName: String, date: Date) {
        requestAuthorizationIfNeeded()
        guard let fireDate = Calendar.current.date(byAdding: .hour, value: -1, to: date), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Starting in an hour"
        content.body = trainerName.isEmpty ? title : "\(title) with \(trainerName)"
        content.sound = .default
        schedule(identifier: "session-\(id.uuidString)", content: content, fireDate: fireDate)
    }

    static func cancelSessionReminder(id: UUID) {
        cancel(identifier: "session-\(id.uuidString)")
    }

    static func scheduleEventReminder(id: UUID, title: String, date: Date) {
        requestAuthorizationIfNeeded()
        guard let fireDate = Calendar.current.date(byAdding: .hour, value: -1, to: date), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Event starting soon"
        content.body = "\(title) starts in an hour."
        content.sound = .default
        schedule(identifier: "event-\(id.uuidString)", content: content, fireDate: fireDate)
    }

    static func cancelEventReminder(id: UUID) {
        cancel(identifier: "event-\(id.uuidString)")
    }

    /// `daysBefore` the renewal date, once a day at 10am local time.
    static func scheduleRenewalReminder(planName: String, renewDate: Date, daysBefore: Int = 3) {
        requestAuthorizationIfNeeded()
        guard let fireDay = Calendar.current.date(byAdding: .day, value: -daysBefore, to: renewDate) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDay)
        components.hour = 10
        guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Subscription renewing soon"
        content.body = "Your \(planName) plan renews in \(daysBefore) days."
        content.sound = .default
        schedule(identifier: "renewal", content: content, fireDate: fireDate)
    }

    private static func schedule(identifier: String, content: UNMutableNotificationContent, fireDate: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().add(request)
    }

    private static func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
