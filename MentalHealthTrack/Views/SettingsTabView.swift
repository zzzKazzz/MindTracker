import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            SettingsView()
                .navigationTitle("設定")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsTabView()
}
