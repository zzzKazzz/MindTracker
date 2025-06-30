import SwiftUI
import PhotosUI
import Vision

struct PurchaseHistoryView: View {
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingPurchaseEntry = false

    var body: some View {
                ScrollView {
                    VStack(spacing: 20) {
                        // 画像アップロード機能
                        VStack(spacing: 16) {
                            Text("購入履歴をアップロード")
                                .font(.headline)
                                .fontWeight(.semibold)

                            // フォトライブラリから選択
                            Button(action: { showingImagePicker = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("購入履歴のスクリーンショットを選択")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)

                        Divider()
                            .padding(.horizontal, 20)

                        // 購入履歴サイトのリスト
                        Text("外部サイトで確認")
                            .font(.headline)
                            .fontWeight(.semibold)
                                                // 注意事項
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("ご利用について")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            Text("各サイトにログインが必要です。\nブラウザで購入履歴ページが開きます。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        VStack(spacing: 16) {
                            // Amazon
                            PurchaseHistoryButton(
                                title: "Amazon",
                                subtitle: "Amazonでの購入履歴を確認",
                                iconName: "bag.fill",
                                iconColor: .orange,
                                url: "https://www.amazon.co.jp/gp/your-account/order-history"
                            )

                            // 楽天市場
                            PurchaseHistoryButton(
                                title: "楽天市場",
                                subtitle: "楽天市場での購入履歴を確認",
                                iconName: "bag.fill",
                                iconColor: .red,
                                url: "https://order.my.rakuten.co.jp/"
                            )

                            // Yahoo!ショッピング（追加オプション）
                            PurchaseHistoryButton(
                                title: "Yahoo!ショッピング",
                                subtitle: "Yahoo!ショッピングでの購入履歴を確認",
                                iconName: "bag.fill",
                                iconColor: .purple,
                                url: "https://order.shopping.yahoo.co.jp/"
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingPurchaseEntry) {
            if let image = selectedImage {
                PurchaseEntryView(image: image)
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if newValue != nil {
                showingPurchaseEntry = true
            }
        }
    }
}

struct PurchaseHistoryButton: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let url: String
    
    var body: some View {
        Button(action: {
            openURL(url)
        }) {
            HStack(spacing: 16) {
                // アイコン
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(8)
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 矢印アイコン
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - DetectedProduct
struct DetectedProduct: Identifiable {
    let id = UUID()
    var name: String
    var price: String
    var category: String
    var boundingBox: CGRect
    var purchaseReason: String = ""
    var mood: String = "😐"
}

// MARK: - PurchaseEntryView
struct PurchaseEntryView: View {
    let image: UIImage

    @State private var detectedProducts: [DetectedProduct] = []
    @State private var isProcessingOCR = false
    @State private var extractedText = ""
    @State private var selectedProductIndex = 0

    let moods = ["😊", "🙂", "😐", "😔", "😢"]
    let categories = ["食品・飲料", "ファッション", "電子機器", "本・雑誌", "日用品", "趣味・娯楽", "その他"]

    var body: some View {
                ScrollView {
                    VStack(spacing: 20) {
                        // 画像表示
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        if isProcessingOCR {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("複数商品を検出中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                    // 検出された商品一覧
                    if !detectedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("検出された商品")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(detectedProducts.count)件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // 商品選択タブ
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(detectedProducts.indices, id: \.self) { index in
                                        Button(action: { selectedProductIndex = index }) {
                                            VStack(spacing: 4) {
                                                Text("商品\(index + 1)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                Text(detectedProducts[index].name.prefix(10) + (detectedProducts[index].name.count > 10 ? "..." : ""))
                                                    .font(.caption2)
                                                    .lineLimit(1)
                                                Text("¥\(detectedProducts[index].price)")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedProductIndex == index ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // 選択された商品の詳細入力フォーム
                        if selectedProductIndex < detectedProducts.count {
                            VStack(spacing: 16) {
                                Text("商品\(selectedProductIndex + 1)の詳細")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // 商品名
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("商品名")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    TextField("商品名を入力", text: Binding(
                                        get: { detectedProducts[selectedProductIndex].name },
                                        set: { detectedProducts[selectedProductIndex].name = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                }

                                // 価格
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("価格")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    TextField("価格を入力", text: Binding(
                                        get: { detectedProducts[selectedProductIndex].price },
                                        set: { detectedProducts[selectedProductIndex].price = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                }

                                // カテゴリ
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("カテゴリ")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Picker("カテゴリ", selection: Binding(
                                        get: { detectedProducts[selectedProductIndex].category },
                                        set: { detectedProducts[selectedProductIndex].category = $0 }
                                    )) {
                                        ForEach(categories, id: \.self) { category in
                                            Text(category).tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                // 購入理由
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("購入理由")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    TextField("なぜこの商品を購入しましたか？", text: Binding(
                                        get: { detectedProducts[selectedProductIndex].purchaseReason },
                                        set: { detectedProducts[selectedProductIndex].purchaseReason = $0 }
                                    ), axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...6)
                                }

                                // 購入時の気分
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("購入時の気分")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    HStack {
                                        ForEach(moods, id: \.self) { moodOption in
                                            Button(action: {
                                                detectedProducts[selectedProductIndex].mood = moodOption
                                            }) {
                                                Text(moodOption)
                                                    .font(.title2)
                                                    .frame(width: 50, height: 50)
                                                    .background(detectedProducts[selectedProductIndex].mood == moodOption ? Color.blue.opacity(0.2) : Color.clear)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }

                    // 保存ボタン
                    Button(action: saveAllPurchaseRecords) {
                        Text("全ての商品を保存 (\(detectedProducts.count)件)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(detectedProducts.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(detectedProducts.isEmpty)

                    // デバッグ用：抽出されたテキスト
                    if !extractedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("検出されたテキスト（デバッグ用）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(extractedText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    }
                    .padding()
                }
                .onAppear {
                    performOCR()
                }
    }

    private func performOCR() {
        isProcessingOCR = true

        guard let cgImage = image.cgImage else {
            isProcessingOCR = false
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                self.isProcessingOCR = false

                if let error = error {
                    print("OCRエラー: \(error)")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }

                // テキストと位置情報を保持
                let textObservations = observations.compactMap { observation -> (String, CGRect)? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return (topCandidate.string, observation.boundingBox)
                }

                self.extractedText = textObservations.map { $0.0 }.joined(separator: "\n")
                self.detectMultipleProducts(from: textObservations)
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja", "en"]
        request.usesLanguageCorrection = true  // 言語補正ON

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingOCR = false
                    print("OCR処理エラー: \(error)")
                }
            }
        }
    }

    private func detectMultipleProducts(from textObservations: [(String, CGRect)]) {
        var products: [DetectedProduct] = []
        var priceTexts: [(String, CGRect)] = []
        var allTexts: [(String, CGRect)] = []

        // 全テキストを保持し、価格のみ分類
        for (text, boundingBox) in textObservations {
            allTexts.append((text, boundingBox))
            if isPriceText(text) {
                priceTexts.append((cleanPriceText(text), boundingBox))
            }
        }

        print("全テキスト数: \(allTexts.count)")
        print("価格テキスト数: \(priceTexts.count)")

        // 各価格に対して最適な商品名を構築
        for (price, priceBoundingBox) in priceTexts {
            let productName = buildProductName(
                around: priceBoundingBox,
                from: allTexts,
                excludingPrices: priceTexts.map { $0.0 }
            )

            if !productName.isEmpty {
                // 重複チェック（同じ商品名は追加しない）
                let isDuplicate = products.contains { existingProduct in
                    let similarity = calculateStringSimilarity(existingProduct.name, productName)
                    return similarity > 0.8 // 80%以上似ている場合は重複とみなす
                }

                if !isDuplicate {
                    let product = DetectedProduct(
                        name: productName,
                        price: price,
                        category: guessCategory(from: productName),
                        boundingBox: priceBoundingBox
                    )
                    products.append(product)
                    print("商品検出: \(productName) - ¥\(price)")
                } else {
                    print("重複商品をスキップ: \(productName) - ¥\(price)")
                }
            } else {
                print("価格 ¥\(price) に対応する商品名が見つかりませんでした")
            }
        }

        // Y座標でソート（上から下へ）
        products.sort { $0.boundingBox.midY > $1.boundingBox.midY }

        self.detectedProducts = products

        print("最終的に検出された商品数: \(products.count)")
    }

    private func buildProductName(around priceBoundingBox: CGRect, from allTexts: [(String, CGRect)], excludingPrices: [String]) -> String {
        // 価格の周辺にあるテキストを収集
        let nearbyTexts = allTexts.compactMap { (text, boundingBox) -> (String, CGRect, Double)? in
            // 価格テキストは除外
            if excludingPrices.contains(where: { text.contains($0) }) {
                return nil
            }

            // 明らかに商品名ではないテキストを除外
            if !isValidProductNamePart(text) {
                return nil
            }

            // 距離を計算
            let distance = calculateDistance(priceBoundingBox, boundingBox)

            // 距離が近い場合のみ候補とする
            if distance < 0.3 { // 閾値を厳しく設定
                return (text, boundingBox, distance)
            }

            return nil
        }

        // 距離でソートして最も近いテキストを選択
        let sortedTexts = nearbyTexts.sorted { $0.2 < $1.2 }

        // 最も適切な商品名を構築
        if let bestText = sortedTexts.first {
            var productName = bestText.0

            // 同じ行にある他のテキストも結合を試みる
            let sameLineTexts = sortedTexts.filter { candidate in
                abs(candidate.1.midY - bestText.1.midY) < 0.05 && // 同じ行
                candidate.0 != bestText.0 // 同じテキストではない
            }

            for sameLineText in sameLineTexts.prefix(2) { // 最大2つまで結合
                if sameLineText.1.minX > bestText.1.maxX { // 右側にある
                    productName += " " + sameLineText.0
                } else if sameLineText.1.maxX < bestText.1.minX { // 左側にある
                    productName = sameLineText.0 + " " + productName
                }
            }

            return cleanProductName(productName)
        }

        return ""
    }

    private func isValidProductNamePart(_ text: String) -> Bool {
        // 基本的な長さチェック
        guard text.count >= 2 && text.count <= 100 else { return false }

        // 除外パターン（より厳密に）
        let excludePatterns = [
            // サイト・UI関連
            "amazon", "rakuten", "yahoo", "楽天", "アマゾン",
            "カート", "購入", "注文", "決済", "配送", "送料",
            "税込", "税抜", "消費税", "合計", "小計", "割引",
            // レビュー・評価
            "レビュー", "評価", "★", "☆", "星", "点数", "位", "常連",
            // 日付・時間
            "年", "月", "日", "時", "分", "曜日",
            // 数量のみ
            "個", "本", "枚", "台", "点", "セット", "パック",
            // その他
            "詳細", "もっと見る", "続きを読む", "ログイン"
        ]

        let lowercaseText = text.lowercased()
        for pattern in excludePatterns {
            if lowercaseText.contains(pattern.lowercased()) {
                return false
            }
        }

        // 数字だけや記号だけのテキストは除外
        if text.range(of: #"^[\d\s,.-]+$"#, options: .regularExpression) != nil {
            return false
        }

        // 記号が多すぎる場合は除外（50%以上が記号）
        let symbolCount = text.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        if Double(symbolCount) / Double(text.count) > 0.5 {
            return false
        }

        return true
    }

    private func calculateDistance(_ rect1: CGRect, _ rect2: CGRect) -> Double {
        let dx = rect1.midX - rect2.midX
        let dy = rect1.midY - rect2.midY
        return sqrt(dx * dx + dy * dy)
    }
    // TODO:画像解析の精度は上げていこうぜ
    private func cleanProductName(_ name: String) -> String {
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) // 複数スペースを1つに
            .replacingOccurrences(of: "】", with: "") // 不要な記号を削除
            .replacingOccurrences(of: "【", with: "")
    }

    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1

        if longer.isEmpty { return 1.0 }

        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count

        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)

        for i in 0...str1Count {
            matrix[i][0] = i
        }

        for j in 0...str2Count {
            matrix[0][j] = j
        }

        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[str1Count][str2Count]
    }

    private func isPriceText(_ text: String) -> Bool {
        // より厳密な価格パターンの検出
        let pricePattern = #"^[¥￥]?[\d,]{2,}[円]?$"#  // 最低2桁の数字
        let hasValidPrice = text.range(of: pricePattern, options: .regularExpression) != nil

        // 価格として無効なパターンを除外
        let invalidPricePatterns = [
            "年", "月", "日", "時", "分", "秒",  // 日時
            "個", "本", "枚", "台", "点",        // 数量
            "％", "%", "割引", "OFF"             // 割引率
        ]

        for pattern in invalidPricePatterns {
            if text.contains(pattern) {
                return false
            }
        }

        return hasValidPrice
    }

    private func cleanPriceText(_ text: String) -> String {
        // 価格から数字のみを抽出
        return text.replacingOccurrences(of: "[¥￥円,]", with: "", options: .regularExpression)
    }

    private func isProductTextCandidate(_ text: String) -> Bool {
        // 基本的な長さチェック
        guard text.count >= 3 && text.count <= 50 else { return false }

        // 価格テキストは除外
        guard !isPriceText(text) else { return false }

        // 明らかに商品名ではないテキストを除外
        let excludePatterns = [
            // サイト関連
            "amazon", "rakuten", "yahoo", "楽天", "アマゾン",
            // 購入関連UI
            "カート", "購入", "注文", "決済", "支払", "配送", "送料",
            "税込", "税抜", "消費税", "合計", "小計", "割引", "ポイント",
            // 日付・時間
            "年", "月", "日", "時", "分", "曜日",
            // レビュー関連
            "レビュー", "評価", "★", "☆", "星", "点数",
            // 数量・単位
            "個入", "本入", "セット", "パック", "ケース",
            // その他のUI要素
            "詳細", "もっと見る", "続きを読む", "クリック", "タップ",
            "ログイン", "会員", "登録", "新規", "初回",
            // 一般的でない記号が多い
            "http", "www", "@", "#"
        ]

        let lowercaseText = text.lowercased()
        for pattern in excludePatterns {
            if lowercaseText.contains(pattern.lowercased()) {
                return false
            }
        }

        // 数字だけのテキストは除外
        if text.range(of: #"^[\d\s,.-]+$"#, options: .regularExpression) != nil {
            return false
        }

        // 記号が多すぎるテキストは除外
        let symbolCount = text.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        if Double(symbolCount) / Double(text.count) > 0.3 {
            return false
        }

        return true
    }

    private func calculateProductScore(productName: String, productBoundingBox: CGRect, priceBoundingBox: CGRect) -> Double {
        var score: Double = 0

        // 1. 距離スコア（近いほど高得点）
        let distance = abs(productBoundingBox.midY - priceBoundingBox.midY)
        let distanceScore = max(0, 1.0 - Double(distance) * 2.0) // 距離が0.5以上だと0点
        score += distanceScore * 0.4

        // 2. 商品名らしさスコア
        let productScore = calculateProductNameScore(productName)
        score += productScore * 0.6

        return score
    }

    private func calculateProductNameScore(_ text: String) -> Double {
        var score: Double = 0.5 // ベーススコア

        // 商品名らしい特徴があれば加点
        let productKeywords = [
            // 電子機器
            "iPhone", "iPad", "MacBook", "イヤホン", "ケーブル", "充電器", "バッテリー",
            // ファッション
            "Tシャツ", "シャツ", "パンツ", "スカート", "ジャケット", "靴", "バッグ",
            // 本・メディア
            "本", "書籍", "DVD", "CD", "ゲーム", "漫画", "雑誌",
            // 日用品
            "洗剤", "シャンプー", "歯ブラシ", "タオル", "ティッシュ",
            // 食品
            "コーヒー", "お茶", "米", "パン", "お菓子", "調味料"
        ]

        for keyword in productKeywords {
            if text.contains(keyword) {
                score += 0.3
                break
            }
        }

        // 適切な長さの商品名は加点
        if text.count >= 5 && text.count <= 30 {
            score += 0.2
        }

        return min(score, 1.0)
    }

    private func guessCategory(from productName: String) -> String {
        let categoryKeywords: [String: [String]] = [
            "電子機器": ["iPhone", "iPad", "MacBook", "イヤホン", "ケーブル", "充電器", "バッテリー", "スマホ", "PC", "パソコン"],
            "ファッション": ["Tシャツ", "シャツ", "パンツ", "スカート", "ジャケット", "靴", "バッグ", "帽子", "アクセサリー"],
            "本・雑誌": ["本", "書籍", "DVD", "CD", "ゲーム", "漫画", "雑誌", "小説"],
            "日用品": ["洗剤", "シャンプー", "歯ブラシ", "タオル", "ティッシュ", "洗濯", "掃除"],
            "食品・飲料": ["コーヒー", "お茶", "米", "パン", "お菓子", "調味料", "水", "ジュース"]
        ]

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if productName.contains(keyword) {
                    return category
                }
            }
        }

        return "その他"
    }

    private func saveAllPurchaseRecords() {
        // TODO: Core Dataに保存する処理を実装
        print("全ての購入記録を保存:")
        for (index, product) in detectedProducts.enumerated() {
            print("商品\(index + 1):")
            print("  商品名: \(product.name)")
            print("  価格: \(product.price)")
            print("  カテゴリ: \(product.category)")
            print("  購入理由: \(product.purchaseReason)")
            print("  気分: \(product.mood)")
        }

        // TODO: 保存完了後の処理
    }
}

// MARK: - Preview
struct PurchaseHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseHistoryView()
    }
}
