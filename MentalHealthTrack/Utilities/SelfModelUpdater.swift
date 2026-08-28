import Foundation
import CoreData

// 端末内の記録（気分・購入・視聴）の集計から「自分モデル」を更新する。
// 生データ・生テキストは使わず、集計値からルールベースで文章を組み立てる。
// 外部AIには何も送らない。
enum SelfModelUpdater {

    @discardableResult
    static func update(context: NSManagedObjectContext) -> SelfModel? {
        let moods = fetchMindfulness(context: context)
        let purchases = fetchPurchases(context: context)
        let watches = fetchWatches(context: context)

        let model = fetchOrCreateModel(context: context)
        model.values = buildValues(moods: moods)
        model.energyPatterns = buildEnergyPatterns(moods: moods)
        model.decisionTraps = buildDecisionTraps(moods: moods, purchases: purchases)
        model.spendingTriggers = buildSpendingTriggers(purchases: purchases)
        model.watchPatterns = buildWatchPatterns(watches: watches)
        model.updatedAt = Date()

        do {
            try context.save()
            return model
        } catch {
            print("SelfModel保存エラー: \(error.localizedDescription)")
            return nil
        }
    }

    static func current(context: NSManagedObjectContext) -> SelfModel? {
        let request: NSFetchRequest<SelfModel> = SelfModel.fetchRequest()
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // MARK: - Fetch

    private static func fetchOrCreateModel(context: NSManagedObjectContext) -> SelfModel {
        if let existing = current(context: context) {
            return existing
        }
        let model = SelfModel(context: context)
        model.id = UUID()
        return model
    }

    private static func fetchMindfulness(context: NSManagedObjectContext) -> [MindfulnessData] {
        let request: NSFetchRequest<MindfulnessData> = MindfulnessData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    private static func fetchPurchases(context: NSManagedObjectContext) -> [PurchaseRecord] {
        let request: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "purchasedAt", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    private static func fetchWatches(context: NSManagedObjectContext) -> [WatchEvent] {
        let request: NSFetchRequest<WatchEvent> = WatchEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "watchedAt", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Mood scoring

    // 1(とても悪い)〜5(とても良い)。絵文字とrawValueの両方に対応
    static func moodScore(_ moodString: String?) -> Int? {
        guard let moodString = moodString else { return nil }
        switch moodString {
        case "😊", "とても良い": return 5
        case "🙂", "良い": return 4
        case "😐", "普通": return 3
        case "😔", "悪い": return 2
        case "😢", "とても悪い": return 1
        default: return nil
        }
    }

    // MARK: - Builders

    private static func buildValues(moods: [MindfulnessData]) -> String {
        guard !moods.isEmpty else { return "まだ気分の記録が足りません。記録が溜まると、気分が良くなる活動の傾向がここに出ます。" }

        // ジャンル別の平均気分
        var genreScores: [String: [Int]] = [:]
        for entry in moods {
            guard let genre = entry.genre, let score = moodScore(entry.mood) else { continue }
            genreScores[genre, default: []].append(score)
        }
        let averaged = genreScores
            .filter { $0.value.count >= 3 }
            .map { (genre: $0.key, average: Double($0.value.reduce(0, +)) / Double($0.value.count), count: $0.value.count) }

        guard let best = averaged.max(by: { $0.average < $1.average }),
              let worst = averaged.min(by: { $0.average < $1.average }) else {
            return "記録数がまだ少なく、傾向を出せません（各ジャンル3件以上で分析されます）。"
        }

        var lines = ["「\(best.genre)」の時間に気分が良い傾向（平均\(String(format: "%.1f", best.average))/5、\(best.count)件）。"]
        if worst.genre != best.genre {
            lines.append("「\(worst.genre)」の時間は気分が下がりやすい（平均\(String(format: "%.1f", worst.average))/5）。")
        }
        return lines.joined(separator: "\n")
    }

    private static func buildEnergyPatterns(moods: [MindfulnessData]) -> String {
        guard moods.count >= 5 else { return "記録が5件以上になると、時間帯・曜日の傾向が出ます。" }
        let calendar = Calendar.current

        var hourScores: [Int: [Int]] = [:]   // 時間帯（3時間区切り）
        var weekdayScores: [Int: [Int]] = [:]
        for entry in moods {
            guard let date = entry.timestamp, let score = moodScore(entry.mood) else { continue }
            hourScores[calendar.component(.hour, from: date) / 3, default: []].append(score)
            weekdayScores[calendar.component(.weekday, from: date), default: []].append(score)
        }

        func average(_ scores: [Int]) -> Double {
            Double(scores.reduce(0, +)) / Double(scores.count)
        }

        var lines: [String] = []
        if let bestHour = hourScores.filter({ $0.value.count >= 2 }).max(by: { average($0.value) < average($1.value) }) {
            let start = bestHour.key * 3
            lines.append("\(start)時〜\(start + 3)時ごろに気分が良いことが多い。")
        }
        let weekdayNames = [1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土"]
        if let worstDay = weekdayScores.filter({ $0.value.count >= 2 }).min(by: { average($0.value) < average($1.value) }),
           let name = weekdayNames[worstDay.key] {
            lines.append("\(name)曜日は気分が下がりやすい。")
        }
        return lines.isEmpty ? "時間帯・曜日の傾向はまだ出せません。" : lines.joined(separator: "\n")
    }

    private static func buildDecisionTraps(moods: [MindfulnessData], purchases: [PurchaseRecord]) -> String {
        var lines: [String] = []

        // 気分が低い日に購入しているか
        let calendar = Calendar.current
        let lowMoodDays = Set(moods.compactMap { entry -> Date? in
            guard let date = entry.timestamp, let score = moodScore(entry.mood), score <= 2 else { return nil }
            return calendar.startOfDay(for: date)
        })
        if !lowMoodDays.isEmpty && !purchases.isEmpty {
            let lowMoodPurchases = purchases.filter { purchase in
                guard let date = purchase.purchasedAt else { return false }
                return lowMoodDays.contains(calendar.startOfDay(for: date))
            }
            let ratio = Double(lowMoodPurchases.count) / Double(purchases.count)
            if ratio >= 0.3 {
                lines.append("購入の\(Int(ratio * 100))%が気分の低い日に発生。落ち込んだ日の買い物は一晩置く価値がある。")
            }
        }

        // 購入時の気分がネガティブなものの割合（OCR/手入力で気分が付いているもの）
        let purchasesWithMood = purchases.filter { moodScore($0.mood) != nil }
        let negativePurchases = purchasesWithMood.filter { (moodScore($0.mood) ?? 3) <= 2 }
        if purchasesWithMood.count >= 3 && !negativePurchases.isEmpty {
            lines.append("気分が悪いときの購入が\(negativePurchases.count)件ある。ストレス買いの可能性。")
        }

        return lines.isEmpty ? "まだ明確な判断の癖は見つかっていません。記録を続けると精度が上がります。" : lines.joined(separator: "\n")
    }

    private static func buildSpendingTriggers(purchases: [PurchaseRecord]) -> String {
        guard !purchases.isEmpty else { return "購入記録がまだありません。メールかスクショから取り込むと分析されます。" }

        var categoryTotals: [String: Double] = [:]
        for purchase in purchases {
            categoryTotals[purchase.category ?? "その他", default: 0] += purchase.price
        }
        let sorted = categoryTotals.sorted { $0.value > $1.value }
        guard let top = sorted.first else { return "" }

        let total = categoryTotals.values.reduce(0, +)
        var lines = ["支出が一番大きいのは「\(top.key)」（¥\(Int(top.value)) / 全体¥\(Int(total))）。"]
        if sorted.count >= 2 {
            lines.append("次点は「\(sorted[1].key)」（¥\(Int(sorted[1].value))）。")
        }
        return lines.joined(separator: "\n")
    }

    private static func buildWatchPatterns(watches: [WatchEvent]) -> String {
        guard !watches.isEmpty else { return "視聴履歴がまだありません。Takeoutから取り込むと分析されます。" }

        var categoryCounts: [String: Int] = [:]
        var lateNightCount = 0
        let calendar = Calendar.current
        for watch in watches {
            categoryCounts[watch.category ?? "その他", default: 0] += 1
            if let date = watch.watchedAt {
                let hour = calendar.component(.hour, from: date)
                if hour >= 23 || hour < 5 { lateNightCount += 1 }
            }
        }

        var lines: [String] = []
        if let top = categoryCounts.max(by: { $0.value < $1.value }) {
            let ratio = Int(Double(top.value) / Double(watches.count) * 100)
            lines.append("無意識に見ているのは「\(top.key)」が最多（\(ratio)%）。")
        }
        let lateRatio = Double(lateNightCount) / Double(watches.count)
        if lateRatio >= 0.2 {
            lines.append("視聴の\(Int(lateRatio * 100))%が深夜（23時〜5時）。睡眠との交換になっている可能性。")
        }
        return lines.joined(separator: "\n")
    }
}
