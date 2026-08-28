import SwiftUI

// 購入と視聴をまとめた「データ」タブ
struct PurchaseHistoryTabView: View {
    private enum DataKind: String, CaseIterable {
        case purchase = "購入"
        case watch = "視聴"
    }

    @State private var selectedKind: DataKind = .purchase

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("データ種別", selection: $selectedKind) {
                    ForEach(DataKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                switch selectedKind {
                case .purchase:
                    PurchaseHistoryView()
                case .watch:
                    WatchHistoryView()
                }
            }
            .navigationTitle(selectedKind == .purchase ? "購入履歴" : "視聴の無意識")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    PurchaseHistoryTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
