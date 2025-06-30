import CoreData
import SwiftUI

struct CalendarView: View {
    let entries: [MindfulnessData]
    let onDateSelected: (Date) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var dragOffset = CGSize.zero

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // 月選択ヘッダー
            MonthNavigationHeader(
                selectedMonth: $selectedMonth,
                dateFormatter: dateFormatter
            )

            // 曜日ヘッダー
            WeekdayHeader()

            // カレンダーグリッド
            CalendarGrid(
                selectedMonth: selectedMonth,
                entries: entries,
                selectedDate: selectedDate,
                onDateTapped: { date in
                    selectedDate = date
                    onDateSelected(date)
                }
            )

            Spacer()

            // 凡例
            CalendarLegend()
        }
        .offset(y: dragOffset.height)
        .animation(.interactiveSpring(), value: dragOffset)
    }
}

// MARK: - Components
struct MonthNavigationHeader: View {
    @Binding var selectedMonth: Date
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            Button(action: {
                selectedMonth =
                    Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)
                    ?? selectedMonth
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(dateFormatter.string(from: selectedMonth))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: {
                selectedMonth =
                    Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)
                    ?? selectedMonth
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct WeekdayHeader: View {
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        HStack {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct CalendarGrid: View {
    let selectedMonth: Date
    let entries: [MindfulnessData]
    let selectedDate: Date?
    let onDateTapped: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let days = generateDays(for: selectedMonth)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                CalendarDayView(
                    date: date,
                    isCurrentMonth: calendar.isDate(
                        date, equalTo: selectedMonth, toGranularity: .month),
                    isSelected: selectedDate != nil
                        && calendar.isDate(date, inSameDayAs: selectedDate!),
                    entryCount: entriesCount(for: date),
                    onTapped: {
                        onDateTapped(date)
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private func generateDays(for month: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let numberOfDaysInMonth = range.count

        var days: [Date] = []

        // 前月の日付を追加
        for i in 1..<firstWeekday {
            if let date = calendar.date(byAdding: .day, value: -(firstWeekday - i), to: firstDay) {
                days.append(date)
            }
        }

        // 現在月の日付を追加
        for i in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: i, to: firstDay) {
                days.append(date)
            }
        }

        // 次月の日付を追加（6週間分確保）
        let totalCells = 42
        let remainingCells = totalCells - days.count
        let lastDay = days.last ?? firstDay

        for i in 1...remainingCells {
            if let date = calendar.date(byAdding: .day, value: i, to: lastDay) {
                days.append(date)
            }
        }

        return days
    }

    private func entriesCount(for date: Date) -> Int {
        return MindfulnessDataHelper.entriesForDate(date, from: entries).count
    }
}

struct CalendarLegend: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("記録数の見方")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                LegendItem(color: .gray, text: "記録なし")
                LegendItem(color: .blue, text: "1-2回")
                LegendItem(color: .green, text: "3-4回")
                LegendItem(color: .orange, text: "5回以上")
            }
            .font(.caption2)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(entries: []) { _ in }
    }
}
