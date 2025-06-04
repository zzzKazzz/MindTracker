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
    @State private var showingCalendar = false
    @State private var selectedDate: Date? = nil
    @State private var showingDateEntries = false
    @State private var showingAIAnalysis = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 統計情報カード
                StatisticsCardView(
                    todayCount: todayEntriesCount(),
                    totalCount: entries.count
                )
                
                // 今すぐ記録ボタン
                RecordButtonView {
                    showingEntryView = true
                }
                
                // 履歴一覧
                if entries.isEmpty {
                    EmptyStateView()
                } else {
                    EntriesListView(entries: Array(entries)) { offsets in
                        deleteEntries(offsets: offsets)
                    }
                }
            }
            .navigationTitle("Compass for the Mind")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                            .font(.title2)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingAIAnalysis = true }) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                    }

                    Button(action: { showingSettings = true }) {
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
        .sheet(isPresented: $showingAIAnalysis) {
            AIAnalysisView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Private Methods
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
}

// MARK: - Subviews
struct StatisticsCardView: View {
    let todayCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
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
    }
}