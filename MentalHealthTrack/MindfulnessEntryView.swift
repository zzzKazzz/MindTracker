import SwiftUI
import CoreData

struct MindfulnessEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var activityText: String = ""
    @State private var feelingText: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var showingSaveConfirmation = false
    @State private var entryTime = Date()
    
    enum Mood: String, CaseIterable {
        case veryHappy = "😊"
        case happy = "🙂"
        case neutral = "😐"
        case sad = "😔"
        case verySad = "😢"
        
        var description: String {
            switch self {
            case .veryHappy: return "とても良い"
            case .happy: return "良い"
            case .neutral: return "普通"
            case .sad: return "悪い"
            case .verySad: return "とても悪い"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 8) {
                        Text("30分間の振り返り")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(timeRangeText())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 25) {
                        // 活動内容入力
                        VStack(alignment: .leading, spacing: 12) {
                            Label("この30分間、何をしていましたか？", systemImage: "clock.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $activityText)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        // 気分選択
                        VStack(alignment: .leading, spacing: 12) {
                            Label("気分はいかがでしたか？", systemImage: "heart.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 15) {
                                ForEach(Mood.allCases, id: \.self) { mood in
                                    VStack(spacing: 8) {
                                        Text(mood.rawValue)
                                            .font(.system(size: 32))
                                        Text(mood.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 8)
                                    .background(
                                        selectedMood == mood ?
                                        Color.blue.opacity(0.2) : Color.clear
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedMood == mood ? Color.blue : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .onTapGesture {
                                        selectedMood = mood
                                        // 触覚フィードバック
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                            }
                        }
                        
                        // 感情詳細入力
                        VStack(alignment: .leading, spacing: 12) {
                            Label("どのように感じましたか？（詳細）", systemImage: "text.bubble.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $feelingText)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        // 保存ボタン
                        Button(action: saveEntry) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("記録を保存")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(activityText.isEmpty || feelingText.isEmpty)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("記録完了", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                clearForm()
            }
        } message: {
            Text("30分間の振り返りが正常に保存されました。")
        }
    }
    
    private func timeRangeText() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        
        let endTime = entryTime
        let startTime = Calendar.current.date(byAdding: .minute, value: -30, to: endTime) ?? endTime
        
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    private func saveEntry() {
        // ここでCore Dataやその他のデータベースに保存
        let entry = MindfulnessEntry(
            timestamp: entryTime,
            activity: activityText,
            mood: selectedMood,
            feelings: feelingText
        )
        
        // TODO: データベース保存処理
        saveToDatabase(entry)
        
        // 成功フィードバック
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        showingSaveConfirmation = true
    }
    
    private func clearForm() {
        activityText = ""
        feelingText = ""
        selectedMood = .neutral
        entryTime = Date()
    }
    
    private func saveToDatabase(_ entry: MindfulnessEntry) {
        // Core Dataエンティティを作成
        let mindfulnessData = MindfulnessData(context: viewContext)
        mindfulnessData.id = entry.id
        mindfulnessData.timestamp = entry.timestamp
        mindfulnessData.activity = entry.activity
        mindfulnessData.mood = entry.mood.rawValue
        mindfulnessData.feelings = entry.feelings
        
        // データを保存
        do {
            try viewContext.save()
            print("データが正常に保存されました")
        } catch {
            print("保存エラー: \(error.localizedDescription)")
        }
    }
}

// データモデル
struct MindfulnessEntry {
    let id = UUID()
    let timestamp: Date
    let activity: String
    let mood: MindfulnessEntryView.Mood
    let feelings: String
}

// プレビュー
struct MindfulnessEntryView_Previews: PreviewProvider {
    static var previews: some View {
        MindfulnessEntryView()
    }
}
