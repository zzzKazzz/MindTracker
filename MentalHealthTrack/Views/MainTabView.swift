import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // ホームタブ（現在のContentView）
            HomeTabView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)

            // 購入履歴タブ
            PurchaseHistoryTabView()
                .tabItem {
                    Image(systemName: "cart")
                    Text("購入履歴")
                }
                .tag(1)

            // カレンダータブ
            CalendarTabView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
                .tag(2)

            // My統計タブ
            MoodClockTabView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("My統計")
                }
                .tag(3)

            // 設定タブ
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}
