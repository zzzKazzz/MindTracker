import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    // 通知を送るための権限（許可）をユーザーにリクエストするだけ
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // 許可取得後の処理
        }
    }
}
