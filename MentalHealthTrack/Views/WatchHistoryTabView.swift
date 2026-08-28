import SwiftUI
import CoreData
import UniformTypeIdentifiers

// YouTube Takeout の視聴履歴を取り込み、無意識の視聴傾向を見える化する。
// 解析・保存はすべて端末内。生タイトルを外部に送らない。
// 親側の NavigationView 内で使う想定。
struct WatchHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WatchEvent.watchedAt, ascending: false)],
        animation: .default)
    private var events: FetchedResults<WatchEvent>

    @State private var showingFileImporter = false
    @State private var importMessage: String?
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                importSection

                if events.isEmpty {
                    emptyState
                } else {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("すべて削除", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                    categorySection
                    channelSection
                    hourSection
                }
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("取り込み結果", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
        .confirmationDialog("視聴履歴をすべて削除しますか？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("すべて削除", role: .destructive) { deleteAll() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var allowedTypes: [UTType] {
        [.json, .html, .plainText]
    }

    // MARK: - Sections

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showingFileImporter = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Takeoutから取り込み")
                            .font(.headline)
                        Text("watch-history.json / .html")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Text("Google Takeout（takeout.google.com）で「YouTube と YouTube Music」の履歴をエクスポートして読み込んでください。解析は端末内だけで行われます。")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.title)
                .foregroundColor(.secondary)
            Text("視聴履歴がまだありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("カテゴリ比率", subtitle: "全\(events.count)件")

            let counts = countBy { $0.category ?? "その他" }
            ForEach(counts, id: \.key) { item in
                RatioBarRow(
                    label: item.key,
                    count: item.count,
                    total: events.count,
                    color: categoryColor(item.key)
                )
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("よく見るチャンネル", subtitle: "上位5つ")

            let counts = Array(countBy { $0.channel ?? "不明" }.prefix(5))
            ForEach(counts, id: \.key) { item in
                HStack {
                    Text(item.key)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.count)回")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var hourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("時間帯の傾向", subtitle: "いつ見ているか")

            let buckets = hourBuckets()
            let maxCount = buckets.map { $0.count }.max() ?? 1
            ForEach(buckets, id: \.label) { bucket in
                RatioBarRow(
                    label: bucket.label,
                    count: bucket.count,
                    total: max(maxCount, 1),
                    color: .indigo,
                    showPercentage: false
                )
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Aggregation

    private func countBy(_ key: (WatchEvent) -> String) -> [(key: String, count: Int)] {
        Dictionary(grouping: events, by: key)
            .map { (key: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private func hourBuckets() -> [(label: String, count: Int)] {
        let calendar = Calendar.current
        let ranges: [(String, Range<Int>)] = [
            ("早朝 (5-8時)", 5..<8),
            ("午前 (8-12時)", 8..<12),
            ("午後 (12-18時)", 12..<18),
            ("夜 (18-23時)", 18..<23),
            ("深夜 (23-5時)", 23..<29) // 23,0,1,2,3,4 は別処理
        ]
        return ranges.map { label, range in
            let count = events.filter { event in
                guard let date = event.watchedAt else { return false }
                let hour = calendar.component(.hour, from: date)
                if range.lowerBound == 23 {
                    return hour >= 23 || hour < 5
                }
                return range.contains(hour)
            }.count
            return (label, count)
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "学習": return .green
        case "ニュース": return .blue
        case "音楽": return .purple
        case "ゲーム": return .orange
        case "スポーツ": return .teal
        case "エンタメ": return .pink
        default: return .gray
        }
    }

    // MARK: - Import / Delete

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                importMessage = "ファイルを読み込めませんでした。"
                return
            }

            let parsed = WatchHistoryParser.parse(data: data, filename: url.lastPathComponent)
            guard !parsed.isEmpty else {
                importMessage = "視聴履歴が見つかりませんでした。Takeoutの watch-history.json を選んでください。"
                return
            }

            // 既存と同じ (タイトル, 日時) は取り込まない
            let existingKeys = Set(events.compactMap { event -> String? in
                guard let title = event.title, let date = event.watchedAt else { return nil }
                return "\(title)_\(date.timeIntervalSince1970)"
            })

            var added = 0
            for item in parsed {
                let key = "\(item.title)_\(item.watchedAt.timeIntervalSince1970)"
                if existingKeys.contains(key) { continue }
                let event = WatchEvent(context: viewContext)
                event.id = UUID()
                event.title = item.title
                event.channel = item.channel
                event.watchedAt = item.watchedAt
                event.source = "youtube"
                event.category = item.category
                added += 1
            }

            do {
                try viewContext.save()
                importMessage = "\(added)件を取り込みました（重複\(parsed.count - added)件はスキップ）。"
            } catch {
                importMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        for event in events {
            viewContext.delete(event)
        }
        try? viewContext.save()
    }
}

// MARK: - RatioBarRow
struct RatioBarRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    var showPercentage: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                if showPercentage {
                    Text("\(count)件 (\(percentageText))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(count)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
    }

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total)
    }

    private var percentageText: String {
        guard total > 0 else { return "0%" }
        return "\(Int(round(Double(count) / Double(total) * 100)))%"
    }
}

#Preview {
    NavigationView {
        WatchHistoryView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
