//
//  MentalHealthTrackApp.swift
//  MentalHealthTrack
//
//  Created by KAZ on 5/30/25.
//

import SwiftUI
import CoreData

@main
struct MentalHealthTrackApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // アプリ起動時の初期設定
        setupInitialConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // 通知権限の要求
                    NotificationManager.shared.requestPermission()
                    // HealthKit権限の要求
                    HealthKitManager().requestAuthorization()
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
