import Foundation

// Takeoutから抽出した視聴1件分
struct ParsedWatchEvent: Identifiable {
    let id = UUID()
    let title: String
    let channel: String
    let watchedAt: Date
    let category: String
}

// Google Takeout の YouTube 視聴履歴（watch-history.json / watch-history.html）を
// ローカルで解析する。生タイトルは端末内にのみ保存し、外部には集計だけを使う。
enum WatchHistoryParser {

    static func parse(data: Data, filename: String) -> [ParsedWatchEvent] {
        if filename.lowercased().hasSuffix(".json") {
            return parseJSON(data)
        }
        if let text = String(data: data, encoding: .utf8) {
            // 拡張子が不明でもJSONとして読めるなら読む
            if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
                return parseJSON(data)
            }
            return parseHTML(text)
        }
        return []
    }

    // MARK: - JSON (推奨フォーマット)

    private struct TakeoutEntry: Decodable {
        struct Subtitle: Decodable {
            let name: String?
        }
        let title: String?
        let subtitles: [Subtitle]?
        let time: String?
    }

    private static func parseJSON(_ data: Data) -> [ParsedWatchEvent] {
        guard let entries = try? JSONDecoder().decode([TakeoutEntry].self, from: data) else {
            return []
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFraction = ISO8601DateFormatter()

        return entries.compactMap { entry in
            guard let rawTitle = entry.title, let timeString = entry.time else { return nil }
            guard let date = isoFormatter.date(from: timeString)
                    ?? isoFormatterNoFraction.date(from: timeString) else { return nil }

            let title = cleanTitle(rawTitle)
            guard !title.isEmpty else { return nil }
            let channel = entry.subtitles?.first?.name ?? "不明"

            return ParsedWatchEvent(
                title: title,
                channel: channel,
                watchedAt: date,
                category: categorize(title: title, channel: channel)
            )
        }
    }

    // MARK: - HTML (ベストエフォート)

    private static func parseHTML(_ html: String) -> [ParsedWatchEvent] {
        // <a href="...watch?v=...">タイトル</a><br><a href="...">チャンネル</a><br>2024/01/01 12:34:56 JST
        let pattern = #"<a href="https://www\.youtube\.com/watch[^"]*">([^<]+)</a><br\s*/?>\s*<a href="[^"]*">([^<]+)</a><br\s*/?>\s*([\d/年月日\s:APM]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"

        var events: [ParsedWatchEvent] = []
        let range = NSRange(html.startIndex..., in: html)
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match = match,
                  let titleRange = Range(match.range(at: 1), in: html),
                  let channelRange = Range(match.range(at: 2), in: html),
                  let dateRange = Range(match.range(at: 3), in: html) else { return }

            let title = cleanTitle(String(html[titleRange]))
            let channel = String(html[channelRange])
            let dateString = String(html[dateRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let date = formatter.date(from: String(dateString.prefix(19))) ?? Date()

            events.append(ParsedWatchEvent(
                title: title,
                channel: channel,
                watchedAt: date,
                category: categorize(title: title, channel: channel)
            ))
        }
        return events
    }

    private static func cleanTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "を視聴しました", with: "")
            .replacingOccurrences(of: "Watched ", with: "")
            .replacingOccurrences(of: "視聴しました: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Category

    static func categorize(title: String, channel: String) -> String {
        let text = "\(title) \(channel)"
        let categoryKeywords: [String: [String]] = [
            "学習": ["解説", "講座", "入門", "tutorial", "勉強", "英語", "プログラミング", "数学", "歴史", "レッスン", "how to", "使い方"],
            "ニュース": ["ニュース", "news", "速報", "報道", "政治", "経済"],
            "音楽": ["MV", "music", "ライブ", "歌ってみた", "cover", "曲", "アルバム", "official video"],
            "ゲーム": ["ゲーム", "実況", "攻略", "gameplay", "プレイ"],
            "スポーツ": ["サッカー", "野球", "バスケ", "テニス", "スポーツ", "ハイライト", "試合"],
            "エンタメ": ["面白", "ドッキリ", "vlog", "検証", "やってみた", "モッパン", "切り抜き"]
        ]

        for (category, keywords) in categoryKeywords {
            for keyword in keywords where text.localizedCaseInsensitiveContains(keyword) {
                return category
            }
        }
        return "その他"
    }
}
