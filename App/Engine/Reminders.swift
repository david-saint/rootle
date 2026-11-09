import Foundation
import UserNotifications

/// A daily nudge that teases that day's word — scheduled a week ahead.
enum Reminders {
    static func reschedule(enabled: Bool, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let state = SharedStore.load()
            for offset in 0..<7 {
                let day = Day.adding(offset)
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = 0
                guard let fire = Calendar.current.date(from: comps), fire > .now else { continue }
                let word = state.wordOfTheDay(day)
                let content = UNMutableNotificationContent()
                content.title = "Today's word: \(word.word)"
                content.body = "It once meant “\(word.lit)”. Dig in and keep your roots growing."
                content.sound = .default
                content.userInfo = ["word": word.id]
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "rootle.daily.\(offset)", content: content, trigger: trigger))
            }
        }
    }
}
