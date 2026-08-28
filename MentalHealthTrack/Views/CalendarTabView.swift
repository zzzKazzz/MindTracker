import SwiftUI
import CoreData

struct CalendarTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>

    @State private var focusedDate = Date()
    @State private var scope: CalendarScope = .week
    @State private var showingDateEntries = false
    @State private var selectedDate: Date?
    @State private var showingEntryView = false
    @State private var entryToEdit: MindfulnessData?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CalendarHubView(
                    entries: Array(entries),
                    focusedDate: $focusedDate,
                    scope: $scope,
                    onSelectDate: { date in
                        selectedDate = date
                        showingDateEntries = true
                    },
                    onSelectEntry: { entry in
                        entryToEdit = entry
                    },
                    onSelectEmptySlot: { start, end in
                        appState.entrySlotStart = start
                        appState.entrySlotEnd = end
                        showingEntryView = true
                    }
                )

                RecordButtonView {
                    appState.entrySlotStart = nil
                    appState.entrySlotEnd = nil
                    showingEntryView = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingDateEntries) {
            if let selectedDate {
                DateEntriesView(
                    date: selectedDate,
                    entries: MindfulnessDataHelper.entriesForDate(selectedDate, from: Array(entries))
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(item: $entryToEdit) { entry in
            MindfulnessEditView(entry: entry)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingEntryView, onDismiss: {
            appState.entrySlotStart = nil
            appState.entrySlotEnd = nil
        }) {
            MindfulnessEntryView(
                slotStart: appState.entrySlotStart,
                slotEnd: appState.entrySlotEnd
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: appState.shouldShowEntryView) { _, newValue in
            if newValue {
                showingEntryView = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appState.shouldShowEntryView = false
                }
            }
        }
    }
}

#Preview {
    CalendarTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}
