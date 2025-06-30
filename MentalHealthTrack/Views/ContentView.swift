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
    let tags: String
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appState: AppState
    @StateObject private var healthKitManager = HealthKitManager.shared
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>
    
    // 新規記録画面の表示状態を管理
    @State private var showingEntryView = false
    // 通知権限の現在の状態を管理
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    // データエクスポート完了アラートの表示状態を管理
    @State private var showingExportAlert = false
    // データエクスポート処理中の状態を管理
    @State private var isExporting = false
    // 日付ベースのページング用の現在表示日付を管理
    @State private var currentDate = Date()
    // ビューの強制更新用
    @State private var refreshTrigger = false
    // 日付更新用のタイマー
    @State private var dateUpdateTimer: Timer?
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
                // TODO:日付ベースの履歴表示
                DailyEntriesPageView(
                    currentDate: $currentDate,
                    allEntries: Array(entries),
                    onDelete: { offsets in
                        deleteEntries(offsets: offsets)
                    },
                    refreshTrigger: refreshTrigger
                )
                // 今すぐ記録ボタン
                RecordButtonView {
                    showingEntryView = true
                }
            }
            .navigationTitle("Footstep of the Mind")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showingEntryView) {
            MindfulnessEntryView()
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

    // 日付更新タイマーを開始
    private func startDateUpdateTimer() {
        // 既存のタイマーがあれば停止
        dateUpdateTimer?.invalidate()

        // 1分ごとに日付をチェック
        dateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            checkAndUpdateCurrentDate()
        }
    }

    // 現在日付をチェックして必要に応じて更新
    private func checkAndUpdateCurrentDate() {
        let now = Date()
        let calendar = Calendar.current

        // 現在表示している日付が今日で、実際の今日と異なる場合は更新
        if calendar.isDateInToday(currentDate) && !calendar.isDate(currentDate, inSameDayAs: now) {
            print("📅 日付が変更されました。currentDateを更新します: \(DateFormatters.dateOnly.string(from: currentDate)) -> \(DateFormatters.dateOnly.string(from: now))")
            withAnimation(.easeInOut(duration: 0.3)) {
                currentDate = now
            }
            // HealthKitデータも更新
            if healthKitManager.isAuthorized {
                healthKitManager.fetchTodaySteps()
                healthKitManager.fetchWeeklySteps()
            }
        }
    }

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
            (hour: 9, minute: 0, message: "おはようございます！☀️今日も一日元気よく!"),
            (hour: 14, minute: 0, message: "午後の一息にサクッと今の気持ちを記録しましょう!"),
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
                    feeling: entry.feelings ?? "",
                    tags: entry.tags ?? ""
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

    // 気分文字列をenum名に変換するヘルパー関数
    private func convertEmojiToMoodName(_ moodString: String) -> String {
        let mood = getMoodFromString(moodString)
        switch mood {
        case .veryHappy: return "veryHappy"
        case .happy: return "happy"
        case .neutral: return "neutral"
        case .sad: return "sad"
        case .verySad: return "verySad"
        }
    }

    // 文字列から気分を取得するヘルパー関数（ContentView用）
    private func getMoodFromString(_ moodString: String) -> Mood {
        // まず新しい形式（rawValue）で検索
        if let mood = Mood.allCases.first(where: { $0.rawValue == moodString }) {
            return mood
        } else {
            // 絵文字形式の場合は変換
            return Mood.fromEmoji(moodString)
        }
    }
}

// MARK: - Subviews
struct StatisticsCardView: View {
    let todayCount: Int
    let totalCount: Int
    let todaySteps: Int
    let isHealthAuthorized: Bool
    let onExport: (() -> Void)?
    let isExporting: Bool

    init(todayCount: Int, totalCount: Int, todaySteps: Int, isHealthAuthorized: Bool, onExport: (() -> Void)? = nil, isExporting: Bool = false) {
        self.todayCount = todayCount
        self.totalCount = totalCount
        self.todaySteps = todaySteps
        self.isHealthAuthorized = isHealthAuthorized
        self.onExport = onExport
        self.isExporting = isExporting
    }

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

                // エクスポートボタン
                if let onExport = onExport {
                    Button(action: onExport) {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                        }
                    }
                    .disabled(isExporting)
                    .padding(.leading, 8)
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
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("今の気持ちを記録する")
                    .fontWeight(.semibold)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(1.0)
            .animation(
                .easeInOut(duration: 0.2),
                value: false
            )
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

struct DailyEntriesPageView: View {
    @Binding var currentDate: Date
    let allEntries: [MindfulnessData]
    let onDelete: (IndexSet) -> Void
    let refreshTrigger: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // 日付ナビゲーションヘッダー
            DateNavigationHeader(currentDate: $currentDate)

            // 現在の日付のエントリ表示（高さ固定）
            DailyEntriesView(
                date: currentDate,
                entries: entriesForDate(currentDate),
                onDelete: onDelete,
                refreshTrigger: refreshTrigger
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func entriesForDate(_ date: Date) -> [MindfulnessData] {
        return MindfulnessDataHelper.entriesForDate(date, from: allEntries)
    }
}

struct DateNavigationHeader: View {
    @Binding var currentDate: Date
    private let calendar = Calendar.current

