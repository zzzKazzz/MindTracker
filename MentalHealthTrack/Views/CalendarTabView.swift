import SwiftUI
import CoreData

struct CalendarTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // CoreDataからMindfulnessDataを取得
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>
    
    // 選択された日付の記録一覧画面の表示状態を管理
    @State private var showingDateEntries = false
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        NavigationView {
            CalendarView(entries: Array(entries)) { date in
                selectedDate = date
                showingDateEntries = true
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingDateEntries) {
            if let selectedDate = selectedDate {
                DateEntriesView(
                    date: selectedDate,
                    entries: entriesForDate(selectedDate)
                )
            }
        }
    }
    
    private func entriesForDate(_ date: Date) -> [MindfulnessData] {
        return MindfulnessDataHelper.entriesForDate(date, from: Array(entries))
    }
}

#Preview {
    CalendarTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
