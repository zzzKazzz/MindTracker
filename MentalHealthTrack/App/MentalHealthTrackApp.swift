import SwiftUI
import CoreData
import UserNotifications

@main
struct MentalHealthTrackApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    init() {
        setupInitialConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .onAppear {
                    setupNotifications()
                    NotificationManager.shared.scheduleUserDefinedNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // 非リピート通知を使っているため、復帰のたびに今後の枠を張り直す
                    NotificationManager.shared.scheduleUserDefinedNotifications()
                }
        }
    }
    
    private func setupNotifications() {
        NotificationManager.shared.requestPermission()
        HealthKitManager.shared.requestAuthorization()
        appState.setupNotificationDelegate()
    }
    
    private func setupInitialConfigurations() {
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.set(30, forKey: "notificationInterval")
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
    }
}

class AppState: ObservableObject {
    @Published var shouldShowEntryView = false
    // 通知タップ経由のときの記録対象スロット
    @Published var entrySlotStart: Date?
    @Published var entrySlotEnd: Date?
    private var notificationDelegate: NotificationDelegate?
    
    init() {}
    
    func setupNotificationDelegate() {
        notificationDelegate = NotificationDelegate(appState: self)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    func openEntryView(slotStart: Date? = nil, slotEnd: Date? = nil) {
        DispatchQueue.main.async {
            self.entrySlotStart = slotStart
            self.entrySlotEnd = slotEnd
            self.shouldShowEntryView = true
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        let isMindfulness = (userInfo["type"] as? String) == "mindfulness"
        
        if isMindfulness ||
           identifier.contains("intervalNotification") ||
           identifier.contains("dailyReminder") || 
           identifier.contains("mindfulness") || 
           identifier.contains("testNotification") {
            let slotStart = Self.date(fromUserInfo: userInfo, key: "slotStart")
            let slotEnd = Self.date(fromUserInfo: userInfo, key: "slotEnd")
            self.appState.openEntryView(slotStart: slotStart, slotEnd: slotEnd)
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // userInfo の数値は NSNumber になることがある
    private static func date(fromUserInfo userInfo: [AnyHashable: Any], key: String) -> Date? {
        if let interval = userInfo[key] as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        }
        if let number = userInfo[key] as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        return nil
    }
}