import SwiftUI
import CoreData

// StatMuse 型の数字宝庫。分析は端末内の集計のみ。
struct MyStatsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MindfulnessData.timestamp, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<MindfulnessData>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PurchaseRecord.purchasedAt, ascending: false)])
    private var purchases: FetchedResults<PurchaseRecord>

    @State private var myStatsSummary: SelfModel?
    @State private var isUpdating = false
    @State private var showingWallPunch = false
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    private static let updatedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    statsCard(title: "This Week", stats: weekStats)
                    statsCard(title: "Career", stats: careerStats)
                    recentDaysCard
                    summaryCard

                    Button(action: updateSummary) {
                        HStack {
                            if isUpdating { ProgressView().tint(.white) }
                            Text("サマリーを更新")
                                .fontWeight(.semibold)
                            Spacer()
                            if let updatedAt = myStatsSummary?.updatedAt {
                                Text(Self.updatedFormatter.string(from: updatedAt))
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        .padding(16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isUpdating)

                    wallPunchButton

                    NavigationLink(destination: MoodStatisticsView()) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(.blue)
                            Text("詳細グラフ")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("MyStats")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                myStatsSummary = SelfModelUpdater.current(context: viewContext)
            }
            .sheet(isPresented: $showingWallPunch) {
                WallPunchView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: Binding(
                get: { selectedDay != nil },
                set: { if !$0 { selectedDay = nil } }
            )) {
                if let selectedDay {
                    DateEntriesView(
                        date: selectedDay,
                        entries: entries.filter { calendar.isDate($0.timestamp ?? Date.distantPast, inSameDayAs: selectedDay) }
                    )
                    .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Week")
                .font(.title)
                .fontWeight(.bold)
            Text("気分・記録のスタッツ")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func statsCard(title: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                statCell(value: stats.moodText, label: "気分")
                statCell(value: "\(stats.entryCount)", label: "記録")
                statCell(value: stats.topGenre, label: "最多")
                statCell(value: stats.spendText, label: "支出")
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recentDaysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("直近")
                .font(.headline)

            if recentDays.isEmpty {
                Text("まだ日次の記録がありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(recentDays, id: \.date) { day in
                    Button(action: { selectedDay = day.date }) {
                        HStack {
                            Text(day.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(day.moodText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(day.genre)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                            Text("\(day.count)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if day.date != recentDays.last?.date {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            if let summary = myStatsSummary {
                summaryLine(summary.values)
                summaryLine(summary.energyPatterns)
                summaryLine(summary.decisionTraps)
            } else {
                Text("記録が溜まると要約が出る")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func summaryLine(_ text: String?) -> some View {
        Group {
            if let text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var wallPunchButton: some View {
        Button(action: { showingWallPunch = true }) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("決断の壁打ち")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("数字とサマリーを材料に確認する")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Stats

    private var weekStats: PeriodStats {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return stats(from: start)
    }

    private var careerStats: PeriodStats {
        stats(from: Date.distantPast)
    }

    private func stats(from start: Date) -> PeriodStats {
        let moodEntries = entries.filter { ($0.timestamp ?? Date.distantPast) >= start }
        let scores = moodEntries.compactMap { SelfModelUpdater.moodScore($0.mood) }
        let average = scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)
        let genres = Dictionary(grouping: moodEntries.compactMap(\.genre), by: { $0 })
            .mapValues(\.count)
        let topGenre = genres.max(by: { $0.value < $1.value })?.key ?? "-"
        let spend = purchases
            .filter { ($0.purchasedAt ?? Date.distantPast) >= start }
            .reduce(0) { $0 + $1.price }
        return PeriodStats(
            moodText: average.map { String(format: "%.1f", $0) } ?? "-",
            entryCount: moodEntries.count,
            topGenre: topGenre,
            spendText: spend > 0 ? "¥\(Int(spend))" : "-"
        )
    }

    private var recentDays: [RecentDay] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let grouped = Dictionary(grouping: entries) { entry -> Date in
            calendar.startOfDay(for: entry.timestamp ?? Date())
        }
        return grouped.keys.sorted(by: >).prefix(7).map { day in
            let dayEntries = grouped[day] ?? []
            let scores = dayEntries.compactMap { SelfModelUpdater.moodScore($0.mood) }
            let average = scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)
            let genre = Dictionary(grouping: dayEntries.compactMap(\.genre), by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key ?? "-"
            return RecentDay(
                date: day,
                label: formatter.string(from: day),
                moodText: average.map { String(format: "%.1f", $0) } ?? "-",
                genre: genre,
                count: dayEntries.count
            )
        }
    }

    private func updateSummary() {
        isUpdating = true
        DispatchQueue.main.async {
            myStatsSummary = SelfModelUpdater.update(context: viewContext)
            isUpdating = false
        }
    }
}

private struct PeriodStats {
    let moodText: String
    let entryCount: Int
    let topGenre: String
    let spendText: String
}

private struct RecentDay {
    let date: Date
    let label: String
    let moodText: String
    let genre: String
    let count: Int
}

#Preview {
    MyStatsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
