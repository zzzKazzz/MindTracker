import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isPermissionGranted = false
    
    private init() {}
    
    // 通知を送るための権限（許可）をユーザーにリクエストするだけ
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
            }
        }
    }
    
    // 通知をキャンセルする
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // スケジュールされた通知を取得する
    func getNotificationSchedule() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    // 通知をスケジュールする
    func scheduleNotifications(startTime: Date, endTime: Date, interval: Int) {
        // まず既存の通知をクリア
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
        
        while currentMinutes <= endMinutes {
            let hour = currentMinutes / 60
            let minute = currentMinutes % 60
            
            // 通知内容を作成
            let content = UNMutableNotificationContent()
            content.title = "水分補給のリマインダー"
            content.body = "水を飲む時間です！"
            content.sound = .default
            
            // 毎日同じ時間に通知するトリガーを作成
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 通知リクエストを作成
            let identifier = "hydration-reminder-\(hour)-\(minute)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // 通知をスケジュール
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("通知のスケジュールに失敗: \(error)")
                }
            }
            
            currentMinutes += interval
            notificationCount += 1
            
            // iOS の制限により、64個以上の通知はスケジュールできないため制限
            if notificationCount >= 64 {
                break
            }
        }
        
        print("通知を \(notificationCount) 個スケジュールしました")
    }
}
