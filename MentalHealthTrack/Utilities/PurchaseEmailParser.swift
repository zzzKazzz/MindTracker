import Foundation

// メール本文から抽出した購入1件分
struct ParsedPurchase: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var merchant: String
    var purchasedAt: Date
    var category: String
}

// Amazon / 楽天などの注文確認メールをローカルで解析する。
// 生メールは端末外に出さない前提なので、LLMは使わず正規表現ベースで抽出する。
enum PurchaseEmailParser {

    static func parse(_ rawText: String) -> [ParsedPurchase] {
        let text = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        let merchant = detectMerchant(text)
        let orderDate = detectOrderDate(text) ?? Date()

        var purchases: [ParsedPurchase] = []
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for (index, line) in lines.enumerated() {
            guard let price = extractPrice(line), price > 0 else { continue }
            if isExcludedLine(line) { continue }

            // 価格と同じ行に商品名があればそれを、なければ直前の行を商品名とみなす
            var name = removePricePart(line)
            if name.count < 2, index > 0 {
                for lookback in 1...min(3, index) {
                    let candidate = lines[index - lookback]
                    if candidate.count >= 2, !isExcludedLine(candidate), extractPrice(candidate) == nil {
                        name = candidate
                        break
                    }
                }
            }
            guard name.count >= 2 else { continue }

            // 同名・同額の重複は取らない
            if purchases.contains(where: { $0.name == name && $0.price == price }) { continue }

            purchases.append(ParsedPurchase(
                name: name,
                price: price,
                merchant: merchant,
                purchasedAt: orderDate,
                category: guessCategory(from: name)
            ))
        }

        return purchases
    }

    // MARK: - Merchant / Date

    private static func detectMerchant(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("amazon.co.jp") || lower.contains("amazon") || text.contains("アマゾン") {
            return "Amazon"
        }
        if lower.contains("rakuten") || text.contains("楽天") {
            return "楽天市場"
        }
        if lower.contains("yahoo") || text.contains("ヤフー") {
            return "Yahoo!ショッピング"
        }
        return "その他"
    }

    private static func detectOrderDate(_ text: String) -> Date? {
        // 2026年8月18日 / 2026/8/18 / 2026-08-18 に対応
        let pattern = #"(\d{4})[年/\-](\d{1,2})[月/\-](\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let dayRange = Range(match.range(at: 3), in: text),
              let year = Int(text[yearRange]),
              let month = Int(text[monthRange]),
              let day = Int(text[dayRange]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)
    }

    // MARK: - Price

    private static func extractPrice(_ line: String) -> Double? {
        // ¥1,234 / ￥1,234 / 1,234円 に対応
        let patterns = [
            #"[¥￥]\s*([\d,]+)"#,
            #"([\d,]+)\s*円"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range(at: 1), in: line) else {
                continue
            }
            let digits = line[range].replacingOccurrences(of: ",", with: "")
            if let value = Double(digits) {
                return value
            }
        }
        return nil
    }

    private static func removePricePart(_ line: String) -> String {
        var result = line
        for pattern in [#"[¥￥]\s*[\d,]+"#, #"[\d,]+\s*円"#, #"[:：]\s*$"#] {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":：、,")))
    }

    // 合計・送料・ポイントなどの行は商品ではない
    private static func isExcludedLine(_ line: String) -> Bool {
        let excludeKeywords = [
            "合計", "小計", "総額", "送料", "配送料", "手数料",
            "ポイント", "割引", "クーポン", "消費税", "税込", "税抜",
            "お支払い", "支払い", "請求", "残高", "ギフト券", "注文番号"
        ]
        return excludeKeywords.contains { line.contains($0) }
    }

    // MARK: - Category

    static func guessCategory(from productName: String) -> String {
        let categoryKeywords: [String: [String]] = [
            "電子機器": ["iPhone", "iPad", "PC", "パソコン", "イヤホン", "ヘッドホン", "充電", "ケーブル", "モニター", "キーボード", "マウス", "カメラ", "スマホ"],
            "ファッション": ["シャツ", "パンツ", "スカート", "靴", "スニーカー", "バッグ", "帽子", "ジャケット", "コート", "服"],
            "本・雑誌": ["本", "書籍", "DVD", "CD", "ゲーム", "漫画", "雑誌", "小説", "Kindle"],
            "日用品": ["洗剤", "シャンプー", "歯ブラシ", "タオル", "ティッシュ", "洗濯", "掃除", "マスク"],
            "食品・飲料": ["コーヒー", "お茶", "米", "パン", "お菓子", "調味料", "水", "ジュース", "プロテイン", "サプリ"],
            "趣味・娯楽": ["フィギュア", "プラモ", "釣り", "キャンプ", "ゴルフ", "楽器"]
        ]

        for (category, keywords) in categoryKeywords {
            for keyword in keywords where productName.localizedCaseInsensitiveContains(keyword) {
                return category
            }
        }
        return "その他"
    }
}
