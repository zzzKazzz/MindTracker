import SwiftUI
import Foundation
import FamilyControls
import DeviceActivity

struct ScreenTimeCardView: View {
    @StateObject private var screenTimeManager = ScreenTimeManager()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                // TODO:ここは一旦アクセスする権限がないので使えない
                Text("アプリ使用状況")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if !screenTimeManager.isAuthorized {
                    Button("許可") {
                        Task {
                            await screenTimeManager.requestAuthorization()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            if screenTimeManager.isLoading {
                ProgressView("データを読み込み中...")
                    .frame(height: 100)
            } else if screenTimeManager.isAuthorized && !screenTimeManager.appUsageData.isEmpty {
                PieChartView(data: screenTimeManager.appUsageData)
            } else if !screenTimeManager.isAuthorized {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("スクリーンタイムの許可が必要です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("アプリ使用状況を表示するには、\nスクリーンタイムへのアクセスを許可してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            } else {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}
