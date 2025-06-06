import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("morning_notification_enabled") private var morningEnabled = true
    @AppStorage("lunch_notification_enabled") private var lunchEnabled = true
    @AppStorage("evening_notification_enabled") private var eveningEnabled = true
    @AppStorage("morning_notification_hour") private var morningHour = 9
    @AppStorage("morning_notification_minute") private var morningMinute = 0
    @AppStorage("lunch_notification_hour") private var lunchHour = 13
    @AppStorage("lunch_notification_minute") private var lunchMinute = 0
    @AppStorage("evening_notification_hour") private var eveningHour = 20
    @AppStorage("evening_notification_minute") private var eveningMinute = 0
    
    @State private var showingTimePicker = false
    @State private var currentTimeType: TimeType?
    @Environment(\.presentationMode) var presentationMode
    
    enum TimeType {
        case morning, lunch, evening
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("リマインダー設定")) {
                    // 朝の通知
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("朝のリマインダー", isOn: $morningEnabled)
                                .onChange(of: morningEnabled) { _ in
                                    updateNotifications()
                                }
                        }
                        
                        if morningEnabled {
                            Button(action: {
                                currentTimeType = .morning
                                showingTimePicker = true
                            }) {
                                HStack {
                                    Text("時刻:")
                                    Spacer()
                                    Text(String(format: "%02d:%02d", morningHour, morningMinute))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    // 昼の通知
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("昼のリマインダー", isOn: $lunchEnabled)
                                .onChange(of: lunchEnabled) { _ in
                                    updateNotifications()
                                }
                        }
                        
                        if lunchEnabled {
                            Button(action: {
                                currentTimeType = .lunch
                                showingTimePicker = true
                            }) {
                                HStack {
                                    Text("時刻:")
                                    Spacer()
                                    Text(String(format: "%02d:%02d", lunchHour, lunchMinute))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    // 夜の通知
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("夜のリマインダー", isOn: $eveningEnabled)
                                .onChange(of: eveningEnabled) { _ in
                                    updateNotifications()
                                }
                        }
                        
                        if eveningEnabled {
                            Button(action: {
                                currentTimeType = .evening
                                showingTimePicker = true
                            }) {
                                HStack {
                                    Text("時刻:")
                                    Spacer()
                                    Text(String(format: "%02d:%02d", eveningHour, eveningMinute))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("通知について")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("通知の効果")
                            .font(.headline)
                        Text("定期的なリマインダーは、感情の記録習慣を身につけるのに役立ちます。自分の心の状態を意識する機会を増やし、メンタルヘルスの向上につながります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("通知設定をリセット") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(
                timeType: currentTimeType ?? .morning,
                hour: getCurrentHour(),
                minute: getCurrentMinute()
            ) { hour, minute in
                setTime(hour: hour, minute: minute)
                updateNotifications()
            }
        }
    }
    
    private func getCurrentHour() -> Int {
        switch currentTimeType {
        case .morning: return morningHour
        case .lunch: return lunchHour
        case .evening: return eveningHour
        case .none: return 9
        }
    }
    
    private func getCurrentMinute() -> Int {
        switch currentTimeType {
        case .morning: return morningMinute
        case .lunch: return lunchMinute
        case .evening: return eveningMinute
        case .none: return 0
        }
    }
    
    private func setTime(hour: Int, minute: Int) {
        switch currentTimeType {
        case .morning:
            morningHour = hour
            morningMinute = minute
        case .lunch:
            lunchHour = hour
            lunchMinute = minute
        case .evening:
            eveningHour = hour
            eveningMinute = minute
        case .none:
            break
        }
    }
    
    private func updateNotifications() {
        NotificationManager.shared.scheduleCustomNotifications(
            morningEnabled: morningEnabled,
            morningHour: morningHour,
            morningMinute: morningMinute,
            lunchEnabled: lunchEnabled,
            lunchHour: lunchHour,
            lunchMinute: lunchMinute,
            eveningEnabled: eveningEnabled,
            eveningHour: eveningHour,
            eveningMinute: eveningMinute
        )
    }
    
    private func resetToDefaults() {
        morningEnabled = true
        lunchEnabled = true
        eveningEnabled = true
        morningHour = 9
        morningMinute = 0
        lunchHour = 13
        lunchMinute = 0
        eveningHour = 20
        eveningMinute = 0
        updateNotifications()
    }
}

struct TimePickerView: View {
    let timeType: NotificationSettingsView.TimeType
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    let onTimeSelected: (Int, Int) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    init(timeType: NotificationSettingsView.TimeType, hour: Int, minute: Int, onTimeSelected: @escaping (Int, Int) -> Void) {
        self.timeType = timeType
        self._selectedHour = State(initialValue: hour)
        self._selectedMinute = State(initialValue: minute)
        self.onTimeSelected = onTimeSelected
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(timeTitle)
                    .font(.headline)
                    .padding()
                
                HStack {
                    Picker("時", selection: $selectedHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80)
                    
                    Text(":")
                        .font(.title)
                    
                    Picker("分", selection: $selectedMinute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 80)
                }
                
                Spacer()
            }
            .navigationTitle("時刻設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("設定") {
                        onTimeSelected(selectedHour, selectedMinute)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var timeTitle: String {
        switch timeType {
        case .morning: return "朝のリマインダー時刻"
        case .lunch: return "昼のリマインダー時刻"
        case .evening: return "夜のリマインダー時刻"
        }
    }
}

func scheduleCustomReminder(title: String, body: String, hour: Int, minute: Int) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.default
    
    var dateComponents = DateComponents()
    dateComponents.hour = hour
    dateComponents.minute = minute
    
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    
    // 一意のIDを生成（時間ベース）
    let identifier = "customReminder_\(hour)_\(minute)"
    
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("通知のスケジュール中にエラーが発生しました: \(error)")
        } else {
            print("カスタムリマインダーが正常にスケジュールされました: \(title) at \(hour):\(minute)")
        }
    }
}

// NotificationManagerの拡張
extension NotificationManager {
    func scheduleCustomNotifications(
        morningEnabled: Bool, morningHour: Int, morningMinute: Int,
        lunchEnabled: Bool, lunchHour: Int, lunchMinute: Int,
        eveningEnabled: Bool, eveningHour: Int, eveningMinute: Int
    ) {
        // 既存の通知をクリア
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if morningEnabled {
            scheduleCustomReminder(
                title: "おはようございます！",
                body: "今日も一日、心の状態を記録してみませんか？",
                hour: morningHour,
                minute: morningMinute
            )
        }
        
        if lunchEnabled {
            scheduleCustomReminder(
                title: "お疲れ様です",
                body: "ランチタイムの気持ちはいかがですか？",
                hour: lunchHour,
                minute: lunchMinute
            )
        }
        
        if eveningEnabled {
            scheduleCustomReminder(
                title: "今日も一日お疲れ様でした",
                body: "今日の気持ちを振り返って記録してみましょう",
                hour: eveningHour,
                minute: eveningMinute
            )
        }
    }
}