    // 次の日に移動可能かどうかを判定
    private var canMoveToNextDay: Bool {
        let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        return nextDate <= Date()
    }

    var body: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle()) // タップ時のハイライトを無効化

            Spacer()

            VStack(spacing: 2) {
                Text(DateFormatters.dateOnly.string(from: currentDate))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentDate)

                if calendar.isDateInToday(currentDate) {
                    Text("今日")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .transition(.opacity.combined(with: .scale))
                } else if calendar.isDateInYesterday(currentDate) {
                    Text("昨日")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                        .transition(.opacity.combined(with: .scale))
                } else if calendar.isDateInTomorrow(currentDate) {
                    Text("明日")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                        .transition(.opacity.combined(with: .scale))
                }
            }

            Spacer()

            Button(action: {
                let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                // 未来の日付には移動しない（今日まで）
                if nextDate <= Date() {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                        currentDate = nextDate
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(canMoveToNextDay ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle()) // タップ時のハイライトを無効化
            .disabled(!canMoveToNextDay)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
    }
}

struct DailyEntriesView: View {
    let date: Date
    let entries: [MindfulnessData]
    let onDelete: (IndexSet) -> Void
    let refreshTrigger: Bool
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        GeometryReader { geometry in
            if entries.isEmpty {
                DailyEmptyStateView(date: date)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries.indices, id: \.self) { index in
                        EntryRowView(entry: entries[index], viewContext: viewContext, refreshTrigger: refreshTrigger)
                    }
                    .onDelete(perform: onDelete)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minHeight: 400) // 最小高さを設定
    }
}

struct DailyEmptyStateView: View {
    let date: Date
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            if calendar.isDateInToday(date) {
                Text("今日はまだ記録がありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("「今の気持ちを記録する」ボタンから\n最初の記録を始めましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if date > Date() {
                Text("未来の記録はありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Text("この日の記録はありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(DateFormatters.dateOnly.string(from: date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EntriesListView: View {
    let entries: [MindfulnessData]
    let onDelete: (IndexSet) -> Void
    let refreshTrigger: Bool
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        List {
            ForEach(entries.indices, id: \.self) { index in
                EntryRowView(entry: entries[index], viewContext: viewContext, refreshTrigger: refreshTrigger)
            }
            .onDelete(perform: onDelete)
        }
    }
}

struct EntryRowView: View {
    let entry: MindfulnessData
    let viewContext: NSManagedObjectContext
    let refreshTrigger: Bool
    @State private var showingEditView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 気分アイコン表示
                if let moodString = entry.mood {
                    let mood = getMoodFromString(moodString)
                    Image(systemName: mood.icon)
                        .font(.title2)
                        .foregroundColor(mood.color)
                } else {
                    Image(systemName: Mood.neutral.icon)
                        .font(.title2)
                        .foregroundColor(Mood.neutral.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateFormatters.dateTime.string(from: entry.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(DateFormatters.timeRange(from: entry.timestamp ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // 活動ジャンル表示
                if let genreString = entry.genre, !genreString.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: genreIcon(for: genreString))
                            .font(.caption)
                            .foregroundColor(genreColor(for: genreString))
                        Text(genreString)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(genreColor(for: genreString))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(genreColor(for: genreString).opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(genreColor(for: genreString).opacity(0.3), lineWidth: 1)
                    )
                }
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
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditView = true
        }
        .sheet(isPresented: $showingEditView) {
            MindfulnessEditView(entry: entry)
                .environment(\.managedObjectContext, viewContext)
        }
        .id("\(entry.objectID)-\(refreshTrigger ? "1" : "0")")
    }

    // 文字列から気分を取得するヘルパー関数
    private func getMoodFromString(_ moodString: String) -> Mood {
        // まず新しい形式（rawValue）で検索
        if let mood = Mood.allCases.first(where: { $0.rawValue == moodString }) {
            return mood
        } else {
            // 絵文字形式の場合は変換
            return Mood.fromEmoji(moodString)
        }
    }

    // ジャンルに対応するアイコンを返すヘルパー関数
    private func genreIcon(for genreString: String) -> String {
        switch genreString {
        case "仕事": return "briefcase.fill"
        case "エンタメ": return "tv.fill"
        case "エクササイズ": return "figure.run"
        case "仮眠": return "bed.double.fill"
        case "移動": return "car.fill"
        case "食事": return "fork.knife"
        case "勉強": return "book.fill"
        case "読書": return "book.closed.fill"
        case "創作": return "paintbrush.fill"
        case "家事": return "house.fill"
        case "ソーシャライズ": return "person.2.fill"
        case "リラックス": return "leaf.fill"
        default: return "ellipsis.circle.fill"
        }
    }

    // ジャンルに対応する色を返すヘルパー関数
    private func genreColor(for genreString: String) -> Color {
        switch genreString {
        case "仕事": return .blue
        case "エンタメ": return .purple
        case "エクササイズ": return .green
        case "仮眠": return .indigo
        case "移動": return .orange
        case "食事": return .red
        case "勉強": return .cyan
        case "読書": return .teal
        case "創作": return .yellow
        case "家事": return .brown
        case "ソーシャライズ": return .pink
        case "リラックス": return .mint
        default: return .gray
        }
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