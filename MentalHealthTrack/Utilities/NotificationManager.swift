import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Permission Management
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("通知権限リクエストエラー: \(error)")
                    return
                }
                
                print("通知権限リクエスト結果: \(granted)")
                
                if granted {
                    self.scheduleUserDefinedNotifications()
                }
            }
        }
    }
    
    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleUserDefinedNotifications() {
        // UserDefaultsから設定を読み込み
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        guard notificationsEnabled else {
            print("通知が無効になっています")
            cancelNotifications()
            return
        }

        let startTime = UserDefaults.standard.object(forKey: "notificationStartTime") as? Date ?? createDefaultTime(hour: 9, minute: 0)
        let endTime = UserDefaults.standard.object(forKey: "notificationEndTime") as? Date ?? createDefaultTime(hour: 18, minute: 0)
        let interval = UserDefaults.standard.integer(forKey: "notificationInterval")
        let actualInterval = interval > 0 ? interval : 60 // デフォルト1時間

        // 曜日設定を読み込み
        let selectedWeekdays = loadSelectedWeekdays()

        scheduleIntervalNotifications(startTime: startTime, endTime: endTime, interval: actualInterval, selectedWeekdays: selectedWeekdays)
    }
    
    // iOSのpending通知は64件が上限のため、リピート通知ではなく
    // 「これから来る枠」を具体的な日時で最大60件だけ張り、起動/復帰のたびに張り直す
    func scheduleIntervalNotifications(startTime: Date, endTime: Date, interval: Int, selectedWeekdays: Set<Int>? = nil) {
        cancelNotifications()

        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: startTime) * 60 + calendar.component(.minute, from: startTime)
        let endMinutes = calendar.component(.hour, from: endTime) * 60 + calendar.component(.minute, from: endTime)
        let now = Date()

        var slots: [Date] = []
        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if let weekdays = selectedWeekdays, !weekdays.contains(weekday) { continue }

            var currentMinutes = startMinutes
            while currentMinutes <= endMinutes {
                let hour = currentMinutes / 60
                let minute = currentMinutes % 60

                // 12:01〜13:00の間は通知をスキップ（12:00ぴったりは含まない）
                if !((hour == 12 && minute > 0) || (hour == 13 && minute == 0)),
                   let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                   fireDate > now {
                    slots.append(fireDate)
                }
                currentMinutes += interval
            }
        }

        slots.sort()
        for (index, fireDate) in slots.prefix(60).enumerated() {
            scheduleSlotNotification(index: index, fireDate: fireDate, interval: interval)
        }

        // スケジュール結果を確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.printScheduledNotifications()
        }
    }

    private func scheduleSlotNotification(index: Int, fireDate: Date, interval: Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = "気持ちの記録"
        content.body = getNotificationMessage(for: hour)
        content.sound = .default
        content.badge = 1

        // 「この枠（slotStart〜slotEnd）どうだった？」を記録画面に渡す
        let slotStart = fireDate.addingTimeInterval(TimeInterval(-interval * 60))
        content.userInfo = [
            "type": "mindfulness",
            "slotStart": slotStart.timeIntervalSince1970,
            "slotEnd": fireDate.timeIntervalSince1970
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "intervalNotification_\(index)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー (\(fireDate)): \(error)")
            }
        }
    }
    
    private func getNotificationMessage(for hour: Int) -> String {
        switch hour {
        case 6..<9:
            return "おはよう！今日の気持ちも登録して行こう!"
        case 9..<12:
            return "午前中の記録をしていこう！"
        case 12..<14:
            return "お昼休み、リフレッシュ"
        case 14..<17:
            return "午後の一息、今の気持ちを記録しませんか？"
        case 17..<20:
            return "今日もあと一息。"
        case 20..<23:
            return "今日もお疲れ！記録して振り返ろう！"
        default:
            return "今の気持ちを記録してみませんか？"
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func printScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            for request in requests.sorted(by: { req1, req2 in
                guard let trigger1 = req1.trigger as? UNCalendarNotificationTrigger,
                      let trigger2 = req2.trigger as? UNCalendarNotificationTrigger,
                      let hour1 = trigger1.dateComponents.hour,
                      let minute1 = trigger1.dateComponents.minute,
                      let hour2 = trigger2.dateComponents.hour,
                      let minute2 = trigger2.dateComponents.minute else {
                    return false
                }
                
                let time1 = hour1 * 60 + minute1
                let time2 = hour2 * 60 + minute2
                return time1 < time2
            }) {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let hour = trigger.dateComponents.hour ?? 0
                    let minute = trigger.dateComponents.minute ?? 0
                }
            }
        }
    }
    
    // MARK: - Helper Methods

    private func createDefaultTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private func loadSelectedWeekdays() -> Set<Int>? {
        guard let selectedWeekdaysData = UserDefaults.standard.data(forKey: "selectedWeekdays") else {
            // デフォルトは平日（月〜金）
            return Set([2, 3, 4, 5, 6])
        }

        if let decoded = try? JSONDecoder().decode(Set<Int>.self, from: selectedWeekdaysData) {
            return decoded.isEmpty ? nil : decoded
        }

        // デコードに失敗した場合はデフォルト値
        return Set([2, 3, 4, 5, 6])
    }
    
    // MARK: - Test Notifications
    
    func scheduleTestNotification(after seconds: TimeInterval, message: String = "テスト通知です") {
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = message
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "testNotification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("テスト通知エラー: \(error)")
            } else {
                print("テスト通知が\(Int(seconds))秒後にスケジュールされました")
            }
        }
    }
}

// 5. 通知作成時のデバッグログも追加
// NotificationManager.swift（または通知作成部分）に以下を追加：

extension NotificationManager {
    func scheduleDebugNotification() {
        print("🔔 デバッグ通知をスケジュール中...")
        
        let content = UNMutableNotificationContent()
        content.title = "デバッグ通知"
        content.body = "通知タップのテストです"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "debugNotification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ デバッグ通知エラー: \(error)")
            } else {
                print("✅ デバッグ通知が10秒後にスケジュールされました")
                print("🔔 通知識別子: \(request.identifier)")
            }
        }
    }
}