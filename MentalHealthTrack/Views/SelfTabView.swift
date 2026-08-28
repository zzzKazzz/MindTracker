import SwiftUI
import CoreData

// MARK: - WallPunchView

// 決断の壁打ち。断定的なアドバイスはせず、
// 自分モデル・直近の状態・確認すべき問いを返す。
struct WallPunchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var decisionText = ""
    @State private var reflection: WallPunchReflection?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("いま迷っていることを書いてください。転職、大きな買い物、続けるかやめるか、なんでも。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $decisionText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                            )
                        if decisionText.isEmpty {
                            Text("例: 転職するか迷っている")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    Button(action: generateReflection) {
                        Text("自分モデルと照らす")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(decisionText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(decisionText.isEmpty)

                    if let reflection = reflection {
                        reflectionSection("いまの自分の状態", icon: "waveform.path.ecg", lines: reflection.currentState)
                        reflectionSection("自分の癖との照合", icon: "exclamationmark.triangle", lines: reflection.traps)
                        reflectionSection("決める前に確認したい問い", icon: "questionmark.circle", lines: reflection.questions)

                        Text("これは答えではなく、自分の記録から出した確認材料です。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("決断の壁打ち")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func reflectionSection(_ title: String, icon: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Text("・")
                    Text(line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func generateReflection() {
        reflection = WallPunchReflection.build(
            decision: decisionText,
            context: viewContext
        )
    }
}

// MARK: - WallPunchReflection

struct WallPunchReflection {
    let currentState: [String]
    let traps: [String]
    let questions: [String]

    static func build(decision: String, context: NSManagedObjectContext) -> WallPunchReflection {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        // 直近14日の気分
        let request: NSFetchRequest<MindfulnessData> = MindfulnessData.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", twoWeeksAgo as NSDate)
        let recentMoods = (try? context.fetch(request)) ?? []
        let scores = recentMoods.compactMap { SelfModelUpdater.moodScore($0.mood) }
        let average = scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)

        var currentState: [String] = []
        if let average = average {
            let label = average >= 3.5 ? "良い" : (average >= 2.5 ? "普通" : "低め")
            currentState.append("直近2週間の気分は「\(label)」（平均\(String(format: "%.1f", average))/5、\(scores.count)件）。")
            if average < 2.5 {
                currentState.append("気分が低い時期の大きな決断は、後から見え方が変わりやすい。")
            }
        } else {
            currentState.append("直近2週間の気分記録がない。今の状態を測る材料が不足している。")
        }

        // 自分モデルの癖
        var traps: [String] = []
        if let model = SelfModelUpdater.current(context: context) {
            if let decisionTraps = model.decisionTraps, !decisionTraps.isEmpty {
                traps.append(contentsOf: decisionTraps.components(separatedBy: "\n"))
            }
            let isPurchaseDecision = ["買", "購入", "欲しい"].contains { decision.contains($0) }
            if isPurchaseDecision, let spending = model.spendingTriggers, !spending.isEmpty {
                traps.append(contentsOf: spending.components(separatedBy: "\n"))
            }
        }
        if traps.isEmpty {
            traps.append("サマリーが未作成か、まだ癖が抽出されていない。MyStats で更新できる。")
        }

        // 確認の問い
        var questions = [
            "1週間後の自分も同じ判断をするか？",
            "これは「近づきたいもの」への決断か、「逃げたいもの」からの決断か？",
            "最悪のケースになったとき、取り返しはつくか？"
        ]
        if let average = average, average < 2.5 {
            questions.insert("今は気分が低め。決断を1週間延期する選択肢はないか？", at: 0)
        }

        return WallPunchReflection(currentState: currentState, traps: traps, questions: questions)
    }
}

#Preview {
    WallPunchView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
