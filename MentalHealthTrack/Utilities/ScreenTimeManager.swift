//
//  ScreenTimeManager.swift
//  MentalHealthTrack
//
//  Created by KAZ on 6/4/25.
//

import SwiftUI
import FamilyControls
import DeviceActivity

@MainActor
class ScreenTimeManager: ObservableObject {
    @Published var appUsageData: [AppUsageData] = []
    @Published var isAuthorized = false
    @Published var isLoading = false
    
    private let authorizationCenter = AuthorizationCenter.shared
    
    init() {
        checkAuthorization()
    }
    
    func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = true
                Task {
                    await loadScreenTimeData()
                }
            }
        } catch {
            print("Screen Time authorization failed: \(error)")
        }
    }
    
    private func checkAuthorization() {
        switch authorizationCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
            Task {
                await loadScreenTimeData()
            }
        default:
            isAuthorized = false
        }
    }
    
    private func loadScreenTimeData() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Screen Time APIを使用してデータを取得
        // 注意: 実際の実装では DeviceActivityReport を使用する必要があります
        // ここではサンプルデータを生成
        let sampleData = generateSampleData()
        
        await MainActor.run {
            self.appUsageData = sampleData
            self.isLoading = false
        }
    }
    
    private func generateSampleData() -> [AppUsageData] {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan]
        let sampleApps = [
            ("Safari", "com.apple.safari", 7200.0),
            ("Instagram", "com.instagram.app", 5400.0),
            ("Twitter", "com.twitter.twitter", 3600.0),
            ("YouTube", "com.google.youtube", 4800.0),
            ("Messages", "com.apple.messages", 2400.0),
            ("Mail", "com.apple.mail", 1800.0),
            ("その他", "other", 3000.0)
        ]
        
        return sampleApps.enumerated().map { index, app in
            AppUsageData(
                appName: app.0,
                bundleIdentifier: app.1,
                totalTime: app.2,
                color: colors[index % colors.count]
            )
        }
    }
}
