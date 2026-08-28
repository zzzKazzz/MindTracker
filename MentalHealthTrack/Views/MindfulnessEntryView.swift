import CoreData
import SwiftUI
import UIKit

struct MindfulnessEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyboard = KeyboardResponder()
    @AppStorage("notificationInterval") private var notificationInterval = 60
    @State private var activityText: String = ""
    @State private var feelingText: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var selectedGenre: Genre = .work
    @State private var entryTime: Date
    @State private var showingActivityInfo = false
    @State private var showingFeelingInfo = false

    // 通知タップ経由のときの記録対象スロット
    let slotStart: Date?
    let slotEnd: Date?

    init(slotStart: Date? = nil, slotEnd: Date? = nil) {
        self.slotStart = slotStart
        self.slotEnd = slotEnd
        self._entryTime = State(initialValue: slotEnd ?? Date())
    }

    // 設定された通知間隔に応じた表現（30分 / 1時間 / 2時間）
    private var intervalLabel: String {
        switch notificationInterval {
        case ..<60: return "\(notificationInterval)分間"
        case 60: return "1時間"
        default: return "\(notificationInterval / 60)時間"
        }
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
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

                            Text(slotEnd == nil ? "🧘‍♂️マインド・ジャーナル" : "この時間はどうだった？")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        Text(slotEnd == nil ? "今の気持ちを記録してみましょう" : "この\(intervalLabel)の気分を記録しましょう")
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
                        // ジャンル選択セクション
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                Text("分類")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("この\(intervalLabel)は何に使いましたか？")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 8) {
                                    ForEach(Genre.allCases, id: \.self) { genre in
                                        VStack(spacing: 4) {
                                            Image(systemName: genre.icon)
                                                .font(.title3)
                                                .foregroundColor(selectedGenre == genre ? .white : genre.color)
                                            Text(genre.rawValue)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedGenre == genre ? .white : .primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(1)
                                        }
                                        .frame(height: 50)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    selectedGenre == genre
                                                        ? genre.color
                                                        : genre.color.opacity(0.1)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    selectedGenre == genre ? genre.color : Color.clear,
                                                    lineWidth: selectedGenre == genre ? 0 : 1
                                                )
                                        )
                                        .scaleEffect(selectedGenre == genre ? 1.02 : 1.0)
                                        .animation(
                                            .spring(response: 0.3, dampingFraction: 0.6),
                                            value: selectedGenre
                                        )
                                        .onTapGesture {
                                            selectedGenre = genre
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    }
                                }
                            }
                        }

                        // 活動内容入力セクション
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                Text("この30分間の活動")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Button(action: { showingActivityInfo = true }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $activityText)
                                        .frame(minHeight: 100, maxHeight: 200)
                                        .padding(12)
                                        .background(Color(UIColor.systemBackground))
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                        )
                                    
                                    if activityText.isEmpty {
                                        Text("何をしていましたか？")
                                            .foregroundColor(Color(UIColor.placeholderText))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .id("activity")
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

                                HStack(spacing: 8) {
                                    ForEach(Mood.allCases, id: \.self) { mood in
                                        VStack(spacing: 6) {
                                            Image(systemName: mood.icon)
                                                .font(.title2)
                                                .foregroundColor(selectedMood == mood ? .white : mood.color)
                                            Text(mood.description)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedMood == mood ? .white : .primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 60)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    selectedMood == mood
                                                        ? mood.color
                                                        : mood.color.opacity(0.1)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedMood == mood ? mood.color : Color.clear,
                                                    lineWidth: selectedMood == mood ? 0 : 1
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
                                Spacer()
                                Button(action: { showingFeelingInfo = true }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $feelingText)
                                        .frame(minHeight: 120, maxHeight: 200)
                                        .padding(12)
                                        .background(Color(UIColor.systemBackground))
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                        )
                                    
                                    if feelingText.isEmpty {
                                        Text("どのように感じましたか？")
                                            .foregroundColor(Color(UIColor.placeholderText))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .id("feeling")
                            }
                        }

                        // 保存ボタン（気分とジャンルだけでも保存できる。文章は任意）
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
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: keyboard.currentHeight) { height in
                    if height > 0 {
                        withAnimation {
                            if !activityText.isEmpty {
                                proxy.scrollTo("activity", anchor: .bottom)
                            } else if !feelingText.isEmpty {
                                proxy.scrollTo("feeling", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: activityText) { _ in
                    if keyboard.currentHeight > 0 {
                        withAnimation {
                            proxy.scrollTo("activity", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: feelingText) { _ in
                    if keyboard.currentHeight > 0 {
                        withAnimation {
                            proxy.scrollTo("feeling", anchor: .bottom)
                        }
                    }
                }
                .padding(.bottom, keyboard.currentHeight)
            }
            .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationBarHidden(true)
        }
        .alert("活動記録のヒント", isPresented: $showingActivityInfo) {
            Button("OK") { }
        } message: {
            Text("• 仕事のメールを確認していた\n• 友人と電話で話していた\n• 散歩をしていた\n• 読書をしていた\n\n振り返った際に、どんな活動が自分の気分に影響するのか理解する手助けになります。")
        }

        .alert("感情記録のヒント", isPresented: $showingFeelingInfo) {
            Button("OK") { }
        } message: {
            Text("• 始めるのは億劫だったが、終えると気分が良かった\n• 時間の無駄だと感じイライラした\n• ダラダラ過ごしてしまい罪悪感があった\n\n感情を振り返ることで、自分の意外な一面を知ることができます。")
        }
    }

    private func timeRangeText() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")

        // 通知タップ経由ならそのスロット、手動なら設定間隔ぶん遡る
        let endTime = slotEnd ?? entryTime
        let startTime = slotStart
            ?? Calendar.current.date(byAdding: .minute, value: -notificationInterval, to: endTime)
            ?? endTime

        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    private func saveEntry() {
        let entry = MindfulnessEntry(
            timestamp: entryTime,
            activity: activityText,
            mood: selectedMood,
            genre: selectedGenre,
            feelings: feelingText
        )

        saveToDatabase(entry)

        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        dismiss()
    }

    private func clearForm() {
        activityText = ""
        feelingText = ""
        selectedMood = .neutral
        selectedGenre = .work
        entryTime = Date()
    }


    private func saveToDatabase(_ entry: MindfulnessEntry) {
        let mindfulnessData = MindfulnessData(context: viewContext)
        mindfulnessData.id = entry.id
        mindfulnessData.timestamp = entry.timestamp
        mindfulnessData.activity = entry.activity
        mindfulnessData.mood = entry.mood.rawValue

        mindfulnessData.genre = entry.genre.rawValue

        mindfulnessData.feelings = entry.feelings
        mindfulnessData.tags = nil

        do {
            try viewContext.save()
            print("データが正常に保存されました")
        } catch {
            print("保存エラー: \(error.localizedDescription)")
        }
    }
}



// プレビュー
struct MindfulnessEntryView_Previews: PreviewProvider {
    static var previews: some View {
        MindfulnessEntryView()
    }
}