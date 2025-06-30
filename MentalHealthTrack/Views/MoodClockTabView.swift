import SwiftUI
import CoreData

struct MoodClockTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            MoodStatisticsView()
                .environment(\.managedObjectContext, viewContext)
                .navigationTitle("My統計")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MoodClockTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
