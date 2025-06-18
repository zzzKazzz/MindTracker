import SwiftUI
import CoreData
import UserNotifications

// エクスポート用のデータ構造
struct ExportEntry: Codable {
    let date: String
    let time: String
    let mood: String
    let activity: String
    let feeling: String
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appState: AppState
    @StateObject private var healthKitManager = HealthKitManager.shared
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>
    
    @State private var showingEntryView = false
    @State private var showingSettings = false
    @State private var showingCalendar = false
    @State private var selectedDate: Date? = nil
    @State private var showingDateEntries = false
    @State private var showingAIAnalysis = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingExportAlert = false
    @State private var isExporting = false
    
    // SettingsViewと同じ設定を参照
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    var body: some View {
        NavigationView {
            VStack {
                // スクリーンタイム円グラフ
                // TODO:課金アカウントになったら解放予定
                // ScreenTimeCardView()
                //     .padding(.horizontal)
                
                // 統計情報カード
                StatisticsCardView(
                    todayCount: todayEntriesCount(),
                    totalCount: entries.count,
                    todaySteps: healthKitManager.todaySteps,
                    isHealthAuthorized: healthKitManager.isAuthorized
                )
                
                // 履歴一覧
                if entries.isEmpty {
                    EmptyStateView()
                } else {
                    EntriesListView(entries: Array(entries)) { offsets in
                        deleteEntries(offsets: offsets)
                    }
                }
                // 今すぐ記録ボタン
                RecordButtonView {
                    showingEntryView = true
                }
            }
            .navigationTitle("Compass for the Mind")
            .toolbar {
                // TODO:YouTubeの視聴履歴を使いたい場合は
                // ユーザーにGoogle Takeoutを使ってエクスポートしてもらい、それをアプリ内のAPIで読み込ませる。面倒だな。
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                            .font(.title2)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // TODO:規模がデカくなったらファイル化が必要
                    // エクスポートボタン
                    Button(action: { exportData() }) {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                        }
                    }
                    .disabled(isExporting)
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                    }
                }
            }
        }
        .onAppear {
            // アプリ起動時に通知状態をチェック
            checkNotificationStatus()

            // HealthKitデータを更新
            if healthKitManager.isAuthorized {
                healthKitManager.fetchTodaySteps()
                healthKitManager.fetchWeeklySteps()
            }

            // 1秒後に権限リクエスト（ユーザーエクスペリエンス向上のため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                requestNotificationPermissionIfNeeded()
            }
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
        .sheet(isPresented: $showingEntryView) {
            MindfulnessEntryView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView(entries: Array(entries)) { date in
                selectedDate = date
                showingCalendar = false
                showingDateEntries = true
            }
        }
        .sheet(isPresented: $showingDateEntries) {
            if let selectedDate = selectedDate {
                DateEntriesView(
                    date: selectedDate,
                    entries: entriesForDate(selectedDate)
                )
            }
        }
        .alert("データエクスポート完了", isPresented: $showingExportAlert) {
        Button("OK") { }
        } message: {
            Text("記録データがクリップボードにコピーされました。")
        }
    }
    
    // MARK: - Computed Properties
    private var notificationStatusText: String {
        switch notificationStatus {
        case .notDetermined: return "未確認"
        case .denied: return "拒否"
        case .authorized: return "許可"
        case .provisional: return "暫定許可"
        case .ephemeral: return "一時許可"
        @unknown default: return "不明"
        }
    }
    
    // MARK: - Private Methods
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
                print("現在の通知ステータス: \(settings.authorizationStatus.rawValue)")
                print("アラート設定: \(settings.alertSetting.rawValue)")
                print("サウンド設定: \(settings.soundSetting.rawValue)")
                print("バッジ設定: \(settings.badgeSetting.rawValue)")
            }
        }
    }
    
    private func requestNotificationPermissionIfNeeded() {
        // 現在の通知ステータスを確認
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
                
                // まだ決定されていない場合のみリクエスト
                if settings.authorizationStatus == .notDetermined {
                    print("通知権限をリクエストします...")
                    requestNotificationPermission()
                } else {
                    print("通知権限は既に設定済みです: \(settings.authorizationStatus)")
                    
                    // 既に許可されている場合は設定に従って通知をスケジュール
                    if settings.authorizationStatus == .authorized && notificationsEnabled {
                        NotificationManager.shared.scheduleUserDefinedNotifications()
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("通知権限リクエストエラー: \(error)")
                    return
                }
                
                print("通知権限リクエスト結果: \(granted)")
                
                if granted {
                    print("通知権限が許可されました")
                    // 設定に基づいて通知をスケジュール（SettingsViewの設定を使用）
                    if notificationsEnabled {
                        NotificationManager.shared.scheduleUserDefinedNotifications()
                    }
                    // テスト通知を送信
                    self.sendTestNotification()
                } else {
                    print("通知権限が拒否されました")
                }
                
                // 最新の状態を再取得
                self.checkNotificationStatus()
            }
        }
    }
    
    private func scheduleReminderNotifications() {
        // 既存の通知をクリア
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 複数時間帯でのリマインダー設定
        let reminderTimes = [
            (hour: 9, minute: 0, message: "おはようございます！今朝の気持ちはいかがですか？"),
            (hour: 14, minute: 0, message: "午後の一息、今の気持ちを記録しませんか？"),
            (hour: 20, minute: 0, message: "一日お疲れさまでした。今日の気持ちを振り返ってみましょう")
        ]
        
        for (index, time) in reminderTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "気持ちの記録"
            content.body = time.message
            content.sound = .default
            content.badge = 1
            
            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "dailyReminder_\(index)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("通知スケジュールエラー (\(time.hour):00): \(error)")
                } else {
                    print("リマインダー通知がスケジュールされました（毎日\(time.hour):00）")
                }
            }
        }
        
        // スケジュールされた通知を確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                print("スケジュール済み通知数: \(requests.count)")
                for request in requests {
                    print("通知ID: \(request.identifier)")
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let hour = trigger.dateComponents.hour ?? 0
                        let minute = trigger.dateComponents.minute ?? 0
                        print("  時刻: \(hour):\(String(format: "%02d", minute))")
                    }
                }
            }
        }
    }
    
    // テスト用の即座に表示される通知
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = "通知設定が正常に動作しています！"
        content.sound = .default
        
        // 5秒後に通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "testNotification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("テスト通知エラー: \(error)")
            } else {
                print("テスト通知が5秒後にスケジュールされました")
            }
        }
    }
    
    // テスト用の任意の時間後に通知
    private func scheduleTestNotification(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = "\(Int(seconds))秒後の通知テストです！"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "testNotification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("テスト通知エラー: \(error)")
            } else {
                print("テスト通知が\(Int(seconds))秒後にスケジュールされました")
            }
        }
    }
    
    private func todayEntriesCount() -> Int {
        return MindfulnessDataHelper.todayEntriesCount(from: Array(entries))
    }
    
    private func entriesForDate(_ date: Date) -> [MindfulnessData] {
        return MindfulnessDataHelper.entriesForDate(date, from: Array(entries))
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { entries[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("削除エラー: \(error.localizedDescription)")
            }
        }
    }

    private func exportData() {
        // エクスポート開始
        isExporting = true

        // バックグラウンドで処理を実行
        DispatchQueue.global(qos: .userInitiated).async {
            // エクスポート用の日付フォーマッター
            let exportDateFormatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }()

            let exportTimeFormatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter
            }()

            let exportEntries = Array(self.entries).map { entry in
                let timestamp = entry.timestamp ?? Date()
                let endTime = timestamp
                let startTime = Calendar.current.date(byAdding: .minute, value: -30, to: endTime) ?? endTime

                // 絵文字をenum名に変換
                let moodString = self.convertEmojiToMoodName(entry.mood ?? "😐")

                return ExportEntry(
                    date: exportDateFormatter.string(from: timestamp),
                    time: "\(exportTimeFormatter.string(from: startTime))-\(exportTimeFormatter.string(from: endTime))",
                    mood: moodString,
                    activity: entry.activity ?? "",
                    feeling: entry.feelings ?? ""
                )
            }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(exportEntries)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    // プロンプトを追加
                    let analysisPrompt = """

                    あなたは優秀なデータアナリスト兼心理コーチです。 以下の私の「支出履歴」「動画視聴履歴」「行動ログ」「日々の感情記録」などをもとに、 私自身も気づいていない価値観、性格傾向、無意識のパターンを分析してください。
                    その上で、
                    1. 私の幸福度が高くなる「時間・行動・環境・仕事」の特徴
                    2. 逆に「自分に向いていない行動・場所・関わり方」
                    3. 無意識に避けているが実は自分に合っているかもしれない選択肢
                    4. 私の強み・弱みやユニークな資質、それがどのような仕事やライフスタイルで活きるか
                    5. 私がより幸福度を最大化するための具体的アドバイスや問いかけ
                    を、根拠（データのどの部分から読み取ったか、なぜそう推論したか）付きで教えてください。
                    私が自分自身を「もっと深く理解」し、「今後の意思決定の質を上げる」ために役立つ内容にしてください。
                    """

                    let finalContent = jsonString + analysisPrompt

                    // メインスレッドでUI更新
                    DispatchQueue.main.async {
                        UIPasteboard.general.string = finalContent
                        self.isExporting = false
                        self.showingExportAlert = true
                        print("エクスポート完了: \(exportEntries.count)件の記録")
                    }
                }
            } catch {
                // エラー時もメインスレッドでUI更新
                DispatchQueue.main.async {
                    self.isExporting = false
                    print("エクスポートエラー: \(error.localizedDescription)")
                }
            }
        }
    }

    // 絵文字をenum名に変換するヘルパー関数
    private func convertEmojiToMoodName(_ emoji: String) -> String {
        switch emoji {
        case "😊": return "veryHappy"
        case "🙂": return "happy"
        case "😐": return "neutral"
        case "😔": return "sad"
        case "😢": return "verySad"
        default: return "neutral"
        }
    }
}

