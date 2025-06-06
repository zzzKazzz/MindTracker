import SwiftUI
import CoreData
import UserNotifications

@main
struct MentalHealthTrackApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    init() {
        print("📱 アプリ初期化中...")
        setupInitialConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .onAppear {
                    print("📱 ContentView表示中...")
                    setupNotifications()
                }
        }
    }
    private func setupNotifications() {
        print("🔔 通知設定開始...")
        // 通知権限の要求
        NotificationManager.shared.requestPermission()
        // HealthKit権限の要求
        HealthKitManager.shared.requestAuthorization()
        
        // 通知デリゲートを設定
        appState.setupNotificationDelegate()
        print("🔔 通知デリゲート設定完了")
        // デリゲートが正しく設定されているか確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if UNUserNotificationCenter.current().delegate != nil {
                print("✅ 通知デリゲートが正しく設定されています")
            } else {
                print("❌ 通知デリゲートの設定に失敗しました")
            }
        }
    }
    
    private func setupInitialConfigurations() {
        print("⚙️ 初期設定開始...")
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            print("🆕 初回起動を検出")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.set(30, forKey: "notificationInterval")
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
            print("✅ 初期設定完了")
        } else {
            print("🔄 既存ユーザーのアプリ起動")
        }
    }
}

// 2. AppState.swift - デバッグログ付き改善版
// TODO:デバック終わったら消す
import SwiftUI

class AppState: ObservableObject {
    @Published var shouldShowEntryView = false
    private var notificationDelegate: NotificationDelegate?
    init() {
        print("🎯 AppState初期化")
    }
    func setupNotificationDelegate() {
        print("🎯 通知デリゲートの設定開始")
        notificationDelegate = NotificationDelegate(appState: self)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        print("🎯 通知デリゲートの設定完了")
    }
    
    func openEntryView() {
        print("🎯 AppState.openEntryView() 呼び出し")
        print("🎯 現在のshouldShowEntryView: \(shouldShowEntryView)")
        DispatchQueue.main.async {
            print("🎯 メインスレッドでshouldShowEntryViewをtrueに設定")
            self.shouldShowEntryView = true
            print("🎯 設定後のshouldShowEntryView: \(self.shouldShowEntryView)")
        }
    }
}

// 3. NotificationDelegate.swift - デバッグログ付き改善版
// TODO:デバック終わったら消す
import UserNotifications
import SwiftUI

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        print("🔔 NotificationDelegate初期化完了")
    }
    
    // 通知がタップされた時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("🔔 通知がタップされました！")
        print("🔔 通知識別子: \(response.notification.request.identifier)")
        print("🔔 通知タイトル: \(response.notification.request.content.title)")
        print("🔔 通知本文: \(response.notification.request.content.body)")
        print("🔔 アクションID: \(response.actionIdentifier)")
        let identifier = response.notification.request.identifier
        
        // より広範囲の識別子をチェック
        if identifier.contains("dailyReminder") || 
           identifier.contains("mindfulness") || 
           identifier.contains("testNotification") {
            print("✅ マインドフルネス関連の通知を確認")
            print("🎯 記録画面を開く処理開始...")
            // AppStateの参照を確認
            print("🎯 AppState参照確認: \(appState)")
            // メインスレッドで記録画面を開く
            DispatchQueue.main.async {
                print("🎯 メインスレッドで記録画面を開く処理実行")
                self.appState.openEntryView()
                // 少し待ってから状態を確認
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎯 0.5秒後の状態確認: shouldShowEntryView = \(self.appState.shouldShowEntryView)")
                }
            }
        } else {
            print("❌ 対象外の通知識別子: \(identifier)")
        }
        
        completionHandler()
        print("🔔 通知処理完了")
    }
    
    // アプリがフォアグラウンドにある時の通知表示設定
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 フォアグラウンドで通知を受信")
        print("🔔 通知識別子: \(notification.request.identifier)")
        print("🔔 通知タイトル: \(notification.request.content.title)")
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
}