import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CalendarTabView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
                .tag(0)

            MyStatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("MyStats")
                }
                .tag(1)

            SettingsTabView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}
