// SettingsView.swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationStartTime") private var notificationStartTime = createTime(
        hour: 9, minute: 0)
    @AppStorage("notificationEndTime") private var notificationEndTime = createTime(
        hour: 18, minute: 0)
    @AppStorage("notificationInterval") private var notificationInterval = 60
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    let notificationManager = NotificationManager.shared
    @State private var notificationSchedule: [Date] = []

    private let intervalOptions = [
        (5, "5分ごと"),
        (15, "15分ごと"),
        (30, "30分ごと"),
        (60, "1時間ごと"),
        (120, "2時間ごと"),
    ]

    static func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationView {
            Form {
                notificationSection

                if notificationsEnabled {
                    notificationPreviewSection
                }

                aboutSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var notificationSection: some View {
        Section(header: Text("通知設定")) {
            Toggle("通知を有効にする", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { enabled in
                    if enabled {
                        notificationManager.requestPermission()
                        scheduleNotifications()
                    } else {
                        notificationManager.cancelNotifications()
                    }
                }

            if notificationsEnabled {
                notificationSettingsView
            }
        }
    }

    private var notificationSettingsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("開始")
                    .frame(width: 40, alignment: .leading)
                DatePicker(
                    "", selection: $notificationStartTime, displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: notificationStartTime) { _ in
                    scheduleNotifications()
                }
            }

            HStack {
                Text("終了")
                    .frame(width: 40, alignment: .leading)
                DatePicker("", selection: $notificationEndTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: notificationEndTime) { _ in
                        scheduleNotifications()
                    }
            }

            Picker("通知間隔", selection: $notificationInterval) {
                ForEach(intervalOptions, id: \.0) { interval, label in
                    Text(label).tag(interval)
                }
            }
            .onChange(of: notificationInterval) { _ in
                scheduleNotifications()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("通知時間帯")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(
                    formatNotificationPeriod(start: notificationStartTime, end: notificationEndTime)
                )
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }

    private var notificationPreviewSection: some View {
        Section(header: Text("通知プレビュー")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("実際の通知スケジュール")
                    .font(.headline)

                if notificationSchedule.isEmpty {
                    Text("設定された時間帯に通知はありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("1日あたり \(notificationSchedule.count) 回の通知")
                        .font(.caption)
                        .foregroundColor(.blue)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(notificationSchedule.prefix(10), id: \.self) { time in
                                Text(formatTimeOnly(time))
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }

                            if notificationSchedule.count > 10 {
                                Text("他\(notificationSchedule.count - 10)件...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .onAppear {
            updateNotificationSchedule()
        }
    }

    private var aboutSection: some View {
        Section(header: Text("アプリについて")) {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)

            Link("利用規約", destination: URL(string: "https://example.com/terms")!)

            Button("フィードバックを送信") {
                sendFeedback()
            }
        }
    }

    // MARK: - Helper Methods

    private func scheduleNotifications() {
        guard notificationsEnabled else { return }

        notificationManager.scheduleIntervalNotifications(
            startTime: notificationStartTime,
            endTime: notificationEndTime,
            interval: notificationInterval
        )

        updateNotificationSchedule()
    }

    private func updateNotificationSchedule() {
        notificationSchedule = generateNotificationSchedule(
            startTime: notificationStartTime,
            endTime: notificationEndTime,
            interval: notificationInterval
        )
    }

    private func generateNotificationSchedule(startTime: Date, endTime: Date, interval: Int)
        -> [Date]
    {
        var schedule: [Date] = []
        let calendar = Calendar.current

        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)

        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        var currentMinutes = startMinutes

        while currentMinutes <= endMinutes {
            let hour = currentMinutes / 60
            let minute = currentMinutes % 60

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            if let time = calendar.date(from: components) {
                schedule.append(time)
            }

            currentMinutes += interval
        }

        return schedule
    }

    private func sendFeedback() {
        if let url = URL(string: "mailto:feedback@example.com?subject=アプリのフィードバック") {
            UIApplication.shared.open(url)
        }
    }

    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatNotificationPeriod(start: Date, end: Date) -> String {
        let startString = formatTimeOnly(start)
        let endString = formatTimeOnly(end)
        return "\(startString) 〜 \(endString)"
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
