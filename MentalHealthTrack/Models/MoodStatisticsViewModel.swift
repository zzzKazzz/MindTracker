import Foundation
import CoreData
import SwiftUI

// MARK: - Data Models for Statistics
struct MoodStatisticsData: Identifiable {
    let id = UUID()
    let date: Date
    let veryHappyCount: Int
    let happyCount: Int
    let neutralCount: Int
    let sadCount: Int
    let verySadCount: Int

    var totalCount: Int {
        veryHappyCount + happyCount + neutralCount + sadCount + verySadCount
    }
}

struct MoodChartData: Identifiable {
    let id = UUID()
    let date: Date
    let moodType: String
    let count: Int
    let color: Color
}

struct WeekdayMoodData: Identifiable {
    let id = UUID()
    let weekday: Int // 1=日曜日, 2=月曜日, ..., 7=土曜日
    let weekdayName: String
    let veryHappyCount: Int
    let happyCount: Int
    let neutralCount: Int
    let sadCount: Int
    let verySadCount: Int
    let totalCount: Int
    let averageMoodScore: Double
    let dominantMood: String
    let dominantMoodEmoji: String

    init(weekday: Int, veryHappyCount: Int, happyCount: Int, neutralCount: Int, sadCount: Int, verySadCount: Int) {
        self.weekday = weekday
        self.veryHappyCount = veryHappyCount
        self.happyCount = happyCount
        self.neutralCount = neutralCount
        self.sadCount = sadCount
        self.verySadCount = verySadCount
        self.totalCount = veryHappyCount + happyCount + neutralCount + sadCount + verySadCount

        // 曜日名を設定
        let weekdayNames = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
        self.weekdayName = weekdayNames[weekday - 1]

        // 気分スコアを計算（veryHappy=5, happy=4, neutral=3, sad=2, verySad=1）
        let totalScore = (veryHappyCount * 5) + (happyCount * 4) + (neutralCount * 3) + (sadCount * 2) + (verySadCount * 1)
        self.averageMoodScore = totalCount > 0 ? Double(totalScore) / Double(totalCount) : 3.0

        // 最も多い気分を特定
        let moodCounts = [
            ("😊", veryHappyCount),
            ("🙂", happyCount),
            ("😐", neutralCount),
            ("😔", sadCount),
            ("😢", verySadCount)
        ]

        let maxMood = moodCounts.max { $0.1 < $1.1 } ?? ("😐", 0)
        self.dominantMoodEmoji = maxMood.0

        switch maxMood.0 {
        case "😊":
            self.dominantMood = "とても幸せ"
        case "🙂":
            self.dominantMood = "幸せ"
        case "😐":
            self.dominantMood = "普通"
        case "😔":
            self.dominantMood = "悲しい"
        case "😢":
            self.dominantMood = "とても悲しい"
        default:
            self.dominantMood = "普通"
        }
    }
}

struct WeekdayInsight {
    let message: String
    let type: InsightType

    enum InsightType {
        case positive
        case negative
        case neutral
        case pattern
    }
}




enum StatisticsPeriod: String, CaseIterable {
    case daily = "1日"
    case weekly = "1週間"
    case monthly = "1ヶ月"
}

// MARK: - ViewModel
class MoodStatisticsViewModel: ObservableObject {
    @Published var statisticsData: [MoodStatisticsData] = []
    @Published var chartData: [MoodChartData] = []
    @Published var weekdayMoodData: [WeekdayMoodData] = []
    @Published var weekdayInsights: [WeekdayInsight] = []
    @Published var selectedPeriod: StatisticsPeriod = .daily
    @Published var isLoading = false

    private let calendar = Calendar.current

    // 気分文字列から色を取得するヘルパー
    private func getMoodColor(for moodString: String) -> Color {
        let mood = getMoodFromString(moodString)
        return mood.color
    }

    // 気分文字列から名前を取得するヘルパー
    private func getMoodName(for moodString: String) -> String {
        let mood = getMoodFromString(moodString)
        return mood.description
    }

    // 文字列から気分を取得するヘルパー関数
    private func getMoodFromString(_ moodString: String) -> Mood {
        // まず新しい形式（rawValue）で検索
        if let mood = Mood.allCases.first(where: { $0.rawValue == moodString }) {
            return mood
        } else {
            // 絵文字形式の場合は変換
            return Mood.fromEmoji(moodString)
        }
    }

