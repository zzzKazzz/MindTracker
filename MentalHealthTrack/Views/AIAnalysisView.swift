import CoreData
import SwiftUI

struct AIAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: true)]
    ) private var entries: FetchedResults<MindfulnessData>

    @State private var analysisText: String = "分析中..."
    @State private var isLoading = true

    var body: some View {
        // Grabber（引っ張りハンドル）
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(UIColor.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Spacer()
        }
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                }
                Text(analysisText)
                    .padding()
            }
            .navigationTitle("AI分析")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            ChatGPTManager.shared.analyze(entries: Array(entries)) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let text):
                        analysisText = text
                    case .failure:
                        analysisText = "分析に失敗しました。"
                    }
                }
            }
        }
    }
}

struct AIAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        AIAnalysisView()
            .environment(
                \.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
