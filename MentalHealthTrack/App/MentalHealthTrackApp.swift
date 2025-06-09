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
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .onAppear {
                    setupNotifications()
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
    private var notificationDelegate: NotificationDelegate?
    
    init() {}
    
    func setupNotificationDelegate() {
        notificationDelegate = NotificationDelegate(appState: self)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    func openEntryView() {
        DispatchQueue.main.async {
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
        
        if identifier.contains("dailyReminder") || 
           identifier.contains("mindfulness") || 
           identifier.contains("testNotification") {
            DispatchQueue.main.async {
                self.appState.openEntryView()
            }
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}