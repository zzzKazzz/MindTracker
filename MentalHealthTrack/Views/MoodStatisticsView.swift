import SwiftUI
import Charts
import CoreData

struct MoodStatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MoodStatisticsViewModel()

    @State private var showingMoodEntries = false
    @State private var selectedMoodLevel = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: true)],
        animation: .default
    ) private var entries: FetchedResults<MindfulnessData>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 期間選択セグメント
                periodSelectionView

                // 統計サマリー
                statisticsSummaryView

                // 折れ線グラフ
                chartView

                // 詳細統計
                detailStatisticsView

                // 曜日別分析
                weekdayAnalysisView
            }
            .padding()
        }
        .navigationTitle("My統計")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.updateStatistics(entries: Array(entries))
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.updateStatistics(entries: Array(entries))
        }

        .sheet(isPresented: $showingMoodEntries) {
            MoodEntriesView(
                moodLevel: selectedMoodLevel,
                entries: getEntriesForMood(selectedMoodLevel)
            )
            .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Period Selection
    private var periodSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表示期間")
                .font(.headline)
                .fontWeight(.semibold)

            Picker("期間", selection: $viewModel.selectedPeriod) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Statistics Summary
    private var statisticsSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計サマリー")
                .font(.headline)
                .fontWeight(.semibold)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 60)
            } else {
                let totalEntries = viewModel.statisticsData.reduce(0) { $0 + $1.totalCount }
                let averagePerPeriod = totalEntries > 0 ? Double(totalEntries) / Double(viewModel.statisticsData.count) : 0

                HStack {
                    VStack(alignment: .leading) {
                        Text("総記録数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalEntries)回")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("平均記録数/\(viewModel.selectedPeriod.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f回", averagePerPeriod))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Chart View
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("気分の推移")
                .font(.headline)
                .fontWeight(.semibold)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if viewModel.chartData.isEmpty {
                Text("データがありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(viewModel.chartData) { data in
                        LineMark(
                            x: .value("日付", data.date),
                            y: .value("回数", data.count)
                        )
                        .foregroundStyle(by: .value("気分", data.moodType))
                        .symbol(by: .value("気分", data.moodType))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: chartXAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: chartXAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Detail Statistics
    private var detailStatisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詳細統計")
                .font(.headline)
                .fontWeight(.semibold)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 100)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(moodSummaryData, id: \.mood) { item in
                        Button(action: {
                            selectedMoodLevel = item.emoji
                            showingMoodEntries = true
                        }) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(item.emoji)
                                        .font(.title2)
                                    Text(item.mood)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }

                                HStack {
                                    Text("\(item.count)回")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(item.color)
                                    Spacer()
                                    Text("\(item.percentage, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(item.count == 0)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties
    private var chartXAxisStride: Calendar.Component {
        switch viewModel.selectedPeriod {
        case .daily:
            return .day
        case .weekly:
            return .weekOfYear
        case .monthly:
            return .month
        }
    }

    private var chartXAxisFormat: Date.FormatStyle {
        switch viewModel.selectedPeriod {
        case .daily:
            return .dateTime.month(.abbreviated).day()
        case .weekly:
            return .dateTime.month(.abbreviated).day()
        case .monthly:
            return .dateTime.year().month(.abbreviated)
        }
    }

    private var moodSummaryData: [(emoji: String, mood: String, count: Int, percentage: Double, color: Color)] {
        let totalCount = viewModel.statisticsData.reduce(0) { $0 + $1.totalCount }

        let veryHappyTotal = viewModel.statisticsData.reduce(0) { $0 + $1.veryHappyCount }
        let happyTotal = viewModel.statisticsData.reduce(0) { $0 + $1.happyCount }
        let neutralTotal = viewModel.statisticsData.reduce(0) { $0 + $1.neutralCount }
        let sadTotal = viewModel.statisticsData.reduce(0) { $0 + $1.sadCount }
        let verySadTotal = viewModel.statisticsData.reduce(0) { $0 + $1.verySadCount }

        return [
            ("😊", "とても良い", veryHappyTotal, totalCount > 0 ? Double(veryHappyTotal) / Double(totalCount) * 100 : 0, .green),
            ("🙂", "良い", happyTotal, totalCount > 0 ? Double(happyTotal) / Double(totalCount) * 100 : 0, .blue),
            ("😐", "普通", neutralTotal, totalCount > 0 ? Double(neutralTotal) / Double(totalCount) * 100 : 0, .gray),
            ("😔", "悪い", sadTotal, totalCount > 0 ? Double(sadTotal) / Double(totalCount) * 100 : 0, .orange),
            ("😢", "とても悪い", verySadTotal, totalCount > 0 ? Double(verySadTotal) / Double(totalCount) * 100 : 0, .red)
        ]
    }

    // MARK: - Helper Methods
    private func getEntriesForMood(_ moodLevel: String) -> [MindfulnessData] {
        return Array(entries).filter { entry in
            return entry.mood == moodLevel
        }
    }

    // MARK: - Weekday Analysis View
    private var weekdayAnalysisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曜日別分析")
                .font(.headline)
                .fontWeight(.semibold)

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if viewModel.weekdayMoodData.isEmpty || viewModel.weekdayMoodData.allSatisfy({ $0.totalCount == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("曜日別データがありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("より多くの記録を蓄積すると、\n曜日ごとの気分パターンを分析できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            } else {
                VStack(spacing: 16) {
                    // 曜日別気分グラフ
                    weekdayMoodChart

                    // 洞察メッセージ
                    if !viewModel.weekdayInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("気づき")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            ForEach(viewModel.weekdayInsights.indices, id: \.self) { index in
                                let insight = viewModel.weekdayInsights[index]
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: insightIcon(for: insight.type))
                                        .foregroundColor(insightColor(for: insight.type))
                                        .font(.caption)
                                    Text(insight.message)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(insightBackgroundColor(for: insight.type))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var weekdayMoodChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("曜日別平均気分")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 4) {
                ForEach(viewModel.weekdayMoodData, id: \.weekday) { weekdayData in
                    VStack(spacing: 4) {
                        // 気分スコアバー
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(moodScoreColor(weekdayData.averageMoodScore))
                                .frame(width: 30, height: CGFloat(weekdayData.averageMoodScore / 5.0 * 60))
                                .cornerRadius(4)
                        }
                        .frame(height: 60)

                        // 曜日名（短縮形）
                        Text(weekdayShortName(weekdayData.weekday))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // 記録数
                        Text("\(weekdayData.totalCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 凡例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("良い")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text("普通")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("悪い")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private func weekdayShortName(_ weekday: Int) -> String {
        let shortNames = ["日", "月", "火", "水", "木", "金", "土"]
        return shortNames[weekday - 1]
    }

    private func moodScoreColor(_ score: Double) -> Color {
        switch score {
        case 4.0...5.0: return .green
        case 3.0..<4.0: return .blue
        case 2.0..<3.0: return .gray
        case 1.0..<2.0: return .orange
        default: return .red
        }
    }

    private func insightIcon(for type: WeekdayInsight.InsightType) -> String {
        switch type {
        case .positive: return "checkmark.circle.fill"
        case .negative: return "exclamationmark.triangle.fill"
        case .neutral: return "info.circle.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        }
    }

    private func insightColor(for type: WeekdayInsight.InsightType) -> Color {
        switch type {
        case .positive: return .green
        case .negative: return .orange
        case .neutral: return .blue
        case .pattern: return .purple
        }
    }

    private func insightBackgroundColor(for type: WeekdayInsight.InsightType) -> Color {
        switch type {
        case .positive: return Color.green.opacity(0.1)
        case .negative: return Color.orange.opacity(0.1)
        case .neutral: return Color.blue.opacity(0.1)
        case .pattern: return Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Preview
struct MoodStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        MoodStatisticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