// MARK: - Subviews
struct StatisticsCardView: View {
    let todayCount: Int
    let totalCount: Int
    let todaySteps: Int
    let isHealthAuthorized: Bool

    var body: some View {
        VStack(spacing: 16) {
            // 記録統計
            HStack {
                VStack(alignment: .leading) {
                    Text("今日の記録")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(todayCount)回")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("総記録数")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(totalCount)回")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)

            // ヘルスデータ
            if isHealthAuthorized {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.orange)
                            Text("今日の歩数")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        Text("\(todaySteps.formatted())歩")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("健康連携")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        Text("有効")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "heart.slash")
                                .foregroundColor(.gray)
                            Text("ヘルスケア連携")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        Text("未許可")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button("許可する") {
                        HealthKitManager.shared.requestAuthorization()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}

struct RecordButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("今の気持ちを記録する")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("まだ記録がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("「今の気持ちを記録する」ボタンから\n最初の記録を始めましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
}

struct EntriesListView: View {
    let entries: [MindfulnessData]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(entries.indices, id: \.self) { index in
                EntryRowView(entry: entries[index])
            }
            .onDelete(perform: onDelete)
        }
    }
}

struct EntryRowView: View {
    let entry: MindfulnessData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.mood ?? "😐")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateFormatters.dateTime.string(from: entry.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(DateFormatters.timeRange(from: entry.timestamp ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Text("活動: \(entry.activity ?? "")")
                .font(.subheadline)
                .lineLimit(2)
            
            Text("感情: \(entry.feelings ?? "")")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppState())
    }
}

// 6. 通知権限確認用の関数も追加
extension ContentView {
    private func debugNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🔔 === 通知設定デバッグ情報 ===")
                print("🔔 認証状態: \(settings.authorizationStatus.rawValue)")
                print("🔔 アラート設定: \(settings.alertSetting.rawValue)")
                print("🔔 サウンド設定: \(settings.soundSetting.rawValue)")
                print("🔔 バッジ設定: \(settings.badgeSetting.rawValue)")
                print("🔔 通知センター設定: \(settings.notificationCenterSetting.rawValue)")
                print("🔔 ロック画面設定: \(settings.lockScreenSetting.rawValue)")
                print("🔔 ===========================")
            }
        }
        // 保留中の通知も確認
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("🔔 保留中の通知数: \(requests.count)")
            for request in requests {
                print("🔔 通知ID: \(request.identifier)")
                print("🔔 タイトル: \(request.content.title)")
            }
        }
    }
}