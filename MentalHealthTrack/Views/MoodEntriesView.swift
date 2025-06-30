import SwiftUI
import CoreData

struct MoodEntriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let moodLevel: String
    let entries: [MindfulnessData]
    
    @State private var entryToDelete: MindfulnessData?
    @State private var showingDeleteAlert = false
    
    // 気分文字列から名前を取得するヘルパー
    private func getMoodName(for moodString: String) -> String {
        let mood = getMoodFromString(moodString)
        return mood.description
    }

    // 気分文字列から色を取得するヘルパー
    private func getMoodColor(for moodString: String) -> Color {
        let mood = getMoodFromString(moodString)
        return mood.color
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                // 記録一覧
                if entries.isEmpty {
                    emptyStateView
                } else {
                    entriesListView
                }
            }
            .navigationTitle("気分別記録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
        .alert("記録を削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この記録を削除しますか？")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // 気分レベル表示
            HStack {
                // 気分アイコン表示
                let mood = getMoodFromString(moodLevel)
                Image(systemName: mood.icon)
                    .font(.system(size: 48))
                    .foregroundColor(mood.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getMoodName(for: moodLevel))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(getMoodColor(for: moodLevel))
                    
                    Text("\(entries.count)件の記録")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 気分アイコン表示
            let mood = getMoodFromString(moodLevel)
            Image(systemName: mood.icon)
                .font(.system(size: 64))
                .foregroundColor(mood.color)
                .opacity(0.3)
            
            Text("「\(getMoodName(for: moodLevel))」の記録がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("この気分レベルの記録がまだありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Entries List View
    private var entriesListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedEntries, id: \.0) { dateString, dayEntries in
                    VStack(alignment: .leading, spacing: 12) {
                        // 日付ヘッダー
                        HStack {
                            Text(dateString)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(dayEntries.count)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // その日の記録一覧
                        ForEach(dayEntries, id: \.objectID) { entry in
                            MoodEntryRowView(entry: entry, moodLevel: moodLevel) {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Computed Properties
    private var groupedEntries: [(String, [MindfulnessData])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日(E)"
        dateFormatter.locale = Locale(identifier: "ja_JP")
        
        let grouped = Dictionary(grouping: sortedEntries) { entry in
            guard let timestamp = entry.timestamp else { return "不明" }
            return dateFormatter.string(from: timestamp)
        }
        
        return grouped.sorted { first, second in
            // 日付文字列から実際の日付を復元して比較
            let firstDate = sortedEntries.first { entry in
                guard let timestamp = entry.timestamp else { return false }
                return dateFormatter.string(from: timestamp) == first.0
            }?.timestamp ?? Date.distantPast
            
            let secondDate = sortedEntries.first { entry in
                guard let timestamp = entry.timestamp else { return false }
                return dateFormatter.string(from: timestamp) == second.0
            }?.timestamp ?? Date.distantPast
            
            return firstDate > secondDate
        }
    }
    
    private var sortedEntries: [MindfulnessData] {
        entries.sorted { entry1, entry2 in
            let date1 = entry1.timestamp ?? Date.distantPast
            let date2 = entry2.timestamp ?? Date.distantPast
            return date1 > date2
        }
    }
    
    // MARK: - Helper Methods
    private func deleteEntry(_ entry: MindfulnessData) {
        withAnimation {
            viewContext.delete(entry)
            
            do {
                try viewContext.save()
            } catch {
                print("削除エラー: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Mood Entry Row View
struct MoodEntryRowView: View {
    let entry: MindfulnessData
    let moodLevel: String
    let onDelete: () -> Void
    
    @State private var showingFullText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 時刻とアクション
            HStack {
                if let timestamp = entry.timestamp {
                    Text(DateFormatter.timeFormatter.string(from: timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // 活動内容
            if let activity = entry.activity, !activity.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("活動")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(activity)
                        .font(.subheadline)
                        .lineLimit(showingFullText ? nil : 3)
                        .onTapGesture {
                            showingFullText.toggle()
                        }
                }
            }
            
            // 感情
            if let feelings = entry.feelings, !feelings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("感情")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(feelings)
                        .font(.subheadline)
                        .lineLimit(showingFullText ? nil : 3)
                        .onTapGesture {
                            showingFullText.toggle()
                        }
                }
            }

        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - Preview
struct MoodEntriesView_Previews: PreviewProvider {
    static var previews: some View {
        MoodEntriesView(moodLevel: "😊", entries: [])
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
