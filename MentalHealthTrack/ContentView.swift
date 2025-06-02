//
//  ContentView.swift
//  MentalHealthTrack
//
//  Created by KAZ on 5/30/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>
    
    @State private var showingEntryView = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 統計情報カード
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("今日の記録")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("\(todayEntriesCount())回")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("総記録数")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("\(entries.count)回")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 今すぐ記録ボタン
                Button(action: {
                    showingEntryView = true
                }) {
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
                
                // 履歴一覧
                if entries.isEmpty {
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
                } else {
                    List {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.mood ?? "😐")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(entry.timestamp ?? Date()))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatTimeRange(entry.timestamp ?? Date()))
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
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Compass for the Mind")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                    }
                    
                    if !entries.isEmpty {
                        EditButton()
                    }
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
    }
    
    private func todayEntriesCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= today && timestamp < tomorrow
        }.count
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatTimeRange(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        
        let endTime = date
        let startTime = Calendar.current.date(byAdding: .minute, value: -30, to: endTime) ?? endTime
        
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// 設定画面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationTime") private var notificationTime = Date()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通知設定")) {
                    Toggle("通知を有効にする", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { enabled in
                            if enabled {
                                requestNotificationPermission()
                                scheduleNotification()
                            } else {
                                cancelNotifications()
                            }
                        }
                    
                    if notificationsEnabled {
                        DatePicker("通知時刻", selection: $notificationTime, displayedComponents: .hourAndMinute)
                            .onChange(of: notificationTime) { _ in
                                scheduleNotification()
                            }
                    }
                }
                
                Section(header: Text("アプリについて")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("開発者")
                        Spacer()
                        Text("Your Name")
                            .foregroundColor(.secondary)
                    }
                }
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
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知許可が得られました")
            } else if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleNotification() {
        // 既存の通知をキャンセル
        cancelNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "心の記録帳"
        content.body = "今日の気持ちを記録しませんか？"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: notificationTime)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー: \(error.localizedDescription)")
            } else {
                print("通知がスケジュールされました: \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    private func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        print("通知がキャンセルされました")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