    func updateStatistics(entries: [MindfulnessData]) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let stats = self.calculateStatistics(entries: entries, period: self.selectedPeriod)
            let chartData = self.generateChartData(from: stats)
            let weekdayMoodData = self.calculateWeekdayMoodStatistics(entries: entries)
            let weekdayInsights = self.generateWeekdayInsights(from: weekdayMoodData)

            DispatchQueue.main.async {
                self.statisticsData = stats
                self.chartData = chartData
                self.weekdayMoodData = weekdayMoodData
                self.weekdayInsights = weekdayInsights
                self.isLoading = false
            }
        }
    }

    private func calculateStatistics(entries: [MindfulnessData], period: StatisticsPeriod) -> [MoodStatisticsData] {
        let now = Date()
        var statistics: [MoodStatisticsData] = []

        switch period {
        case .daily:
            // 過去30日間の日別統計
            for i in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
                let dayStats = calculateDayStatistics(entries: entries, date: date)
                statistics.append(dayStats)
            }

        case .weekly:
            // 過去12週間の週別統計
            for i in 0..<12 {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: now) else { continue }
                let weekStats = calculateWeekStatistics(entries: entries, weekStart: weekStart)
                statistics.append(weekStats)
            }

        case .monthly:
            // 過去12ヶ月の月別統計
            for i in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
                let monthStats = calculateMonthStatistics(entries: entries, monthStart: monthStart)
                statistics.append(monthStats)
            }
        }

        return statistics.reversed() // 古い順に並び替え
    }

    private func calculateDayStatistics(entries: [MindfulnessData], date: Date) -> MoodStatisticsData {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let dayEntries = entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= startOfDay && timestamp < endOfDay
        }

        return createMoodStatistics(entries: dayEntries, date: date)
    }

    private func calculateWeekStatistics(entries: [MindfulnessData], weekStart: Date) -> MoodStatisticsData {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start ?? weekStart
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!

        let weekEntries = entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= startOfWeek && timestamp < endOfWeek
        }

        return createMoodStatistics(entries: weekEntries, date: startOfWeek)
    }

    private func calculateMonthStatistics(entries: [MindfulnessData], monthStart: Date) -> MoodStatisticsData {
        let startOfMonth = calendar.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let monthEntries = entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= startOfMonth && timestamp < endOfMonth
        }

        return createMoodStatistics(entries: monthEntries, date: startOfMonth)
    }

    private func createMoodStatistics(entries: [MindfulnessData], date: Date) -> MoodStatisticsData {
        var veryHappyCount = 0
        var happyCount = 0
        var neutralCount = 0
        var sadCount = 0
        var verySadCount = 0

        for entry in entries {
            switch entry.mood {
            case "😊":
                veryHappyCount += 1
            case "🙂":
                happyCount += 1
            case "😐":
                neutralCount += 1
            case "😔":
                sadCount += 1
            case "😢":
                verySadCount += 1
            default:
                break
            }
        }

        return MoodStatisticsData(
            date: date,
            veryHappyCount: veryHappyCount,
            happyCount: happyCount,
            neutralCount: neutralCount,
            sadCount: sadCount,
            verySadCount: verySadCount
        )
    }

    private func generateChartData(from statistics: [MoodStatisticsData]) -> [MoodChartData] {
        var chartData: [MoodChartData] = []

        for stat in statistics {
            // 各気分レベルのデータポイントを作成
            chartData.append(MoodChartData(
                date: stat.date,
                moodType: "とても良い",
                count: stat.veryHappyCount,
                color: Mood.veryHappy.color
            ))

            chartData.append(MoodChartData(
                date: stat.date,
                moodType: "良い",
                count: stat.happyCount,
                color: Mood.happy.color
            ))

            chartData.append(MoodChartData(
                date: stat.date,
                moodType: "普通",
                count: stat.neutralCount,
                color: Mood.neutral.color
            ))

            chartData.append(MoodChartData(
                date: stat.date,
                moodType: "悪い",
                count: stat.sadCount,
                color: Mood.sad.color
            ))

            chartData.append(MoodChartData(
                date: stat.date,
                moodType: "とても悪い",
                count: stat.verySadCount,
                color: Mood.verySad.color
            ))
        }

        return chartData
    }

    // MARK: - Weekday Mood Statistics
    private func calculateWeekdayMoodStatistics(entries: [MindfulnessData]) -> [WeekdayMoodData] {
        var weekdayMoodCounts: [Int: [String: Int]] = [:]

        // 曜日ごとの気分を集計（1=日曜日, 2=月曜日, ..., 7=土曜日）
        for entry in entries {
            guard let timestamp = entry.timestamp else { continue }
            let weekday = calendar.component(.weekday, from: timestamp)
            let mood = entry.mood ?? "😐"

            if weekdayMoodCounts[weekday] == nil {
                weekdayMoodCounts[weekday] = [
                    "😊": 0, "🙂": 0, "😐": 0, "😔": 0, "😢": 0
                ]
            }
            weekdayMoodCounts[weekday]?[mood, default: 0] += 1
        }

        // WeekdayMoodDataオブジェクトを作成
        var weekdayData: [WeekdayMoodData] = []
        for weekday in 1...7 {
            let moodCounts = weekdayMoodCounts[weekday] ?? ["😊": 0, "🙂": 0, "😐": 0, "😔": 0, "😢": 0]
            let data = WeekdayMoodData(
                weekday: weekday,
                veryHappyCount: moodCounts["😊"] ?? 0,
                happyCount: moodCounts["🙂"] ?? 0,
                neutralCount: moodCounts["😐"] ?? 0,
                sadCount: moodCounts["😔"] ?? 0,
                verySadCount: moodCounts["😢"] ?? 0
            )
            weekdayData.append(data)
        }

        return weekdayData
    }

    private func generateWeekdayInsights(from weekdayData: [WeekdayMoodData]) -> [WeekdayInsight] {
        var insights: [WeekdayInsight] = []

        // データが不十分な場合は空の配列を返す
        let totalEntries = weekdayData.reduce(0) { $0 + $1.totalCount }
        guard totalEntries >= 10 else {
            return [WeekdayInsight(message: "より多くのデータが蓄積されると、曜日ごとの気分パターンを分析できます。", type: .neutral)]
        }

        // 最も幸せな曜日を特定
        let happiestWeekday = weekdayData.max { $0.averageMoodScore < $1.averageMoodScore }
        if let happiest = happiestWeekday, happiest.totalCount > 0 {
            let message = "\(happiest.weekdayName)は最も気分が良い日です（平均スコア: \(String(format: "%.1f", happiest.averageMoodScore))）"
            insights.append(WeekdayInsight(message: message, type: .positive))
        }

        // 最も憂鬱な曜日を特定
        let saddestWeekday = weekdayData.min { $0.averageMoodScore < $1.averageMoodScore }
        if let saddest = saddestWeekday, saddest.totalCount > 0 {
            let message = "\(saddest.weekdayName)は気分が落ち込みがちな日です（平均スコア: \(String(format: "%.1f", saddest.averageMoodScore))）"
            insights.append(WeekdayInsight(message: message, type: .negative))
        }

        // 週末と平日の比較
        let weekendData = weekdayData.filter { $0.weekday == 1 || $0.weekday == 7 } // 日曜日と土曜日
        let weekdayDataFiltered = weekdayData.filter { $0.weekday >= 2 && $0.weekday <= 6 } // 月曜日から金曜日

        let weekendAverage = weekendData.reduce(0.0) { $0 + $1.averageMoodScore * Double($1.totalCount) } / Double(weekendData.reduce(0) { $0 + $1.totalCount })
        let weekdayAverage = weekdayDataFiltered.reduce(0.0) { $0 + $1.averageMoodScore * Double($1.totalCount) } / Double(weekdayDataFiltered.reduce(0) { $0 + $1.totalCount })

        if !weekendAverage.isNaN && !weekdayAverage.isNaN {
            if weekendAverage > weekdayAverage + 0.3 {
                insights.append(WeekdayInsight(message: "週末の方が平日よりも気分が良い傾向があります", type: .pattern))
            } else if weekdayAverage > weekendAverage + 0.3 {
                insights.append(WeekdayInsight(message: "平日の方が週末よりも気分が良い傾向があります", type: .pattern))
            }
        }

        // 月曜日の特別な分析
        if let monday = weekdayData.first(where: { $0.weekday == 2 }), monday.totalCount > 0 {
            if monday.averageMoodScore < 2.5 {
                insights.append(WeekdayInsight(message: "月曜日は特に憂鬱になりがちです。週の始まりを意識したセルフケアを心がけましょう", type: .negative))
            }
        }

        // 金曜日の特別な分析
        if let friday = weekdayData.first(where: { $0.weekday == 6 }), friday.totalCount > 0 {
            if friday.averageMoodScore > 3.5 {
                insights.append(WeekdayInsight(message: "金曜日は気分が良い日です。週末への期待が気分を高めているようです", type: .positive))
            }
        }

        return insights
    }
    func changePeriod(to period: StatisticsPeriod) {
        selectedPeriod = period
    }




}
