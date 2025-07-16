import SwiftUI
import CoreData

struct MindfulnessEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyboard = KeyboardResponder()

    let entry: MindfulnessData

    @State private var activityText: String = ""
    @State private var feelingText: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var selectedGenre: Genre = .work
    @State private var showingDeleteAlert = false
    @State private var showingActivityInfo = false
    @State private var showingFeelingInfo = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 32) {
                        // Grabber（引っ張りハンドル）
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(UIColor.systemGray3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 8)

                            // ヘッダー
                            ZStack {
                                Text("記録を編集")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                        }

                        // 活動ジャンル選択セクション
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
                                Text("この30分間は何に使いましたか？")
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
                                Text("していたこと")
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

                        // 保存ボタン
                        Button(action: saveChanges) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("変更を保存")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .disabled(activityText.isEmpty || feelingText.isEmpty)

                        // 削除ボタン
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("記録を削除")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
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
            .navigationBarHidden(true)
        }
        .onAppear {
            loadEntryData()
        }
        .alert("活動記録のヒント", isPresented: $showingActivityInfo) {
            Button("OK") { }
        } message: {
            Text("具体的な活動内容を記録することで、後で振り返りやすくなります。例：「プレゼン資料作成」「友人とカフェで会話」など")
        }
        .alert("感情記録のヒント", isPresented: $showingFeelingInfo) {
            Button("OK") { }
        } message: {
            Text("感情を詳しく記録することで、自分の気持ちのパターンを理解できます。例：「達成感があった」「少し不安だった」など")
        }

        .alert("記録を削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteEntry()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この記録を削除しますか？")
        }
    }
    
    private func loadEntryData() {
        activityText = entry.activity ?? ""
        feelingText = entry.feelings ?? ""

        // 気分を設定（絵文字と新しい形式の両方に対応）
        if let moodString = entry.mood {
            // まず新しい形式（rawValue）で検索
            if let mood = Mood.allCases.first(where: { $0.rawValue == moodString }) {
                selectedMood = mood
            } else {
                // 絵文字形式の場合は変換
                selectedMood = Mood.fromEmoji(moodString)
            }
        }

        // ジャンルを設定
        if let genreString = entry.genre {
            selectedGenre = Genre.allCases.first { $0.rawValue == genreString } ?? .work
        }
    }
    
    private func saveChanges() {
        entry.activity = activityText
        entry.feelings = feelingText
        entry.mood = selectedMood.rawValue
        entry.genre = selectedGenre.rawValue

        do {
            // 変更をコンテキストに保存
            try viewContext.save()

            // 保存成功のフィードバック
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)

            // メインスレッドで画面を閉じる
            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            print("保存エラー: \(error.localizedDescription)")

            // エラーフィードバック
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    private func deleteEntry() {
        viewContext.delete(entry)

        do {
            try viewContext.save()

            // 削除成功のフィードバック
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)

            // メインスレッドで画面を閉じる
            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            print("削除エラー: \(error.localizedDescription)")

            // エラーフィードバック
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
}
