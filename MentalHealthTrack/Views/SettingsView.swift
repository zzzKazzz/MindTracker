//
//  SettingsView.swift
//  MentalHealthTrack
//
//  Created by KAZ on 6/3/25.
//

// SettingsView.swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationStartTime") private var notificationStartTime = createTime(hour: 9, minute: 0)
    @AppStorage("notificationEndTime") private var notificationEndTime = createTime(hour: 18, minute: 0)
    @AppStorage("notificationInterval") private var notificationInterval = 60
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    @StateObject private var notificationManager = NotificationManager.shared
    
    private let intervalOptions = [
        (30, "30分ごと"),
        (60, "1時間ごと"),
        (120, "2時間ごと")
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
                DatePicker("", selection: $notificationStartTime, displayedComponents: .hourAndMinute)
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
                Text(DateFormatters.notificationPeriod(start: notificationStartTime, end: notificationEndTime))
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
                
                let schedule = notificationManager.getNotificationSchedule(
                    startTime: notificationStartTime,
                    endTime: notificationEndTime,
                    interval: notificationInterval
                )
                
                if schedule.isEmpty {
                    Text("設定された時間帯に通知はありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("1日あたり \(schedule.
