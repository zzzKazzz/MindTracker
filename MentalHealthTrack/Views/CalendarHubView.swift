import SwiftUI
import CoreData

enum CalendarScope: String, CaseIterable {
    case day = "日"
    case week = "週"
    case month = "月"
}

// Outlook 型カレンダーの本体。日/週/月で記録位置を見せ、タップで中身を見る。
struct CalendarHubView: View {
    let entries: [MindfulnessData]
    @Binding var focusedDate: Date
    @Binding var scope: CalendarScope
    let onSelectDate: (Date) -> Void
    let onSelectEntry: (MindfulnessData) -> Void
    let onSelectEmptySlot: (Date, Date) -> Void

    @AppStorage("notificationInterval") private var notificationInterval = 60
    @AppStorage("notificationStartTime") private var notificationStartTime = SettingsView.createTime(hour: 9, minute: 0)
    @AppStorage("notificationEndTime") private var notificationEndTime = SettingsView.createTime(hour: 18, minute: 0)

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header

            switch scope {
            case .month:
                CalendarView(
                    entries: entries,
                    displayedMonth: focusedDate,
                    selectedDate: focusedDate,
                    onDateSelected: { date in
                        focusedDate = date
                        onSelectDate(date)
                    }
                )
            case .week:
                WeekGridView(
                    entries: entries,
                    focusedDate: focusedDate,
                    intervalMinutes: max(notificationInterval, 30),
                    dayStartMinutes: minutes(from: notificationStartTime),
                    dayEndMinutes: minutes(from: notificationEndTime),
                    onSelectEntry: onSelectEntry,
                    onSelectEmptySlot: onSelectEmptySlot
                )
            case .day:
                DayGridView(
                    entries: entries,
                    focusedDate: focusedDate,
                    intervalMinutes: max(notificationInterval, 30),
                    dayStartMinutes: minutes(from: notificationStartTime),
                    dayEndMinutes: minutes(from: notificationEndTime),
                    onSelectEntry: onSelectEntry,
                    onSelectEmptySlot: onSelectEmptySlot
                )
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Picker("表示", selection: $scope) {
                ForEach(CalendarScope.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button(action: { focusedDate = Date() }) {
                    Label("今日", systemImage: "calendar")
                        .font(.subheadline)
                }

                Spacer()

                Button(action: { shift(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }

                Text(periodLabel)
                    .font(.headline)
                    .frame(minWidth: 160)

                Button(action: { shift(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        switch scope {
        case .day:
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: focusedDate)
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: focusedDate)
            let start = interval?.start ?? focusedDate
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? focusedDate
            formatter.dateFormat = "M月d日"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "yyyy年 M月"
            return formatter.string(from: focusedDate)
        }
    }

    private func shift(_ value: Int) {
        switch scope {
        case .day:
            focusedDate = calendar.date(byAdding: .day, value: value, to: focusedDate) ?? focusedDate
        case .week:
            focusedDate = calendar.date(byAdding: .weekOfYear, value: value, to: focusedDate) ?? focusedDate
        case .month:
            focusedDate = calendar.date(byAdding: .month, value: value, to: focusedDate) ?? focusedDate
        }
    }

    private func minutes(from date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
