import SwiftUI
import CoreData

struct HomeTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    
    // CoreDataからMindfulnessDataを取得
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>
    
    // HealthKitManager
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    // 現在の日付を管理
    @State private var currentDate = Date()
    // 日付更新用のタイマー
    @State private var dateUpdateTimer: Timer?
    // ビューの更新をトリガーするためのフラグ
    @State private var refreshTrigger = false
    
    // 新規記録画面の表示状態を管理
    @State private var showingEntryView = false
    
    // エクスポート関連
    @State private var isExporting = false
    @State private var showingExportAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // タイトル（購入履歴と同じスタイル）
            VStack(spacing: 0) {
                Text("Footstep of the Mind")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
            }

            // メインコンテンツ
            ScrollView {
                VStack(spacing: 16) {
                    // 統計情報カード
                    StatisticsCardView(
                        todayCount: todayEntriesCount(),
                        totalCount: entries.count,
                        todaySteps: healthKitManager.todaySteps,
                        isHealthAuthorized: healthKitManager.isAuthorized,
                        onExport: { exportData() },
                        isExporting: isExporting
                    )
                    .padding(.horizontal, 16)

                    // 日付ベースの履歴表示
                    DailyEntriesPageView(
                        currentDate: $currentDate,
                        allEntries: Array(entries),
                        onDelete: { offsets in
                            deleteEntries(offsets: offsets)
                        },
                        refreshTrigger: refreshTrigger
                    )

                    // 記録ボタンのためのスペース
                    Spacer()
                        .frame(height: 100)
                }
            }

            // 今すぐ記録ボタン（固定位置）
            VStack {
                RecordButtonView {
                    showingEntryView = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34) // タブバーの高さ + セーフエリア
            }
            .background(Color(UIColor.systemBackground))
        }
        .onAppear {
            // HealthKitデータを更新
            if healthKitManager.isAuthorized {
                healthKitManager.fetchTodaySteps()
                healthKitManager.fetchWeeklySteps()
            }
            // 日付更新タイマーを開始
            startDateUpdateTimer()
        }
        .onDisappear {
            // タイマーを停止
            dateUpdateTimer?.invalidate()
            dateUpdateTimer = nil
        }
        // 通知タップで記録画面を開く処理
        .onChange(of: appState.shouldShowEntryView) { oldValue, newValue in
            print("🎯 shouldShowEntryView変更検出: \(oldValue) -> \(newValue)")
            if newValue {
                print("🎯 記録画面を表示します")
                showingEntryView = true     
                // フラグをリセット
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🎯 shouldShowEntryViewをfalseにリセット")
                    appState.shouldShowEntryView = false
                }
            }
        }
        .sheet(isPresented: $showingEntryView, onDismiss: {
            appState.entrySlotStart = nil
            appState.entrySlotEnd = nil
        }) {
            MindfulnessEntryView(
                slotStart: appState.entrySlotStart,
                slotEnd: appState.entrySlotEnd
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .alert("データエクスポート完了", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text("記録データがクリップボードにコピーされました。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // CoreDataの変更通知を受け取った時にビューを更新
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // アプリがフォアグラウンドに戻った時に日付をチェック
            checkAndUpdateCurrentDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // 日付が変わった時に現在日付を更新
            checkAndUpdateCurrentDate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func todayEntriesCount() -> Int {
        let calendar = Calendar.current
        let today = Date()
        return entries.filter { entry in
            calendar.isDate(entry.timestamp ?? Date(), inSameDayAs: today)
        }.count
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            let entriesArray = Array(entries)
            offsets.map { entriesArray[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                print("削除エラー: \(error)")
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            var csvContent = "日時,気分,活動ジャンル,メモ\n"
            
            for entry in Array(entries).reversed() {
                let timestamp = dateFormatter.string(from: entry.timestamp ?? Date())
                let mood = entry.mood ?? ""
                let genre = entry.genre ?? ""
                let note = (entry.feelings ?? "").replacingOccurrences(of: "\n", with: " ")
                csvContent += "\(timestamp),\(mood),\(genre),\(note)\n"
            }
            
            DispatchQueue.main.async {
                UIPasteboard.general.string = csvContent
                isExporting = false
                showingExportAlert = true
            }
        }
    }
    
    private func startDateUpdateTimer() {
        dateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            checkAndUpdateCurrentDate()
        }
    }
    
    private func checkAndUpdateCurrentDate() {
        let calendar = Calendar.current
        let now = Date()
        
        if !calendar.isDate(currentDate, inSameDayAs: now) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentDate = now
            }
        }
    }
}

#Preview {
    HomeTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}
