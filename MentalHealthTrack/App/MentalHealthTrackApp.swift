// 1. MentalHealthTrackApp.swiftを以下のように変更

import SwiftUI
import CoreData
import UserNotifications

@main
struct MentalHealthTrackApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    init() {
        // アプリ起動時の初期設定
        setupInitialConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .onAppear {
                    // 通知権限の要求
                    NotificationManager.shared.requestPermission()
                    // HealthKit権限の要求
                    HealthKitManager.shared.requestAuthorization()
                    
                    // 通知デリゲートを設定
                    UNUserNotificationCenter.current().delegate = NotificationDelegate(appState: appState)
                }
        }
    }
    
    private func setupInitialConfigurations() {
        // 初回起動時の設定
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            // デフォルト通知設定
            UserDefaults.standard.set(30, forKey: "notificationInterval") // 30分間隔
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
    }
}

// 2. AppState.swift - 新規作成
class AppState: ObservableObject {
    @Published var shouldShowEntryView = false
    
    func openEntryView() {
        shouldShowEntryView = true
    }
}

// 3. NotificationDelegate.swift - 新規作成
import UserNotifications
import SwiftUI

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // 通知がタップされた時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // 通知の識別子をチェック
        let identifier = response.notification.request.identifier
        
        // マインドフルネス関連の通知の場合
        if identifier.contains("dailyReminder") || identifier.contains("mindfulness") {
            // メインスレッドで記録画面を開く
            DispatchQueue.main.async {
                self.appState.openEntryView()
            }
        }
        
        completionHandler()
    }
    
    // アプリがフォアグラウンドにある時の通知表示設定
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
}