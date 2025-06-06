// NotificationManager.swift
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
        
        scheduleIntervalNotifications(startTime: startTime, endTime: endTime, interval: actualInterval)
    }
    
    func scheduleIntervalNotifications(startTime: Date, endTime: Date, interval: Int) {
        // 既存の通知をクリア
        cancelNotifications()
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        var currentMinutes = startMinutes
        var notificationCount = 0
        
        print("通知スケジュール開始: \(startHour):\(String(format: "%02d", startMinute)) 〜 \(endHour):\(String(format: "%02d", endMinute)), 間隔: \(interval)分")
        
        while currentMinutes <= endMinutes {
            let hour = currentMinutes / 60
            let minute = currentMinutes % 60
            
            scheduleNotification(
                identifier: "intervalNotification_\(notificationCount)",
                hour: hour,
                minute: minute,
                title: "気持ちの記録",
                body: getNotificationMessage(for: hour)
            )
            
            print("通知スケジュール: \(hour):\(String(format: "%02d", minute))")
            
            currentMinutes += interval
            notificationCount += 1
        }
        
        print("合計 \(notificationCount) 個の通知をスケジュールしました")
        
        // スケジュール結果を確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.printScheduledNotifications()
        }
    }
    
    private func scheduleNotification(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー (\(hour):\(String(format: "%02d", minute))): \(error)")
            }
        }
    }
    
    private func getNotificationMessage(for hour: Int) -> String {
        switch hour {
        case 6..<10:
            return "おはようございます！今朝の気持ちはいかがですか？"
        case 10..<12:
            return "午前中の調子はどうですか？"
        case 12..<14:
            return "お昼休み、リフレッシュしていますか？"
        case 14..<17:
            return "午後の一息、今の気持ちを記録しませんか？"
        case 17..<20:
            return "お疲れさまです。今日の振り返りをしてみましょう"
        case 20..<23:
            return "一日お疲れさまでした。今日の気持ちを記録してみませんか？"
        default:
            return "今の気持ちを記録してみませんか？"
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("すべての通知をキャンセルしました")
    }
    
    func printScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("=== スケジュール済み通知一覧 ===")
            print("通知数: \(requests.count)")
            
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
                    print("- \(hour):\(String(format: "%02d", minute)) : \(request.content.body)")
                }
            }
            print("===============================")
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