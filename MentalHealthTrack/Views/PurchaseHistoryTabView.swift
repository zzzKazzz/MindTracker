import SwiftUI

struct PurchaseHistoryTabView: View {
    var body: some View {
        NavigationView {
            PurchaseHistoryView()
                .navigationTitle("購入履歴")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    PurchaseHistoryTabView()
}
