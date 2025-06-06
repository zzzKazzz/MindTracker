import CoreData
import SwiftUI

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
                VStack(alignment: .leading, spacing: 24) {
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
                    // 改善されたヘッダー
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.6), Color.purple.opacity(0.6),
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 12, height: 12)

                            Text("マインドフルネス・ジャーナル")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        Text("今の気持ちを記録してみましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // 時間表示をもっとスタイリッシュに
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(timeRangeText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)  // grabberの分、上のパディングを少し減らす

                    VStack(spacing: 28) {
                        // 活動内容入力セクション
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                Text("この30分間の活動")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("何をしていましたか？")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextEditor(text: $activityText)
                                    .frame(minHeight: 100)
                                    .padding(16)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                    )
                            }
                        }

                        // 気分選択セクション
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                    .font(.title3)
                                Text("今の気分")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("どんな気分でしたか？")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    ForEach(Mood.allCases, id: \.self) { mood in
                                        VStack(spacing: 6) {
                                            Text(mood.rawValue)
                                                .font(.system(size: 28))
                                            Text(mood.description)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(
                                                    selectedMood == mood
                                                        ? Color.blue.opacity(0.15)
                                                        : Color(UIColor.systemGray6))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    selectedMood == mood ? Color.blue : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .scaleEffect(selectedMood == mood ? 1.02 : 1.0)
                                        .animation(
                                            .spring(response: 0.3, dampingFraction: 0.6),
                                            value: selectedMood
                                        )
                                        .onTapGesture {
                                            selectedMood = mood
                                            let impactFeedback = UIImpactFeedbackGenerator(
                                                style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    }
                                }
                            }
                        }

                        // 感情詳細入力セクション
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text("感情の詳細")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("どのように感じましたか？")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextEditor(text: $feelingText)
                                    .frame(minHeight: 120)
                                    .padding(16)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                    )
                            }
                        }

                        // 保存ボタン
                        Button(action: saveEntry) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                Text("記録を保存")
                                    .fontWeight(.semibold)
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        activityText.isEmpty || feelingText.isEmpty
                                            ? Color.gray.opacity(0.6) : Color.blue,
                                        activityText.isEmpty || feelingText.isEmpty
                                            ? Color.gray.opacity(0.4) : Color.blue.opacity(0.8),
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            .scaleEffect(activityText.isEmpty || feelingText.isEmpty ? 0.98 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.2),
                                value: activityText.isEmpty || feelingText.isEmpty)
                        }
                        .disabled(activityText.isEmpty || feelingText.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
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
        let entry = MindfulnessEntry(
            timestamp: entryTime,
            activity: activityText,
            mood: selectedMood,
            feelings: feelingText
        )

        saveToDatabase(entry)

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
        let mindfulnessData = MindfulnessData(context: viewContext)
        mindfulnessData.id = entry.id
        mindfulnessData.timestamp = entry.timestamp
        mindfulnessData.activity = entry.activity
        mindfulnessData.mood = entry.mood.rawValue
        mindfulnessData.feelings = entry.feelings

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
