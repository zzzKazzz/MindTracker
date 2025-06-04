import SwiftUI
import CoreData

struct DateEntriesView: View {
    let date: Date
    let entries: [MindfulnessData]
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: MindfulnessData?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日付ヘッダー
                DateHeaderView(date: date, dateFormatter: dateFormatter)
                
                // 記録一覧
                if entries.isEmpty {
                    EmptyDateEntriesView()
                } else {
                    DateEntriesListView(
                        entries: entries,
                        onDelete: { entry in
                            entryToDelete = entry
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .navigationTitle("記録詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("記録を削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この記録を削除しますか？")
        }
    }
    
    private func deleteEntry(_ entry: MindfulnessData) {
        withAnimation {
            viewContext.delete(entry)
            
            do {
                try viewContext.save()
            } catch {
                print("削除エラー: \(error.localizedDescription)")
            }
        }
        
        // 削除後、記録が空になった場合は画面を閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let remainingEntries = MindfulnessDataHelper.entriesForDate(date, from: entries)
            if remainingEntries.isEmpty {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Components
struct DateHeaderView: View {
    let date: Date
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(spacing: 8) {
            Text(dateFormatter.string(from: date))
                .font(.title2)
                .fontWeight(.semibold)
            
            if Calendar.current.isDateInToday(date) {
                Text("今日")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
    }
}

struct EmptyDateEntriesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("この日の記録がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("記録を追加するには\nメイン画面から記録を作成してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DateEntriesListView: View {
    let entries: [MindfulnessData]
    let onDelete: (MindfulnessData) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedEntries, id: \.objectID) { entry in
                    DateEntryCardView(entry: entry, onDelete: onDelete)
                }
            }
            .padding()
        }
    }
    
    private var sortedEntries: [MindfulnessData] {
        entries.sorted { (entry1, entry2) in
            let date1 = entry1.timestamp ?? Date.distantPast
            let date2 = entry2.timestamp ?? Date.distantPast
            return date1 > date2
        }
    }
}

struct DateEntryCardView: View {
    let entry: MindfulnessData
    let onDelete: (MindfulnessData) -> Void
    
    @State private var showingFullText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー部分
            HStack {
                // 気分
                Text(entry.mood ?? "😐")
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateFormatters.time.string(from: entry.timestamp ?? Date()))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(DateFormatters.timeRange(from: entry.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 削除ボタン
                Button(action: {
                    onDelete(entry)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            // 活動
            VStack(alignment: .leading, spacing: 4) {
                Text("活動")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(entry.activity ?? "")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 感情・気持ち
            VStack(alignment: .leading, spacing: 4) {
                Text("感情・気持ち")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                let feelingsText = entry.feelings ?? ""
                let shouldTruncate = feelingsText.count > 100
                
                Text(showingFullText || !shouldTruncate ? feelingsText : String(feelingsText.prefix(100)) + "...")
                    .font(.subheadline)
                    .lineLimit(showingFullText ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if shouldTruncate {
                    Button(showingFullText ? "少なく表示" : "もっと見る") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingFullText.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
struct DateEntriesView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleEntry = MindfulnessData(context: context)
        sampleEntry.timestamp = Date()
        sampleEntry.mood = "😊"
        sampleEntry.activity = "散歩"
        sampleEntry.feelings = "とても良い天気で、公園を歩いていると気持ちが晴れやかになりました。鳥のさえずりが聞こえて、自然の音に癒されています。"
        
        return DateEntriesView(date: Date(), entries: [sampleEntry])
            .environment(\.managedObjectContext, context)
    }
}